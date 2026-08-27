class_name CombatProgressionResult
extends RefCounted

enum Branch {
	NONE,
	DODGE,
	PARRY,
	HIT,
}

enum Outcome {
	NOT_REACHED,
	COMPLETED,
	INVALID_SOURCE_STATE,
}

enum FailureStage {
	NONE,
	INVALID_INPUT,
	DODGE_DEFENDER_GIN_DIVISION,
	DODGE_DEFENDER_RANDOM_BOUND,
	DODGE_DEFENDER_RANDOM_DRAW,
	DODGE_ATTACKER_EXP_RANDOM_BOUND,
	DODGE_ATTACKER_EXP_RANDOM_DRAW,
	DODGE_ATTACKER_SKILL_RANDOM_BOUND,
	DODGE_ATTACKER_SKILL_RANDOM_DRAW,
	DODGE_ATTACKER_SKILL_DEFINITION,
	PARRY_DEFENDER_GIN_DIVISION,
	PARRY_DEFENDER_RANDOM_BOUND,
	PARRY_DEFENDER_RANDOM_DRAW,
	HIT_ATTACKER_GIN_DIVISION,
	HIT_ATTACKER_RANDOM_BOUND,
	HIT_ATTACKER_RANDOM_DRAW,
	HIT_ATTACKER_SKILL_DEFINITION,
	HIT_DEFENDER_RANDOM_BOUND,
	HIT_DEFENDER_RANDOM_DRAW,
}

enum ReachedStage {
	NONE,
	BRANCH_SELECTED,
	DEFENDER_CONDITION_EVALUATED,
	DEFENDER_RANDOM_EVALUATED,
	DEFENDER_MUTATION_COMPLETED,
	ATTACKER_CONDITION_EVALUATED,
	ATTACKER_FIRST_RANDOM_EVALUATED,
	ATTACKER_SECOND_RANDOM_EVALUATED,
	ATTACKER_MUTATION_COMPLETED,
	HIT_OUTER_CONDITION_EVALUATED,
	HIT_ATTACKER_CONDITION_EVALUATED,
	HIT_ATTACKER_RANDOM_EVALUATED,
	HIT_ATTACKER_MUTATION_COMPLETED,
	HIT_DEFENDER_RANDOM_EVALUATED,
	HIT_DEFENDER_MUTATION_COMPLETED,
	COMPLETED,
}

var _branch: int = Branch.NONE
var _outcome: int = Outcome.NOT_REACHED
var _failure_stage: int = FailureStage.NONE
var _reached_stage: int = ReachedStage.NONE

var _outer_condition_evaluated: bool = false
var _outer_condition_matched: bool = false
var _attacker_condition_evaluated: bool = false
var _attacker_condition_matched: bool = false
var _defender_condition_evaluated: bool = false
var _defender_condition_matched: bool = false
var _attacker_first_roll_performed: bool = false
var _attacker_first_roll_succeeded: bool = false
var _attacker_second_roll_performed: bool = false
var _defender_roll_performed: bool = false
var _defender_roll_succeeded: bool = false

var _attacker_combat_experience_before: int = 0
var _attacker_combat_experience_after: int = 0
var _defender_combat_experience_before: int = 0
var _defender_combat_experience_after: int = 0
var _attacker_potential_before: int = 0
var _attacker_potential_after: int = 0
var _defender_potential_before: int = 0
var _defender_potential_after: int = 0

var _attacker_skill_improvement_attempted: bool = false
var _attacker_skill_definition_checked: bool = false
var _attacker_skill_definition_available: bool = false
var _defender_skill_improvement_attempted: bool = false
var _attacker_skill_improvement: SkillImprovementResult
var _defender_skill_improvement: SkillImprovementResult
var _attacker_skill_effect: SkillImprovementEffectResult
var _defender_skill_effect: SkillImprovementEffectResult
var _has_failed_random_bound: bool = false
var _failed_random_bound: int = 0
var _random_upper_bounds: Array[int] = []
var _random_draws: Array[int] = []

var branch: int:
	get:
		return _branch
var outcome: int:
	get:
		return _outcome
var failure_stage: int:
	get:
		return _failure_stage
var reached_stage: int:
	get:
		return _reached_stage
var outer_condition_evaluated: bool:
	get:
		return _outer_condition_evaluated
var outer_condition_matched: bool:
	get:
		return _outer_condition_matched
var attacker_condition_evaluated: bool:
	get:
		return _attacker_condition_evaluated
var attacker_condition_matched: bool:
	get:
		return _attacker_condition_matched
var defender_condition_evaluated: bool:
	get:
		return _defender_condition_evaluated
var defender_condition_matched: bool:
	get:
		return _defender_condition_matched
var attacker_first_roll_performed: bool:
	get:
		return _attacker_first_roll_performed
var attacker_first_roll_succeeded: bool:
	get:
		return _attacker_first_roll_succeeded
var attacker_second_roll_performed: bool:
	get:
		return _attacker_second_roll_performed
var defender_roll_performed: bool:
	get:
		return _defender_roll_performed
var defender_roll_succeeded: bool:
	get:
		return _defender_roll_succeeded
var attacker_combat_experience_before: int:
	get:
		return _attacker_combat_experience_before
