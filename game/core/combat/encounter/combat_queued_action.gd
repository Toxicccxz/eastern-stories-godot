class_name CombatQueuedAction
extends RefCounted

## No readiness/busy authority: status is projected from the live ActionBusyState.
enum Status { EMPTY, READY, WAITING_FOR_BUSY }

var _request: CombatTacticalRequest
var _sequence: int
var _resolved_target_id: StringName

var request: CombatTacticalRequest:
	get: return null if _request == null else _request.duplicate_snapshot()
var sequence: int:
	get: return _sequence
var resolved_target_id: StringName:
	get: return _resolved_target_id


func _init(
	p_request: CombatTacticalRequest = null,
	p_sequence: int = 0,
	p_resolved_target_id: StringName = &"",
) -> void:
	_request = null if p_request == null else p_request.duplicate_snapshot()
	_sequence = p_sequence
	_resolved_target_id = p_resolved_target_id


func is_valid() -> bool:
	return _request != null and _request.is_valid() and _sequence > 0


func duplicate_snapshot() -> CombatQueuedAction:
	return CombatQueuedAction.new(_request, _sequence, _resolved_target_id)
