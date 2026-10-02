class_name WorldMapController
extends WorldResidentMapController

## One walkable map, configured by its data (maps/zones/portals/services/doors/
## landmarks in world.json, spawns.json) and by ID-carrying scene components:
## WorldPhysicalZoneArea2D under Zones, WorldSpawnMarker2D under SpawnPoints,
## WorldPassageArea2D, WorldServicePoint, WorldDoor and WorldLandmarkArea2D.
## NPCs get a WorldNpcBody2D each, created in spawn order. No region-specific code.
const NpcBodyScene := preload("res://scenes/world/common/world_npc_body.tscn")
const WORLD_CAPACITY: int = 1_000_000

@export var map: StringName = &""

## Services, the HUD, restore entries and combat talk to the Session; optional
## for isolated map compositions without one.
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
var _landmark_areas: Dictionary[StringName, WorldLandmarkArea2D] = {}

var _map_characters: MapCharacterRuntimeState
var _npcs: Array[NpcRuntimeState] = []
var _npc_bodies: Dictionary[StringName, WorldCharacterBody2D] = {}
var _npc_presence: Dictionary[StringName, Area2D] = {}
var _registered_npc_content: Dictionary[StringName, CombatSliceContentProfile] = {}
var _corpse_states: Array[CorpseState] = []
var _corpse_views: Dictionary[StringName, CombatSliceCorpseView] = {}
var _corpse_locations: Dictionary[StringName, WorldLocationState] = {}
var _floor_items: Dictionary[StringName, WorldFloorItemView] = {}
var _effects: SkillImprovementEffectRegistry
var _selected_target: WorldInteractionTarget
var _selected_landmark_available: bool = false
var _aggression: NpcAggressionAdapter = NpcAggressionAdapter.new()
var _last_aggression_decisions: Array[NpcAggressionDecision] = []
var _last_aggression_initiations: Array[CombatSliceInitiationResult] = []
## Aggressive NPCs of a complete-set zone whose current contact already started
## an encounter; contact must break before it can start another.
var _complete_set_consumed_contacts: Array[StringName] = []
var _loot: CorpseLootAdapter = CorpseLootAdapter.new()
var _last_loot_transfer_result: CorpseLootTransferResult
var _weapon_resolver: WorldWeaponContentResolver = WorldWeaponContentResolver.new()
var _last_player_content_resolution: WorldWeaponContentResolution
var _last_lifecycle_results: Array[CombatSliceLifecycleResult] = []
var _lifecycle_failed: bool = false
var _npc_heartbeat: NpcHeartbeat
var _ambience: NpcAmbience
var _walker: WorldNpcWalker
## The player's place as the NPCs' init() last saw it; another one is an arrival.
var _arrival_zone_id: StringName = &""
var _last_landmark_use: RefCounted
var _last_passage_traversal: RefCounted


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
	if not _bind_zones() or not _bind_passages() or not _bind_services() or not _bind_doors() or not _bind_landmarks():
		return false
	var entry: WorldSpawnMarker2D = resolve_spawn_marker(_definition.entry_spawn_id)
	if entry == null or _zone_at(entry.global_position) == null:
		return false
	if not player_body.bind_player(_player) or not player_body.bind_world_simulation_gate(_world_simulation_gate):
		return false
	player_body.global_position = entry.global_position
	_map_characters = MapCharacterRuntimeState.new(map)
	_effects = SkillImprovementEffectRegistry.new()
	_effects.register_legacy_defaults()
	var restoring: bool = session != null and session.bootstrap_mode() == OldPineWorldSessionController.BootstrapMode.RESTORE
	if not (_restore_actors() if restoring else _spawn_actors()):
		return false
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
## coordinator that holds this map; otherwise its blocking wall stays. A hidden
## passage starts shut until its landmark opens it (the Session's WorldHiddenPassages).
func _bind_passages() -> bool:
	var coordinator: WorldResidentMapCoordinator = _coordinator()
	var passages: Array[WorldPassageArea2D] = []
	for node: Node in find_children("*", "Area2D", true, false):
		var passage: WorldPassageArea2D = node as WorldPassageArea2D
		if passage == null:
			continue
		passages.append(passage)
		var portal: PortalDefinition = GameContent.catalog().portal(passage.portal_id)
		if portal == null:
			return false
		if coordinator != null and coordinator.has_resident_map(portal.destination_map_id) and not configure_passage(portal):
			return false
	if not initialize_passages():
		return false
	for passage: WorldPassageArea2D in passages:
		if GameContent.catalog().hidden_passage_for_portal(passage.portal_id) != null:
			passage.set_open(false)
	return true


func _coordinator() -> WorldResidentMapCoordinator:
	if session != null:
		return session
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


func _bind_landmarks() -> bool:
	var expected: Dictionary[StringName, bool] = {}
	for definition: WorldLandmarkDefinition in GameContent.catalog().landmarks_for_map(map):
		expected[definition.landmark_id] = true
	for node: Node in find_children("*", "Area2D", true, false):
		var area: WorldLandmarkArea2D = node as WorldLandmarkArea2D
		if area == null:
			continue
		if not expected.erase(area.landmark_id):
			return false
		_landmark_areas[area.landmark_id] = area
		area.selection_requested.connect(select_landmark)
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
	var zone: WorldPhysicalZoneArea2D = physical_zone(zone_id)
	return marker != null and zone != null and zone.contains_center(marker.global_position)


func _zone_at(point: Vector2) -> WorldPhysicalZoneArea2D:
	for zone: WorldPhysicalZoneArea2D in _zones:
		if zone.contains_center(point):
			return zone
	return null


## Read from the scene, so it also works before initialize_map().
func physical_zones() -> Array[WorldPhysicalZoneArea2D]:
	var result: Array[WorldPhysicalZoneArea2D] = []
	var zones: Node = get_node_or_null("Zones")
	if zones != null:
		for child: Node in zones.get_children():
			if child is WorldPhysicalZoneArea2D:
				result.append(child as WorldPhysicalZoneArea2D)
	return result


func physical_zone(zone_id: StringName) -> WorldPhysicalZoneArea2D:
	for zone: WorldPhysicalZoneArea2D in physical_zones():
		if zone.zone_id == zone_id:
			return zone
	return null


func location_for_zone(id: StringName) -> WorldLocationState:
	var zone: ZoneDefinition = GameContent.catalog().zone(id)
	var definition: MapDefinition = GameContent.catalog().map(map)
	if zone == null or zone.map_id != map or definition == null:
		return null
	return WorldLocationState.new(definition.region_id, map, zone.zone_id, zone.combat_location_id)


func resolve_location(zone_id: StringName, combat_id: StringName) -> WorldLocationState:
	var location: WorldLocationState = location_for_zone(zone_id)
	return location if location != null and location.combat_location_id == combat_id else null


## Moves the living player to a spawn marker of this map without a scene
## change, as ES2's move_object() does within one place: reincarnating at the
## temple after dying on the temple's own map. False if marker and zone differ.
func relocate_player(zone_id: StringName, spawn_point_id: StringName) -> bool:
	if not _initialized or _player == null or _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		return false
	var marker: WorldSpawnMarker2D = resolve_spawn_marker(spawn_point_id)
	var location: WorldLocationState = location_for_zone(zone_id)
	if marker == null or location == null or not spawn_matches_zone(spawn_point_id, zone_id):
		return false
	player_body.global_position = marker.global_position
	if not _player.set_world_location(location):
		return false
	player_body.refresh_runtime_state()
	_selected_target = null
	if _hud() != null:
		_hud().set_selected_target(null)
	return true


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
	# A re-attached TileMapLayer builds its collision on its next update; build it now so
	# the walls exist from the first physics step after an arrival.
	for node: Node in find_children("*", "TileMapLayer", true, false):
		(node as TileMapLayer).update_internals()
	player_body.player_controlled = true
	player_body.refresh_runtime_state()
	(player_body.get_node("Camera2D") as Camera2D).enabled = true
	clear_passage_contacts()
	if _hud() != null:
		_hud().refresh_live_state()
	return true


func prepare_for_deactivation() -> void:
	if player_body == null:
		return
	player_body.player_controlled = false
	player_body.velocity = Vector2.ZERO
	(player_body.get_node("Camera2D") as Camera2D).enabled = false
	# Nobody watches a map the player left: its NPCs stand where they were going.
	if _walker != null:
		_walker.finish_all()
	_arrival_zone_id = &""
	_present_zones.clear()
	_zone_check_pending = false
	clear_passage_contacts()
	_selected_target = null
	_aggression.clear_all()
	if _hud() != null:
		_hud().set_selected_target(null)
		_hud().close_loot()
		_hud().close_inventory()


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


## The player walks from one zone into a neighbouring one (ES2 room exits and
## the zone links that DECISIONS records).
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
	# A fight or a transition takes NPCs where their move was going (their place
	# already is), so a body never dies or is saved between two zones.
	if _walker != null:
		_walker.finish_all()
	_aggression.clear_all()
	_selected_target = null
	if _hud() != null:
		_hud().set_selected_target(null)
		_hud().close_loot()
		_hud().close_inventory()
	for body: WorldCharacterBody2D in _character_bodies():
		body.quarantine_current_movement_input()
	return true


