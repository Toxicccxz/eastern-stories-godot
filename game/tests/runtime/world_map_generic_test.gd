extends RefCounted

## Package 3B2: Old Pine and Snow run on one data-configured WorldMapController.
const SessionScene := preload("res://scenes/world/oldpine/oldpine_world_session.tscn")

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _test_spawned_bodies(tree)
	await _test_water_sources(tree)
	await _test_landmark_policies(tree)
	await _test_zone_links_and_waterfall_cliff(tree)
	await _test_every_map_can_fight(tree)
	await _test_arrival_has_terrain_walls(tree)
	await _test_corpse_beside_a_wall(tree)
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


## A body that falls against the forest edge leaves a corpse Continue accepts.
func _test_corpse_beside_a_wall(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree)
	var forest: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	var slope: WorldLocationState = forest.location_for_zone(OldPineWorldDefinitions.SLOPE_ZONE_ID)
	# Walk west from the slope's path at y -150 to the last spot a body still fits.
	var fell_at: Vector2 = Vector2(450, -150)
	while MapPlacementValidator.is_valid_character_position(forest, slope.zone_id, fell_at - Vector2(1, 0)) and fell_at.x > 0:
		fell_at.x -= 1.0
	_assert_true(MapPlacementValidator.is_valid_character_position(forest, slope.zone_id, fell_at), "a body can stand against the slope's west forest")
	_assert_false(MapPlacementValidator.is_valid_corpse_position(forest, slope.zone_id, fell_at), "the wider corpse would overlap that forest")
	var corpse_at: Vector2 = forest._corpse_position(fell_at, slope)
	_assert_true(MapPlacementValidator.is_valid_corpse_position(forest, slope.zone_id, corpse_at), "the corpse is shifted to where Continue accepts it")
	_assert_true(corpse_at.distance_to(fell_at) <= 40.0, "but stays where the body fell")
	_assert_eq(forest._corpse_position(Vector2(450, -150), slope), Vector2(450, -150), "a corpse in the open lies exactly where the body fell")
	await _free(session, tree)


## Tile collision is built when a map becomes active, not one frame later.
func _test_arrival_has_terrain_walls(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree)
	var handoff: OldPineMapHandoffResult = session.handoff_to(OldPineWorldDefinitions.GORGE_MAP_ID, OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID, OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID, OldPineWorldDefinitions.RIVERBANK1_CLIFF_LANDING_SPAWN_POINT_ID)
	var gorge: WorldMapController = session.world_map_of(OldPineWorldDefinitions.GORGE_MAP_ID)
	_assert_true(handoff.succeeded(), "the player arrives on the river bank")
	_assert_true(gorge.player_body.test_move(gorge.player_body.global_transform, Vector2(-400, 0)), "the stream blocks in the very frame of arrival")
	await _free(session, tree)


func _session(tree: SceneTree, source_entry: bool = false) -> OldPineWorldSessionController:
	var session: OldPineWorldSessionController = SessionScene.instantiate() as OldPineWorldSessionController
	session.deterministic_npc_seed = true
	session.deterministic_combat_seed = true
	session.deterministic_world_interaction_seed = true
	if source_entry:
		session.configure_source_entry("凌雪", CharacterState.GENDER_FEMALE)
	tree.root.add_child(session)
	await tree.physics_frame
	return session


func _free(session: OldPineWorldSessionController, tree: SceneTree) -> void:
	session.queue_free()
	await tree.process_frame


func _test_spawned_bodies(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree)
	_assert_eq(session.world_npcs().size(), 36, "every spawns.json point has one NPC")
	# Each map spawns its own points: the forest the five bandits, the gorge the five serpents.
	var outdoor: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	_assert_eq(outdoor.npc_runtimes().size(), 23, "the forest spawns its 23 (five summoned, absent)")
	_assert_spawned_bodies(outdoor)
	var gorge: WorldMapController = session.world_map_of(OldPineWorldDefinitions.GORGE_MAP_ID)
	_assert_eq(gorge.npc_runtimes().size(), 5, "the gorge spawns the five lake serpents")
	_assert_true(session.handoff_to(gorge.map_id(), OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, OldPineWorldDefinitions.WATERFALL_LANDING_SPAWN_POINT_ID).succeeded(), "the gorge becomes active before its physics is read")
	await tree.physics_frame
	_assert_spawned_bodies(gorge)
	await _free(session, tree)


