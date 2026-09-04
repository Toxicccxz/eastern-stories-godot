class_name CombatTriggerCandidate
extends RefCounted

var _participant_id: StringName
var _side_id: StringName

var participant_id: StringName:
	get:
		return _participant_id
var side_id: StringName:
	get:
		return _side_id


func _init(
	p_participant_id: StringName = &"",
	p_side_id: StringName = &"",
) -> void:
	_participant_id = p_participant_id
	_side_id = p_side_id


func is_valid() -> bool:
	return not _participant_id.is_empty() and not _side_id.is_empty()


func duplicate_snapshot() -> CombatTriggerCandidate:
	return CombatTriggerCandidate.new(_participant_id, _side_id)
