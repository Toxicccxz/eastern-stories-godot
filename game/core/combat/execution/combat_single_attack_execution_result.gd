class_name CombatSingleAttackExecutionResult
extends RefCounted

enum Outcome {
	INVALID_UPSTREAM_RESULT,
	UPSTREAM_NOT_APPLICABLE,
	CALLER_AUTHORITY_MISMATCH,
	ACTION_SELECTION_FAILED,
	SELECTED_ACTION_PROJECTION_MISMATCH,
	ORDINARY_ATTACK_FAILED,
	POST_RELATIONSHIP_FAILED,
	AUTHORED_POST_ACTION_POLICY_UNAVAILABLE,
	COMPLETED_WITHOUT_RIPOSTE,
	RIPOSTE_RANDOM_SOURCE_MISSING,
	INVALID_RIPOSTE_RANDOM_BOUND,
	RIPOSTE_RANDOM_DRAW_OUT_OF_RANGE,
	REVERSE_ATTACK_REQUIRED,
}

enum FailureStage {
	NONE,
	UPSTREAM_FIGHT_DECISION,
	CALLER_AUTHORITY_BINDING,
	ACTION_SELECTION,
	SELECTED_ACTION_PROJECTION,
	ORDINARY_ATTACK,
	POST_RELATIONSHIP,
	POST_ACTION,
	RIPOSTE_RANDOM_BOUND,
	RIPOSTE_RANDOM,
}

enum ReachedStage {
	NONE,
	UPSTREAM_VALIDATED,
	ACTION_SELECTION,
	ACTION_SELECTED,
	ORDINARY_ATTACK,
	ORDINARY_COMPLETED,
	LEGACY_DAMAGE,
	POST_RELATIONSHIP,
	POST_ACTION,
	RIPOSTE_EVALUATION,
	RIPOSTE_GUARD_CLEARED,
	RIPOSTE_RANDOM,
	COMPLETED,
}

var _outcome: int = Outcome.INVALID_UPSTREAM_RESULT
var _failure_stage: int = FailureStage.UPSTREAM_FIGHT_DECISION
var _reached_stage: int = ReachedStage.NONE
var _fight_decision_result: CombatFightDecisionResult
var _action_selection_result: CombatActionSelectionResult
var _ordinary_attack_result: CombatOrdinaryAttackResult
var _post_relationship_result: CombatPostRelationshipResult
var _attacker_id: StringName = &""
var _victim_id: StringName = &""
var _attack_type: int = -1
var _selected_action_id: StringName = &""
var _has_legacy_damage: bool = false
var _legacy_damage: int = 0
var _post_action_reached: bool = false
var _post_action_policy_present: bool = false
var _post_action_policy_id: StringName = &""
var _post_action_weapon_present: bool = false
var _post_action_weapon_id: StringName = &""
var _riposte_evaluation_reached: bool = false
var _victim_guarding_observed: bool = false
var _riposte_eligible: bool = false
var _riposte_guard_clear_attempted: bool = false
var _victim_guarding_before_clear: bool = false
var _victim_guarding_after_clear: bool = false
var _riposte_random_reached: bool = false
var _riposte_random_attempted: bool = false
var _riposte_random_bound: int = 0
var _riposte_random_draw: int = 0
var _riposte_request: CombatRiposteRequest
var _partial_mutation_preserved: bool = false
var _combined_random_upper_bounds: Array[int] = []
var _combined_random_draws: Array[int] = []

var outcome: int:
	get:
		return _outcome
var failure_stage: int:
	get:
		return _failure_stage
var reached_stage: int:
	get:
		return _reached_stage
var fight_decision_result: CombatFightDecisionResult:
	get:
		return (
			_fight_decision_result.duplicate_snapshot()
			if _fight_decision_result != null
			else null
		)
var action_selection_result: CombatActionSelectionResult:
	get:
		return (
			_action_selection_result.duplicate_snapshot()
			if _action_selection_result != null
			else null
		)
