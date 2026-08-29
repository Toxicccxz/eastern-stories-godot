class_name VineTraversalPolicyResult
extends RefCounted

enum Outcome {
	INVALID_INPUT,
	WATERFALL_BRANCH,
	PASSAGE_BRANCH,
	LEGACY_RANDOM_BOUND_AMBIGUITY,
	INVALID_RANDOM_DRAW,
}

enum ReachedStage {
	INPUT,
	RANDOM_BOUND,
	RANDOM_DRAW,
	BRANCH_SELECTED,
}

enum Branch {
	NONE,
	WATERFALL,
	PASSAGE,
}

var _outcome: int = Outcome.INVALID_INPUT
var _reached_stage: int = ReachedStage.INPUT
var _effective_dodge: int = 0
var _random_bound: int = 0
var _draw_performed: bool = false
var _draw_value: int = 0
var _selected_branch: int = Branch.NONE
var _selected_portal_id: StringName = &""
var _legacy_ambiguity: bool = false
var _invalid_draw: bool = false

var outcome: int:
	get: return _outcome
var reached_stage: int:
	get: return _reached_stage
var effective_dodge: int:
	get: return _effective_dodge
var random_bound: int:
	get: return _random_bound
var draw_performed: bool:
	get: return _draw_performed
var draw_value: int:
	get: return _draw_value
var selected_branch: int:
	get: return _selected_branch
var selected_portal_id: StringName:
	get: return _selected_portal_id
var legacy_ambiguity: bool:
	get: return _legacy_ambiguity
var invalid_draw: bool:
	get: return _invalid_draw


func branch_selected() -> bool:
	return _selected_branch != Branch.NONE
