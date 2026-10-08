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
# --- components ---
var corpses: WorldMapCorpses = WorldMapCorpses.new(self)
var floor_items: WorldMapFloorItems = WorldMapFloorItems.new(self)
var selection: WorldMapSelection = WorldMapSelection.new(self)
var npcs: WorldMapNpcs = WorldMapNpcs.new(self)
var _definition: MapDefinition
var _initialized: bool = false
var _initialization_count: int = 0
var _freeze_owner: StringName = &""
var _zones: Array[WorldPhysicalZoneArea2D] = []
var _present_zones: Array[WorldPhysicalZoneArea2D] = []
var _zone_check_pending: bool = false
## The last exit rule that refused the player and when (ms): its lines show once per attempt.
var _last_exit_refusal: StringName = &""
var _last_exit_refusal_ms: int = 0
const EXIT_REFUSAL_REPEAT_MS: int = 2000
## Half a 34 px character body.
const BODY_HALF_EXTENT: float = 17.0
var service_nodes: Array[WorldService] = []
var doors_by_id: Dictionary[StringName, WorldDoor] = {}
var landmark_areas: Dictionary[StringName, WorldLandmarkArea2D] = {}

var _post_actions: CombatSlicePostActions
var _last_player_berserk := CombatSliceInitiationResult.new()
## The NPC whose arrival made the player's init() roll go over: combatd.c
## auto_fight() call_out()s start_berserk(), run on the next world tick (after the
## room's description). Empty when none waits (looking_for_trouble).
var _pending_player_berserk: StringName = &""
var _effects: SkillImprovementEffectRegistry
var _aggression: NpcAggressionAdapter = NpcAggressionAdapter.new()
var _last_aggression_decisions: Array[NpcAggressionDecision] = []
var _last_aggression_initiations: Array[CombatSliceInitiationResult] = []
## Aggressive NPCs of a complete-set zone whose current contact already started
## an encounter; contact must break before it can start another.
var _complete_set_consumed_contacts: Array[StringName] = []
## Seconds each toll-taker (NpcDealings.toll_attack_delay_ms) has been touching the
## player without a break; its greeting attacks once that reaches the delay.
var _toll_contact_seconds: Dictionary[StringName, float] = {}
## Toll-takers put back in the pair queue while their greeting waits.
var _toll_waiting: Dictionary[StringName, bool] = {}
var _weapon_resolver: WorldWeaponContentResolver = WorldWeaponContentResolver.new()
var _last_player_content_resolution: WorldWeaponContentResolution
var _last_lifecycle_results: Array[CombatSliceLifecycleResult] = []
var _lifecycle_failed: bool = false
var _npc_heartbeat: NpcHeartbeat
var _ambience: NpcAmbience
## steal.c between main() and compelete_steal(): {item, sp, dp} by thief.
var _pending_steals: Dictionary[StringName, Dictionary] = {}
## query("thief") of each thief: how often it was caught (not saved, as NPCs are made anew).
var _times_caught: Dictionary[StringName, int] = {}
var _walker: WorldNpcWalker
## The player's place as the NPCs' init() last saw it; another one is an arrival.
var _arrival_zone_id: StringName = &""
var _last_landmark_use: RefCounted
var _last_passage_traversal: RefCounted


## What 切磋 with the selected NPC would be, for the HUD to ask first: DEADLY when its
## accept_fight() answers with kill_ob(), ARMED when a weapon in hand wounds, NONE when
## it is unarmed or will not take place (spar_selected()'s refusals, or the NPC's).
enum SparRisk { NONE, ARMED, DEADLY }


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
	npcs.map_characters = MapCharacterRuntimeState.new(map)
	_effects = SkillImprovementEffectRegistry.new()
	_effects.register_legacy_defaults()
	var restoring: bool = session != null and session.bootstrap_mode() == OldPineWorldSessionController.BootstrapMode.RESTORE
	if not (npcs.restore_actors() if restoring else npcs.spawn_actors()):
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
		service_nodes.append(service)
	return expected.is_empty()


func _bind_doors() -> bool:
	var expected: Dictionary[StringName, bool] = {}
	for definition: DoorDefinition in GameContent.catalog().doors_for_map(map):
		expected[definition.door_id] = true
	for door: WorldDoor in doors():
		if door.wall_shape() == null or not expected.erase(door.door_id):
			return false
		doors_by_id[door.door_id] = door
		door.set_open(GameContent.catalog().door(door.door_id).starts_open)
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
		landmark_areas[area.landmark_id] = area
		area.selection_requested.connect(selection.select_landmark)
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
	selection.selected_target = null
	if hud() != null:
		hud().set_selected_target(null)
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
	if hud() != null:
		hud().refresh_live_state()
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
	selection.selected_target = null
	_aggression.clear_all()
	_toll_contact_seconds.clear()
	_toll_waiting.clear()
	if hud() != null:
		hud().set_selected_target(null)
		hud().close_loot()
		hud().close_inventory()


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
	var refusal: ZoneExitRuleDefinition = _exit_refusal(current.zone_id, zone.zone_id)
	if refusal != null:
		_refuse_exit(refusal, current.zone_id)
		return false
	if session != null:
		session.player_leaving_zone(current.zone_id, zone.zone_id)
	return _player.set_world_location(location_for_zone(zone.zone_id))


## The room's valid_leave() that refuses this way out now, or null.
func _exit_refusal(from_zone_id: StringName, to_zone_id: StringName) -> ZoneExitRuleDefinition:
	var leaver: ZoneExitRuleDefinition.Leaver = ZoneExitRuleDefinition.Leaver.of(_player.state)
	for rule: ZoneExitRuleDefinition in GameContent.catalog().exit_rules_between(from_zone_id, to_zone_id):
		var present: bool = false
		for npc: NpcRuntimeState in npcs.residents:
			present = present or (
				npc.definition().definition_id == rule.present_npc_id and npc.exists_in_map
				and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD and npc.world_location().zone_id == from_zone_id
			)
		if rule.refuses(leaver, present):
			return rule
	return null


## valid_leave() for a passage (d/green/entrance.c east into the 迷阵): a refusal keeps
## the player out of the passage, back in the room, and says why; a way that marks
## whoever takes it (eight7.c set("八卦阵")) marks the player as they go.
func leave_by_passage(portal: PortalDefinition, passage: WorldPassageArea2D) -> bool:
	if portal == null or _player == null:
		return false
	var refusal: ZoneExitRuleDefinition = _exit_refusal(portal.source_zone_id, portal.destination_zone_id)
	if refusal != null:
		_refuse_passage(refusal, portal.source_zone_id, passage)
		return false
	if not portal.set_mark.is_empty():
		_player.state.marks[portal.set_mark] = 1
	return true


## The refused passage pushes the player back out of it, toward the room's middle.
func _refuse_passage(rule: ZoneExitRuleDefinition, from_zone_id: StringName, passage: WorldPassageArea2D) -> void:
	var room: WorldPhysicalZoneArea2D = physical_zone(from_zone_id)
	if room != null and passage != null:
		var area: Rect2 = passage.global_rect().grow(BODY_HALF_EXTENT + 2.0)
		var middle: Vector2 = room.global_rect().get_center()
		var at: Vector2 = player_body.global_position
		var toward: Vector2 = middle - at
		# Step out of the passage along the axis that leads back into the room.
		if absf(toward.x) * area.size.y > absf(toward.y) * area.size.x:
			at.x = area.position.x if toward.x < 0.0 else area.end.x
		else:
			at.y = area.position.y if toward.y < 0.0 else area.end.y
		player_body.global_position = at
		player_body.velocity = Vector2.ZERO
	_tell_refusal(rule)


## valid_leave() returned 0: the player stays in the room (back inside its edge) and
## reads why, once per attempt (a held key tries every frame).
func _refuse_exit(rule: ZoneExitRuleDefinition, from_zone_id: StringName) -> void:
	var room: WorldPhysicalZoneArea2D = physical_zone(from_zone_id)
	if room != null:
		var inside: Rect2 = room.global_rect().grow(-20.0)
		player_body.global_position = player_body.global_position.clamp(inside.position, inside.end)
		player_body.velocity = Vector2.ZERO
	_tell_refusal(rule)


func _tell_refusal(rule: ZoneExitRuleDefinition) -> void:
	var now: int = Time.get_ticks_msec()
	if rule.rule_id != _last_exit_refusal or now - _last_exit_refusal_ms > EXIT_REFUSAL_REPEAT_MS:
		var lines: Array[String] = []
		for line: String in rule.lines:
			lines.append(tr(line))
		hud().append_log_lines(lines)
	_last_exit_refusal = rule.rule_id
	_last_exit_refusal_ms = now


func freeze_world_gameplay(id: StringName) -> bool:
	if not _initialized or id.is_empty() or not _freeze_owner.is_empty() or _world_simulation_gate.freeze_owner_id() != id:
		return false
	_freeze_owner = id
	# A fight or a transition takes NPCs where their move was going (their place
	# already is), so a body never dies or is saved between two zones.
	if _walker != null:
		_walker.finish_all()
	_aggression.clear_all()
	_pending_player_berserk = &""
	selection.selected_target = null
	if hud() != null:
		hud().set_selected_target(null)
		hud().close_loot()
		hud().close_inventory()
	for body: WorldCharacterBody2D in npcs.character_bodies():
		body.quarantine_current_movement_input()
	return true


