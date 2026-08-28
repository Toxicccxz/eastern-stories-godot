extends SceneTree

const Phase8B1Test := preload(
	"res://tests/runtime/oldpine_corpse_loot_interaction_test.gd"
)
const Phase7B3Test := preload(
	"res://tests/runtime/oldpine_portal_aggression_test.gd"
)
const Phase7B2Test := preload(
	"res://tests/runtime/oldpine_outdoor_smoke_test.gd"
)
const WorldDefinitionTest := preload("res://tests/core/world_definition_test.gd")
const NpcSpawnTest := preload("res://tests/core/npc_spawn_foundation_test.gd")
const Phase6B3Test := preload(
	"res://tests/runtime/combat_slice_lifecycle_corpse_test.gd"
)
const Phase4B5CTest := preload("res://tests/core/death_inventory_corpse_test.gd")
const Phase4B3Test := preload("res://tests/core/combined_stack_currency_test.gd")
const Phase4B2Test := preload(
	"res://tests/core/inventory_containment_transfer_test.gd"
)


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var results: Array[Dictionary] = []
	print("RUN Phase 8B1 world corpse loot and single Take")
	results.append(await Phase8B1Test.new().run_all(self))
	print("RUN focused closed regressions")
	results.append(await Phase7B3Test.new().run_all(self))
	results.append(await Phase7B2Test.new().run_all(self))
	results.append(WorldDefinitionTest.new().run_all())
	results.append(NpcSpawnTest.new().run_all())
	results.append(await Phase6B3Test.new().run_all(self))
	results.append(Phase4B5CTest.new().run_all())
	results.append(Phase4B3Test.new().run_all())
	results.append(Phase4B2Test.new().run_all())
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	if failures.is_empty():
		print("PASS Phase 8B1 targeted regressions: %d assertions" % assertions)
		quit(0)
		return
	for failure: String in failures:
		printerr(failure)
	printerr("FAIL Phase 8B1: %d failure(s), %d assertions" % [failures.size(), assertions])
	quit(1)
