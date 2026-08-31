class_name OldPineRestoredCorpseEntry
extends RefCounted

var state: CorpseState
var world_location: WorldLocationState
var map_position: Vector2


func _init(
	p_state: CorpseState = null,
	p_world_location: WorldLocationState = null,
	p_map_position: Vector2 = Vector2.ZERO,
) -> void:
	state = p_state
	world_location = (
		null if p_world_location == null else p_world_location.duplicate_snapshot()
	)
	map_position = p_map_position


func is_valid() -> bool:
	return (
		state != null
		and state.is_valid()
		and world_location != null
		and world_location.is_valid()
		and map_position.is_finite()
	)
