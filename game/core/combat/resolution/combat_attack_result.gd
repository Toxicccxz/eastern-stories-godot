class_name CombatAttackResult
extends RefCounted

enum Outcome {
	DODGE,
	PARRY,
	HIT,
	INVALID_SOURCE_STATE,
	AUTHORED_HIT_POLICY_UNAVAILABLE,
	HIT_POLICY_DISPATCH_AMBIGUOUS,
}

enum FailureStage {
	NONE,
	INVALID_ATTACK_INPUT,
	ATTACK_SKILL_PROJECTION_MISMATCH,
	RANDOM_SOURCE_MISSING,
	INVALID_LIMB_SET,
	LIMB_RANDOM_DRAW,
	DODGE_RANDOM_DRAW,
	PARRY_RANDOM_DRAW,
	APPLY_DAMAGE_RANDOM_BOUND,
	APPLY_DAMAGE_RANDOM_DRAW,
	FORCE_HIT_POLICY,
	MARTIAL_HIT_POLICY,
	WEAPON_HIT_POLICY,
	ATTACKER_HIT_POLICY,
	STRENGTH_RANDOM_DRAW,
	DEFENSE_FACTOR_RANDOM_BOUND,
	DEFENSE_FACTOR_RANDOM_DRAW,
	WOUND_RANDOM_BOUND,
	WOUND_RANDOM_DRAW,
}

enum AuthoredPolicyKind {
	NONE,
	FORCE,
	MARTIAL,
	WEAPON,
	ATTACKER,
}

enum ThresholdCandidate {
	NOT_OBSERVED,
	NONE,
	UNCONSCIOUS,
	DEATH,
}

var _outcome: int
var _failure_stage: int
var _authored_policy_kind: int
var _authored_policy_id: StringName
var _threshold_candidate: int
var _attacker_id: StringName
var _defender_id: StringName
var _action_id: StringName
var _interrupt_requested: bool
var _calculation: CombatAttackCalculation
var _resource_mutation: CombatResourceMutationResult

var outcome: int:
	get:
		return _outcome
var failure_stage: int:
	get:
		return _failure_stage
var authored_policy_kind: int:
	get:
		return _authored_policy_kind
var authored_policy_id: StringName:
	get:
		return _authored_policy_id
var threshold_candidate: int:
	get:
		return _threshold_candidate
var attacker_id: StringName:
	get:
		return _attacker_id
var defender_id: StringName:
	get:
		return _defender_id
var action_id: StringName:
	get:
		return _action_id
var interrupt_requested: bool:
	get:
		return _interrupt_requested
var calculation: CombatAttackCalculation:
	get:
		return _calculation.duplicate_snapshot()
var resource_mutation: CombatResourceMutationResult:
	get:
		return _resource_mutation.duplicate_snapshot()


func _init(
	p_outcome: int = Outcome.INVALID_SOURCE_STATE,
	p_failure_stage: int = FailureStage.INVALID_ATTACK_INPUT,
	p_authored_policy_kind: int = AuthoredPolicyKind.NONE,
	p_authored_policy_id: StringName = &"",
	p_threshold_candidate: int = ThresholdCandidate.NOT_OBSERVED,
	p_attacker_id: StringName = &"",
	p_defender_id: StringName = &"",
	p_action_id: StringName = &"",
	p_interrupt_requested: bool = false,
	p_calculation: CombatAttackCalculation = null,
	p_resource_mutation: CombatResourceMutationResult = null,
) -> void:
	_outcome = p_outcome
	_failure_stage = p_failure_stage
	_authored_policy_kind = p_authored_policy_kind
	_authored_policy_id = p_authored_policy_id
	_threshold_candidate = p_threshold_candidate
	_attacker_id = p_attacker_id
	_defender_id = p_defender_id
	_action_id = p_action_id
	_interrupt_requested = p_interrupt_requested
	_calculation = (
		p_calculation.duplicate_snapshot()
		if p_calculation != null
		else CombatAttackCalculation.new()
	)
	_resource_mutation = (
		p_resource_mutation.duplicate_snapshot()
		if p_resource_mutation != null
		else CombatResourceMutationResult.new()
	)


func succeeded() -> bool:
	return _outcome == Outcome.DODGE or _outcome == Outcome.PARRY or _outcome == Outcome.HIT