var attacker_combat_experience_after: int:
	get:
		return _attacker_combat_experience_after
var defender_combat_experience_before: int:
	get:
		return _defender_combat_experience_before
var defender_combat_experience_after: int:
	get:
		return _defender_combat_experience_after
var attacker_potential_before: int:
	get:
		return _attacker_potential_before
var attacker_potential_after: int:
	get:
		return _attacker_potential_after
var defender_potential_before: int:
	get:
		return _defender_potential_before
var defender_potential_after: int:
	get:
		return _defender_potential_after
var attacker_skill_improvement_attempted: bool:
	get:
		return _attacker_skill_improvement_attempted
var attacker_skill_definition_checked: bool:
	get:
		return _attacker_skill_definition_checked
var attacker_skill_definition_available: bool:
	get:
		return _attacker_skill_definition_available
var defender_skill_improvement_attempted: bool:
	get:
		return _defender_skill_improvement_attempted
var attacker_skill_improvement: SkillImprovementResult:
	get:
		return _copy_improvement(_attacker_skill_improvement)
var defender_skill_improvement: SkillImprovementResult:
	get:
		return _copy_improvement(_defender_skill_improvement)
var attacker_skill_effect: SkillImprovementEffectResult:
	get:
		return _copy_effect(_attacker_skill_effect)
var defender_skill_effect: SkillImprovementEffectResult:
	get:
		return _copy_effect(_defender_skill_effect)
var has_failed_random_bound: bool:
	get:
		return _has_failed_random_bound
var failed_random_bound: int:
	get:
		return _failed_random_bound


func random_upper_bounds() -> Array[int]:
	return _random_upper_bounds.duplicate()


func random_draws() -> Array[int]:
	return _random_draws.duplicate()


func attacker_combat_experience_incremented() -> bool:
	return _attacker_combat_experience_after > _attacker_combat_experience_before


func defender_combat_experience_incremented() -> bool:
	return _defender_combat_experience_after > _defender_combat_experience_before


func attacker_potential_incremented() -> bool:
	return _attacker_potential_after > _attacker_potential_before


func defender_potential_incremented() -> bool:
	return _defender_potential_after > _defender_potential_before


func duplicate_snapshot() -> CombatProgressionResult:
	var copy: CombatProgressionResult = CombatProgressionResult.new()
	copy._branch = _branch
	copy._outcome = _outcome
	copy._failure_stage = _failure_stage
	copy._reached_stage = _reached_stage
	copy._outer_condition_evaluated = _outer_condition_evaluated
	copy._outer_condition_matched = _outer_condition_matched
	copy._attacker_condition_evaluated = _attacker_condition_evaluated
	copy._attacker_condition_matched = _attacker_condition_matched
	copy._defender_condition_evaluated = _defender_condition_evaluated
	copy._defender_condition_matched = _defender_condition_matched
	copy._attacker_first_roll_performed = _attacker_first_roll_performed
	copy._attacker_first_roll_succeeded = _attacker_first_roll_succeeded
	copy._attacker_second_roll_performed = _attacker_second_roll_performed
	copy._defender_roll_performed = _defender_roll_performed
	copy._defender_roll_succeeded = _defender_roll_succeeded
	copy._attacker_combat_experience_before = _attacker_combat_experience_before
	copy._attacker_combat_experience_after = _attacker_combat_experience_after
	copy._defender_combat_experience_before = _defender_combat_experience_before
	copy._defender_combat_experience_after = _defender_combat_experience_after
	copy._attacker_potential_before = _attacker_potential_before
	copy._attacker_potential_after = _attacker_potential_after
	copy._defender_potential_before = _defender_potential_before
	copy._defender_potential_after = _defender_potential_after
	copy._attacker_skill_improvement_attempted = _attacker_skill_improvement_attempted
	copy._attacker_skill_definition_checked = _attacker_skill_definition_checked
	copy._attacker_skill_definition_available = _attacker_skill_definition_available
	copy._defender_skill_improvement_attempted = _defender_skill_improvement_attempted
	copy._attacker_skill_improvement = _copy_improvement(_attacker_skill_improvement)
	copy._defender_skill_improvement = _copy_improvement(_defender_skill_improvement)
	copy._attacker_skill_effect = _copy_effect(_attacker_skill_effect)
	copy._defender_skill_effect = _copy_effect(_defender_skill_effect)
	copy._has_failed_random_bound = _has_failed_random_bound
	copy._failed_random_bound = _failed_random_bound
	copy._random_upper_bounds = _random_upper_bounds.duplicate()
	copy._random_draws = _random_draws.duplicate()
	return copy


static func _copy_improvement(value: SkillImprovementResult) -> SkillImprovementResult:
	if value == null:
		return null
	return SkillImprovementResult.new(
		value.skill_id,
		value.previous_level,
		value.current_level,
		value.leveled_up,
		value.learned_before,
		value.learned_after,
	)


static func _copy_effect(value: SkillImprovementEffectResult) -> SkillImprovementEffectResult:
	if value == null:
		return null
	return SkillImprovementEffectResult.new(
		value.skill_id,
		value.status,
		value.mutation,
		value.mutation_amount,
		value.previous_value,
		value.current_value,
	)
