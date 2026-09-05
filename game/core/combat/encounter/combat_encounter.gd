class_name CombatEncounter
extends RefCounted

var _encounter_id: StringName
var _trigger: CombatTrigger
var _phase: int = CombatEncounterLifecycle.Value.ESTABLISHING
var _participants: Array[CombatParticipant] = []
var _hostilities: Array[CombatDirectedHostility] = []
var _targets: Array[CombatTargetAssignment] = []
var _events: Array[CombatEncounterEvent] = []
var _terminal_result: CombatEncounterResult
var _next_event_sequence: int = 1
var _queued_player_action: CombatQueuedAction

var encounter_id: StringName:
	get:
		return _encounter_id
var mode: int:
	get:
		return -1 if _trigger == null else _trigger.requested_mode
var phase: int:
	get:
		return _phase
var terminal_result: CombatEncounterResult:
	get:
		return (
			null
			if _terminal_result == null
			else _terminal_result.duplicate_snapshot()
		)


func _init(
	p_encounter_id: StringName = &"",
	p_trigger: CombatTrigger = null,
	p_participants: Array[CombatParticipant] = [],
	p_hostilities: Array[CombatDirectedHostility] = [],
) -> void:
	_encounter_id = p_encounter_id
	_trigger = null if p_trigger == null else p_trigger.duplicate_snapshot()
	for participant: CombatParticipant in p_participants:
		_participants.append(
			null if participant == null else participant.duplicate_reference()
		)
	for hostility: CombatDirectedHostility in p_hostilities:
		_hostilities.append(
			null if hostility == null else hostility.duplicate_snapshot()
		)


func is_valid() -> bool:
	return (
		_base_inputs_are_valid()
		and CombatEncounterLifecycle.is_valid(_phase)
		and _targets_are_valid()
		and _result_matches_phase()
		and _events_are_valid()
		and _queue_is_valid()
	)


func queued_player_action() -> CombatQueuedAction:
	return (
		null if _queued_player_action == null
		else _queued_player_action.duplicate_snapshot()
	)


func replace_queued_player_action(action: CombatQueuedAction) -> bool:
	if (
		_phase != CombatEncounterLifecycle.Value.ACTIVE
		or action == null or not action.is_valid()
		or action.request.encounter_id != _encounter_id
		or _participant_internal(action.request.actor_id) == null
		or (not action.resolved_target_id.is_empty()
			and _participant_internal(action.resolved_target_id) == null)
	):
		return false
	_queued_player_action = action.duplicate_snapshot()
	return true


func clear_queued_player_action(expected_request_id: StringName) -> bool:
	if (
		_queued_player_action == null
		or _queued_player_action.request.request_id != expected_request_id
	):
		return false
	_queued_player_action = null
	return true


func _queue_is_valid() -> bool:
	return _queued_player_action == null or (
		_phase == CombatEncounterLifecycle.Value.ACTIVE
		and _queued_player_action.is_valid()
		and _queued_player_action.request.encounter_id == _encounter_id
		and _participant_internal(_queued_player_action.request.actor_id) != null
	)


func accepted_trigger() -> CombatTrigger:
	return null if _trigger == null else _trigger.duplicate_snapshot()


func participants() -> Array[CombatParticipant]:
	var result: Array[CombatParticipant] = []
	for participant: CombatParticipant in _participants:
		result.append(
			null if participant == null else participant.duplicate_reference()
		)
	return result


func participant_for(participant_id: StringName) -> CombatParticipant:
	var participant: CombatParticipant = _participant_internal(participant_id)
	return null if participant == null else participant.duplicate_reference()


func side_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for participant: CombatParticipant in _participants:
		if participant != null and not result.has(participant.side_id):
			result.append(participant.side_id)
	return result


func hostilities() -> Array[CombatDirectedHostility]:
	var result: Array[CombatDirectedHostility] = []
	for hostility: CombatDirectedHostility in _hostilities:
		result.append(null if hostility == null else hostility.duplicate_snapshot())
	return result


func has_directed_hostility(from_side_id: StringName, to_side_id: StringName) -> bool:
	for hostility: CombatDirectedHostility in _hostilities:
		if (
			hostility != null
			and hostility.from_side_id == from_side_id
			and hostility.to_side_id == to_side_id
		):
			return true
	return false


func is_hostile(actor_id: StringName, target_id: StringName) -> bool:
	var actor: CombatParticipant = _participant_internal(actor_id)
	var target: CombatParticipant = _participant_internal(target_id)
	return (
		actor != null
		and target != null
		and actor_id != target_id
		and has_directed_hostility(actor.side_id, target.side_id)
	)


