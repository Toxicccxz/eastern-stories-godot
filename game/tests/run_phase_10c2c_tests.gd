extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var result: Dictionary[String, Variant] = await preload("res://tests/application/mobile_lifecycle_test.gd").new().run_all(self)
	var audit: Dictionary[String, Variant] = await preload("res://tests/application/mobile_lifecycle_audit_test.gd").new().run_all(self)
	result["assertions"] += audit["assertions"]
	result["failures"].append_array(audit["failures"])
	for failure: String in result["failures"]:
		push_error(failure)
	print("%s Phase 10C2C: %d assertions, %d failures" % ["PASS" if result["failures"].is_empty() else "FAIL", result["assertions"], result["failures"].size()])
	quit(0 if result["failures"].is_empty() else 1)
