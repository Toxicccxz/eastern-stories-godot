extends RefCounted

const HistoricalCombat := preload("res://tests/support/historical_world_combat_fixture.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")

const SceneType := preload(
	"res://scenes/world/oldpine/oldpine_world_session.tscn"
)

class CountingMaximumCombatRandomSource extends CombatRandomSource:
	var calls: int = 0

	func next_below(exclusive_upper_bound: int) -> int:
		calls += 1
		return exclusive_upper_bound - 1 if exclusive_upper_bound > 0 else -1

class CountingAttackFavoringRandomSource extends CombatRandomSource:
	var calls: int = 0

	func next_below(exclusive_upper_bound: int) -> int:
		calls += 1
		if exclusive_upper_bound <= 0:
			return -1
		return 0 if calls <= 4 else exclusive_upper_bound - 1

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_authored_definitions_and_fixed_zone_partition()
	await _test_persisted_maze_geometry_and_zone_transitions(tree)
	await _test_tall_bandit_runtime_aggression_death_loot_and_equip(tree)
	await _test_partial_tall_death_is_not_lootable(tree)
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _test_authored_definitions_and_fixed_zone_partition() -> void:
	_assert_true(GameContent.load_errors().is_empty(), "Old Pine world definitions validate")
	_assert_true(GameContent.load_errors().is_empty(), "Old Pine NPC definitions validate")
	_assert_true(TestContent.spawns_match_world(), "Old Pine spawn definitions validate")
	_assert_eq(
		GameContent.catalog().zone(
			OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID
		).room_ids(),
		[&"es2:d/oldpine/pine1", &"es2:d/oldpine/pine2"],
		"Pine Entrance has exact source-room trace",
	)
	_assert_eq(
		GameContent.catalog().zone(
			OldPineWorldDefinitions.PINE_DEEP_ZONE_ID
		).room_ids(),
		[
			&"es2:d/oldpine/pine3", &"es2:d/oldpine/pine4",
			&"es2:d/oldpine/pine5", &"es2:d/oldpine/pine6",
		],
		"Pine Deep has exact source-room trace",
	)
	_assert_eq(
		GameContent.catalog().zone(
			OldPineWorldDefinitions.PINE_CLIFF_EDGE_ZONE_ID
		).room_ids(),
		[&"es2:d/oldpine/cliffdown", &"es2:d/oldpine/pine7"],
		"Pine Cliff Edge has exact source-room trace",
	)
	var pine_room_counts: Dictionary[StringName, int] = {}
	for zone_id: StringName in [
		OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID,
		OldPineWorldDefinitions.PINE_DEEP_ZONE_ID,
		OldPineWorldDefinitions.PINE_CLIFF_EDGE_ZONE_ID,
	]:
		var zone: ZoneDefinition = GameContent.catalog().zone(zone_id)
		_assert_eq(zone.combat_location_id, zone_id, "Pine combat location is exact zone ID")
		for source_path: StringName in zone.room_ids():
			pine_room_counts[source_path] = pine_room_counts.get(source_path, 0) + 1
	_assert_eq(pine_room_counts.size(), 8, "exactly eight Pine legacy rooms are represented")
	for source_path: StringName in pine_room_counts:
		_assert_eq(pine_room_counts[source_path], 1, "%s occurs exactly once" % source_path)
	for portal_id: StringName in [
			OldPineWorldDefinitions.CLIMB_PINE_PORTAL_ID,
			OldPineWorldDefinitions.DESCEND_TREE1_PORTAL_ID,
			OldPineWorldDefinitions.VINE_WATERFALL_PORTAL_ID,
			OldPineWorldDefinitions.VINE_PASSAGE_PORTAL_ID,
			OldPineWorldDefinitions.PASSAGE_SOUTH_PORTAL_ID,
			OldPineWorldDefinitions.RIVERBANK1_CLIFF_PORTAL_ID,
			OldPineWorldDefinitions.CLIFF1_DOWN_PORTAL_ID,
			OldPineWorldDefinitions.CLIFF1_UP_PORTAL_ID,
	]:
		_assert_true(GameContent.catalog().portal(portal_id) != null, "%s is authored" % portal_id)

	var tall: NpcDefinition = TestContent.npc(TestContent.TALL_BANDIT_NPC_ID)
	_assert_eq(tall.definition_id, &"oldpine.npc.tall_bandit", "tall bandit ID")
	_assert_eq(tall.display_name, "土匪", "tall bandit display name")
	_assert_eq(tall.aliases(), [&"bandit"], "tall bandit alias")
	_assert_eq(tall.gender, CharacterState.GENDER_MALE, "tall bandit gender")
	_assert_eq(tall.age, 27, "tall bandit age")
	_assert_eq(tall.combat_experience, 900, "tall bandit combat experience")
	_assert_eq(tall.score, 100, "tall bandit score")
	_assert_eq(tall.attitude, NpcDefinition.Attitude.AGGRESSIVE, "tall bandit attitude")
	_assert_eq(
		_skill_pairs(tall.skill_levels()),
		[[&"sword", 15], [&"parry", 15], [&"dodge", 10]],
		"tall bandit exact authored skills",
	)
	_assert_true(tall.base_attribute_overrides().is_empty(), "no invented base overrides")
	_assert_true(tall.resource_overrides().is_empty(), "no invented resource overrides")
	var loadout: Array[NpcLoadoutEntry] = tall.loadout_entries()
	_assert_eq(loadout.size(), 2, "tall bandit has exactly two loadout entries")
	_assert_eq(loadout[0].item_definition_id, TestContent.LONG_SWORD_ITEM_ID, "long sword loadout ID")
	_assert_eq(loadout[0].quantity, 1, "one long sword")
	_assert_eq(loadout[0].equipment_intent, NpcLoadoutEntry.EquipmentIntent.WIELD_PRIMARY, "long sword starts wielded")
	_assert_eq(loadout[1].item_definition_id, TestContent.SILVER_ITEM_ID, "silver loadout ID")
	_assert_eq(loadout[1].quantity, 6, "six silver")
	var sword: NpcLoadoutItemDefinition = TestContent.loadout(TestContent.LONG_SWORD_ITEM_ID)
	var canonical_sword: ItemContentDefinition = (
		TestContent.item(
			TestContent.LONG_SWORD_ITEM_ID
		)
	)
	_assert_eq(sword.item_definition().item_definition_id, canonical_sword.item_definition_id, "NPC loadout uses canonical long-sword ID")
	_assert_eq(sword.own_weight, canonical_sword.own_weight, "NPC loadout projects canonical weight 7000")
	_assert_eq(sword.weapon_damage, canonical_sword.weapon_damage, "NPC loadout projects canonical damage 25")
	_assert_eq(sword.weapon_definition().skill_type, &"sword", "long sword skill type")
	_assert_false(sword.weapon_definition().can_wield_as_secondary, "long sword has no SECONDARY flag")
	_assert_eq(
		sword.legacy_source_paths(),
		["d/oldpine/obj/long_sword.c", "d/oldpine/npc/obj/long_sword.c"],
		"long sword keeps both source paths",
	)
	_assert_eq(
		TestContent.loadout(TestContent.SILVER_ITEM_ID).currency_definition().value_for_amount(6),
		600,
		"six silver has LPC-derived value 600",
	)
	var spawn: NpcSpawnDefinition = TestContent.spawn(TestContent.PINE1_TALL_BANDIT_SPAWN_ID)
	_assert_eq(spawn.zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "tall bandit spawns in Pine Entrance")
	_assert_eq(spawn.quantity, 1, "exactly one tall bandit")
	_assert_eq(spawn.legacy_source_room_path, "d/oldpine/pine1.c", "tall spawn traces pine1")


