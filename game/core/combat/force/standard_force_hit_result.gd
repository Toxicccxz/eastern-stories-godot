class_name StandardForceHitResult
extends RefCounted

enum Outcome {
	INVALID_SOURCE_STATE,
	NUMERIC_BONUS,
	NO_NUMERIC_EFFECT,
	REFLECTION,
}

enum FailureStage {
	NONE,
	INVALID_INPUT,
	REFLECTION_RANDOM_BOUND,
	REFLECTION_RANDOM_DRAW,
	NORMAL_RANDOM_BOUND,
	NORMAL_RANDOM_DRAW,
}

enum ReachedStage {
	NONE,
	FORCE_DEDUCTED,
	FORCE_DAMAGE_CALCULATED,
	ARMOR_APPLIED,
	REFLECTION_CHECKED,
	REFLECTION_APPLIED,
	NORMAL_RANDOM_CHECKED,
	COMPLETED,
}

var _outcome: int = Outcome.INVALID_SOURCE_STATE
var _failure_stage: int = FailureStage.INVALID_INPUT
var _reached_stage: int = ReachedStage.NONE
var _provider_id: StringName
var _entering_damage_bonus: int
var _factor: int
var _force_before: int
var _force_after_deduction: int
var _force_damage_before_armor: int
var _force_damage_after_armor: int
var _armor_subtraction_reached: bool
var _numeric_contribution: int
var _failed_random_bound: int
var _has_failed_random_bound: bool
var _attacker_threshold_candidate: int = CombatAttackResult.ThresholdCandidate.NOT_OBSERVED
var _reflection_mutation: StandardForceReflectionMutationResult
var _random_upper_bounds: Array[int] = []
var _random_draws: Array[int] = []

var outcome: int:
	get:
		return _outcome
var failure_stage: int:
	get:
		return _failure_stage
var reached_stage: int:
	get:
		return _reached_stage
var provider_id: StringName:
	get:
		return _provider_id
var entering_damage_bonus: int:
	get:
		return _entering_damage_bonus
var factor: int:
	get:
		return _factor
var force_before: int:
	get:
		return _force_before
var force_after_deduction: int:
	get:
		return _force_after_deduction
var force_damage_before_armor: int:
	get:
		return _force_damage_before_armor
var force_damage_after_armor: int:
	get:
		return _force_damage_after_armor
var armor_subtraction_reached: bool:
	get:
		return _armor_subtraction_reached
var numeric_contribution: int:
	get:
		return _numeric_contribution
var failed_random_bound: int:
	get:
		return _failed_random_bound
var has_failed_random_bound: bool:
	get:
		return _has_failed_random_bound
var attacker_threshold_candidate: int:
	get:
		return _attacker_threshold_candidate
var reflection_mutation: StandardForceReflectionMutationResult:
	get:
		return _reflection_mutation.duplicate_snapshot()


func _init() -> void:
	_reflection_mutation = StandardForceReflectionMutationResult.new()


func has_numeric_contribution() -> bool:
	return _outcome == Outcome.NUMERIC_BONUS


func random_upper_bounds() -> Array[int]:
	return _random_upper_bounds.duplicate()


func random_draws() -> Array[int]:
	return _random_draws.duplicate()


func duplicate_snapshot() -> StandardForceHitResult:
	var copy: StandardForceHitResult = StandardForceHitResult.new()
	copy._outcome = _outcome
	copy._failure_stage = _failure_stage
	copy._reached_stage = _reached_stage
	copy._provider_id = _provider_id
	copy._entering_damage_bonus = _entering_damage_bonus
	copy._factor = _factor
	copy._force_before = _force_before
	copy._force_after_deduction = _force_after_deduction
	copy._force_damage_before_armor = _force_damage_before_armor
	copy._force_damage_after_armor = _force_damage_after_armor
	copy._armor_subtraction_reached = _armor_subtraction_reached
	copy._numeric_contribution = _numeric_contribution
	copy._failed_random_bound = _failed_random_bound
	copy._has_failed_random_bound = _has_failed_random_bound
	copy._attacker_threshold_candidate = _attacker_threshold_candidate
	copy._reflection_mutation = _reflection_mutation.duplicate_snapshot()
	copy._random_upper_bounds = _random_upper_bounds.duplicate()
	copy._random_draws = _random_draws.duplicate()
	return copy