func current_target_for(actor_id: StringName) -> StringName:
	var index: int = _target_index(actor_id)
	return &"" if index < 0 else _targets[index].target_id


func target_assignments() -> Array[CombatTargetAssignment]:
	var result: Array[CombatTargetAssignment] = []
	for assignment: CombatTargetAssignment in _targets:
		result.append(assignment.duplicate_snapshot())
	return result


func events() -> Array[CombatEncounterEvent]:
	var result: Array[CombatEncounterEvent] = []
	for event: CombatEncounterEvent in _events:
		result.append(event.duplicate_snapshot())
	return result


func activate() -> bool:
	if not is_valid() or _phase != CombatEncounterLifecycle.Value.ESTABLISHING:
		return false
	var event: CombatEncounterEvent = CombatEncounterEvent.established(
		_encounter_id,
		_next_event_sequence,
	)
	if not event.is_valid():
		return false
	_phase = CombatEncounterLifecycle.Value.ACTIVE
	_append_event(event)
	return true


func set_current_target(actor_id: StringName, target_id: StringName) -> bool:
	if not is_valid() or _phase != CombatEncounterLifecycle.Value.ACTIVE:
		return false
	if not is_hostile(actor_id, target_id):
		return false
	var replacement: CombatTargetAssignment = CombatTargetAssignment.new(actor_id, target_id)
	if not replacement.is_valid():
		return false
	var index: int = _target_index(actor_id)
	var previous_target_id: StringName = &"" if index < 0 else _targets[index].target_id
	if previous_target_id == target_id:
		return false
	var event: CombatEncounterEvent = CombatEncounterEvent.target_changed(
		_encounter_id,
		_next_event_sequence,
		actor_id,
		previous_target_id,
		target_id,
	)
	if not event.is_valid():
		return false
	if index < 0:
		_targets.append(replacement)
	else:
		_targets[index] = replacement
	_append_event(event)
	return true


func clear_current_target(actor_id: StringName) -> bool:
	if not is_valid() or _phase != CombatEncounterLifecycle.Value.ACTIVE:
		return false
	var index: int = _target_index(actor_id)
	if index < 0:
		return false
	var previous_target_id: StringName = _targets[index].target_id
	var event: CombatEncounterEvent = CombatEncounterEvent.target_changed(
		_encounter_id,
		_next_event_sequence,
		actor_id,
		previous_target_id,
		&"",
	)
	if not event.is_valid():
		return false
	_targets.remove_at(index)
	_append_event(event)
	return true


func begin_resolving() -> bool:
	if not is_valid() or _phase != CombatEncounterLifecycle.Value.ACTIVE:
		return false
	var event: CombatEncounterEvent = CombatEncounterEvent.phase_changed(
		_encounter_id,
		_next_event_sequence,
		CombatEncounterLifecycle.Value.ACTIVE,
		CombatEncounterLifecycle.Value.RESOLVING,
	)
	if not event.is_valid():
		return false
	_phase = CombatEncounterLifecycle.Value.RESOLVING
	_queued_player_action = null
	_append_event(event)
	return true


func complete(result: CombatEncounterResult) -> bool:
	if (
		not is_valid()
		or _phase != CombatEncounterLifecycle.Value.RESOLVING
		or not _result_is_acceptable(result)
		or result.kind == CombatEncounterResultKind.Value.FAILED_TO_ESTABLISH
	):
		return false
	var event: CombatEncounterEvent = CombatEncounterEvent.completed(
		_encounter_id,
		_next_event_sequence,
		result,
	)
	if not event.is_valid():
		return false
	_terminal_result = result.duplicate_snapshot()
	_phase = CombatEncounterLifecycle.Value.COMPLETED
	_append_event(event)
	return true


func fail_to_establish(result: CombatEncounterResult) -> bool:
	if (
		not is_valid()
		or _phase != CombatEncounterLifecycle.Value.ESTABLISHING
		or not _result_is_acceptable(result)
		or result.kind != CombatEncounterResultKind.Value.FAILED_TO_ESTABLISH
	):
		return false
	var event: CombatEncounterEvent = CombatEncounterEvent.failed_to_establish(
		_encounter_id,
		_next_event_sequence,
		result,
	)
	if not event.is_valid():
		return false
	_terminal_result = result.duplicate_snapshot()
	_phase = CombatEncounterLifecycle.Value.FAILED_TO_ESTABLISH
	_append_event(event)
	return true