func _test_persisted_maze_geometry_and_zone_transitions(tree: SceneTree) -> void:
	# Synchronize scene cleanup before beginning collision-backed movement proofs.
	await tree.physics_frame
	var controller: WorldMapController = _instantiate_scene(tree)
	_assert_true(controller != null, "Old Pine scene instantiates for maze geometry")
	if controller == null:
		return
	var initial_npcs: Array[NpcRuntimeState] = controller.npc_runtimes()
	_assert_eq(initial_npcs.size(), 19, "scene ready constructs all 19 forest NPCs before Area signals (the keep's hall is its own map since the remap)")
	_assert_eq(initial_npcs[3].world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "Tall starts logically in Pine Entrance before Area signals")
	await tree.physics_frame
	_assert_true(controller.find_children("ResetButton", "Button", true, false).is_empty(), "fixed Pine Maze hierarchy reflects Phase 10C1A Reset removal")
	# The high ground east of the gorge is drawn with 16 px terrain tiles whose physics is the
	# collision: one trodden way between the pines with a deep branch, no maze any more
	# (tools/maps/layouts/oldpine.json; DECISIONS「老松林的林径与藏起来的寨门」).
	_assert_eq(_openings(controller, Vector2(1528, -496), Vector2(1528, 996)), [[400, 512]], "the high ground's west edge opens only where the plank road comes up from epath3 (pine1); the cliffs are closed")
	_assert_eq(_openings(controller, Vector2(1524, 696), Vector2(2592, 696)), [[1620, 1764]], "the south edge opens only to the cliffside (pine1 to cliffside)")
	var north: Array = _openings(controller, Vector2(2104, 264), Vector2(2592, 264))
	_assert_true(north.size() == 1 and north[0][0] >= 2140 and north[0][1] <= 2320, "Entrance and Deep are joined by one way, the trail north: %s" % [north])
	_assert_eq(_openings(controller, Vector2(1524, 264), Vector2(2096, 264)), [], "Entrance and Cliff Edge do not meet")
	var west: Array = _openings(controller, Vector2(2096, -496), Vector2(2096, 256))
	_assert_true(west.size() == 1 and west[0][0] >= -460 and west[0][1] <= -120, "Deep and Cliff Edge are joined by one way, round to pine7: %s" % [west])
	var keep_way: Array = _openings(controller, Vector2(2660, 324), Vector2(2660, 636))
	_assert_true(keep_way.size() == 1, "one way leads east to the keep (pine2 east → keep1): %s" % [keep_way])
	for gone: Vector2 in [Vector2(2560, 120), Vector2(2400, -20), Vector2(2900, -120), Vector2(3112, 48), Vector2(2440, -420)]:
		_assert_eq(TerrainProbe.terrain_at(controller, gone), "forest", "the old loop and dead ends at %s are forest" % gone)
	_assert_eq(TerrainProbe.terrain_at(controller, Vector2(2200, -170)), "forest_floor", "the deep branch is drawn as forest floor")
	_assert_eq(TerrainProbe.terrain_at(controller, Vector2(2400, 510)), "forest_floor", "the way to the thicket is drawn as forest floor")
	_assert_eq(TerrainProbe.terrain_at(controller, Vector2(1548, 140)), "cliff", "the cliff's edge west of cliffdown is drawn as cliff")
	var thicket: WorldDoor = controller.door(&"oldpine.pine.thicket")
	_assert_true(thicket != null and not thicket.is_open(), "the thicket across the way to keep1 stands shut at first")
	var thicket_definition: DoorDefinition = GameContent.catalog().door(&"oldpine.pine.thicket")
	_assert_true(thicket_definition != null and thicket_definition.found_by == "老松寨的小径" and not thicket_definition.operable, "the thicket is a way found by the knife marks' mark, worked by no hand")
	for zone_name: String in ["PineEntranceZone", "PineDeepZone", "PineCliffEdgeZone"]:
		var zone: Area2D = controller.get_node_or_null("Zones/%s" % zone_name) as Area2D
		_assert_true(zone != null, "%s persists" % zone_name)
		_assert_eq(zone.get_signal_connection_list("body_entered").size(), 1, "%s has one typed zone adapter" % zone_name)
	var bridge_rect: Rect2 = _zone_rect(controller, "EastBridgeZone")
	var entrance_rect: Rect2 = _zone_rect(controller, "PineEntranceZone")
	var deep_rect: Rect2 = _zone_rect(controller, "PineDeepZone")
	var cliff_rect: Rect2 = _zone_rect(controller, "PineCliffEdgeZone")
	var cliffside_rect: Rect2 = _zone_rect(controller, "CliffsideZone")
	_assert_eq(entrance_rect.position.x, bridge_rect.end.x, "Pine Entrance begins at the east bank's edge, where the plank road comes up")
	_assert_eq([entrance_rect.position.x, cliff_rect.position.x, cliffside_rect.position.x], [1520.0, 1520.0, 1520.0], "pine1, cliffdown and the cliffside share the high ground's west edge")
	_assert_eq(entrance_rect.position.y, cliff_rect.end.y, "Cliff Edge lies north of the Entrance without gap or interior overlap")
	_assert_eq(entrance_rect.position.y, deep_rect.end.y, "Entrance and Deep meet without gap or interior overlap")
	_assert_eq(deep_rect.position.x, cliff_rect.end.x, "Deep and Cliff Edge meet without gap or interior overlap")
	_assert_eq(cliffside_rect.position.y, entrance_rect.end.y, "Cliffside meets Pine Entrance at its south edge")

	# Keep both pine1 bandits off the walked ways and out of presence range of them: at the
	# slope's far end, across the gorge.
	OldPineTestMap.body(controller, "TallBandit").global_position = Vector2(430, 1060)
	OldPineTestMap.body(controller, "FatBandit").global_position = Vector2(470, 1030)
	# On epath3, at the foot of the plank road (the fixture moves the zone authority with the body).
	controller.player_body.global_position = Vector2(1430, 400)
	controller.player_body.set_world_location(controller.location_for_zone(OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID))
	await tree.physics_frame
	var player_state: CharacterState = controller.player_runtime().state
	var resources_before: Array[int] = [
		player_state.essence.current,
		player_state.vitality.current,
		player_state.spirit.current,
	]
	# The ways through the pines, as the layout draws them (each point a gap's middle).
	var up_the_plank_road: Array[Vector2] = [Vector2(1500, 452), Vector2(1576, 470), Vector2(1640, 474)]
	var into_pines: Array[Vector2] = [Vector2(1720, 480)]
	var north_way: Array[Vector2] = [Vector2(1860, 420), Vector2(2040, 380), Vector2(2200, 340), Vector2(2240, 200), Vector2(2240, 60), Vector2(2240, -20)]
	var deep_way: Array[Vector2] = [Vector2(2200, -160), Vector2(2120, -290)]
	var to_cliffdown: Array[Vector2] = [Vector2(1960, -380), Vector2(1820, -220), Vector2(1720, -40), Vector2(1680, 80), Vector2(1650, 140)]
	var to_the_thicket: Array[Vector2] = [Vector2(1860, 540), Vector2(2000, 560), Vector2(2200, 540), Vector2(2400, 510), Vector2(2540, 492)]
	_assert_true(await _walk_route(controller.player_body, up_the_plank_road), "the plank road from epath3 leads up into Pine Entrance")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "physical threshold enters Pine Entrance")
	_assert_true(await _walk_route(controller.player_body, into_pines), "Pine Entrance floor is traversable")
	_assert_true(await _walk_route(controller.player_body, north_way.slice(0, 3) + [Vector2(2212, 300)]), "Pine Entrance reaches its northern opening")
	_assert_true(await _walk_route(controller.player_body, [Vector2(2234, 220)]), "physical Entrance-to-Deep seam is traversable")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, "Entrance-to-Deep seam assigns Deep without a gap")
	_assert_true(await _walk_route(controller.player_body, [Vector2(2212, 300)]), "physical Deep-to-Entrance seam is traversable")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "Deep-to-Entrance seam assigns Entrance deterministically")
	_assert_true(await _walk_route(controller.player_body, north_way.slice(3) + deep_way), "the trail north leads into the deep pines and round towards pine7")
	_assert_true(controller.player_body.move_and_collide(Vector2(160, 0), true) != null, "no way east out of the deep pines: the old loop is forest")
	_assert_true(await _walk_route(controller.player_body, to_cliffdown.slice(0, 1)), "the deep branch reaches pine7's hollow")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_CLIFF_EDGE_ZONE_ID, "Deep-to-Cliff Edge seam assigns Cliff Edge without a gap")
	_assert_true(await _walk_route(controller.player_body, to_cliffdown.slice(1)), "the branch goes on down to the cliff's edge")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_CLIFF_EDGE_ZONE_ID, "physical route enters Pine Cliff Edge")
	var cliff_collision: KinematicCollision2D = controller.player_body.move_and_collide(Vector2(-200, 0))
	_assert_true(cliff_collision != null, "the drop west of cliffdown is physically closed (climbed, not walked)")
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_CLIFF_EDGE_ZONE_ID, "blocked cliff edge retains Pine Cliff Edge location")
	var back: Array[Vector2] = to_cliffdown.duplicate()
	back.reverse()
	_assert_true(await _walk_route(controller.player_body, back.slice(1)), "the way back climbs to pine7's hollow")
	var back_deep: Array[Vector2] = deep_way.duplicate()
	back_deep.reverse()
	_assert_true(await _walk_route(controller.player_body, back_deep), "the way back re-enters the deep pines")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, "Cliff Edge-to-Deep seam assigns Deep deterministically")
	var back_north: Array[Vector2] = north_way.duplicate()
	back_north.reverse()
	_assert_true(await _walk_route(controller.player_body, back_north + [Vector2(1720, 480), Vector2(1640, 474), Vector2(1576, 470), Vector2(1500, 452), Vector2(1430, 400)]), "the same trail leads back to the plank road and down to the east bank")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID, "physical return restores existing Outdoor location")
	_assert_eq(
		[
			player_state.essence.current,
			player_state.vitality.current,
			player_state.spirit.current,
		],
		resources_before,
		"physical zone traversal does not mutate CharacterState resources",
	)

	# pine1 south <-> cliffside is ordinary walking now (formerly a same-map portal).
	controller.player_body.global_position = Vector2(1720, 480)
	_assert_true(await _walk_route(controller.player_body, [Vector2(1704, 580), Vector2(1690, 680), Vector2(1700, 780), Vector2(1700, 850)]), "Pine Entrance walks south into the cliffside")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.CLIFFSIDE_ZONE_ID, "south opening assigns the cliffside")
	_assert_true(await _walk_route(controller.player_body, [Vector2(1690, 680), Vector2(1704, 580)]), "cliffside walks north back into Pine Entrance")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "cliffside-to-pine1 walk restores Pine Entrance")

	# East, the trail ends at the thicket: shut until the knife marks are followed, then the
	# way to keep1 and open ever after (the mark is saved; a map bound for a player who holds it
	# opens the door at once).
	controller.player_body.global_position = Vector2(1720, 480)
	_assert_true(await _walk_route(controller.player_body, to_the_thicket), "the trail east reaches the thicket")
	_assert_true(controller.player_body.move_and_collide(Vector2(60, 0), true) != null, "the thicket blocks the way on east while shut")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "before the thicket the player is still in Pine Entrance")
	_assert_true(controller.select_landmark(&"oldpine.outdoor.landmark.pine_knife_marks"), "the knife marks by the thicket can be chosen")
	var found: FindWayLandmarkPolicy.Result = controller.traverse_selected_portal() as FindWayLandmarkPolicy.Result
	_assert_true(found != null and found.used and found.found, "following the knife marks finds the path")
	_assert_eq(int(player_state.marks.get("老松寨的小径", 0)), 1, "the find gives its mark")
	_assert_true(thicket.is_open(), "the thicket opens")
	var hud_lines: Array[String] = controller.session.shared_ui().log_lines()
	_assert_true(hud_lines.has("你顺着树上的刀痕往东找去，拨开那丛灌木，后面果然有一条踩得结实的小径，通往林子深处。"), "the find is told")
	_assert_true(hud_lines.has("【见闻】你顺着松树上的刀痕，在崖上林径尽头的灌木后找到了一条小径，通往老松寨。"), "the journal records the knife marks: %s" % [hud_lines.slice(-4)])
	var again: FindWayLandmarkPolicy.Result = controller.traverse_selected_portal() as FindWayLandmarkPolicy.Result
	_assert_true(again != null and again.used and not again.found, "followed again, the marks only point at the path")
	_assert_true(controller.session.shared_ui().log_lines().has("刀痕指的就是灌木后面那条小径。"), "the second use says so")
	await tree.physics_frame
	await tree.physics_frame
	_assert_true(await _walk_route(controller.player_body, [Vector2(2640, 486), Vector2(2700, 480)]), "through the thicket the trail goes on to keep1")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, &"oldpine.outdoor.keep_gate", "past the thicket the player stands before keep1's gate")
	_assert_true(await _walk_route(controller.player_body, [Vector2(2640, 486), Vector2(2540, 492)]), "and back west through it")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "back in Pine Entrance")
	# A map bound again for a player who holds the mark (Continue) finds the thicket open.
	thicket.set_open(false)
	_assert_true(controller._bind_doors(), "the forest's doors bind again")
	_assert_true(thicket.is_open(), "bound for a player who holds the mark, the thicket stands open")
	player_state.marks.erase("老松寨的小径")
	_assert_true(controller._bind_doors(), "the forest's doors bind again without the mark")
	_assert_false(thicket.is_open(), "without the mark the thicket is shut")

	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID,
	))
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "Pine Entrance has stable combat location")
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID,
	))
	_assert_eq(controller.player_runtime().world_location().combat_location_id, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, "Pine Deep has stable combat location")
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.PINE_CLIFF_EDGE_ZONE_ID, OldPineWorldDefinitions.PINE_CLIFF_EDGE_ZONE_ID,
	))
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_CLIFF_EDGE_ZONE_ID, "Pine Cliff Edge has stable zone identity")
	# Continue: the mark is saved, and a session restored from the save binds the forest's doors
	# for a player who holds it: the thicket stands open (DoorDefinition.found_by).
	player_state.marks["老松寨的小径"] = 1
	# Everyone on a valid spot for the capture: the two bandits back on their markers, the
	# player on the trail before the thicket.
	for name: String in ["TallBandit", "FatBandit"]:
		OldPineTestMap.body(controller, name).global_position = controller.resolve_spawn_marker(OldPineTestMap.POINTS[name]).global_position
	controller.player_body.global_position = MapPlaces.spot(controller, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, Vector2(2300, 520), 64.0)
	controller.player_body.set_world_location(controller.location_for_zone(OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID))
	await tree.physics_frame
	await tree.physics_frame
	var snapshot: GameSaveSnapshot = Work.capture(controller.session)
	_assert_true(snapshot != null, "the forest session captures with the mark held")
	controller.session.queue_free()
	await tree.process_frame
	await tree.process_frame
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(snapshot, tree.root)
	_assert_eq(restored.outcome, OldPineWorldRestoreResult.Outcome.SUCCESS, "the save restores (%s: %s)" % [restored.path, restored.detail])
	if restored.candidate != null:
		var forest: WorldMapController = restored.candidate.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
		var found_way: WorldDoor = null if forest == null else forest.door(&"oldpine.pine.thicket")
		_assert_true(found_way != null and found_way.is_open(), "Continue finds the thicket open: a way once found stays found")
		restored.candidate.queue_free()
		await tree.process_frame


