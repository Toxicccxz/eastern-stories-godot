extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var result: Dictionary = await load("res://tests/runtime/player_recovery_cadence_test.gd").new().run_all(self)
	for failure: String in result.failures: printerr(failure)
	print("S5B focused: %d assertions, %d failures" % [result.assertions, result.failures.size()])
	quit(0 if result.failures.is_empty() else 1)
