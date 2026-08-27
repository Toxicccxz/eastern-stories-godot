class_name CombatSliceOpportunityResult
extends RefCounted

enum Outcome {
	INVALID_INPUT,
	LIFECYCLE_REQUIRED_DEATH,
	LIFECYCLE_REQUIRED_UNCONSCIOUS,
	ACTOR_NOT_AVAILABLE,
	ACTOR_NOT_ACTIVE,
	COMBAT_NOT_AVAILABLE,
	BUSY_ADVANCED,
	NO_OPPONENT,
	OPPONENT_SELECTION_FAILED,
	FIGHT_DECISION_FAILED,
	FIGHT_NO_ACTION,
	ENTERED_GUARDING,
	ATTACK_CHAIN_COMPLETE,
	ATTACK_CHAIN_INCOMPLETE,
}

enum ReachedStage {
	NONE,
	LIFECYCLE_GATE,
	ACTOR_AVAILABILITY,
	BUSY_GATE,
	OPPONENT_SELECTION,
	FIGHT_DECISION,
	FORWARD_ATTACK,
	REVERSE_PROJECTION,
	CHAIN_COMPLETION,
}

var _outcome: int = Outcome.INVALID_INPUT
var _reached_stage: int = ReachedStage.NONE
var _actor_id: StringName = &""
var _life_status_observed: int = CombatSliceLifeStatus.Value.ACTIVE
var _life_threshold_observed: int = CharacterState.LifeThreshold.ACTIVE
var _busy_before: int = 0
var _busy_after: int = 0
var _busy_advance_attempted: bool = false
var _busy_advance_changed: bool = false
var _opponent_selection_result: CombatOpponentSelectionResult
var _fight_decision_result: CombatFightDecisionResult
var _forward_result: CombatSingleAttackExecutionResult
var _chain_result: CombatAttackChainResult
var _reverse_projection_built: bool = false
var _reverse_attacker_experience_at_projection: int = 0

var outcome: int:
	get:
		return _outcome
var reached_stage: int:
	get:
		return _reached_stage
var actor_id: StringName:
	get:
		return _actor_id
var life_status_observed: int:
	get:
		return _life_status_observed
var life_threshold_observed: int:
	get:
		return _life_threshold_observed
var busy_before: int:
	get:
		return _busy_before
var busy_after: int:
	get:
		return _busy_after
var busy_advance_attempted: bool:
	get:
		return _busy_advance_attempted
var busy_advance_changed: bool:
	get:
		return _busy_advance_changed
var opponent_selection_result: CombatOpponentSelectionResult:
	get:
		return (
			_opponent_selection_result.duplicate_snapshot()
			if _opponent_selection_result != null
			else null
		)
var fight_decision_result: CombatFightDecisionResult:
	get:
		return (
			_fight_decision_result.duplicate_snapshot()
			if _fight_decision_result != null
			else null
		)
var forward_result: CombatSingleAttackExecutionResult:
	get:
		return _forward_result.duplicate_snapshot() if _forward_result != null else null
var chain_result: CombatAttackChainResult:
	get:
		return _chain_result.duplicate_snapshot() if _chain_result != null else null
var reverse_projection_built: bool:
	get:
		return _reverse_projection_built
var reverse_attacker_experience_at_projection: int:
	get:
		return _reverse_attacker_experience_at_projection


func random_upper_bounds() -> Array[int]:
	var values: Array[int] = []
	if _opponent_selection_result != null:
		values.append_array(_opponent_selection_result.random_upper_bounds())
	if _chain_result != null:
		values.append_array(_chain_result.combined_random_upper_bounds())
	elif _forward_result != null:
		values.append_array(_forward_result.combined_random_upper_bounds())
	elif _fight_decision_result != null:
		values.append_array(_fight_decision_result.random_upper_bounds())
	return values


func random_draws() -> Array[int]:
	var values: Array[int] = []
	if _opponent_selection_result != null:
		values.append_array(_opponent_selection_result.random_draws())
	if _chain_result != null:
		values.append_array(_chain_result.combined_random_draws())
	elif _forward_result != null:
		values.append_array(_forward_result.combined_random_draws())
	elif _fight_decision_result != null:
		values.append_array(_fight_decision_result.random_draws())
	return values


func duplicate_snapshot() -> CombatSliceOpportunityResult:
	var copy: CombatSliceOpportunityResult = CombatSliceOpportunityResult.new()
	copy._outcome = _outcome
	copy._reached_stage = _reached_stage
	copy._actor_id = _actor_id
	copy._life_status_observed = _life_status_observed
	copy._life_threshold_observed = _life_threshold_observed
	copy._busy_before = _busy_before
	copy._busy_after = _busy_after
	copy._busy_advance_attempted = _busy_advance_attempted
	copy._busy_advance_changed = _busy_advance_changed
	copy._opponent_selection_result = (
		_opponent_selection_result.duplicate_snapshot()
		if _opponent_selection_result != null
		else null
	)
	copy._fight_decision_result = (
		_fight_decision_result.duplicate_snapshot()
		if _fight_decision_result != null
		else null
	)
	copy._forward_result = (
		_forward_result.duplicate_snapshot() if _forward_result != null else null
	)
	copy._chain_result = (
		_chain_result.duplicate_snapshot() if _chain_result != null else null
	)
	copy._reverse_projection_built = _reverse_projection_built
	copy._reverse_attacker_experience_at_projection = (
		_reverse_attacker_experience_at_projection
	)
	return copy
