class_name CombatTargetAssignment
extends RefCounted

var _actor_id: StringName
var _target_id: StringName

var actor_id: StringName:
	get:
		return _actor_id
var target_id: StringName:
	get:
		return _target_id


func _init(
	p_actor_id: StringName = &"",
	p_target_id: StringName = &"",
) -> void:
	_actor_id = p_actor_id
	_target_id = p_target_id


func is_valid() -> bool:
	return (
		not _actor_id.is_empty()
		and not _target_id.is_empty()
		and _actor_id != _target_id
	)


func duplicate_snapshot() -> CombatTargetAssignment:
	return CombatTargetAssignment.new(_actor_id, _target_id)
