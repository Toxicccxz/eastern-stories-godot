class_name NpcRaising
extends RefCounted

## An NPC a spell raises from a corpse (obj/npc/zombie.c, made by obj/corpse.c animate()
## for daemon/class/taoist/necromancy/animate.c). It takes the corpse's name
## (`name`: set_name(query("victim_name") + "的僵尸"), {name} the victim's), follows
## whoever raised it and lives on them: each heal_up() it tells them `tell` (in `color`,
## message("tell"): wherever they are), takes `drain_atman` atman and `drain_gin` gin
## while they have more than `drain_above` atman; else, or once the fight its sheet sent
## it into is over (end_tag), it dispells a second later: `dissolve` to its room, then
## destruct(). $N is its name.
var name_template: String
var drain_above: int
var drain_atman: int
var drain_gin: int
var tell: String
var color: StringName = ColoredLine.PLAIN
var dissolve: String

## dispell()'s call_out("dispell", 1).
const DISPELL_DELAY_SECONDS: float = 1.0


func is_valid() -> bool:
	return (
		name_template.contains("{name}") and drain_above >= 0 and drain_atman > 0 and drain_gin >= 0
		and not tell.is_empty() and not dissolve.is_empty()
		and (color == ColoredLine.PLAIN or ColoredLine.COLORS.has(color))
	)


## heal_up()'s test: whether a master with `atman` keeps it (query("atman") > 10).
func feeds_on(atman: int) -> bool:
	return atman > drain_above


## heal_up()'s master->add("atman", -10) and receive_damage("gin", 1).
func drain(master: CharacterState) -> void:
	master.recovery.atman.current -= drain_atman
	master.essence.apply_damage(drain_gin)


## `raised` {"name", "drain": {"above", "atman", "gin"}, "tell", "color"?, "dissolve"}.
static func from_record(reader: ContentRecordReader) -> NpcRaising:
	var raising := NpcRaising.new()
	raising.name_template = reader.required_text("name")
	var drain: ContentRecordReader = reader.child("drain")
	if drain == null:
		reader.fail("drain", "needs above, atman and gin")
	else:
		raising.drain_above = drain.required_integer("above")
		raising.drain_atman = drain.required_integer("atman")
		raising.drain_gin = drain.required_integer("gin")
		drain.finish()
	raising.tell = reader.required_text("tell")
	raising.color = StringName(reader.text("color"))
	raising.dissolve = reader.required_text("dissolve")
	reader.finish()
	if not raising.is_valid():
		reader.fail("", "needs a name with {name}, a positive atman drain, its tell and dissolve lines (and a known color)")
	return raising
