extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var result: Dictionary[String, Variant] = await preload("res://tests/runtime/battle_presentation_test.gd").new().run_all(self)
	for failure: String in result["failures"]:
		printerr(failure)
	print("%s CXR6: %d assertions, %d failures" % ["PASS" if result["failures"].is_empty() else "FAIL", result["assertions"], result["failures"].size()])
	quit(0 if result["failures"].is_empty() else 1)
