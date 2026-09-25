extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var result: Dictionary = await load("res://tests/runtime/snow_martial_progression_test.gd").new().run_all(self)
	for failure: String in result.failures:
		push_error(failure)
	quit(0 if result.failures.is_empty() else 1)
