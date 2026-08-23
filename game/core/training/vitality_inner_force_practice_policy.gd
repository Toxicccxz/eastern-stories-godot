class_name VitalityInnerForcePracticePolicy
extends "res://core/training/practice_policy.gd"

## Covers the practice_skill() shape represented by fall-steps.c: kee/force
## requirements and costs. valid_learn() is owned by SkillLearnPolicy.
var required_vitality: int
var vitality_cost: int
var required_inner_force: int
var inner_force_cost: int


func _init(
	p_skill_id: StringName = &"",
	p_required_vitality: int = 0,
	p_vitality_cost: int = 0,
	p_required_inner_force: int = 0,
	p_inner_force_cost: int = 0,
) -> void:
	super(p_skill_id)
	required_vitality = p_required_vitality
	vitality_cost = p_vitality_cost
	required_inner_force = p_required_inner_force
	inner_force_cost = p_inner_force_cost

func practice(character: CharacterStateType) -> bool:
	if character.vitality.current < required_vitality:
		return false
	if character.recovery.inner_force.current < required_inner_force:
		return false
	character.vitality.apply_damage(vitality_cost)
	character.recovery.inner_force.current -= inner_force_cost
	return true