func _test_tall_bandit_runtime_aggression_death_loot_and_equip(
	tree: SceneTree,
) -> void:
	var controller: WorldMapController = _instantiate_scene(tree)
	await tree.physics_frame
	var npcs: Array[NpcRuntimeState] = controller.npc_runtimes()
	_assert_eq(npcs.size(), 19, "forest runtime owns its 19 NPCs (the keep's hall is its own map since the remap)")
	_assert_eq(controller.session.world_npcs().size(), 36, "Old Pine runtime owns its 36 NPCs")
	var tall: NpcRuntimeState = npcs[3]
	_assert_eq(tall.definition_id, TestContent.TALL_BANDIT_NPC_ID, "fourth runtime is exact tall bandit")
	_assert_eq(tall.world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "tall runtime starts in Pine Entrance")
	_assert_eq(OldPineTestMap.body(controller, "TallBandit").global_position, (controller.get_node("SpawnPoints/Pine1TallBanditSpawn") as Marker2D).global_position, "tall body starts at exact marker")
	_assert_eq(OldPineTestMap.body(controller, "TallBandit").get_signal_connection_list("selection_requested").size(), 1, "tall selection signal persists once")
	var presence: Area2D = OldPineTestMap.body(controller, "TallBandit").get_node("AggressionPresence") as Area2D
	_assert_eq(presence.get_signal_connection_list("body_entered").size(), 1, "tall aggression enter signal persists once")
	_assert_eq(presence.get_signal_connection_list("body_exited").size(), 1, "tall aggression exit signal persists once")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	# A click selects nothing (owner, 2026-10-11); a nearby group's button selects.
	OldPineTestMap.body(controller, "TallBandit")._input_event(controller.get_viewport(), click, 0)
	_assert_true(controller.selected_character_id() != tall.character_id, "clicking Tall selects nothing")
	_assert_true(controller.select_npc(tall.character_id), "Tall can be selected")
	_assert_eq(controller.selected_character_id(), tall.character_id, "selecting Tall selects exact Tall identity")
	_assert_true(controller.select_npc(npcs[0].character_id), "the first bandit can be selected")
	_assert_eq(controller.selected_character_id(), npcs[0].character_id, "selecting the existing bandit still selects exact original identity")
	var map_local_timer_count: int = 0
	for child: Node in controller.get_children():
		if child is Timer:
			map_local_timer_count += 1
	_assert_eq(map_local_timer_count, 0, "combat cadence is the session encounter scheduler, not a map Timer")

	var long_sword: ItemInstance = _item_by_definition(tall.loadout_items(), TestContent.LONG_SWORD_ITEM_ID)
	var silver: ItemInstance = _item_by_definition(tall.loadout_items(), TestContent.SILVER_ITEM_ID)
	_assert_true(long_sword != null, "tall runtime owns long sword instance")
	_assert_true(silver != null, "tall runtime owns silver instance")
	var tall_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.CHARACTER,
		tall.character_id,
	)
	_assert_true(controller.inventory_state().is_direct_child(long_sword.item_instance_id, tall_endpoint), "tall long sword is direct owned inventory")
	_assert_true(controller.inventory_state().is_direct_child(silver.item_instance_id, tall_endpoint), "tall silver is direct owned inventory")
	_assert_true(controller.item_instance_index().resolve(long_sword.item_instance_id) != null, "tall long sword is present in map-local item index")
	_assert_true(controller.item_instance_index().resolve(silver.item_instance_id) != null, "tall silver is present in map-local item index")
	_assert_ne(long_sword.item_instance_id, controller.player_runtime().state.equipment.primary_weapon().instance_id, "tall and player long swords have distinct live identities")
	_assert_eq(tall.character_state.equipment.primary_weapon().instance_id, long_sword.item_instance_id, "tall long sword starts in primary hand")
	_assert_eq(controller.stack_collection().stack_state(silver.item_instance_id).amount, 6, "tall silver stack amount is six")
	_assert_eq(controller.inventory_state().own_weight(silver.item_instance_id), 222, "six silver weighs 6 * 37")
	var participants: Array[CombatSliceCharacterBinding] = controller.combat_lifecycle.build_participants()
	_assert_eq(participants.size(), 15, "combat projection includes player and the forest map's 14 present NPCs (the keep's hall is its own map since the remap)")
	_assert_eq(participants[4].content.projected_apply_damage(participants[4].state.equipment.primary_weapon()), 25, "tall combat projection uses long-sword damage 25")
	var tall_primary: EquippedWeaponRef = tall.character_state.equipment.primary_weapon()
	_assert_true(tall.character_state.equipment.unwield(tall_primary.instance_id).succeeded, "audit can remove Tall current primary through Equipment authority")
	var unequipped_binding: CombatSliceCharacterBinding = _binding_for(controller.combat_lifecycle.build_participants(), tall.character_id)
	_assert_eq(unequipped_binding.content.projected_apply_damage(unequipped_binding.state.equipment.primary_weapon()), 0, "authored Tall profile does not override live unequipped state")
	_assert_true(tall.character_state.equipment.wield(tall_primary, false).succeeded, "audit restores Tall primary before combat")

	var random: CountingMaximumCombatRandomSource = CountingMaximumCombatRandomSource.new()
	controller.session.configure_combat_random_source(random)
	_assert_true(HistoricalCombat.tick(controller).is_empty(), "idle Tall creates no combat opportunity")
	_assert_eq(random.calls, 0, "idle Tall consumes zero Combat RNG")
	controller.set_process(false)
	# TEST-ONLY: the loot loop's fights are Tall alone (进门一起上 would bring Fat).
	var aside: Array[NpcRuntimeState] = OldPineTestMap.stand_aside(controller, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, [tall.character_id])
	# A teleport, not a walk: the zone follows the body before its presence reports it.
	controller.player_body.set_world_location(controller.location_for_zone(OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID))
	controller.player_body.global_position = OldPineTestMap.body(controller, "TallBandit").global_position
	await tree.physics_frame
	await tree.physics_frame
	_assert_true(controller.aggression_adapter().has_pending(tall.character_id), "physical tall-bandit presence queues aggression")
	_assert_eq(random.calls, 0, "presence and aggression decision consume no Combat RNG")
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID,
	))
	_assert_true(controller.process_pending_aggression().is_empty(), "escape before deferred recheck starts no combat")
	_assert_false(tall.relationship.is_fighting(), "escaped tall presence creates no relationship")
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID,
	))
	OldPineTestMap.presence_exited(controller, 3, controller.player_body)
	OldPineTestMap.presence_entered(controller, 3, controller.player_body)
	var starts: Array[CombatSliceInitiationResult] = controller.process_pending_aggression()
	_assert_eq(starts.size(), 1, "one tall aggressor establishes combat")
	_assert_eq(starts[0].initiator_id, tall.character_id, "aggression initiator is exact tall bandit")
	_assert_true(tall.relationship.has_lethal_target(controller.player_runtime().character_id), "tall bandit gains reciprocal lethal relation")
	_assert_eq(random.calls, 0, "relationship initiation remains RNG-free")
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID,
	))
	HistoricalCombat.tick(controller)
	_assert_false(controller.player_runtime().relationship.has_opponent(tall.character_id), "Pine zone change uses closed opponent cleanup")
	_assert_false(tall.relationship.has_opponent(controller.player_runtime().character_id), "Pine zone cleanup is reciprocal")
	_assert_true(controller.player_runtime().relationship.has_lethal_target(tall.character_id), "Pine zone cleanup preserves lethal marker")
	_assert_eq(random.calls, 0, "different-location cleanup consumes no Combat RNG")
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID,
	))
	OldPineTestMap.presence_exited(controller, 3, controller.player_body)
	OldPineTestMap.presence_entered(controller, 3, controller.player_body)
	_assert_eq(controller.process_pending_aggression().size(), 1, "returning to Pine Entrance permits authored aggression again")
	HistoricalCombat.set_running(controller, false)
	var attack_random: CountingAttackFavoringRandomSource = (
		CountingAttackFavoringRandomSource.new()
	)
	controller.session.configure_combat_random_source(attack_random)
	controller.player_runtime().busy.start_busy(1)
	var actual_tall_apply_damage: int = -1
	for _opportunity: int in range(6):
		for result: CombatSliceOpportunityResult in HistoricalCombat.tick(controller):
			if result.actor_id != tall.character_id:
				continue
			var forward: CombatSingleAttackExecutionResult = result.forward_result
			if forward == null or forward.ordinary_attack_result == null:
				continue
			var ordinary: CombatOrdinaryAttackResult = forward.ordinary_attack_result
			if ordinary.has_base_result and ordinary.base_result != null:
				actual_tall_apply_damage = ordinary.base_result.calculation.base_apply_damage
				break
		if actual_tall_apply_damage >= 0:
			break
	_assert_eq(actual_tall_apply_damage, 25, "actual tall attack calculation receives long-sword damage 25")
	_assert_true(attack_random.calls > 0, "actual tall combat consumes only Combat RNG")

	HistoricalCombat.set_running(controller, false)
	controller.session.configure_combat_random_source(CountingMaximumCombatRandomSource.new())
	controller.player_runtime().busy.start_busy(1)
	# BF3: source death copies stored body facts even after raw strength changes.
	var expected_body_weight: int = tall.body_weight
	var expected_capacity: int = tall.maximum_encumbrance
	tall.character_state.attributes.strength = 30
	# On the trail north, inside Pine Deep.
	controller.player_body.global_position = Vector2(2240, 100)
	OldPineTestMap.body(controller, "TallBandit").global_position = Vector2(2240, 100)
	# NPCs never walk between zones; the fixture moves both authorities with the bodies.
	controller.player_body.set_world_location(controller.location_for_zone(OldPineWorldDefinitions.PINE_DEEP_ZONE_ID))
	OldPineTestMap.body(controller, "TallBandit").set_world_location(controller.location_for_zone(OldPineWorldDefinitions.PINE_DEEP_ZONE_ID))
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, "player live authority reaches Pine Deep before Tall death")
	_assert_eq(tall.world_location().zone_id, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, "Tall live authority reaches Pine Deep before death")
	var current_participants: Array[CombatSliceCharacterBinding] = controller.combat_lifecycle.build_participants()
	var tall_binding: CombatSliceCharacterBinding = _binding_for(current_participants, tall.character_id)
	var killer_binding: CombatSliceCharacterBinding = _binding_for(current_participants, controller.player_runtime().character_id)
	var death_destination: InventoryTransferDestination = controller.combat_lifecycle._world_destination_for(tall.character_id)
	var death_context: DeathContext = controller.combat_lifecycle._death_context_for(tall_binding, killer_binding, death_destination)
	_assert_eq(death_context.victim_display_name, "土匪", "Tall death context uses authored display name")
	_assert_eq(death_context.victim_gender, CharacterState.GENDER_MALE, "Tall death context uses current gender")
	_assert_eq(death_context.victim_age, 27, "Tall death context uses authored age")
	_assert_eq(death_context.victim_body_own_weight, expected_body_weight, "Tall death context copies established NPC body weight")
	_assert_eq(death_context.victim_maximum_encumbrance, expected_capacity, "Tall death context copies established NPC capacity")
	_assert_true(death_context.victim_owner.equipment_state == tall.character_state.equipment, "Tall death context uses current EquipmentState")
	_assert_true(death_context.victim_owner.armor_state == tall.armor, "Tall death context uses current ArmorState")
	_assert_eq(death_context.victim_environment.endpoint.kind, ContainmentEndpoint.Kind.WORLD, "Tall death destination is a WORLD endpoint")
	_assert_eq(death_context.victim_environment.endpoint.endpoint_id, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, "Tall death context reads current Pine location")
	tall.character_state.vitality.current = -1
	HistoricalCombat.tick(controller)
	for _tick: int in range(24):
		if tall.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			break
		HistoricalCombat.tick(controller)
	_assert_eq(tall.life_status, CharacterRuntimeLifeStatus.Value.DEAD, "existing combat lifecycle kills tall bandit")
	_assert_false(tall.exists_in_map, "dead tall bandit leaves active map membership")
	_assert_false(OldPineTestMap.body(controller, "TallBandit").visible, "dead tall body is hidden")
	_assert_eq(controller.corpse_states().size(), 1, "tall death creates one corpse")
	var corpse: CorpseState = controller.corpse_states()[0]
	_assert_eq(corpse.victim_display_name, "土匪", "Tall corpse preserves authored display name")
	_assert_eq(corpse.victim_gender, CharacterState.GENDER_MALE, "Tall corpse preserves authored gender")
	_assert_eq(corpse.victim_age, 27, "Tall corpse preserves authored age")
	_assert_eq(controller.inventory_state().direct_parent(corpse.corpse_item_instance_id).endpoint_id, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, "Tall corpse is placed at current Pine Deep endpoint")
	var corpse_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.ITEM,
		corpse.corpse_item_instance_id,
	)
	_assert_true(controller.inventory_state().is_direct_child(long_sword.item_instance_id, corpse_endpoint), "long sword transfers into corpse")
	_assert_true(controller.inventory_state().is_direct_child(silver.item_instance_id, corpse_endpoint), "silver transfers into corpse")
	_assert_true(tall.character_state.equipment.is_primary_hand_empty(), "death transfer unwields the same Tall long sword")
	_assert_eq(controller.stack_collection().stack_state(silver.item_instance_id).amount, 6, "corpse preserves silver amount six")
	var corpse_view: CombatSliceCorpseView = controller.corpse_view_for(corpse.corpse_item_instance_id)
	controller.player_body.global_position = corpse_view.global_position
	await tree.physics_frame
	await tree.physics_frame
	_assert_true(controller.select_corpse(corpse.corpse_item_instance_id), "tall corpse is selectable")
	_assert_true(controller.open_selected_loot(), "tall corpse opens through existing loot UI boundary")
	var loot_rows: Array[WorldItemRowProjection] = controller.session.shared_ui().loot_rows()
	var long_row: WorldItemRowProjection = _loot_row(loot_rows, long_sword.item_instance_id)
	var silver_row: WorldItemRowProjection = _loot_row(loot_rows, silver.item_instance_id)
	_assert_true(long_row != null and long_row.display_name == "长剑", "Loot projects authored long sword")
	_assert_true(silver_row != null and silver_row.display_name == "银子", "Loot projects authored silver")
	_assert_eq(silver_row.amount, 6, "Loot projects silver amount six")
	var existing_silver: ItemInstance = _add_player_silver(controller, &"phase9b1.existing-player-silver", 3)
	_assert_true(existing_silver != null, "merge regression creates prior player silver amount three")
	var player_primary_before_take: StringName = (
		controller.player_runtime().state.equipment.primary_weapon().instance_id
	)
	_assert_true(controller.take_selected_loot_item(long_sword.item_instance_id).succeeded, "player takes exact long sword instance")
	_assert_eq(controller.player_runtime().state.equipment.primary_weapon().instance_id, player_primary_before_take, "Take does not auto-wield Tall long sword")
	var silver_take: CorpseLootTransferResult = controller.take_selected_loot_item(silver.item_instance_id)
	_assert_eq(silver_take.outcome, CorpseLootTransferResult.Outcome.COMPLETED_WITH_MERGE, "Tall silver uses existing corpse Take merge path")
	_assert_eq(silver_take.resulting_item_instance_id, silver.item_instance_id, "incoming Tall silver is closed-semantics survivor")
	var player_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.CHARACTER,
		WorldSessionController.PLAYER_ID,
	)
	_assert_true(controller.inventory_state().is_direct_child(long_sword.item_instance_id, player_endpoint), "looted long sword becomes player direct inventory")
	_assert_true(controller.inventory_state().is_direct_child(silver.item_instance_id, player_endpoint), "looted silver becomes player direct inventory")
	_assert_eq(controller.stack_collection().stack_state(silver.item_instance_id).amount, 9, "existing silver three plus Tall silver six merges to nine")
	_assert_eq(controller.inventory_state().own_weight(silver.item_instance_id), 333, "merged silver weight remains 9 * 37")
	_assert_eq(TestContent.loadout(TestContent.SILVER_ITEM_ID).currency_definition().value_for_amount(9), 900, "merged silver value remains 9 * 100")
	_assert_false(controller.inventory_state().is_registered(existing_silver.item_instance_id), "absorbed prior player silver is no longer live")
	_assert_true(OldPineTestMap.open_inventory(controller), "existing Inventory UI opens after Tall loot")
	_assert_eq(_definition_row_count(controller.session.shared_ui().inventory_rows(), TestContent.LONG_SWORD_ITEM_ID), 2, "two live long swords remain separate inventory rows")
	var original_primary: EquippedWeaponRef = controller.player_runtime().state.equipment.primary_weapon()
	_assert_true(OldPineTestMap.unwield(controller, original_primary.instance_id).succeeded, "existing equipment action unwields original long sword")
	_assert_true(OldPineTestMap.wield(controller, long_sword.item_instance_id).succeeded, "existing equipment action wields looted long sword")
	_assert_eq(controller.player_runtime().state.equipment.primary_weapon().instance_id, long_sword.item_instance_id, "looted instance is current primary authority")
	var player_binding: CombatSliceCharacterBinding = controller.combat_lifecycle.build_participants()[0]
	_assert_eq(player_binding.content.projected_apply_damage(player_binding.state.equipment.primary_weapon()), 25, "looted long sword preserves combat content projection")
	var old_tall_state: CharacterState = tall.character_state
	var old_long_id: StringName = long_sword.item_instance_id
	var old_silver_id: StringName = silver.item_instance_id
	OldPineTestMap.rejoin(aside)
	controller.queue_free()
	await tree.process_frame
	var fresh: WorldMapController = _instantiate_scene(tree)
	await tree.physics_frame
	var fresh_tall: NpcRuntimeState = fresh.npc_runtimes()[3]
	_assert_true(fresh_tall.character_state != old_tall_state, "fresh scene owns new tall CharacterState")
	_assert_eq(fresh_tall.world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "fresh tall returns to Pine Entrance")
	_assert_eq(fresh.corpse_states().size(), 0, "fresh scene clears tall corpse")
	_assert_true(fresh.selected_interaction_target() == null, "fresh scene clears stale interaction target")
	_assert_false(fresh.player_runtime().relationship.is_fighting(), "fresh scene clears player relationships")
	for fresh_npc: NpcRuntimeState in fresh.npc_runtimes():
		_assert_false(fresh_npc.relationship.is_fighting(), "fresh scene clears every NPC relationship")
	var fresh_long: ItemInstance = _item_by_definition(fresh_tall.loadout_items(), TestContent.LONG_SWORD_ITEM_ID)
	var fresh_silver: ItemInstance = _item_by_definition(fresh_tall.loadout_items(), TestContent.SILVER_ITEM_ID)
	_assert_ne(fresh_long.item_instance_id, old_long_id, "fresh tall owns new long-sword instance")
	_assert_ne(fresh_silver.item_instance_id, old_silver_id, "fresh tall owns new silver instance")
	_assert_eq(fresh.stack_collection().stack_state(fresh_silver.item_instance_id).amount, 6, "fresh tall restores silver amount six")
	_assert_eq(OldPineTestMap.body(fresh, "TallBandit").get_signal_connection_list("selection_requested").size(), 1, "fresh tall has no duplicate selection signal")
	_assert_eq((OldPineTestMap.body(fresh, "TallBandit").get_node("AggressionPresence") as Area2D).get_signal_connection_list("body_entered").size(), 1, "fresh tall has no duplicate presence signal")
	fresh.queue_free()
	await tree.process_frame


