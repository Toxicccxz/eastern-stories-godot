class_name CombatAttackChainResult
extends RefCounted

enum Outcome {
	FORWARD_INCOMPLETE,
	FORWARD_COMPLETE_NO_REVERSE,
	REVERSE_REQUEST_INCOHERENT,
	REVERSE_CONTEXT_INVALID,
	REVERSE_ACTION_SELECTION_FAILED,
	REVERSE_ACTION_PROJECTION_MISMATCH,
	REVERSE_ORDINARY_FAILED,
	REVERSE_RELATIONSHIP_FAILED,
	REVERSE_POST_ACTION_UNAVAILABLE,
	REVERSE_COMPLETE,
}

enum FailureStage {
	NONE,
	FORWARD_RESULT,
	REVERSE_REQUEST,
	REVERSE_CONTEXT,
	REVERSE_ACTION_SELECTION,
	REVERSE_ACTION_PROJECTION,
	REVERSE_ORDINARY,
	REVERSE_RELATIONSHIP,
	REVERSE_POST_ACTION,
}

enum ReachedStage {
	NONE,
	FORWARD_INSPECTED,
	FORWARD_COMPLETE,
	REVERSE_REQUEST_VALIDATED,
	REVERSE_CONTEXT_VALIDATED,
	REVERSE_ACTION_SELECTION,
	REVERSE_ACTION_SELECTED,
	REVERSE_ORDINARY,
	REVERSE_ORDINARY_COMPLETED,
	REVERSE_LEGACY_DAMAGE,
	REVERSE_RELATIONSHIP,
	REVERSE_POST_ACTION,
	COMPLETED,
}

var _outcome: int = Outcome.FORWARD_INCOMPLETE
var _failure_stage: int = FailureStage.FORWARD_RESULT
var _reached_stage: int = ReachedStage.NONE
var _forward_result: CombatSingleAttackExecutionResult
var _reverse_required: bool = false
var _reverse_request: CombatRiposteRequest
var _reverse_execution_reached: bool = false
var _reverse_attacker_id: StringName = &""
var _reverse_victim_id: StringName = &""
var _reverse_attack_type: int = -1
var _reverse_action_selection_result: CombatActionSelectionResult
var _reverse_ordinary_result: CombatOrdinaryAttackResult
var _reverse_relationship_result: CombatPostRelationshipResult
var _reverse_selected_action_id: StringName = &""
var _has_reverse_legacy_damage: bool = false
var _reverse_legacy_damage: int = 0
var _reverse_post_action_reached: bool = false
var _reverse_post_action_policy_present: bool = false
var _reverse_post_action_policy_id: StringName = &""
var _reverse_weapon_present: bool = false
var _reverse_weapon_instance_id: StringName = &""
var _reverse_weapon_profile_id: StringName = &""
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
var forward_result: CombatSingleAttackExecutionResult:
	get:
		return _forward_result.duplicate_snapshot() if _forward_result != null else null
var reverse_required: bool:
	get:
		return _reverse_required
var reverse_request: CombatRiposteRequest:
	get:
		return _reverse_request.duplicate_snapshot() if _reverse_request != null else null
var reverse_execution_reached: bool:
	get:
		return _reverse_execution_reached
var reverse_attacker_id: StringName:
	get:
		return _reverse_attacker_id
var reverse_victim_id: StringName:
	get:
		return _reverse_victim_id
var reverse_attack_type: int:
	get:
		return _reverse_attack_type
var reverse_action_selection_result: CombatActionSelectionResult:
	get:
		return (
			_reverse_action_selection_result.duplicate_snapshot()
			if _reverse_action_selection_result != null
			else null
		)
var reverse_ordinary_result: CombatOrdinaryAttackResult:
	get:
		return _copy_ordinary(_reverse_ordinary_result)
var reverse_relationship_result: CombatPostRelationshipResult:
	get:
		return _copy_relationship(_reverse_relationship_result)
var reverse_selected_action_id: StringName:
	get:
		return _reverse_selected_action_id
var has_reverse_legacy_damage: bool:
	get:
		return _has_reverse_legacy_damage
