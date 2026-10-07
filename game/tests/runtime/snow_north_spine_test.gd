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
	check(await MapPlaces.take_passage(tree, session.active_map() as WorldMapController, SnowWorldDefinitions.INN_EXIT_PORTAL_ID), "out through the Inn's door")
	check(session.active_map_id() == &"snow.outdoor", "physical Inn doorway")
	geometry_tests(snow)
	check(await MapPlaces.drive_through(tree, snow, [&"snow.square", &"snow.mstreet1"]), "north into the street")
	await solid(tree, session, snow, &"snow.school1", MapPlaces.door_spot(snow, &"snow.school.gate", &"snow.school1"), "move_right", "School closed gate")
	var mstreet2: Rect2 = MapPlaces.zone_rect(snow, &"snow.mstreet2")
	await solid(tree, session, snow, &"snow.mstreet2", MapPlaces.spot(snow, &"snow.mstreet2", Vector2(mstreet2.position.x, mstreet2.position.y + 48)), "move_left", "mstreet2 west beside the smithy doorway")
	for zone: StringName in [&"snow.mstreet3", &"snow.mstreet4", &"snow.crossroad"]:
		check(await MapPlaces.drive_to_zone(tree, snow, zone), "walk on north to " + String(zone))
		check(session.player_runtime().world_location().zone_id == zone and session.active_map() == snow, "real forward Area entry " + String(zone))
		check(not session.fill_water_available(), "no Fill outside waterfall")
		check(session.player_recovery_cadence() == ids[6] and session.player_recovery_cadence().source_tick == 4 and session.player_recovery_cadence().accumulated_seconds == 1.0 and random.calls == 1, "zone entry does not reset cadence or draw")
		await walk.round_trip(tree, session, Work.capture(session), String(zone))
		if zone != &"snow.crossroad":
			var street: Rect2 = MapPlaces.zone_rect(snow, zone)
			await solid(tree, session, snow, zone, MapPlaces.spot(snow, zone, Vector2(street.end.x, street.get_center().y)), "move_right", "Hockshop's shut door or mst4's houses east")
			# 4B: the west fronts are doorways (herbshop.c, postoffice.c).
			var shop: StringName = &"snow.herbshop" if zone == &"snow.mstreet3" else &"snow.postoffice"
			check(await MapPlaces.drive_to_zone(tree, snow, shop), "into the shop west of " + String(zone))
			check(session.player_runtime().world_location().zone_id == shop, "west doorway enters the shop from " + String(zone))
			check(await MapPlaces.drive_to_zone(tree, snow, zone), "back out of " + String(shop))
			check(session.player_runtime().world_location().zone_id == zone, "back out to " + String(zone))
	# 野羊山: the crossroad's north is a passage, there and back.
	check(await MapPlaces.take_passage(tree, snow, &"snow.crossroad.north"), "north off the col")
	check(session.active_map_id() == &"goathill.mountain" and session.player_runtime().world_location().zone_id == &"goathill.mroad1", "north out of the crossroad: 野羊山's mroad1")
	await _walk_until_map(tree, session, &"snow.outdoor", "move_down")
	check(session.player_runtime().world_location().zone_id == &"snow.crossroad" and session.active_map() == snow, "and back south to the crossroad")
	var col: Rect2 = MapPlaces.zone_rect(snow, &"snow.crossroad")
	await solid(tree, session, snow, &"snow.crossroad", MapPlaces.spot(snow, &"snow.crossroad", Vector2(col.end.x, col.get_center().y)), "move_right", "Green east")
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
	for zone: StringName in [&"snow.mstreet4", &"snow.mstreet3", &"snow.mstreet2", &"snow.mstreet1", &"snow.square"]:
		check(await MapPlaces.drive_to_zone(tree, snow, zone), "walk back south to " + String(zone))
		check(session.player_runtime().world_location().zone_id == zone and session.active_map() == snow, "physical reverse " + String(zone))
		if zone == &"snow.mstreet3":
			session.player_runtime().state.recovery.food = 399
			session.player_runtime().state.recovery.water = 399
			check(Food.eat(session, dumpling.item_id).outcome == FoodUseResult.Outcome.ATE and session.player_runtime().state.recovery.food == 459, "held food unchanged in new zone")
			check(Water.drink(session, wineskin.item_id).succeeded() and session.player_runtime().state.recovery.water == 429, "held water unchanged in new zone")
			check(not Water.fill(session, wineskin.item_id, session.fill_water_available()).succeeded(), "cannot fill in new zone")
	var square: Rect2 = MapPlaces.zone_rect(snow, &"snow.square")
	await solid(tree, session, snow, &"snow.square", MapPlaces.spot(snow, &"snow.square", Vector2(square.end.x, square.get_center().y)), "move_right", "Temple wall east, beside its door")
	var sroad1: Rect2 = MapPlaces.zone_rect(snow, &"snow.sroad1")
	var sroad2: Rect2 = MapPlaces.zone_rect(snow, &"snow.sroad2")
	await solid(tree, session, snow, &"snow.sroad1", MapPlaces.spot(snow, &"snow.sroad1", Vector2(sroad1.position.x, sroad2.position.y - 32)), "move_left", "sroad1 west above the sroad2 road")
	# 卧龙岗 (绮云镇 3A): sroad1's south is a passage, there and back.
	check(await MapPlaces.take_passage(tree, snow, &"snow.sroad1.south"), "south down the street")
	check(session.active_map_id() == &"cloud.outdoor" and session.player_runtime().world_location().zone_id == &"cloud.dragonhill.nroad", "south out of sroad1: 卧龙岗's 黄土路")
	await _walk_until_map(tree, session, &"snow.outdoor", "move_up")
	check(session.player_runtime().world_location().zone_id == &"snow.sroad1" and session.active_map() == snow, "and back north to sroad1")
	check(await MapPlaces.drive_to_zone(tree, snow, &"snow.square"), "up the street to the square")
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