func _test_partial_tall_death_is_not_lootable(tree: SceneTree) -> void:
	var controller: WorldMapController = _instantiate_scene(tree)
	await tree.physics_frame
	var tall: NpcRuntimeState = controller.npc_runtimes()[3]
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID,
	))
	_assert_true(controller.select_npc(tall.character_id), "partial Tall fixture selects exact Tall")
	# TEST-ONLY: the partial-death fight is Tall alone (进门一起上 would bring Fat).
	var aside: Array[NpcRuntimeState] = OldPineTestMap.stand_aside(controller, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, [tall.character_id])
	_assert_eq(controller.attack_selected().outcome, CombatSliceInitiationResult.Outcome.COMPLETED, "partial Tall fixture starts lethal combat")
	HistoricalCombat.set_running(controller, false)
	var unknown: ItemInstance = ItemInstance.new(
		&"phase9b1.partial-tall-unknown",
		&"phase9b1.partial-tall-unknown-definition",
	)
	_assert_true(controller.inventory_state().register_item(unknown, 1), "partial Tall fixture registers uncovered direct item")
	_assert_true(InventoryTransferService.new().transfer(
		controller.inventory_state(),
		unknown.item_instance_id,
		InventoryTransferDestination.new(
			ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, tall.character_id),
			true,
			true,
			tall.maximum_encumbrance,
		),
	).succeeded, "partial Tall fixture places uncovered item in Tall inventory")
	controller.player_runtime().busy.start_busy(1)
	tall.character_state.vitality.current = -1
	tall.character_state.vitality.effective = -1
	HistoricalCombat.tick(controller)
	var lifecycles: Array[CombatSliceLifecycleResult] = controller.last_lifecycle_results()
	_assert_eq(lifecycles.size(), 1, "partial Tall death produces one lifecycle result")
	_assert_eq(lifecycles[0].outcome, CombatSliceLifecycleResult.Outcome.DEATH_INVENTORY_BLOCKED, "uncovered Tall item preserves typed partial death")
	_assert_eq(controller.corpse_states().size(), 1, "partial Tall corpse authority is retained")
	var corpse: CorpseState = controller.corpse_states()[0]
	_assert_false(controller.item_instance_index().has_snapshot(corpse.corpse_item_instance_id), "partial Tall corpse is absent from interaction index")
	_assert_true(controller.corpse_view_for(corpse.corpse_item_instance_id) == null, "partial Tall corpse has no loot-range binding")
	_assert_false(controller.select_corpse(corpse.corpse_item_instance_id), "partial Tall corpse cannot become loot target")
	OldPineTestMap.rejoin(aside)
	controller.queue_free()
	await tree.process_frame


