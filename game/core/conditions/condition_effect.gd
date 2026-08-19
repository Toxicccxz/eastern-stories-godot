class_name ConditionEffect
extends RefCounted

const CharacterStateType := preload("res://core/characters/character_state.gd")
const ConditionPayloadType := preload("res://core/conditions/condition_payload.gd")


func condition_id() -> StringName:
	assert(false, "ConditionEffect.condition_id() must be implemented.")
	return &""


## Executes one explicitly requested condition update and returns legacy flags.
func update(_character: CharacterStateType, _payload: ConditionPayloadType) -> int:
	assert(false, "ConditionEffect.update() must be implemented.")
	return 0
