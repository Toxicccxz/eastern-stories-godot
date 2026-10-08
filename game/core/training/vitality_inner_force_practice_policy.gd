class_name VitalityInnerForcePracticePolicy
extends "res://core/training/practice_policy.gd"

## Covers the practice_skill() shape represented by fall-steps.c: kee/force
## requirements and costs, after spring-blade.c's weapon check (query_temp("weapon")
## of that skill_type; "" asks for none), necromancy.c's mana and stormdance.c's sen.
## valid_learn() is owned by SkillLearnPolicy.
var required_vitality: int
var vitality_cost: int
var required_inner_force: int
var inner_force_cost: int
var required_weapon_skill_type: StringName
var required_spirit: int = 0
var spirit_cost: int = 0
var required_mana: int = 0
var mana_cost: int = 0


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


## stormdance.c: sen at least `required`, then `cost` of it spent.
func with_spirit(required: int, cost: int) -> VitalityInnerForcePracticePolicy:
	required_spirit = required
	spirit_cost = cost
	return self


## necromancy.c: mana at least `required`, then `cost` of it spent (checked before sen).
func with_mana(required: int, cost: int) -> VitalityInnerForcePracticePolicy:
	required_mana = required
	mana_cost = cost
	return self


func refusal(character: CharacterStateType) -> StringName:
	if refuses_weapon(character):
		return &"weapon"
	if character.vitality.current < required_vitality:
		return &"kee"
	if character.recovery.inner_force.current < required_inner_force:
		return &"force"
	if character.recovery.mana.current < required_mana:
		return &"mana"
	if character.spirit.current < required_spirit:
		return &"sen"
	return &""


func practice(character: CharacterStateType) -> bool:
	if not refusal(character).is_empty():
		return false
	character.vitality.apply_damage(vitality_cost)
	character.recovery.inner_force.current -= inner_force_cost
	character.recovery.mana.current -= mana_cost
	character.spirit.apply_damage(spirit_cost)
	return true