func _assert_spawned_bodies(map: WorldMapController) -> void:
	for npc: NpcRuntimeState in map.npc_runtimes():
		var body: WorldNpcBody2D = map.runtime_body_for_character(npc.character_id) as WorldNpcBody2D
		var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(npc.spawn_id)
		_assert_eq(spawn.map_id, map.map_id(), "%s spawns on the map its spawn names" % npc.character_id)
		_assert_true(body != null and body.character_id == npc.character_id, "%s has its own spawned body" % npc.character_id)
		if body == null:
			continue
		_assert_eq(body.global_position, map.resolve_spawn_marker(npc.spawn_point_id).global_position, "%s stands on its spawn marker" % npc.character_id)
		var circle: CircleShape2D = (body.get_node("AggressionPresence/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
		_assert_eq(int(circle.radius), spawn.presence_radius, "%s presence radius comes from its spawn" % npc.character_id)
		_assert_eq((body.get_node("BeastVisual") as CanvasItem).visible, npc.definition().race_id == &"beast", "%s visual follows its race" % npc.character_id)
		_assert_eq(PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM).origin, body.global_position, "%s enters physics at its marker, not the origin" % npc.character_id)


func _test_water_sources(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree, true)
	# Both water sources belong to the gorge map, which owns their zones.
	var map: WorldMapController = session.world_map_of(OldPineWorldDefinitions.GORGE_MAP_ID)
	_assert_true(session.handoff_to(map.map_id(), OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, OldPineWorldDefinitions.WATERFALL_LANDING_SPAWN_POINT_ID).succeeded(), "public world reaches the Waterfall landing")
	var waterfall: WorldServicePoint = map.get_node("WaterfallWaterPoint") as WorldServicePoint
	# The point stands at the foot of the falls; the pool is south of it.
	map.player_body.global_position = waterfall.global_position + Vector2(0, 60)
	_assert_true(map.water_available(), "resource/water at the waterfall pool")
	_assert_true(session.fill_water_available(), "the supplies panel may fill here")
	_assert_eq(map.interaction_title(), "", "water adds no context button of its own")
	map.player_body.global_position = waterfall.global_position + Vector2(0, 150)
	_assert_false(map.water_available(), "out of reach of the waterfall pool")
	var lake: WorldServicePoint = map.get_node("LakeWaterPoint") as WorldServicePoint
	map.player_body.global_position = lake.global_position
	_assert_false(map.water_available(), "the lake point needs the player in the Lake zone")
	map.player_body.set_world_location(map.location_for_zone(OldPineWorldDefinitions.LAKE_ZONE_ID))
	_assert_true(map.water_available(), "resource/water at the lake shore")
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var serpent: NpcRuntimeState = map.npc_runtimes()[0]
	_assert_eq(serpent.spawn_id, &"oldpine.gorge.lake.serpents", "the lake opponent is a gorge serpent")
	player.relationship.add_opponent(serpent.character_id)
	_assert_true(map.water_available(), "liquid.c do_fill has no fighting gate")
	player.relationship.remove_opponent(serpent.character_id)
	await _free(session, tree)


func _test_landmark_policies(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree)
	var map: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	_assert_true(map.select_landmark(&"oldpine.outdoor.landmark.ancient_pine"), "the clearing pine is selectable")
	# The tree top is its own map: the portal policy climbs by map handoff.
	var climb: OldPineMapHandoffResult = map.traverse_selected_portal() as OldPineMapHandoffResult
	_assert_true(climb != null and climb.succeeded(), "portal policy climbs the pine")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.TREE_MAP_ID, "climb pine activates the tree map")
	_assert_eq(session.player_runtime().world_location().zone_id, OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID, "climb pine lands in the canopy")
	_assert_true(session.shared_ui().log_lines().has("爬树：大松树"), "the action is logged as before")
	_assert_false(session.world_map_of(OldPineWorldDefinitions.TREE_MAP_ID).select_landmark(&"oldpine.outdoor.landmark.nope"), "unknown landmarks are not selectable")
	# Contact landmarks refuse without standing in their area, whatever the zone.
	# The river cliff belongs to the gorge map.
	map = session.world_map_of(OldPineWorldDefinitions.GORGE_MAP_ID)
	_assert_true(session.handoff_to(map.map_id(), OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID, OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID, OldPineWorldDefinitions.RIVERBANK1_CLIFF_LANDING_SPAWN_POINT_ID).succeeded(), "fixture reaches the river gorge")
	map.player_body.global_position = Vector2(1420, 1300)
	map.player_body.set_world_location(map.location_for_zone(OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID))
	_assert_true(map.select_landmark(&"oldpine.gorge.landmark.riverbank1_cliff"), "the river cliff is selectable from afar")
	_assert_false(map.landmark_available(GameContent.catalog().landmark(&"oldpine.gorge.landmark.riverbank1_cliff")), "contact landmark is unavailable away from its area")
	var refused: WorldPortalTraversalResult = map.traverse_selected_portal() as WorldPortalTraversalResult
	_assert_true(refused != null and not refused.completed(), "no climb without contact")
	_assert_eq(session.player_runtime().world_location().zone_id, OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID, "refused climb does not move the player")
	await _free(session, tree)


