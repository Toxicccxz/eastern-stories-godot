extends SceneTree

const PhaseTest := preload(
	"res://tests/core/native_item_persistence_composition_test.gd"
)
const Phase10B1CodecTest := preload("res://tests/core/game_save_json_codec_test.gd")
const Phase10B1RandomTest := preload(
	"res://tests/runtime/random_stream_persistence_test.gd"
)
const Phase10B1RepositoryTest := preload(
	"res://tests/runtime/game_save_repository_test.gd"
)
const Phase4B5ATest := preload("res://tests/core/native_item_save_restore_test.gd")
const OldPineSessionTest := preload(
	"res://tests/runtime/oldpine_world_session_test.gd"
)
const OldPineCorpseTest := preload(
	"res://tests/runtime/oldpine_corpse_loot_interaction_test.gd"
)
const InventoryTest := preload(
	"res://tests/core/inventory_containment_transfer_test.gd"
)
const EquipmentTest := preload("res://tests/core/equipment_state_test.gd")
const ArmorTest := preload("res://tests/core/armor_foundation_test.gd")
const CombinedTest := preload("res://tests/core/combined_stack_currency_test.gd")
const NpcFoundationTest := preload("res://tests/core/npc_spawn_foundation_test.gd")
const NpcArmorLoadoutTest := preload("res://tests/core/npc_armor_loadout_test.gd")
const DeathInventoryTest := preload("res://tests/core/death_inventory_corpse_test.gd")
const RuntimeLifecycleTest := preload(
	"res://tests/runtime/combat_slice_lifecycle_corpse_test.gd"
)


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var scripts: Array[Script] = [
		preload("res://core/persistence/session_item_id_allocation_result.gd"),
		preload("res://core/persistence/session_item_id_allocator_restore_result.gd"),
		preload("res://core/persistence/session_item_id_allocator.gd"),
		preload("res://core/persistence/native_item_restore_composition_result.gd"),
		preload("res://core/persistence/native_item_persistence_composition.gd"),
		preload("res://data/oldpine/oldpine_native_item_definition_projections.gd"),
		PhaseTest,
	]
	for script: Script in scripts:
		if not script.can_instantiate():
			printerr("FAIL: Phase 10B2 script cannot instantiate: %s" % script.resource_path)
			quit(1)
			return
	var results: Array[Dictionary] = [PhaseTest.new().run_all()]
	results.append(Phase10B1CodecTest.new().run_all())
	results.append(Phase10B1RandomTest.new().run_all())
	results.append(Phase10B1RepositoryTest.new().run_all())
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
	results.append(await OldPineCorpseTest.new().run_all(self))
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	if failures.is_empty():
		print("PASS Phase 10B2 focused: %d assertions" % assertions)
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("FAIL: %d failure(s), %d assertions" % [failures.size(), assertions])
	quit(1)
