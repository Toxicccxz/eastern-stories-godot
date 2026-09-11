class_name WorldPassageArea2D
extends Area2D

## One authored physical passage, configured by the owning map composition.
## Unconfigured cross-region passages retain their optional blocking wall.
@export var portal_id: StringName = &""
@export var closed_wall_path: NodePath
var _portal: PortalDefinition
var _map: WorldResidentMapController
var _contact: bool = false
var _pending: bool = false


func configure(portal: PortalDefinition, map: WorldResidentMapController) -> bool:
	if _portal != null or portal == null or not portal.is_valid() or map == null or portal.portal_id != portal_id or portal.source_map_id != map.map_id():
		return false
	_portal = portal
	_map = map
	if not closed_wall_path.is_empty():
		var wall: CollisionShape2D = get_node_or_null(closed_wall_path) as CollisionShape2D
		if wall == null:
			return false
		wall.disabled = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	return true


func is_current(portal: PortalDefinition) -> bool:
	if _portal == null or portal != _portal or not is_inside_tree() or not monitoring or _map == null or not _map.is_map_initialized():
		return false
	var body: WorldCharacterBody2D = _map.runtime_player_body()
	if body == null or not body.player_controlled or _map._world_simulation_gate.is_frozen():
		return false
	var location: WorldLocationState = _map._player.world_location()
	if location.map_id != _portal.source_map_id or location.zone_id != _portal.source_zone_id:
		return false
	var collision: CollisionShape2D = get_node("CollisionShape2D") as CollisionShape2D
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	return not collision.disabled and rectangle != null and Rect2(-rectangle.size / 2.0, rectangle.size).has_point(collision.to_local(body.global_position))


func _physics_process(_delta: float) -> void:
	# Area enter can replay a cached contact after resident reattachment. Require
	# the current body center, and recheck again at the deferred coordinator boundary.
	if _contact and not _pending and is_current(_portal):
		_pending = true
		_map.passage_requested.emit(_portal)


func clear_contact() -> void:
	_contact = false
	_pending = false


func _on_body_entered(body: Node2D) -> void:
	if _map != null and body == _map.runtime_player_body():
		_contact = true


func _on_body_exited(body: Node2D) -> void:
	if _map != null and body == _map.runtime_player_body():
		clear_contact()
