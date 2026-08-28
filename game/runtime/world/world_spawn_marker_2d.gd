class_name WorldSpawnMarker2D
extends Marker2D

@export var spawn_point_id: StringName = &""


func is_configured() -> bool:
	return not spawn_point_id.is_empty()
