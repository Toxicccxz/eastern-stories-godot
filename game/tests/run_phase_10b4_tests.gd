extends SceneTree

const Phase10B4Test := preload(
	"res://tests/runtime/oldpine_save_load_transaction_test.gd"
)
const Phase10B3Test := preload(
	"res://tests/runtime/oldpine_world_restore_test.gd"
)
const Phase10B1CodecTest := preload("res://tests/core/game_save_json_codec_test.gd")
const Phase10B2Test := preload(
	"res://tests/core/native_item_persistence_composition_test.gd"
)
const SessionTest := preload("res://tests/runtime/oldpine_world_session_test.gd")
const LifecycleTest := preload(
	"res://tests/runtime/combat_slice_lifecycle_corpse_test.gd"
)


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var results: Array[Dictionary] = []
	results.append(await Phase10B4Test.new().run_all(self))
	results.append(await Phase10B3Test.new().run_all(self))
	results.append(Phase10B1CodecTest.new().run_all())
	results.append(Phase10B2Test.new().run_all())
	results.append(await SessionTest.new().run_all(self))
	results.append(await LifecycleTest.new().run_all(self))
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	if failures.is_empty():
		print("PASS Phase 10B4 focused: %d assertions" % assertions)
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("FAIL: %d failure(s), %d assertions" % [failures.size(), assertions])
	quit(1)
