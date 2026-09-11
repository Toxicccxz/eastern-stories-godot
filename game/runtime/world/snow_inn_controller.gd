class_name SnowInnController
extends WorldResidentMapController

## Physical embodiment only. No birth, NPC spawns, Session, save or exit execution.
@onready var player_body: WorldCharacterBody2D = %Player
@onready var birth_marker: WorldSpawnMarker2D = %PlayerBirth
@onready var floor_area: Area2D = %MainFloor

var _initialized: bool = false
var _initialization_count: int = 0
var _freeze_owner: StringName = &""


func _ready() -> void:
	initialize_map()


func map_id() -> StringName:
	return SnowWorldDefinitions.INN_MAP_ID


func initialize_map() -> bool:
	if _initialized:
		return true
	if not _configured or player_body == null or birth_marker == null or floor_area == null:
		return false
	if not spawn_matches_zone(SnowWorldDefinitions.BIRTH_SPAWN_ID, SnowWorldDefinitions.MAIN_FLOOR_ZONE_ID):
		return false
	if not player_body.bind_player(_player) or not player_body.bind_world_simulation_gate(_world_simulation_gate):
		return false
	player_body.global_position = birth_marker.global_position
	prepare_for_deactivation()
	_initialized = true
	_initialization_count += 1
	return true


func is_map_initialized() -> bool:
	return _initialized


func initialization_count() -> int:
	return _initialization_count


func runtime_player_body() -> WorldCharacterBody2D:
	return player_body


func resolve_spawn_marker(spawn_point_id: StringName) -> WorldSpawnMarker2D:
	if birth_marker != null and birth_marker.spawn_point_id == spawn_point_id:
		return birth_marker
	return null


func spawn_matches_zone(spawn_point_id: StringName, zone_id: StringName) -> bool:
	var marker: WorldSpawnMarker2D = resolve_spawn_marker(spawn_point_id)
	if marker == null or zone_id != SnowWorldDefinitions.MAIN_FLOOR_ZONE_ID or floor_area == null:
		return false
	var collision: CollisionShape2D = floor_area.get_node("CollisionShape2D") as CollisionShape2D
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	return rectangle != null and Rect2(-rectangle.size / 2.0, rectangle.size).has_point(collision.to_local(marker.global_position))


func resolve_location(zone_id: StringName, combat_location_id: StringName) -> WorldLocationState:
	if zone_id != SnowWorldDefinitions.MAIN_FLOOR_ZONE_ID or combat_location_id != SnowWorldDefinitions.MAIN_FLOOR_COMBAT_LOCATION_ID:
		return null
	return SnowWorldDefinitions.birth_location()


func prepare_for_activation(spawn_point_id: StringName) -> bool:
	if not _initialized or not spawn_matches_zone(spawn_point_id, SnowWorldDefinitions.MAIN_FLOOR_ZONE_ID):
		return false
	prepare_for_deactivation()
	player_body.global_position = resolve_spawn_marker(spawn_point_id).global_position
	return true


func complete_activation() -> bool:
	if not _initialized or not _player.world_location().same_location(SnowWorldDefinitions.birth_location()):
		return false
	player_body.player_controlled = true
	player_body.refresh_runtime_state()
	(player_body.get_node("Camera2D") as Camera2D).enabled = true
	return true


func prepare_for_deactivation() -> void:
	if player_body == null:
		return
	player_body.player_controlled = false
	player_body.velocity = Vector2.ZERO
	(player_body.get_node("Camera2D") as Camera2D).enabled = false


func freeze_world_gameplay(encounter_id: StringName) -> bool:
	if not _initialized or encounter_id.is_empty() or not _freeze_owner.is_empty() or _world_simulation_gate.freeze_owner_id() != encounter_id:
		return false
	_freeze_owner = encounter_id
	player_body.quarantine_current_movement_input()
	return true


func thaw_world_gameplay(encounter_id: StringName) -> bool:
	if encounter_id.is_empty() or _freeze_owner != encounter_id or _world_simulation_gate.freeze_owner_id() != encounter_id:
		return false
	_freeze_owner = &""
	player_body.quarantine_current_movement_input()
	return true


func suspend_for_session_swap() -> bool:
	if not _initialized:
		return false
	prepare_for_deactivation()
	return true


func resume_after_session_swap_rollback() -> bool:
	return complete_activation()


func replace_combat_random_source(value: CombatRandomSource) -> bool:
	if value == null:
		return false
	_combat_random = value
	return true


func replace_world_interaction_random_source(value: WorldInteractionRandomSource) -> bool:
	if value == null:
		return false
	_world_interaction_random = value
	return true
