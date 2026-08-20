class_name VitalityInnerForcePracticePolicy
extends "res://core/training/practice_policy.gd"

## Covers the common daemon/skill practice shape represented by fall-steps.c:
## a max_force learning prerequisite followed by kee/force requirements and costs.
var minimum_maximum_inner_force: int
var required_vitality: int
var vitality_cost: int
var required_inner_force: int
var inner_force_cost: int


func _init(
	p_skill_id: StringName = &"",
	p_minimum_maximum_inner_force: int = 0,
	p_required_vitality: int = 0,
	p_vitality_cost: int = 0,
	p_required_inner_force: int = 0,
	p_inner_force_cost: int = 0,
) -> void:
	super(p_skill_id)
	minimum_maximum_inner_force = p_minimum_maximum_inner_force
	required_vitality = p_required_vitality
	vitality_cost = p_vitality_cost
	required_inner_force = p_required_inner_force
	inner_force_cost = p_inner_force_cost


func valid_learn(character: CharacterStateType) -> bool:
	return character.recovery.inner_force.maximum >= minimum_maximum_inner_force


func practice(character: CharacterStateType) -> bool:
	if character.vitality.current < required_vitality:
		return false
	if character.recovery.inner_force.current < required_inner_force:
		return false
	character.vitality.apply_damage(vitality_cost)
	character.recovery.inner_force.current -= inner_force_cost
	return true
