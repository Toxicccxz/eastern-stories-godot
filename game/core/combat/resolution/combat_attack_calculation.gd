class_name CombatAttackCalculation
extends RefCounted

enum ReachedStage {
	NONE,
	LIMB_SELECTED,
	ATTACK_AND_DODGE_POWER_READY,
	DODGE_EVALUATED,
	PARRY_POWER_READY,
	PARRY_EVALUATED,
	APPLY_DAMAGE_PROJECTED,
	BASE_DAMAGE_READY,
	ACTION_DAMAGE_READY,
	INITIAL_STRENGTH_READY,
	FORCE_HOOK_PASSED,
	ACTION_FORCE_READY,
	MARTIAL_HOOK_PASSED,
	TERMINAL_HOOK_PASSED,
	STRENGTH_DAMAGE_READY,
	DEFENSE_LOOP_COMPLETED,
	DAMAGE_APPLIED,
	WOUND_ELIGIBILITY_EVALUATED,
	WOUND_EVALUATED,
	THRESHOLD_OBSERVED,
}

var _reached_stage: int = ReachedStage.NONE
var _selected_limb: StringName
var _attack_skill_type: StringName
var _attack_power: int
var _dodge_power: int
var _parry_power: int
var _base_apply_damage: int
var _damage_value: int
var _initial_strength_bonus: int
var _final_strength_bonus: int
var _requested_damage: int
var _armor: int
var _defense_iterations: int
var _defense_factor_at_exit: int
var _wound_eligible: bool
var _wound_roll_performed: bool
var _wound_amount: int
var _random_upper_bounds: Array[int] = []
var _random_draws: Array[int] = []

var selected_limb: StringName:
	get:
		return _selected_limb
var attack_skill_type: StringName:
	get:
		return _attack_skill_type
var attack_power: int:
	get:
		return _attack_power
var dodge_power: int:
	get:
		return _dodge_power
var parry_power: int:
	get:
		return _parry_power
var base_apply_damage: int:
	get:
		return _base_apply_damage
var damage_value: int:
	get:
		return _damage_value
var initial_strength_bonus: int:
	get:
		return _initial_strength_bonus
var final_strength_bonus: int:
	get:
		return _final_strength_bonus
var requested_damage: int:
	get:
		return _requested_damage
var armor: int:
	get:
		return _armor
var defense_iterations: int:
	get:
		return _defense_iterations
var defense_factor_at_exit: int:
	get:
		return _defense_factor_at_exit
var wound_eligible: bool:
	get:
		return _wound_eligible
var wound_roll_performed: bool:
	get:
		return _wound_roll_performed
var wound_amount: int:
	get:
		return _wound_amount
var reached_stage: int:
	get:
		return _reached_stage


func has_reached(stage: int) -> bool:
	if stage == ReachedStage.WOUND_EVALUATED:
		return _wound_roll_performed
	return stage >= ReachedStage.NONE and stage <= _reached_stage


func random_upper_bounds() -> Array[int]:
	return _random_upper_bounds.duplicate()


func random_draws() -> Array[int]:
	return _random_draws.duplicate()


func duplicate_snapshot() -> CombatAttackCalculation:
	var copy: CombatAttackCalculation = CombatAttackCalculation.new()
	copy._reached_stage = _reached_stage
	copy._selected_limb = _selected_limb
	copy._attack_skill_type = _attack_skill_type
	copy._attack_power = _attack_power
	copy._dodge_power = _dodge_power
	copy._parry_power = _parry_power
	copy._base_apply_damage = _base_apply_damage
	copy._damage_value = _damage_value
	copy._initial_strength_bonus = _initial_strength_bonus
	copy._final_strength_bonus = _final_strength_bonus
	copy._requested_damage = _requested_damage
	copy._armor = _armor
	copy._defense_iterations = _defense_iterations
	copy._defense_factor_at_exit = _defense_factor_at_exit
	copy._wound_eligible = _wound_eligible
	copy._wound_roll_performed = _wound_roll_performed
	copy._wound_amount = _wound_amount
	copy._random_upper_bounds = _random_upper_bounds.duplicate()
	copy._random_draws = _random_draws.duplicate()
	return copy
