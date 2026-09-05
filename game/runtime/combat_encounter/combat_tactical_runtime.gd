class_name CombatTacticalRuntime
extends RefCounted

const Code := CombatTacticalResult.Code
const Kind := CombatTacticalEvent.Kind
const Target := CombatTacticalRequest.TargetRule

var _encounter: CombatEncounter
var _player_id: StringName
var _registry: CombatTacticalActionRegistry
var _order: CombatProgressionOrder
var _next_request_sequence: int = 1
## Correlation tombstones, NOT pending actions. Includes rejected/replaced/executed IDs.
var _seen_request_ids: Array[StringName] = []
var _events: Array[CombatTacticalEvent] = []


func _init(
	p_encounter: CombatEncounter,
	p_player_id: StringName,
	p_registry: CombatTacticalActionRegistry,
	p_order: CombatProgressionOrder,
) -> void:
	_encounter = p_encounter
	_player_id = p_player_id
	_registry = p_registry
	_order = p_order


func events() -> Array[CombatTacticalEvent]:
	var result: Array[CombatTacticalEvent] = []
	for event: CombatTacticalEvent in _events:
		result.append(event.duplicate_snapshot())
	return result


## Incremental defensive read: walks only the new suffix, never clones old history.
func events_after(progression_order: int) -> Array[CombatTacticalEvent]:
	var result: Array[CombatTacticalEvent] = []
	for index: int in range(_events.size() - 1, -1, -1):
		var event: CombatTacticalEvent = _events[index]
		if event.progression_order <= progression_order:
			break
		result.append(event.duplicate_snapshot())
	result.reverse()
	return result


func queue_status() -> int:
	var action: CombatQueuedAction = _encounter.queued_player_action()
	if action == null:
		return CombatQueuedAction.Status.EMPTY
	var policy: CombatTacticalActionPolicy = _registry.find(action.request.action_id)
	var actor: CombatParticipant = _encounter.participant_for(action.request.actor_id)
	if policy != null and actor != null and policy.blocks_when_busy and actor.binding.busy.is_busy():
		return CombatQueuedAction.Status.WAITING_FOR_BUSY
	return CombatQueuedAction.Status.READY


func submit(
	request: CombatTacticalRequest,
	application_active: bool,
	gate_owner: StringName,
	bindings: Array[CombatSliceCharacterBinding],
) -> CombatTacticalResult:
	if request == null or not request.is_valid():
		return CombatTacticalResult.new(Code.INVALID_REQUEST)
	if _seen_request_ids.has(request.request_id):
		return CombatTacticalResult.new(Code.DUPLICATE_REQUEST)
	if _next_request_sequence == 9223372036854775807:
		return CombatTacticalResult.new(Code.SEQUENCE_EXHAUSTED)
	var sequence: int = _next_request_sequence
	_next_request_sequence += 1
	_seen_request_ids.append(request.request_id)
	var action := CombatQueuedAction.new(request, sequence, request.target_id)
	_emit(Kind.REQUESTED, action)
	var code: int = _base_validation(action, application_active, gate_owner, bindings)
	var policy: CombatTacticalActionPolicy = _registry.find(request.action_id)
	if code == Code.ACCEPTED:
		var target_id: StringName = request.target_id
		match policy.target_rule:
			Target.NONE:
				if not target_id.is_empty():
					code = Code.TARGET_INVALID
			Target.SELF:
				if not target_id.is_empty() and target_id != request.actor_id:
					code = Code.TARGET_INVALID
				target_id = request.actor_id
			Target.CURRENT_HOSTILE:
				var current: StringName = _encounter.current_target_for(request.actor_id)
				if not target_id.is_empty() and target_id != current:
					code = Code.TARGET_INVALID
				target_id = current
		action = CombatQueuedAction.new(request, sequence, target_id)
	if code == Code.ACCEPTED:
		code = _target_validation(action, policy, bindings)
	if code == Code.ACCEPTED:
		code = policy.validate_request(_context(action))
	if code != Code.ACCEPTED:
		_emit(Kind.REJECTED, action, code)
		return CombatTacticalResult.new(code, sequence)
	var previous: CombatQueuedAction = _encounter.queued_player_action()
	if not _encounter.replace_queued_player_action(action):
		_emit(Kind.REJECTED, action, Code.INACTIVE)
		return CombatTacticalResult.new(Code.INACTIVE, sequence)
	if previous != null:
		_events.append(CombatTacticalEvent.new(
			_order.take(), Kind.REPLACED, previous, Code.ACCEPTED, null,
			request.request_id, sequence,
		))
	_emit(Kind.ACCEPTED, action)
	_emit(Kind.QUEUED, action)
	return CombatTacticalResult.new(Code.ACCEPTED, sequence)


func cancel(
	expected_request_id: StringName,
	application_active: bool,
	gate_owner: StringName,
) -> CombatTacticalResult:
	if _encounter.phase != CombatEncounterLifecycle.Value.ACTIVE:
		return CombatTacticalResult.new(Code.INACTIVE)
	if not application_active:
		return CombatTacticalResult.new(Code.APPLICATION_BLOCKED)
	if gate_owner != _encounter.encounter_id:
		return CombatTacticalResult.new(Code.WORLD_GATE_MISMATCH)
	var action: CombatQueuedAction = _encounter.queued_player_action()
	if action == null or not _encounter.clear_queued_player_action(expected_request_id):
		return CombatTacticalResult.new(Code.STALE_CANCEL)
	_emit(Kind.CANCELLED, action, Code.CANCELLED)
	return CombatTacticalResult.new(Code.CANCELLED, action.sequence)


