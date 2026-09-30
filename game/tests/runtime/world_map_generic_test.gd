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
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


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
	var map: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	_assert_eq(map.npc_runtimes().size(), 10, "every spawns.json point has one NPC")
	for npc: NpcRuntimeState in map.npc_runtimes():
		var body: WorldNpcBody2D = map.runtime_body_for_character(npc.character_id) as WorldNpcBody2D
		var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(npc.spawn_id)
		_assert_true(body != null and body.character_id == npc.character_id, "%s has its own spawned body" % npc.character_id)
		if body == null:
			continue
		_assert_eq(body.global_position, map.resolve_spawn_marker(npc.spawn_point_id).global_position, "%s stands on its spawn marker" % npc.character_id)
		var circle: CircleShape2D = (body.get_node("AggressionPresence/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
		_assert_eq(int(circle.radius), spawn.presence_radius, "%s presence radius comes from its spawn" % npc.character_id)
		_assert_eq((body.get_node("BeastVisual") as CanvasItem).visible, npc.definition().race_id == &"beast", "%s visual follows its race" % npc.character_id)
		_assert_eq(PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM).origin, body.global_position, "%s enters physics at its marker, not the origin" % npc.character_id)
	await _free(session, tree)


func _test_water_sources(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree, true)
	var map: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	_assert_true(session.handoff_to(map.map_id(), OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, OldPineWorldDefinitions.WATERFALL_LANDING_SPAWN_POINT_ID).succeeded(), "public world reaches the Waterfall landing")
	var waterfall: WorldServicePoint = map.get_node("WaterfallWaterPoint") as WorldServicePoint
	map.player_body.global_position = waterfall.global_position + Vector2(0, -60)
	_assert_true(map.water_available(), "resource/water at the waterfall pool")
	_assert_true(session.fill_water_available(), "the supplies panel may fill here")
	_assert_eq(map.interaction_title(), "", "water adds no context button of its own")
	map.player_body.global_position = waterfall.global_position + Vector2(0, -150)
	_assert_false(map.water_available(), "out of reach of the waterfall pool")
	var lake: WorldServicePoint = map.get_node("LakeWaterPoint") as WorldServicePoint
	map.player_body.global_position = lake.global_position
	_assert_false(map.water_available(), "the lake point needs the player in the Lake zone")
	map.player_body.set_world_location(map.location_for_zone(OldPineWorldDefinitions.LAKE_ZONE_ID))
	_assert_true(map.water_available(), "resource/water at the lake shore")
	await _free(session, tree)


func _test_landmark_policies(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree)
	var map: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	_assert_true(map.select_landmark(&"oldpine.outdoor.landmark.ancient_pine"), "the clearing pine is selectable")
	var climb: WorldPortalTraversalResult = map.traverse_selected_portal() as WorldPortalTraversalResult
	_assert_true(climb != null and climb.completed(), "portal policy climbs the pine")
	_assert_eq(session.player_runtime().world_location().zone_id, OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID, "climb pine lands in the canopy")
	_assert_true(session.shared_ui().log_lines().has("Climb: 大松树"), "the action is logged as before")
	_assert_false(map.select_landmark(&"oldpine.outdoor.landmark.nope"), "unknown landmarks are not selectable")
	# Contact landmarks refuse without standing in their area, whatever the zone.
	map.player_body.global_position = Vector2(1300, 1300)
	map.player_body.set_world_location(map.location_for_zone(OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID))
	_assert_true(map.select_landmark(&"oldpine.outdoor.landmark.riverbank1_cliff"), "the river cliff is selectable from afar")
	_assert_false(map.landmark_available(GameContent.catalog().landmark(&"oldpine.outdoor.landmark.riverbank1_cliff")), "contact landmark is unavailable away from its area")
	var refused: WorldPortalTraversalResult = map.traverse_selected_portal() as WorldPortalTraversalResult
	_assert_true(refused != null and not refused.completed(), "no climb without contact")
	_assert_eq(session.player_runtime().world_location().zone_id, OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID, "refused climb does not move the player")
	await _free(session, tree)


func _test_zone_links_and_waterfall_cliff(tree: SceneTree) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_assert_true(catalog.zones_adjacent(OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID), "recorded Pine threshold link")
	_assert_true(catalog.zones_adjacent(OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID), "fixed maze link works both ways")
	_assert_false(catalog.zones_adjacent(OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID), "no ES2 exit from the bridge down to the pool")
	_assert_false(catalog.zones_adjacent(OldPineWorldDefinitions.SOUTH_SLOPE_ZONE_ID, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID), "no ES2 exit from the south slope to the pool")
	var session: OldPineWorldSessionController = await _session(tree)
	var map: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	var body: WorldCharacterBody2D = map.player_body
	for probe: Array in [[Vector2(1200, 560), Vector2(0, 80), "bridge edge"], [Vector2(860, 850), Vector2(80, 0), "south slope edge"]]:
		_assert_true(body.test_move(Transform2D(0.0, probe[0]), probe[1]), "the waterfall cliff blocks the %s" % probe[2])
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
