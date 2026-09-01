class_name ApplicationShellState
extends RefCounted

enum Mode {
	BOOT,
	MAIN_MENU,
	STARTING_SESSION,
	PLAYING,
	RESULT,
}

enum Operation {
	NONE,
	INSPECT_SLOT,
	NEW_GAME,
	CONTINUE,
	END_SESSION,
}

var _mode: int
var _operation: int


func _init(p_mode: int = Mode.BOOT, p_operation: int = Operation.NONE) -> void:
	_mode = p_mode
	_operation = p_operation


func mode() -> int:
	return _mode


func operation() -> int:
	return _operation


func is_valid() -> bool:
	if _mode < Mode.BOOT or _mode > Mode.RESULT:
		return false
	if _operation < Operation.NONE or _operation > Operation.END_SESSION:
		return false
	match _mode:
		Mode.BOOT:
			return _operation == Operation.NONE or _operation == Operation.INSPECT_SLOT
		Mode.STARTING_SESSION:
			return _operation == Operation.NEW_GAME or _operation == Operation.CONTINUE
		Mode.MAIN_MENU, Mode.PLAYING, Mode.RESULT:
			return _operation == Operation.NONE
	return false


static func boot_inspecting() -> ApplicationShellState:
	return ApplicationShellState.new(Mode.BOOT, Operation.INSPECT_SLOT)


static func main_menu() -> ApplicationShellState:
	return ApplicationShellState.new(Mode.MAIN_MENU)


static func starting(operation_value: int) -> ApplicationShellState:
	return ApplicationShellState.new(Mode.STARTING_SESSION, operation_value)


static func playing() -> ApplicationShellState:
	return ApplicationShellState.new(Mode.PLAYING)


static func result() -> ApplicationShellState:
	return ApplicationShellState.new(Mode.RESULT)
