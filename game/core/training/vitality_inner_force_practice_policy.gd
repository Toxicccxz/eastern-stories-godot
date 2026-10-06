class_name VitalityInnerForcePracticePolicy
extends "res://core/training/practice_policy.gd"

## Covers the practice_skill() shape represented by fall-steps.c: kee/force
## requirements and costs, after spring-blade.c's weapon check (query_temp("weapon")
## of that skill_type; "" asks for none). valid_learn() is owned by SkillLearnPolicy.
var required_vitality: int
var vitality_cost: int
var required_inner_force: int
var inner_force_cost: int
var required_weapon_skill_type: StringName


func _init(
	p_skill_id: StringName = &"",
	p_required_vitality: int = 0,
	p_vitality_cost: int = 0,
	p_required_inner_force: int = 0,
	p_inner_force_cost: int = 0,
	p_required_weapon_skill_type: StringName = &"",
) -> void:
	super(p_skill_id)
	required_vitality = p_required_vitality
	vitality_cost = p_vitality_cost
	required_inner_force = p_required_inner_force
	inner_force_cost = p_inner_force_cost
	required_weapon_skill_type = p_required_weapon_skill_type


func refuses_weapon(character: CharacterStateType) -> bool:
	return not required_weapon_skill_type.is_empty() and (
		character.equipment.is_primary_hand_empty()
		or character.equipment.primary_weapon_skill_type() != required_weapon_skill_type
	)


func practice(character: CharacterStateType) -> bool:
	if refuses_weapon(character):
		return false
	if character.vitality.current < required_vitality:
		return false
	if character.recovery.inner_force.current < required_inner_force:
		return false
	character.vitality.apply_damage(vitality_cost)
	character.recovery.inner_force.current -= inner_force_cost
	return true
