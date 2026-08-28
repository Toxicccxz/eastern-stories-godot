extends SceneTree

const WorldDefinitionTest := preload("res://tests/core/world_definition_test.gd")
const NpcSpawnTest := preload("res://tests/core/npc_spawn_foundation_test.gd")
const CharacterStateTest := preload("res://tests/core/character_state_test.gd")
const SkillCoreTest := preload("res://tests/core/skill_core_test.gd")
const InventoryTest := preload(
	"res://tests/core/inventory_containment_transfer_test.gd"
)
const EquipmentTest := preload("res://tests/core/equipment_state_test.gd")
const CombinedStackTest := preload("res://tests/core/combined_stack_currency_test.gd")
const RelationshipTest := preload(
	"res://tests/core/combat_relationship_opponent_friendly_stop_test.gd"
)
const CombatSliceOpportunityTest := preload(
	"res://tests/runtime/combat_slice_opportunity_integration_test.gd"
)


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var results: Array[Dictionary] = []
	print("RUN Phase 7B1 world/NPC/spawn foundation")
	results.append(WorldDefinitionTest.new().run_all())
	results.append(NpcSpawnTest.new().run_all())
	print("RUN focused closed-domain regressions")
	results.append(CharacterStateTest.new().run_all())
	results.append(SkillCoreTest.new().run_all())
	results.append(InventoryTest.new().run_all())
	results.append(EquipmentTest.new().run_all())
	results.append(CombinedStackTest.new().run_all())
	results.append(RelationshipTest.new().run_all())
	results.append(CombatSliceOpportunityTest.new().run_all())
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	if failures.is_empty():
		print("PASS Phase 7B1 targeted regressions: %d assertions" % assertions)
		quit(0)
		return
	for failure: String in failures:
		printerr(failure)
	printerr(
		"FAIL Phase 7B1 targeted regressions: %d failure(s), %d assertions"
		% [failures.size(), assertions]
	)
	quit(1)
