class_name WorldPortalTraversalResult
extends RefCounted

enum Outcome {
	INVALID_INPUT,
	PLAYER_NOT_AVAILABLE,
	PLAYER_NOT_ACTIVE,
	SOURCE_LOCATION_MISMATCH,
	UNSUPPORTED_POLICY,
	DESTINATION_MARKER_MISMATCH,
	DESTINATION_LOCATION_MISMATCH,
	LOGICAL_LOCATION_UPDATE_FAILED,
	COMPLETED,
}

var _outcome: int = Outcome.INVALID_INPUT
var _portal_id: StringName = &""
var _previous_location: WorldLocationState
var _current_location: WorldLocationState
var _physical_position_updated: bool = false
var _logical_location_updated: bool = false

var outcome: int:
	get:
		return _outcome
var portal_id: StringName:
	get:
		return _portal_id
var physical_position_updated: bool:
	get:
		return _physical_position_updated
var logical_location_updated: bool:
	get:
		return _logical_location_updated


func previous_location() -> WorldLocationState:
	return (
		null
		if _previous_location == null
		else _previous_location.duplicate_snapshot()
	)


func current_location() -> WorldLocationState:
	return (
		null
		if _current_location == null
		else _current_location.duplicate_snapshot()
	)


func completed() -> bool:
	return _outcome == Outcome.COMPLETED