func thaw_world_gameplay(id: StringName) -> bool:
	if id.is_empty() or _freeze_owner != id or _world_simulation_gate.freeze_owner_id() != id:
		return false
	_freeze_owner = &""
	for body: WorldCharacterBody2D in _character_bodies():
		body.quarantine_current_movement_input()
	if _hud() != null:
		_hud().refresh_live_state()
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


# --- Authorities ---------------------------------------------------------------

func player_runtime() -> WorldPlayerRuntimeState:
	return _player


func inventory_state() -> InventoryState:
	return _inventory


func stack_collection() -> CombinedStackCollection:
	return _stacks


func item_instance_index() -> WorldItemInstanceIndex:
	return _item_index


func item_id_allocator() -> SessionItemIdAllocator:
	return _item_id_allocator


func food_collection() -> FoodCollection:
	return _foods


func liquid_collection() -> LiquidCollection:
	return _liquids


func npc_random_source() -> NpcInitializationRandomSource:
	return _npc_random


func combat_random_source() -> CombatRandomSource:
	return _combat_random


func world_interaction_random_source() -> WorldInteractionRandomSource:
	return _world_interaction_random


func map_character_state() -> MapCharacterRuntimeState:
	return _map_characters


func _hud() -> SharedGameplayUI:
	return null if session == null else session.shared_ui()


func _gameplay_open() -> bool:
	return _world_simulation_gate == null or _world_simulation_gate.is_open()


# --- NPC bodies ----------------------------------------------------------------

## Spawns are created in authored order: it fixes each NPC's random draws and
## loadout item identities.
func _spawn_actors() -> bool:
	var catalog: ContentCatalog = GameContent.catalog()
	var loadout_content: Array[NpcLoadoutItemDefinition] = catalog.loadout_item_definitions()
	for spawn: NpcSpawnDefinition in catalog.spawns_for_map(map):
		var created: Array[NpcRuntimeState] = NpcCharacterStateFactory.new().create_spawn_instances(
			spawn,
			catalog.npc(spawn.npc_definition_id),
			location_for_zone(spawn.zone_id),
			_inventory,
			_stacks,
			_npc_random,
			loadout_content,
			_item_id_allocator.scope,
		)
		if created.size() != spawn.quantity:
			push_error("spawn %s could not be created; check its npc, map and zone" % spawn.spawn_id)
			return false
		for npc: NpcRuntimeState in created:
			if not _register_loadout(npc):
				return false
		for npc: NpcRuntimeState in created:
			var marker: WorldSpawnMarker2D = resolve_spawn_marker(npc.spawn_point_id)
			if marker == null or not _add_npc_body(npc, marker.global_position):
				return false
	return _spawn_floor_items()


func _register_loadout(npc: NpcRuntimeState) -> bool:
	for item: ItemInstance in npc.loadout_items():
		if not _item_index.register_snapshot(item):
			return false
		# The drunk's wineskin starts full, as a bought one does.
		var content: ItemContentDefinition = GameContent.catalog().item(item.item_definition_id)
		if content != null and not ItemRoleStates.register_fresh(content, item.item_instance_id, _foods, _liquids):
			return false
	return true


## Restore places the saved NPCs and corpses of this map, exactly where they were.
func _restore_actors() -> bool:
	for entry: OldPineRestoredNpcEntry in session.restored_npc_entries():
		var npc: NpcRuntimeState = entry.runtime
		if npc.world_location().map_id != map:
			continue
		# register_npc() is a live-spawn API and marks existence true. Restore
		# immediately reapplies the persisted tombstone fact before any frame.
		var saved_exists: bool = npc.exists_in_map
		if not _add_npc_body(npc, entry.map_position):
			return false
		npc.set_exists_in_map(saved_exists)
		_npc_bodies[npc.character_id].refresh_runtime_state()
	for entry: OldPineRestoredCorpseEntry in session.restored_corpse_entries():
		if entry.world_location.map_id == map and not _publish_corpse_view(entry.state, entry.map_position, entry.world_location):
			return false
	var authored_npc_count: int = 0
	for spawn: NpcSpawnDefinition in GameContent.catalog().spawns_for_map(map):
		authored_npc_count += spawn.quantity
	return _npcs.size() == authored_npc_count and _restore_floor_items()


# --- Items on the floor ------------------------------------------------------------

## A new world lays each item spawn's item on its marker (room.c reset() ->
## make_inventory()). Its identity follows from the spawn point, so nothing
## draws from a random source or the dynamic ID sequence.
func _spawn_floor_items() -> bool:
	for spawn: ItemSpawnDefinition in GameContent.catalog().item_spawns_for_map(map):
		for point_id: StringName in spawn.spawn_point_ids():
			if not _place_floor_item(spawn, point_id):
				return false
	return true


func _place_floor_item(spawn: ItemSpawnDefinition, point_id: StringName) -> bool:
	var content: ItemContentDefinition = GameContent.catalog().item(spawn.item_definition_id)
	var location: WorldLocationState = location_for_zone(spawn.zone_id)
	if content == null or location == null:
		return false
	var item: ItemInstance = ItemInstance.new(ItemSpawnDefinition.item_instance_id(_item_id_allocator.scope, point_id), content.item_definition_id)
	if (
		not _inventory.register_item(item, content.own_weight)
		or not _item_index.register_snapshot(item)
		or not ItemRoleStates.register_fresh(content, item.item_instance_id, _foods, _liquids)
	):
		return false
	var placed: InventoryTransferResult = InventoryTransferService.new().transfer(
		_inventory,
		item.item_instance_id,
		InventoryTransferDestination.new(_floor_endpoint(location), true, true, WORLD_CAPACITY),
	)
	return placed.succeeded and _add_floor_item_view(item.item_instance_id, content, point_id)


## Continue: an item still lies on its spawn marker while the save keeps it in
## that zone's WORLD; one taken away is wherever its record says.
func _restore_floor_items() -> bool:
	var catalog: ContentCatalog = GameContent.catalog()
	for spawn: ItemSpawnDefinition in catalog.item_spawns_for_map(map):
		var content: ItemContentDefinition = catalog.item(spawn.item_definition_id)
		var location: WorldLocationState = location_for_zone(spawn.zone_id)
		if content == null or location == null:
			return false
		for point_id: StringName in spawn.spawn_point_ids():
			var id: StringName = ItemSpawnDefinition.item_instance_id(_item_id_allocator.scope, point_id)
			var parent: ContainmentEndpoint = _inventory.direct_parent(id) if _inventory.is_registered(id) else null
			if parent == null or parent.kind != ContainmentEndpoint.Kind.WORLD:
				continue
			if parent.endpoint_id != location.combat_location_id or not _add_floor_item_view(id, content, point_id):
				return false
	return true


func _add_floor_item_view(item_id: StringName, content: ItemContentDefinition, point_id: StringName) -> bool:
	var marker: WorldSpawnMarker2D = resolve_spawn_marker(point_id)
	var view: WorldFloorItemView = WorldFloorItemView.new()
	if marker == null or not view.configure(item_id, content.display_name):
		view.free()
		return false
	view.position = marker.position
	marker.get_parent().add_child(view)
	_floor_items[item_id] = view
	view.selection_requested.connect(select_floor_item)
	return true


static func _floor_endpoint(location: WorldLocationState) -> ContainmentEndpoint:
	return ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, location.combat_location_id)


## Item IDs lying on this map's floor, in spawn order.
func floor_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_floor_items.keys())
	return result


func floor_item_view(item_id: StringName) -> WorldFloorItemView:
	return _floor_items.get(item_id)


func _selected_floor_item() -> WorldFloorItemView:
	if _selected_target == null or _selected_target.kind != WorldInteractionTarget.Kind.ITEM:
		return null
	return _floor_items.get(_selected_target.target_id)


func _floor_item_content(view: WorldFloorItemView) -> ItemContentDefinition:
	var item: ItemInstance = null if view == null else _item_index.resolve(view.item_instance_id)
	return null if item == null else GameContent.catalog().item(item.item_definition_id)


## look.c sees what lies in the player's own room.
func _floor_item_in_player_zone(view: WorldFloorItemView) -> bool:
	var location: WorldLocationState = null if _player == null else _player.world_location()
	return view != null and location != null and _inventory.is_direct_child(view.item_instance_id, _floor_endpoint(location))


func _refresh_selected_floor_item() -> void:
	var view: WorldFloorItemView = _selected_floor_item()
	if view != null:
		_hud().set_selected_floor_item(view.display_name, view.is_body_in_reach(player_body), false)


func select_floor_item(item_id: StringName) -> bool:
	if not _gameplay_open() or session == null:
		return false
	var view: WorldFloorItemView = _floor_items.get(item_id)
	if view == null:
		return false
	_selected_target = WorldInteractionTarget.item(item_id)
	_hud().set_selected_floor_item(view.display_name, view.is_body_in_reach(player_body))
	return true


