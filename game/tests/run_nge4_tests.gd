extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Load after main-loop initialization, as with the existing NGE2 Session test.
	var test: RefCounted = load("res://tests/runtime/snow_oldpine_connection_test.gd").new()
	var result: Dictionary = await test.run_all(self)
	await process_frame
	for failure: String in result["failures"]:
		printerr(failure)
	print("%s NGE4: %d assertions, %d failures" % ["PASS" if result["failures"].is_empty() else "FAIL", result["assertions"], result["failures"].size()])
	quit(0 if result["failures"].is_empty() else 1)
