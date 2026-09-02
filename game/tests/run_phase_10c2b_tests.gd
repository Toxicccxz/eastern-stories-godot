extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result: Dictionary[String, Variant] = await preload("res://tests/application/mobile_touch_test.gd").new().run_all(self)
	for failure: String in result["failures"]:
		push_error(failure)
	print("%s Phase 10C2B: %d assertions, %d failures" % ["PASS" if result["failures"].is_empty() else "FAIL", result["assertions"], result["failures"].size()])
	quit(0 if result["failures"].is_empty() else 1)
