class_name SuiteResult
extends RefCounted

## What a suite's run_all() returned, made safe to add up. A script error inside run_all()
## ends it early with no result; that becomes one failure naming the suite instead of an
## error in the runner (which would stop run_tests.gd before it can quit).


static func checked(suite: String, result: Variant) -> Dictionary[String, Variant]:
	if result is Dictionary and (result as Dictionary).has("assertions") and (result as Dictionary).has("failures"):
		var valid: Dictionary[String, Variant] = {}
		valid.assign(result)
		return valid
	var failures: Array[String] = ["%s: run_all() returned no result (script error?)" % suite]
	return {"assertions": 0, "failures": failures}
