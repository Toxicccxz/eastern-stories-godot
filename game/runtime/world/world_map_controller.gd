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
var session: WorldSessionController
var player_body: WorldCharacterBody2D
# --- components ---
var corpses: WorldMapCorpses = WorldMapCorpses.new(self)
var floor_items: WorldMapFloorItems = WorldMapFloorItems.new(self)
var selection: WorldMapSelection = WorldMapSelection.new(self)
var npcs: WorldMapNpcs = WorldMapNpcs.new(self)
var npc_life: WorldMapNpcLife = WorldMapNpcLife.new(self)
var hostilities: WorldMapHostilities = WorldMapHostilities.new(self)
var combat_lifecycle: WorldMapCombatLifecycle = WorldMapCombatLifecycle.new(self)
var spells: WorldMapSpells = WorldMapSpells.new(self)
var acts: WorldMapActs = WorldMapActs.new(self)
var mazes: WorldMapMazes = WorldMapMazes.new(self)
var patrols: WorldMapPatrols = WorldMapPatrols.new(self)
var thefts: WorldMapThefts = WorldMapThefts.new(self)
var debts: WorldMapDebts = WorldMapDebts.new(self)
var _definition: MapDefinition
var _static_nodes: WorldMapStaticNodes
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
## Optional presentation projection, published by a map's visual child. Gameplay stays
## on its authored plane; screen markers must use the same projection as the models.
var projected_view: bool = false
var view_ground: Transform2D = Transform2D.IDENTITY
var view_up: Vector2 = Vector2.UP
var _last_landmark_use: RefCounted
var _last_passage_traversal: RefCounted


## What 切磋 with the selected NPC would be, for the HUD to ask first: DEADLY when its
## accept_fight() answers with kill_ob(), ARMED when a weapon in hand wounds, STRONGER
## when it is clearly stronger than the player (RelativeStrength, owner A10), NONE when
## none of these or it will not take place (spar_selected()'s refusals, or the NPC's).
enum SparRisk { NONE, ARMED, DEADLY, STRONGER }


func screen_position(point: Vector2, height: float = 0.0) -> Vector2:
	if projected_view:
		return view_ground * point + view_up * height
	return get_viewport().get_canvas_transform() * (point + Vector2.UP * height)


func screen_scale() -> Vector2:
	return view_ground.get_scale().abs() if projected_view else get_viewport().get_canvas_transform().get_scale().abs()


func _ready() -> void:
	initialize_map()


func map_id() -> StringName:
	return map


func configure_session(value: WorldSessionController) -> bool:
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
	combat_lifecycle.effects = SkillImprovementEffectRegistry.new()
	combat_lifecycle.effects.register_legacy_defaults()
	var restoring: bool = session != null and session.bootstrap_mode() == WorldSessionController.BootstrapMode.RESTORE
	if not (npcs.restore_actors() if restoring else npcs.spawn_actors()):
		return false
	prepare_for_deactivation()
	if not player_body.pushed_against.is_connected(_on_pushed_against):
		player_body.pushed_against.connect(_on_pushed_against)
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
		area.selection_requested.connect(selection.on_thing_clicked)
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
	return marker != null and point_in_zone(marker.global_position, zone_id)


func point_in_zone(point: Vector2, zone_id: StringName) -> bool:
	var zone: WorldPhysicalZoneArea2D = physical_zone(zone_id)
	return zone != null and zone.contains_center(point)


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
## Puts the player at a spawn point of a zone on this map; `even_unconscious` moves one
## lying unconscious too (ob->move(): d/latemoon shinyu.c's kick).
func relocate_player(zone_id: StringName, spawn_point_id: StringName, even_unconscious: bool = false) -> bool:
	if not _initialized:
		return false
	var marker: WorldSpawnMarker2D = resolve_spawn_marker(spawn_point_id)
	if marker == null or not spawn_matches_zone(spawn_point_id, zone_id):
		return false
	return place_player(zone_id, marker.global_position, even_unconscious)


## relocate_player() to a spot of the zone instead of a marker (drift_sense.c's move to
## where someone stands). False when the spot is not in the zone.
func place_player(zone_id: StringName, point: Vector2, even_unconscious: bool = false) -> bool:
	var lying: bool = even_unconscious and _player != null and _player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS
	if not _initialized or _player == null or (_player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE and not lying):
		return false
	var location: WorldLocationState = location_for_zone(zone_id)
	if location == null or not point_in_zone(point, zone_id):
		return false
	player_body.global_position = point
	player_body.placed()
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
	return marker != null and prepare_for_activation_at(marker.global_position)


