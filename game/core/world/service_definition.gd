class_name ServiceDefinition
extends RefCounted

## Something the player can use at one spot of a zone: an ES2 room or NPC
## service (bank convert, work, vendor, pawn shop, teacher). The kind picks the
## rules; the scene places it with a WorldServicePoint of the same ID.
const KINDS: Array[StringName] = [&"bank", &"work", &"vendor", &"hockshop", &"teacher"]

var _service_id: StringName
var _kind: StringName
var _map_id: StringName
var _zone_id: StringName
var _display_name: String
var _reach: int
var _vendor_id: StringName
var _legacy_source: String

var service_id: StringName:
	get:
		return _service_id
var kind: StringName:
	get:
		return _kind
var map_id: StringName:
	get:
		return _map_id
var zone_id: StringName:
	get:
		return _zone_id
var display_name: String:
	get:
		return _display_name
## Pixels from the service point within which the player can use it.
var reach: int:
	get:
		return _reach
## Only for `vendor`: the vendors[] record whose goods are sold.
var vendor_id: StringName:
	get:
		return _vendor_id
var legacy_source: String:
	get:
		return _legacy_source


func _init(
	p_service_id: StringName = &"",
	p_kind: StringName = &"",
	p_map_id: StringName = &"",
	p_zone_id: StringName = &"",
	p_display_name: String = "",
	p_reach: int = 0,
	p_vendor_id: StringName = &"",
	p_legacy_source: String = "",
) -> void:
	_service_id = p_service_id
	_kind = p_kind
	_map_id = p_map_id
	_zone_id = p_zone_id
	_display_name = p_display_name
	_reach = p_reach
	_vendor_id = p_vendor_id
	_legacy_source = p_legacy_source


static func from_record(reader: ContentRecordReader) -> ServiceDefinition:
	var definition: ServiceDefinition = ServiceDefinition.new(
		StringName(reader.required_text("id")),
		StringName(reader.required_text("kind")),
		&"",
		StringName(reader.required_text("zone")),
		reader.required_text("name"),
		reader.required_integer("reach"),
		StringName(reader.text("vendor")),
		reader.required_text("legacy_source"),
	)
	reader.finish()
	if not KINDS.has(definition.kind):
		reader.fail("kind", "unsupported service kind '%s'" % definition.kind)
	if definition.reach <= 0:
		reader.fail("reach", "must be positive")
	if (definition.kind == &"vendor") != not definition.vendor_id.is_empty():
		reader.fail("vendor", "is required for, and only for, kind 'vendor'")
	return definition


## Copy placed on the map of its zone.
func with_map(map_id: StringName) -> ServiceDefinition:
	return ServiceDefinition.new(_service_id, _kind, map_id, _zone_id, _display_name, _reach, _vendor_id, _legacy_source)
