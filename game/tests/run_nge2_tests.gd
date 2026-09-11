extends SceneTree

const InnTest := preload("res://tests/runtime/snow_inn_foundation_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var result: Dictionary = await InnTest.new().run_all(self)
	await process_frame
	for failure: String in result["failures"]:
		printerr(failure)
	print("%s NGE2: %d assertions, %d failures" % ["PASS" if result["failures"].is_empty() else "FAIL", result["assertions"], result["failures"].size()])
	quit(0 if result["failures"].is_empty() else 1)
