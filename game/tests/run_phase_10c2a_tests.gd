extends SceneTree

const PresentationTest := preload("res://tests/presentation/mobile_presentation_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var results: Array[Dictionary] = []
	if "--consumers" in OS.get_cmdline_user_args():
		results.append(await preload("res://tests/application/application_shell_phase10c1b_test.gd").new().run_all(self))
		results.append(preload("res://tests/runtime/player_inventory_equipment_test.gd").new().run_all())
		results.append(await preload("res://tests/runtime/oldpine_full_loot_loop_test.gd").new().run_all(self))
		results.append(await preload("res://tests/runtime/oldpine_corpse_loot_interaction_test.gd").new().run_all(self))
		results.append(await preload("res://tests/runtime/oldpine_fat_bandit_armor_loop_test.gd").new().run_all(self))
		results.append(await preload("res://tests/runtime/oldpine_pine_maze_tall_bandit_test.gd").new().run_all(self))
		results.append(await preload("res://tests/runtime/oldpine_river_cliff_route_test.gd").new().run_all(self))
	else:
		results.append(await PresentationTest.new().run_all(self))
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += result["assertions"]
		failures.append_array(result["failures"])
	for failure: String in failures:
		push_error(failure)
	print("%s Phase 10C2A %s: %d assertions, %d failures" % ["PASS" if failures.is_empty() else "FAIL", "consumers" if "--consumers" in OS.get_cmdline_user_args() else "layout", assertions, failures.size()])
	await process_frame
	quit(0 if failures.is_empty() else 1)
