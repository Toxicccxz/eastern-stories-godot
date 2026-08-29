class_name VineTraversalPolicy
extends RefCounted

const WATERFALL_THRESHOLD: int = 5

var _waterfall_portal_id: StringName
var _passage_portal_id: StringName


func _init(
	waterfall_portal_id: StringName = &"",
	passage_portal_id: StringName = &"",
) -> void:
	_waterfall_portal_id = waterfall_portal_id
	_passage_portal_id = passage_portal_id


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
	result._reached_stage = VineTraversalPolicyResult.ReachedStage.RANDOM_BOUND
	if effective_dodge <= 0:
		result._outcome = (
			VineTraversalPolicyResult.Outcome.LEGACY_RANDOM_BOUND_AMBIGUITY
		)
		result._legacy_ambiguity = true
		return result

	result._reached_stage = VineTraversalPolicyResult.ReachedStage.RANDOM_DRAW
	result._draw_performed = true
	result._draw_value = random_source.next_below(effective_dodge)
	if result._draw_value < 0 or result._draw_value >= effective_dodge:
		result._outcome = VineTraversalPolicyResult.Outcome.INVALID_RANDOM_DRAW
		result._invalid_draw = true
		return result

	result._reached_stage = VineTraversalPolicyResult.ReachedStage.BRANCH_SELECTED
	if result._draw_value < WATERFALL_THRESHOLD:
		result._outcome = VineTraversalPolicyResult.Outcome.WATERFALL_BRANCH
		result._selected_branch = VineTraversalPolicyResult.Branch.WATERFALL
		result._selected_portal_id = _waterfall_portal_id
	else:
		result._outcome = VineTraversalPolicyResult.Outcome.PASSAGE_BRANCH
		result._selected_branch = VineTraversalPolicyResult.Branch.PASSAGE
		result._selected_portal_id = _passage_portal_id
	return result
