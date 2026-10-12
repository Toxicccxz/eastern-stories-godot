class_name RoomHazardDefinition
extends RefCounted

## An ES2 room that does something to the player again and again while they stay
## (d/chuenyu/trap_castle.c): init()'s call_out("arrowing", first) and, while the player
## is still there, arrowing()'s own call_out(every). Its `act` is what each time does
## (no NPC acts: lines and hurts). Leaving and coming back starts the first wait again
## (init()'s remove_call_out()). Its timing is not saved: a Continue in the room waits
## the first time again, as a player coming in does.
var _hazard_id: StringName
var _zone_id: StringName
var _room_id: StringName
var _first_ms: int = 0
var _every_ms: int = 0
var _act: ScriptedAct
var _legacy_source_path: String

var hazard_id: StringName:
	get:
		return _hazard_id
var zone_id: StringName:
	get:
		return _zone_id
var room_id: StringName:
	get:
		return _room_id
## World milliseconds from the player's coming in to the first time.
var first_ms: int:
	get:
		return _first_ms
## World milliseconds between one time and the next while the player stays.
var every_ms: int:
	get:
		return _every_ms
var act: ScriptedAct:
	get:
		return _act
var legacy_source_path: String:
	get:
		return _legacy_source_path


## {id, zone, room, first_seconds, every_seconds, act: {steps}, legacy_source}.
static func from_record(reader: ContentRecordReader) -> RoomHazardDefinition:
	var definition := RoomHazardDefinition.new()
	definition._hazard_id = StringName(reader.required_text("id"))
	definition._zone_id = StringName(reader.required_text("zone"))
	definition._room_id = StringName(reader.required_text("room"))
	definition._first_ms = 1000 * reader.required_integer("first_seconds")
	definition._every_ms = 1000 * reader.required_integer("every_seconds")
	var act: ContentRecordReader = reader.child("act")
	if act == null:
		reader.fail("act", "a hazard does something")
	else:
		definition._act = ScriptedAct.from_record(act)
	definition._legacy_source_path = reader.required_text("legacy_source")
	reader.finish()
	if definition._first_ms <= 0 or definition._every_ms <= 0:
		reader.fail("every_seconds", "first_seconds and every_seconds are positive")
	return definition
