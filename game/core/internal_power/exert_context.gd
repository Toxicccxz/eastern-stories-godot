class_name ExertContext
extends RefCounted

## What an exert function file's exert(me, me) works on: the character, its
## query_skill("force"), whether it is fighting and its busy state. The function
## writes its lines here (write(), message_vision() as the character sees it), or
## sets its notify_fail() line and returns false.
var character: CharacterState
var force_level: int
var is_fighting: bool
var busy: ActionBusyState
var lines: Array[ColoredLine] = []
var fail_line: String = ""


func _init(p_character: CharacterState, p_force_level: int, p_is_fighting: bool, p_busy: ActionBusyState) -> void:
	character = p_character
	force_level = p_force_level
	is_fighting = p_is_fighting
	busy = p_busy
