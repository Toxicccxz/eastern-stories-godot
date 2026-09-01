class_name ApplicationSlotInspection
extends RefCounted

enum Availability {
	NO_SAVE,
	CONTINUE_AVAILABLE,
	RECOVERY_REQUIRED,
	SAVE_UNUSABLE,
	UNSUPPORTED_SAVE,
	STORAGE_FAILURE,
}

var _availability: int
var _message_key: StringName


func _init(
	p_availability: int = Availability.STORAGE_FAILURE,
	p_message_key: StringName = &"save.storage_failure",
) -> void:
	_availability = p_availability
	_message_key = p_message_key


func availability() -> int:
	return _availability


func message_key() -> StringName:
	return _message_key


func continue_available() -> bool:
	return _availability == Availability.CONTINUE_AVAILABLE


func has_save_material() -> bool:
	# A storage failure cannot prove the slot is empty, so New Game confirmation
	# remains conservative. Starting New Game itself never mutates the slot.
	return _availability != Availability.NO_SAVE