func _instantiate_scene(tree: SceneTree) -> WorldMapController:
	var session: WorldSessionController = (
		SceneType.instantiate() as WorldSessionController
	)
	if session == null:
		return null
	session.deterministic_npc_seed = true
	session.npc_seed = 9011
	session.deterministic_combat_seed = true
	session.combat_seed = 9012
	tree.root.add_child(session)
	preload("res://tests/support/historical_world_combat_fixture.gd").install(session)
	return session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)


## Walks like a player would: zone tracking follows the body at most 50 px
## per physics frame, so it sees every neighbouring zone on the way.
## Walks the points in order in straight lines; false at the first collision.
func _walk_route(body: CharacterBody2D, points: Array) -> bool:
	for point: Vector2 in points:
		if not await _walk_without_collision(body, point):
			return false
	return true


## Walkable spans along a horizontal or vertical line, as [first, last] coordinates
## along it (16 px steps), read from the terrain tiles.
func _openings(map: Node2D, from: Vector2, to: Vector2) -> Array:
	var along: Vector2 = (to - from).normalized()
	var result: Array = []
	var open: bool = false
	for step: int in range(int(from.distance_to(to) / 16.0) + 1):
		var point: Vector2 = from + along * step * 16.0
		var coordinate: int = int(point.x if absf(along.x) > 0.5 else point.y)
		var walkable: bool = not TerrainProbe.blocks_at(map, point) and not TerrainProbe.terrain_at(map, point).is_empty()
		if walkable and not open:
			result.append([coordinate, coordinate])
		elif walkable:
			result[-1][1] = coordinate
		open = walkable
	return result


