extends SceneTree

const BodyTests := preload("res://tests/core/beast_persistence_body_test.gd")
const DeathTests := preload("res://tests/runtime/beast_death_body_test.gd")
const HumanTests := preload("res://tests/runtime/beast_human_save_regression_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var assertions: int = 0
	var failures: Array[String] = []
	var results: Array[Dictionary] = [BodyTests.new().run_all(), DeathTests.new().run_all(), await HumanTests.new().run_all(self)]
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
		print("BF3 suite: %d assertions, %d failures" % [result["assertions"], result["failures"].size()])
	for failure: String in failures:
		printerr(failure)
	print("%s BF3 focused: %d assertions" % ["PASS" if failures.is_empty() else "FAIL", assertions])
	quit(0 if failures.is_empty() else 1)
