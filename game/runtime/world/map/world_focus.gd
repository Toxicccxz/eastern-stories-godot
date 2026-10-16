class_name WorldFocus
extends RefCounted

## What the place's A (ui_accept) goes to now (DECISIONS「手感」), for the ring and the
## prompt over it: the place's context action (a door, a service: `title` is its button
## text) or, with none, the nearest thing in reach (`thing`), whose group A goes into.

var title: String = ""
var thing: WorldNearbyThing
## The node it stands at (an NPC walks), or null and a fixed `point`.
var node: Node2D
var point: Vector2 = Vector2.INF


func _init(p_title: String, p_thing: WorldNearbyThing, p_node: Node2D, p_point: Vector2 = Vector2.INF) -> void:
	title = p_title
	thing = p_thing
	node = p_node
	point = p_point


## Where it is in the world now (INF when its node is gone).
func at() -> Vector2:
	if node != null:
		return node.global_position if is_instance_valid(node) and node.is_inside_tree() else Vector2.INF
	return point
