extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var count: int = 0
	var failures: Array[String] = []
	for path: String in [
		"res://tests/application/public_source_new_game_test.gd",
		"res://tests/application/application_shell_test.gd",
		"res://tests/application/application_shell_phase10c1c_test.gd",
		"res://tests/application/mobile_lifecycle_test.gd",
		"res://tests/application/mobile_lifecycle_audit_test.gd",
		"res://tests/runtime/versioned_source_save_test.gd",
		"res://tests/runtime/player_body_facts_test.gd",
		"res://tests/runtime/new_player_legacy_integration_test.gd",
	]:
		var result: Dictionary = await load(path).new().run_all(self)
		count += result["assertions"]
		failures.append_array(result["failures"])
	for failure: String in failures: printerr(failure)
	print("%s NGE5B: %d assertions, %d failures" % ["PASS" if failures.is_empty() else "FAIL", count, failures.size()])
	quit(0 if failures.is_empty() else 1)