## get.c on the selected floor item, with its lines in the log.
func take_selected_floor_item() -> FloorItemPickup.Outcome:
	var view: WorldFloorItemView = _selected_floor_item() if _gameplay_open() and session != null else null
	var content: ItemContentDefinition = _floor_item_content(view)
	var location: WorldLocationState = null if _player == null else _player.world_location()
	if view == null or content == null or location == null:
		return FloorItemPickup.Outcome.INVALID_REQUEST
	var outcome: FloorItemPickup.Outcome = FloorItemPickup.take(
		_player, view.item_instance_id, _floor_endpoint(location), view.is_body_in_reach(player_body), _inventory, _item_index,
	)
	match outcome:
		FloorItemPickup.Outcome.TAKEN:
			_floor_items.erase(view.item_instance_id)
			view.queue_free()
			_selected_target = null
			_hud().set_selected_target(null)
			_hud().append_log_lines([tr("你捡起一%s%s。") % [content.unit, content.display_name]])
			if _hud().inventory_is_open():
				_hud().show_inventory(session.player_inventory_rows())
		FloorItemPickup.Outcome.BUSY:
			_hud().append_log_lines([tr("你上一个动作还没有完成！")])
		FloorItemPickup.Outcome.NOT_HERE:
			_hud().append_log_lines([tr("你附近没有这样东西。")])
		FloorItemPickup.Outcome.NO_GET:
			_hud().append_log_lines([tr("这个东西拿不起来。")])
		FloorItemPickup.Outcome.TOO_HEAVY:
			_hud().append_log_lines([tr("%s对你而言太重了。") % content.display_name])
	return outcome


## A body for `npc` at `position`; `at` keeps a respawned NPC in its spawn order.
func _add_npc_body(npc: NpcRuntimeState, position: Vector2, at: int = -1) -> bool:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(npc.spawn_id)
	if spawn == null or not _map_characters.register_npc(npc):
		return false
	var body: WorldNpcBody2D = NpcBodyScene.instantiate() as WorldNpcBody2D
	body.name = String(npc.spawn_point_id).replace(".", "_")
	body.configure_npc(spawn, npc.definition())
	# Enter the physics space already at the spawn point, never at the origin.
	var parent: Node = _characters_node()
	body.position = (parent as Node2D).to_local(position) if parent is Node2D else position
	parent.add_child(body)
	if at < 0 or at > _npcs.size():
		_npcs.append(npc)
	else:
		_npcs.insert(at, npc)
	if not body.bind_world_simulation_gate(_world_simulation_gate) or not body.bind_npc(npc):
		return false
	_connect_npc_body(npc.character_id, body, body.presence())
	return true


func _characters_node() -> Node:
	var node: Node = get_node_or_null("Characters")
	return self if node == null else node


func _connect_npc_body(character_id: StringName, body: WorldCharacterBody2D, presence: Area2D) -> void:
	_npc_bodies[character_id] = body
	_npc_presence[character_id] = presence
	body.selection_requested.connect(_on_npc_selection_requested)
	presence.body_entered.connect(_on_presence_entered.bind(character_id))
	presence.body_exited.connect(_on_presence_exited.bind(character_id))


## Binds an already-created NPC to a caller-owned physical body. This does not
## author a spawn, initialize a character, or establish combat relationships.
func register_npc_body(npc: NpcRuntimeState, body: WorldCharacterBody2D, presence: Area2D, content: CombatSliceContentProfile) -> bool:
	if (
		not _initialized or not _gameplay_open()
		or npc == null or not npc.is_valid() or not npc.exists_in_map
		or npc.character_id == _player.character_id or find_resident_npc(npc.character_id) != null
		or not is_instance_valid(body) or not is_ancestor_of(body)
		or not body.character_id.is_empty() or body.player_controlled
		or not body.get_node_or_null("CollisionShape2D") is CollisionShape2D
		or not is_instance_valid(presence) or not body.is_ancestor_of(presence)
		or npc.world_location().map_id != map
		or _map_characters.has_character(npc.character_id)
		or WorldCombatBindingAdapter.from_npc(npc, content) == null
	):
		return false
	if not _map_characters.register_npc(npc):
		return false
	if not body.bind_world_simulation_gate(_world_simulation_gate) or not body.bind_npc(npc):
		_map_characters.remove_character(npc.character_id)
		return false
	_registered_npc_content[npc.character_id] = content
	_npcs.append(npc)
	_connect_npc_body(npc.character_id, body, presence)
	return true


## Caller owns physical-node removal. Never detach a live Encounter participant.
func unregister_npc_body(character_id: StringName) -> bool:
	if not _gameplay_open() or not _registered_npc_content.has(character_id):
		return false
	var npc: NpcRuntimeState = find_resident_npc(character_id)
	if npc == null or npc.relationship.is_fighting():
		return false
	var body: WorldCharacterBody2D = _npc_bodies[character_id]
	if is_instance_valid(body):
		body.selection_requested.disconnect(_on_npc_selection_requested)
	var area: Area2D = _npc_presence[character_id]
	if is_instance_valid(area):
		area.body_entered.disconnect(_on_presence_entered.bind(character_id))
		area.body_exited.disconnect(_on_presence_exited.bind(character_id))
	_npc_bodies.erase(character_id)
	_npc_presence.erase(character_id)
	_registered_npc_content.erase(character_id)
	_npcs.erase(npc)
	_map_characters.remove_character(character_id)
	_aggression.clear_npc(character_id)
	if selected_character_id() == character_id:
		_selected_target = null
	return true


func npc_runtimes() -> Array[NpcRuntimeState]:
	return _npcs.duplicate()


func resident_npcs() -> Array[NpcRuntimeState]:
	return _npcs.duplicate()


