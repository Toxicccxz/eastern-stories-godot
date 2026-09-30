class_name WorldDoor
extends Node

## Scene half of a data-defined door (doors[] in world.json): the wall shape
## that blocks the doorway while closed and the visual that shows it shut.
## Opening only toggles these; the map decides whether the player may.
@export var door_id: StringName = &""
@export var wall: NodePath
@export var shutter: NodePath

var _open: bool = false


func is_open() -> bool:
	return _open


func wall_shape() -> CollisionShape2D:
	return get_node_or_null(wall) as CollisionShape2D


func set_open(value: bool) -> void:
	_open = value
	wall_shape().set_deferred("disabled", value)
	(get_node(shutter) as CanvasItem).visible = not value
