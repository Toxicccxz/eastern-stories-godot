extends SceneTree

const BirthTest := preload("res://tests/core/new_player_initialization_test.gd")
const LegacyTest := preload("res://tests/runtime/new_player_legacy_integration_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var results: Array[Dictionary] = [BirthTest.new().run_all()]
	results.append(await LegacyTest.new().run_all(self))
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	for failure: String in failures:
		printerr(failure)
	print("%s NGE1: %d assertions, %d failures" % ["PASS" if failures.is_empty() else "FAIL", assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
