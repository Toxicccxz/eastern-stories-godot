class_name CombatEncounterCoordinator
extends RefCounted

const ENCOUNTER_ID_PREFIX: String = "encounter:"

var _session: OldPineWorldSessionController
var _world_gate: WorldSimulationGate
var _active_encounter: CombatEncounter
var _active_scheduler: CombatEncounterScheduler
var _tactical_registry := CombatTacticalActionRegistry.new()


## Content/test composition before encounter start; no production policies yet.
func register_tactical_policy(policy: CombatTacticalActionPolicy) -> bool:
	return not has_active_encounter() and _tactical_registry.register_policy(policy)


func action_infos() -> Array[CombatTacticalActionInfo]:
	return _tactical_registry.action_infos()


func submit_player_action(request: CombatTacticalRequest) -> CombatTacticalResult:
	if _active_scheduler == null or _active_scheduler.player_tactics() == null:
		return CombatTacticalResult.new()
	return _active_scheduler.player_tactics().submit(
		request, _session.application_gameplay_allows_encounter_advance(),
		_world_gate.freeze_owner_id(), _session.encounter_combat_bindings(_active_encounter),
	)


func cancel_player_action(expected_request_id: StringName) -> CombatTacticalResult:
	if _active_scheduler == null or _active_scheduler.player_tactics() == null:
		return CombatTacticalResult.new()
	return _active_scheduler.player_tactics().cancel(
		expected_request_id, _session.application_gameplay_allows_encounter_advance(),
		_world_gate.freeze_owner_id(),
	)


func _init(
	p_session: OldPineWorldSessionController = null,
	p_world_gate: WorldSimulationGate = null,
) -> void:
	_session = p_session
	_world_gate = p_world_gate


func is_valid() -> bool:
	return _session != null and _world_gate != null


func has_active_encounter() -> bool:
	return _active_encounter != null


func active_encounter() -> CombatEncounter:
	return _active_encounter


func active_scheduler() -> CombatEncounterScheduler:
	return _active_scheduler


func advance_scheduler(delta_seconds: float) -> CombatSchedulerAdvanceResult:
	if _active_encounter == null or _active_scheduler == null or not is_valid():
		return CombatSchedulerAdvanceResult.new()
	return _active_scheduler.advance(
		delta_seconds,
		_session.application_gameplay_allows_encounter_advance(),
		_world_gate.freeze_owner_id(),
		_session.encounter_combat_bindings(_active_encounter),
		_session.combat_random_source(),
		_session.encounter_skill_effect_registry(),
	)


func start(trigger: CombatTrigger) -> CombatEncounterStartResult:
	if trigger == null or not trigger.is_valid():
		return CombatEncounterStartResult.new()
	if trigger.cause != CombatTriggerCause.Value.SCRIPTED:
		return _start_failure(CombatEncounterStartResult.Outcome.UNSUPPORTED_CAUSE, trigger)
	if trigger.requested_mode != CombatEncounterMode.Value.SCRIPTED:
		return _start_failure(CombatEncounterStartResult.Outcome.UNSUPPORTED_MODE, trigger)
	if not is_valid() or not _session.is_initialized():
		return _start_failure(CombatEncounterStartResult.Outcome.SESSION_NOT_READY, trigger)
	if trigger.source_location.map_id != _session.active_map_id():
		return _start_failure(CombatEncounterStartResult.Outcome.LOCATION_MISMATCH, trigger)
	if has_active_encounter() or not _world_gate.is_open():
		return _start_failure(
			CombatEncounterStartResult.Outcome.ENCOUNTER_ALREADY_ACTIVE,
			trigger,
		)

	var participants: Array[CombatParticipant] = []
	for candidate: CombatTriggerCandidate in trigger.candidates():
		var binding: CombatEncounterAuthorityBinding = (
			_session.resolve_encounter_binding(candidate.participant_id)
		)
		var location: WorldLocationState = (
			_session.resolve_encounter_location(candidate.participant_id)
		)
		if binding == null or location == null:
			return _start_failure(
				CombatEncounterStartResult.Outcome.PARTICIPANT_NOT_FOUND,
				trigger,
			)
		if not _session.encounter_participant_is_available(candidate.participant_id):
			return _start_failure(
				CombatEncounterStartResult.Outcome.PARTICIPANT_UNAVAILABLE,
				trigger,
			)
		if not _location_matches_trigger(trigger, candidate, location):
			return _start_failure(
				CombatEncounterStartResult.Outcome.LOCATION_MISMATCH,
				trigger,
			)
		participants.append(
			CombatParticipant.new(candidate.participant_id, candidate.side_id, binding)
		)

	var hostilities: Array[CombatDirectedHostility] = _derive_hostilities(
		participants
	)
	if participants.size() < 2 or hostilities.is_empty():
		return _start_failure(
			CombatEncounterStartResult.Outcome.RELATIONSHIP_TOPOLOGY_MISSING,
			trigger,
		)
	var encounter_id := StringName(ENCOUNTER_ID_PREFIX + String(trigger.trigger_id))
	var encounter := CombatEncounter.new(encounter_id, trigger, participants, hostilities)
	if not encounter.is_valid() or not encounter.activate():
		return _start_failure(
			CombatEncounterStartResult.Outcome.ENCOUNTER_INVALID,
			trigger,
		)
	var scheduler := CombatEncounterScheduler.new(
		encounter,
		CombatSchedulerConfig.new(
			_session.encounter_opportunity_interval_seconds()
		),
	)
	if not scheduler.is_valid():
		return _start_failure(
			CombatEncounterStartResult.Outcome.SCHEDULER_PREPARATION_FAILED,
			trigger,
		)
	## NPC-only scripted encounters retain CXR3 behavior, with no player queue API.
	if encounter.participant_for(_session.player_runtime().character_id) != null:
		scheduler.configure_player_tactics(_session.player_runtime().character_id, _tactical_registry)
	if not _world_gate.acquire(encounter_id):
		return _start_failure(
			CombatEncounterStartResult.Outcome.WORLD_FREEZE_FAILED,
			trigger,
		)
	if not _session.freeze_world_for_encounter(encounter_id):
		_world_gate.release(encounter_id)
		return _start_failure(
			CombatEncounterStartResult.Outcome.WORLD_FREEZE_FAILED,
			trigger,
		)
	_active_encounter = encounter
	_active_scheduler = scheduler
	return CombatEncounterStartResult.new(
		CombatEncounterStartResult.Outcome.STARTED,
		trigger.trigger_id,
		encounter_id,
	)


