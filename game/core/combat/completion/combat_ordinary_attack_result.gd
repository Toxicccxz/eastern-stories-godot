class_name CombatOrdinaryAttackResult
extends RefCounted

enum Outcome {
	INVALID_COMPOSITION_INPUT,
	BASE_ATTACK_INCOMPLETE,
	PROGRESSION_FAILED,
	STATUS_REPORT_BOUNDARY_FAILED,
	FUNCTION_INTERRUPT_POLICY_UNAVAILABLE,
	COMPLETED,
}

enum FailureStage {
	NONE,
	INVALID_INPUT,
	ATTACKER_ID_PROJECTION,
	DEFENDER_ID_PROJECTION,
	ATTACKER_PROGRESSION_PROJECTION,
	DEFENDER_PROGRESSION_PROJECTION,
	ATTACKER_ATTRIBUTE_PROJECTION,
	DEFENDER_ATTRIBUTE_PROJECTION,
	BUSY_PROJECTION,
	BASE_ATTACK,
	PROGRESSION,
	REPORT_STATUS,
	BUSY_INTERRUPT,
}

var _outcome: int
var _failure_stage: int
var _has_base_result: bool
var _base_result: CombatAttackResult
var _progression_result: CombatProgressionResult
var _status_report_result: CombatStatusReportBoundaryResult
var _busy_result: CombatBusyInterruptResult
var _combined_random_upper_bounds: Array[int] = []
var _combined_random_draws: Array[int] = []
var _partial_mutation_preserved: bool

var outcome: int:
	get:
		return _outcome
var failure_stage: int:
	get:
		return _failure_stage
var has_base_result: bool:
	get:
		return _has_base_result
var base_result: CombatAttackResult:
	get:
		return _copy_base(_base_result) if _has_base_result else null
var progression_result: CombatProgressionResult:
	get:
		return _progression_result.duplicate_snapshot()
var status_report_result: CombatStatusReportBoundaryResult:
	get:
		return _status_report_result.duplicate_snapshot()
var busy_result: CombatBusyInterruptResult:
	get:
		return _busy_result.duplicate_snapshot()
var partial_mutation_preserved: bool:
	get:
		return _partial_mutation_preserved


func _init(
	p_outcome: int = Outcome.INVALID_COMPOSITION_INPUT,
	p_failure_stage: int = FailureStage.INVALID_INPUT,
	p_base_result: CombatAttackResult = null,
	p_progression_result: CombatProgressionResult = null,
	p_status_report_result: CombatStatusReportBoundaryResult = null,
	p_busy_result: CombatBusyInterruptResult = null,
	p_partial_mutation_preserved: bool = false,
) -> void:
	_outcome = p_outcome
	_failure_stage = p_failure_stage
	_has_base_result = p_base_result != null
	_base_result = _copy_base(p_base_result) if p_base_result != null else null
	_progression_result = (
		p_progression_result.duplicate_snapshot()
		if p_progression_result != null
		else CombatProgressionResult.new()
	)
	_status_report_result = (
		p_status_report_result.duplicate_snapshot()
		if p_status_report_result != null
		else CombatStatusReportBoundaryResult.new()
	)
	_busy_result = (
		p_busy_result.duplicate_snapshot()
		if p_busy_result != null
		else CombatBusyInterruptResult.new()
	)
	_partial_mutation_preserved = p_partial_mutation_preserved
	if _has_base_result:
		_combined_random_upper_bounds.append_array(
			_base_result.calculation.random_upper_bounds()
		)
		_combined_random_draws.append_array(_base_result.calculation.random_draws())
	_combined_random_upper_bounds.append_array(_progression_result.random_upper_bounds())
	_combined_random_draws.append_array(_progression_result.random_draws())


func combined_random_upper_bounds() -> Array[int]:
	return _combined_random_upper_bounds.duplicate()


func combined_random_draws() -> Array[int]:
	return _combined_random_draws.duplicate()


static func _copy_base(value: CombatAttackResult) -> CombatAttackResult:
	if value == null:
		return null
	return CombatAttackResult.new(
		value.outcome,
		value.failure_stage,
		value.authored_policy_kind,
		value.authored_policy_id,
		value.threshold_candidate,
		value.attacker_id,
		value.defender_id,
		value.action_id,
		value.interrupt_requested,
		value.calculation,
		value.resource_mutation,
		value.standard_force_result,
	)
