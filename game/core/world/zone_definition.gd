class_name ZoneDefinition
extends RefCounted

## A walkable part of a map made of one or more ES2 rooms. The first room is
## the zone's primary room: its short and long text are what the player sees.
## How aggressive NPCs start a fight here: `pair` (one at a time) or
## `complete_set` (every aggressive NPC in contact joins one encounter).
const COMBAT_ENTRIES: Array[StringName] = [&"pair", &"complete_set"]

var _zone_id: StringName
var _map_id: StringName
var _room_ids: Array[StringName] = []
var _primary_room: RoomDefinition
var _combat_entry: StringName = &"pair"
var _link_ids: Array[StringName] = []

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
var combat_entry: StringName:
	get:
		return _combat_entry


func _init(
	p_zone_id: StringName = &"",
	p_map_id: StringName = &"",
	p_room_ids: Array[StringName] = [],
	p_primary_room: RoomDefinition = null,
	p_combat_entry: StringName = &"pair",
	p_link_ids: Array[StringName] = [],
) -> void:
	_zone_id = p_zone_id
	_map_id = p_map_id
	_room_ids = p_room_ids.duplicate()
	_primary_room = p_primary_room
	_combat_entry = p_combat_entry
	_link_ids = p_link_ids.duplicate()


static func from_record(reader: ContentRecordReader) -> ZoneDefinition:
	var room_ids: Array[StringName] = []
	for room_id: String in reader.text_list("rooms"):
		room_ids.append(StringName(room_id))
	if room_ids.is_empty():
		reader.fail("rooms", "needs at least one room")
	var link_ids: Array[StringName] = []
	for zone_id: String in reader.text_list("links"):
		link_ids.append(StringName(zone_id))
	var definition: ZoneDefinition = ZoneDefinition.new(
		StringName(reader.required_text("id")),
		StringName(reader.required_text("map")),
		room_ids,
		null,
		StringName(reader.text("combat_entry", "pair")),
		link_ids,
	)
	reader.finish()
	if not COMBAT_ENTRIES.has(definition.combat_entry):
		reader.fail("combat_entry", "unsupported combat entry '%s'" % definition.combat_entry)
	return definition


## Copy whose text comes from the resolved primary room.
func with_primary_room(room: RoomDefinition) -> ZoneDefinition:
	return ZoneDefinition.new(_zone_id, _map_id, _room_ids, room, _combat_entry, _link_ids)


func room_ids() -> Array[StringName]:
	return _room_ids.duplicate()


## Zones the player can walk into although no static ES2 exit says so; each
## link stands for a recorded decision (DECISIONS.md).
func link_ids() -> Array[StringName]:
	return _link_ids.duplicate()


func is_valid() -> bool:
	return (
		not _zone_id.is_empty()
		and not _map_id.is_empty()
		and not _room_ids.is_empty()
		and _primary_room != null
		and _primary_room.room_id == _room_ids[0]
	)
