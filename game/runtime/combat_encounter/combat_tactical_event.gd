class_name CombatTacticalEvent
extends RefCounted

enum Kind {
	REQUESTED, ACCEPTED, QUEUED, REPLACED, CANCELLED, REJECTED,
	EXECUTION_STARTED, EXECUTION_REJECTED, RESOLVED,
}

var _order: int
var _kind: int
var _action: CombatQueuedAction
var _reason: int
var _execution: CombatTacticalExecutionResult
var _replacement_request_id: StringName
var _replacement_sequence: int
var replacement_request_id: StringName:
	get: return _replacement_request_id
var replacement_sequence: int:
	get: return _replacement_sequence
var progression_order: int:
	get: return _order
var kind: int:
	get: return _kind
var action: CombatQueuedAction:
	get: return _action.duplicate_snapshot()
var reason: int:
	get: return _reason
var execution: CombatTacticalExecutionResult:
	get: return null if _execution == null else _execution.duplicate_snapshot()


func _init(
	p_order: int,
	p_kind: int,
	p_action: CombatQueuedAction,
	p_reason: int = CombatTacticalResult.Code.ACCEPTED,
	p_execution: CombatTacticalExecutionResult = null,
	p_replacement_request_id: StringName = &"",
	p_replacement_sequence: int = 0,
) -> void:
	_replacement_request_id = p_replacement_request_id
	_replacement_sequence = p_replacement_sequence
	_order = p_order
	_kind = p_kind
	_action = p_action.duplicate_snapshot()
	_reason = p_reason
	_execution = null if p_execution == null else p_execution.duplicate_snapshot()


func duplicate_snapshot() -> CombatTacticalEvent:
	return CombatTacticalEvent.new(
		_order, _kind, _action, _reason, _execution,
		_replacement_request_id, _replacement_sequence,
	)
