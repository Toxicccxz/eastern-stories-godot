class_name CombatSchedulerAdvanceResult
extends RefCounted

enum Outcome {
	INERT,
	INVALID_DELTA,
	APPLICATION_PAUSED,
	WORLD_GATE_MISMATCH,
	AUTHORITY_INVALID,
	ADVANCED_NO_OPPORTUNITY,
	ADVANCED,
}

var _outcome: int
var _cycles_processed: int
var _events: Array[CombatSchedulerEvent] = []

var outcome: int:
	get: return _outcome
var cycles_processed: int:
	get: return _cycles_processed


func _init(
	p_outcome: int = Outcome.INERT,
	p_cycles_processed: int = 0,
	p_events: Array[CombatSchedulerEvent] = [],
) -> void:
	_outcome = p_outcome
	_cycles_processed = p_cycles_processed
	for event: CombatSchedulerEvent in p_events:
		_events.append(null if event == null else event.duplicate_snapshot())


func events() -> Array[CombatSchedulerEvent]:
	var result: Array[CombatSchedulerEvent] = []
	for event: CombatSchedulerEvent in _events:
		result.append(null if event == null else event.duplicate_snapshot())
	return result


func progressed() -> bool:
	return _outcome == Outcome.ADVANCED
