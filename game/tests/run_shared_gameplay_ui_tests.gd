extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var paths: PackedStringArray = OS.get_cmdline_user_args()
	if paths.is_empty():
		paths = ["runtime/shared_gameplay_ui_test", "runtime/oldpine_world_restore_test", "application/application_shell_test", "presentation/mobile_presentation_test", "presentation/mobile_presentation_audit_test", "application/mobile_touch_test", "application/mobile_touch_audit_test", "runtime/battle_presentation_test", "runtime/snow_dumpling_test", "runtime/snow_water_test", "runtime/snow_bank_access_test", "runtime/oldpine_playability_test"]
	var failures: Array[String] = []
	for path: String in paths:
		print("START " + path)
		var result: Dictionary = await load("res://tests/" + path + ".gd").new().run_all(self)
		failures.append_array(result["failures"])
		print(result)
	print("Shared UI consumer checks: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
