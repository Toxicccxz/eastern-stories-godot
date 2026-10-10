class_name VineTraversalPolicy
extends RefCounted

const WATERFALL_THRESHOLD: int = 5

var _waterfall_portal_id: StringName
var _passage_portal_id: StringName
var _below: int = WATERFALL_THRESHOLD


func _init(
	waterfall_portal_id: StringName = &"",
	passage_portal_id: StringName = &"",
	below: int = WATERFALL_THRESHOLD,
) -> void:
	_waterfall_portal_id = waterfall_portal_id
	_passage_portal_id = passage_portal_id
	_below = below


func evaluate(
	effective_dodge: int,
	random_source: WorldInteractionRandomSource,
) -> VineTraversalPolicyResult:
	var result: VineTraversalPolicyResult = VineTraversalPolicyResult.new()
	result._effective_dodge = effective_dodge
	result._random_bound = effective_dodge
	if (
		random_source == null
		or _waterfall_portal_id.is_empty()
		or _passage_portal_id.is_empty()
		or _waterfall_portal_id == _passage_portal_id
	):
		return result
	result._reached_stage = VineTraversalPolicyResult.ReachedStage.RANDOM_DRAW
	# epath2.c: random(dodge) < 5; with no dodge random(0) is 0 (the waterfall).
	result._draw_performed = effective_dodge > 0
	result._draw_value = random_source.legacy_random(effective_dodge)
	if effective_dodge > 0 and (result._draw_value < 0 or result._draw_value >= effective_dodge):
		result._outcome = VineTraversalPolicyResult.Outcome.INVALID_RANDOM_DRAW
		result._invalid_draw = true
		return result

	result._reached_stage = VineTraversalPolicyResult.ReachedStage.BRANCH_SELECTED
	if result._draw_value < _below:
		result._outcome = VineTraversalPolicyResult.Outcome.WATERFALL_BRANCH
		result._selected_branch = VineTraversalPolicyResult.Branch.WATERFALL
		result._selected_portal_id = _waterfall_portal_id
	else:
		result._outcome = VineTraversalPolicyResult.Outcome.PASSAGE_BRANCH
		result._selected_branch = VineTraversalPolicyResult.Branch.PASSAGE
		result._selected_portal_id = _passage_portal_id
	return result
