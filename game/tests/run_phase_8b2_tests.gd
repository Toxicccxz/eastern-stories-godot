extends SceneTree

const PlayerInventoryEquipmentTest := preload(
	"res://tests/runtime/player_inventory_equipment_test.gd"
)
const OldPineFullLootLoopTest := preload(
	"res://tests/runtime/oldpine_full_loot_loop_test.gd"
)
const Phase8B1Test := preload(
	"res://tests/runtime/oldpine_corpse_loot_interaction_test.gd"
)
const Phase7B3Test := preload(
	"res://tests/runtime/oldpine_portal_aggression_test.gd"
)
const Phase7B2Test := preload(
	"res://tests/runtime/oldpine_outdoor_smoke_test.gd"
)
const Phase7B1WorldTest := preload("res://tests/core/world_definition_test.gd")
const Phase7B1NpcTest := preload("res://tests/core/npc_spawn_foundation_test.gd")
const Phase6B1Test := preload(
	"res://tests/runtime/combat_slice_opportunity_integration_test.gd"
)
const Phase6B2Test := preload(
	"res://tests/runtime/combat_vertical_slice_smoke_test.gd"
)
const Phase6B3Test := preload(
	"res://tests/runtime/combat_slice_lifecycle_corpse_test.gd"
)
const Phase5B2ATest := preload(
	"res://tests/core/combat_ordinary_attack_core_resolution_test.gd"
)
const Phase5B2B1Test := preload(
	"res://tests/core/standard_force_hit_policy_test.gd"
)
const Phase5B2B2Test := preload(
	"res://tests/core/combat_progression_busy_completion_test.gd"
)
const Phase5B3ATest := preload(
	"res://tests/core/combat_relationship_opponent_friendly_stop_test.gd"
)
const Phase5B3B1Test := preload(
	"res://tests/core/combat_fight_decision_guard_test.gd"
)
const Phase5B3B2ATest := preload(
	"res://tests/core/combat_single_attack_post_action_riposte_decision_test.gd"
)
const Phase5B3B2BTest := preload(
	"res://tests/core/combat_synchronous_reverse_attack_execution_test.gd"
)
const Phase4A1Test := preload("res://tests/core/equipment_state_test.gd")
const Phase4B2Test := preload(
	"res://tests/core/inventory_containment_transfer_test.gd"
)
const Phase4B3Test := preload("res://tests/core/combined_stack_currency_test.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var results: Array[Dictionary] = []
	print("RUN Phase 8B2 player inventory/equipment/content")
	results.append(PlayerInventoryEquipmentTest.new().run_all())
	results.append(await OldPineFullLootLoopTest.new().run_all(self))
	print("RUN focused closed regressions")
	results.append(await Phase8B1Test.new().run_all(self))
	results.append(await Phase7B3Test.new().run_all(self))
	results.append(await Phase7B2Test.new().run_all(self))
	results.append(Phase7B1WorldTest.new().run_all())
	results.append(Phase7B1NpcTest.new().run_all())
	results.append(Phase6B1Test.new().run_all())
	results.append(await Phase6B2Test.new().run_all(self))
	results.append(await Phase6B3Test.new().run_all(self))
	results.append(Phase5B2ATest.new().run_all())
	results.append(Phase5B2B1Test.new().run_all())
	results.append(Phase5B2B2Test.new().run_all())
	results.append(Phase5B3ATest.new().run_all())
	results.append(Phase5B3B1Test.new().run_all())
	results.append(Phase5B3B2ATest.new().run_all())
	results.append(Phase5B3B2BTest.new().run_all())
	results.append(Phase4A1Test.new().run_all())
	results.append(Phase4B2Test.new().run_all())
	results.append(Phase4B3Test.new().run_all())
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	if failures.is_empty():
		print("PASS Phase 8B2 targeted regressions: %d assertions" % assertions)
		quit(0)
		return
	for failure: String in failures:
		printerr(failure)
	printerr("FAIL Phase 8B2: %d failure(s), %d assertions" % [failures.size(), assertions])
	quit(1)
