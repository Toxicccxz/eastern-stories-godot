class_name ConditionReport
extends RefCounted

## What one condition update tells: tell_object() lines to the character itself
## (source text, translated by ConditionSystem) and message("vision", ...) lines to
## everyone else in its room, a template whose {name} is the character's name. A
## daemon that asks living(me) reads `conscious`; an unconscious character hears
## nothing (damage.c unconcious() sets block_msg/all).
var conscious: bool = true
var knocked_out: bool = false
var lines: Array[ColoredLine] = []
var room_lines: Array[String] = []


func _init(p_conscious: bool = true) -> void:
	conscious = p_conscious


func tell(text: String, color: StringName = ColoredLine.PLAIN) -> void:
	if conscious:
		lines.append(ColoredLine.new(text, color))


## `template` names the character as {name}.
func tell_room(template: String) -> void:
	room_lines.append(template)


## me->unconcious() from a daemon: the character falls at its next life check
## (CharacterState.fall_unconscious()) and is no longer living(me) for the rest of
## this update.
func knock_out(character: CharacterState) -> void:
	character.fall_unconscious()
	conscious = false
	knocked_out = true