func _walk_without_collision(body: CharacterBody2D, target: Vector2) -> bool:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	for step: int in range(1000):
		var remaining: Vector2 = target - body.global_position
		if remaining.length() <= 0.5:
			return true
		var motion: Vector2 = remaining.limit_length(5.0)
		if body.move_and_collide(motion) != null:
			return false
		if step % 10 == 9:
			await body.get_tree().physics_frame
	return false


func _binding_for(
	participants: Array[CombatSliceCharacterBinding],
	character_id: StringName,
) -> CombatSliceCharacterBinding:
	for participant: CombatSliceCharacterBinding in participants:
		if participant.character_id == character_id:
			return participant
	return null


func _add_player_silver(
	controller: WorldMapController,
	instance_id: StringName,
	amount: int,
) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new(
		instance_id,
		TestContent.SILVER_ITEM_ID,
	)
	if not controller.inventory_state().register_item(item, 0):
		return null
	if not controller.item_instance_index().register_snapshot(item):
		return null
	var registration: CombinedStackAmountResult = CombinedStackService.register_stack(
		controller.stack_collection(),
		controller.inventory_state(),
		item,
		TestContent.loadout(TestContent.SILVER_ITEM_ID).stack_definition(),
		amount,
	)
	if not registration.accepted:
		return null
	var result: InventoryTransferResult = InventoryTransferService.new().transfer(
		controller.inventory_state(),
		item.item_instance_id,
		InventoryTransferDestination.new(
			ContainmentEndpoint.new(
				ContainmentEndpoint.Kind.CHARACTER,
				WorldSessionController.PLAYER_ID,
			),
			true,
			true,
			controller.player_runtime().maximum_encumbrance,
		),
	)
	return item if result.succeeded else null


