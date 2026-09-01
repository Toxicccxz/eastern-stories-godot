extends SceneTree

const ApplicationShellTest := preload(
	"res://tests/application/application_shell_test.gd"
)
const GameSaveRepositoryTest := preload(
	"res://tests/runtime/game_save_repository_test.gd"
)
const OldPineSaveLoadTransactionTest := preload(
	"res://tests/runtime/oldpine_save_load_transaction_test.gd"
)
const OldPineWorldSessionTest := preload(
	"res://tests/runtime/oldpine_world_session_test.gd"
)
const OldPineOutdoorSmokeTest := preload(
	"res://tests/runtime/oldpine_outdoor_smoke_test.gd"
)


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var results: Array[Dictionary] = []
	results.append(await ApplicationShellTest.new().run_all(self))
	results.append(GameSaveRepositoryTest.new().run_all())
	results.append(await OldPineSaveLoadTransactionTest.new().run_all(self))
	results.append(await OldPineWorldSessionTest.new().run_all(self))
	results.append(await OldPineOutdoorSmokeTest.new().run_all(self))
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	if failures.is_empty():
		print("PASS Phase 10C1B focused: %d assertions" % assertions)
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("FAIL: %d failure(s), %d assertions" % [failures.size(), assertions])
	quit(1)
