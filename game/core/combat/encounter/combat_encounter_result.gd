class_name CombatEncounterResult
extends RefCounted

var _encounter_id: StringName
var _mode: int
var _kind: int
var _winning_side_ids: Array[StringName] = []
var _losing_side_ids: Array[StringName] = []
var _subject_participant_ids: Array[StringName] = []
var _scripted_result_id: StringName

var encounter_id: StringName:
	get:
		return _encounter_id
var mode: int:
	get:
		return _mode
var kind: int:
	get:
		return _kind
var scripted_result_id: StringName:
	get:
		return _scripted_result_id


func _init(
	p_encounter_id: StringName = &"",
	p_mode: int = -1,
	p_kind: int = -1,
	p_winning_side_ids: Array[StringName] = [],
	p_losing_side_ids: Array[StringName] = [],
	p_subject_participant_ids: Array[StringName] = [],
	p_scripted_result_id: StringName = &"",
) -> void:
	_encounter_id = p_encounter_id
	_mode = p_mode
	_kind = p_kind
	_winning_side_ids = p_winning_side_ids.duplicate()
	_losing_side_ids = p_losing_side_ids.duplicate()
	_subject_participant_ids = p_subject_participant_ids.duplicate()
	_scripted_result_id = p_scripted_result_id


func is_valid() -> bool:
	if (
		_encounter_id.is_empty()
		or not CombatEncounterMode.is_valid(_mode)
		or not CombatEncounterResultKind.is_valid(_kind)
		or not _ids_are_unique_and_nonempty(_winning_side_ids)
		or not _ids_are_unique_and_nonempty(_losing_side_ids)
		or not _ids_are_unique_and_nonempty(_subject_participant_ids)
	):
		return false
	for side_id: StringName in _winning_side_ids:
		if _losing_side_ids.has(side_id):
			return false
	if _kind == CombatEncounterResultKind.Value.SCRIPTED:
		return _mode == CombatEncounterMode.Value.SCRIPTED and not _scripted_result_id.is_empty()
	return _scripted_result_id.is_empty()


func winning_side_ids() -> Array[StringName]:
	return _winning_side_ids.duplicate()


func losing_side_ids() -> Array[StringName]:
	return _losing_side_ids.duplicate()


func subject_participant_ids() -> Array[StringName]:
	return _subject_participant_ids.duplicate()


func duplicate_snapshot() -> CombatEncounterResult:
	return CombatEncounterResult.new(
		_encounter_id,
		_mode,
		_kind,
		_winning_side_ids,
		_losing_side_ids,
		_subject_participant_ids,
		_scripted_result_id,
	)


static func _ids_are_unique_and_nonempty(ids: Array[StringName]) -> bool:
	var observed: Array[StringName] = []
	for value: StringName in ids:
		if value.is_empty() or observed.has(value):
			return false
		observed.append(value)
	return true
