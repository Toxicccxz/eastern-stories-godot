class_name WorldMapController
extends WorldResidentMapController

## One walkable map, configured by its data (maps/zones/portals/services/doors
## in world.json) and by ID-carrying scene components: WorldPhysicalZoneArea2D
## under Zones, WorldSpawnMarker2D under SpawnPoints, WorldPassageArea2D,
## WorldServicePoint and WorldDoor. No region-specific code.
@export var map: StringName = &""

## Services talk to the Session's shared UI and player state; optional for
## isolated map compositions without a Session.
var session: OldPineWorldSessionController
var player_body: WorldCharacterBody2D
var _definition: MapDefinition
var _initialized: bool = false
var _initialization_count: int = 0
var _freeze_owner: StringName = &""
var _zones: Array[WorldPhysicalZoneArea2D] = []
var _present_zones: Array[WorldPhysicalZoneArea2D] = []
var _zone_check_pending: bool = false
var _services: Array[WorldService] = []
var _doors: Dictionary[StringName, WorldDoor] = {}


func _ready() -> void:
	initialize_map()


func map_id() -> StringName:
	return map


func configure_session(value: OldPineWorldSessionController) -> bool:
	if _initialized or value == null or session != null:
		return false
	session = value
	return true


func initialize_map() -> bool:
	if _initialized:
		return true
	_definition = GameContent.catalog().map(map)
	player_body = get_node_or_null("%Player") as WorldCharacterBody2D
	if not _configured or _definition == null or player_body == null:
		return false
	if not _bind_zones() or not _bind_passages() or not _bind_services() or not _bind_doors():
		return false
	var entry: WorldSpawnMarker2D = resolve_spawn_marker(_definition.entry_spawn_id)
	if entry == null or _zone_at(entry.global_position) == null:
		return false
	if not player_body.bind_player(_player) or not player_body.bind_world_simulation_gate(_world_simulation_gate):
		return false
	player_body.global_position = entry.global_position
	prepare_for_deactivation()
	_initialized = true
	_initialization_count += 1
	return true


## Every zone of this map has exactly one Area in the scene, and no more.
func _bind_zones() -> bool:
	var expected: Dictionary[StringName, bool] = {}
	for zone: ZoneDefinition in GameContent.catalog().zones_for_map(map):
		expected[zone.zone_id] = true
	for child: Node in get_node("Zones").get_children():
		var zone: WorldPhysicalZoneArea2D = child as WorldPhysicalZoneArea2D
		if zone == null or not expected.erase(zone.zone_id):
			return false
		_zones.append(zone)
		zone.body_entered.connect(_zone_entered.bind(zone))
		zone.body_exited.connect(_zone_exited.bind(zone))
	return expected.is_empty()


## A passage opens only when its destination map is resident in the
## coordinator that holds this map; otherwise its blocking wall stays.
func _bind_passages() -> bool:
	var coordinator: WorldResidentMapCoordinator = _coordinator()
	for node: Node in find_children("*", "Area2D", true, false):
		var passage: WorldPassageArea2D = node as WorldPassageArea2D
		if passage == null:
			continue
		var portal: PortalDefinition = GameContent.catalog().portal(passage.portal_id)
		if portal == null:
			return false
		if coordinator != null and coordinator.has_resident_map(portal.destination_map_id) and not configure_passage(portal):
			return false
	return initialize_passages()


func _coordinator() -> WorldResidentMapCoordinator:
	var node: Node = get_parent()
	while node != null and not node is WorldResidentMapCoordinator:
		node = node.get_parent()
	return node as WorldResidentMapCoordinator


func _bind_services() -> bool:
	var expected: Dictionary[StringName, bool] = {}
	for definition: ServiceDefinition in GameContent.catalog().services_for_map(map):
		expected[definition.service_id] = true
	for node: Node in find_children("*", "Marker2D", true, false):
		var point: WorldServicePoint = node as WorldServicePoint
		if point == null:
			continue
		var definition: ServiceDefinition = GameContent.catalog().service(point.service_id)
		var service: WorldService = null if definition == null else WorldServiceKinds.create(definition.kind)
		if service == null or not expected.erase(point.service_id):
			return false
		service.setup(self, definition, point)
		add_child(service)
		_services.append(service)
	return expected.is_empty()


func _bind_doors() -> bool:
	var expected: Dictionary[StringName, bool] = {}
	for definition: DoorDefinition in GameContent.catalog().doors_for_map(map):
		expected[definition.door_id] = true
	for door: WorldDoor in doors():
		if door.wall_shape() == null or not expected.erase(door.door_id):
			return false
		_doors[door.door_id] = door
	return expected.is_empty()


func is_map_initialized() -> bool:
	return _initialized


func initialization_count() -> int:
	return _initialization_count


func runtime_player_body() -> WorldCharacterBody2D:
	return player_body


func region_id() -> StringName:
	return &"" if _definition == null else _definition.region_id


func resolve_spawn_marker(id: StringName) -> WorldSpawnMarker2D:
	for child: Node in get_node("SpawnPoints").get_children():
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


func _zone_at(point: Vector2) -> WorldPhysicalZoneArea2D:
	for zone: WorldPhysicalZoneArea2D in _zones:
		if zone.contains_center(point):
			return zone
	return null


func physical_zones() -> Array[WorldPhysicalZoneArea2D]:
	return _zones.duplicate()