var ordinary_attack_result: CombatOrdinaryAttackResult:
	get:
		return _copy_ordinary(_ordinary_attack_result)
var post_relationship_result: CombatPostRelationshipResult:
	get:
		return _copy_post_relationship(_post_relationship_result)
var attacker_id: StringName:
	get:
		return _attacker_id
var victim_id: StringName:
	get:
		return _victim_id
var attack_type: int:
	get:
		return _attack_type
var selected_action_id: StringName:
	get:
		return _selected_action_id
var has_legacy_damage: bool:
	get:
		return _has_legacy_damage
var legacy_damage: int:
	get:
		return _legacy_damage
var post_action_reached: bool:
	get:
		return _post_action_reached
var post_action_policy_present: bool:
	get:
		return _post_action_policy_present
var post_action_policy_id: StringName:
	get:
		return _post_action_policy_id
var post_action_weapon_present: bool:
	get:
		return _post_action_weapon_present
var post_action_weapon_id: StringName:
	get:
		return _post_action_weapon_id
var riposte_evaluation_reached: bool:
	get:
		return _riposte_evaluation_reached
var victim_guarding_observed: bool:
	get:
		return _victim_guarding_observed
var riposte_eligible: bool:
	get:
		return _riposte_eligible
var riposte_guard_clear_attempted: bool:
	get:
		return _riposte_guard_clear_attempted
var victim_guarding_before_clear: bool:
	get:
		return _victim_guarding_before_clear
var victim_guarding_after_clear: bool:
	get:
		return _victim_guarding_after_clear
var riposte_random_reached: bool:
	get:
		return _riposte_random_reached
var riposte_random_attempted: bool:
	get:
		return _riposte_random_attempted
var riposte_random_bound: int:
	get:
		return _riposte_random_bound
var riposte_random_draw: int:
	get:
		return _riposte_random_draw
var has_riposte_request: bool:
	get:
		return _riposte_request != null and _riposte_request.has_request
var riposte_request: CombatRiposteRequest:
	get:
		return (
			_riposte_request.duplicate_snapshot()
			if _riposte_request != null
			else null
		)
var partial_mutation_preserved: bool:
	get:
		return _partial_mutation_preserved


func combined_random_upper_bounds() -> Array[int]:
	return _combined_random_upper_bounds.duplicate()


func combined_random_draws() -> Array[int]:
	return _combined_random_draws.duplicate()


func duplicate_snapshot() -> CombatSingleAttackExecutionResult:
	var copy: CombatSingleAttackExecutionResult = CombatSingleAttackExecutionResult.new()
	copy._outcome = _outcome
	copy._failure_stage = _failure_stage
	copy._reached_stage = _reached_stage
	copy._fight_decision_result = (
		_fight_decision_result.duplicate_snapshot()
		if _fight_decision_result != null
		else null
	)
	copy._action_selection_result = (
		_action_selection_result.duplicate_snapshot()
		if _action_selection_result != null
		else null
	)
	copy._ordinary_attack_result = _copy_ordinary(_ordinary_attack_result)
	copy._post_relationship_result = _copy_post_relationship(
		_post_relationship_result
	)
	copy._attacker_id = _attacker_id
	copy._victim_id = _victim_id
	copy._attack_type = _attack_type
	copy._selected_action_id = _selected_action_id
	copy._has_legacy_damage = _has_legacy_damage
	copy._legacy_damage = _legacy_damage
	copy._post_action_reached = _post_action_reached
	copy._post_action_policy_present = _post_action_policy_present
	copy._post_action_policy_id = _post_action_policy_id
	copy._post_action_weapon_present = _post_action_weapon_present
	copy._post_action_weapon_id = _post_action_weapon_id
	copy._riposte_evaluation_reached = _riposte_evaluation_reached
	copy._victim_guarding_observed = _victim_guarding_observed
	copy._riposte_eligible = _riposte_eligible
	copy._riposte_guard_clear_attempted = _riposte_guard_clear_attempted
	copy._victim_guarding_before_clear = _victim_guarding_before_clear
	copy._victim_guarding_after_clear = _victim_guarding_after_clear
	copy._riposte_random_reached = _riposte_random_reached
	copy._riposte_random_attempted = _riposte_random_attempted
	copy._riposte_random_bound = _riposte_random_bound
	copy._riposte_random_draw = _riposte_random_draw
	copy._riposte_request = (
		_riposte_request.duplicate_snapshot()
		if _riposte_request != null
		else null
	)
	copy._partial_mutation_preserved = _partial_mutation_preserved
	copy._combined_random_upper_bounds = _combined_random_upper_bounds.duplicate()
	copy._combined_random_draws = _combined_random_draws.duplicate()
	return copy


