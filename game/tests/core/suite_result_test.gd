extends RefCounted

## run_tests.gd adds up every suite through SuiteResult.checked(); a crashed suite must
## become a named failure, never an error in the runner.

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	var passed: Dictionary[String, Variant] = SuiteResult.checked("ok", {"assertions": 3, "failures": []})
	_assert_eq(passed["assertions"], 3, "a complete result passes through")
	_assert_eq((passed["failures"] as Array).size(), 0, "with its failures")
	for crashed: Variant in [{}, null, {"assertions": 1}]:
		var result: Dictionary[String, Variant] = SuiteResult.checked("broken_test", crashed)
		_assert_eq(result["assertions"], 0, "no result counts no assertions: %s" % str(crashed))
		_assert_eq(result["failures"], ["broken_test: run_all() returned no result (script error?)"], "and one failure naming the suite: %s" % str(crashed))
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("SUITE RESULT: %s (expected %s, got %s)" % [message, str(expected), str(actual)])