func prepare_for_activation_at(point: Vector2) -> bool:
	if not _initialized or not point.is_finite():
		return false
	prepare_for_deactivation()
	player_body.global_position = point
	player_body.placed()
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
	frame_camera()
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	player_body.placed()
	clear_passage_contacts()
	if hud() != null:
		hud().refresh_live_state()
	return true


## The player's camera on this map (DECISIONS「手感」), also on a window resize or a new
## 界面缩放: it follows at the feel's
## camera_follow_speed (0: stuck to the player) and stops at the edges of what is drawn
## (every TileMapLayer's tiles), so the view never shows past the map; a map smaller
## than the view sits in its middle.
func frame_camera() -> void:
	var camera: Camera2D = player_body.get_node("Camera2D") as Camera2D
	var speed: float = GameContent.catalog().pacing().feel.camera_follow_speed
	camera.position_smoothing_enabled = speed > 0.0
	if speed > 0.0:
		camera.position_smoothing_speed = speed
	# The 界面缩放 grows everything the window draws; the camera divides it back out so
	# the map shows as much as at 100% (the scene's own zoom is kept as authored). What the
	# map itself draws (names over bodies, landmark and floor labels) stays the map's size.
	if not camera.has_meta(&"authored_zoom"):
		camera.set_meta(&"authored_zoom", camera.zoom)
	var window: Window = get_viewport() as Window
	camera.zoom = (camera.get_meta(&"authored_zoom") as Vector2) / (window.content_scale_factor if window != null else 1.0)
	var drawn: Rect2 = drawn_rect()
	if not drawn.has_area():
		return
	var limits: Rect2 = camera_limits(drawn, get_viewport_rect().size / camera.zoom)
	camera.limit_left = floori(limits.position.x)
	camera.limit_top = floori(limits.position.y)
	camera.limit_right = ceili(limits.end.x)
	camera.limit_bottom = ceili(limits.end.y)


## `point` (world) is on the screen now: inside what the player's camera shows.
func in_view(point: Vector2) -> bool:
	if projected_view:
		return get_viewport_rect().has_point(screen_position(point))
	var camera: Camera2D = null if player_body == null else player_body.get_node_or_null("Camera2D") as Camera2D
	if camera == null or not camera.enabled or not camera.is_inside_tree():
		return true
	var half: Vector2 = get_viewport_rect().size / camera.zoom / 2.0
	return Rect2(camera.get_screen_center_position() - half, half * 2.0).has_point(point)


## The camera's limits for a map drawing `drawn` seen through a view of `view`: the map's
## edges, widened evenly on a side where the map is smaller than the view.
static func camera_limits(drawn: Rect2, view: Vector2) -> Rect2:
	var spare: Vector2 = (view - drawn.size).max(Vector2.ZERO) / 2.0
	return drawn.grow_individual(spare.x, spare.y, spare.x, spare.y)


## What this map draws, in world coordinates: the union of its TileMapLayers' used cells.
func drawn_rect() -> Rect2:
	var drawn: Rect2 = Rect2()
	for node: Node in find_children("*", "TileMapLayer", true, false):
		var layer: TileMapLayer = node as TileMapLayer
		var used: Rect2i = layer.get_used_rect()
		if used.size == Vector2i.ZERO or layer.tile_set == null:
			continue
		var half: Vector2 = Vector2(layer.tile_set.tile_size) / 2.0
		var first: Vector2 = layer.to_global(layer.map_to_local(used.position) - half)
		var last: Vector2 = layer.to_global(layer.map_to_local(used.end - Vector2i.ONE) + half)
		var cells: Rect2 = Rect2(first, Vector2.ZERO).expand(last)
		drawn = cells if not drawn.has_area() else drawn.merge(cells)
	return drawn


func _on_viewport_resized() -> void:
	if player_body != null and player_body.player_controlled:
		frame_camera()