func thaw_world_gameplay(id: StringName) -> bool:
	if id.is_empty() or _freeze_owner != id or _world_simulation_gate.freeze_owner_id() != id:
		return false
	_freeze_owner = &""
	npcs.dismiss_summoned()
	for body: WorldCharacterBody2D in npcs.character_bodies():
		body.quarantine_current_movement_input()
	if hud() != null:
		hud().refresh_live_state()
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
	return npcs.map_characters


func hud() -> SharedGameplayUI:
	return null if session == null else session.shared_ui()


func world_simulation_gate() -> WorldSimulationGate:
	return _world_simulation_gate


func gameplay_open() -> bool:
	return _world_simulation_gate == null or _world_simulation_gate.is_open()


func _process(delta: float) -> void:
	if not _initialized or not gameplay_open():
		return
	for npc: NpcRuntimeState in npcs.residents:
		if _zone_entry(npc.world_location()) == &"complete_set" and not _complete_entry_contact(npc.character_id):
			_complete_set_consumed_contacts.erase(npc.character_id)
	_advance_toll_contacts(delta)
	if _aggression.pending_count() > 0 or _zone_entry(_player.world_location()) == &"complete_set":
		process_pending_aggression()
	if selection.selected_target != null and selection.selected_target.kind == WorldInteractionTarget.Kind.ITEM:
		if floor_items.item_views.has(selection.selected_target.target_id):
			floor_items.refresh_selected_floor_item()
		else:
			corpses.refresh_selected_corpse()
	if selection.selected_target != null and selection.selected_target.kind == WorldInteractionTarget.Kind.LANDMARK:
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
	var npc: NpcRuntimeState = npcs.find_resident_npc(character_id)
	if gameplay_open() and body == player_body and npc != null and _zone_entry(npc.world_location()) != &"complete_set":
		_aggression.enter_player_presence(npc, _player, _combat_allowed(npc))


func _on_presence_exited(body: Node2D, character_id: StringName) -> void:
	if body == player_body and not _complete_entry_contact(character_id):
		_complete_set_consumed_contacts.erase(character_id)
	if gameplay_open() and body == player_body:
		_aggression.leave_player_presence(character_id)
		_toll_waiting.erase(character_id)


func aggression_adapter() -> NpcAggressionAdapter:
	return _aggression


func last_aggression_decisions() -> Array[NpcAggressionDecision]:
	return _last_aggression_decisions.duplicate()


func last_aggression_initiations() -> Array[CombatSliceInitiationResult]:
	return _last_aggression_initiations.duplicate()


func process_pending_aggression() -> Array[CombatSliceInitiationResult]:
	if not gameplay_open() or session == null:
		return []
	_last_aggression_initiations.clear()
	if _zone_entry(_player.world_location()) == &"complete_set":
		if collect_complete_combat_entry(CombatTriggerCause.Value.NPC_AGGRESSION).size() > 1:
			var started: CombatSliceInitiationResult = session.combat_encounter_coordinator().start_complete_production(CombatTriggerCause.Value.NPC_AGGRESSION)
			if started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED:
				_announce_fight([])
			_last_aggression_initiations.append(started)
		return _last_aggression_initiations.duplicate()
	_last_aggression_decisions = _aggression.resolve_pending(npcs.residents, _player, _combat_allowed())
	for decision: NpcAggressionDecision in _last_aggression_decisions:
		var npc: NpcRuntimeState = npcs.find_resident_npc(decision.npc_id)
		if decision.outcome != NpcAggressionDecision.Outcome.READY or npc == null:
			continue
		if not npc.definition().attacks_on_sight(npc.flags(), _player.state):
			# Paid while its greeting waited: attack.c init() rolled berserk on arrival, not now.
			if not _toll_waiting.erase(npc.character_id):
				_go_berserk(npc)
			continue
		if not _toll_due(npc):
			# Its greeting has not come yet: wait while the player stays in reach.
			_toll_waiting[npc.character_id] = true
			_aggression.enter_player_presence(npc, _player, _combat_allowed(npc))
			continue
		_toll_waiting.erase(npc.character_id)
		# combatd.c start_aggressive() says nothing itself; its kill_ob() warns the player.
		_last_aggression_initiations.append(_initiate_lethal_combat(npc.character_id, _player.character_id, []))
	return _last_aggression_initiations.duplicate()


## gangster.c init(): call_out("greeting", 1). The toll-taker's greeting attacks a
## player still in reach when its delay has passed; one who walked on meets nobody.
## Owner (pacing knobs): walking past makes no grudge either (ES2's greeting
## kill_ob()s a passer-by who has left, and it attacks at once next time).
func _advance_toll_contacts(delta: float) -> void:
	for npc: NpcRuntimeState in npcs.residents:
		if npc.definition().dealings().toll_attack_delay_ms > 0 and _complete_entry_contact(npc.character_id):
			_toll_contact_seconds[npc.character_id] = _toll_contact_seconds.get(npc.character_id, 0.0) + delta
		else:
			_toll_contact_seconds.erase(npc.character_id)


func _toll_due(npc: NpcRuntimeState) -> bool:
	var delay_ms: int = npc.definition().toll_attack_delay_ms(npc.flags(), _player.state)
	return delay_ms <= 0 or _toll_contact_seconds.get(npc.character_id, 0.0) * 1000.0 >= delay_ms


## gangster.c kill_passenger() sets attitude "aggressive", and attack.c's hatred
## follows whoever it fights: a toll-taker that fights the player (its aggression, a
## refused toll, the player's 攻击 or 切磋) attacks on sight from then on, mark or not,
## until a reset makes it anew. An object variable: Continue forgets it.
func _note_toll_fights() -> void:
	for npc: NpcRuntimeState in npcs.residents:
		if not npc.definition().dealings().attack_unless_mark.is_empty() and npc.relationship.is_fighting():
			npc.set_flag(NpcDefinition.FLAG_FOUGHT_PLAYER, true)


## attack.c init()'s berserk case for an NPC (Berserk.roll()), then start_berserk().
func _go_berserk(npc: NpcRuntimeState) -> void:
	var outcome: Berserk.Outcome = Berserk.roll(npc.character_state, npc.definition().score, _world_interaction_random)
	if outcome != Berserk.Outcome.NONE:
		_last_aggression_initiations.append(_npc_berserk(npc, outcome, []))


## combatd.c start_berserk(npc, player) once it decided (`outcome`); `lines` come
## first (look.c's 瞪你一眼). It stares at everyone, then attacks to kill
## (kill_ob(): only it kills, the player fights back) or challenges the player to a
## spar (fight_ob()). The fight is the two of them, in a room where aggressive NPCs
## fight together too.
func _npc_berserk(npc: NpcRuntimeState, outcome: Berserk.Outcome, lines: Array[String]) -> CombatSliceInitiationResult:
	var name: String = tr(npc.definition().display_name)
	lines.append(tr("%s用一种异样的眼神扫视著在场的每一个人。") % name)
	if outcome == Berserk.Outcome.STARE:
		hud().append_log_lines(lines)
		return CombatSliceInitiationResult.new()
	var participants: Array[CombatSliceCharacterBinding] = _build_participants()
	var npc_binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(participants, npc.character_id)
	var player_binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(participants, _player.character_id)
	var self_rude: String = tr(RankWords.query_self_rude(npc.character_state.gender, npc.age, &""))
	if outcome == Berserk.Outcome.KILL:
		# TRANSLATORS: combatd.c start_berserk(): {self} is how the NPC calls itself (老子).
		var kill_line: String = tr("{npc}对著你喝道：{self}看你实在很不顺眼，去死吧。").format({"npc": name, "self": self_rude})
		return _berserk_fight(session.combat_encounter_coordinator().start_production(
			npc_binding, player_binding, CombatTriggerCause.Value.NPC_AGGRESSION, true,
		), npc, lines, kill_line, false)
	# TRANSLATORS: combatd.c start_berserk(): {rude} is how the NPC insults the player (臭贼), {self} how it calls itself (老子).
	var fight_line: String = tr("{npc}对著你喝道：喂！{rude}，{self}正想找人打架，陪我玩两手吧！").format({
		"npc": name, "self": self_rude,
		"rude": tr(RankWords.query_rude(_player.state.gender, _player.facts.age, _player.state.affiliation.class_id)),
	})
	return _berserk_fight(session.combat_encounter_coordinator().start_production(
		npc_binding, player_binding, CombatTriggerCause.Value.NPC_SPAR,
	), npc, lines, fight_line, true)


## kill_ob(player) by `npc` outside a fight (juechen/master.c's answer to a traitor's
## 拜师): it hunts the player, who only fights back. False when no fight could begin.
func npc_kills_player(npc: NpcRuntimeState) -> bool:
	if npc == null or _player == null or session == null:
		return false
	var participants: Array[CombatSliceCharacterBinding] = _build_participants()
	var npc_binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(participants, npc.character_id)
	var player_binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(participants, _player.character_id)
	if npc_binding == null or player_binding == null:
		return false
	var started: CombatSliceInitiationResult = session.combat_encounter_coordinator().start_production(
		npc_binding, player_binding, CombatTriggerCause.Value.NPC_AGGRESSION, true,
	)
	if started.outcome != CombatSliceInitiationResult.Outcome.COMPLETED:
		return false
	_announce_fight([], npc.character_id)
	return true


