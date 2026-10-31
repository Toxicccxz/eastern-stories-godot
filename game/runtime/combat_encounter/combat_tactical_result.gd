class_name CombatTacticalResult
extends RefCounted

enum Code {
	ACCEPTED, CANCELLED, INVALID_REQUEST, INACTIVE, APPLICATION_BLOCKED,
	WORLD_GATE_MISMATCH, NOT_PLAYER, AUTHORITY_INVALID, ACTOR_UNAVAILABLE,
	UNKNOWN_ACTION, CATEGORY_MISMATCH, TARGET_INVALID, PREREQUISITE_FAILED,
	DUPLICATE_REQUEST, STALE_CANCEL, SEQUENCE_EXHAUSTED, POLICY_UNSUPPORTED,
	## 战斗决策层 1B: the perform waits its cooldown rounds.
	COOLING_DOWN,
}

var _code: int
var _sequence: int
var code: int:
	get: return _code
var sequence: int:
	get: return _sequence


func _init(p_code: int = Code.INACTIVE, p_sequence: int = 0) -> void:
	_code = p_code
	_sequence = p_sequence


func accepted() -> bool:
	return _code == Code.ACCEPTED