func prepare_for_deactivation() -> void:
	if player_body == null:
		return
	player_body.player_controlled = false
	player_body.velocity = Vector2.ZERO
	player_body.walk_paused = false
	(player_body.get_node("Camera2D") as Camera2D).enabled = false
	# Nobody watches a map the player left: its NPCs stand where they were going.
	if npc_life.walker != null:
		npc_life.walker.finish_all()
	# ...and those on their way out by a door are through it.
	npc_life.finish_departures(false)
	npc_life.arrival_zone_id = &""
	_present_zones.clear()
	_zone_check_pending = false
	clear_passage_contacts()
	selection.selected_target = null
	hostilities.aggression.clear_all()
	# The player left the map: whoever noticed them, or fought them in a complete-set room,
	# meets them anew when they come back.
	hostilities.room_present.clear()
	hostilities.complete_set_consumed_contacts.clear()
	hostilities.toll_contact_seconds.clear()
	hostilities.toll_waiting.clear()
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
	if _initialized and player_body != null and player_body.player_controlled:
		patrols.hold_player()
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
		if refusal.counts_tries:
			_refuse_try(refusal)
			return false
		_refuse_exit(refusal, current.zone_id)
		if refusal.asks:
			_ask_way_in(refusal, _enter_after_asking.bind(refusal))
		return false
	clear_tries(current.zone_id)
	_tell_passing(current.zone_id, zone.zone_id)
	if session != null:
		session.player_leaving_zone(current.zone_id, zone.zone_id)
	if not _player.set_world_location(location_for_zone(zone.zone_id)):
		return false
	_drop_selection_left_behind()
	return true


func _on_pushed_against(other: WorldCharacterBody2D) -> void:
	if gameplay_open() and other != null:
		npc_life.step_aside(other)


## An NPC the player walked away from is no longer selected (kill.c's present():
## its actions would only be refused). One in the room the player walked into stays, and
## so does a dead one (it offers nothing; picking its corpse replaces it) and one that
## follows the player and is about to walk after them (WorldMapNpcLife._followers_follow()).
func _drop_selection_left_behind() -> void:
	var npc: NpcRuntimeState = selection.selected_npc()
	if (
		npc == null or npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD
		or npc.world_location().shares_combat_location(_player.world_location())
		or (
			npc.flags().get(NpcDefinition.FLAG_FOLLOWS_PLAYER, false)
			and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not npc.relationship.is_fighting()
		)
	):
		return
	selection.selected_target = null
	if hud() != null:
		hud().set_selected_target(null)


## The room's valid_leave() that refuses this way out now, or null.
func _exit_refusal(from_zone_id: StringName, to_zone_id: StringName) -> ZoneExitRuleDefinition:
	var leaver: ZoneExitRuleDefinition.Leaver = ZoneExitRuleDefinition.Leaver.of(_player.state, _world_interaction_random.legacy_random)
	leaver.temps = _player.temp_marks.duplicate()
	for rule: ZoneExitRuleDefinition in GameContent.catalog().exit_rules_between(from_zone_id, to_zone_id):
		var present: bool = _rule_npc_present(rule, from_zone_id)
		if rule.condition == ZoneExitRuleDefinition.Condition.HELD:
			present = npcs.first_npc_in_zone(rule.present_npc_id, from_zone_id, true, StringName(rule.temp)) != null
		if rule.refuses(leaver, present):
			return rule
	return null


## present() of the rule's NPC in the room: any of the kinds it names (road2.c's "trainer").
func _rule_npc_present(rule: ZoneExitRuleDefinition, zone_id: StringName) -> bool:
	if rule.present_npc_ids.is_empty():
		return not rule.present_npc_id.is_empty() and npcs.npc_present_in_zone(rule.present_npc_id, zone_id)
	return rule.present_npc_ids.any(func(npc_id: StringName) -> bool: return npcs.npc_present_in_zone(npc_id, zone_id))


## valid_leave() for a passage (d/green/entrance.c east into the 迷阵): a refusal keeps
## the player out of the passage, back in the room, and says why; a way that marks
## whoever takes it (eight7.c set("八卦阵")) marks the player as they go, and the way into
## a note maze (d/choyin/entrance.c east) sets how far its way out is.
func leave_by_passage(portal: PortalDefinition, passage: WorldPassageArea2D) -> bool:
	if portal == null or _player == null:
		return false
	var refusal: ZoneExitRuleDefinition = _exit_refusal(portal.source_zone_id, portal.destination_zone_id)
	if refusal != null:
		_refuse_passage(refusal, portal.source_zone_id, passage)
		return false
	_tell_passing(portal.source_zone_id, portal.destination_zone_id)
	# Leaving the room by a door is leaving it (a trap on the way out: keep2.c's boulder as
	# one goes east into the keep's hall, a map of its own since the remap).
	if session != null:
		session.player_leaving_zone(portal.source_zone_id, portal.destination_zone_id)
	if not portal.set_mark.is_empty():
		_player.state.marks[portal.set_mark] = 1
	mazes.entering(portal, _player.state)
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
		player_body.placed()
	_tell_refusal(rule)


