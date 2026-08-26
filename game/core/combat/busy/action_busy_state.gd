class_name ActionBusyState
extends RefCounted

## Integer-only projection of feature/action.c. Function busy actions and
## function interrupt handlers are deliberately not representable here.
var _busy_value: int = 0
var _interrupt_threshold: int = 0

var busy_value: int:
	get:
		return _busy_value

var interrupt_threshold: int:
	get:
		return _interrupt_threshold


func is_busy() -> bool:
	return _busy_value != 0


## start_busy(0, ...) is a complete no-op. Any non-zero integer replaces both
## current integer facts, including negative busy values.
func start_busy(value: int, threshold: int = 0) -> bool:
	if value == 0:
		return false
	_busy_value = value
	_interrupt_threshold = threshold
	return true


## Returns whether either stored fact changed. Positive values decrement and
## return immediately; non-positive values clear both facts.
func advance() -> bool:
	if _busy_value > 0:
		_busy_value -= 1
		return true
	var changed: bool = _busy_value != 0 or _interrupt_threshold != 0
	_busy_value = 0
	_interrupt_threshold = 0
	return changed


## feature/action.c uses a strict busy < interrupt comparison and clears only
## busy on the integer path, leaving the interrupt value untouched.
func try_interrupt() -> bool:
	if _busy_value == 0:
		return false
	if _busy_value < _interrupt_threshold:
		_busy_value = 0
		return true
	return false