func complete(result: CombatEncounterResult) -> CombatEncounterCompletionResult:
	if _active_encounter == null:
		return CombatEncounterCompletionResult.new()
	var encounter_id: StringName = _active_encounter.encounter_id
	if (
		result == null
		or not result.is_valid()
		or result.encounter_id != encounter_id
		or result.mode != _active_encounter.mode
	):
		return CombatEncounterCompletionResult.new(
			CombatEncounterCompletionResult.Outcome.INVALID_RESULT,
			encounter_id,
		)
	if not _result_is_allowed_for_mode(result):
		return CombatEncounterCompletionResult.new(
			CombatEncounterCompletionResult.Outcome.RESULT_NOT_ALLOWED_FOR_MODE,
			encounter_id,
		)
	var queued: CombatQueuedAction = _active_encounter.queued_player_action()
	if not _active_encounter.begin_resolving():
		return CombatEncounterCompletionResult.new(
			CombatEncounterCompletionResult.Outcome.RESOLVING_TRANSITION_FAILED,
			encounter_id,
		)
	if _active_scheduler != null and _active_scheduler.player_tactics() != null:
		_active_scheduler.player_tactics().report_completion_cancellation(queued)
	if not _active_encounter.complete(result):
		return CombatEncounterCompletionResult.new(
			CombatEncounterCompletionResult.Outcome.COMPLETION_TRANSITION_FAILED,
			encounter_id,
		)
	if not _session.thaw_world_after_encounter(encounter_id):
		return CombatEncounterCompletionResult.new(
			CombatEncounterCompletionResult.Outcome.WORLD_THAW_FAILED,
			encounter_id,
			result,
		)
	_active_scheduler = null
	_active_encounter = null
	if not _world_gate.release(encounter_id):
		return CombatEncounterCompletionResult.new(
			CombatEncounterCompletionResult.Outcome.WORLD_THAW_FAILED,
			encounter_id,
			result,
		)
	var completed_result := CombatEncounterCompletionResult.new(
		CombatEncounterCompletionResult.Outcome.COMPLETED,
		encounter_id,
		result,
	)
	return completed_result


func _location_matches_trigger(
	trigger: CombatTrigger,
	candidate: CombatTriggerCandidate,
	location: WorldLocationState,
) -> bool:
	var source: WorldLocationState = trigger.source_location
	if candidate.participant_id == trigger.initiator_id:
		return location.same_location(source)
	return (
		location.region_id == source.region_id
		and location.map_id == source.map_id
		and location.shares_combat_location(source)
	)


func _derive_hostilities(
	participants: Array[CombatParticipant],
) -> Array[CombatDirectedHostility]:
	var result: Array[CombatDirectedHostility] = []
	for actor: CombatParticipant in participants:
		for target: CombatParticipant in participants:
			if (
				actor.participant_id == target.participant_id
				or actor.side_id == target.side_id
				or not actor.binding.relationship.has_opponent(target.participant_id)
			):
				continue
			var hostility := CombatDirectedHostility.new(actor.side_id, target.side_id)
			var duplicate: bool = false
			for observed: CombatDirectedHostility in result:
				duplicate = duplicate or observed.same_direction(hostility)
			if not duplicate:
				result.append(hostility)
	return result


func _result_is_allowed_for_mode(result: CombatEncounterResult) -> bool:
	match result.mode:
		CombatEncounterMode.Value.SCRIPTED:
			return result.kind == CombatEncounterResultKind.Value.SCRIPTED
		CombatEncounterMode.Value.SPAR:
			return result.kind in [
				CombatEncounterResultKind.Value.SPAR_CONCLUDED,
				CombatEncounterResultKind.Value.FLED,
			]
		CombatEncounterMode.Value.LETHAL:
			return result.kind in [
				CombatEncounterResultKind.Value.VICTORY,
				CombatEncounterResultKind.Value.DEFEAT,
				CombatEncounterResultKind.Value.FLED,
			]
	return false


func _start_failure(outcome: int, trigger: CombatTrigger) -> CombatEncounterStartResult:
	return CombatEncounterStartResult.new(
		outcome,
		&"" if trigger == null else trigger.trigger_id,
	)