func location_for_zone(id: StringName) -> WorldLocationState:
	var zone: ZoneDefinition = GameContent.catalog().zone(id)
	if zone == null or zone.map_id != map or _definition == null:
		return null
	return WorldLocationState.new(_definition.region_id, map, zone.zone_id, zone.combat_location_id)


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
	if not _initialized or not _zone_check_pending or not player_body.player_controlled or _world_simulation_gate.is_frozen():
		return
	# Only re-evaluate Areas reported by physics, while straddling their boundary.
	# Never clear the last valid location on body_exited; center ownership is atomic.
	for zone: WorldPhysicalZoneArea2D in _present_zones:
		if zone.contains_center(player_body.global_position):
			accept_zone_presence(zone)
			_zone_check_pending = _present_zones.size() > 1
			return


## The player walks from one zone into a neighbouring one (ES2 room exits).
func accept_zone_presence(zone: WorldPhysicalZoneArea2D) -> bool:
	if not _initialized or not player_body.player_controlled or _world_simulation_gate.is_frozen() or not _zones.has(zone) or not zone.contains_center(player_body.global_position):
		return false
	var current: WorldLocationState = _player.world_location()
	if current.map_id != map or current.region_id != _definition.region_id:
		return false
	if current.zone_id == zone.zone_id:
		return true
	if not GameContent.catalog().zones_adjacent(current.zone_id, zone.zone_id):
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


# --- Authorities for services -------------------------------------------------

func player() -> WorldPlayerRuntimeState:
	return _player


func inventory() -> InventoryState:
	return _inventory


func stacks() -> CombinedStackCollection:
	return _stacks


func item_index() -> WorldItemInstanceIndex:
	return _item_index


func item_id_allocator() -> SessionItemIdAllocator:
	return _item_id_allocator


func foods() -> FoodCollection:
	return _foods


func liquids() -> LiquidCollection:
	return _liquids


func world_interaction_random() -> WorldInteractionRandomSource:
	return _world_interaction_random


# --- Interactions: services and doors ----------------------------------------

## Whether the player may use something on this map right now. `idle` adds
## ES2's busy/fight gate and needs a Session.
func can_act(idle: bool) -> bool:
	if not is_inside_tree() or not _initialized or get_tree().paused or not player_body.player_controlled or not _world_simulation_gate.is_open():
		return false
	if _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or _player.relationship.is_fighting() or _player.world_location().map_id != map:
		return false
	if not idle:
		return true
	return (
		session != null
		and session.liquid_interaction_available()
		and session.active_map() == self
		and not _player.busy.is_busy()
		and not session.combat_encounter_coordinator().has_active_encounter()
	)


## The player stands in one of `zone_ids`, within `reach` of `point`, at a
## position a save could hold.
func player_near(zone_ids: Array[StringName], point: Vector2, reach: int) -> bool:
	var zone_id: StringName = _player.world_location().zone_id
	return (
		zone_ids.has(zone_id)
		and player_body.global_position.distance_squared_to(point) <= float(reach * reach)
		and OldPineMapPlacementValidator.is_valid_character_position(self, zone_id, player_body.global_position)
	)


func services() -> Array[WorldService]:
	return _services.duplicate()


func service(service_id: StringName) -> WorldService:
	for candidate: WorldService in _services:
		if candidate.definition.service_id == service_id:
			return candidate
	return null


func door(door_id: StringName) -> WorldDoor:
	return _doors.get(door_id)


## Read from the scene, so it also works before initialize_map().
func doors() -> Array[WorldDoor]:
	var result: Array[WorldDoor] = []
	for node: Node in find_children("*", "", true, false):
		if node is WorldDoor:
			result.append(node as WorldDoor)
	return result


func can_operate_door(door_id: StringName) -> bool:
	var node: WorldDoor = _doors.get(door_id)
	var definition: DoorDefinition = GameContent.catalog().door(door_id)
	return (
		node != null
		and (definition.closable or not node.is_open())
		and can_act(true)
		and player_near(definition.zone_ids(), node.wall_shape().global_position, definition.reach)
	)


func open_door(door_id: StringName) -> bool:
	if not can_operate_door(door_id) or _doors[door_id].is_open():
		return false
	_doors[door_id].set_open(true)
	return true


## The closed footprint is never a valid position (see the placement
## validator), so closing cannot trap the player in the doorway.
func close_door(door_id: StringName) -> bool:
	if not can_operate_door(door_id) or not _doors[door_id].is_open():
		return false
	_doors[door_id].set_open(false)
	return true


## What the context button offers here: a door first, then a service.
func interaction_title() -> String:
	for door_id: StringName in _doors:
		if can_operate_door(door_id):
			var name_text: String = GameContent.catalog().door(door_id).display_name
			return (tr("关闭%s") if _doors[door_id].is_open() else tr("打开%s")) % name_text
	for candidate: WorldService in _services:
		var title: String = candidate.context_title()
		if not title.is_empty():
			return title
	return ""


func interact() -> void:
	if ExplorationPresentationBlocker.is_blocked(get_tree()):
		return
	for door_id: StringName in _doors:
		if can_operate_door(door_id):
			if _doors[door_id].is_open():
				close_door(door_id)
			else:
				open_door(door_id)
			return
	for candidate: WorldService in _services:
		if not candidate.context_title().is_empty():
			candidate.interact()
			return


## Back/Escape on a service panel. False when no service claims `content`.
func dismiss_panel(content: Control) -> bool:
	for candidate: WorldService in _services:
		if candidate.dismiss(content):
			return true
	return false