func _base_inputs_are_valid() -> bool:
	if _encounter_id.is_empty() or _trigger == null or not _trigger.is_valid():
		return false
	var participant_ids: Array[StringName] = []
	var initiator_found: bool = false
	for participant: CombatParticipant in _participants:
		if (
			participant == null
			or not participant.is_valid()
			or participant_ids.has(participant.participant_id)
		):
			return false
		var candidate: CombatTriggerCandidate = _trigger.candidate_for(
			participant.participant_id
		)
		if candidate == null or candidate.side_id != participant.side_id:
			return false
		participant_ids.append(participant.participant_id)
		initiator_found = initiator_found or participant.participant_id == _trigger.initiator_id
	if not initiator_found:
		return false
	var observed_hostilities: Array[CombatDirectedHostility] = []
	var valid_sides: Array[StringName] = side_ids()
	for hostility: CombatDirectedHostility in _hostilities:
		if (
			hostility == null
			or not hostility.is_valid()
			or not valid_sides.has(hostility.from_side_id)
			or not valid_sides.has(hostility.to_side_id)
		):
			return false
		for observed: CombatDirectedHostility in observed_hostilities:
			if hostility.same_direction(observed):
				return false
		observed_hostilities.append(hostility)
	return true


func _targets_are_valid() -> bool:
	var actor_ids: Array[StringName] = []
	for assignment: CombatTargetAssignment in _targets:
		if (
			assignment == null
			or not assignment.is_valid()
			or actor_ids.has(assignment.actor_id)
			or not is_hostile(assignment.actor_id, assignment.target_id)
		):
			return false
		actor_ids.append(assignment.actor_id)
	return true


func _result_matches_phase() -> bool:
	if CombatEncounterLifecycle.is_terminal(_phase):
		if not _result_is_acceptable(_terminal_result):
			return false
		return (
			(_phase == CombatEncounterLifecycle.Value.FAILED_TO_ESTABLISH)
			== (
				_terminal_result.kind
				== CombatEncounterResultKind.Value.FAILED_TO_ESTABLISH
			)
		)
	return _terminal_result == null


func _result_is_acceptable(result: CombatEncounterResult) -> bool:
	if (
		result == null
		or not result.is_valid()
		or result.encounter_id != _encounter_id
		or result.mode != mode
	):
		return false
	var valid_sides: Array[StringName] = side_ids()
	for side_id: StringName in result.winning_side_ids():
		if not valid_sides.has(side_id):
			return false
	for side_id: StringName in result.losing_side_ids():
		if not valid_sides.has(side_id):
			return false
	for participant_id: StringName in result.subject_participant_ids():
		if _participant_internal(participant_id) == null:
			return false
	return true


func _events_are_valid() -> bool:
	var expected_sequence: int = 1
	for event: CombatEncounterEvent in _events:
		if (
			event == null
			or not event.is_valid()
			or event.encounter_id != _encounter_id
			or event.sequence != expected_sequence
		):
			return false
		expected_sequence += 1
	if expected_sequence != _next_event_sequence:
		return false
	match _phase:
		CombatEncounterLifecycle.Value.ESTABLISHING:
			return _events.is_empty()
		CombatEncounterLifecycle.Value.ACTIVE:
			return (
				not _events.is_empty()
				and _events[0].kind
				== CombatEncounterEventKind.Value.ENCOUNTER_ESTABLISHED
			)
		CombatEncounterLifecycle.Value.RESOLVING:
			return (
				not _events.is_empty()
				and _events[-1].kind == CombatEncounterEventKind.Value.PHASE_CHANGED
				and _events[-1].current_phase == CombatEncounterLifecycle.Value.RESOLVING
			)
		CombatEncounterLifecycle.Value.COMPLETED:
			return (
				not _events.is_empty()
				and _events[-1].kind
				== CombatEncounterEventKind.Value.ENCOUNTER_COMPLETED
			)
		CombatEncounterLifecycle.Value.FAILED_TO_ESTABLISH:
			return (
				not _events.is_empty()
				and _events[-1].kind
				== CombatEncounterEventKind.Value.ENCOUNTER_FAILED_TO_ESTABLISH
			)
	return false


func _participant_internal(participant_id: StringName) -> CombatParticipant:
	if participant_id.is_empty():
		return null
	for participant: CombatParticipant in _participants:
		if participant != null and participant.participant_id == participant_id:
			return participant
	return null


func _target_index(actor_id: StringName) -> int:
	for index: int in range(_targets.size()):
		if _targets[index].actor_id == actor_id:
			return index
	return -1


func _append_event(event: CombatEncounterEvent) -> void:
	_events.append(event.duplicate_snapshot())
	_next_event_sequence += 1
