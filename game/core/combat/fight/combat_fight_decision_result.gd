class_name CombatFightDecisionResult
extends RefCounted

enum Outcome {
	INVALID_SOURCE_STATE,
	ATTACKER_NOT_LIVING,
	TARGET_NOT_PERCEIVED,
	QUICK_ATTACK,
	REGULAR_ATTACK,
	ENTERED_GUARDING,
	REMAIN_GUARDING,
	RANDOM_SOURCE_MISSING,
	INVALID_RANDOM_BOUND,
	RANDOM_DRAW_OUT_OF_RANGE,
	RELATIONSHIP_INVARIANT_FAILURE,
}

enum FailureStage {
	NONE,
	INPUT,
	RELATIONSHIP_PROJECTION,
	PERCEPTION_SKILL_PROJECTION,
	PERCEPTION_RANDOM_BOUND,
	PERCEPTION_RANDOM,
	COURAGE_RANDOM_BOUND,
	COURAGE_RANDOM,
	RECIPROCAL_RELATION,
	GUARD_PRESENTATION_RANDOM,
}

enum ReachedStage {
	NONE,
	INPUT_VALIDATED,
	ATTACKER_LIVING,
	VISIBILITY,
	PERCEPTION_RANDOM,
	QUICK_BRANCH,
	COURAGE_RANDOM,
	REGULAR_BRANCH,
	GUARD_BRANCH,
	GUARD_PRESENTATION_RANDOM,
	COMPLETED,
}

var _outcome: int = Outcome.INVALID_SOURCE_STATE
var _failure_stage: int = FailureStage.INPUT
var _reached_stage: int = ReachedStage.NONE
var _attacker_id: StringName = &""
var _victim_id: StringName = &""
var _attack_type: int = -1
var _guarding_before: bool = false
var _guarding_after: bool = false
var _guarding_mutated: bool = false
var _visibility_evaluated: bool = false
var _target_visible: bool = false
var _perception_skill_id: StringName = &""
var _effective_perception: int = 0
var _perception_random_reached: bool = false
var _perception_random_attempted: bool = false
var _perception_random_bound: int = 0
var _perception_random_draw: int = 0
var _perception_comparison_evaluated: bool = false
var _perception_check_passed: bool = false
var _courage_random_reached: bool = false
var _courage_random_attempted: bool = false
var _courage_random_bound: int = 0
var _courage_random_draw: int = 0
var _courage_threshold: int = 0
var _courage_comparison_evaluated: bool = false
var _courage_check_passed: bool = false
var _reciprocal_opponent_existed: bool = false
var _reciprocal_add_attempted: bool = false
var _reciprocal_opponent_added: bool = false
var _guard_random_reached: bool = false
var _guard_random_attempted: bool = false
var _guard_random_bound: int = 0
var _guard_random_draw: int = 0
var _guard_presentation_index: int = -1
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
var attacker_id: StringName:
	get:
		return _attacker_id
var victim_id: StringName:
	get:
		return _victim_id
var attack_type: int:
	get:
		return _attack_type
var has_attack_intent: bool:
	get:
		return CombatAttackType.is_fight_decision_intent(_attack_type)
var guarding_before: bool:
	get:
		return _guarding_before
var guarding_after: bool:
	get:
		return _guarding_after
var guarding_mutated: bool:
	get:
		return _guarding_mutated
var visibility_evaluated: bool:
	get:
		return _visibility_evaluated
var target_visible: bool:
	get:
		return _target_visible
var perception_skill_id: StringName:
	get:
		return _perception_skill_id
var effective_perception: int:
	get:
		return _effective_perception
var perception_random_reached: bool:
	get:
		return _perception_random_reached
var perception_random_attempted: bool:
	get:
		return _perception_random_attempted
var perception_random_bound: int:
	get:
		return _perception_random_bound
var perception_random_draw: int:
	get:
		return _perception_random_draw
