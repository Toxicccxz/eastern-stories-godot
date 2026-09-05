class_name CombatProgressionOrder
extends RefCounted

## One encounter-local order shared by tactical and ordinary event streams.
## This is not a clock, request correlation ID, queue, or global counter.
var _next: int = 1


func take() -> int:
	if _next == 9223372036854775807:
		return 0
	var result: int = _next
	_next += 1
	return result
