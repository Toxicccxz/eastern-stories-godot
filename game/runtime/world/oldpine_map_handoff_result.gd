class_name OldPineMapHandoffResult
extends RefCounted

enum Outcome {
	INVALID_INPUT,
	SESSION_NOT_READY,
	WORLD_SIMULATION_FROZEN,
	PLAYER_NOT_ACTIVE,
	SOURCE_LOCATION_INVALID,
	UNKNOWN_DESTINATION_MAP,
	DESTINATION_LOCATION_INVALID,
	DESTINATION_MARKER_MISSING,
	ALREADY_ACTIVE,
	DESTINATION_PREPARATION_FAILED,
	LOCATION_COMMIT_FAILED,
	DESTINATION_ACTIVATION_FAILED,
	RELATIONSHIP_RECONCILIATION_FAILED,
	COMPLETED,
}

enum FailureStage {
	NONE,
	VALIDATION,
	PREPARATION,
	LOCATION_COMMIT,
	ACTIVATION,
	RECONCILIATION,
}

var _outcome: int = Outcome.INVALID_INPUT
var _failure_stage: int = FailureStage.VALIDATION
var _source_map_id: StringName = &""
var _destination_map_id: StringName = &""
var _destination_zone_id: StringName = &""
var _destination_combat_location_id: StringName = &""
var _destination_spawn_point_id: StringName = &""
var _destination_prepared: bool = false
var _source_detached: bool = false
var _source_restored: bool = false
var _location_committed: bool = false
var _destination_attached: bool = false
var _relationship_reconciled: bool = false

var outcome: int:
	get: return _outcome
var failure_stage: int:
	get: return _failure_stage
var source_map_id: StringName:
	get: return _source_map_id
var destination_map_id: StringName:
	get: return _destination_map_id
var destination_zone_id: StringName:
	get: return _destination_zone_id
var destination_combat_location_id: StringName:
	get: return _destination_combat_location_id
var destination_spawn_point_id: StringName:
	get: return _destination_spawn_point_id
var destination_prepared: bool:
	get: return _destination_prepared
var source_detached: bool:
	get: return _source_detached
var source_restored: bool:
	get: return _source_restored
var location_committed: bool:
	get: return _location_committed
var destination_attached: bool:
	get: return _destination_attached
var relationship_reconciled: bool:
	get: return _relationship_reconciled


func succeeded() -> bool:
	return _outcome == Outcome.COMPLETED


func has_committed_partial_transition() -> bool:
	return _location_committed and not succeeded()
