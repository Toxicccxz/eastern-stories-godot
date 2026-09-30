class_name ZoneDefinition
extends RefCounted

## A walkable part of a map made of one or more ES2 rooms. The first room is
## the zone's primary room: its short and long text are what the player sees.
var _zone_id: StringName
var _map_id: StringName
var _room_ids: Array[StringName] = []
var _primary_room: RoomDefinition

var zone_id: StringName:
	get:
		return _zone_id
var map_id: StringName:
	get:
		return _map_id
## Combat happens per zone, as it happened per room in ES2.
var combat_location_id: StringName:
	get:
		return _zone_id
var display_name: String:
	get:
		return "" if _primary_room == null else _primary_room.short
## The primary room's authored long text.
var description: String:
	get:
		return "" if _primary_room == null else _primary_room.long


func _init(
	p_zone_id: StringName = &"",
	p_map_id: StringName = &"",
	p_room_ids: Array[StringName] = [],
	p_primary_room: RoomDefinition = null,
) -> void:
	_zone_id = p_zone_id
	_map_id = p_map_id
	_room_ids = p_room_ids.duplicate()
	_primary_room = p_primary_room


static func from_record(reader: ContentRecordReader) -> ZoneDefinition:
	var room_ids: Array[StringName] = []
	for room_id: String in reader.text_list("rooms"):
		room_ids.append(StringName(room_id))
	if room_ids.is_empty():
		reader.fail("rooms", "needs at least one room")
	var definition: ZoneDefinition = ZoneDefinition.new(
		StringName(reader.required_text("id")),
		StringName(reader.required_text("map")),
		room_ids,
	)
	reader.finish()
	return definition


## Copy whose text comes from the resolved primary room.
func with_primary_room(room: RoomDefinition) -> ZoneDefinition:
	return ZoneDefinition.new(_zone_id, _map_id, _room_ids, room)


func room_ids() -> Array[StringName]:
	return _room_ids.duplicate()


func is_valid() -> bool:
	return (
		not _zone_id.is_empty()
		and not _map_id.is_empty()
		and not _room_ids.is_empty()
		and _primary_room != null
		and _primary_room.room_id == _room_ids[0]
	)