## A berserk's fight began: its shout and the opening (a spar with a blade has the
## armed spar's hint). One that could not begin says no shout: nothing happens.
func _berserk_fight(started: CombatSliceInitiationResult, npc: NpcRuntimeState, lines: Array[String], shout: String, spar: bool) -> CombatSliceInitiationResult:
	if started.outcome != CombatSliceInitiationResult.Outcome.COMPLETED:
		hud().append_log_lines(lines)
		return started
	lines.append(shout)
	if spar and selection.spar_is_armed(npc):
		lines.append(tr("刀剑无眼，持兵刃比试可能真的受伤。"))
	_announce_fight(lines, npc.character_id)
	return started


## The player's own feature/attack.c init() for each living NPC in `others` (who
## came into the player's place, or into whose place the player came): its berserk
## case, random(bellicosity / 40) > cps, drawn for each; the first that goes over
## gets combatd.c start_berserk() on the next world tick (auto_fight()'s call_out();
## looking_for_trouble lets one through). Not while
## the player fights or lies unconscious. Owner (水烟阁 C): never at the player's own
## master; an NPC whose fight is not ported is not there for it either.
func _player_init(others: Array[NpcRuntimeState]) -> void:
	if (
		not gameplay_open() or session == null or _player == null or not _player.exists_in_world
		or _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or _player.relationship.is_fighting()
		or session.combat_encounter_coordinator().has_active_encounter()
	):
		return
	var chosen: NpcRuntimeState = null
	for npc: NpcRuntimeState in others:
		if (
			not npc.exists_in_map or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or not _player_shares_zone(npc)
			or npc.definition().dealings().is_fight_deferred() or PlayerKillerReward.is_own_master(_player.state, npc.definition())
		):
			continue
		if Berserk.init_roll(_player.state, _world_interaction_random) and chosen == null:
			chosen = npc
	if chosen != null and _pending_player_berserk.is_empty():
		_pending_player_berserk = chosen.character_id


## auto_fight()'s call_out(start_berserk): the player's berserk whose roll went over,
## if the player and that NPC are still both here and free (start_berserk()'s checks).
func run_pending_player_berserk() -> void:
	var npc: NpcRuntimeState = npcs.find_resident_npc(_pending_player_berserk)
	_pending_player_berserk = &""
	if (
		npc == null or not gameplay_open() or session == null or _player == null or not npc.exists_in_map
		or _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or not _player_shares_zone(npc)
		or _player.relationship.is_fighting() or session.combat_encounter_coordinator().has_active_encounter()
	):
		return
	_player_berserk(npc)


## combatd.c start_berserk(player, npc): nothing in a room where fighting is
## forbidden; the player stares at everyone, calms down when their force beats
## (random(bellicosity) + bellicosity) / 2, else, with bellicosity above their
## score, attacks the NPC to kill (kill_ob(): the NPC only fights back), or
## challenges it to a spar (fight_ob(): it is not asked). Nobody asks the player
## first: the player did not choose it.
func _player_berserk(npc: NpcRuntimeState) -> void:
	if not _combat_allowed(npc):
		return
	hud().describe_arrival()
	var outcome: Berserk.Outcome = Berserk.start(_player.state, _player.state.progression.score, _world_interaction_random)
	var name: String = tr(npc.definition().display_name)
	var lines: Array[String] = [tr("你用一种异样的眼神扫视著在场的每一个人。")]
	if outcome == Berserk.Outcome.STARE:
		hud().append_log_lines(lines)
		_last_player_berserk = CombatSliceInitiationResult.new()
		return
	var self_rude: String = tr(RankWords.query_self_rude(_player.state.gender, _player.facts.age, _player.state.affiliation.class_id))
	var participants: Array[CombatSliceCharacterBinding] = _build_participants()
	var player_binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(participants, _player.character_id)
	var npc_binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(participants, npc.character_id)
	if outcome == Berserk.Outcome.KILL:
		# The two of them, in any room: the player kills, the NPC only fights back.
		# TRANSLATORS: combatd.c start_berserk() for the player: {self} is how the player calls themself (老子).
		var kill_line: String = tr("你对著{npc}喝道：{self}看你实在很不顺眼，去死吧。").format({"npc": name, "self": self_rude})
		_last_player_berserk = _berserk_fight(session.combat_encounter_coordinator().start_production(
			player_binding, npc_binding, CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK, true,
		), npc, lines, kill_line, false)
		return
	# TRANSLATORS: combatd.c start_berserk() for the player: {rude} is how the player insults the NPC (臭贼), {self} how they call themself (老子).
	var fight_line: String = tr("你对著{npc}喝道：喂！{rude}，{self}正想找人打架，陪我玩两手吧！").format({
		"npc": name, "rude": tr(RankWords.query_rude(npc.character_state.gender, npc.age, &"")), "self": self_rude,
	})
	_last_player_berserk = _berserk_fight(session.combat_encounter_coordinator().start_production(
		player_binding, npc_binding, CombatTriggerCause.Value.PLAYER_SPAR,
	), npc, lines, fight_line, true)


## cmds/std/look.c on a living NPC here: when random(its bellicosity / 10) beats the
## player's per, it turns to glare and goes berserk at them (auto_fight(),
## start_berserk(): nothing more while it already fights them or fighting is
## forbidden here).
func _look_berserk(npc: NpcRuntimeState) -> void:
	if (
		npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or _player == null
		or not npc.world_location().shares_combat_location(_player.world_location())
		or not Berserk.look_roll(npc.character_state, _player.state.attributes.personality, _world_interaction_random)
	):
		return
	var lines: Array[String] = [tr("%s突然转过头来瞪你一眼。") % tr(npc.definition().display_name)]
	if (
		npc.relationship.has_opponent(_player.character_id) or not _combat_allowed(npc)
		or npc.definition().dealings().is_fight_deferred() or session.combat_encounter_coordinator().has_active_encounter()
	):
		hud().append_log_lines(lines)
		return
	_npc_berserk(npc, Berserk.start(npc.character_state, npc.definition().score, _world_interaction_random), lines)


## The fight the player's last berserk started (or tried to), for tests.
func last_player_berserk() -> CombatSliceInitiationResult:
	return _last_player_berserk


## Owner decision P2A-M: every eligible aggressive enemy in current physical
## contact, plus a manual target, enters one encounter in stable ID order.
func collect_complete_combat_entry(cause: int, requested_target: StringName = &"") -> Array[CombatSliceCharacterBinding]:
	if not gameplay_open() or session == null or session.active_map() != self:
		return []
	if cause not in [CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK, CombatTriggerCause.Value.NPC_AGGRESSION]:
		return []
	var manual: bool = cause == CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK
	if (manual and npcs.find_resident_npc(requested_target) == null) or (not manual and not requested_target.is_empty()):
		return []
	if player_body._player != _player:
		return []
	var ids: Array[StringName] = []
	var fresh_contact: bool = false
	var waiting: Array[StringName] = []
	for npc: NpcRuntimeState in npcs.residents:
		if npc.exists_in_map:
			var body: WorldCharacterBody2D = npcs.runtime_body_for_character(npc.character_id)
			if not is_instance_valid(body) or body._npc != npc or npcs.map_characters.find_npc(npc.character_id) != npc:
				return []
		var contact: bool = _complete_entry_contact(npc.character_id)
		if not contact:
			_complete_set_consumed_contacts.erase(npc.character_id)
		var decision: NpcAggressionDecision = _aggression._evaluate(npc, _player, _combat_allowed(npc))
		var on_sight: bool = (
			contact and decision.outcome in [NpcAggressionDecision.Outcome.READY, NpcAggressionDecision.Outcome.NPC_ALREADY_FIGHTING]
			and npc.definition().attacks_on_sight(npc.flags(), _player.state)
		)
		var aggressive: bool = on_sight and _toll_due(npc)
		if on_sight and not aggressive:
			waiting.append(npc.character_id)
		if aggressive or (manual and npc.character_id == requested_target):
			if ids.has(npc.character_id):
				return []
			ids.append(npc.character_id)
			fresh_contact = fresh_contact or (aggressive and not _complete_set_consumed_contacts.has(npc.character_id))
	if ids.is_empty() or (not manual and not fresh_contact):
		return []
	# gangster.c: every robber's greeting comes from the same arrival (each init()), so the
	# toll-takers still waiting in reach join the fight that starts here.
	for id: StringName in waiting:
		if not ids.has(id):
			ids.append(id)
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
	var body: WorldCharacterBody2D = npcs.runtime_body_for_character(id)
	if not is_instance_valid(body) or not body.is_inside_tree():
		return false
	var area: Area2D = npcs.npc_presence.get(id)
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


func _initiate_lethal_combat(initiator_id: StringName, target_id: StringName, lines: Array[String]) -> CombatSliceInitiationResult:
	if not gameplay_open() or session == null:
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
		_announce_fight(lines, target_id if cause == CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK else initiator_id)
	return result


