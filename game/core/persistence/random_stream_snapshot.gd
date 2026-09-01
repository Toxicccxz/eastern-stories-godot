class_name RandomStreamSnapshot
extends RefCounted

const GODOT_PCG32_ADAPTER_ID: StringName = &"godot-random-number-generator-pcg32-v1"

var adapter_id: StringName
var seed: int
var state: int


func _init(
	p_adapter_id: StringName = GODOT_PCG32_ADAPTER_ID,
	p_seed: int = 0,
	p_state: int = 0,
) -> void:
	adapter_id = p_adapter_id
	seed = p_seed
	state = p_state


func duplicate_snapshot() -> RandomStreamSnapshot:
	return RandomStreamSnapshot.new(adapter_id, seed, state)


func is_supported() -> bool:
	return adapter_id == GODOT_PCG32_ADAPTER_ID