## road2.c valid_leave(): the try counts (set_temp("long_road", i)) and the road does not
## change: the player is back where it began (`point`), told every time.
func _refuse_try(rule: ZoneExitRuleDefinition) -> void:
	_player.temp_marks[rule.temp] = int(_player.temp_marks.get(rule.temp, 0)) + 1
	if not spawn_matches_zone(rule.point_id, rule.from_zone_id) or not relocate_player(rule.from_zone_id, rule.point_id):
		push_error("exit rule %s: no point %s in %s" % [rule.rule_id, rule.point_id, rule.from_zone_id])
		_refuse_exit(rule, rule.from_zone_id)
		return
	var lines: Array[String] = []
	for line: String in rule.lines:
		lines.append(tr(line))
	hud().append_log_lines(lines)


## road2.c delete_temp("long_road"): whoever leaves the road starts counting anew.
func clear_tries(from_zone_id: StringName) -> void:
	for rule: ZoneExitRuleDefinition in GameContent.catalog().exit_rules():
		if rule.counts_tries and rule.from_zone_id == from_zone_id:
			_player.temp_marks.erase(rule.temp)


## valid_leave() returned 0: the player stays in the room (back inside its edge) and
## reads why, once per attempt (a held key tries every frame).
func _refuse_exit(rule: ZoneExitRuleDefinition, from_zone_id: StringName) -> void:
	var room: WorldPhysicalZoneArea2D = physical_zone(from_zone_id)
	if room != null:
		var inside: Rect2 = room.global_rect().grow(-20.0)
		player_body.global_position = player_body.global_position.clamp(inside.position, inside.end)
		player_body.placed()
	_tell_refusal(rule)


func _tell_refusal(rule: ZoneExitRuleDefinition) -> void:
	if rule.asks:
		return
	var now: int = Time.get_ticks_msec()
	if rule.knocks_out or rule.rule_id != _last_exit_refusal or now - _last_exit_refusal_ms > EXIT_REFUSAL_REPEAT_MS:
		var lines: Array[String] = []
		for line: String in rule.lines:
			lines.append(tr(line))
		hud().append_log_lines(lines)
	_last_exit_refusal = rule.rule_id
	_last_exit_refusal_ms = now
	# road1.c: unconcious() right after the slip, where the player now is.
	if rule.knocks_out:
		_player.state.fall_unconscious()
		player_fall_below_zero()


## An `ask` rule stopped the player at the way in (owner, 晚月庄 plan Q2): the
## question, while they stay in the room it asks from; `go` takes them in.
func _ask_way_in(rule: ZoneExitRuleDefinition, go: Callable) -> void:
	player_body.quarantine_current_movement_input()
	if hud() == null or hud().is_asking():
		return
	var still_here: Callable = func() -> bool:
		return (
			_player != null and _player.world_location().zone_id == rule.from_zone_id and can_act(false)
			and not door_shut_between(rule.from_zone_id, rule.to_zone_id)
		)
	hud().ask_first(tr(rule.ask), tr(rule.choice), go, still_here)


## A door between the two zones stands shut (room.c valid_leave(): 你必须先把…打开！).
func door_shut_between(from_zone_id: StringName, to_zone_id: StringName) -> bool:
	for node: WorldDoor in doors_by_id.values():
		var definition: DoorDefinition = GameContent.catalog().door(node.door_id)
		if definition != null and definition.zone_ids().has(from_zone_id) and definition.zone_ids().has(to_zone_id) and not node.is_open():
			return true
	return false


