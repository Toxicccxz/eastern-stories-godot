class_name ApplicationOperationResult
extends RefCounted

enum Operation {
	INSPECT_SLOT,
	NEW_GAME,
	CONTINUE,
	END_SESSION,
}

enum Outcome {
	SUCCESS,
	NO_SAVE,
	RECOVERY_REQUIRED,
	INVALID_SAVE,
	UNSUPPORTED_SAVE,
	STORAGE_FAILURE,
	RESTORE_FAILURE,
	SESSION_FAILURE,
	REQUEST_BUSY,
	CONFIRMATION_REQUIRED,
}

var _operation: int
var _outcome: int
var _message_key: StringName


func _init(
	p_operation: int,
	p_outcome: int,
	p_message_key: StringName,
) -> void:
	_operation = p_operation
	_outcome = p_outcome
	_message_key = p_message_key


func operation() -> int:
	return _operation


func outcome() -> int:
	return _outcome


func message_key() -> StringName:
	return _message_key


func succeeded() -> bool:
	return _outcome == Outcome.SUCCESS
