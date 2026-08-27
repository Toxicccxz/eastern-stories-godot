class_name CombatBusyInterruptResult
extends RefCounted

enum Outcome {
	NOT_REACHED,
	DEFENDER_NOT_BUSY,
	INTEGER_BUSY_REMAINED,
	INTEGER_BUSY_CLEARED,
	FUNCTION_INTERRUPT_POLICY_UNAVAILABLE,
	FUNCTION_BUSY_INTEGER_INTERRUPT_NO_OP,
}

var _outcome: int
var _interrupt_attempted: bool
var _busy_kind: int
var _interrupt_kind: int
var _has_integer_state: bool
var _busy_before: int
var _busy_after: int
var _interrupt_threshold: int

var outcome: int:
	get:
		return _outcome
var interrupt_attempted: bool:
	get:
		return _interrupt_attempted
var busy_kind: int:
	get:
		return _busy_kind
var interrupt_kind: int:
	get:
		return _interrupt_kind
var has_integer_state: bool:
	get:
		return _has_integer_state
var busy_before: int:
	get:
		return _busy_before
var busy_after: int:
	get:
		return _busy_after
var interrupt_threshold: int:
	get:
		return _interrupt_threshold


func _init(
	p_outcome: int = Outcome.NOT_REACHED,
	p_interrupt_attempted: bool = false,
	p_busy_kind: int = CombatBusyInterruptProjection.BusyKind.NOT_BUSY,
	p_interrupt_kind: int = CombatBusyInterruptProjection.InterruptKind.INTEGER,
	p_has_integer_state: bool = false,
	p_busy_before: int = 0,
	p_busy_after: int = 0,
	p_interrupt_threshold: int = 0,
) -> void:
	_outcome = p_outcome
	_interrupt_attempted = p_interrupt_attempted
	_busy_kind = p_busy_kind
	_interrupt_kind = p_interrupt_kind
	_has_integer_state = p_has_integer_state
	_busy_before = p_busy_before
	_busy_after = p_busy_after
	_interrupt_threshold = p_interrupt_threshold


func duplicate_snapshot() -> CombatBusyInterruptResult:
	return CombatBusyInterruptResult.new(
		_outcome,
		_interrupt_attempted,
		_busy_kind,
		_interrupt_kind,
		_has_integer_state,
		_busy_before,
		_busy_after,
		_interrupt_threshold,
	)
