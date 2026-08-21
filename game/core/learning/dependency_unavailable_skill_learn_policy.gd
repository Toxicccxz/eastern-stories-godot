class_name DependencyUnavailableSkillLearnPolicy
extends "res://core/learning/skill_learn_policy.gd"


func evaluate(_student: CharacterStateType) -> PolicyResultType:
	return PolicyResultType.new(PolicyResultType.Status.DEPENDENCY_UNAVAILABLE)
