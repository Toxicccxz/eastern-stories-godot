class_name ScriptedNpcInitializationRandomSource
extends NpcInitializationRandomSource

var _values: Array[int] = []
var _next_index: int = 0
var _requested_bounds: Array[int] = []


func _init(p_values: Array[int] = []) -> void:
	_values = p_values.duplicate()


func next_below(exclusive_upper_bound: int) -> int:
	_requested_bounds.append(exclusive_upper_bound)
	if _next_index >= _values.size():
		return -1
	var value: int = _values[_next_index]
	_next_index += 1
	return value


func call_count() -> int:
	return _requested_bounds.size()


func requested_bounds() -> Array[int]:
	return _requested_bounds.duplicate()
