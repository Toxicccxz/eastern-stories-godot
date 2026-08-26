class_name ScriptedCombatRandomSource
extends CombatRandomSource

var _draws: Array[int] = []
var _bounds: Array[int] = []
var _next_index: int = 0


func _init(p_draws: Array[int] = []) -> void:
	_draws = p_draws.duplicate()


func next_below(exclusive_upper_bound: int) -> int:
	_bounds.append(exclusive_upper_bound)
	if _next_index >= _draws.size():
		return -1
	var result: int = _draws[_next_index]
	_next_index += 1
	return result


func call_count() -> int:
	return _bounds.size()


func requested_bounds() -> Array[int]:
	return _bounds.duplicate()
