class_name DefaultSkillLearnPolicy
extends "res://core/learning/skill_learn_policy.gd"


## Explicit std/skill.c default valid_learn() == 1 for a known skill.
func evaluate(_student: CharacterStateType) -> PolicyResultType:
	return PolicyResultType.new(PolicyResultType.Status.ALLOWED)
