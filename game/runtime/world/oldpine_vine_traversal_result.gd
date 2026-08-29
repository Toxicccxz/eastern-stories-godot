class_name OldPineVineTraversalResult
extends RefCounted

enum Outcome {
	INVALID_INPUT,
	PLAYER_NOT_AVAILABLE,
	PLAYER_NOT_ACTIVE,
	TRANSITION_IN_PROGRESS,
	INVALID_SELECTED_TARGET,
	SOURCE_LOCATION_MISMATCH,
	POLICY_AMBIGUITY,
	POLICY_INVALID_DRAW,
	SAME_MAP_TRAVERSAL_FAILED,
	MAP_HANDOFF_FAILED,
	COMPLETED_WATERFALL,
	COMPLETED_PASSAGE,
}

enum ReachedStage {
	VALIDATION,
	SOURCE_PRESENTATION,
	POLICY,
	BRANCH_PRESENTATION,
	MOVEMENT,
	COMPLETED,
}

var _outcome: int = Outcome.INVALID_INPUT
var _reached_stage: int = ReachedStage.VALIDATION
var _player_id: StringName = &""
var _interaction_id: StringName = &""
var _source_location: WorldLocationState
var _effective_dodge: int = 0
var _policy_result: VineTraversalPolicyResult
var _selected_portal_id: StringName = &""
var _source_presentation_reached: bool = false
var _branch_presentation_reached: bool = false
var _same_map_result: WorldPortalTraversalResult
var _map_handoff_result: OldPineMapHandoffResult
var _movement_location_committed: bool = false

var outcome: int:
	get: return _outcome
var reached_stage: int:
	get: return _reached_stage
var player_id: StringName:
	get: return _player_id
var interaction_id: StringName:
	get: return _interaction_id
var effective_dodge: int:
	get: return _effective_dodge
var policy_result: VineTraversalPolicyResult:
	get: return _policy_result
var selected_portal_id: StringName:
	get: return _selected_portal_id
var source_presentation_reached: bool:
	get: return _source_presentation_reached
var branch_presentation_reached: bool:
	get: return _branch_presentation_reached
var same_map_result: WorldPortalTraversalResult:
	get: return _same_map_result
var map_handoff_result: OldPineMapHandoffResult:
	get: return _map_handoff_result
var movement_location_committed: bool:
	get: return _movement_location_committed


func source_location() -> WorldLocationState:
	return null if _source_location == null else _source_location.duplicate_snapshot()


func succeeded() -> bool:
	return _outcome in [Outcome.COMPLETED_WATERFALL, Outcome.COMPLETED_PASSAGE]


func has_ordered_partial_completion() -> bool:
	return not succeeded() and (
		_source_presentation_reached
		or (_policy_result != null and _policy_result.draw_performed)
		or _branch_presentation_reached
		or _movement_location_committed
	)