func find_resident_npc(character_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in _npcs:
		if npc.character_id == character_id:
			return npc
	return null


## Where a save puts an NPC: its body, or the end of the walk it is on.
func npc_rest_position(character_id: StringName) -> Vector2:
	var body: WorldCharacterBody2D = runtime_body_for_character(character_id)
	return Vector2.INF if body == null else npc_walker().rest_position(character_id, body)


func runtime_body_for_character(character_id: StringName) -> WorldCharacterBody2D:
	if _player != null and character_id == _player.character_id:
		return player_body
	return _npc_bodies.get(character_id)


## The body of the NPC spawned at `spawn_point_id` (a spawns[] point).
func runtime_body_for_spawn_point(spawn_point_id: StringName) -> WorldCharacterBody2D:
	for npc: NpcRuntimeState in _npcs:
		if npc.spawn_point_id == spawn_point_id:
			return _npc_bodies.get(npc.character_id)
	return null


func _character_bodies() -> Array[WorldCharacterBody2D]:
	var result: Array[WorldCharacterBody2D] = [player_body]
	result.append_array(_npc_bodies.values())
	return result


# --- Aggression ------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not _initialized or not _gameplay_open():
		return
	for npc: NpcRuntimeState in _npcs:
		if _zone_entry(npc.world_location()) == &"complete_set" and not _complete_entry_contact(npc.character_id):
			_complete_set_consumed_contacts.erase(npc.character_id)
	if _aggression.pending_count() > 0 or _zone_entry(_player.world_location()) == &"complete_set":
		process_pending_aggression()
	if _selected_target != null and _selected_target.kind == WorldInteractionTarget.Kind.ITEM:
		if _floor_items.has(_selected_target.target_id):
			_refresh_selected_floor_item()
		else:
			_refresh_selected_corpse()
	if _selected_target != null and _selected_target.kind == WorldInteractionTarget.Kind.LANDMARK:
		_refresh_selected_landmark_source()


static func _zone_entry(location: WorldLocationState) -> StringName:
	var zone: ZoneDefinition = null if location == null else GameContent.catalog().zone(location.zone_id)
	return &"" if zone == null else zone.combat_entry


## combatd.c start_aggressive/hatred/vendetta return in a no_fight room; an
## NPC's own zone counts too, since presence can reach across a zone edge.
func _combat_allowed(npc: NpcRuntimeState = null) -> bool:
	var location: WorldLocationState = _player.world_location()
	if location == null or location.map_id != map:
		return false
	var catalog: ContentCatalog = GameContent.catalog()
	if catalog.zone_forbids_fighting(location.zone_id):
		return false
	return npc == null or not catalog.zone_forbids_fighting(npc.world_location().zone_id)


## A complete-set zone polls exact contact instead of queueing pair entries.
func _on_presence_entered(body: Node2D, character_id: StringName) -> void:
	var npc: NpcRuntimeState = find_resident_npc(character_id)
	if _gameplay_open() and body == player_body and npc != null and _zone_entry(npc.world_location()) != &"complete_set":
		_aggression.enter_player_presence(npc, _player, _combat_allowed(npc))


func _on_presence_exited(body: Node2D, character_id: StringName) -> void:
	if body == player_body and not _complete_entry_contact(character_id):
		_complete_set_consumed_contacts.erase(character_id)
	if _gameplay_open() and body == player_body:
		_aggression.leave_player_presence(character_id)


func aggression_adapter() -> NpcAggressionAdapter:
	return _aggression


func last_aggression_decisions() -> Array[NpcAggressionDecision]:
	return _last_aggression_decisions.duplicate()


func last_aggression_initiations() -> Array[CombatSliceInitiationResult]:
	return _last_aggression_initiations.duplicate()


func process_pending_aggression() -> Array[CombatSliceInitiationResult]:
	if not _gameplay_open() or session == null:
		return []
	_last_aggression_initiations.clear()
	if _zone_entry(_player.world_location()) == &"complete_set":
		if collect_complete_combat_entry(CombatTriggerCause.Value.NPC_AGGRESSION).size() > 1:
			_last_aggression_initiations.append(session.combat_encounter_coordinator().start_complete_production(CombatTriggerCause.Value.NPC_AGGRESSION))
		return _last_aggression_initiations.duplicate()
	_last_aggression_decisions = _aggression.resolve_pending(_npcs, _player, _combat_allowed())
	for decision: NpcAggressionDecision in _last_aggression_decisions:
		var npc: NpcRuntimeState = find_resident_npc(decision.npc_id)
		if decision.outcome != NpcAggressionDecision.Outcome.READY or npc == null:
			continue
		_last_aggression_initiations.append(_initiate_lethal_combat(npc.character_id, _player.character_id, "%s attacks on sight" % npc.definition().display_name))
	return _last_aggression_initiations.duplicate()


## Owner decision P2A-M: every eligible aggressive enemy in current physical
## contact, plus a manual target, enters one encounter in stable ID order.
func collect_complete_combat_entry(cause: int, requested_target: StringName = &"") -> Array[CombatSliceCharacterBinding]:
	if not _gameplay_open() or session == null or session.active_map() != self:
		return []
	if cause not in [CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK, CombatTriggerCause.Value.NPC_AGGRESSION]:
		return []
	var manual: bool = cause == CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK
	if (manual and find_resident_npc(requested_target) == null) or (not manual and not requested_target.is_empty()):
		return []
	if player_body._player != _player:
		return []
	var ids: Array[StringName] = []
	var fresh_contact: bool = false
	for npc: NpcRuntimeState in _npcs:
		if npc.exists_in_map:
			var body: WorldCharacterBody2D = runtime_body_for_character(npc.character_id)
			if not is_instance_valid(body) or body._npc != npc or _map_characters.find_npc(npc.character_id) != npc:
				return []
		var contact: bool = _complete_entry_contact(npc.character_id)
		if not contact:
			_complete_set_consumed_contacts.erase(npc.character_id)
		var decision: NpcAggressionDecision = _aggression._evaluate(npc, _player, _combat_allowed(npc))
		var aggressive: bool = contact and decision.outcome in [NpcAggressionDecision.Outcome.READY, NpcAggressionDecision.Outcome.NPC_ALREADY_FIGHTING]
		if aggressive or (manual and npc.character_id == requested_target):
			if ids.has(npc.character_id):
				return []
			ids.append(npc.character_id)
			fresh_contact = fresh_contact or (aggressive and not _complete_set_consumed_contacts.has(npc.character_id))
	if ids.is_empty() or (not manual and not fresh_contact):
		return []
	ids.sort_custom(func(first: StringName, second: StringName) -> bool: return String(first) < String(second))
	ids.push_front(_player.character_id)
	var available: Array[CombatSliceCharacterBinding] = _build_participants()
	var result: Array[CombatSliceCharacterBinding] = []
	for id: StringName in ids:
		var binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(available, id)
		if binding == null or not session.encounter_participant_is_available(id):
			return []
		result.append(binding)
	return result


## Exact current shapes, not cached Area overlap lists or deferred signal order.
func _complete_entry_contact(id: StringName) -> bool:
	var body: WorldCharacterBody2D = runtime_body_for_character(id)
	if not is_instance_valid(body) or not body.is_inside_tree():
		return false
	var area: Area2D = _npc_presence.get(id)
	if not is_instance_valid(area) or not area.monitoring or not area.is_inside_tree():
		return false
	var player_shape: CollisionShape2D = player_body.get_node_or_null("CollisionShape2D")
	if player_shape == null or player_shape.disabled or player_shape.shape == null:
		return false
	for child: Node in area.get_children():
		if child is CollisionShape2D and not child.disabled and child.shape != null:
			if child.shape.collide(child.global_transform, player_shape.shape, player_shape.global_transform):
				return true
	return false


func consume_complete_entry_contacts(ids: Array[StringName]) -> void:
	for id: StringName in ids:
		if _complete_entry_contact(id) and not _complete_set_consumed_contacts.has(id):
			_complete_set_consumed_contacts.append(id)


func _initiate_lethal_combat(initiator_id: StringName, target_id: StringName, log_line: String) -> CombatSliceInitiationResult:
	if not _gameplay_open() or session == null:
		return CombatSliceInitiationResult.new()
	var cause: int = CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK if initiator_id == _player.character_id else CombatTriggerCause.Value.NPC_AGGRESSION
	var result: CombatSliceInitiationResult
	if _zone_entry(_player.world_location()) == &"complete_set":
		result = session.combat_encounter_coordinator().start_complete_production(cause, target_id if cause == CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK else &"")
	else:
		var participants: Array[CombatSliceCharacterBinding] = _build_participants()
		result = session.combat_encounter_coordinator().start_production(
			CombatSliceProjectionBuilder.find_binding(participants, initiator_id),
			CombatSliceProjectionBuilder.find_binding(participants, target_id),
			cause,
		)
	if result.outcome == CombatSliceInitiationResult.Outcome.COMPLETED:
		_hud().append_log_lines([log_line])
	return result


# --- Combat participants and lifecycle publication ----------------------------------

func encounter_combat_bindings(encounter: CombatEncounter) -> Array[CombatSliceCharacterBinding]:
	var result: Array[CombatSliceCharacterBinding] = []
	if not _initialized or encounter == null or not encounter.is_valid():
		return result
	var current: Array[CombatSliceCharacterBinding] = _build_participants(true)
	for participant: CombatParticipant in encounter.participants():
		var binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(current, participant.participant_id)
		if (
			binding == null
			or binding.state != participant.binding.state
			or binding.relationship != participant.binding.relationship
			or binding.busy != participant.binding.busy
			or binding.armor != participant.binding.armor
		):
			return []
		result.append(binding)
	return result


func encounter_skill_effect_registry() -> SkillImprovementEffectRegistry:
	return _effects


func last_player_content_resolution() -> WorldWeaponContentResolution:
	return _last_player_content_resolution


func _build_participants(include_absent: bool = false) -> Array[CombatSliceCharacterBinding]:
	var result: Array[CombatSliceCharacterBinding] = []
	_last_player_content_resolution = _weapon_resolver.resolve(_player, _inventory, _item_index)
	var player_binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_player(
		_player,
		_last_player_content_resolution.content_profile if _last_player_content_resolution.succeeded else null,
	)
	if player_binding != null:
		result.append(player_binding)
	for npc: NpcRuntimeState in _npcs:
		if not include_absent and not npc.exists_in_map:
			continue
		var content: CombatSliceContentProfile = _registered_npc_content.get(npc.character_id, _authored_weapon_profile(npc.definition()))
		var binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_npc(npc, content)
		if binding != null:
			result.append(binding)
	return result


## The weapon an NPC is authored to wield, as its verified combat weapon.
static func _authored_weapon_profile(definition: NpcDefinition) -> CombatSliceContentProfile:
	for entry: NpcLoadoutEntry in definition.loadout_entries():
		if entry.equipment_intent != NpcLoadoutEntry.EquipmentIntent.WIELD_PRIMARY:
			continue
		var content: ItemContentDefinition = GameContent.catalog().item(entry.item_definition_id)
		if content != null and content.weapon_definition() != null:
			return CombatSliceContentProfile.new(content.item_definition_id, content.weapon_skill_type, content.weapon_damage)
	return CombatSliceContentProfile.new(&"", &"", 0)


func last_lifecycle_results() -> Array[CombatSliceLifecycleResult]:
	return _last_lifecycle_results.duplicate()


func lifecycle_is_pending() -> bool:
	return _lifecycle_failed


## Map-owned physical publication; rules remain in the existing lifecycle/death
## services. Encounter calls this only at its synchronous outer boundary.
func execute_encounter_lifecycle(victim: CombatSliceCharacterBinding, opportunity: CombatSliceOpportunityResult, participants: Array[CombatSliceCharacterBinding], last_hitter_id: StringName = &"") -> CombatSliceLifecycleResult:
	if _lifecycle_failed:
		return CombatSliceLifecycleResult.new()
	# Read before the lifecycle clears lethal relations and moves the body.
	var is_player: bool = _player != null and victim.character_id == _player.character_id
	var killer: CombatSliceCharacterBinding = _find_killer(victim, participants, last_hitter_id)
	var location: WorldLocationState = _location_for_character(victim.character_id)
	var receipt: CombatSliceLifecycleResult = _execute_lifecycle(victim, opportunity, participants, killer)
	_last_lifecycle_results.append(receipt)
	if not receipt.completed():
		_lifecycle_failed = true
	elif is_player and session != null:
		session.on_player_lifecycle(receipt, killer != null, location)
	elif receipt.outcome == CombatSliceLifecycleResult.Outcome.UNCONSCIOUS_COMPLETE and session != null:
		# damage.c unconcious(): call_out("revive", random(100 - con) + 30).
		var npc: NpcRuntimeState = find_resident_npc(victim.character_id)
		if npc != null:
			npc.set_revive_in_ms(1000 * UnconsciousReviveDelay.seconds(npc.character_state.attributes.constitution, session.npc_revive_random_source()))
	return receipt


## One step of NPC heart_beat time (NpcHeartbeat); the session decides when it flows.
func advance_npc_heartbeat(delta: float) -> void:
	if not _initialized or session == null:
		return
	if _npc_heartbeat == null:
		_npc_heartbeat = NpcHeartbeat.new(session.npc_recovery_random_source())
	for npc: NpcRuntimeState in _npc_heartbeat.advance(delta, npc_runtimes()):
		var body: WorldCharacterBody2D = runtime_body_for_character(npc.character_id)
		if body != null:
			body.refresh_runtime_state()
		# combatd.c announce("revive"), heard in the same room.
		if _player != null and npc.world_location().zone_id == _player.world_location().zone_id:
			_hud().append_log_lines([tr("%s慢慢睁开眼睛，清醒了过来。") % npc.definition().display_name])
	_advance_ambience(delta)


# --- Room reset ----------------------------------------------------------------------

## std/room.c reset() for one ES2 room's set("objects") on this map: a new NPC
## where one died (make_inventory() for a destructed object), the others called
## home (npc.c return_home()), and an item laid down again once the one it put
## there is gone from the world (owner, DECISIONS 4D).
func reset_room(legacy_room: String) -> void:
	if not _initialized or session == null:
		return
	var catalog: ContentCatalog = GameContent.catalog()
	for spawn: NpcSpawnDefinition in catalog.spawns_for_map(map):
		if spawn.legacy_source_room_path != legacy_room:
			continue
		for point_id: StringName in spawn.spawn_point_ids():
			var npc: NpcRuntimeState = _npc_at_point(point_id)
			if npc == null:
				continue
			if npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
				_respawn_npc(spawn, npc)
			elif npc.world_location().zone_id != spawn.zone_id:
				return_home(npc)
	for spawn: ItemSpawnDefinition in catalog.item_spawns_for_map(map):
		if spawn.legacy_source_room_path != legacy_room:
			continue
		for point_id: StringName in spawn.spawn_point_ids():
			if not _inventory.is_registered(ItemSpawnDefinition.item_instance_id(_item_id_allocator.scope, point_id)):
				if not _place_floor_item(spawn, point_id):
					push_error("room reset could not lay %s on %s" % [spawn.item_definition_id, point_id])


func _npc_at_point(point_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in _npcs:
		if npc.spawn_point_id == point_id:
			return npc
	return null


## make_inventory() where an NPC died: a new one, its create() drawn afresh from
## the NPC stream, on its marker and in its old place in spawn order.
func _respawn_npc(spawn: NpcSpawnDefinition, dead: NpcRuntimeState) -> bool:
	var catalog: ContentCatalog = GameContent.catalog()
	var marker: WorldSpawnMarker2D = resolve_spawn_marker(dead.spawn_point_id)
	var fresh: NpcRuntimeState = NpcCharacterStateFactory.new().create_one(
		catalog.npc(spawn.npc_definition_id),
		NpcGeneration.next(dead.character_id, dead.spawn_point_id),
		spawn.spawn_id,
		dead.spawn_point_id,
		location_for_zone(spawn.zone_id),
		_inventory,
		_stacks,
		_npc_random,
		catalog.loadout_item_definitions(),
		_item_id_allocator.scope,
	)
	if marker == null or fresh == null or not _register_loadout(fresh):
		push_error("room reset could not make a new NPC at %s" % dead.spawn_point_id)
		return false
	var at: int = _npcs.find(dead)
	_drop_npc(dead)
	return _add_npc_body(fresh, marker.global_position, at)


## Forgets a dead NPC the room has replaced; its corpse stays.
func _drop_npc(npc: NpcRuntimeState) -> void:
	var character_id: StringName = npc.character_id
	var body: WorldCharacterBody2D = _npc_bodies.get(character_id)
	if is_instance_valid(body):
		body.selection_requested.disconnect(_on_npc_selection_requested)
		body.name = "%s_replaced" % body.name
		body.queue_free()
	_npc_bodies.erase(character_id)
	_npc_presence.erase(character_id)
	_npcs.erase(npc)
	_map_characters.remove_character(character_id)
	_aggression.clear_npc(character_id)
	if _ambience != null:
		_ambience.cancel_greeting(character_id)
	if _walker != null:
		_walker.cancel(character_id)
	if _npc_heartbeat != null:
		_npc_heartbeat.forget(character_id)
	if selected_character_id() == character_id:
		_selected_target = null
		if _hud() != null:
			_hud().set_selected_target(null)


## npc.c return_home(): a conscious NPC that is not fighting leaves for home
## (急急忙忙地离开了。 where it was); move() says nothing where it arrives. The body
## walks home on the map the player is on and is simply there elsewhere.
func return_home(npc: NpcRuntimeState) -> bool:
	var catalog: ContentCatalog = GameContent.catalog()
	var spawn: NpcSpawnDefinition = catalog.spawn(npc.spawn_id)
	var from_zone_id: StringName = npc.world_location().zone_id
	if spawn == null or from_zone_id == spawn.zone_id:
		return true
	var zone: ZoneDefinition = catalog.zone(from_zone_id)
	if (
		npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or npc.relationship.is_fighting()
		or zone == null or catalog.room(zone.room_ids()[0]).exits().is_empty()
	):
		return false
	var seen: bool = _player_shares_zone(npc)
	var body: WorldCharacterBody2D = runtime_body_for_character(npc.character_id)
	var marker: WorldSpawnMarker2D = resolve_spawn_marker(npc.spawn_point_id)
	if body == null or marker == null:
		return false
	npc_walker().cancel(npc.character_id)
	var watched: bool = session != null and session.active_map() == self
	if not watched or not npc_walker().walk_to(npc.character_id, body, physical_zone(from_zone_id), physical_zone(spawn.zone_id), marker.global_position):
		body.global_position = marker.global_position
	npc.set_world_location(location_for_zone(spawn.zone_id))
	if seen:
		_hud().append_log_lines([tr("%s急急忙忙地离开了。") % npc.definition().display_name])
	return true


# --- Talk, greetings and wandering ---------------------------------------------------

## npc.c chat() and random_move(), and greetings, on NPC heart_beat time (NpcAmbience).
func _advance_ambience(delta: float) -> void:
	if _ambience == null:
		_ambience = NpcAmbience.new(session.npc_ambience_random_source())
	_ambience.set_random(session.npc_ambience_random_source())
	_note_player_arrival()
	for character_id: StringName in _ambience.due_greetings(delta):
		_greet(find_resident_npc(character_id))
	for beat: int in _ambience.due_beats(delta):
		for npc: NpcRuntimeState in _npcs.duplicate():
			if _chats(npc):
				_act(npc, _ambience.chat(npc.definition().talk()))
	npc_walker().advance(delta)


func npc_walker() -> WorldNpcWalker:
	if _walker == null:
		_walker = WorldNpcWalker.new(self)
	return _walker


## The NPCs' init() when the player comes into a place: a greeting call_out.
func _note_player_arrival() -> void:
	var zone_id: StringName = &"" if _player == null or not _player.exists_in_world else _player.world_location().zone_id
	if zone_id == _arrival_zone_id:
		return
	_arrival_zone_id = zone_id
	for npc: NpcRuntimeState in _npcs:
		if (
			npc.world_location().zone_id == zone_id and npc.exists_in_map
			and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
			and not npc.relationship.is_fighting()
			and not npc.definition().talk().greeting_say.is_empty()
		):
			_ambience.start_greeting(npc.character_id)


## keeper.c greeting(): said only if the player is still there.
func _greet(npc: NpcRuntimeState) -> void:
	if npc == null or not npc.exists_in_map or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or not _player_shares_zone(npc):
		return
	var respect: String = RankWords.query_respect(_player.state.gender, _player.facts.age, _player.state.affiliation.class_id)
	var text: String = NpcTalk.line(npc.definition().talk().greeting_say).replace("$RESPECT", tr(respect))
	_hud().append_log_lines([tr("%s说道：%s") % [npc.definition().display_name, text]])


func _player_shares_zone(npc: NpcRuntimeState) -> bool:
	return (
		_player != null and _player.exists_in_world
		and npc.world_location().map_id == _player.world_location().map_id
		and npc.world_location().zone_id == _player.world_location().zone_id
	)


## char.c heart_beat() reaches chat() for a conscious NPC that is neither busy nor
## fighting, and beats while the player is in its place. A walking NPC is still
## making its last move. Deviation: an unconscious NPC says nothing (DECISIONS 4D).
func _chats(npc: NpcRuntimeState) -> bool:
	return (
		npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
		and not npc.relationship.is_fighting() and not npc.busy.is_busy()
		and npc.definition().talk().has_chat() and _player_shares_zone(npc)
		and not npc_walker().is_walking(npc.character_id)
	)


func _act(npc: NpcRuntimeState, entry: Variant) -> void:
	if entry is String:
		_hud().append_log_lines([NpcTalk.line(entry)])
	elif entry is StringName and entry == NpcTalk.RANDOM_MOVE:
		random_move(npc)


## npc.c random_move() through go.c, within the NPC's range (NpcRandomMove). The
## body walks; its place changes now. False when nothing moved.
func random_move(npc: NpcRuntimeState) -> bool:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(npc.spawn_id)
	var from_zone_id: StringName = npc.world_location().zone_id
	if spawn == null or _ambience == null:
		return false
	var move: NpcRandomMove.Move = NpcRandomMove.choose(GameContent.catalog(), from_zone_id, spawn.zone_id, _ambience.random(), _door_closed_between)
	if move == null:
		return false
	var seen: bool = _player_shares_zone(npc)
	if not npc_walker().walk_into(npc.character_id, runtime_body_for_character(npc.character_id), physical_zone(from_zone_id), physical_zone(move.to_zone_id), _ambience.random()):
		return false
	npc.set_world_location(location_for_zone(move.to_zone_id))
	if seen:
		_hud().append_log_lines([tr(move.leave_line(npc.definition().display_name))])
	return true


## room.c valid_leave(): a closed door between the two zones stops the move.
func _door_closed_between(from_zone_id: StringName, to_zone_id: StringName) -> bool:
	for door: WorldDoor in doors():
		var definition: DoorDefinition = GameContent.catalog().door(door.door_id)
		if definition != null and definition.zone_ids().has(from_zone_id) and definition.zone_ids().has(to_zone_id) and not door.is_open():
			return true
	return false


## A corpse lies where its body fell. It is wider than the body, so beside a wall it is
## shifted (sideways first, at most 40 px, same zone) until it fits; Continue validates it.
func _corpse_position(death_position: Vector2, death_location: WorldLocationState) -> Vector2:
	if death_location == null or MapPlacementValidator.is_valid_corpse_position(self, death_location.zone_id, death_position):
		return death_position
	for distance: int in range(8, 41, 8):
		for offset: Vector2 in [Vector2(distance, 0), Vector2(-distance, 0), Vector2(0, distance), Vector2(0, -distance)]:
			if MapPlacementValidator.is_valid_corpse_position(self, death_location.zone_id, death_position + offset):
				return death_position + offset
	return death_position


func _execute_lifecycle(victim: CombatSliceCharacterBinding, opportunity: CombatSliceOpportunityResult, participants: Array[CombatSliceCharacterBinding], killer: CombatSliceCharacterBinding) -> CombatSliceLifecycleResult:
	var body: WorldCharacterBody2D = runtime_body_for_character(victim.character_id)
	var death_position: Vector2 = Vector2.ZERO if body == null else body.global_position
	var death_location: WorldLocationState = _location_for_character(victim.character_id)
	var destination: InventoryTransferDestination = _world_destination_for(victim.character_id)
	var allocation: SessionItemIdAllocationResult = _item_id_allocator.allocate(_inventory)
	if not allocation.succeeded:
		return CombatSliceLifecycleResult.new()
	var lifecycle: CombatSliceLifecycleResult = CombatSliceLifecycleAdapter.new().execute(
		opportunity,
		victim,
		participants,
		killer,
		_inventory,
		_stacks,
		allocation.item_instance_id,
		destination,
		_death_item_facts_for(victim.character_id),
		DeathItemPolicyRegistry.new(),
		DeathRewearPolicyRegistry.new(),
		_death_context_for(victim, killer, destination),
	)
	if lifecycle.completed():
		_sync_binding(victim)
		if body != null:
			body.refresh_runtime_state()
	var corpse: CorpseState = null if lifecycle.death_inventory_result == null else lifecycle.death_inventory_result.corpse_state
	if corpse == null:
		return lifecycle
	var view: CombatSliceCorpseView = _add_corpse_view(corpse, _corpse_position(death_position, death_location), death_location)
	if view == null:
		lifecycle._outcome = CombatSliceLifecycleResult.Outcome.WORLD_PUBLICATION_FAILED
		return lifecycle
	# Phase 6B3 keeps a partial corpse mutation and its view even when death
	# cannot complete; only a completed, indexed death becomes a loot interaction.
	if lifecycle.outcome != CombatSliceLifecycleResult.Outcome.DEATH_COMPLETE:
		return lifecycle
	if not _item_index.register_snapshot(ItemInstance.new(corpse.corpse_item_instance_id, CombatSliceDeathAdapter.CORPSE_DEFINITION_ID)):
		lifecycle._outcome = CombatSliceLifecycleResult.Outcome.WORLD_PUBLICATION_FAILED
		return lifecycle
	_make_corpse_interactive(view)
	return lifecycle


## A restored corpse is already indexed and interactive.
func _publish_corpse_view(corpse: CorpseState, position: Vector2, location: WorldLocationState) -> bool:
	var view: CombatSliceCorpseView = _add_corpse_view(corpse, position, location)
	if view == null:
		return false
	_make_corpse_interactive(view)
	return true


func _add_corpse_view(corpse: CorpseState, position: Vector2, location: WorldLocationState) -> CombatSliceCorpseView:
	_corpse_states.append(corpse)
	if location != null:
		_corpse_locations[corpse.corpse_item_instance_id] = location.duplicate_snapshot()
	var view: CombatSliceCorpseView = CombatSliceCorpseView.new()
	if not view.configure(corpse):
		view.free()
		return null
	view.global_position = position
	_corpse_layer().add_child(view)
	return view


func _make_corpse_interactive(view: CombatSliceCorpseView) -> void:
	_corpse_views[view.corpse_item_instance_id] = view
	view.selection_requested.connect(select_corpse)
	view.loot_range_changed.connect(_on_corpse_loot_range_changed)


func _corpse_layer() -> Node2D:
	var layer: Node2D = get_node_or_null("CorpseLayer") as Node2D
	if layer == null:
		layer = Node2D.new()
		layer.name = "CorpseLayer"
		add_child(layer)
	return layer


func _death_context_for(victim: CombatSliceCharacterBinding, killer: CombatSliceCharacterBinding, destination: InventoryTransferDestination) -> DeathContext:
	if _player != null and victim.character_id == _player.character_id:
		return _player.death_context(destination, killer != null)
	var fallback: PlayerIdentityFacts = PlayerIdentityFacts.legacy_technical()
	var display_name: String = fallback.display_name
	var age: int = fallback.age
	var strength: int = victim.state.attributes.strength
	var body_weight: int = CharacterDerivedValues.human_weight(strength)
	var maximum_encumbrance: int = CharacterDerivedValues.maximum_encumbrance(strength)
	var npc: NpcRuntimeState = find_resident_npc(victim.character_id)
	if npc != null:
		display_name = npc.definition().display_name
		age = npc.age
		# chard.c copies query_weight/query_max_encumbrance, not a fresh race setup.
		body_weight = npc.body_weight
		maximum_encumbrance = npc.maximum_encumbrance
	return DeathContext.new(
		victim.character_id,
		false,
		false,
		destination,
		ItemLifecycleOwnerContext.new(victim.character_id, victim.state.equipment, victim.armor),
		display_name,
		victim.state.gender,
		age,
		body_weight,
		maximum_encumbrance,
		false,
		destination.endpoint if killer != null else null,
		victim.state.gender,
		killer != null,
	)


func _death_item_facts_for(character_id: StringName) -> Array[DeathItemFacts]:
	var facts: Array[DeathItemFacts] = []
	var endpoint: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, character_id)
	# Current direct inventory, not the original bootstrap loadout or only sword.
	for item_id: StringName in _inventory.direct_children(endpoint):
		var item: ItemInstance = _item_index.resolve(item_id)
		if item == null:
			continue # Existing death validator fails closed on incomplete facts.
		var content: ItemContentDefinition = GameContent.catalog().item(item.item_definition_id)
		facts.append(DeathItemFacts.new(item, null if content == null else content.armor_definition()))
	return facts


func _sync_binding(binding: CombatSliceCharacterBinding) -> void:
	if binding.character_id == _player.character_id:
		WorldCombatBindingAdapter.sync_player(binding, _player)
		return
	var npc: NpcRuntimeState = find_resident_npc(binding.character_id)
	if npc != null:
		WorldCombatBindingAdapter.sync_npc(binding, npc)


func _location_for_character(character_id: StringName) -> WorldLocationState:
	if _player != null and character_id == _player.character_id:
		return _player.world_location()
	var npc: NpcRuntimeState = find_resident_npc(character_id)
	return null if npc == null else npc.world_location()


func _world_destination_for(character_id: StringName) -> InventoryTransferDestination:
	var location: WorldLocationState = _location_for_character(character_id)
	return InventoryTransferDestination.new(
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, location.combat_location_id),
		true,
		true,
		WORLD_CAPACITY,
	)


