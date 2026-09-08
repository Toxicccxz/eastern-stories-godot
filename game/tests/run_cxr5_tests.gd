extends SceneTree

const TacticalTest := preload("res://tests/runtime/combat_tactical_queue_test.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var result: Dictionary = await TacticalTest.new().run_all(self)
	for failure: String in result["failures"]:
		printerr(failure)
	if result["failures"].is_empty():
		print("PASS CXR5 targeted: %d assertions" % result["assertions"])
		quit(0)
	else:
		printerr("FAIL CXR5 targeted: %d assertions" % result["assertions"])
		quit(1)
