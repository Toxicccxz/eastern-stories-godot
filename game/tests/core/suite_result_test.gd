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
	# A fight that aborted during the suite is a failure even when its checks passed.
	CombatEncounterCoordinator._aborted_total += 2
	var aborted: Dictionary[String, Variant] = SuiteResult.checked("fighting_test", {"assertions": 5, "failures": []})
	_assert_eq(aborted["assertions"], 5, "an abort keeps the assertions")
	_assert_eq(aborted["failures"], ["fighting_test: 2 combat encounter(s) aborted (see the push_error lines)"], "and adds one failure naming the count")
	_assert_eq(CombatEncounterCoordinator.take_aborted_total(), 0, "the count is taken")
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("SUITE RESULT: %s (expected %s, got %s)" % [message, str(expected), str(actual)])