## damage.c die(): the killer is last_damage_from, whoever hit the victim last,
## fight or kill. Without a hit in hand (a fall settled later) a participant
## holding a kill mark on either side stands in.
static func _find_killer(victim: CombatSliceCharacterBinding, participants: Array[CombatSliceCharacterBinding], last_hitter_id: StringName = &"") -> CombatSliceCharacterBinding:
	for candidate: CombatSliceCharacterBinding in participants:
		if candidate != victim and not last_hitter_id.is_empty() and candidate.character_id == last_hitter_id:
			return candidate
	for candidate: CombatSliceCharacterBinding in participants:
		if candidate != victim and (candidate.relationship.has_lethal_target(victim.character_id) or victim.relationship.has_lethal_target(candidate.character_id)):
			return candidate
	return null


# --- Corpses -----------------------------------------------------------------------

func corpse_states() -> Array[CorpseState]:
	return _corpse_states.duplicate()


func corpse_view_for(corpse_id: StringName) -> CombatSliceCorpseView:
	return _corpse_views.get(corpse_id)


func corpse_world_location(corpse_id: StringName) -> WorldLocationState:
	var location: WorldLocationState = _corpse_locations.get(corpse_id)
	return null if location == null else location.duplicate_snapshot()


func last_loot_transfer_result() -> CorpseLootTransferResult:
	return _last_loot_transfer_result


