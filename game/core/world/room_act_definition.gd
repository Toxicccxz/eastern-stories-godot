class_name RoomActDefinition
extends RefCounted

## A room's or a carried item's own command that acts on whoever uses it (ScriptedAct):
## d/latemoon/room/bathroom.c `take bath` (a 女性 bathes, anyone else is poisoned),
## upstar/uproom3.c `ponder`, latemoon2.c `search bracelet`; obj/bracelet.c `pray start`,
## obj/book.c `dancing home`, room/npc/obj/letter.c `fire`. `verb` is the button's word;
## the first branch that is for the player acts. `command` is the LPC verb a carried item's
## add_action() names (pray, dancing): a room may answer it instead (ZoneDefinition.refusal()).
## `stronger` (d/village/melonfarm.c's pick, owner A10): the command can bring an NPC of
## `stronger.npc` from `stronger.zone` down on the player in a fight to the death, so it is
## asked first (`ask`, `choice`) while the first of them standing there is clearly stronger.
var verb: String = ""
var command: String = ""
var acts: Array[ScriptedAct] = []
var stronger_npc_id: StringName = &""
var stronger_zone_id: StringName = &""
var stronger_ask: String = ""
var stronger_choice: String = ""


## The branch for a player of this gender and class, with these facts; null when none is.
func act_for(gender: StringName, class_id: StringName, facts: ScriptedAct.Facts = null) -> ScriptedAct:
	return ScriptedAct.first_for(acts, gender, class_id, facts)


## Whether a branch rolls (ScriptedAct.kar_above): the branch is chosen when it runs.
func draws() -> bool:
	return acts.any(func(act: ScriptedAct) -> bool: return act.draws())


## {verb, command?, stronger?: {npc, zone, ask, choice}, acts: [ScriptedAct]}.
static func from_record(reader: ContentRecordReader) -> RoomActDefinition:
	var definition := RoomActDefinition.new()
	definition.verb = reader.required_text("verb")
	definition.command = reader.text("command")
	var stronger: ContentRecordReader = reader.child("stronger")
	if stronger != null:
		definition.stronger_npc_id = StringName(stronger.required_text("npc"))
		definition.stronger_zone_id = StringName(stronger.required_text("zone"))
		definition.stronger_ask = stronger.required_text("ask")
		definition.stronger_choice = stronger.required_text("choice")
		stronger.finish()
	for record: ContentRecordReader in reader.children("acts"):
		definition.acts.append(ScriptedAct.from_record(record))
	reader.finish()
	if definition.acts.is_empty():
		reader.fail("acts", "a command does something")
	return definition
