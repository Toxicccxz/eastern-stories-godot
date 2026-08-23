class_name PracticePolicy
extends RefCounted

const CharacterStateType := preload("res://core/characters/character_state.gd")

var skill_id: StringName


func _init(p_skill_id: StringName = &"") -> void:
	skill_id = p_skill_id


## Typed replacement for practice_skill(). Implementations may mutate the
## character before returning, matching the LPC hook contract.
func practice(_character: CharacterStateType) -> bool:
	return true
