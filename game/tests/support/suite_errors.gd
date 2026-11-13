class_name SuiteErrors
extends RefCounted

## The ERROR and SHADER ERROR lines a suite may log (run_suite.gd counts every one): none,
## unless the suite provokes them on purpose and says so in a constant naming a part of each
## message and how many times it comes:
##
##     const EXPECTED_ERRORS: Dictionary = {"Combat encounter encounter:production:1 aborted": 1}
##
## Each logged line counts for the first declared part it contains. A line no part matches
## fails the suite, and so does a part logged more or fewer times than declared: an error
## that stops coming is as much news as a new one. SCRIPT ERROR lines are never allowed.

const CONSTANT: String = "EXPECTED_ERRORS"
## Undeclared lines shown per suite; the rest are counted.
const SHOWN: int = 20


static func expected_of(script: Script) -> Dictionary:
	var declared: Variant = script.get_script_constant_map().get(CONSTANT, {})
	return declared if declared is Dictionary else {}


## The failures for `logged` (as run_suite.gd records them: "ERROR <message> @ <where>")
## against what the suite declared.
static func judge(logged: Array[String], expected: Dictionary) -> Array[String]:
	var seen: Dictionary = {}
	var undeclared: Array[String] = []
	for line: String in logged:
		var matched: Variant = null
		for part: Variant in expected:
			if line.contains(str(part)):
				matched = part
				break
		if matched == null:
			undeclared.append(line)
		else:
			seen[matched] = int(seen.get(matched, 0)) + 1
	var failures: Array[String] = []
	for line: String in undeclared.slice(0, SHOWN):
		failures.append("undeclared %s" % line)
	if undeclared.size() > SHOWN:
		failures.append("and %d more undeclared error line(s)" % (undeclared.size() - SHOWN))
	for part: Variant in expected:
		var count: int = int(seen.get(part, 0))
		if count != int(expected[part]):
			failures.append("%s: %d error(s) containing「%s」declared, %d logged" % [CONSTANT, int(expected[part]), str(part), count])
	return failures
