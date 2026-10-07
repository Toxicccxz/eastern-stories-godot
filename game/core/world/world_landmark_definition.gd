class_name WorldLandmarkDefinition
extends RefCounted

## Something in a zone the player can select, look at and use: an ES2 room
## item (`set("item_desc")`) with a verb such as `climb` or `hold`. Using it
## moves the player through one of its portals; the policy decides which.
## `portal` always takes the single portal; `vine` rolls dodge (epath2.c);
## `hidden_passage` does not move the player: each use is one push, and the
## `pushes`-th opens its two portals (the way down and the way back) for
## `open_seconds` (weapon_storage.c). `bury` buries the `buried` item lying in the
## zone and rolls the player's kar: the `reward` item falls, or the player falls
## through its portal (cave5.c do_bury()). A `portal` landmark may say its LPC
## line (`use`, message_vision() to the mover) instead of the action's name. A
## `look` landmark is only looked at (a sign, a stone tablet): no action, no portal.
## `join_class` is std/room/class_guild.c's join, on the thing that tells of it (the
## 正厅's sign): a player with no class takes its `class` (`joined`); one with a class
## is refused (`refused`).
const POLICIES: Dictionary[StringName, Dictionary] = {
	&"portal": {"portals": 1, "messages": [], "optional_messages": ["use"], "settings": [], "items": []},
	&"vine": {"portals": 2, "messages": ["hold", "fall", "fall_observer", "climb", "climb_observer"], "settings": [], "items": []},
	&"hidden_passage": {"portals": 2, "messages": ["push", "open", "close"], "settings": ["pushes", "open_seconds"], "items": []},
	&"bury": {"portals": 1, "messages": ["bury", "book", "paper", "fall"], "settings": [], "items": ["buried", "reward"]},
	&"look": {"portals": 0, "messages": [], "settings": [], "items": [], "no_action": true},
	&"join_class": {"portals": 0, "messages": ["joined", "refused"], "settings": [], "items": [], "class": true},
}

var _landmark_id: StringName
var _map_id: StringName
var _zone_id: StringName
var _display_name: String
var _description: String
var _action_label: String
var _policy: StringName
var _portal_ids: Array[StringName] = []
var _requires_contact: bool
var _messages: Dictionary[String, String] = {}
var _settings: Dictionary[String, int] = {}
var _items: Dictionary[String, StringName] = {}
var _class_id: StringName = &""
var _legacy_source_path: String

var landmark_id: StringName:
	get:
		return _landmark_id
var map_id: StringName:
	get:
		return _map_id
var zone_id: StringName:
	get:
		return _zone_id
var display_name: String:
	get:
		return _display_name
var description: String:
	get:
		return _description
var action_label: String:
	get:
		return _action_label
var policy: StringName:
	get:
		return _policy
## The first portal; the only one for the `portal` policy.
var portal_id: StringName:
	get:
		return &"" if _portal_ids.is_empty() else _portal_ids[0]
## The player must stand inside the landmark's scene area, not only in its zone.
var requires_contact: bool:
	get:
		return _requires_contact
var legacy_source_path: String:
	get:
		return _legacy_source_path
## The class a `join_class` landmark gives (fighter).
var class_id: StringName:
	get:
		return _class_id


func _init(
	p_landmark_id: StringName = &"",
	p_zone_id: StringName = &"",
	p_display_name: String = "",
	p_description: String = "",
	p_action_label: String = "",
	p_policy: StringName = &"portal",
	p_portal_ids: Array[StringName] = [],
	p_requires_contact: bool = false,
	p_messages: Dictionary[String, String] = {},
	p_legacy_source_path: String = "",
	p_map_id: StringName = &"",
) -> void:
	_landmark_id = p_landmark_id
	_zone_id = p_zone_id
	_display_name = p_display_name
	_description = p_description
	_action_label = p_action_label
	_policy = p_policy
	_portal_ids = p_portal_ids.duplicate()
	_requires_contact = p_requires_contact
	_messages = p_messages.duplicate()
	_legacy_source_path = p_legacy_source_path
	_map_id = p_map_id


