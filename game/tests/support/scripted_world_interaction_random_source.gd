class_name ScriptedWorldInteractionRandomSource
extends WorldInteractionRandomSource

var _draws: Array[int] = []
var _requested_bounds: Array[int] = []


func _init(draws: Array[int] = []) -> void:
	_draws = draws.duplicate()


func next_below(exclusive_upper_bound: int) -> int:
	_requested_bounds.append(exclusive_upper_bound)
	if _draws.is_empty():
		return -1
	return _draws.pop_front()


func call_count() -> int:
	return _requested_bounds.size()


func requested_bounds() -> Array[int]:
	return _requested_bounds.duplicate()