var perception_comparison_evaluated: bool:
	get:
		return _perception_comparison_evaluated
var perception_check_passed: bool:
	get:
		return _perception_check_passed
var courage_random_reached: bool:
	get:
		return _courage_random_reached
var courage_random_attempted: bool:
	get:
		return _courage_random_attempted
var courage_random_bound: int:
	get:
		return _courage_random_bound
var courage_random_draw: int:
	get:
		return _courage_random_draw
var courage_threshold: int:
	get:
		return _courage_threshold
var courage_comparison_evaluated: bool:
	get:
		return _courage_comparison_evaluated
var courage_check_passed: bool:
	get:
		return _courage_check_passed
var reciprocal_opponent_existed: bool:
	get:
		return _reciprocal_opponent_existed
var reciprocal_add_attempted: bool:
	get:
		return _reciprocal_add_attempted
var reciprocal_opponent_added: bool:
	get:
		return _reciprocal_opponent_added
var guard_random_reached: bool:
	get:
		return _guard_random_reached
var guard_random_attempted: bool:
	get:
		return _guard_random_attempted
var guard_random_bound: int:
	get:
		return _guard_random_bound
var guard_random_draw: int:
	get:
		return _guard_random_draw
var guard_presentation_index: int:
	get:
		return _guard_presentation_index
var has_guard_presentation_index: bool:
	get:
		return _guard_presentation_index >= 0
var partial_relationship_mutation_preserved: bool:
	get:
		return (
			(_guarding_mutated or _reciprocal_opponent_added)
			and _outcome != Outcome.QUICK_ATTACK
			and _outcome != Outcome.REGULAR_ATTACK
			and _outcome != Outcome.ENTERED_GUARDING
		)


func random_upper_bounds() -> Array[int]:
	return _random_upper_bounds.duplicate()


func random_draws() -> Array[int]:
	return _random_draws.duplicate()


func duplicate_snapshot() -> CombatFightDecisionResult:
	var copy: CombatFightDecisionResult = CombatFightDecisionResult.new()
	copy._outcome = _outcome
	copy._failure_stage = _failure_stage
	copy._reached_stage = _reached_stage
	copy._attacker_id = _attacker_id
	copy._victim_id = _victim_id
	copy._attack_type = _attack_type
	copy._guarding_before = _guarding_before
	copy._guarding_after = _guarding_after
	copy._guarding_mutated = _guarding_mutated
	copy._visibility_evaluated = _visibility_evaluated
	copy._target_visible = _target_visible
	copy._perception_skill_id = _perception_skill_id
	copy._effective_perception = _effective_perception
	copy._perception_random_reached = _perception_random_reached
	copy._perception_random_attempted = _perception_random_attempted
	copy._perception_random_bound = _perception_random_bound
	copy._perception_random_draw = _perception_random_draw
	copy._perception_comparison_evaluated = _perception_comparison_evaluated
	copy._perception_check_passed = _perception_check_passed
	copy._courage_random_reached = _courage_random_reached
	copy._courage_random_attempted = _courage_random_attempted
	copy._courage_random_bound = _courage_random_bound
	copy._courage_random_draw = _courage_random_draw
	copy._courage_threshold = _courage_threshold
	copy._courage_comparison_evaluated = _courage_comparison_evaluated
	copy._courage_check_passed = _courage_check_passed
	copy._reciprocal_opponent_existed = _reciprocal_opponent_existed
	copy._reciprocal_add_attempted = _reciprocal_add_attempted
	copy._reciprocal_opponent_added = _reciprocal_opponent_added
	copy._guard_random_reached = _guard_random_reached
	copy._guard_random_attempted = _guard_random_attempted
	copy._guard_random_bound = _guard_random_bound
	copy._guard_random_draw = _guard_random_draw
	copy._guard_presentation_index = _guard_presentation_index
	copy._random_upper_bounds = _random_upper_bounds.duplicate()
	copy._random_draws = _random_draws.duplicate()
	return copy