static func from_record(reader: ContentRecordReader) -> WorldLandmarkDefinition:
	var portal_ids: Array[StringName] = []
	for id: String in reader.text_list("portals"):
		portal_ids.append(StringName(id))
	var messages: Dictionary[String, String] = {}
	var message_reader: ContentRecordReader = reader.child("messages")
	if message_reader != null:
		for key: String in message_reader.keys():
			messages[key] = message_reader.required_text(key)
		message_reader.finish()
	var settings: Dictionary[String, int] = {}
	for key: String in ["pushes", "open_seconds"]:
		if reader.has(key):
			settings[key] = reader.required_integer(key)
	var definition: WorldLandmarkDefinition = WorldLandmarkDefinition.new(
		StringName(reader.required_text("id")),
		StringName(reader.required_text("zone")),
		reader.required_text("name"),
		reader.required_text("long"),
		reader.text("action") if reader.text("policy", "portal") == "look" else reader.required_text("action"),
		StringName(reader.text("policy", "portal")),
		portal_ids,
		reader.boolean("contact", false),
		messages,
		reader.required_text("legacy_source"),
	)
	definition._settings = settings
	definition._class_id = StringName(reader.text("class"))
	var item_reader: ContentRecordReader = reader.child("items")
	if item_reader != null:
		for key: String in item_reader.keys():
			definition._items[key] = StringName(item_reader.required_text(key))
		item_reader.finish()
	reader.finish()
	if not POLICIES.has(definition.policy):
		reader.fail("policy", "unsupported landmark policy '%s'" % definition.policy)
		return definition
	var rule: Dictionary = POLICIES[definition.policy]
	if rule.get("no_action", false) and not definition.action_label.is_empty():
		reader.fail("action", "a '%s' landmark is only looked at" % definition.policy)
	if definition.class_id.is_empty() == bool(rule.get("class", false)):
		reader.fail("class", "only a join_class landmark names a class, and it must")
	if portal_ids.size() != int(rule["portals"]):
		reader.fail("portals", "policy '%s' needs %d portal(s)" % [definition.policy, rule["portals"]])
	var keys: Array = messages.keys()
	for optional: String in rule.get("optional_messages", []):
		keys.erase(optional)
	keys.sort()
	var expected: Array = (rule["messages"] as Array).duplicate()
	expected.sort()
	if keys != expected:
		reader.fail("messages", "policy '%s' needs exactly %s" % [definition.policy, expected])
	var item_keys: Array = definition._items.keys()
	item_keys.sort()
	var expected_items: Array = (rule["items"] as Array).duplicate()
	expected_items.sort()
	if item_keys != expected_items:
		reader.fail("items", "policy '%s' needs exactly the items %s" % [definition.policy, expected_items])
	var setting_keys: Array = settings.keys()
	setting_keys.sort()
	var expected_settings: Array = (rule["settings"] as Array).duplicate()
	expected_settings.sort()
	if setting_keys != expected_settings:
		reader.fail("", "policy '%s' needs exactly the settings %s" % [definition.policy, expected_settings])
	for key: String in settings:
		if settings[key] < 1:
			reader.fail(key, "must be at least 1")
	return definition


## Copy placed on the map of its zone.
func with_map(map_id: StringName) -> WorldLandmarkDefinition:
	var copy: WorldLandmarkDefinition = WorldLandmarkDefinition.new(_landmark_id, _zone_id, _display_name, _description, _action_label, _policy, _portal_ids, _requires_contact, _messages, _legacy_source_path, map_id)
	copy._items = _items.duplicate()
	copy._settings = _settings.duplicate()
	copy._class_id = _class_id
	return copy


func portal_ids() -> Array[StringName]:
	return _portal_ids.duplicate()


## Authored ES2 text the policy prints, by key (see POLICIES).
func message(key: String) -> String:
	return _messages.get(key, "")


## A policy's authored number (see POLICIES), e.g. `pushes`; 0 when absent.
func setting(key: String) -> int:
	return _settings.get(key, 0)


## A policy's item by role (see POLICIES), e.g. `reward`; empty when absent.
func item(key: String) -> StringName:
	return _items.get(key, &"")


func is_valid() -> bool:
	return (
		not _landmark_id.is_empty()
		and not _zone_id.is_empty()
		and not _display_name.is_empty()
		and not _description.is_empty()
		and POLICIES.has(_policy)
		and _action_label.is_empty() == bool(POLICIES[_policy].get("no_action", false))
		and _portal_ids.size() == int(POLICIES[_policy]["portals"])
		and not _legacy_source_path.is_empty()
	)