## The player chose to walk in: they are put inside, as a walk would (the way's
## valid_leave() lines, the room traps).
func _enter_after_asking(rule: ZoneExitRuleDefinition) -> void:
	if _player == null or _player.world_location().zone_id != rule.from_zone_id or door_shut_between(rule.from_zone_id, rule.to_zone_id):
		return
	if not spawn_matches_zone(rule.point_id, rule.to_zone_id):
		push_error("exit rule %s: no point %s in %s" % [rule.rule_id, rule.point_id, rule.to_zone_id])
		return
	_tell_passing(rule.from_zone_id, rule.to_zone_id)
	if session != null:
		session.player_leaving_zone(rule.from_zone_id, rule.to_zone_id)
	if relocate_player(rule.to_zone_id, rule.point_id):
		_drop_selection_left_behind()


## What the room's valid_leave() tells one who goes through (book_room1.c's
## message_vision()), before the next room's text, and what it takes back
## (latemoon3.c: the tea cup goes back to 雨梅).
func _tell_passing(from_zone_id: StringName, to_zone_id: StringName) -> void:
	var lines: Array[String] = []
	for rule: ZoneExitRuleDefinition in GameContent.catalog().exit_rules_between(from_zone_id, to_zone_id):
		if rule.condition == ZoneExitRuleDefinition.Condition.TAKES_BACK:
			_take_back(rule)
			continue
		# gate.c: the 门房's leave goes with the one who went in on it (owner's M3, 默认).
		if rule.condition == ZoneExitRuleDefinition.Condition.NO_MARK and rule.spends:
			_player.state.marks.erase(rule.mark)
		# A rule an NPC's own command makes (waiter.c go_up()) says nothing without that NPC.
		if rule.condition == ZoneExitRuleDefinition.Condition.NO_MARK and not rule.present_npc_id.is_empty() and not _rule_npc_present(rule, from_zone_id):
			continue
		for line: String in rule.pass_lines:
			lines.append(tr(line))
	if not lines.is_empty() and hud() != null:
		hud().append_log_lines(lines)


## latemoon3.c valid_leave(): present("tea cup", me) among the player's own things;
## with the flag it goes back (destruct()) and the flag goes; without one at all the
## player reads `without`.
func _take_back(rule: ZoneExitRuleDefinition) -> void:
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id)
	if not rule.item_ids.is_empty():
		_take_back_all(rule, carried)
		return
	var held: StringName = &""
	for item_id: StringName in inventory_state().direct_children(carried):
		var item: ItemInstance = item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == rule.item_id:
			held = item_id
			break
	if held.is_empty():
		var without: Array[String] = []
		for line: String in rule.without:
			without.append(tr(line))
		if hud() != null:
			hud().append_log_lines(without)
		return
	if _player.temp_marks.get(rule.temp, 0) == 0:
		return
	_player.temp_marks.erase(rule.temp)
	if not floor_items.use_up_one(held, ItemLifecycleOwnerContext.new(_player.character_id, _player.state.equipment, _player.armor)):
		push_error("handing back %s failed: the item state is inconsistent" % held)
	if hud() != null:
		var taken: Array[ColoredLine] = []
		for line: NpcLine in rule.taken:
			taken.append(line.colored("", ""))
		hud().append_colored_lines(taken)
		if hud().inventory_is_open():
			hud().show_inventory(session.player_inventory_rows())


## club.c valid_leave(): while present("book", me) the hermit's book goes back (destruct(),
## HIC 你将书放回到矮几。 each); with none, 你离开草堂!. Only his own books (owner, 乔阴 B): ES2
## took any book once one was scratched, and looped forever on one without the flag.
func _take_back_all(rule: ZoneExitRuleDefinition, carried: ContainmentEndpoint) -> void:
	var held: Array[StringName] = []
	for item_id: StringName in inventory_state().direct_children(carried):
		var item: ItemInstance = item_instance_index().resolve(item_id)
		if item != null and rule.item_ids.has(ItemContentDefinition.unnamed_id(item.item_definition_id)):
			held.append(item_id)
	if hud() == null:
		return
	if held.is_empty():
		var without: Array[String] = []
		for line: String in rule.without:
			without.append(tr(line))
		hud().append_log_lines(without)
		return
	var taken: Array[ColoredLine] = []
	for item_id: StringName in held:
		if not floor_items.use_up_one(item_id, ItemLifecycleOwnerContext.new(_player.character_id, _player.state.equipment, _player.armor)):
			push_error("putting back %s failed: the item state is inconsistent" % item_id)
			continue
		for line: NpcLine in rule.taken:
			taken.append(line.colored("", ""))
	hud().append_colored_lines(taken)
	if hud().inventory_is_open():
		hud().show_inventory(session.player_inventory_rows())


