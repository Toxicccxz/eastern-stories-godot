extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--foundations-only" in OS.get_cmdline_user_args():
		var result: Dictionary = await load("res://tests/runtime/oldpine_p2a_foundations_test.gd").new().run_all(self)
		for failure: String in result.failures: push_error(failure)
		print("P2A foundations: %d assertions; %d failures" % [result.assertions, result.failures.size()])
		quit(0 if result.failures.is_empty() else 1)
		return
	var count: int = 0
	var failures: Array[String] = []
	for path: String in ["runtime/oldpine_p2a_foundations_test", "runtime/versioned_source_save_test", "runtime/oldpine_world_restore_test", "runtime/beast_human_save_regression_test", "runtime/beast_runtime_integration_test", "runtime/snow_martial_progression_acceptance_test", "runtime/snow_martial_progression_test", "runtime/snow_first_progression_test", "runtime/oldpine_outdoor_smoke_test", "runtime/combat_tactical_queue_test", "runtime/combat_flee_test", "runtime/oldpine_save_load_transaction_test"]:
		var result: Dictionary = await load("res://tests/" + path + ".gd").new().run_all(self)
		count += int(result.assertions)
		failures.append_array(result.failures)
	for path: String in ["core/learn_service_test", "core/equipment_skill_learn_policies_test"]:
		var result: Dictionary = load("res://tests/" + path + ".gd").new().run_all()
		count += int(result.assertions)
		failures.append_array(result.failures)
	for failure: String in failures:
		push_error(failure)
	print("P2A focused gate: %d assertions; %d failures" % [count, failures.size()])
	quit(0 if failures.is_empty() else 1)
