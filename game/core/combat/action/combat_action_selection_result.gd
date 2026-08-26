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


func _init(
	p_outcome: int = Outcome.NO_ACTION_SOURCE,
	p_source_kind: int = SourceKind.NONE,
	p_selected_action: CombatActionDefinition = null,
	p_selected_index: int = -1,
) -> void:
	_outcome = p_outcome
	_source_kind = p_source_kind
	_selected_action = (
		p_selected_action.duplicate_snapshot() if p_selected_action != null else null
	)
	_selected_index = p_selected_index
