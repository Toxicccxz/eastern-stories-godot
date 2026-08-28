extends SceneTree

const Phase7B3Test := preload(
	"res://tests/runtime/oldpine_portal_aggression_test.gd"
)
const Phase7B2Test := preload(
	"res://tests/runtime/oldpine_outdoor_smoke_test.gd"
)
const WorldDefinitionTest := preload("res://tests/core/world_definition_test.gd")
const NpcSpawnTest := preload("res://tests/core/npc_spawn_foundation_test.gd")
const CombatSliceOpportunityTest := preload(
	"res://tests/runtime/combat_slice_opportunity_integration_test.gd"
)
const CombatVerticalSliceTest := preload(
	"res://tests/runtime/combat_vertical_slice_smoke_test.gd"
)
const CombatLifecycleTest := preload(
	"res://tests/runtime/combat_slice_lifecycle_corpse_test.gd"
)
const CombatRelationshipTest := preload(
	"res://tests/core/combat_relationship_opponent_friendly_stop_test.gd"
)
const CombatFightTest := preload(
	"res://tests/core/combat_fight_decision_guard_test.gd"
)
const CombatExecutionTest := preload(
	"res://tests/core/combat_single_attack_post_action_riposte_decision_test.gd"
)
const CombatReverseTest := preload(
	"res://tests/core/combat_synchronous_reverse_attack_execution_test.gd"
)


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var results: Array[Dictionary] = []
	print("RUN Phase 7B3 portal traversal and authored aggression")
	results.append(await Phase7B3Test.new().run_all(self))
	print("RUN focused closed regressions")
	results.append(await Phase7B2Test.new().run_all(self))
	results.append(WorldDefinitionTest.new().run_all())
	results.append(NpcSpawnTest.new().run_all())
	results.append(CombatSliceOpportunityTest.new().run_all())
	results.append(await CombatVerticalSliceTest.new().run_all(self))
	results.append(await CombatLifecycleTest.new().run_all(self))
	results.append(CombatRelationshipTest.new().run_all())
	results.append(CombatFightTest.new().run_all())
	results.append(CombatExecutionTest.new().run_all())
	results.append(CombatReverseTest.new().run_all())
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	if failures.is_empty():
		print("PASS Phase 7B3 targeted regressions: %d assertions" % assertions)
		quit(0)
		return
	for failure: String in failures:
		printerr(failure)
	printerr("FAIL Phase 7B3: %d failure(s), %d assertions" % [failures.size(), assertions])
	quit(1)
