extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var count: int = 0
	var failures: Array[String] = []
	for path: String in [
		"res://tests/runtime/combat_tactical_queue_test.gd",
		"res://tests/runtime/battle_presentation_test.gd",
		"res://tests/runtime/combat_multi_target_test.gd",
		"res://tests/runtime/combat_flee_test.gd",
		"res://tests/runtime/combat_resolution_cutover_test.gd",
		"res://tests/runtime/oldpine_playability_test.gd",
		"res://tests/runtime/combat_vertical_slice_smoke_test.gd",
		"res://tests/runtime/combat_slice_lifecycle_corpse_test.gd",
		"res://tests/runtime/oldpine_outdoor_smoke_test.gd",
		"res://tests/runtime/oldpine_portal_aggression_test.gd",
		"res://tests/presentation/mobile_presentation_test.gd",
		"res://tests/presentation/mobile_presentation_audit_test.gd",
		"res://tests/application/mobile_touch_test.gd",
		"res://tests/application/mobile_touch_audit_test.gd",
	]:
		var result: Dictionary = await load(path).new().run_all(self)
		count += result["assertions"]
		failures.append_array(result["failures"])
		print("UI REGRESSION %s: %d failures" % [path, result["failures"].size()])
		if not result["failures"].is_empty():
			print(result["failures"])
	for failure: String in failures: printerr(failure)
	print("%s NGE5B UI: %d assertions, %d failures" % ["PASS" if failures.is_empty() else "FAIL", count, failures.size()])
	quit(0 if failures.is_empty() else 1)