## A fight the player is in has just begun: `lines` (what was said) go to the log,
## then feature/attack.c kill_ob()'s warning, in HIR bright red, from every NPC
## that now fights the player to the death (kill.c's obj->kill_ob(me),
## combatd.c start_aggressive(), annihir.c accept_fight()). The battle log opens
## with the same lines and keeps the warnings pinned while the panel covers the log.
## `first_id`: the NPC whose kill_ob() came first (kill.c's target), when one did.
func _announce_fight(lines: Array[String], first_id: StringName = &"") -> void:
	_note_toll_fights()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var encounter: CombatEncounter = coordinator.active_encounter()
	var warnings: Array[String] = []
	if encounter != null:
		for participant: CombatParticipant in encounter.participants():
			var npc: NpcRuntimeState = npcs.find_resident_npc(participant.participant_id)
			if npc != null and participant.binding.relationship.has_lethal_target(_player.character_id):
				var warning: String = tr("看起来%s想杀死你！") % tr(npc.definition().display_name)
				if participant.participant_id == first_id:
					warnings.push_front(warning)
				else:
					warnings.append(warning)
	if not lines.is_empty():
		hud().append_log_lines(lines)
	if not warnings.is_empty():
		hud().append_log_lines(warnings, true)
	coordinator.note_opening(lines, warnings)


## all_inventory(environment(actor)) without the actor, as an exert file sees it
## (roar.c): the NPCs in the actor's place, in the map's order, those in the fight
## through their fight bindings. An NPC whose fight is not ported is not there.
func exert_room(actor_id: StringName, bindings: Array[CombatSliceCharacterBinding]) -> Array[SpecialSide]:
	var room: Array[SpecialSide] = []
	var location: WorldLocationState = _location_for_character(actor_id)
	if location == null:
		return room
	for npc: NpcRuntimeState in npcs.residents:
		if (
			npc.character_id == actor_id or not npc.exists_in_map or not npc.world_location().shares_combat_location(location)
			or npc.definition().dealings().is_fight_deferred()
		):
			continue
		var binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(bindings, npc.character_id)
		if binding == null and npc.combat_available:
			binding = combat_binding_for(npc.character_id)
		if binding != null:
			room.append(CombatNpcChat.side_of(binding, npc))
	return room


## A fight binding for an NPC here that is not in the fight (one roar.c brings in).
func combat_binding_for(character_id: StringName) -> CombatSliceCharacterBinding:
	var npc: NpcRuntimeState = npcs.find_resident_npc(character_id)
	if npc == null or not npc.exists_in_map:
		return null
	var binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_npc(npc, npcs.npc_content(npc))
	if binding != null:
		if _post_actions == null:
			_post_actions = CombatSlicePostActions.new(_run_post_action)
		binding.post_actions = _post_actions
	return binding


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
	if _post_actions == null:
		_post_actions = CombatSlicePostActions.new(_run_post_action)
	if player_binding != null:
		player_binding.post_actions = _post_actions
		result.append(player_binding)
	for npc: NpcRuntimeState in npcs.residents:
		if not include_absent and not npc.exists_in_map:
			continue
		var content: CombatSliceContentProfile = npcs.npc_content(npc)
		var binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_npc(npc, content)
		if binding != null:
			binding.post_actions = _post_actions
			result.append(binding)
	return result


## combatd.c do_attack(npc, player, the npc's weapon) called straight outside any fight
## (champion.c's accept test): TYPE_REGULAR, as a special file's direct attack, with
## the encounter random source and skill_improved() effects. A kee below zero falls
## only on the heart beat after (player_fall_below_zero()). Null when either cannot
## take part (not here, not conscious, already fighting).
func attack_player_outside_fight(npc: NpcRuntimeState) -> CombatSliceOpportunityResult:
	if (
		npc == null or _player == null or not npc.exists_in_map or not _player.exists_in_world
		or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE
		or npc.relationship.is_fighting() or _player.relationship.is_fighting()
	):
		return null
	_last_player_content_resolution = _weapon_resolver.resolve(_player, _inventory, _item_index)
	var player_binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_player(
		_player,
		_last_player_content_resolution.content_profile if _last_player_content_resolution.succeeded else null,
	)
	var npc_binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_npc(npc, npcs.npc_content(npc))
	if player_binding == null or npc_binding == null:
		return null
	if _post_actions == null:
		_post_actions = CombatSlicePostActions.new(_run_post_action)
	player_binding.post_actions = _post_actions
	npc_binding.post_actions = _post_actions
	var participants: Array[CombatSliceCharacterBinding] = [player_binding, npc_binding]
	var result: CombatSliceOpportunityResult = CombatSliceOpportunityExecutor.execute_direct_attack(npc_binding, player_binding, participants, _combat_random, _effects)
	return null if result.forward_result == null else result


## weapond.c's post_actions for one attack; what the player sees of it.
func _run_post_action(binding: CombatSliceCharacterBinding, policy_id: StringName, victim: CombatSliceCharacterBinding, parried: bool, random: CombatRandomSource) -> Array[ColoredLine]:
	match policy_id:
		CombatPostActionIds.THROW_WEAPON:
			return _throw_weapon(binding)
		CombatPostActionIds.BASH_WEAPON:
			return _bash_weapon(binding, victim, parried, random)
	return []


## throw_weapon(): the weapon of the attack loses one of its amount; the last one is
## unequipped first and its thrower told (你的飞刀用完了！, tell_object()). At 0 it is
## gone (combined.c destructs it).
func _throw_weapon(binding: CombatSliceCharacterBinding) -> Array[ColoredLine]:
	var told: Array[ColoredLine] = []
	var weapon: EquippedWeaponRef = binding.state.equipment.primary_weapon()
	if weapon == null or not _stacks.has_stack(weapon.instance_id):
		return told
	if _stacks.stack_state(weapon.instance_id).amount == 1:
		binding.state.equipment.unwield(weapon.instance_id)
		if binding.is_user:
			# TRANSLATORS: weapond.c throw_weapon(): the last of a thrown weapon (飞刀) is gone.
			told.append(ColoredLine.new(tr("你的%s用完了！") % _item_name(weapon.instance_id)))
	if not floor_items.use_up_one(weapon.instance_id, ItemLifecycleOwnerContext.new(binding.character_id, binding.state.equipment, binding.armor)):
		push_error("throwing %s failed: the item state is inconsistent" % weapon.instance_id)
	return told


## bash_weapon() (hammers, staffs): a blow the victim parried with a weapon pits the two
## weapons, weight / 500 + rigidity + str each; random(wap) over 2 x wdp knocks the
## victim's weapon away, over wdp nearly, over wdp / 2 breaks it, else sparks.
## message_vision(): the room sees it. No ported item sets rigidity yet (0).
func _bash_weapon(binding: CombatSliceCharacterBinding, victim: CombatSliceCharacterBinding, parried: bool, random: CombatRandomSource) -> Array[ColoredLine]:
	var weapon: EquippedWeaponRef = binding.state.equipment.primary_weapon()
	var parrying: EquippedWeaponRef = null if victim == null else victim.state.equipment.primary_weapon()
	if weapon == null or parrying == null or not parried:
		return []
	@warning_ignore("integer_division")
	var wap: int = _inventory.own_weight(weapon.instance_id) / 500 + binding.state.attributes.strength
	@warning_ignore("integer_division")
	var wdp: int = _inventory.own_weight(parrying.instance_id) / 500 + victim.state.attributes.strength
	var roll: int = random.legacy_random(wap) if wap > 0 else 0
	var who: String = _vision_name(victim)
	var held: String = _item_name(parrying.instance_id)
	if roll > 2 * wdp:
		# TRANSLATORS: weapond.c bash_weapon(): {who} (你 or a name) loses the weapon ({weapon}).
		var line := ColoredLine.new(tr("{who}只觉得手中{weapon}把持不定，脱手飞出！").format({"who": who, "weapon": held}), ColoredLine.HIW)
		var knocked: Array[ColoredLine] = []
		if _knock_away(victim, parrying.instance_id, false):
			knocked.append(line)
		return knocked
	if roll > wdp:
		# TRANSLATORS: weapond.c bash_weapon(): {who} nearly loses the weapon ({weapon}).
		return [ColoredLine.new(tr("{who}只觉得手中{weapon}一震，险些脱手！").format({"who": who, "weapon": held}))]
	@warning_ignore("integer_division")
	if roll > wdp / 2:
		# TRANSLATORS: weapond.c bash_weapon(): {who}'s weapon ({weapon}) breaks in two.
		var broken := ColoredLine.new(tr("只听见「啪」地一声，{who}手中的{weapon}已经断为两截！").format({"who": who, "weapon": held}), ColoredLine.HIW)
		var shown: Array[ColoredLine] = []
		if _knock_away(victim, parrying.instance_id, true):
			shown.append(broken)
		return shown
	# TRANSLATORS: weapond.c bash_weapon(): the two weapons meet; {me} and {who} are 你 or names.
	return [ColoredLine.new(tr("{me}的{weapon}和{who}的{other}相击，冒出点点的火星。").format({
		"me": _vision_name(binding), "weapon": _item_name(weapon.instance_id), "who": who, "other": held,
	}))]


