class_name CombatOpponentSelectionResult
extends RefCounted

enum Outcome {
	INVALID_INPUT,
	INVALID_AVAILABILITY_PROJECTION,
	CLEANUP_INVARIANT_FAILURE,
	NO_OPPONENT,
	RANDOM_SOURCE_MISSING,
	RANDOM_DRAW_OUT_OF_RANGE,
	LAST_OPPONENT_INVARIANT_FAILURE,
	SELECTED,
	REQUESTED_OPPONENT_UNAVAILABLE,
}

enum FailureStage {
	NONE,
	INPUT,
	AVAILABILITY_PROJECTION,
	CLEANUP,
	SELECTION_RANDOM,
	LAST_OPPONENT,
}

var _outcome: int = Outcome.INVALID_INPUT
var _failure_stage: int = FailureStage.INPUT
var _owner_character_id: StringName = &""
var _original_opponent_ids: Array[StringName] = []
var _removed_opponent_ids: Array[StringName] = []
var _retained_opponent_ids: Array[StringName] = []
var _resulting_opponent_ids: Array[StringName] = []
var _last_opponent_before: StringName = &""
var _last_opponent_after: StringName = &""
var _cleanup_completed: bool = false
var _selection_random_reached: bool = false
var _selection_random_attempted: bool = false
var _selection_random_bound: int = 0
var _selection_random_draw: int = 0
var _selected_index: int = -1
var _selected_opponent_id: StringName = &""
var _random_upper_bounds: Array[int] = []
var _random_draws: Array[int] = []

var outcome: int:
	get:
		return _outcome
var failure_stage: int:
	get:
		return _failure_stage
var owner_character_id: StringName:
	get:
		return _owner_character_id
var last_opponent_before: StringName:
	get:
		return _last_opponent_before
var last_opponent_after: StringName:
	get:
		return _last_opponent_after
var cleanup_completed: bool:
	get:
		return _cleanup_completed
var selection_random_reached: bool:
	get:
		return _selection_random_reached
var selection_random_attempted: bool:
	get:
		return _selection_random_attempted
var selection_random_bound: int:
	get:
		return _selection_random_bound
var selection_random_draw: int:
	get:
		return _selection_random_draw
var selected_index: int:
	get:
		return _selected_index
var selected_opponent_id: StringName:
	get:
		return _selected_opponent_id
var has_selected_opponent: bool:
	get:
		return not _selected_opponent_id.is_empty()
var cleanup_mutated: bool:
	get:
		return not _removed_opponent_ids.is_empty()


func original_opponent_ids() -> Array[StringName]:
	return _original_opponent_ids.duplicate()


func removed_opponent_ids() -> Array[StringName]:
	return _removed_opponent_ids.duplicate()


func retained_opponent_ids() -> Array[StringName]:
	return _retained_opponent_ids.duplicate()


func resulting_opponent_ids() -> Array[StringName]:
	return _resulting_opponent_ids.duplicate()


func random_upper_bounds() -> Array[int]:
	return _random_upper_bounds.duplicate()


func random_draws() -> Array[int]:
	return _random_draws.duplicate()


func duplicate_snapshot() -> CombatOpponentSelectionResult:
	var copy: CombatOpponentSelectionResult = CombatOpponentSelectionResult.new()
	copy._outcome = _outcome
	copy._failure_stage = _failure_stage
	copy._owner_character_id = _owner_character_id
	copy._original_opponent_ids = _original_opponent_ids.duplicate()
	copy._removed_opponent_ids = _removed_opponent_ids.duplicate()
	copy._retained_opponent_ids = _retained_opponent_ids.duplicate()
	copy._resulting_opponent_ids = _resulting_opponent_ids.duplicate()
	copy._last_opponent_before = _last_opponent_before
	copy._last_opponent_after = _last_opponent_after
	copy._cleanup_completed = _cleanup_completed
	copy._selection_random_reached = _selection_random_reached
	copy._selection_random_attempted = _selection_random_attempted
	copy._selection_random_bound = _selection_random_bound
	copy._selection_random_draw = _selection_random_draw
	copy._selected_index = _selected_index
	copy._selected_opponent_id = _selected_opponent_id
	copy._random_upper_bounds = _random_upper_bounds.duplicate()
	copy._random_draws = _random_draws.duplicate()
	return copy