var reverse_legacy_damage: int:
	get:
		return _reverse_legacy_damage
var reverse_post_action_reached: bool:
	get:
		return _reverse_post_action_reached
var reverse_post_action_policy_present: bool:
	get:
		return _reverse_post_action_policy_present
var reverse_post_action_policy_id: StringName:
	get:
		return _reverse_post_action_policy_id
var reverse_weapon_present: bool:
	get:
		return _reverse_weapon_present
var reverse_weapon_instance_id: StringName:
	get:
		return _reverse_weapon_instance_id
var reverse_weapon_profile_id: StringName:
	get:
		return _reverse_weapon_profile_id
var partial_mutation_preserved: bool:
	get:
		return _partial_mutation_preserved


func combined_random_upper_bounds() -> Array[int]:
	return _combined_random_upper_bounds.duplicate()


func combined_random_draws() -> Array[int]:
	return _combined_random_draws.duplicate()


func duplicate_snapshot() -> CombatAttackChainResult:
	var copy: CombatAttackChainResult = CombatAttackChainResult.new()
	copy._outcome = _outcome
	copy._failure_stage = _failure_stage
	copy._reached_stage = _reached_stage
	copy._forward_result = (
		_forward_result.duplicate_snapshot() if _forward_result != null else null
	)
	copy._reverse_required = _reverse_required
	copy._reverse_request = (
		_reverse_request.duplicate_snapshot() if _reverse_request != null else null
	)
	copy._reverse_execution_reached = _reverse_execution_reached
	copy._reverse_attacker_id = _reverse_attacker_id
	copy._reverse_victim_id = _reverse_victim_id
	copy._reverse_attack_type = _reverse_attack_type
	copy._reverse_action_selection_result = (
		_reverse_action_selection_result.duplicate_snapshot()
		if _reverse_action_selection_result != null
		else null
	)
	copy._reverse_ordinary_result = _copy_ordinary(_reverse_ordinary_result)
	copy._reverse_relationship_result = _copy_relationship(
		_reverse_relationship_result
	)
	copy._reverse_selected_action_id = _reverse_selected_action_id
	copy._has_reverse_legacy_damage = _has_reverse_legacy_damage
	copy._reverse_legacy_damage = _reverse_legacy_damage
	copy._reverse_post_action_reached = _reverse_post_action_reached
	copy._reverse_post_action_policy_present = _reverse_post_action_policy_present
	copy._reverse_post_action_policy_id = _reverse_post_action_policy_id
	copy._reverse_weapon_present = _reverse_weapon_present
	copy._reverse_weapon_instance_id = _reverse_weapon_instance_id
	copy._reverse_weapon_profile_id = _reverse_weapon_profile_id
	copy._partial_mutation_preserved = _partial_mutation_preserved
	copy._combined_random_upper_bounds = _combined_random_upper_bounds.duplicate()
	copy._combined_random_draws = _combined_random_draws.duplicate()
	return copy


func _rebuild_combined_random_evidence() -> void:
	_combined_random_upper_bounds.clear()
	_combined_random_draws.clear()
	if _forward_result != null:
		_combined_random_upper_bounds.append_array(
			_forward_result.combined_random_upper_bounds()
		)
		_combined_random_draws.append_array(_forward_result.combined_random_draws())
	if _reverse_action_selection_result != null:
		_combined_random_upper_bounds.append_array(
			_reverse_action_selection_result.random_upper_bounds()
		)
		_combined_random_draws.append_array(
			_reverse_action_selection_result.random_draws()
		)
	if _reverse_ordinary_result != null:
		_combined_random_upper_bounds.append_array(
			_reverse_ordinary_result.combined_random_upper_bounds()
		)
		_combined_random_draws.append_array(
			_reverse_ordinary_result.combined_random_draws()
		)
	if _reverse_relationship_result != null:
		_combined_random_upper_bounds.append_array(
			_reverse_relationship_result.winner_random_upper_bounds()
		)
		_combined_random_draws.append_array(
			_reverse_relationship_result.winner_random_draws()
		)


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


static func _copy_relationship(
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
