class_name DoorDefinition
extends RefCounted

## An ES2 `create_door()` pair between two zones of one map. It starts closed;
## the scene places it with a WorldDoor of the same ID. Door state is not saved.
var _door_id: StringName
var _map_id: StringName
var _display_name: String
var _zone_ids: Array[StringName] = []
var _reach: int
var _closable: bool
var _legacy_room_id: StringName

var door_id: StringName:
	get:
		return _door_id
var map_id: StringName:
	get:
		return _map_id
var display_name: String:
	get:
		return _display_name
## Pixels from the door within which the player can operate it.
var reach: int:
	get:
		return _reach
## False for a door the player may only open (an approved adaptation).
var closable: bool:
	get:
		return _closable
var legacy_room_id: StringName:
	get:
		return _legacy_room_id


func _init(
	p_door_id: StringName = &"",
	p_map_id: StringName = &"",
	p_display_name: String = "",
	p_zone_ids: Array[StringName] = [],
	p_reach: int = 0,
	p_closable: bool = true,
	p_legacy_room_id: StringName = &"",
) -> void:
	_door_id = p_door_id
	_map_id = p_map_id
	_display_name = p_display_name
	_zone_ids = p_zone_ids.duplicate()
	_reach = p_reach
	_closable = p_closable
	_legacy_room_id = p_legacy_room_id


static func from_record(reader: ContentRecordReader) -> DoorDefinition:
	var zones: Array[StringName] = []
	for zone_id: String in reader.text_list("zones"):
		zones.append(StringName(zone_id))
	var definition: DoorDefinition = DoorDefinition.new(
		StringName(reader.required_text("id")),
		&"",
		reader.required_text("name"),
		zones,
		reader.required_integer("reach"),
		reader.boolean("closable", true),
		StringName(reader.required_text("legacy_room")),
	)
	reader.finish()
	if zones.size() != 2:
		reader.fail("zones", "a door joins exactly two zones")
	if definition.reach <= 0:
		reader.fail("reach", "must be positive")
	return definition


## Zones from which the door can be operated (its two sides).
func zone_ids() -> Array[StringName]:
	return _zone_ids.duplicate()


func with_map(map_id: StringName) -> DoorDefinition:
	return DoorDefinition.new(_door_id, map_id, _display_name, _zone_ids, _reach, _closable, _legacy_room_id)
