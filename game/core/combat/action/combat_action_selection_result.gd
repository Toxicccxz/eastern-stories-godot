class_name CombatActionSelectionResult
extends RefCounted

enum Outcome {
	SELECTED,
	NO_ACTION_SOURCE,
	MAPPED_ACTION_DATA_UNAVAILABLE,
	PRIMARY_WEAPON_ACTION_DATA_UNAVAILABLE,
	EMPTY_ACTION_SET,
	INVALID_ACTION_SET,
	RANDOM_SOURCE_MISSING,
	RANDOM_DRAW_OUT_OF_RANGE,
}

enum SourceKind {
	NONE,
	MAPPED_MARTIAL,
	PRIMARY_WEAPON,
	DEFAULT_ACTIONS,
}

var _outcome: int
var _source_kind: int
var _selected_action: CombatActionDefinition
var _selected_index: int
var _random_reached: bool
var _random_attempted: bool
var _random_bound: int
var _random_draw: int

var outcome: int:
	get:
		return _outcome
var source_kind: int:
	get:
		return _source_kind
var selected_index: int:
	get:
		return _selected_index
var succeeded: bool:
	get:
		return _outcome == Outcome.SELECTED
var selected_action: CombatActionDefinition:
	get:
		return _selected_action.duplicate_snapshot() if _selected_action != null else null
var random_reached: bool:
	get:
		return _random_reached
var random_attempted: bool:
	get:
		return _random_attempted
var random_bound: int:
	get:
		return _random_bound
var random_draw: int:
	get:
		return _random_draw


func _init(
	p_outcome: int = Outcome.NO_ACTION_SOURCE,
	p_source_kind: int = SourceKind.NONE,
	p_selected_action: CombatActionDefinition = null,
	p_selected_index: int = -1,
	p_random_reached: bool = false,
	p_random_attempted: bool = false,
	p_random_bound: int = 0,
	p_random_draw: int = 0,
) -> void:
	_outcome = p_outcome
	_source_kind = p_source_kind
	_selected_action = (
		p_selected_action.duplicate_snapshot() if p_selected_action != null else null
	)
	_selected_index = p_selected_index
	_random_reached = p_random_reached
	_random_attempted = p_random_attempted
	_random_bound = p_random_bound
	_random_draw = p_random_draw


func random_upper_bounds() -> Array[int]:
	if not _random_attempted:
		return []
	return [_random_bound]


func random_draws() -> Array[int]:
	if not _random_attempted:
		return []
	return [_random_draw]


func duplicate_snapshot() -> CombatActionSelectionResult:
	return CombatActionSelectionResult.new(
		_outcome,
		_source_kind,
		_selected_action,
		_selected_index,
		_random_reached,
		_random_attempted,
		_random_bound,
		_random_draw,
	)