## unequip() and move(environment(victim)): the weapon falls at the victim's feet; a broken
## one is 断掉的 from then on (set("name"), set("value"), set("weapon_prop", 0)). False when
## the victim has no place to drop it in (nothing happens).
func _knock_away(victim: CombatSliceCharacterBinding, item_id: StringName, broken: bool) -> bool:
	var npc: NpcRuntimeState = null if victim.is_user else npcs.find_resident_npc(victim.character_id)
	var location: WorldLocationState = _player.world_location() if victim.is_user else (null if npc == null else npc.world_location())
	var body: Node2D = player_body if victim.is_user else npcs.runtime_body_for_character(victim.character_id)
	if location == null or body == null:
		return false
	victim.state.equipment.unwield(item_id)
	var moved: InventoryTransferResult = InventoryTransferService.new().transfer(
		_inventory, item_id, InventoryTransferDestination.new(WorldMapFloorItems.floor_endpoint(location), true, true, WORLD_CAPACITY),
		victim.state.equipment, victim.armor,
	)
	if not moved.succeeded:
		push_error("knocking %s away failed: the item state is inconsistent" % item_id)
		return false
	if broken:
		var item: ItemInstance = _item_index.resolve(item_id)
		var broken_id: StringName = &"" if item == null else ItemContentDefinition.broken_id(item.item_definition_id)
		var form: ItemContentDefinition = GameContent.catalog().item(broken_id)
		if form == null or not _item_index.transmute(item_id, broken_id) or (_stacks.has_stack(item_id) and not _stacks.redefine(item_id, form.stack_definition())):
			push_error("breaking %s failed" % item_id)
	if not floor_items.add_dropped_item_view(item_id, location, floor_items.at_feet(location, body.global_position)):
		push_error("knocked-away %s has no view" % item_id)
	if victim.is_user and hud().inventory_is_open():
		hud().show_inventory(session.player_inventory_rows())
	return true


## $N/$n as the player reads message_vision(): 你, or the character's name.
func _vision_name(binding: CombatSliceCharacterBinding) -> String:
	if binding.is_user:
		return tr("你")
	var npc: NpcRuntimeState = npcs.find_resident_npc(binding.character_id)
	return "" if npc == null else tr(npc.definition().display_name)


## name() of a held item, in the shown language (断掉的 for a broken one).
func _item_name(item_id: StringName) -> String:
	var item: ItemInstance = _item_index.resolve(item_id)
	var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	return "" if content == null else tr(content.display_name)


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
	# killed_enemy() speaks before the dying player's ghost is moved away (damage.c die()).
	var killer_npc: NpcRuntimeState = null if killer == null else npcs.find_resident_npc(killer.character_id)
	var killer_heard: bool = killer_npc != null and (_player_hears(killer_npc) or (is_player and _player_shares_zone(killer_npc)))
	var victim_npc: NpcRuntimeState = null if is_player else npcs.find_resident_npc(victim.character_id)
	var receipt: CombatSliceLifecycleResult = _execute_lifecycle(victim, opportunity, participants, killer)
	_last_lifecycle_results.append(receipt)
	if receipt.completed() and receipt.outcome == CombatSliceLifecycleResult.Outcome.DEATH_COMPLETE and killer != null:
		corpses.killed_enemy(killer_npc, killer_heard)
		# combatd.c killer_reward(): a possessed killer's reward goes to who called it (its
		# !is_living() test always holds: nothing defines is_living()).
		var rewarded: StringName = npcs.summoners.get(killer.character_id, killer.character_id)
		if rewarded == _player.character_id and victim_npc != null:
			_player_killer_reward(victim_npc)
	if not receipt.completed():
		_lifecycle_failed = true
	elif is_player and session != null:
		session.on_player_lifecycle(receipt, killer != null, location)
	elif receipt.outcome == CombatSliceLifecycleResult.Outcome.UNCONSCIOUS_COMPLETE and session != null:
		# damage.c unconcious(): call_out("revive", random(100 - con) + 30).
		var npc: NpcRuntimeState = npcs.find_resident_npc(victim.character_id)
		if npc != null:
			npc.set_revive_in_ms(1000 * UnconsciousReviveDelay.seconds(npc.character_state.attributes.constitution, session.npc_revive_random_source()))
	return receipt


## One step of NPC heart_beat time (NpcHeartbeat); the session decides when it flows.
func advance_npc_heartbeat(delta: float) -> void:
	if not _initialized or session == null:
		return
	if _npc_heartbeat == null:
		_npc_heartbeat = NpcHeartbeat.new(session.npc_recovery_random_source())
	_fall_below_zero()
	corpses.advance_pending_dissolves(delta)
	for npc: NpcRuntimeState in _npc_heartbeat.advance(delta, npcs.npc_runtimes()):
		var body: WorldCharacterBody2D = npcs.runtime_body_for_character(npc.character_id)
		if body != null:
			body.refresh_runtime_state()
		# combatd.c announce("revive"), heard in the same room.
		if _player_hears(npc):
			hud().append_log_lines([tr("%s慢慢睁开眼睛，清醒了过来。") % tr(npc.definition().display_name)])
	# What the NPCs' conditions show their room (drunk.c, slumber_drug.c).
	for character_id: StringName in _npc_heartbeat.room_lines:
		var seen: NpcRuntimeState = npcs.find_resident_npc(character_id)
		if seen == null or not _player_hears(seen):
			continue
		var lines: Array[String] = []
		for template: String in _npc_heartbeat.room_lines[character_id]:
			lines.append(tr(template).format({"name": tr(seen.definition().display_name)}))
		hud().append_log_lines(lines)
	_advance_ambience(delta)


## std/char.c heart_beat(): an NPC whose gin, kee or sen went below zero outside a
## fight (安惜迩's powerfade costs 100 sen) falls unconscious, or dies below zero
## effective, on its next beat. In a fight the encounter does it.
func _fall_below_zero() -> void:
	for npc: NpcRuntimeState in npcs.npc_runtimes():
		if not npc.exists_in_map or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or npc.relationship.is_fighting():
			continue
		if npc.character_state.life_threshold() == CharacterState.LifeThreshold.ACTIVE:
			continue
		var content: CombatSliceContentProfile = npcs.npc_content(npc)
		var binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_npc(npc, content)
		var required: CombatSliceOpportunityResult = null if binding == null else CombatSliceOpportunityExecutor.inspect_lifecycle(binding)
		if required == null:
			continue
		var receipt: CombatSliceLifecycleResult = execute_encounter_lifecycle(binding, required, [binding])
		# combatd.c announce("unconcious"), heard in the same room (a drunk passing out).
		if receipt.outcome == CombatSliceLifecycleResult.Outcome.UNCONSCIOUS_COMPLETE and _player_hears(npc):
			hud().append_log_lines([tr("%s脚下一个不稳，跌在地上一动也不动了。") % tr(npc.definition().display_name)])


## The same for the player outside a fight, after a condition's tick (snake_poison.c
## wounds kee without a `who`): the killer is whoever hurt the player last
## (last_damage_from), while that NPC still stands on this map.
func player_fall_below_zero() -> void:
	if _player == null or _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or _player.relationship.is_fighting():
		return
	if _player.state.life_threshold() == CharacterState.LifeThreshold.ACTIVE:
		return
	_last_player_content_resolution = _weapon_resolver.resolve(_player, _inventory, _item_index)
	var binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_player(
		_player,
		_last_player_content_resolution.content_profile if _last_player_content_resolution.succeeded else null,
	)
	var required: CombatSliceOpportunityResult = null if binding == null else CombatSliceOpportunityExecutor.inspect_lifecycle(binding)
	if required == null:
		return
	var participants: Array[CombatSliceCharacterBinding] = [binding]
	var from: NpcRuntimeState = npcs.find_resident_npc(_player.relationship.last_damage_from_id)
	if from != null and from.exists_in_map and from.life_status != CharacterRuntimeLifeStatus.Value.DEAD:
		var killer: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_npc(from, npcs.npc_content(from))
		if killer != null:
			participants.append(killer)
	execute_encounter_lifecycle(binding, required, participants, _player.relationship.last_damage_from_id)


## combatd.c killer_reward() when the player killed an NPC (PlayerKillerReward): its
## tell_object() lines go to the log after the fight's result, so the HUD shows them last.
func _player_killer_reward(victim: NpcRuntimeState) -> void:
	var result: PlayerKillerReward.Result = PlayerKillerReward.apply(_player.state, victim.definition(), _world_interaction_random.legacy_random)
	if result.left_family:
		_player.take_title(PlayerKillerReward.REBEL_TITLE)
	if not result.lines.is_empty() and hud() != null:
		hud().append_after_fight(result.lines)


## npc.c chat() and random_move(), and greetings, on NPC heart_beat time (NpcAmbience).
func _advance_ambience(delta: float) -> void:
	if _ambience == null:
		_ambience = NpcAmbience.new(session.npc_ambience_random_source())
	_ambience.set_random(session.npc_ambience_random_source())
	_note_bellicosity()
	run_pending_player_berserk()
	# A fight began: the world stands still from here.
	if not gameplay_open():
		return
	_note_player_arrival()
	for character_id: StringName in _ambience.due_greetings(delta):
		_greet(npcs.find_resident_npc(character_id))
	for character_id: StringName in _ambience.due_calls(delta):
		_steal_step(npcs.find_resident_npc(character_id))
	for beat: int in _ambience.due_beats(delta):
		if beat > 0:
			# char.c heart_beat() falls before it chats, on each of several beats too.
			_fall_below_zero()
		for npc: NpcRuntimeState in npcs.residents.duplicate():
			if _chats(npc):
				_act(npc, _ambience.chat(npc.definition().talk()))
	npc_walker().advance(delta)


func npc_walker() -> WorldNpcWalker:
	if _walker == null:
		_walker = WorldNpcWalker.new(self)
	return _walker


## Owner (水烟阁 C): the first time the player's bellicosity can boil over (a kill, a
## powerup, whatever raised it), they are told once (Berserk.WARNING).
func _note_bellicosity() -> void:
	if _player != null and Berserk.take_warning(_player.state):
		hud().append_log_lines([tr(Berserk.WARNING)], true)


