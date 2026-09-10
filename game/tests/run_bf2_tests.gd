extends SceneTree

const Profiles := preload("res://tests/core/beast_combat_profile_test.gd")
const Execution := preload("res://tests/core/beast_combat_execution_test.gd")
const ProjectionTests := preload("res://tests/core/beast_combat_projection_test.gd")


func _init() -> void:
	var assertions: int = 0
	var failures: Array[String] = []
	for suite: Script in [Profiles, Execution, ProjectionTests]:
		var result: Dictionary[String, Variant] = suite.new().run_all()
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
		print("%s: %d assertions, %d failures" % [suite.resource_path, result["assertions"], result["failures"].size()])
	for failure: String in failures:
		printerr(failure)
	print("%s BF2 focused: %d assertions" % ["PASS" if failures.is_empty() else "FAIL", assertions])
	quit(0 if failures.is_empty() else 1)
