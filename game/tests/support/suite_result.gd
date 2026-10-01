class_name SuiteResult
extends RefCounted

## What a suite's run_all() returned, made safe to add up. A script error inside run_all()
## ends it early with no result; that becomes one failure naming the suite instead of an
## error in the runner (which would stop run_tests.gd before it can quit).


## A fight that aborted on a failed attack chain or lifecycle is a failure too, unless
## the suite took the count itself (CombatEncounterCoordinator.take_aborted_total()).
static func checked(suite: String, result: Variant) -> Dictionary[String, Variant]:
	var aborted: int = CombatEncounterCoordinator.take_aborted_total()
	var checked_result: Dictionary[String, Variant] = {}
	if result is Dictionary and (result as Dictionary).has("assertions") and (result as Dictionary).has("failures"):
		checked_result.assign(result)
	else:
		var failures: Array[String] = ["%s: run_all() returned no result (script error?)" % suite]
		checked_result = {"assertions": 0, "failures": failures}
	if aborted > 0:
		var failures: Array = (checked_result["failures"] as Array).duplicate()
		failures.append("%s: %d combat encounter(s) aborted (see the push_error lines)" % [suite, aborted])
		checked_result["failures"] = failures
	return checked_result
