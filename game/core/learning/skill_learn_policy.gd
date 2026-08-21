class_name SkillLearnPolicy
extends RefCounted

const CharacterStateType := preload("res://core/characters/character_state.gd")
const PolicyResultType := preload("res://core/learning/skill_learn_policy_result.gd")

var skill_id: StringName


func _init(p_skill_id: StringName = &"") -> void:
	skill_id = p_skill_id


## Missing authored coverage is explicit and never silently allowed.
func evaluate(_student: CharacterStateType) -> PolicyResultType:
	return PolicyResultType.new(PolicyResultType.Status.DEPENDENCY_UNAVAILABLE)