func freeze_world_gameplay(id: StringName) -> bool:
	if not _initialized or id.is_empty() or not _freeze_owner.is_empty() or _world_simulation_gate.freeze_owner_id() != id:
		return false
	_freeze_owner = id
	# A fight or a transition takes NPCs where their move was going (their place
	# already is), so a body never dies or is saved between two zones.
	if npc_life.walker != null:
		npc_life.walker.finish_all()
	hostilities.aggression.clear_all()
	hostilities.pending_player_berserk = &""
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
	hostilities.after_fight()
	npcs.dismiss_summoned()
	for body: WorldCharacterBody2D in npcs.character_bodies():
		body.quarantine_current_movement_input()
	if hud() != null:
		hud().refresh_live_state()
	return true


## The player went to another map (a handoff that completed): its NPCs' call_outs go.
## Not on deactivation, which a failed handoff or session swap rolls back.
func player_departed() -> void:
	npc_life.player_left()


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


## char.c visible(): a ghost player (damage.c is_ghost()) sees ghosts, and so does one whose
## 阴阳眼 runs (apply/astral_vision).
func player_sees_ghosts() -> bool:
	return _player != null and _player.state != null and _player.state.sees_ghosts()


## Whether the player sees `npc` (a ghost only while they see ghosts).
func player_sees(npc: NpcRuntimeState) -> bool:
	return npc != null and (not npc.definition().is_ghost() or player_sees_ghosts())


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


## What the player waits for on this map (DECISIONS「响应性」): their steal, a master's
## test, an NPC's told sequence.
func player_waits() -> Array[WorldWait]:
	var shown: Array[WorldWait] = []
	var steal: WorldWait = thefts.wait()
	if steal != null:
		shown.append(steal)
	shown.append_array(npc_life.waits())
	return shown


func _process(delta: float) -> void:
	if not _initialized or not gameplay_open():
		return
	# World time held (the menu, a presentation beat): the toll's seconds and pending
	# aggression wait too.
	if session != null and (session.world_time_held() or session.presentation_frozen()):
		return
	hostilities.refresh_room_presence()
	for npc: NpcRuntimeState in npcs.residents:
		if WorldMapHostilities.zone_entry(npc.world_location()) == &"complete_set" and not hostilities.complete_entry_contact(npc.character_id):
			hostilities.complete_set_consumed_contacts.erase(npc.character_id)
	hostilities.advance_toll_contacts(delta)
	if hostilities.aggression.pending_count() > 0 or WorldMapHostilities.zone_entry(_player.world_location()) == &"complete_set":
		hostilities.process_pending_aggression()
	if selection.selected_target != null and selection.selected_target.kind == WorldInteractionTarget.Kind.ITEM:
		if floor_items.item_views.has(selection.selected_target.target_id):
			floor_items.refresh_selected_floor_item()
		else:
			corpses.refresh_selected_corpse()
	if selection.selected_target != null and selection.selected_target.kind == WorldInteractionTarget.Kind.LANDMARK:
		_refresh_selected_landmark_source()


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
## Uses the selected landmark: its action, or another of its actions (`action`: a dial's
## turn, by its count).
func traverse_selected_portal(action: String = "") -> RefCounted:
	if not gameplay_open() or session == null or selection.selected_target == null or selection.selected_target.kind != WorldInteractionTarget.Kind.LANDMARK:
		return WorldPortalTraversalResult.new()
	var landmark: WorldLandmarkDefinition = GameContent.catalog().landmark(selection.selected_target.target_id)
	var policy: WorldLandmarkPolicy = null if landmark == null else WorldLandmarkPolicies.create(landmark.policy)
	if policy == null or patrols.refuses_move():
		return WorldPortalTraversalResult.new()
	# The policy reports a wrong source zone itself; only the physical reach is checked here.
	if landmark.requires_contact and not _inside_area(landmark_areas[landmark.landmark_id], player_body.global_position):
		_refresh_selected_landmark_source()
		return WorldPortalTraversalResult.new()
	var before: WorldLocationState = _player.world_location()
	_last_landmark_use = policy.use_action(self, landmark, action)
	if not _player.world_location().same_location(before) and not policy.keeps_selection():
		selection.selected_target = null
		hud().set_selected_target(null)
	_refresh_selected_landmark_source()
	return _last_landmark_use


