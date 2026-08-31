class_name OldPineRestoredNpcEntry
extends RefCounted

var runtime: NpcRuntimeState
var map_position: Vector2


func _init(
	p_runtime: NpcRuntimeState = null,
	p_map_position: Vector2 = Vector2.ZERO,
) -> void:
	runtime = p_runtime
	map_position = p_map_position


func is_valid() -> bool:
	return runtime != null and runtime.is_valid() and map_position.is_finite()
