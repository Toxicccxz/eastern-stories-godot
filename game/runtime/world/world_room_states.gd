class_name WorldRoomStates
extends RefCounted

## The Session's room flags: what an ES2 room's own code set() or set_temp() on the room
## itself (d/canyon/bamboo/bamboo3.c's exits/enter), by zone: a zone that holds several rooms
## shares them. std/room.c's reset() leaves them be. Not saved, as doors and room counters are
## not: a new world and a Continue both start with none.
var _flags: Dictionary[StringName, Dictionary] = {}


## The flags `zone_id` has, each 1.
func flags(zone_id: StringName) -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {}
	result.assign(_flags.get(zone_id, {}))
	return result


func has_flag(zone_id: StringName, flag: String) -> bool:
	return flags(zone_id).has(flag)


func set_flag(zone_id: StringName, flag: String) -> void:
	if not _flags.has(zone_id):
		_flags[zone_id] = {}
	_flags[zone_id][flag] = 1


func clear_flag(zone_id: StringName, flag: String) -> void:
	if _flags.has(zone_id):
		_flags[zone_id].erase(flag)