func last_landmark_use() -> RefCounted:
	return _last_landmark_use


## WorldPassageArea2D calls this (deferred) for a portal that stays on this map: the
## 迷阵's exits and 青石村's one-way ways (stoneroom.c west, water.c west). A way out of a
## note maze (the 桃林) is judged first, and the right last one leads out instead.
func traverse_same_map_passage(portal: PortalDefinition) -> void:
	if not gameplay_open() or portal == null or not is_passage_current(portal):
		return
	var way: PortalDefinition = mazes.take_way(portal, _player.state)
	if way != null:
		portal = way
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
	# On the way through a passage (the view going dark, DECISIONS「手感」): nothing else now.
	if session != null and session.passage_request_pending():
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


## feature/finance.c can_afford(price) for the player: the money they carry (gold, silver
## and coins) comes to `price` or more, whether or not in the right coins.
func player_can_afford(price: int) -> bool:
	var outcome: MoneyAffordabilityResult.Outcome = MoneyPaymentService.can_afford(floor_items.item_authorities().context, price).outcome
	return outcome == MoneyAffordabilityResult.Outcome.AFFORDABLE or outcome == MoneyAffordabilityResult.Outcome.DENOMINATION_REJECTED


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
	return static_nodes().doors.duplicate()


## The scene's tile layers, static walls, doors and passages (WorldMapStaticNodes).
func static_nodes() -> WorldMapStaticNodes:
	if _static_nodes == null:
		_static_nodes = WorldMapStaticNodes.new(self)
	return _static_nodes


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
	set_door_open(door_id, true)
	return true


## A room rule's door (DoorDefinition.operable false): no reach, no player. A door on
## a portal opens or shuts on the other map too (the same door seen from both sides).
func set_door_open(door_id: StringName, open: bool) -> bool:
	var node: WorldDoor = doors_by_id.get(door_id)
	if node == null:
		return false
	node.set_open(open)
	var definition: DoorDefinition = GameContent.catalog().door(door_id)
	if session != null and definition != null:
		for map_id: StringName in definition.map_ids():
			var other: WorldMapController = null if map_id == map else session.world_map_of(map_id)
			if other != null and other.door(door_id) != null:
				other.door(door_id).set_open(open)
	return true


## The closed footprint is never a valid position (see the placement
## validator), so closing cannot trap the player in the doorway.
func close_door(door_id: StringName) -> bool:
	if not can_operate_door(door_id) or not doors_by_id[door_id].is_open():
		return false
	set_door_open(door_id, false)
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


# --- forwarded to WorldMapSpells (spells) ---


func animatable_corpse() -> CorpseState:
	return spells.animatable_corpse()


func animate_knocks_out() -> bool:
	return spells.animate_knocks_out()


func animate_selected_corpse() -> bool:
	return spells.animate_selected_corpse()


func scribable_npc() -> NpcRuntimeState:
	return spells.scribable_npc()


func scribe_knocks_out() -> bool:
	return spells.scribe_knocks_out()


func scribe_kills() -> bool:
	return spells.scribe_kills()


func scribe_on(paper_id: StringName) -> bool:
	return spells.scribe_on(paper_id)


func sheet_carrier() -> NpcRuntimeState:
	return spells.sheet_carrier()


func sheet_target(sheet_id: StringName) -> NpcRuntimeState:
	return spells.sheet_target(sheet_id)


func attach_sheet(sheet_id: StringName) -> bool:
	return spells.attach_sheet(sheet_id)


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


func act_with_item(item_id: StringName) -> bool:
	return floor_items.act_with_item(item_id)


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


func gift_rule_for_selected(item_id: StringName, amount: int = 0) -> NpcObjectRule:
	return floor_items.gift_rule_for_selected(item_id, amount)


func give_to_selected(item_id: StringName, amount: int = 0) -> ItemHandlingResult:
	return floor_items.give_to_selected(item_id, amount)


func drop_item(item_id: StringName, amount: int = 0) -> ItemHandlingResult:
	return floor_items.drop_item(item_id, amount)


func container_in_reach() -> StringName:
	return floor_items.container_in_reach()


func put_in_container(item_id: StringName, amount: int = 0) -> ItemHandlingResult:
	return floor_items.put_in_container(item_id, amount)


func take_from_carried_container(container_id: StringName, item_id: StringName) -> ItemHandlingResult:
	return floor_items.take_from_carried_container(container_id, item_id)


