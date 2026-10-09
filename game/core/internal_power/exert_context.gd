class_name ExertContext
extends RefCounted

## What an exert function file's exert(me, me) works on: the character, its
## query_skill("force"), whether it is fighting and its busy state. The function
## writes its lines here (write(), message_vision() as the character sees it), or
## sets its notify_fail() line and returns false. A message_vision() line also goes
## to `vision_lines` as the others in the room read it ($N is `actor_id`): an NPC's
## exert is seen, not read.
var character: CharacterState
var force_level: int
var is_fighting: bool
var busy: ActionBusyState
var actor_id: StringName
var lines: Array[ColoredLine] = []
var vision_lines: Array[VisionLine] = []
var fail_line: String = ""
## MudOS random(n) (n <= 0 gives 0 without a draw); none draws 0.
var random: Callable
## all_inventory(environment(me)) without me: the others in the room, the fight's
## and the bystanders' (roar.c), each with its fight and whether it is living().
var room: Array[SpecialSide] = []
## me->unconcious() (powerfade.c in a fight): set when the file knocked its user out.
var fainted: bool = false
## Those the file had kill_ob() me (roar.c), in the room's order.
var killers: Array[StringName] = []
## std/sserver.c offensive_target(me) for the files that aim at an enemy (chillgaze.c):
## returns a SpecialSide (SpecialContext.offensive_target()); none: no target.
var offensive: Callable


func _init(
	p_character: CharacterState, p_force_level: int, p_is_fighting: bool, p_busy: ActionBusyState,
	p_actor_id: StringName = &"", p_random: Callable = Callable(), p_room: Array[SpecialSide] = [],
) -> void:
	character = p_character
	force_level = p_force_level
	is_fighting = p_is_fighting
	busy = p_busy
	actor_id = p_actor_id
	random = p_random
	room = p_room


## message_vision(template, me): the line as the character reads it ($N is 你) and
## as everyone else does.
func vision(template: String, color: StringName = ColoredLine.PLAIN) -> void:
	lines.append(ColoredLine.new(ExertFunction._as_actor(template), color))
	vision_lines.append(VisionLine.new(template, actor_id, &"", color))


## random(n) as the file draws it.
func legacy_random(n: int) -> int:
	return random.call(n) if random.is_valid() and n > 0 else 0


## offensive_target(me), or null.
func pick_offensive_target() -> SpecialSide:
	return offensive.call() as SpecialSide if offensive.is_valid() else null


## message_vision(template, me, target): $N the character, $n `target`. As the character
## reads it, $N is 你 and $n `target_name` (its short() as shown).
func vision_at(target: SpecialSide, template: String, color: StringName = ColoredLine.PLAIN, target_name: String = "") -> void:
	lines.append(ColoredLine.new(ExertFunction._as_actor(template).replace("$n", target_name), color))
	vision_lines.append(VisionLine.new(template, actor_id, target.character_id, color))


## message_vision(template, target, me): $N is `target`, $n the character (你 as it reads it).
func vision_by(target: SpecialSide, template: String, color: StringName = ColoredLine.PLAIN, target_name: String = "") -> void:
	# TRANSLATORS: message_vision(): the character an exert line names as its $n.
	lines.append(ColoredLine.new(ExertFunction._t(template).replace("$N", target_name).replace("$n", ExertFunction._t("你")), color))
	vision_lines.append(VisionLine.new(template, target.character_id, actor_id, color))
