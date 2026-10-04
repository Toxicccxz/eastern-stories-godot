class_name PerformFunction
extends RefCounted

## One perform action file (perform <skill>.<id>, a martial skill's
## perform_action_file()): perform() returns 1 after its effect, or notify_fail() and 0.
var id: StringName


func perform(_context: SpecialContext) -> bool:
	return false
