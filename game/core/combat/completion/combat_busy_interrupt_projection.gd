class_name CombatBusyInterruptProjection
extends RefCounted

## feature/action.c stores busy and interrupt independently. Function values
## remain typed facts only; no Callable enters the combat domain in this phase.
enum BusyKind {
	NOT_BUSY,
	INTEGER,
	FUNCTION,
}

enum InterruptKind {
	INTEGER,
	FUNCTION,
}

var _busy_kind: int
var _interrupt_kind: int

var busy_kind: int:
	get:
		return _busy_kind
var interrupt_kind: int:
	get:
		return _interrupt_kind


func _init(
	p_busy_kind: int = BusyKind.NOT_BUSY,
	p_interrupt_kind: int = InterruptKind.INTEGER,
) -> void:
	_busy_kind = p_busy_kind
	_interrupt_kind = p_interrupt_kind


func is_valid() -> bool:
	return (
		_busy_kind >= BusyKind.NOT_BUSY
		and _busy_kind <= BusyKind.FUNCTION
		and _interrupt_kind >= InterruptKind.INTEGER
		and _interrupt_kind <= InterruptKind.FUNCTION
	)


func duplicate_snapshot() -> CombatBusyInterruptProjection:
	return CombatBusyInterruptProjection.new(_busy_kind, _interrupt_kind)