## The NPCs' init() when the player comes into a place: a greeting call_out.
func _note_player_arrival() -> void:
	var zone_id: StringName = &"" if _player == null or not _player.exists_in_world else _player.world_location().zone_id
	if zone_id == _arrival_zone_id:
		return
	_arrival_zone_id = zone_id
	for npc: NpcRuntimeState in npcs.residents:
		if (
			npc.world_location().zone_id == zone_id and npc.exists_in_map
			and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
			and not npc.relationship.is_fighting()
			and npc.definition().talk().has_greeting()
		):
			_ambience.start_greeting(npc.character_id)
	var here: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in npcs.residents:
		if npc.world_location().zone_id == zone_id:
			_consider_stealing(npc)
			here.append(npc)
	_player_init(here)


## keeper.c and waiter.c greeting(): said only if the player is still there; the
## waiter picks one of its lines then (switch(random(3))); a draw past the lines
## (switch(random(4)) with fewer cases) says nothing.
func _greet(npc: NpcRuntimeState) -> void:
	if npc == null or not npc.exists_in_map or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or not _player_hears(npc):
		return
	var choices: Array[NpcLine] = npc.definition().talk().greeting_choices()
	if choices.is_empty():
		return
	var draws: int = npc.definition().talk().greeting_draws()
	var drawn: int = 0 if draws == 1 else _ambience.random().legacy_random(draws)
	if drawn >= choices.size():
		return
	var respect: String = RankWords.query_respect(_player.state.gender, _player.facts.age, _player.state.affiliation.class_id)
	hud().append_log_lines([choices[clampi(drawn, 0, choices.size() - 1)].sentence(npc.definition().display_name, respect)])


## interactive(ob) in the NPC's room: an unconscious player still counts.
func _player_shares_zone(npc: NpcRuntimeState) -> bool:
	return (
		_player != null and _player.exists_in_world
		and npc.world_location().map_id == _player.world_location().map_id
		and npc.world_location().zone_id == _player.world_location().zone_id
	)


## What the player reads of an NPC: only in its place, and not while unconscious
## (damage.c unconcious() sets block_msg/all).
func _player_hears(npc: NpcRuntimeState) -> bool:
	return _player_shares_zone(npc) and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE


## init() of an NPC that comes into the player's place (make_inventory(), move()).
func _npc_arrived(npc: NpcRuntimeState) -> void:
	if (
		_ambience != null and _player_shares_zone(npc)
		and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
		and npc.definition().talk().has_greeting()
	):
		_ambience.start_greeting(npc.character_id)
	if _ambience != null and _player_shares_zone(npc):
		_consider_stealing(npc)
		_player_init([npc])


## thief.c init(): a player coming into its place (or it into theirs) is robbed one
## second later when random(kar) < chance_below; a fighting thief always tries.
func _consider_stealing(npc: NpcRuntimeState) -> void:
	var steal: NpcSteal = npc.definition().dealings().steal
	if (
		steal == null or _ambience == null or _ambience.has_call(npc.character_id) or _pending_steals.has(npc.character_id)
		or not npc.exists_in_map or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE
	):
		return
	if npc.relationship.is_fighting() or steal.starts(_player.state.attributes.karma, _ambience.random()):
		_ambience.start_call(npc.character_id, NpcSteal.START_DELAY_SECONDS)


## steal_it() and steal.c main() one second on; compelete_steal() three seconds after.
func _steal_step(npc: NpcRuntimeState) -> void:
	if npc == null:
		return
	var pending: Dictionary = _pending_steals.get(npc.character_id, {})
	_pending_steals.erase(npc.character_id)
	if pending.is_empty():
		_start_stealing(npc)
	else:
		_complete_stealing(npc, pending)


## steal_it(): only if the player is still there; steal.c main() picks present(what)
## or a random thing the player carries and fixes the odds.
func _start_stealing(npc: NpcRuntimeState) -> void:
	if not npc.exists_in_map or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or not _player_shares_zone(npc):
		return
	if GameContent.catalog().zone_forbids_fighting(npc.world_location().zone_id):
		return
	var steal: NpcSteal = npc.definition().dealings().steal
	var item_id: StringName = _player_item_with_alias(steal.what)
	if item_id.is_empty():
		var carried: Array[StringName] = _player_carried_item_ids()
		if carried.is_empty():
			return
		item_id = carried[_ambience.random().legacy_random(carried.size())]
	var thief_fighting: bool = npc.relationship.is_fighting()
	var sp: int = NpcSteal.thief_odds(
		npc.character_state.skills.effective_level(&"stealing"), npc.character_state.attributes.karma,
		_times_caught.get(npc.character_id, 0), thief_fighting,
	)
	if thief_fighting:
		npc.busy.start_busy(3)
	var dp: int = NpcSteal.victim_odds(
		_player.state.spirit.current, _inventory.subtree_weight(item_id), _player.relationship.is_fighting(),
		_player.state.equipment.has_weapon_instance(item_id) or _player.armor.is_worn(item_id),
	)
	_pending_steals[npc.character_id] = {"item": item_id, "sp": sp, "dp": dp}
	_ambience.start_call(npc.character_id, NpcSteal.COMPLETE_DELAY_SECONDS)


## compelete_steal(): the player must still be there; caught, the two fight (fight_ob).
## Taken, ES2 tells the player nothing; deviation (owner, modern fixes): the player
## reads what is gone, not who took it (one knocked out reads it on waking).
func _complete_stealing(npc: NpcRuntimeState, pending: Dictionary) -> void:
	# A thief killed meanwhile is gone (destructed: no `me` to move anything to).
	if not npc.exists_in_map or npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD or not _player_shares_zone(npc):
		return
	var item_id: StringName = pending["item"]
	if not _player_carried_item_ids().has(item_id):
		return
	var conscious: bool = _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	var outcome: NpcSteal.Outcome = NpcSteal.resolve(pending["sp"], pending["dp"], conscious, _ambience.random())
	match outcome:
		NpcSteal.Outcome.TAKEN:
			# ob->move(me); a thing too heavy for the thief stays (its own notice only)
			# and steal.c returns before its last two draws.
			var item_name: String = tr(_item_content(item_id).display_name)
			if not ItemHandlingService.hand_over(npc, item_id, floor_items.item_authorities()):
				return
			NpcSteal.after_taken(pending["sp"], conscious, npc.character_state.attributes.intelligence, _ambience.random())
			# TRANSLATORS: a thief took {item} from the player unseen; the player notices it is gone.
			var noticed: String = tr("你忽然觉得身上一轻，{item}不见了！")
			if not conscious:
				# TRANSLATORS: a thief took {item} from the player lying unconscious; read on waking.
				noticed = tr("你昏迷不醒的时候，身上的{item}被人拿走了！")
			hud().append_log_lines([noticed.format({"item": item_name})], true)
			if hud().inventory_is_open():
				hud().show_inventory(session.player_inventory_rows())
		NpcSteal.Outcome.CAUGHT:
			var lines: Array[String] = [
				tr("你一回头，正好发现{npc}的手正抓著你身上的{item}！").format({
					"npc": tr(npc.definition().display_name), "item": tr(_item_content(item_id).display_name),
				}),
				tr("你喝道：「干什麽！」"),
			]
			_times_caught[npc.character_id] = _times_caught.get(npc.character_id, 0) + 1
			var participants: Array[CombatSliceCharacterBinding] = _build_participants()
			var started: CombatSliceInitiationResult = session.combat_encounter_coordinator().start_production(
				CombatSliceProjectionBuilder.find_binding(participants, _player.character_id),
				CombatSliceProjectionBuilder.find_binding(participants, npc.character_id),
				CombatTriggerCause.Value.PLAYER_SPAR,
			)
			if started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED:
				npc.busy.start_busy(5)
				_announce_fight(lines)
			else:
				hud().append_log_lines(lines)


## The player's own things (all_inventory(me)), in inventory order.
func _player_carried_item_ids() -> Array[StringName]:
	return _inventory.direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id))


## present(alias, me): the first of the player's own things answering to `alias`.
func _player_item_with_alias(alias: StringName) -> StringName:
	for item_id: StringName in _player_carried_item_ids():
		var content: ItemContentDefinition = _item_content(item_id)
		if content != null and content.aliases().has(String(alias)):
			return item_id
	return &""


func _item_content(item_id: StringName) -> ItemContentDefinition:
	var item: ItemInstance = _item_index.resolve(item_id)
	return null if item == null else GameContent.catalog().item(item.item_definition_id)


## char.c heart_beat() reaches chat() for a conscious NPC that is neither busy nor
## fighting, and beats while the player is in its place. A walking NPC is still
## making its last move. Deviation: an unconscious NPC says nothing (DECISIONS 4D).
## The player need not be conscious; only what they read is (`_player_hears`).
func _chats(npc: NpcRuntimeState) -> bool:
	return (
		npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
		and not npc.relationship.is_fighting() and not npc.busy.is_busy()
		and npc.definition().talk().has_chat() and _player_shares_zone(npc)
		and not npc_walker().is_walking(npc.character_id)
	)


