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


## One update as ConditionSystem runs it: update() and its fixed message(). A daemon
## whose lines depend on the update (drunk.c's tiers, a vision line for the room,
## living(me)) overrides this instead and says them through `report`.
func tick(character: CharacterStateType, payload: ConditionPayloadType, report: ConditionReport) -> int:
	var flags: int = update(character, payload)
	if not message().is_empty():
		report.tell(message(), message_color())
	return flags
