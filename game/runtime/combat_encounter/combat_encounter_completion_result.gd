class_name CombatEncounterCompletionResult
extends RefCounted

enum Outcome {
	NO_ACTIVE_ENCOUNTER,
	INVALID_RESULT,
	RESULT_NOT_ALLOWED_FOR_MODE,
	RESOLVING_TRANSITION_FAILED,
	COMPLETION_TRANSITION_FAILED,
	WORLD_THAW_FAILED,
	COMPLETED,
}

var _outcome: int
var _encounter_id: StringName
var _terminal_result: CombatEncounterResult

var outcome: int:
	get: return _outcome
var encounter_id: StringName:
	get: return _encounter_id
var terminal_result: CombatEncounterResult:
	get:
		return (
			null
			if _terminal_result == null
			else _terminal_result.duplicate_snapshot()
		)


func _init(
	p_outcome: int = Outcome.NO_ACTIVE_ENCOUNTER,
	p_encounter_id: StringName = &"",
	p_terminal_result: CombatEncounterResult = null,
) -> void:
	_outcome = p_outcome
	_encounter_id = p_encounter_id
	_terminal_result = (
		null
		if p_terminal_result == null
		else p_terminal_result.duplicate_snapshot()
	)


func succeeded() -> bool:
	return _outcome == Outcome.COMPLETED
