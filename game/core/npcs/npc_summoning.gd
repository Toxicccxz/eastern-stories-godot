class_name NpcSummoning
extends RefCounted

## A summoned NPC's coming and going (obj/npc/heaven_soldier.c invocation() and
## leave()): message("vision") lines to the room, in its colour; $N is its name. It
## comes into the fight of whoever called it, against that one's enemies, and leaves
## once the fight is over (heal_up() when it is not fighting).
var arrive: Array[String] = []
var leave: Array[String] = []
var color: StringName = ColoredLine.PLAIN


func is_valid() -> bool:
	return not arrive.is_empty() and not leave.is_empty() and (color == ColoredLine.PLAIN or ColoredLine.COLORS.has(color))


## `summoned` {"arrive": [line], "leave": [line], "color"?}.
static func from_record(reader: ContentRecordReader) -> NpcSummoning:
	var summoning := NpcSummoning.new()
	summoning.arrive = reader.text_list("arrive")
	summoning.leave = reader.text_list("leave")
	summoning.color = StringName(reader.text("color"))
	reader.finish()
	if not summoning.is_valid():
		reader.fail("", "needs its arrive and leave lines (and a known color)")
	return summoning