## Only the scheduler calls this, after its foreground/gate/delta/authority gates
## and BEFORE advancing ordinary cycles. One snapshot, at most one attempt.
func process_command_boundary(
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
) -> void:
	var action: CombatQueuedAction = _encounter.queued_player_action()
	if action == null:
		return
	var code: int = _base_validation(action, true, _encounter.encounter_id, bindings)
	var policy: CombatTacticalActionPolicy = _registry.find(action.request.action_id)
	if code == Code.ACCEPTED and policy.blocks_when_busy and _context(action).actor.busy.is_busy():
		return
	if code == Code.ACCEPTED:
		code = _target_validation(action, policy, bindings)
	if code == Code.ACCEPTED:
		code = policy.validate_execution(_context(action))
	if code != Code.ACCEPTED:
		_encounter.clear_queued_player_action(action.request.request_id)
		_emit(Kind.EXECUTION_REJECTED, action, code)
		_emit(Kind.CANCELLED, action, code)
		return
	## Consume BEFORE execution: a failed attempt has no implicit retry/rollback.
	if not _encounter.clear_queued_player_action(action.request.request_id):
		return
	_emit(Kind.EXECUTION_STARTED, action)
	var result: CombatTacticalExecutionResult = policy.execute(_context(action), random_source)
	if result == null:
		result = CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.FAILED)
	_emit(Kind.RESOLVED, action, Code.ACCEPTED, result)


## Coordinator invokes only after its valid resolving transition cleared the slot.
func report_completion_cancellation(action: CombatQueuedAction) -> void:
	if action != null:
		_emit(Kind.CANCELLED, action, Code.INACTIVE)


func _base_validation(
	action: CombatQueuedAction,
	application_active: bool,
	gate_owner: StringName,
	bindings: Array[CombatSliceCharacterBinding],
) -> int:
	var request: CombatTacticalRequest = action.request
	if (_encounter.phase != CombatEncounterLifecycle.Value.ACTIVE
		or request.encounter_id != _encounter.encounter_id):
		return Code.INACTIVE
	if not application_active:
		return Code.APPLICATION_BLOCKED
	if gate_owner != _encounter.encounter_id:
		return Code.WORLD_GATE_MISMATCH
	if request.actor_id != _player_id:
		return Code.NOT_PLAYER
	var actor: CombatSliceCharacterBinding = _find(bindings, request.actor_id)
	if not _exact_authority(actor):
		return Code.AUTHORITY_INVALID
	if not _available(actor):
		return Code.ACTOR_UNAVAILABLE
	var policy: CombatTacticalActionPolicy = _registry.find(request.action_id)
	if policy == null or not policy.is_valid():
		return Code.UNKNOWN_ACTION
	if policy.category != request.category:
		return Code.CATEGORY_MISMATCH
	return Code.ACCEPTED


func _target_validation(
	action: CombatQueuedAction,
	policy: CombatTacticalActionPolicy,
	bindings: Array[CombatSliceCharacterBinding],
) -> int:
	if policy.target_rule == Target.NONE:
		return Code.ACCEPTED if action.resolved_target_id.is_empty() else Code.TARGET_INVALID
	var target: CombatSliceCharacterBinding = _find(bindings, action.resolved_target_id)
	if not _exact_authority(target) or not _available(target):
		return Code.TARGET_INVALID
	var actor: CombatSliceCharacterBinding = _find(bindings, action.request.actor_id)
	if policy.target_rule == Target.SELF:
		return Code.ACCEPTED if target.character_id == actor.character_id else Code.TARGET_INVALID
	if (
		target.location_id != actor.location_id
		or not _encounter.is_hostile(actor.character_id, target.character_id)
		or not actor.relationship.has_opponent(target.character_id)
	):
		return Code.TARGET_INVALID
	return Code.ACCEPTED


func _exact_authority(binding: CombatSliceCharacterBinding) -> bool:
	if binding == null or not binding.is_valid():
		return false
	var participant: CombatParticipant = _encounter.participant_for(binding.character_id)
	return participant != null and (
		binding.state == participant.binding.state
		and binding.relationship == participant.binding.relationship
		and binding.busy == participant.binding.busy
		and binding.armor == participant.binding.armor
	)


func _available(binding: CombatSliceCharacterBinding) -> bool:
	return (
		binding.exists_in_encounter and binding.combat_available
		and binding.life_status == CombatSliceLifeStatus.Value.ACTIVE
	)


func _context(action: CombatQueuedAction) -> CombatTacticalContext:
	var target: CombatParticipant = _encounter.participant_for(action.resolved_target_id)
	return CombatTacticalContext.new(
		_encounter.participant_for(action.request.actor_id).binding,
		null if target == null else target.binding,
	)


func _find(bindings: Array[CombatSliceCharacterBinding], id: StringName) -> CombatSliceCharacterBinding:
	for binding: CombatSliceCharacterBinding in bindings:
		if binding != null and binding.character_id == id:
			return binding
	return null


func _emit(
	kind: int,
	action: CombatQueuedAction,
	reason: int = Code.ACCEPTED,
	execution: CombatTacticalExecutionResult = null,
) -> void:
	_events.append(CombatTacticalEvent.new(_order.take(), kind, action, reason, execution))