func _definition_row_count(
	rows: Array[PlayerInventoryRowProjection],
	definition_id: StringName,
) -> int:
	var count: int = 0
	for row: PlayerInventoryRowProjection in rows:
		if row.item_definition_id == definition_id:
			count += 1
	return count


func _item_by_definition(
	items: Array[ItemInstance],
	definition_id: StringName,
) -> ItemInstance:
	for item: ItemInstance in items:
		if item.item_definition_id == definition_id:
			return item
	return null


func _loot_row(
	rows: Array[WorldItemRowProjection],
	item_instance_id: StringName,
) -> WorldItemRowProjection:
	for row: WorldItemRowProjection in rows:
		if row.item_instance_id == item_instance_id:
			return row
	return null


func _skill_pairs(skills: Array[NpcSkillLevelDefinition]) -> Array[Array]:
	var result: Array[Array] = []
	for skill: NpcSkillLevelDefinition in skills:
		result.append([skill.skill_id, skill.raw_level])
	return result


## A zone Area's rectangle in map coordinates.
func _zone_rect(map: Node2D, zone_name: String) -> Rect2:
	var zone: Area2D = map.get_node("Zones/%s" % zone_name) as Area2D
	var shape: RectangleShape2D = (zone.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	return Rect2(zone.position - shape.size / 2.0, shape.size)


## [colliding samples, all samples] over a grid of points inside `rect`, finer than one 16 px tile.
func _blocking_coverage(map: Node2D, rect: Rect2) -> Vector2i:
	var columns: int = maxi(1, ceili(rect.size.x / 8.0))
	var rows: int = maxi(1, ceili(rect.size.y / 8.0))
	var blocking: int = 0
	var total: int = 0
	for column: int in range(columns + 1):
		for row: int in range(rows + 1):
			var point: Vector2 = Vector2(
				lerpf(rect.position.x + 0.5, rect.end.x - 0.5, float(column) / float(columns)),
				lerpf(rect.position.y + 0.5, rect.end.y - 0.5, float(row) / float(rows)),
			)
			total += 1
			if TerrainProbe.blocks_at(map, point):
				blocking += 1
	return Vector2i(blocking, total)


func _all_blocking(map: Node2D, rect: Rect2) -> bool:
	var coverage: Vector2i = _blocking_coverage(map, rect)
	return coverage.x == coverage.y


func _none_blocking(map: Node2D, rect: Rect2) -> bool:
	return _blocking_coverage(map, rect).x == 0


func _count_tree_nodes(root: Node) -> int:
	var count: int = 1
	for child: Node in root.get_children():
		count += _count_tree_nodes(child)
	return count


func _assert_true(value: bool, label: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append("Expected true: %s" % label)


func _assert_false(value: bool, label: String) -> void:
	_assert_true(not value, label)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _assert_ne(actual: Variant, unexpected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual == unexpected:
		_failures.append("%s: values unexpectedly equal: %s" % [label, actual])
