extends SceneTree

const RouteTest := preload("res://tests/runtime/oldpine_river_cliff_route_test.gd")
const VinePolicyTest := preload("res://tests/core/vine_traversal_policy_test.gd")
const VineRuntimeTest := preload("res://tests/runtime/oldpine_vine_cross_map_traversal_test.gd")
const SessionTest := preload("res://tests/runtime/oldpine_world_session_test.gd")
const WorldDefinitionTest := preload("res://tests/core/world_definition_test.gd")
const NpcArmorLoadoutTest := preload("res://tests/core/npc_armor_loadout_test.gd")
const PlayerArmorInteractionTest := preload("res://tests/runtime/player_armor_interaction_test.gd")
const FatArmorLoopTest := preload("res://tests/runtime/oldpine_fat_bandit_armor_loop_test.gd")
const Phase9B1Test := preload("res://tests/runtime/oldpine_pine_maze_tall_bandit_test.gd")
const Phase8B2UnitTest := preload("res://tests/runtime/player_inventory_equipment_test.gd")
const Phase8B2LoopTest := preload("res://tests/runtime/oldpine_full_loot_loop_test.gd")
const Phase8B1Test := preload("res://tests/runtime/oldpine_corpse_loot_interaction_test.gd")
const Phase7B3Test := preload("res://tests/runtime/oldpine_portal_aggression_test.gd")
const RelationshipTest := preload("res://tests/core/combat_relationship_opponent_friendly_stop_test.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var results: Array[Dictionary] = []
	print("RUN Phase 9B3B3 River / Cliff / Pine route")
	results.append(WorldDefinitionTest.new().run_all())
	results.append(await RouteTest.new().run_all(self))
	print("RUN focused Phase 9B3B2/B1, 9B2/B1, 8B2/B1, 7B3 regressions")
	results.append(VinePolicyTest.new().run_all())
	results.append(await VineRuntimeTest.new().run_all(self))
	results.append(await SessionTest.new().run_all(self))
	results.append(NpcArmorLoadoutTest.new().run_all())
	results.append(PlayerArmorInteractionTest.new().run_all())
	results.append(await FatArmorLoopTest.new().run_all(self))
	results.append(await Phase9B1Test.new().run_all(self))
	results.append(Phase8B2UnitTest.new().run_all())
	results.append(await Phase8B2LoopTest.new().run_all(self))
	results.append(await Phase8B1Test.new().run_all(self))
	results.append(await Phase7B3Test.new().run_all(self))
	results.append(RelationshipTest.new().run_all())
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	if failures.is_empty():
		print("PASS Phase 9B3B3 targeted regressions: %d assertions" % assertions)
		quit(0)
		return
	for failure: String in failures:
		printerr(failure)
	printerr("FAIL Phase 9B3B3: %d failure(s), %d assertions" % [failures.size(), assertions])
	quit(1)
