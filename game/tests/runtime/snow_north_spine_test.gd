extends RefCounted

const WorldCounts := preload("res://tests/support/world_counts.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Recovery := preload("res://tests/runtime/player_recovery_cadence_test.gd")
const Food := preload("res://tests/runtime/snow_dumpling_test.gd")
const Water := preload("res://tests/runtime/snow_water_test.gd")
var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	definition_tests()
	await physical_tests(tree)
	for zone: String in ["mstreet3", "crossroad"]:
		var profile: String = "s7b-%s-%d-%d" % [zone, OS.get_process_id(), Time.get_ticks_usec()]
		for mode: String in ["write", "read"]:
			var output: Array = []
			var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/run_snow_spine_cold_process.gd", "--", mode, zone, profile], output, true)
			check(code == 0 and str(output).contains("S7B cold PASS") and not str(output).contains("SCRIPT ERROR"), "cold " + zone + "/" + mode + ": " + str(output))
	return {"assertions": assertions, "failures": failures}


func definition_tests() -> void:
	check(GameContent.catalog().zones_for_map(&"snow.outdoor").size() == 31, "S7B twelve outdoor zones plus H3 Hockshop, P2 three school zones, the revival temple, 4B's nine rooms and 4C's five")
	var spine: Array[StringName] = [&"snow.mstreet2", &"snow.mstreet3", &"snow.mstreet4", &"snow.crossroad"]
	for id: StringName in spine.slice(1):
		var zone: ZoneDefinition = GameContent.catalog().zone(id)
		check(zone != null and zone.is_valid() and zone.map_id == &"snow.outdoor" and zone.combat_location_id == id, "separate typed identity " + String(id))
		check(zone.room_ids() == [StringName("es2:d/snow/" + String(id).get_slice(".", 1))], "exact LPC path " + String(id))
	for i: int in range(spine.size()):
		for j: int in range(spine.size()):
			check(GameContent.catalog().zones_adjacent(spine[i], spine[j]) == (absi(i-j) == 1), "ordered bidirectional adjacency without shortcut " + str([i,j]))
	for row: Array in [["mstreet3", "east", &"es2:d/snow/hockshop"], ["mstreet3", "west", &"es2:d/snow/herbshop"], ["mstreet4", "west", &"es2:d/snow/postoffice"], ["crossroad", "north", &"es2:d/goathill/mroad1"], ["crossroad", "east", &"es2:d/green/path6"]]:
		check(GameContent.catalog().room(StringName("es2:d/snow/" + row[0])).exits().get(row[1]) == row[2], "source exit metadata %s:%s" % [row[0], row[1]])
	check(not GameContent.catalog().room(&"es2:d/snow/mstreet4").exits().has("east"), "mstreet4.c exits mapping overrides contradictory east prose")
	# 4B opened the herbshop, post office and smithy (west) and the Hockshop storage room.
	for row: Array in [[&"snow.mstreet2", &"snow.smithy"], [&"snow.mstreet3", &"snow.herbshop"], [&"snow.mstreet4", &"snow.postoffice"], [&"snow.hockshop", &"snow.hockshop2"]]:
		check(GameContent.catalog().zones_adjacent(row[0], row[1]), "4B shop neighbour " + str(row))
	for deferred: StringName in [&"snow.alley", &"green.path6"]:
		check(GameContent.catalog().zone(deferred) == null and GameContent.catalog().portal(deferred) == null, "no executable deferred identity " + String(deferred))
		for id: StringName in spine:
			check(not GameContent.catalog().zones_adjacent(id, deferred), "no deferred neighbor")
	check(_portal_ids(&"snow.outdoor") == WorldCounts.ids("snow_outdoor_portals"), "external portals: Old Pine, 野羊山 (crossroad north), 卧龙岗 (sroad1 south), 水烟阁 (sroad5 west) and the weapon storage's way down (world_counts.json)")


func _portal_ids(map_id: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for portal: PortalDefinition in GameContent.catalog().portals_for_map(map_id):
		ids.append(portal.portal_id)
	return ids


func physical_tests(tree: SceneTree) -> void:
	var random: Recovery.RandomSequence = Recovery.RandomSequence.new([5])
	var session: OldPineWorldSessionController = Recovery.create_session(tree, random)
	var walk: Work = Work.new()
	var snow: WorldMapController = session.resident_map(&"snow.outdoor") as WorldMapController
	var ids: Array[Object] = [session.player_runtime(), session.inventory_state(), session.stack_collection(), session.item_instance_index(), session.item_id_allocator(), session.world_simulation_gate(), session.player_recovery_cadence(), snow]
	var rng: Array[int] = Work.rng_state(session)
	var sequence: int = session.item_id_allocator().next_dynamic_sequence
	var residents: int = session.resident_map_count()
	# Exact-delta fixture: automatic Session process is disabled, physics/input remains real.
	session.advance_player_recovery(3.0)
	await tree.physics_frame
	await walk.walk(tree, session, "move_right", 125)
	check(session.active_map_id() == &"snow.outdoor", "physical Inn doorway")
	geometry_tests(snow)
	await walk.walk_to(tree, session, "move_right", 0, 0)
	await walk.walk_to(tree, session, "move_up", -400, 1)
	await wall_test(tree, session, walk, "move_right", 0, 400, "School closed gate", &"snow.school1")
	await walk.walk_to(tree, session, "move_left", 0, 0)
	await walk.walk_to(tree, session, "move_up", -700, 1)
	await wall_test(tree, session, walk, "move_left", 0, -100, "mstreet2 west beside the smithy doorway", &"snow.mstreet2")
	await walk.walk_to(tree, session, "move_right", 0, 0)
	for row: Array in [[&"snow.mstreet3", -1000.0], [&"snow.mstreet4", -1300.0], [&"snow.crossroad", -1650.0]]:
		await walk.walk_to(tree, session, "move_up", row[1], 1)
		check(session.player_runtime().world_location().zone_id == row[0] and session.active_map() == snow, "real forward Area entry " + String(row[0]))
		check(not session.fill_water_available(), "no Fill outside waterfall")
		check(session.player_recovery_cadence() == ids[6] and session.player_recovery_cadence().source_tick == 4 and session.player_recovery_cadence().accumulated_seconds == 1.0 and random.calls == 1, "zone entry does not reset cadence or draw")
		await walk.round_trip(tree, session, Work.capture(session), String(row[0]))
		if row[0] != &"snow.crossroad":
			await wall_test(tree, session, walk, "move_right", 0, 100, "Hockshop or absent mst4 east", row[0])
			# 4B: the west fronts are doorways now (herbshop.c, postoffice.c).
			await walk.walk_to(tree, session, "move_left", -200, 0)
			check(session.player_runtime().world_location().zone_id == (&"snow.herbshop" if row[0] == &"snow.mstreet3" else &"snow.postoffice"), "west doorway enters the shop from " + String(row[0]))
			await walk.walk_to(tree, session, "move_right", 0, 0)
			check(session.player_runtime().world_location().zone_id == row[0], "back out to " + String(row[0]))
	# 野羊山: the crossroad's north is a passage now, there and back.
	await _walk_until_map(tree, session, &"goathill.mountain", "move_up")
	check(session.player_runtime().world_location().zone_id == &"goathill.mroad1", "north out of the crossroad: 野羊山's mroad1")
	await _walk_until_map(tree, session, &"snow.outdoor", "move_down")
	check(session.player_runtime().world_location().zone_id == &"snow.crossroad" and session.active_map() == snow, "and back south to the crossroad")
	await walk.walk_to(tree, session, "move_down", -1650, 1)
	await wall_test(tree, session, walk, "move_right", 0, 300, "Green east", &"snow.crossroad")
	await walk.walk_to(tree, session, "move_left", 0, 0)
	check(session.player_runtime() == ids[0] and session.inventory_state() == ids[1] and session.stack_collection() == ids[2] and session.item_instance_index() == ids[3] and session.item_id_allocator() == ids[4] and session.world_simulation_gate() == ids[5], "all authority identities unchanged")
	check(Work.rng_state(session) == rng and session.item_id_allocator().next_dynamic_sequence == sequence, "entire route zero gameplay RNG/allocation")
	check(session.resident_map_count() == residents and residents == GameContent.catalog().maps().size() and session.active_map_child_count() == 1 and snow.resident_npcs().size() == GameContent.catalog().spawns_for_map(snow.map_id()).reduce(func(total: int, spawn: NpcSpawnDefinition) -> int: return total + spawn.quantity, 0), "same residents (every authored map), one active, only the authored Snow NPCs")
	check(session.advance_player_recovery(1.0).pulses == 1 and session.player_recovery_cadence().source_tick == 3 and random.calls == 1, "next exact pulse continues old phase")
	# Independent typed consumable setup, not a claim of player-visible purchasing.
	check(Food.earn_and_exchange(session), "existing Work/Bank setup")
	var dumpling: VendorPurchaseResult = Food.purchase(session)
	var wineskin: VendorPurchaseResult = Water.purchase(session)
	check(dumpling.delivered and wineskin.delivered, "existing paid held consumables")
	check(Water.fill(session, wineskin.item_id).succeeded(), "typed test setup clear water before use")
	for row: Array in [[&"snow.mstreet4", -1300.0], [&"snow.mstreet3", -1000.0], [&"snow.mstreet2", -700.0], [&"snow.mstreet1", -400.0], [&"snow.square", 0.0]]:
		await walk.walk_to(tree, session, "move_down", row[1], 1)
		check(session.player_runtime().world_location().zone_id == row[0] and session.active_map() == snow, "physical reverse " + String(row[0]))
		if row[0] == &"snow.mstreet3":
			session.player_runtime().state.recovery.food = 399
			session.player_runtime().state.recovery.water = 399
			check(Food.eat(session, dumpling.item_id).outcome == FoodUseResult.Outcome.ATE and session.player_runtime().state.recovery.food == 459, "held food unchanged in new zone")
			check(Water.drink(session, wineskin.item_id).succeeded() and session.player_runtime().state.recovery.water == 429, "held water unchanged in new zone")
			check(not Water.fill(session, wineskin.item_id, session.fill_water_available()).succeeded(), "cannot fill in new zone")
	await wall_test(tree, session, walk, "move_right", 0, 300, "Temple east", &"snow.square")
	await walk.walk_to(tree, session, "move_left", 0, 0)
	await walk.walk_to(tree, session, "move_down", 450, 1)
	await wall_test(tree, session, walk, "move_left", 0, -100, "sroad1 west above the sroad2 road", &"snow.sroad1")
	await walk.walk_to(tree, session, "move_right", 0, 0)
	# 卧龙岗 (绮云镇 3A): sroad1's south is a passage now, there and back.
	await _walk_until_map(tree, session, &"cloud.outdoor", "move_down")
	check(session.player_runtime().world_location().zone_id == &"cloud.dragonhill.nroad", "south out of sroad1: 卧龙岗's 黄土路")
	await _walk_until_map(tree, session, &"snow.outdoor", "move_up")
	check(session.player_runtime().world_location().zone_id == &"snow.sroad1" and session.active_map() == snow, "and back north to sroad1")
	await walk.walk_to(tree, session, "move_up", 0, 1)
	check(session.player_runtime().world_location().zone_id == &"snow.square", "physical final Square return")
	assertions += walk._count
	failures.append_array(walk._failures)
	session.free()
	await tree.process_frame


func _walk_until_map(tree: SceneTree, session: OldPineWorldSessionController, target: StringName, action: String) -> void:
	Input.action_press(action)
	for _step: int in range(400):
		await tree.physics_frame
		if session.active_map_id() == target:
			break
	Input.action_release(action)
	for _step: int in range(3):
		await tree.physics_frame


func wall_test(tree: SceneTree, session: OldPineWorldSessionController, walk: Work, action: String, axis: int, boundary: float, label: String, zone: StringName) -> void:
	await walk.walk(tree, session, action, 140)
	var coordinate: float = session.active_map().runtime_player_body().position[axis]
	check(coordinate > boundary if action in ["move_left", "move_up"] else coordinate < boundary, "physical solid " + label)
	check(session.player_runtime().world_location().zone_id == zone and session.active_map_id() == &"snow.outdoor", "no hidden transition " + label)


func geometry_tests(snow: WorldMapController) -> void:
	for row: Array in [[&"snow.mstreet3", Vector2(0,-1000)], [&"snow.mstreet4", Vector2(0,-1300)], [&"snow.crossroad", Vector2(100,-1650)], [&"snow.mstreet2", Vector2(0,-840)], [&"snow.mstreet2", Vector2(0,-850)], [&"snow.mstreet3", Vector2(0,-1150)], [&"snow.mstreet4", Vector2(0,-1450)]]:
		check(MapPlacementValidator.is_valid_character_position(snow, row[0], row[1]), "valid position/half-open join " + str(row))
	for row: Array in [[&"snow.mstreet3", Vector2(90,-1000)], [&"snow.mstreet3", Vector2(-90,-900)], [&"snow.mstreet4", Vector2(90,-1300)], [&"snow.crossroad", Vector2(290,-1650)], [&"snow.crossroad", Vector2(100,-1840)], [&"snow.crossroad", Vector2(200,-1460)], [&"snow.mstreet3", Vector2(0,-1300)], [&"snow.mstreet4", Vector2(200,-1300)], [&"green.path6", Vector2(400,-1650)], [&"snow.mstreet3", Vector2(INF,0)]]:
		check(not MapPlacementValidator.is_valid_character_position(snow, row[0], row[1]), "reject collision/void/wrong zone " + str(row))
	# Fault injection tests actual overlap rejection; restore fixture before physical path.
	var mst4: Area2D = snow.get_node("Zones/MainStreet4") as Area2D
	var original: Vector2 = mst4.position
	mst4.position = Vector2(0,-1000)
	check(not MapPlacementValidator.is_valid_character_position(snow, &"snow.mstreet3", Vector2(0,-1000)), "ambiguous overlapping zones fail closed")
	mst4.position = original
	check(TerrainProbe.terrain_at(snow, Vector2(320,-1000)) == "floor_shop" and snow.get_node("Ground/HockshopShutter") is Polygon2D and snow.get_node("Ground/HockshopSign") is Label, "visible shuttered frontage Hockshop")
	for row: Array in [["Herbshop", -1008.0, "floor_shop"], ["Postoffice", -1296.0, "floor_wood"]]:
		check(TerrainProbe.terrain_at(snow, Vector2(-96,row[1])) == row[2] and snow.get_node("Ground/" + row[0] + "Sign") is Label, "open doorway and sign " + row[0])


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append("S7B: " + label)
