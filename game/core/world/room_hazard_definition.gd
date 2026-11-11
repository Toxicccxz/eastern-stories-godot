class_name RoomHazardDefinition
extends RefCounted

## An ES2 room that does something to the player again and again while they stay
## (d/chuenyu/trap_castle.c): init()'s call_out("arrowing", first) and, while the player
## is still there, arrowing()'s own call_out(every). Its `act` is what each time does
## (no NPC acts: lines and hurts). Leaving and coming back starts the first wait again
## (init()'s remove_call_out()). Its timing is not saved: a Continue in the room waits
## the first time again, as a player coming in does.
## Native (第八章 A; DECISIONS「寒气」): a `native` hazard is the game's own (the 玄冰's cold, which
## ES2 only spoke of) and runs only while pacing's native_hazards is on; it spares
## whoever wears one of `unless_wearing` (the 寒於宝衣) or bears one of `unless_marks`: the time
## passes, nothing is done to them. Its `act` may hold `acts`, branches as a room's command has
## them (ScriptedAct: the first for the player acts; `at_least` {force} the 内力 that holds the cold off).
var _hazard_id: StringName
var _zone_id: StringName
var _room_id: StringName
var _first_ms: int = 0
var _every_ms: int = 0
var _acts: Array[ScriptedAct] = []
var _legacy_source_path: String
var _native: bool = false
var _unless_wearing: Array[StringName] = []
var _unless_marks: Array[String] = []

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
## The first branch (the only one of an ES2 hazard).
var act: ScriptedAct:
	get:
		return null if _acts.is_empty() else _acts[0]
var legacy_source_path: String:
	get:
		return _legacy_source_path
## The game's own hazard: runs only with pacing's native_hazards.
var native: bool:
	get:
		return _native


## {id, zone, room, first_seconds, every_seconds, act: {steps} | {acts: [...]}, legacy_source, native?,
## unless_wearing?, unless_marks?}.
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
	elif act.has("acts"):
		for record: ContentRecordReader in act.children("acts"):
			definition._acts.append(ScriptedAct.from_record(record))
		act.finish()
		if definition._acts.is_empty():
			act.fail("acts", "a hazard does something")
	else:
		definition._acts.append(ScriptedAct.from_record(act))
	definition._legacy_source_path = reader.required_text("legacy_source")
	definition._native = reader.boolean("native", false)
	for item_id: String in reader.text_list("unless_wearing"):
		definition._unless_wearing.append(StringName(item_id))
	definition._unless_marks = reader.text_list("unless_marks")
	if not definition._native and not (definition._unless_wearing.is_empty() and definition._unless_marks.is_empty()):
		reader.fail("native", "only a native hazard spares anyone")
	reader.finish()
	if definition._first_ms <= 0 or definition._every_ms <= 0:
		reader.fail("every_seconds", "first_seconds and every_seconds are positive")
	return definition


## Whether the hazard spares one wearing these things (by definition id) or bearing these marks.
func spares(worn: Dictionary[StringName, bool], marks: Dictionary[String, int]) -> bool:
	for item_id: StringName in _unless_wearing:
		if worn.get(item_id, false):
			return true
	for mark: String in _unless_marks:
		if marks.get(mark, 0) != 0:
			return true
	return false


## The branch for this player (ScriptedAct.first_for); null when none is.
func act_for(gender: StringName, class_id: StringName, facts: ScriptedAct.Facts = null) -> ScriptedAct:
	return ScriptedAct.first_for(_acts, gender, class_id, facts)


func acts() -> Array[ScriptedAct]:
	return _acts.duplicate()


func unless_wearing() -> Array[StringName]:
	return _unless_wearing.duplicate()


func unless_marks() -> Array[String]:
	return _unless_marks.duplicate()
