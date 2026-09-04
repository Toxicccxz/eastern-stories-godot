class_name CombatTrigger
extends RefCounted

var _trigger_id: StringName
var _cause: int
var _requested_mode: int
var _initiator_id: StringName
var _candidates: Array[CombatTriggerCandidate] = []
var _source_location: WorldLocationState
var _authored_policy_id: StringName

var trigger_id: StringName:
	get:
		return _trigger_id
var cause: int:
	get:
		return _cause
var requested_mode: int:
	get:
		return _requested_mode
var initiator_id: StringName:
	get:
		return _initiator_id
var source_location: WorldLocationState:
	get:
		return null if _source_location == null else _source_location.duplicate_snapshot()
var authored_policy_id: StringName:
	get:
		return _authored_policy_id


func _init(
	p_trigger_id: StringName = &"",
	p_cause: int = -1,
	p_requested_mode: int = -1,
	p_initiator_id: StringName = &"",
	p_candidates: Array[CombatTriggerCandidate] = [],
	p_source_location: WorldLocationState = null,
	p_authored_policy_id: StringName = &"",
) -> void:
	_trigger_id = p_trigger_id
	_cause = p_cause
	_requested_mode = p_requested_mode
	_initiator_id = p_initiator_id
	for candidate: CombatTriggerCandidate in p_candidates:
		_candidates.append(
			null if candidate == null else candidate.duplicate_snapshot()
		)
	_source_location = (
		null if p_source_location == null else p_source_location.duplicate_snapshot()
	)
	_authored_policy_id = p_authored_policy_id


func is_valid() -> bool:
	if (
		_trigger_id.is_empty()
		or not CombatTriggerCause.is_valid(_cause)
		or not CombatEncounterMode.is_valid(_requested_mode)
		or _initiator_id.is_empty()
		or _source_location == null
		or not _source_location.is_valid()
		or (_requested_mode == CombatEncounterMode.Value.SCRIPTED and _authored_policy_id.is_empty())
	):
		return false
	var ids: Array[StringName] = []
	var initiator_found: bool = false
	for candidate: CombatTriggerCandidate in _candidates:
		if candidate == null or not candidate.is_valid() or ids.has(candidate.participant_id):
			return false
		ids.append(candidate.participant_id)
		initiator_found = initiator_found or candidate.participant_id == _initiator_id
	return initiator_found


func candidates() -> Array[CombatTriggerCandidate]:
	var result: Array[CombatTriggerCandidate] = []
	for candidate: CombatTriggerCandidate in _candidates:
		result.append(null if candidate == null else candidate.duplicate_snapshot())
	return result


func candidate_for(participant_id: StringName) -> CombatTriggerCandidate:
	for candidate: CombatTriggerCandidate in _candidates:
		if candidate != null and candidate.participant_id == participant_id:
			return candidate.duplicate_snapshot()
	return null


func duplicate_snapshot() -> CombatTrigger:
	return CombatTrigger.new(
		_trigger_id,
		_cause,
		_requested_mode,
		_initiator_id,
		candidates(),
		_source_location,
		_authored_policy_id,
	)
