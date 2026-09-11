class_name SnowResidentMapController
extends WorldResidentMapController

## Two physical maps share binding/activation; no birth or Session authority.
@onready var player_body: WorldCharacterBody2D = %Player
@onready var birth_marker: WorldSpawnMarker2D = %PlayerBirth
var _initialized: bool = false
var _initialization_count: int = 0
var _freeze_owner: StringName = &""
var _zones: Array[WorldPhysicalZoneArea2D] = []
var _present_zones: Array[WorldPhysicalZoneArea2D] = []
var _zone_check_pending: bool = false


func _ready() -> void:
	initialize_map()


func default_spawn_id() -> StringName:
	return &""


func local_passages() -> Array[PortalDefinition]:
	return []


func initialize_map() -> bool:
	if _initialized:
		return true
	if not _configured or player_body == null or birth_marker == null:
		return false
	for child: Node in $Zones.get_children():
		var zone: WorldPhysicalZoneArea2D = child as WorldPhysicalZoneArea2D
		if zone == null or location_for_zone(zone.zone_id) == null:
			return false
		_zones.append(zone)
		zone.body_entered.connect(_zone_entered.bind(zone))
		zone.body_exited.connect(_zone_exited.bind(zone))
	if not spawn_matches_zone(default_spawn_id(), _player.world_location().zone_id):
		# Inactive map may initialize while Player is in another map.
		var found: bool = false
		for zone: WorldPhysicalZoneArea2D in _zones:
			found = found or spawn_matches_zone(default_spawn_id(), zone.zone_id)
		if not found:
			return false
	if not player_body.bind_player(_player) or not player_body.bind_world_simulation_gate(_world_simulation_gate):
		return false
	player_body.global_position = birth_marker.global_position
	for portal: PortalDefinition in local_passages():
		if not configure_passage(portal):
			return false
	if not initialize_passages():
		return false
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


func resolve_spawn_marker(id: StringName) -> WorldSpawnMarker2D:
	for child: Node in $SpawnPoints.get_children():
		var marker: WorldSpawnMarker2D = child as WorldSpawnMarker2D
		if marker != null and marker.spawn_point_id == id:
			return marker
	return null


func spawn_matches_zone(id: StringName, zone_id: StringName) -> bool:
	var marker: WorldSpawnMarker2D = resolve_spawn_marker(id)
	if marker == null:
		return false
	for zone: WorldPhysicalZoneArea2D in _zones:
		if zone.zone_id == zone_id:
			return zone.contains_center(marker.global_position)
	return false


func location_for_zone(id: StringName) -> WorldLocationState:
	var zone: ZoneDefinition = SnowWorldDefinitions.zone_by_id(id)
	if zone == null or zone.map_id != map_id():
		return null
	return WorldLocationState.new(SnowWorldDefinitions.REGION_ID, map_id(), zone.zone_id, zone.combat_location_id)


func resolve_location(zone_id: StringName, combat_id: StringName) -> WorldLocationState:
	var location: WorldLocationState = location_for_zone(zone_id)
	return location if location != null and location.combat_location_id == combat_id else null


func prepare_for_activation(spawn_id: StringName) -> bool:
	if not _initialized:
		return false
	var marker: WorldSpawnMarker2D = resolve_spawn_marker(spawn_id)
	if marker == null:
		return false
	prepare_for_deactivation()
	player_body.global_position = marker.global_position
	return true


func complete_activation() -> bool:
	if not _initialized:
		return false
	var location: WorldLocationState = _player.world_location()
	var resolved: WorldLocationState = resolve_location(location.zone_id, location.combat_location_id)
	if resolved == null or not location.same_location(resolved):
		return false
	player_body.player_controlled = true
	player_body.refresh_runtime_state()
	(player_body.get_node("Camera2D") as Camera2D).enabled = true
	clear_passage_contacts()
	return true


func prepare_for_deactivation() -> void:
	if player_body == null:
		return
	player_body.player_controlled = false
	player_body.velocity = Vector2.ZERO
	(player_body.get_node("Camera2D") as Camera2D).enabled = false
	_present_zones.clear()
	_zone_check_pending = false
	clear_passage_contacts()


func _zone_entered(body: Node2D, zone: WorldPhysicalZoneArea2D) -> void:
	if body != player_body or not player_body.player_controlled:
		return
	if not _present_zones.has(zone):
		_present_zones.append(zone)
	_zone_check_pending = true


func _zone_exited(body: Node2D, zone: WorldPhysicalZoneArea2D) -> void:
	if body == player_body:
		_present_zones.erase(zone)
		_zone_check_pending = true


func _physics_process(_delta: float) -> void:
	if not _zone_check_pending or not player_body.player_controlled or _world_simulation_gate.is_frozen():
		return
	# Only re-evaluate Areas reported by physics, while straddling their boundary.
	# Never clear the last valid location on body_exited; center ownership is atomic.
	for zone: WorldPhysicalZoneArea2D in _present_zones:
		if zone.contains_center(player_body.global_position):
			accept_zone_presence(zone)
			_zone_check_pending = _present_zones.size() > 1
			return


func accept_zone_presence(zone: WorldPhysicalZoneArea2D) -> bool:
	if not _initialized or not player_body.player_controlled or _world_simulation_gate.is_frozen() or not _zones.has(zone) or not zone.contains_center(player_body.global_position):
		return false
	var current: WorldLocationState = _player.world_location()
	if current.map_id != map_id() or current.region_id != SnowWorldDefinitions.REGION_ID:
		return false
	if current.zone_id == zone.zone_id:
		return true
	if not SnowWorldDefinitions.route_neighbours(current.zone_id, zone.zone_id):
		return false
	return _player.set_world_location(location_for_zone(zone.zone_id))


func freeze_world_gameplay(id: StringName) -> bool:
	if not _initialized or id.is_empty() or not _freeze_owner.is_empty() or _world_simulation_gate.freeze_owner_id() != id:
		return false
	_freeze_owner = id
	player_body.quarantine_current_movement_input()
	return true


func thaw_world_gameplay(id: StringName) -> bool:
	if id.is_empty() or _freeze_owner != id or _world_simulation_gate.freeze_owner_id() != id:
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
