extends RefCounted

## SuiteErrors: the error lines a suite may log are the ones it declares, as many as it says.

const EXPECTED_ERRORS: Dictionary = {"SuiteErrors provoked on purpose": 2}

var assertions: int = 0
var failures: Array[String] = []


func run_all() -> Dictionary:
	_judge()
	_declared_on_the_script()
	# This suite's own declaration, met: run_suite.gd checks these two against it.
	push_error("SuiteErrors provoked on purpose (1)")
	push_error("SuiteErrors provoked on purpose (2)")
	return {"assertions": assertions, "failures": failures}


func _judge() -> void:
	var expected: Dictionary = {"aborted": 1, "Cannot open": 2}
	var logged: Array[String] = ["ERROR Combat encounter x aborted: y @ res://a.gd:1", "ERROR Cannot open file 'a' @ x.cpp:2", "ERROR Cannot open file 'b' @ x.cpp:2"]
	_check(SuiteErrors.judge(logged, expected).is_empty(), "every line declared, every count met: no failure")
	_check(SuiteErrors.judge([], {}).is_empty(), "nothing declared, nothing logged")
	var undeclared: Array[String] = SuiteErrors.judge(["SHADER ERROR Unknown identifier @ s.gdshader:3"], {})
	_check(undeclared == ["undeclared SHADER ERROR Unknown identifier @ s.gdshader:3"], "an undeclared line fails: %s" % [undeclared])
	var fewer: Array[String] = SuiteErrors.judge(logged.slice(0, 2), expected)
	_check(fewer.size() == 1 and fewer[0].contains("2 error(s) containing「Cannot open」declared, 1 logged"), "an error that stops coming fails too: %s" % [fewer])
	var more: Array[String] = SuiteErrors.judge(logged + logged.slice(0, 1), expected)
	_check(more.size() == 1 and more[0].contains("1 error(s) containing「aborted」declared, 2 logged"), "and one that comes more often: %s" % [more])
	var many: Array[String] = []
	for i: int in SuiteErrors.SHOWN + 5:
		many.append("ERROR number %d @ x:1" % i)
	var shown: Array[String] = SuiteErrors.judge(many, {})
	_check(shown.size() == SuiteErrors.SHOWN + 1 and shown[-1] == "and 5 more undeclared error line(s)", "a flood is shown in part and counted: %d" % shown.size())


func _declared_on_the_script() -> void:
	var declared: Dictionary = SuiteErrors.expected_of(get_script())
	_check(declared == EXPECTED_ERRORS, "a suite's EXPECTED_ERRORS is read from its script: %s" % [declared])
	_check(SuiteErrors.expected_of(load("res://tests/support/suite_errors.gd")).is_empty(), "a script without it declares nothing")


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append("suite_errors: " + label)
