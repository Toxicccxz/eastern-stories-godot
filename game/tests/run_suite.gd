extends SceneTree

## Runs selected test suites instead of the full run_tests.gd registry.
## Usage: godot --headless --path game --script res://tests/run_suite.gd -- <path>...
## Each path is a *_test.gd script or a directory searched recursively for *_test.gd.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var suite_paths: Array[String] = []
	for argument: String in OS.get_cmdline_user_args():
		_collect(_as_resource_path(argument), suite_paths)
	if suite_paths.is_empty():
		printerr("usage: --script res://tests/run_suite.gd -- <suite.gd | directory>...")
		quit(2)
		return

	var assertions: int = 0
	var failures: Array[String] = []
	for path: String in suite_paths:
		var script: Script = load(path) as Script
		if script == null or not script.can_instantiate():
			failures.append("%s: cannot load or instantiate" % path)
			continue
		var suite: Object = script.new()
		if not suite.has_method("run_all"):
			failures.append("%s: no run_all()" % path)
			continue
		var arguments: Array = [self] if _run_all_argument_count(suite) == 1 else []
		var started_msec: int = Time.get_ticks_msec()
		var result: Dictionary = SuiteResult.checked(path.get_file().get_basename(), await suite.callv("run_all", arguments))
		var suite_failures: Array = result["failures"]
		assertions += int(result.get("assertions", 0))
		for failure: Variant in suite_failures:
			failures.append("%s: %s" % [path.get_file(), str(failure)])
		print("%s  %d assertions, %d failures, %d ms" % [
			path, int(result.get("assertions", 0)), suite_failures.size(),
			Time.get_ticks_msec() - started_msec,
		])

	for failure: String in failures:
		printerr(failure)
	print("%s: %d suite(s), %d assertions, %d failure(s)" % [
		"PASS" if failures.is_empty() else "FAIL", suite_paths.size(), assertions, failures.size(),
	])
	quit(0 if failures.is_empty() else 1)


func _as_resource_path(argument: String) -> String:
	if argument.begins_with("res://"):
		return argument
	var relative: String = argument.replace("\\", "/").trim_prefix("./").trim_prefix("game/")
	return "res://" + relative


func _collect(path: String, into: Array[String]) -> void:
	if DirAccess.dir_exists_absolute(path):
		var directory: DirAccess = DirAccess.open(path)
		for file: String in directory.get_files():
			if file.ends_with("_test.gd"):
				into.append(path.path_join(file))
		for child: String in directory.get_directories():
			_collect(path.path_join(child), into)
		return
	into.append(path)


func _run_all_argument_count(suite: Object) -> int:
	for method: Dictionary in suite.get_method_list():
		if method["name"] == "run_all":
			return (method["args"] as Array).size()
	return 0
