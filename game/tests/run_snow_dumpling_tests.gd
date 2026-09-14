extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var count: int = 0
	var failures: Array[String] = []
	for path: String in ["res://tests/runtime/snow_dumpling_test.gd", "res://tests/runtime/snow_bank_access_test.gd", "res://tests/runtime/snow_finance_test.gd", "res://tests/runtime/snow_work_income_test.gd"]:
		var result: Dictionary = await load(path).new().run_all(self)
		count += int(result.assertions)
		failures.append_array(result.failures)
	for failure: String in failures: printerr(failure)
	print("S4B focused: %d assertions, %d failures" % [count, failures.size()])
	quit(0 if failures.is_empty() else 1)