func _test_zone_links_and_waterfall_cliff(tree: SceneTree) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_assert_true(catalog.zones_adjacent(OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID), "recorded Pine threshold link")
	_assert_true(catalog.zones_adjacent(OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID), "fixed maze link works both ways")
	_assert_false(catalog.zones_adjacent(OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID), "no ES2 exit from the bridge down to the pool")
	_assert_false(catalog.zones_adjacent(OldPineWorldDefinitions.SLOPE_ZONE_ID, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID), "no ES2 exit from the slope to the pool")
	# The pool lies below the bridge on its own map (DECISIONS 3B5): no forest zone leads there.
	_assert_eq(catalog.zone(OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID).map_id, OldPineWorldDefinitions.GORGE_MAP_ID, "the waterfall pool is a gorge zone")
	for zone: ZoneDefinition in catalog.zones_for_map(OldPineWorldDefinitions.OUTDOOR_MAP_ID):
		_assert_false(catalog.zones_adjacent(zone.zone_id, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID), "no walk from %s down to the pool" % zone.zone_id)
	var session: OldPineWorldSessionController = await _session(tree)
	var map: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	_assert_true(map.physical_zone(OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID) == null, "the forest map holds no waterfall zone")
	_assert_true(map.location_for_zone(OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID) == null, "the forest map cannot place the player at the pool")
	var body: WorldCharacterBody2D = map.player_body
	# The gorge runs under the bridge: off the deck there is only the chasm.
	for probe: Array in [[Vector2(1200, 300), Vector2(0, 80), "south"], [Vector2(1200, 300), Vector2(0, -80), "north"]]:
		_assert_true(body.test_move(Transform2D(0.0, probe[0]), probe[1]), "the chasm blocks walking %s off the bridge deck" % probe[2])
	for point: Vector2 in [Vector2(1200, 200), Vector2(1200, 450), Vector2(1200, 560)]:
		_assert_eq(TerrainProbe.terrain_at(map, point), "chasm", "the gorge under the bridge is chasm at %s" % point)
		_assert_true(TerrainProbe.blocks_at(map, point), "the chasm under the bridge collides at %s" % point)
	_assert_false(body.test_move(Transform2D(0.0, Vector2(1100, 300)), Vector2(200, 0)), "the deck itself still crosses the gorge")
	# On the gorge map the pool is walled on every side but the south.
	var gorge: WorldMapController = session.world_map_of(OldPineWorldDefinitions.GORGE_MAP_ID)
	_assert_true(session.handoff_to(gorge.map_id(), OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, OldPineWorldDefinitions.WATERFALL_LANDING_SPAWN_POINT_ID).succeeded(), "the pool is reached by handoff to the gorge")
	await tree.physics_frame
	body = gorge.player_body
	for probe: Array in [[Vector2(1000, 640), Vector2(0, -80), "north"], [Vector2(940, 850), Vector2(-80, 0), "west"], [Vector2(1460, 850), Vector2(80, 0), "east"]]:
		_assert_true(body.test_move(Transform2D(0.0, probe[0]), probe[1]), "the waterfall cliff walls the pool to the %s" % probe[2])
	_assert_false(body.test_move(Transform2D(0.0, Vector2(1420, 1060)), Vector2(0, 60)), "the pool still opens south along the east bank")
	await _free(session, tree)


func _test_every_map_can_fight(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree, true)
	_assert_eq(session.active_map_id(), SnowWorldDefinitions.INN_MAP_ID, "public New Game starts in the Inn")
	_assert_eq(session.encounter_opportunity_interval_seconds(), 1.0, "Snow has the same one-second combat round")
	_assert_eq(session.encounter_opportunity_interval_seconds(), GameContent.catalog().pacing().combat_round_seconds, "the round comes from pacing.json")
	await _free(session, tree)


func _assert_true(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)


func _assert_false(condition: bool, message: String) -> void:
	_assert_true(not condition, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
