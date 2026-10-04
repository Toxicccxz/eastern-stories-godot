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


func _init(p_character: CharacterState, p_force_level: int, p_is_fighting: bool, p_busy: ActionBusyState, p_actor_id: StringName = &"") -> void:
	character = p_character
	force_level = p_force_level
	is_fighting = p_is_fighting
	busy = p_busy
	actor_id = p_actor_id


## message_vision(template, me): the line as the character reads it ($N is 你) and
## as everyone else does.
func vision(template: String, color: StringName = ColoredLine.PLAIN) -> void:
	lines.append(ColoredLine.new(ExertFunction._as_actor(template), color))
	vision_lines.append(VisionLine.new(template, actor_id, &"", color))