func _act(npc: NpcRuntimeState, entry: Variant) -> void:
	if entry is String:
		if _player_hears(npc):
			hud().append_log_lines([NpcTalk.line(entry)])
	elif entry is ColoredLine:
		if _player_hears(npc):
			hud().append_colored_lines([ColoredLine.new(NpcTalk.line(entry.text), entry.color)])
	elif entry is StringName and entry == NpcTalk.RANDOM_MOVE:
		random_move(npc)
	elif entry is NpcDrinkAction:
		_drink(npc, entry)
	elif entry is NpcSpecialAction:
		_special(npc, entry)


## npc.c's chat functions outside a fight (安惜迩's exert powerfade): with no enemy
## a perform or a spell refuses; an exert runs. The player in the NPC's place sees
## what it shows.
func _special(npc: NpcRuntimeState, action: NpcSpecialAction) -> void:
	var content: CombatSliceContentProfile = npcs.npc_content(npc)
	var binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_npc(npc, content)
	if binding == null:
		return
	var context := SpecialContext.new(
		CombatNpcChat.side_of(binding, npc), [], _ambience.random().legacy_random, GameContent.catalog(), null,
	)
	if not NpcSpecials.run(action, context) or not _player_hears(npc):
		return
	var lines: Array[ColoredLine] = []
	for line: VisionLine in context.lines:
		# Out of a fight only exert lines show: $N is the NPC.
		lines.append(ColoredLine.new(tr(line.template).strip_edges().replace("$N", tr(npc.definition().display_name)), line.color))
	hud().append_colored_lines(lines)


## drunk.c do_drink(): it drinks, drops the emptied container where it stands,
## or asks for more.
func _drink(npc: NpcRuntimeState, action: NpcDrinkAction) -> void:
	var location: WorldLocationState = npc.world_location()
	var drank: NpcDrinkService.Result = NpcDrinkService.drink(npc, action, WorldMapFloorItems.floor_endpoint(location), _inventory, _item_index, _liquids)
	if drank.outcome == NpcDrinkService.Outcome.AUTHORITY_FAILURE:
		push_error("%s could not drink: its carried liquid is inconsistent" % npc.character_id)
		return
	if not drank.dropped_item_id.is_empty():
		var body: WorldCharacterBody2D = npcs.runtime_body_for_character(npc.character_id)
		floor_items.add_dropped_item_view(drank.dropped_item_id, location, floor_items.at_feet(location, Vector2.ZERO if body == null else body.global_position))
	if _player_hears(npc):
		hud().append_log_lines(drank.lines)


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
	var seen: bool = _player_hears(npc)
	if not npc_walker().walk_into(npc.character_id, npcs.runtime_body_for_character(npc.character_id), physical_zone(from_zone_id), physical_zone(move.to_zone_id), _ambience.random()):
		return false
	npc.set_world_location(location_for_zone(move.to_zone_id))
	if seen:
		hud().append_log_lines([move.leave_line(npc.definition().display_name)])
	# The player's init() for one who walks in.
	if _player_shares_zone(npc):
		_player_init([npc])
	return true


## room.c valid_leave(): a closed door between the two zones stops the move.
func _door_closed_between(from_zone_id: StringName, to_zone_id: StringName) -> bool:
	for door: WorldDoor in doors():
		var definition: DoorDefinition = GameContent.catalog().door(door.door_id)
		if definition != null and definition.zone_ids().has(from_zone_id) and definition.zone_ids().has(to_zone_id) and not door.is_open():
			return true
	return false


func _execute_lifecycle(victim: CombatSliceCharacterBinding, opportunity: CombatSliceOpportunityResult, participants: Array[CombatSliceCharacterBinding], killer: CombatSliceCharacterBinding) -> CombatSliceLifecycleResult:
	var body: WorldCharacterBody2D = npcs.runtime_body_for_character(victim.character_id)
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
	var view: CombatSliceCorpseView = corpses.add_corpse_view(corpse, corpses.corpse_position(death_position, death_location), death_location)
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
	corpses.make_corpse_interactive(view)
	return lifecycle


func _death_context_for(victim: CombatSliceCharacterBinding, killer: CombatSliceCharacterBinding, destination: InventoryTransferDestination) -> DeathContext:
	if _player != null and victim.character_id == _player.character_id:
		return _player.death_context(destination, killer != null)
	var fallback: PlayerIdentityFacts = PlayerIdentityFacts.legacy_technical()
	var display_name: String = fallback.display_name
	var age: int = fallback.age
	var strength: int = victim.state.attributes.strength
	var body_weight: int = CharacterDerivedValues.human_weight(strength)
	var maximum_encumbrance: int = CharacterDerivedValues.maximum_encumbrance(strength)
	var npc: NpcRuntimeState = npcs.find_resident_npc(victim.character_id)
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
	var npc: NpcRuntimeState = npcs.find_resident_npc(binding.character_id)
	if npc != null:
		WorldCombatBindingAdapter.sync_npc(binding, npc)


func _location_for_character(character_id: StringName) -> WorldLocationState:
	if _player != null and character_id == _player.character_id:
		return _player.world_location()
	var npc: NpcRuntimeState = npcs.find_resident_npc(character_id)
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


## The player stands in the landmark's zone and, when it needs contact, inside its area.
func landmark_available(landmark: WorldLandmarkDefinition) -> bool:
	if landmark == null or _player == null or not landmark_areas.has(landmark.landmark_id):
		return false
	var location: WorldLocationState = _player.world_location()
	var zone: ZoneDefinition = GameContent.catalog().zone(landmark.zone_id)
	if location == null or zone == null or location.map_id != map or location.zone_id != zone.zone_id or location.combat_location_id != zone.combat_location_id:
		return false
	return not landmark.requires_contact or _inside_area(landmark_areas[landmark.landmark_id], player_body.global_position)


static func _inside_area(area: Area2D, point: Vector2) -> bool:
	var collision: CollisionShape2D = area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rectangle: RectangleShape2D = null if collision == null or collision.disabled else collision.shape as RectangleShape2D
	if rectangle == null:
		return false
	var local: Vector2 = collision.to_local(point)
	return absf(local.x) <= rectangle.size.x / 2.0 and absf(local.y) <= rectangle.size.y / 2.0


func _refresh_selected_landmark_source() -> void:
	if selection.selected_target == null or selection.selected_target.kind != WorldInteractionTarget.Kind.LANDMARK:
		return
	var available: bool = landmark_available(GameContent.catalog().landmark(selection.selected_target.target_id))
	if available != selection.selected_landmark_available:
		selection.selected_landmark_available = available
		hud().set_selected_landmark_source_available(available)


## The selected landmark's action (the HUD's portal button).
func traverse_selected_portal() -> RefCounted:
	if not gameplay_open() or session == null or selection.selected_target == null or selection.selected_target.kind != WorldInteractionTarget.Kind.LANDMARK:
		return WorldPortalTraversalResult.new()
	var landmark: WorldLandmarkDefinition = GameContent.catalog().landmark(selection.selected_target.target_id)
	var policy: WorldLandmarkPolicy = null if landmark == null else WorldLandmarkPolicies.create(landmark.policy)
	if policy == null:
		return WorldPortalTraversalResult.new()
	# The policy reports a wrong source zone itself; only the physical reach is checked here.
	if landmark.requires_contact and not _inside_area(landmark_areas[landmark.landmark_id], player_body.global_position):
		_refresh_selected_landmark_source()
		return WorldPortalTraversalResult.new()
	var before: WorldLocationState = _player.world_location()
	_last_landmark_use = policy.use(self, landmark)
	if not _player.world_location().same_location(before) and not policy.keeps_selection():
		selection.selected_target = null
		hud().set_selected_target(null)
	_refresh_selected_landmark_source()
	return _last_landmark_use


func last_landmark_use() -> RefCounted:
	return _last_landmark_use


## WorldPassageArea2D calls this (deferred) for a portal that stays on this map: the
## 迷阵's exits and 青石村's one-way ways (stoneroom.c west, water.c west).
func traverse_same_map_passage(portal: PortalDefinition) -> void:
	if not gameplay_open() or portal == null or not is_passage_current(portal):
		return
	_last_passage_traversal = WorldLandmarkPolicy.move_through(self, portal)
	var traversal: WorldPortalTraversalResult = _last_passage_traversal as WorldPortalTraversalResult
	if traversal != null and traversal.completed() and session != null:
		selection.selected_target = null
		hud().set_selected_target(null)
		hud().append_log_lines([tr("你来到%s。") % tr(GameContent.catalog().zone(portal.destination_zone_id).display_name)])
		if portal.destination_zone_id == portal.source_zone_id:
			hud().describe_again()


func last_passage_traversal() -> RefCounted:
	return _last_passage_traversal


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
	for candidate: WorldService in service_nodes:
		if candidate is WaterService and (candidate as WaterService).available():
			return true
	return false


func services() -> Array[WorldService]:
	return service_nodes.duplicate()


func service(service_id: StringName) -> WorldService:
	for candidate: WorldService in service_nodes:
		if candidate.service_id() == service_id:
			return candidate
	return null


func door(door_id: StringName) -> WorldDoor:
	return doors_by_id.get(door_id)


## Read from the scene, so it also works before initialize_map().
func doors() -> Array[WorldDoor]:
	var result: Array[WorldDoor] = []
	for node: Node in find_children("*", "", true, false):
		if node is WorldDoor:
			result.append(node as WorldDoor)
	return result


func can_operate_door(door_id: StringName) -> bool:
	var node: WorldDoor = doors_by_id.get(door_id)
	var definition: DoorDefinition = GameContent.catalog().door(door_id)
	return (
		node != null
		and definition.operable
		and (definition.closable or not node.is_open())
		and can_act(true)
		and player_near(definition.zone_ids(), node.wall_shape().global_position, definition.reach)
	)


