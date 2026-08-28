class_name CombatSliceCorpseView
extends Node2D

signal selection_requested(corpse_item_instance_id: StringName)
signal loot_range_changed(
	corpse_item_instance_id: StringName,
	body: Node2D,
	is_inside: bool,
)

const LOOT_INTERACTION_RADIUS: float = 96.0

var _corpse_item_instance_id: StringName = &""
var _victim_display_name: String = ""
var _picking_area: Area2D
var _loot_interaction_range: Area2D
var _bodies_in_loot_range: Array[Node2D] = []

var corpse_item_instance_id: StringName:
	get: return _corpse_item_instance_id
var victim_display_name: String:
	get: return _victim_display_name


func configure(corpse: CorpseState) -> bool:
	if corpse == null or not corpse.is_valid():
		return false
	_corpse_item_instance_id = corpse.corpse_item_instance_id
	_victim_display_name = corpse.victim_display_name
	_ensure_interaction_children()
	queue_redraw()
	return true


func is_body_in_loot_range(body: Node2D) -> bool:
	return (
		body != null
		and (
			_bodies_in_loot_range.has(body)
			or (
				_loot_interaction_range != null
				and _loot_interaction_range.is_inside_tree()
				and _loot_interaction_range.overlaps_body(body)
			)
			or global_position.distance_to(body.global_position)
			<= LOOT_INTERACTION_RADIUS
		)
	)


func loot_interaction_range() -> Area2D:
	return _loot_interaction_range


func picking_area() -> Area2D:
	return _picking_area


func _ensure_interaction_children() -> void:
	if _picking_area != null and _loot_interaction_range != null:
		return
	_picking_area = Area2D.new()
	_picking_area.name = "PickingArea"
	_picking_area.input_pickable = true
	_picking_area.collision_layer = 2
	_picking_area.collision_mask = 0
	var picking_shape: CollisionShape2D = CollisionShape2D.new()
	picking_shape.name = "CollisionShape2D"
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(96.0, 48.0)
	picking_shape.shape = rectangle
	_picking_area.add_child(picking_shape)
	_picking_area.input_event.connect(_on_picking_input_event)
	add_child(_picking_area)

	_loot_interaction_range = Area2D.new()
	_loot_interaction_range.name = "LootInteractionRange"
	_loot_interaction_range.collision_layer = 0
	_loot_interaction_range.collision_mask = 1
	_loot_interaction_range.monitoring = true
	_loot_interaction_range.monitorable = false
	var range_shape: CollisionShape2D = CollisionShape2D.new()
	range_shape.name = "CollisionShape2D"
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = LOOT_INTERACTION_RADIUS
	range_shape.shape = circle
	_loot_interaction_range.add_child(range_shape)
	_loot_interaction_range.body_entered.connect(_on_loot_range_body_entered)
	_loot_interaction_range.body_exited.connect(_on_loot_range_body_exited)
	add_child(_loot_interaction_range)


func _on_picking_input_event(
	_viewport: Viewport,
	event: InputEvent,
	_shape_idx: int,
) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if (
		mouse_event != null
		and mouse_event.pressed
		and mouse_event.button_index == MOUSE_BUTTON_LEFT
		and not _corpse_item_instance_id.is_empty()
	):
		selection_requested.emit(_corpse_item_instance_id)


func _on_loot_range_body_entered(body: Node2D) -> void:
	if body == null or _bodies_in_loot_range.has(body):
		return
	_bodies_in_loot_range.append(body)
	loot_range_changed.emit(_corpse_item_instance_id, body, true)


func _on_loot_range_body_exited(body: Node2D) -> void:
	if body == null or not _bodies_in_loot_range.has(body):
		return
	_bodies_in_loot_range.erase(body)
	loot_range_changed.emit(_corpse_item_instance_id, body, false)


func _draw() -> void:
	draw_polygon(
		PackedVector2Array([
			Vector2(-38.0, -9.0), Vector2(30.0, -9.0),
			Vector2(38.0, 9.0), Vector2(-30.0, 9.0),
		]),
		PackedColorArray([Color("665448")]),
	)
	draw_circle(Vector2(-38.0, 0.0), 11.0, Color("8a7461"))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-52.0, 31.0),
		"%s's corpse" % _victim_display_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		13,
		Color("d8c4aa"),
	)
