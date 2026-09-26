extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--lake-regressions" in OS.get_cmdline_user_args():
		var started: int = Time.get_ticks_msec()
		var failures: Array[String] = []
		for path: String in ["core/serpent_definition_test", "core/world_definition_test", "core/npc_spawn_foundation_test"]:
			var result: Dictionary = load("res://tests/" + path + ".gd").new().run_all()
			failures.append_array(result.failures)
			print("Lake regression %s: %d failures" % [path, result.failures.size()])
		for path: String in ["runtime/oldpine_lake_production_test", "runtime/oldpine_world_restore_test", "runtime/beast_runtime_integration_test", "runtime/oldpine_outdoor_smoke_test", "runtime/oldpine_portal_aggression_test", "runtime/oldpine_river_cliff_route_test", "runtime/snow_first_progression_test", "runtime/snow_water_test", "runtime/player_recovery_cadence_test", "application/public_source_new_game_test", "runtime/snow_oldpine_connection_test", "runtime/versioned_source_save_test", "runtime/beast_human_save_regression_test"]:
			var result: Dictionary = await load("res://tests/" + path + ".gd").new().run_all(self)
			failures.append_array(result.failures)
			print("Lake regression %s: %d failures" % [path, result.failures.size()])
		for failure: String in failures: push_error(failure)
		print("Lake affected regressions: %d failures; %.2fs" % [failures.size(), (Time.get_ticks_msec()-started)/1000.0])
		quit(0 if failures.is_empty() else 1)
		return
	if "--lake-only" in OS.get_cmdline_user_args():
		var started: int = Time.get_ticks_msec()
		var result: Dictionary = await load("res://tests/runtime/oldpine_lake_production_test.gd").new().run_all(self)
		for failure: String in result.failures: push_error(failure)
		print("Lake production: %d checks; %d failures; %.2fs" % [result.assertions, result.failures.size(), (Time.get_ticks_msec()-started)/1000.0])
		quit(0 if result.failures.is_empty() else 1)
		return
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
