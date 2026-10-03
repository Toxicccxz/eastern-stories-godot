class_name WorldFloorItemView
extends Node2D

## An item lying on the floor of a zone (an item spawn): clickable to select,
## with the reach from which it can be picked up. Placeholder box and name.
signal selection_requested(item_instance_id: StringName)

const PICKUP_RADIUS: float = 96.0

var _item_instance_id: StringName = &""
var _display_name: String = ""

var item_instance_id: StringName:
	get: return _item_instance_id
var display_name: String:
	get: return _display_name


func configure(item_instance_id: StringName, display_name: String) -> bool:
	if item_instance_id.is_empty() or display_name.is_empty():
		return false
	_item_instance_id = item_instance_id
	_display_name = display_name
	name = String(item_instance_id).replace(".", "_")
	var picking: Area2D = Area2D.new()
	picking.name = "PickingArea"
	picking.input_pickable = true
	picking.collision_layer = 2
	picking.collision_mask = 0
	picking.monitoring = false
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(48.0, 32.0)
	shape.shape = rectangle
	picking.add_child(shape)
	picking.input_event.connect(_on_picking_input_event)
	add_child(picking)
	# A Label, so the name is shown translated and in the language's font.
	var label := Label.new()
	label.name = "NameLabel"
	label.text = display_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-40.0, 10.0)
	label.size = Vector2(80.0, 18.0)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("e2d3b6"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	queue_redraw()
	return true


func is_body_in_reach(body: Node2D) -> bool:
	return body != null and global_position.distance_to(body.global_position) <= PICKUP_RADIUS


func _on_picking_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		selection_requested.emit(_item_instance_id)


func _draw() -> void:
	draw_rect(Rect2(-10.0, -6.0, 20.0, 12.0), Color("b79a62"))
	draw_rect(Rect2(-10.0, -6.0, 20.0, 12.0), Color("3a2f22"), false, 1.0)
