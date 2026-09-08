class_name CombatParticipant
extends RefCounted

var _participant_id: StringName
var _side_id: StringName
var _binding: CombatEncounterAuthorityBinding

var participant_id: StringName:
	get:
		return _participant_id
var side_id: StringName:
	get:
		return _side_id
var binding: CombatEncounterAuthorityBinding:
	get:
		return _binding


func _init(
	p_participant_id: StringName = &"",
	p_side_id: StringName = &"",
	p_binding: CombatEncounterAuthorityBinding = null,
) -> void:
	_participant_id = p_participant_id
	_side_id = p_side_id
	_binding = p_binding


func is_valid() -> bool:
	return (
		not _participant_id.is_empty()
		and not _side_id.is_empty()
		and _binding != null
		and _binding.is_valid()
		and _binding.participant_id == _participant_id
	)


func duplicate_reference() -> CombatParticipant:
	return CombatParticipant.new(
		_participant_id,
		_side_id,
		null if _binding == null else _binding.duplicate_reference(),
	)
