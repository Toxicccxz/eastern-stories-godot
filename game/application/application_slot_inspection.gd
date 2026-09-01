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
var _recovery_sources: Array[int] = []


func _init(
	p_availability: int = Availability.STORAGE_FAILURE,
	p_message_key: StringName = &"save.storage_failure",
	p_recovery_sources: Array[int] = [],
) -> void:
	_availability = p_availability
	_message_key = p_message_key
	for source: int in p_recovery_sources:
		if GameSaveRecoverySource.is_valid(source) and not _recovery_sources.has(source):
			_recovery_sources.append(source)


func availability() -> int:
	return _availability


func message_key() -> StringName:
	return _message_key


func continue_available() -> bool:
	return _availability == Availability.CONTINUE_AVAILABLE


func recovery_sources() -> Array[int]:
	return _recovery_sources.duplicate()


func recovery_available() -> bool:
	return not _recovery_sources.is_empty()


func has_recovery_source(source: int) -> bool:
	return _recovery_sources.has(source)


func has_save_material() -> bool:
	# A storage failure cannot prove the slot is empty, so New Game confirmation
	# remains conservative. Starting New Game itself never mutates the slot.
	return _availability != Availability.NO_SAVE
