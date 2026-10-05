class_name ConditionEffect
extends RefCounted

const CharacterStateType := preload("res://core/characters/character_state.gd")
const ConditionPayloadType := preload("res://core/conditions/condition_payload.gd")


func condition_id() -> StringName:
	assert(false, "ConditionEffect.condition_id() must be implemented.")
	return &""


## What the daemon tell_object()s the character on each update (source text, not
## yet translated) and its include/ansi.h colour; "" prints nothing.
func message() -> String:
	return ""


func message_color() -> StringName:
	return ColoredLine.PLAIN


## The condition's name on the player's HUD (source text); "" is not shown. ES2 shows
## conditions only through their messages; the HUD tag is presentation.
func shown_name() -> String:
	return ""


## Executes one explicitly requested condition update and returns legacy flags.
func update(_character: CharacterStateType, _payload: ConditionPayloadType) -> int:
	assert(false, "ConditionEffect.update() must be implemented.")
	return 0
