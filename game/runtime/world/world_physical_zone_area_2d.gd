class_name WorldPhysicalZoneArea2D
extends Area2D

## Runtime geometry, not a second WorldLocation authority. Half-open rectangles
## give one center owner even when a CharacterBody overlaps both adjacent Areas.
@export var zone_id: StringName = &""


func contains_center(global_point: Vector2) -> bool:
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.disabled:
		return false
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	return rectangle != null and Rect2(-rectangle.size / 2.0, rectangle.size).has_point(collision.to_local(global_point))