func _find_corpse(corpse_id: StringName) -> CorpseState:
	for corpse: CorpseState in _corpse_states:
		if corpse.corpse_item_instance_id == corpse_id:
			return corpse
	return null


func _selected_corpse() -> CorpseState:
	if _selected_target == null or _selected_target.kind != WorldInteractionTarget.Kind.ITEM:
		return null
	return _find_corpse(_selected_target.target_id)


func _corpse_is_live_in_world(corpse: CorpseState) -> bool:
	if (
		corpse == null
		or not _inventory.is_registered(corpse.corpse_item_instance_id)
		or not _item_index.has_snapshot(corpse.corpse_item_instance_id)
		or not _corpse_views.has(corpse.corpse_item_instance_id)
	):
		return false
	var parent: ContainmentEndpoint = _inventory.direct_parent(corpse.corpse_item_instance_id)
	return parent != null and parent.kind == ContainmentEndpoint.Kind.WORLD


func _corpse_content_count(corpse: CorpseState) -> int:
	if corpse == null:
		return 0
	return _inventory.direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id)).size()


func _player_is_in_corpse_loot_range(corpse_id: StringName) -> bool:
	var view: CombatSliceCorpseView = _corpse_views.get(corpse_id)
	return view != null and view.is_body_in_loot_range(player_body)


