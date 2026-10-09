class_name RoomActDefinition
extends RefCounted

## A room's own command that acts on whoever uses it (ScriptedAct): d/latemoon/room/
## bathroom.c `take bath` (a 女性 bathes, anyone else is poisoned) and upstar/uproom3.c
## `ponder`. `verb` is the button's word; the first branch that is for the player acts.
var verb: String = ""
var acts: Array[ScriptedAct] = []


## The branch for a player of this gender and class; null when none is.
func act_for(gender: StringName, class_id: StringName) -> ScriptedAct:
	return ScriptedAct.first_for(acts, gender, class_id)


## {verb, acts: [ScriptedAct]}.
static func from_record(reader: ContentRecordReader) -> RoomActDefinition:
	var definition := RoomActDefinition.new()
	definition.verb = reader.required_text("verb")
	for record: ContentRecordReader in reader.children("acts"):
		definition.acts.append(ScriptedAct.from_record(record))
	reader.finish()
	if definition.acts.is_empty():
		reader.fail("acts", "a room's command does something")
	return definition
