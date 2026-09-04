class_name WorldSimulationGate
extends RefCounted

var _freeze_owner_id: StringName = &""


func is_open() -> bool:
	return _freeze_owner_id.is_empty()


func is_frozen() -> bool:
	return not is_open()


func freeze_owner_id() -> StringName:
	return _freeze_owner_id


func acquire(owner_id: StringName) -> bool:
	if owner_id.is_empty() or not is_open():
		return false
	_freeze_owner_id = owner_id
	return true


func release(owner_id: StringName) -> bool:
	if owner_id.is_empty() or _freeze_owner_id != owner_id:
		return false
	_freeze_owner_id = &""
	return true
