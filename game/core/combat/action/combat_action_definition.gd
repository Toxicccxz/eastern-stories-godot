class_name CombatActionDefinition
extends RefCounted

## Immutable typed projection of combatd.c action fields that are active or
## needed for future presentation/policy routing. Legacy dodge/parry fields are
## intentionally absent because combatd.c does not consume them.
var _action_id: StringName
var _damage_percent: int
var _force_percent: int
var _damage_type: StringName
var _presentation_key: StringName
var _legacy_action_text: String
var _displayed_weapon_or_body_token: String
var _post_action_policy_id: StringName
## 战斗决策层 1B: the move's tag (CombatMoveTags, &"" for 平) and the name the battle panel
## shows (the 「」 in the action text, or the data's `name`).
var _tag: StringName
var _name: String

var action_id: StringName:
	get:
		return _action_id
var damage_percent: int:
	get:
		return _damage_percent
var force_percent: int:
	get:
		return _force_percent
var damage_type: StringName:
	get:
		return _damage_type
var presentation_key: StringName:
	get:
		return _presentation_key
var legacy_action_text: String:
	get:
		return _legacy_action_text
var displayed_weapon_or_body_token: String:
	get:
		return _displayed_weapon_or_body_token
var post_action_policy_id: StringName:
	get:
		return _post_action_policy_id
var tag: StringName:
	get:
		return _tag
var display_name: String:
	get:
		return _name


func _init(
	p_action_id: StringName = &"",
	p_damage_percent: int = 0,
	p_force_percent: int = 0,
	p_damage_type: StringName = &"",
	p_presentation_key: StringName = &"",
	p_legacy_action_text: String = "",
	p_displayed_weapon_or_body_token: String = "",
	p_post_action_policy_id: StringName = &"",
	p_tag: StringName = &"",
	p_name: String = "",
) -> void:
	_tag = p_tag
	_name = p_name
	_action_id = p_action_id
	_damage_percent = p_damage_percent
	_force_percent = p_force_percent
	_damage_type = p_damage_type
	_presentation_key = p_presentation_key
	_legacy_action_text = p_legacy_action_text
	_displayed_weapon_or_body_token = p_displayed_weapon_or_body_token
	_post_action_policy_id = p_post_action_policy_id


func is_valid() -> bool:
	return not _action_id.is_empty()


## One authored action mapping: {id, action, damage_type, damage?, force?, weapon?,
## post_action?} (post_action: a CombatPostActionIds function, weapond.c's throw).
## The ID is `id_prefix` + id (the source file's path, e.g. es2:daemon/skill/liuh-ken/);
## `weapon` is the action's own $w when no weapon is held. combatd.c reads no other key.
static func from_record(reader: ContentRecordReader, id_prefix: String) -> CombatActionDefinition:
	var action_id: StringName = StringName(id_prefix + reader.required_text("id"))
	var text: String = reader.required_text("action")
	var tag: StringName = StringName(reader.text("tag"))
	if not CombatMoveTags.is_valid(tag):
		reader.fail("tag", "'%s' is not a move tag (%s)" % [tag, ", ".join(CombatMoveTags.ALL)])
		tag = CombatMoveTags.NONE
	var definition := CombatActionDefinition.new(
		action_id, reader.integer("damage"), reader.integer("force"),
		StringName(reader.required_text("damage_type")), action_id,
		text, reader.text("weapon"), StringName(reader.text("post_action")),
		tag, reader.text("name", name_in(text)),
	)
	if reader.has("post_action") and not CombatPostActionIds.is_supported(definition.post_action_policy_id):
		reader.fail("post_action", "'%s' is not ported (%s)" % [definition.post_action_policy_id, ", ".join(CombatPostActionIds.SUPPORTED)])
	reader.finish()
	return definition


## The move's name as the action text names it: the first 「…」 (「古松挂月」), "" when none.
static func name_in(text: String) -> String:
	var start: int = text.find("「")
	var end: int = text.find("」", start + 1)
	return "" if start < 0 or end < 0 else text.substr(start + 1, end - start - 1)


func duplicate_snapshot() -> CombatActionDefinition:
	return CombatActionDefinition.new(
		_action_id,
		_damage_percent,
		_force_percent,
		_damage_type,
		_presentation_key,
		_legacy_action_text,
		_displayed_weapon_or_body_token,
		_post_action_policy_id,
		_tag,
		_name,
	)
