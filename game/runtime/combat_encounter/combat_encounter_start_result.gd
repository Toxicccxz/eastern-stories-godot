class_name CombatEncounterStartResult
extends RefCounted

enum Outcome {
	INVALID_TRIGGER,
	UNSUPPORTED_CAUSE,
	UNSUPPORTED_MODE,
	SESSION_NOT_READY,
	ENCOUNTER_ALREADY_ACTIVE,
	PARTICIPANT_NOT_FOUND,
	PARTICIPANT_UNAVAILABLE,
	LOCATION_MISMATCH,
	RELATIONSHIP_TOPOLOGY_MISSING,
	ENCOUNTER_INVALID,
	WORLD_FREEZE_FAILED,
	STARTED,
}

var _outcome: int
var _trigger_id: StringName
var _encounter_id: StringName

var outcome: int:
	get: return _outcome
var trigger_id: StringName:
	get: return _trigger_id
var encounter_id: StringName:
	get: return _encounter_id


func _init(
	p_outcome: int = Outcome.INVALID_TRIGGER,
	p_trigger_id: StringName = &"",
	p_encounter_id: StringName = &"",
) -> void:
	_outcome = p_outcome
	_trigger_id = p_trigger_id
	_encounter_id = p_encounter_id


func succeeded() -> bool:
	return _outcome == Outcome.STARTED
