class_name CombatPostRelationshipResult
extends RefCounted

enum Outcome {
	INVALID_INPUT,
	ATTACK_RELATIONSHIP_PROJECTION_MISMATCH,
	PRIOR_ATTACK_INCOMPLETE,
	NOT_POSITIVE_HIT,
	FRIENDLY_STOP_NOT_MATCHED,
	RELATIONSHIP_INVARIANT_FAILURE,
	WINNER_RANDOM_SOURCE_MISSING,
	WINNER_RANDOM_DRAW_OUT_OF_RANGE,
	COMPLETED,
}

enum FailureStage {
	NONE,
	INPUT,
	ATTACK_RELATIONSHIP_PROJECTION,
	PRIOR_ATTACK,
	ATTACKER_RELATION_REMOVAL,
	DEFENDER_RELATION_REMOVAL,
	WINNER_PRESENTATION_SELECTION,
}

var _outcome: int = Outcome.INVALID_INPUT
var _failure_stage: int = FailureStage.INPUT
var _ordinary_attack_result: CombatOrdinaryAttackResult
var _attacker_id: StringName = &""
var _defender_id: StringName = &""
var _requested_damage: int = 0
var _positive_hit_gate_matched: bool = false
var _attacker_is_lethal: bool = false
var _defender_is_lethal: bool = false
var _attacker_is_fighting: bool = false
var _defender_is_fighting: bool = false
var _friendly_stop_predicate_matched: bool = false
var _attacker_removal_attempted: bool = false
var _attacker_removal_succeeded: bool = false
var _defender_removal_attempted: bool = false
var _defender_removal_succeeded: bool = false
var _winner_selection_reached: bool = false
var _winner_random_attempted: bool = false
var _winner_random_bound: int = 0
var _winner_random_draw: int = 0
var _winner_presentation_index: int = -1
var _winner_random_upper_bounds: Array[int] = []
var _winner_random_draws: Array[int] = []

var outcome: int:
	get:
		return _outcome
var failure_stage: int:
	get:
		return _failure_stage
var ordinary_attack_result: CombatOrdinaryAttackResult:
	get:
		return _copy_attack(_ordinary_attack_result)
var attacker_id: StringName:
	get:
		return _attacker_id
var defender_id: StringName:
	get:
		return _defender_id
var requested_damage: int:
	get:
		return _requested_damage
var positive_hit_gate_matched: bool:
	get:
		return _positive_hit_gate_matched
var attacker_is_lethal: bool:
	get:
		return _attacker_is_lethal
var defender_is_lethal: bool:
	get:
		return _defender_is_lethal
var attacker_is_fighting: bool:
	get:
		return _attacker_is_fighting
var defender_is_fighting: bool:
	get:
		return _defender_is_fighting
var friendly_stop_predicate_matched: bool:
	get:
		return _friendly_stop_predicate_matched
var attacker_removal_attempted: bool:
	get:
		return _attacker_removal_attempted
var attacker_removal_succeeded: bool:
	get:
		return _attacker_removal_succeeded
var defender_removal_attempted: bool:
	get:
		return _defender_removal_attempted
var defender_removal_succeeded: bool:
	get:
		return _defender_removal_succeeded
var winner_selection_reached: bool:
	get:
		return _winner_selection_reached
var winner_random_attempted: bool:
	get:
		return _winner_random_attempted
var winner_random_bound: int:
	get:
		return _winner_random_bound
var winner_random_draw: int:
	get:
		return _winner_random_draw
var winner_presentation_index: int:
	get:
		return _winner_presentation_index
var has_winner_presentation_index: bool:
	get:
		return _winner_presentation_index >= 0
var partial_relationship_mutation_preserved: bool:
	get:
		return (
			_attacker_removal_succeeded
			or _defender_removal_succeeded
		) and _outcome != Outcome.COMPLETED


func _init(p_ordinary_attack_result: CombatOrdinaryAttackResult = null) -> void:
	_ordinary_attack_result = _copy_attack(p_ordinary_attack_result)


func winner_random_upper_bounds() -> Array[int]:
	return _winner_random_upper_bounds.duplicate()


func winner_random_draws() -> Array[int]:
	return _winner_random_draws.duplicate()


func combined_random_upper_bounds() -> Array[int]:
	var values: Array[int] = []
	if _ordinary_attack_result != null:
		values.append_array(_ordinary_attack_result.combined_random_upper_bounds())
	values.append_array(_winner_random_upper_bounds)
	return values


func combined_random_draws() -> Array[int]:
	var values: Array[int] = []
	if _ordinary_attack_result != null:
		values.append_array(_ordinary_attack_result.combined_random_draws())
	values.append_array(_winner_random_draws)
	return values


static func _copy_attack(value: CombatOrdinaryAttackResult) -> CombatOrdinaryAttackResult:
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
