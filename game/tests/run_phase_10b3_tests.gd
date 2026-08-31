extends SceneTree

const PhaseTest := preload(
	"res://tests/runtime/oldpine_world_restore_test.gd"
)
const Phase10B1CodecTest := preload("res://tests/core/game_save_json_codec_test.gd")
const Phase10B1RandomTest := preload(
	"res://tests/runtime/random_stream_persistence_test.gd"
)
const Phase10B1RepositoryTest := preload(
	"res://tests/runtime/game_save_repository_test.gd"
)
const Phase10B2Test := preload(
	"res://tests/core/native_item_persistence_composition_test.gd"
)
const CharacterTest := preload("res://tests/core/character_state_test.gd")
const SkillTest := preload("res://tests/core/skill_core_test.gd")
const ConditionTest := preload("res://tests/core/condition_system_test.gd")
const Phase4B5ATest := preload("res://tests/core/native_item_save_restore_test.gd")
const InventoryTest := preload("res://tests/core/inventory_containment_transfer_test.gd")
const EquipmentTest := preload("res://tests/core/equipment_state_test.gd")
const ArmorTest := preload("res://tests/core/armor_foundation_test.gd")
const CombinedTest := preload("res://tests/core/combined_stack_currency_test.gd")
const NpcFoundationTest := preload("res://tests/core/npc_spawn_foundation_test.gd")
const NpcArmorLoadoutTest := preload("res://tests/core/npc_armor_loadout_test.gd")
const DeathInventoryTest := preload("res://tests/core/death_inventory_corpse_test.gd")
const RuntimeLifecycleTest := preload(
	"res://tests/runtime/combat_slice_lifecycle_corpse_test.gd"
)
const OldPineSessionTest := preload(
	"res://tests/runtime/oldpine_world_session_test.gd"
)
const VineTest := preload(
	"res://tests/runtime/oldpine_vine_cross_map_traversal_test.gd"
)
const RiverTest := preload(
	"res://tests/runtime/oldpine_river_cliff_route_test.gd"
)


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var scripts: Array[Script] = [
		preload("res://core/persistence/character_state_snapshot_restorer.gd"),
		preload("res://runtime/persistence/oldpine_restored_npc_entry.gd"),
		preload("res://runtime/persistence/oldpine_restored_corpse_entry.gd"),
		preload("res://runtime/persistence/oldpine_world_restore_preparation.gd"),
		preload("res://runtime/persistence/oldpine_world_restore_result.gd"),
		preload("res://runtime/persistence/oldpine_world_restore_composition.gd"),
		preload("res://runtime/persistence/oldpine_map_placement_validator.gd"),
		preload("res://runtime/persistence/oldpine_world_restore_service.gd"),
		PhaseTest,
	]
	for script: Script in scripts:
		if not script.can_instantiate():
			printerr("FAIL: Phase 10B3 script cannot instantiate: %s" % script.resource_path)
			quit(1)
			return
	var results: Array[Dictionary] = []
	results.append(await PhaseTest.new().run_all(self))
	results.append(Phase10B1CodecTest.new().run_all())
	results.append(Phase10B1RandomTest.new().run_all())
	results.append(Phase10B1RepositoryTest.new().run_all())
	results.append(Phase10B2Test.new().run_all())
	results.append(CharacterTest.new().run_all())
	results.append(SkillTest.new().run_all())
	results.append(ConditionTest.new().run_all())
	results.append(Phase4B5ATest.new().run_all())
	results.append(InventoryTest.new().run_all())
	results.append(EquipmentTest.new().run_all())
	results.append(ArmorTest.new().run_all())
	results.append(CombinedTest.new().run_all())
	results.append(NpcFoundationTest.new().run_all())
	results.append(NpcArmorLoadoutTest.new().run_all())
	results.append(DeathInventoryTest.new().run_all())
	results.append(await RuntimeLifecycleTest.new().run_all(self))
	results.append(await OldPineSessionTest.new().run_all(self))
	results.append(await VineTest.new().run_all(self))
	results.append(await RiverTest.new().run_all(self))
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	if failures.is_empty():
		print("PASS Phase 10B3 focused: %d assertions" % assertions)
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("FAIL: %d failure(s), %d assertions" % [failures.size(), assertions])
	quit(1)