func _refresh_selected_corpse() -> void:
	var corpse: CorpseState = _selected_corpse()
	if corpse == null or not _corpse_is_live_in_world(corpse):
		if _selected_target != null and _selected_target.kind == WorldInteractionTarget.Kind.ITEM:
			_selected_target = null
		_hud().set_selected_corpse("", 0, false, true)
		return
	_hud().set_selected_corpse(corpse.victim_display_name, _corpse_content_count(corpse), _player_is_in_corpse_loot_range(corpse.corpse_item_instance_id), false)


func _on_corpse_loot_range_changed(corpse_id: StringName, body: Node2D, _is_inside: bool) -> void:
	if _gameplay_open() and body == player_body and _selected_target != null and _selected_target.kind == WorldInteractionTarget.Kind.ITEM and _selected_target.target_id == corpse_id:
		_refresh_selected_corpse()


func _refresh_loot_panel(corpse: CorpseState) -> void:
	_hud().show_loot("Corpse of %s" % corpse.victim_display_name, _loot.project_rows(corpse, _inventory, _stacks, _item_index))


# --- Selection: NPCs, landmarks, corpses --------------------------------------------

func selected_interaction_target() -> WorldInteractionTarget:
	return _selected_target


func selected_character_id() -> StringName:
	if _selected_target == null or _selected_target.kind != WorldInteractionTarget.Kind.CHARACTER:
		return &""
	return _selected_target.target_id


func selected_npc() -> NpcRuntimeState:
	return find_resident_npc(selected_character_id())


func _on_npc_selection_requested(character_id: StringName) -> void:
	select_npc(character_id)


func select_npc(character_id: StringName) -> bool:
	if not _gameplay_open() or session == null:
		return false
	var npc: NpcRuntimeState = find_resident_npc(character_id)
	if npc == null or not npc.exists_in_map or npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
		return false
	_selected_target = WorldInteractionTarget.character(character_id)
	_hud().set_selected_target(npc)
	return true


func select_landmark(landmark_id: StringName) -> bool:
	if not _gameplay_open() or session == null or not _landmark_areas.has(landmark_id):
		return false
	var landmark: WorldLandmarkDefinition = GameContent.catalog().landmark(landmark_id)
	_selected_target = WorldInteractionTarget.landmark(landmark_id)
	_selected_landmark_available = landmark_available(landmark)
	_hud().set_selected_landmark(landmark, _selected_landmark_available)
	return true


func select_corpse(corpse_id: StringName) -> bool:
	if not _gameplay_open() or session == null:
		return false
	var corpse: CorpseState = _find_corpse(corpse_id)
	if corpse == null or not _corpse_is_live_in_world(corpse):
		return false
	_selected_target = WorldInteractionTarget.item(corpse_id)
	_hud().set_selected_corpse(corpse.victim_display_name, _corpse_content_count(corpse), _player_is_in_corpse_loot_range(corpse_id))
	return true


func inspect_selected() -> bool:
	if not _gameplay_open() or session == null or _selected_target == null:
		return false
	match _selected_target.kind:
		WorldInteractionTarget.Kind.ITEM:
			var floor_view: WorldFloorItemView = _selected_floor_item()
			if floor_view != null:
				var floor_content: ItemContentDefinition = _floor_item_content(floor_view)
				if floor_content == null or not _floor_item_in_player_zone(floor_view):
					return false
				_hud().show_item_inspection(floor_content.display_name, floor_content.description)
				return true
			var corpse: CorpseState = _find_corpse(_selected_target.target_id)
			if corpse == null or not _corpse_is_live_in_world(corpse):
				return false
			_hud().show_corpse_inspection(corpse.victim_display_name, _corpse_content_count(corpse))
			return true
		WorldInteractionTarget.Kind.LANDMARK:
			var landmark: WorldLandmarkDefinition = GameContent.catalog().landmark(_selected_target.target_id)
			if landmark == null:
				return false
			_hud().show_landmark_inspection(landmark)
			return true
	var npc: NpcRuntimeState = selected_npc()
	if npc == null or not npc.exists_in_map:
		return false
	_hud().show_inspection(npc.definition())
	return true


func attack_selected() -> CombatSliceInitiationResult:
	var target: NpcRuntimeState = selected_npc() if _gameplay_open() else null
	if target == null:
		return CombatSliceInitiationResult.new()
	# kill.c checks the attacker's room, which in ES2 is also the target's.
	var catalog: ContentCatalog = GameContent.catalog()
	if catalog.zone_forbids_fighting(_player.world_location().zone_id) or catalog.zone_forbids_fighting(target.world_location().zone_id):
		_hud().append_log_lines([tr("这里不准战斗。")])
		return CombatSliceInitiationResult.new()
	return _initiate_lethal_combat(_player.character_id, target.character_id, "Attack initiated against %s" % target.definition().display_name)