## Walks to `from` in `zone` and pushes on with `action`: a wall or a shut door holds the player
## there, in the zone and on the map.
func solid(tree: SceneTree, session: OldPineWorldSessionController, snow: WorldMapController, zone: StringName, from: Vector2, action: StringName, label: String) -> void:
	check(await MapPlaces.drive(tree, snow, from), "walk up to " + label)
	var before: Vector2 = snow.runtime_player_body().global_position
	await MapPlaces.push(tree, action, 60)
	check(snow.runtime_player_body().global_position.distance_to(before) < 48.0, "physical solid " + label)
	check(session.player_runtime().world_location().zone_id == zone and session.active_map_id() == &"snow.outdoor", "no hidden transition " + label)


func geometry_tests(snow: WorldMapController) -> void:
	for zone: StringName in [&"snow.mstreet3", &"snow.mstreet4", &"snow.crossroad"]:
		check(MapPlacementValidator.is_valid_character_position(snow, zone, MapPlaces.zone_centre(snow, zone)), "valid position " + String(zone))
	# Where two stretches of the street meet, each side of the line belongs to its own stretch.
	for row: Array in [[&"snow.mstreet2", &"snow.mstreet3"], [&"snow.mstreet3", &"snow.mstreet4"]]:
		var seam: Vector2 = MapPlaces.doorway(snow, row[0], row[1])
		check(seam.is_finite(), "the street runs on " + str(row))
		check(MapPlacementValidator.is_valid_character_position(snow, row[0], seam + Vector2(0, 24)) and MapPlacementValidator.is_valid_character_position(snow, row[1], seam - Vector2(0, 24)), "valid position/half-open join " + str(row))
		check(not MapPlacementValidator.is_valid_character_position(snow, row[1], seam + Vector2(0, 24)), "the join's south side is not the north stretch " + str(row))
		var owner: StringName = MapPlaces.seam_owner(snow, row[0], row[1])
		var other: StringName = row[1] if owner == row[0] else row[0]
		check(MapPlacementValidator.is_valid_character_position(snow, owner, seam) and not MapPlacementValidator.is_valid_character_position(snow, other, seam), "half-open join: the line itself is %s's" % owner)
	var mstreet3: Rect2 = MapPlaces.zone_rect(snow, &"snow.mstreet3")
	var mstreet4: Rect2 = MapPlaces.zone_rect(snow, &"snow.mstreet4")
	var col: Rect2 = MapPlaces.zone_rect(snow, &"snow.crossroad")
	for row: Array in [[&"snow.mstreet3", Vector2(mstreet3.end.x - 10, mstreet3.position.y + 40)], [&"snow.mstreet3", Vector2(mstreet3.position.x + 10, mstreet3.position.y + 40)], [&"snow.mstreet4", Vector2(mstreet4.end.x - 10, mstreet4.get_center().y)], [&"snow.crossroad", col.position + Vector2(40, 40)], [&"snow.crossroad", Vector2(col.get_center().x, col.position.y - 20)], [&"snow.mstreet3", mstreet4.get_center()], [&"green.path6", col.get_center() + Vector2(col.size.x, 0)], [&"snow.mstreet3", Vector2(INF,0)]]:
		check(not MapPlacementValidator.is_valid_character_position(snow, row[0], row[1]), "reject collision/void/wrong zone " + str(row))
	# Fault injection tests actual overlap rejection; restore fixture before physical path.
	var mst4: Area2D = snow.physical_zone(&"snow.mstreet4")
	var original: Vector2 = mst4.position
	mst4.position = snow.physical_zone(&"snow.mstreet3").position
	check(not MapPlacementValidator.is_valid_character_position(snow, &"snow.mstreet3", MapPlaces.zone_spot(snow, &"snow.mstreet3")), "ambiguous overlapping zones fail closed")
	mst4.position = original
	check(TerrainProbe.terrain_at(snow, MapPlaces.zone_centre(snow, &"snow.hockshop")) == "floor_shop" and MapPlaces.door_wall(snow, &"snow.hockshop.door") != null and MapPlaces.doorway(snow, &"snow.mstreet3", &"snow.hockshop").is_finite() and snow.get_node("Terrain/HockshopLabel") is Label, "the Hockshop's front: its door on the street and its name")
	for row: Array in [[&"snow.mstreet3", &"snow.herbshop", "floor_shop", "HerbshopLabel"], [&"snow.mstreet4", &"snow.postoffice", "floor_wood", "PostofficeLabel"]]:
		var way: Vector2 = MapPlaces.doorway(snow, row[0], row[1])
		check(way.is_finite() and TerrainProbe.terrain_at(snow, way - Vector2(16, 0)) == row[2] and snow.get_node("Terrain/" + row[3]) is Label, "open doorway and name " + String(row[1]))


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append("S7B: " + label)
