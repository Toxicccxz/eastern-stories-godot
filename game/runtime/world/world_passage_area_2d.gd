class_name WorldPassageArea2D
extends Area2D

## One authored physical passage, configured by the owning map composition.
## Unconfigured cross-region passages retain their optional blocking wall.
## A hidden passage (a hidden_passage landmark's portal) can be shut: then it
## is plain floor, its shape off and its visuals hidden.
@export var portal_id: StringName = &""
@export var closed_wall_path: NodePath
var _portal: PortalDefinition
var _map: WorldResidentMapController
var _contact: bool = false
var _pending: bool = false
var _open: bool = true
## Opened under the player: they have not taken the exit until they step off and on again.
var _wait_for_exit: bool = false
## The room's valid_leave() refused this passage; cleared once the player is off it.
var _refused: bool = false


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


func is_open() -> bool:
	return _open


## Opening adds an exit (ES2 set("exits/down")); whoever already stands on it
## still has to step onto it.
func set_open(value: bool) -> void:
	_open = value
	visible = value
	(get_node("CollisionShape2D") as CollisionShape2D).set_deferred("disabled", not value)
	clear_contact()
	_wait_for_exit = value and _player_overlaps()


func _player_overlaps() -> bool:
	var body: WorldCharacterBody2D = null if _map == null else _map.runtime_player_body()
	if body == null or not is_inside_tree() or not body.is_inside_tree():
		return false
	var mine: CollisionShape2D = get_node("CollisionShape2D") as CollisionShape2D
	var theirs: CollisionShape2D = body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return theirs != null and mine.shape.collide(mine.global_transform, theirs.shape, theirs.global_transform)


func is_current(portal: PortalDefinition) -> bool:
	if _portal == null or portal != _portal or not _open or not is_inside_tree() or not monitoring or _map == null or not _map.is_map_initialized():
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
		# A refusal holds until the player's centre has left the passage (it was pushed back,
		# or walks away): stepping on again is trying again.
		if _refused:
			return
		if not _map.leave_by_passage(_portal, self):
			_refused = true
			return
		_pending = true
		if _portal.destination_map_id == _portal.source_map_id:
			_map.call_deferred(&"traverse_same_map_passage", _portal)
		else:
			_map.passage_requested.emit(_portal)
	elif _refused and not is_current(_portal):
		_refused = false


## The passage's rectangle in the world (the player is kept out of a refused one).
func global_rect() -> Rect2:
	var collision: CollisionShape2D = get_node("CollisionShape2D") as CollisionShape2D
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	return Rect2(collision.global_position - rectangle.size / 2.0, rectangle.size)


func clear_contact() -> void:
	_contact = false
	_pending = false


func _on_body_entered(body: Node2D) -> void:
	if _map != null and body == _map.runtime_player_body() and not _wait_for_exit:
		_contact = true


func _on_body_exited(body: Node2D) -> void:
	if _map != null and body == _map.runtime_player_body():
		_wait_for_exit = false
		clear_contact()