## cmds/std/fight.c for the selected NPC: ask a speaking character to spar; it
## accepts or refuses (NpcSparConsent). Beasts are not asked (no button).
func spar_selected() -> CombatSliceInitiationResult:
	var target: NpcRuntimeState = selected_npc() if _gameplay_open() else null
	if target == null or not target.definition().can_speak():
		return CombatSliceInitiationResult.new()
	var catalog: ContentCatalog = GameContent.catalog()
	var name: String = target.definition().display_name
	if catalog.zone_forbids_fighting(_player.world_location().zone_id):
		_hud().append_log_lines([tr("这里禁止战斗。")])
		return CombatSliceInitiationResult.new()
	# present(arg, environment(me)): only someone in the same place can be asked.
	if not target.world_location().shares_combat_location(_player.world_location()):
		_hud().append_log_lines([tr("你想攻击谁？")])
		return CombatSliceInitiationResult.new()
	if target.relationship.has_opponent(_player.character_id):
		_hud().append_log_lines([tr("加油！加油！加油！")])
		return CombatSliceInitiationResult.new()
	if target.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		_hud().append_log_lines([tr("%s已经无法战斗了。") % name])
		return CombatSliceInitiationResult.new()
	var player_state: CharacterState = _player.state
	var lines: Array[String] = [tr("你对著%s说道：%s%s，领教%s的高招！") % [
		name, tr(RankWords.query_self(player_state.gender, _player.facts.age, player_state.affiliation.class_id)),
		_player.facts.display_name, tr(RankWords.query_respect(target.character_state.gender, target.age, &"")),
	]]
	var consent: NpcSparConsent = NpcSparConsent.decide(target, NpcSparConsent.Challenger.new(
		player_state.gender, _player.facts.age, player_state.affiliation.class_id, player_state.family.family_id,
	))
	var result := CombatSliceInitiationResult.new()
	if consent.accepted:
		var participants: Array[CombatSliceCharacterBinding] = _build_participants()
		result = session.combat_encounter_coordinator().start_production(
			CombatSliceProjectionBuilder.find_binding(participants, _player.character_id),
			CombatSliceProjectionBuilder.find_binding(participants, target.character_id),
			CombatTriggerCause.Value.PLAYER_SPAR,
		)
	var started: bool = result.outcome == CombatSliceInitiationResult.Outcome.COMPLETED
	if consent.accepted and not started:
		# Accepted, yet this encounter model cannot hold the fight (e.g. someone
		# else's fight marks): say no rather than accept into nothing.
		if OS.is_debug_build():
			push_warning("Spar with %s accepted but not started: %s" % [target.character_id, CombatSliceInitiationResult.Outcome.find_key(result.outcome)])
	else:
		for line: NpcSparConsent.Line in consent.lines:
			var text: String = tr(line.text).replace("$RESPECT", tr(consent.respect)).replace("$SELF", tr(consent.npc_self))
			lines.append(name + text if line.emote else tr("%s说道：%s") % [name, text])
	if not started:
		lines.append(tr("看起来%s并不想跟你较量。") % name)
	elif not player_state.equipment.is_primary_hand_empty() or not target.character_state.equipment.is_primary_hand_empty():
		# combatd.c wounds on `is_killing || weapon`: unlike a bare-handed spar, a
		# blade draws blood. Native hint; ES2 says nothing here.
		lines.append(tr("刀剑无眼，持兵刃比试可能真的受伤。"))
	_hud().append_log_lines(lines)
	return result


## cmds/std/ask.c: the selected NPC can be asked when it speaks and is here
## (present()); a beast gets no 打听, as it gets no 切磋.
func can_ask_selected() -> bool:
	var target: NpcRuntimeState = selected_npc() if _gameplay_open() else null
	return (
		target != null and target.definition().can_speak() and target.exists_in_map
		and target.life_status != CharacterRuntimeLifeStatus.Value.DEAD
		and _player != null and target.world_location().shares_combat_location(_player.world_location())
	)


## What the selected NPC can be asked about, in ES2's listing order (NpcInquiry).
func ask_topics_selected() -> Array[String]:
	return NpcInquiry.topics(selected_npc().definition()) if can_ask_selected() else []


## ask <npc> about <topic> on the selected NPC; its lines go to the log too.
func ask_selected(topic: String) -> Array[String]:
	if not ask_topics_selected().has(topic):
		return []
	var target: NpcRuntimeState = selected_npc()
	var zone: ZoneDefinition = GameContent.catalog().zone(target.world_location().zone_id)
	var lines: Array[String] = NpcInquiry.ask(
		target.definition(), target.character_state.gender, target.age,
		target.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE,
		NpcInquiry.Asker.new(_player.state.gender, _player.facts.age, _player.state.affiliation.class_id),
		topic, "" if zone == null else zone.display_name, _world_interaction_random,
	)
	_hud().append_log_lines(lines)
	return lines


func open_selected_loot() -> bool:
	if not _gameplay_open() or session == null:
		return false
	_hud().close_inventory()
	if _selected_floor_item() != null:
		_hud().close_loot()
		return take_selected_floor_item() == FloorItemPickup.Outcome.TAKEN
	var corpse: CorpseState = _selected_corpse()
	if corpse == null:
		_hud().close_loot()
		return false
	var validation: int = _loot.validate_open(_player, corpse, _inventory, _item_index, _player_is_in_corpse_loot_range(corpse.corpse_item_instance_id))
	if validation != CorpseLootAdapter.OpenValidation.READY:
		_hud().close_loot()
		_refresh_selected_corpse()
		return false
	_refresh_loot_panel(corpse)
	return true


func take_selected_loot_item(item_instance_id: StringName) -> CorpseLootTransferResult:
	if not _gameplay_open() or session == null:
		return CorpseLootTransferResult.new(CorpseLootTransferResult.Outcome.INVALID_REQUEST, false, &"" if _player == null else _player.character_id, &"", item_instance_id)
	var corpse: CorpseState = _selected_corpse()
	if corpse == null:
		_last_loot_transfer_result = CorpseLootTransferResult.new(CorpseLootTransferResult.Outcome.CORPSE_NOT_AVAILABLE, false, _player.character_id, &"", item_instance_id)
		_hud().close_loot()
		return _last_loot_transfer_result
	_last_loot_transfer_result = _loot.take(_player, corpse, item_instance_id, _player_is_in_corpse_loot_range(corpse.corpse_item_instance_id), _inventory, _stacks, _item_index)
	_refresh_selected_corpse()
	if _hud().loot_is_open():
		if _corpse_is_live_in_world(corpse):
			_refresh_loot_panel(corpse)
		else:
			_hud().close_loot()
	if _hud().inventory_is_open():
		_hud().show_inventory(session.player_inventory_rows())
	return _last_loot_transfer_result


# --- Landmarks and same-map passages ------------------------------------------------

## The player stands in the landmark's zone and, when it needs contact, inside its area.
func landmark_available(landmark: WorldLandmarkDefinition) -> bool:
	if landmark == null or _player == null or not _landmark_areas.has(landmark.landmark_id):
		return false
	var location: WorldLocationState = _player.world_location()
	var zone: ZoneDefinition = GameContent.catalog().zone(landmark.zone_id)
	if location == null or zone == null or location.map_id != map or location.zone_id != zone.zone_id or location.combat_location_id != zone.combat_location_id:
		return false
	return not landmark.requires_contact or _inside_area(_landmark_areas[landmark.landmark_id], player_body.global_position)


static func _inside_area(area: Area2D, point: Vector2) -> bool:
	var collision: CollisionShape2D = area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rectangle: RectangleShape2D = null if collision == null or collision.disabled else collision.shape as RectangleShape2D
	if rectangle == null:
		return false
	var local: Vector2 = collision.to_local(point)
	return absf(local.x) <= rectangle.size.x / 2.0 and absf(local.y) <= rectangle.size.y / 2.0


func _refresh_selected_landmark_source() -> void:
	if _selected_target == null or _selected_target.kind != WorldInteractionTarget.Kind.LANDMARK:
		return
	var available: bool = landmark_available(GameContent.catalog().landmark(_selected_target.target_id))
	if available != _selected_landmark_available:
		_selected_landmark_available = available
		_hud().set_selected_landmark_source_available(available)


## The selected landmark's action (the HUD's portal button).
func traverse_selected_portal() -> RefCounted:
	if not _gameplay_open() or session == null or _selected_target == null or _selected_target.kind != WorldInteractionTarget.Kind.LANDMARK:
		return WorldPortalTraversalResult.new()
	var landmark: WorldLandmarkDefinition = GameContent.catalog().landmark(_selected_target.target_id)
	var policy: WorldLandmarkPolicy = null if landmark == null else WorldLandmarkPolicies.create(landmark.policy)
	if policy == null:
		return WorldPortalTraversalResult.new()
	# The policy reports a wrong source zone itself; only the physical reach is checked here.
	if landmark.requires_contact and not _inside_area(_landmark_areas[landmark.landmark_id], player_body.global_position):
		_refresh_selected_landmark_source()
		return WorldPortalTraversalResult.new()
	var before: WorldLocationState = _player.world_location()
	_last_landmark_use = policy.use(self, landmark)
	if not _player.world_location().same_location(before) and not policy.keeps_selection():
		_selected_target = null
		_hud().set_selected_target(null)
	_refresh_selected_landmark_source()
	return _last_landmark_use


func last_landmark_use() -> RefCounted:
	return _last_landmark_use


## WorldPassageArea2D calls this (deferred) for a portal that stays on this map.
## No current content has one: Old Pine's height changes all cross maps (DECISIONS 3B5).
func traverse_same_map_passage(portal: PortalDefinition) -> void:
	if not _gameplay_open() or portal == null or not is_passage_current(portal):
		return
	_last_passage_traversal = WorldLandmarkPolicy.move_through(self, portal)
	var traversal: WorldPortalTraversalResult = _last_passage_traversal as WorldPortalTraversalResult
	if traversal != null and traversal.completed() and session != null:
		_selected_target = null
		_hud().set_selected_target(null)
		_hud().append_log_lines(["%s: %s" % [portal.legacy_command.capitalize(), GameContent.catalog().zone(portal.destination_zone_id).display_name]])


func last_passage_traversal() -> RefCounted:
	return _last_passage_traversal


# --- Interactions: services, water and doors ----------------------------------------

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
		and MapPlacementValidator.is_valid_character_position(self, zone_id, player_body.global_position)
	)


## A water source (resource/water) is within reach.
func water_available() -> bool:
	for candidate: WorldService in _services:
		if candidate is WaterService and (candidate as WaterService).available():
			return true
	return false


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
