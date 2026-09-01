class_name ApplicationShellState
extends RefCounted

enum Mode {
	BOOT,
	MAIN_MENU,
	STARTING_SESSION,
	PLAYING,
	PAUSED,
	SAVING,
	RECOVERY_CHOICE,
	RESULT,
}

enum Operation {
	NONE,
	INSPECT_SLOT,
	NEW_GAME,
	CONTINUE,
	RECOVER,
	SAVE,
	END_SESSION,
}

enum ResultOrigin {
	NONE,
	MAIN_MENU,
	PAUSED,
}

var _mode: int
var _operation: int
var _result_origin: int


func _init(
	p_mode: int = Mode.BOOT,
	p_operation: int = Operation.NONE,
	p_result_origin: int = ResultOrigin.NONE,
) -> void:
	_mode = p_mode
	_operation = p_operation
	_result_origin = p_result_origin


func mode() -> int:
	return _mode


func operation() -> int:
	return _operation


func result_origin() -> int:
	return _result_origin


func is_valid() -> bool:
	if _mode < Mode.BOOT or _mode > Mode.RESULT:
		return false
	if _operation < Operation.NONE or _operation > Operation.END_SESSION:
		return false
	if _result_origin < ResultOrigin.NONE or _result_origin > ResultOrigin.PAUSED:
		return false
	match _mode:
		Mode.BOOT:
			return (
				(_operation == Operation.NONE or _operation == Operation.INSPECT_SLOT)
				and _result_origin == ResultOrigin.NONE
			)
		Mode.STARTING_SESSION:
			return (
				_operation in [Operation.NEW_GAME, Operation.CONTINUE, Operation.RECOVER, Operation.END_SESSION]
				and _result_origin == ResultOrigin.NONE
			)
		Mode.SAVING:
			return _operation == Operation.SAVE and _result_origin == ResultOrigin.NONE
		Mode.RESULT:
			return (
				_operation == Operation.NONE
				and _result_origin in [ResultOrigin.MAIN_MENU, ResultOrigin.PAUSED]
			)
		Mode.MAIN_MENU, Mode.PLAYING, Mode.PAUSED, Mode.RECOVERY_CHOICE:
			return _operation == Operation.NONE and _result_origin == ResultOrigin.NONE
	return false


static func boot_inspecting() -> ApplicationShellState:
	return ApplicationShellState.new(Mode.BOOT, Operation.INSPECT_SLOT)


static func main_menu() -> ApplicationShellState:
	return ApplicationShellState.new(Mode.MAIN_MENU)


static func starting(operation_value: int) -> ApplicationShellState:
	return ApplicationShellState.new(Mode.STARTING_SESSION, operation_value)


static func playing() -> ApplicationShellState:
	return ApplicationShellState.new(Mode.PLAYING)


static func paused() -> ApplicationShellState:
	return ApplicationShellState.new(Mode.PAUSED)


static func saving() -> ApplicationShellState:
	return ApplicationShellState.new(Mode.SAVING, Operation.SAVE)


static func recovery_choice() -> ApplicationShellState:
	return ApplicationShellState.new(Mode.RECOVERY_CHOICE)


static func result(origin: int) -> ApplicationShellState:
	return ApplicationShellState.new(Mode.RESULT, Operation.NONE, origin)