func open_door(door_id: StringName) -> bool:
	if not can_operate_door(door_id) or doors_by_id[door_id].is_open():
		return false
	doors_by_id[door_id].set_open(true)
	return true


## A room rule's door (DoorDefinition.operable false): no reach, no player.
func set_door_open(door_id: StringName, open: bool) -> bool:
	var node: WorldDoor = doors_by_id.get(door_id)
	if node == null:
		return false
	node.set_open(open)
	return true


## The closed footprint is never a valid position (see the placement
## validator), so closing cannot trap the player in the doorway.
func close_door(door_id: StringName) -> bool:
	if not can_operate_door(door_id) or not doors_by_id[door_id].is_open():
		return false
	doors_by_id[door_id].set_open(false)
	return true


# --- forwarded to WorldMapCorpses (corpses) ---


func dissolve_selected_corpse(dust_id: StringName) -> bool:
	return corpses.dissolve_selected_corpse(dust_id)


func dissolvable_corpse_name() -> String:
	return corpses.dissolvable_corpse_name()


func dissolvable_corpse_contents() -> int:
	return corpses.dissolvable_corpse_contents()


func corpse_states() -> Array[CorpseState]:
	return corpses.corpse_states()


func corpse_view_for(corpse_id: StringName) -> CombatSliceCorpseView:
	return corpses.corpse_view_for(corpse_id)


func corpse_world_location(corpse_id: StringName) -> WorldLocationState:
	return corpses.corpse_world_location(corpse_id)


func last_loot_transfer_result() -> CorpseLootTransferResult:
	return corpses.last_loot_transfer_result()


func select_corpse(corpse_id: StringName) -> bool:
	return corpses.select_corpse(corpse_id)


func open_selected_loot() -> bool:
	return corpses.open_selected_loot()


func take_selected_loot_item(item_instance_id: StringName) -> CorpseLootTransferResult:
	return corpses.take_selected_loot_item(item_instance_id)


# --- forwarded to WorldMapFloorItems (floor_items) ---


func play_item(item_id: StringName) -> bool:
	return floor_items.play_item(item_id)


func can_hang_here() -> bool:
	return floor_items.can_hang_here()


static func zone_outdoors(zone_id: StringName) -> bool:
	return WorldMapFloorItems.zone_outdoors(zone_id)


func hang_with(item_id: StringName) -> bool:
	return floor_items.hang_with(item_id)


func floor_item_of(item_definition_id: StringName, zone_id: StringName) -> StringName:
	return floor_items.floor_item_of(item_definition_id, zone_id)


func destroy_floor_item(item_id: StringName) -> bool:
	return floor_items.destroy_floor_item(item_id)


func place_new_floor_item(item_definition_id: StringName) -> StringName:
	return floor_items.place_new_floor_item(item_definition_id)


func give_new_item_to_player(item_definition_id: StringName) -> StringName:
	return floor_items.give_new_item_to_player(item_definition_id)


func landmark_uses(landmark_id: StringName) -> int:
	return floor_items.landmark_uses(landmark_id)


func count_landmark_use(landmark_id: StringName) -> void:
	floor_items.count_landmark_use(landmark_id)


func dropped_item_ids() -> Array[StringName]:
	return floor_items.dropped_item_ids()


func dropped_item_location(item_id: StringName) -> WorldLocationState:
	return floor_items.dropped_item_location(item_id)


func floor_item_ids() -> Array[StringName]:
	return floor_items.floor_item_ids()


func floor_item_view(item_id: StringName) -> WorldFloorItemView:
	return floor_items.floor_item_view(item_id)


func select_floor_item(item_id: StringName) -> bool:
	return floor_items.select_floor_item(item_id)


func take_selected_floor_item() -> FloorItemPickup.Outcome:
	return floor_items.take_selected_floor_item()


func use_up_one(item_id: StringName, owner: ItemLifecycleOwnerContext) -> bool:
	return floor_items.use_up_one(item_id, owner)


func apply_item(item_id: StringName) -> bool:
	return floor_items.apply_item(item_id)


func pour_targets() -> Array[StringName]:
	return floor_items.pour_targets()


func pour_into(powder_id: StringName, container_id: StringName) -> bool:
	return floor_items.pour_into(powder_id, container_id)


func violates_unique(item_definition_id: StringName) -> bool:
	return floor_items.violates_unique(item_definition_id)


func can_handle_items() -> bool:
	return floor_items.can_handle_items()


func selected_npc_takes_gifts() -> bool:
	return floor_items.selected_npc_takes_gifts()


func give_to_selected(item_id: StringName, amount: int = 0) -> ItemHandlingResult:
	return floor_items.give_to_selected(item_id, amount)


func drop_item(item_id: StringName, amount: int = 0) -> ItemHandlingResult:
	return floor_items.drop_item(item_id, amount)


func container_in_reach() -> StringName:
	return floor_items.container_in_reach()


func put_in_container(item_id: StringName, amount: int = 0) -> ItemHandlingResult:
	return floor_items.put_in_container(item_id, amount)


func take_from_selected_container(item_id: StringName) -> ItemHandlingResult:
	return floor_items.take_from_selected_container(item_id)


# --- forwarded to WorldMapSelection (selection) ---


func selected_interaction_target() -> WorldInteractionTarget:
	return selection.selected_interaction_target()


func selected_character_id() -> StringName:
	return selection.selected_character_id()


func selected_npc() -> NpcRuntimeState:
	return selection.selected_npc()


func select_npc(character_id: StringName) -> bool:
	return selection.select_npc(character_id)


func select_landmark(landmark_id: StringName) -> bool:
	return selection.select_landmark(landmark_id)


func inspect_selected() -> bool:
	return selection.inspect_selected()


func attack_selected() -> CombatSliceInitiationResult:
	return selection.attack_selected()


func spar_selected() -> CombatSliceInitiationResult:
	return selection.spar_selected()


func spar_consent(target: NpcRuntimeState, asked: bool = false) -> NpcSparConsent:
	return selection.spar_consent(target, asked)


func selected_spar_risk() -> SparRisk:
	return selection.selected_spar_risk()


func selected_attack_starts() -> bool:
	return selection.selected_attack_starts()


func spar_is_armed(target: NpcRuntimeState) -> bool:
	return selection.spar_is_armed(target)


func can_ask_selected() -> bool:
	return selection.can_ask_selected()


func ask_topics_selected() -> Array[String]:
	return selection.ask_topics_selected()


func ask_selected(topic: String) -> Array[String]:
	return selection.ask_selected(topic)


func relay_phrases_selected() -> Array[String]:
	return selection.relay_phrases_selected()


func say_beside_selected(phrase: String) -> Array[String]:
	return selection.say_beside_selected(phrase)


func interaction_title() -> String:
	return selection.interaction_title()


func interact() -> void:
	selection.interact()


func dismiss_panel(content: Control) -> bool:
	return selection.dismiss_panel(content)


# --- forwarded to WorldMapNpcs (npcs) ---


func register_npc_body(npc: NpcRuntimeState, body: WorldCharacterBody2D, presence: Area2D, content: CombatSliceContentProfile) -> bool:
	return npcs.register_npc_body(npc, body, presence, content)


func unregister_npc_body(character_id: StringName) -> bool:
	return npcs.unregister_npc_body(character_id)


func npc_runtimes() -> Array[NpcRuntimeState]:
	return npcs.npc_runtimes()


func resident_npcs() -> Array[NpcRuntimeState]:
	return npcs.resident_npcs()


func find_resident_npc(character_id: StringName) -> NpcRuntimeState:
	return npcs.find_resident_npc(character_id)


func npc_combat_content(character_id: StringName) -> CombatSliceContentProfile:
	return npcs.npc_combat_content(character_id)


func npc_wield_by_type(character_id: StringName, skill_type: StringName, on: bool) -> bool:
	return npcs.npc_wield_by_type(character_id, skill_type, on)


func npc_wield_item(character_id: StringName, item_definition_id: StringName) -> bool:
	return npcs.npc_wield_item(character_id, item_definition_id)


func idle_npc_beside(character_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	return npcs.idle_npc_beside(character_id, definition_id)


func npc_rest_position(character_id: StringName) -> Vector2:
	return npcs.npc_rest_position(character_id)


func runtime_body_for_character(character_id: StringName) -> WorldCharacterBody2D:
	return npcs.runtime_body_for_character(character_id)


func runtime_body_for_spawn_point(spawn_point_id: StringName) -> WorldCharacterBody2D:
	return npcs.runtime_body_for_spawn_point(spawn_point_id)


func reset_room(legacy_room: String) -> void:
	npcs.reset_room(legacy_room)


func summon_one(spawn_id: StringName) -> NpcRuntimeState:
	return npcs.summon_one(spawn_id)


func summon(spawn_id: StringName) -> Array[NpcRuntimeState]:
	return npcs.summon(spawn_id)


func summon_beside(caster_id: StringName, definition_id: StringName) -> StringName:
	return npcs.summon_beside(caster_id, definition_id)


func summoner_of(character_id: StringName) -> StringName:
	return npcs.summoner_of(character_id)


func dismiss_summoned() -> void:
	npcs.dismiss_summoned()


func return_home(npc: NpcRuntimeState) -> bool:
	return npcs.return_home(npc)
