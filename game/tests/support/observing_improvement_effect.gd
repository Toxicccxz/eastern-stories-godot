class_name ObservingImprovementEffect
extends "res://core/skills/improvement_effects/skill_improvement_effect.gd"

var apply_count: int = 0
var observed_essence_current: int = 0
var observed_potential_spent: int = 0


func apply(
	character: CharacterStateType,
	improvement: SkillImprovementResultType,
) -> EffectResultType:
	apply_count += 1
	observed_essence_current = character.essence.current
	observed_potential_spent = character.progression.potential_spent
	return EffectResultType.new(
		improvement.skill_id,
		EffectResultType.Status.EVALUATED_NO_MUTATION,
	)