func put_in_carried_container(item_id: StringName, amount: int, container_id: StringName) -> ItemHandlingResult:
	return floor_items.put_in_carried_container(item_id, amount, container_id)


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


func selected_spar_stronger() -> bool:
	return selection.selected_spar_stronger()


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


func selected_npc_here() -> NpcRuntimeState:
	return selection.selected_npc_here()


func ordination_selected() -> NpcOrdination:
	return selection.ordination_selected()


func kneel_selected() -> Array[String]:
	return selection.kneel_selected()


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


func conjure_beside_player(definition_id: StringName) -> NpcRuntimeState:
	return npcs.conjure_beside_player(definition_id)


func summoner_of(character_id: StringName) -> StringName:
	return npcs.summoner_of(character_id)


func dismiss_summoned() -> void:
	npcs.dismiss_summoned()


func return_home(npc: NpcRuntimeState) -> bool:
	return npcs.return_home(npc)


# --- forwarded to WorldMapNpcLife (npc_life) ---


func advance_npc_heartbeat(delta: float) -> void:
	npc_life.advance_npc_heartbeat(delta)


func npc_walker() -> WorldNpcWalker:
	return npc_life.npc_walker()


func random_move(npc: NpcRuntimeState) -> bool:
	return npc_life.random_move(npc)


# --- forwarded to WorldMapHostilities (hostilities) ---


func aggression_adapter() -> NpcAggressionAdapter:
	return hostilities.aggression_adapter()


func last_aggression_decisions() -> Array[NpcAggressionDecision]:
	return hostilities.last_aggression_decisions()


func last_aggression_initiations() -> Array[CombatSliceInitiationResult]:
	return hostilities.last_aggression_initiations()


func process_pending_aggression() -> Array[CombatSliceInitiationResult]:
	return hostilities.process_pending_aggression()


func npc_kills_player(npc: NpcRuntimeState, lines: Array[String] = []) -> bool:
	return hostilities.npc_kills_player(npc, lines)


func run_pending_player_berserk() -> void:
	hostilities.run_pending_player_berserk()


func last_player_berserk() -> CombatSliceInitiationResult:
	return hostilities.last_player_berserk()


func collect_complete_combat_entry(cause: int, requested_target: StringName = &"") -> Array[CombatSliceCharacterBinding]:
	return hostilities.collect_complete_combat_entry(cause, requested_target)


func consume_complete_entry_contacts(ids: Array[StringName]) -> void:
	hostilities.consume_complete_entry_contacts(ids)


func attack_player_outside_fight(npc: NpcRuntimeState) -> CombatSliceOpportunityResult:
	return hostilities.attack_player_outside_fight(npc)


# --- forwarded to WorldMapCombatLifecycle (combat_lifecycle) ---


func exert_room(actor_id: StringName, bindings: Array[CombatSliceCharacterBinding]) -> Array[SpecialSide]:
	return combat_lifecycle.exert_room(actor_id, bindings)


func combat_binding_for(character_id: StringName) -> CombatSliceCharacterBinding:
	return combat_lifecycle.combat_binding_for(character_id)


func encounter_combat_bindings(encounter: CombatEncounter) -> Array[CombatSliceCharacterBinding]:
	return combat_lifecycle.encounter_combat_bindings(encounter)


func encounter_skill_effect_registry() -> SkillImprovementEffectRegistry:
	return combat_lifecycle.encounter_skill_effect_registry()


func last_player_content_resolution() -> WorldWeaponContentResolution:
	return combat_lifecycle.last_player_content_resolution()


func last_lifecycle_results() -> Array[CombatSliceLifecycleResult]:
	return combat_lifecycle.last_lifecycle_results()


func lifecycle_is_pending() -> bool:
	return combat_lifecycle.lifecycle_is_pending()


func execute_encounter_lifecycle(victim: CombatSliceCharacterBinding, opportunity: CombatSliceOpportunityResult, participants: Array[CombatSliceCharacterBinding], last_hitter_id: StringName = &"") -> CombatSliceLifecycleResult:
	return combat_lifecycle.execute_encounter_lifecycle(victim, opportunity, participants, last_hitter_id)


func player_fall_below_zero(even_unconscious: bool = false) -> void:
	combat_lifecycle.player_fall_below_zero(even_unconscious)