func _rebuild_combined_random_evidence() -> void:
	_combined_random_upper_bounds.clear()
	_combined_random_draws.clear()
	if _fight_decision_result != null:
		_combined_random_upper_bounds.append_array(
			_fight_decision_result.random_upper_bounds()
		)
		_combined_random_draws.append_array(_fight_decision_result.random_draws())
	if _action_selection_result != null:
		_combined_random_upper_bounds.append_array(
			_action_selection_result.random_upper_bounds()
		)
		_combined_random_draws.append_array(
			_action_selection_result.random_draws()
		)
	if _ordinary_attack_result != null:
		_combined_random_upper_bounds.append_array(
			_ordinary_attack_result.combined_random_upper_bounds()
		)
		_combined_random_draws.append_array(
			_ordinary_attack_result.combined_random_draws()
		)
	if _post_relationship_result != null:
		_combined_random_upper_bounds.append_array(
			_post_relationship_result.winner_random_upper_bounds()
		)
		_combined_random_draws.append_array(
			_post_relationship_result.winner_random_draws()
		)
	if _riposte_random_attempted:
		_combined_random_upper_bounds.append(_riposte_random_bound)
		_combined_random_draws.append(_riposte_random_draw)


static func _copy_ordinary(
	value: CombatOrdinaryAttackResult,
) -> CombatOrdinaryAttackResult:
	if value == null:
		return null
	return CombatOrdinaryAttackResult.new(
		value.outcome,
		value.failure_stage,
		value.base_result,
		value.progression_result,
		value.status_report_result,
		value.busy_result,
		value.partial_mutation_preserved,
	)


static func _copy_post_relationship(
	value: CombatPostRelationshipResult,
) -> CombatPostRelationshipResult:
	if value == null:
		return null
	var copy: CombatPostRelationshipResult = CombatPostRelationshipResult.new(
		value.ordinary_attack_result
	)
	copy._outcome = value.outcome
	copy._failure_stage = value.failure_stage
	copy._attacker_id = value.attacker_id
	copy._defender_id = value.defender_id
	copy._requested_damage = value.requested_damage
	copy._positive_hit_gate_matched = value.positive_hit_gate_matched
	copy._attacker_is_lethal = value.attacker_is_lethal
	copy._defender_is_lethal = value.defender_is_lethal
	copy._attacker_is_fighting = value.attacker_is_fighting
	copy._defender_is_fighting = value.defender_is_fighting
	copy._friendly_stop_predicate_matched = value.friendly_stop_predicate_matched
	copy._attacker_removal_attempted = value.attacker_removal_attempted
	copy._attacker_removal_succeeded = value.attacker_removal_succeeded
	copy._defender_removal_attempted = value.defender_removal_attempted
	copy._defender_removal_succeeded = value.defender_removal_succeeded
	copy._winner_selection_reached = value.winner_selection_reached
	copy._winner_random_attempted = value.winner_random_attempted
	copy._winner_random_bound = value.winner_random_bound
	copy._winner_random_draw = value.winner_random_draw
	copy._winner_presentation_index = value.winner_presentation_index
	copy._winner_random_upper_bounds = value.winner_random_upper_bounds()
	copy._winner_random_draws = value.winner_random_draws()
	return copy
