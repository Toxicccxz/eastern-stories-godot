class_name CombatEncounterCoordinator
extends RefCounted

const ENCOUNTER_ID_PREFIX: String = "encounter:"

var _session: OldPineWorldSessionController
var _world_gate: WorldSimulationGate
var _active_encounter: CombatEncounter
var _active_scheduler: CombatEncounterScheduler
var _tactical_registry := CombatTacticalActionRegistry.new()
var _resolution: CombatEncounterResolution
var _last_completion: CombatEncounterCompletionResult
var _entry_sequence: int = 0

func resolution() -> CombatEncounterResolution:
	return _resolution

func last_completion() -> CombatEncounterCompletionResult:
	return _last_completion

## One synchronous production-entry transaction. Reuses the audited playable
## relationship establishment; rollback restores order and preexisting facts.
func start_production(initiator: CombatSliceCharacterBinding, target: CombatSliceCharacterBinding, cause: int) -> CombatSliceInitiationResult:
	if not is_valid() or not _session.application_gameplay_allows_encounter_advance() or has_active_encounter() or not _world_gate.is_open():
		return CombatSliceInitiationResult.new()
	if initiator == null or target == null or not _session.encounter_participant_is_available(initiator.character_id) or not _session.encounter_participant_is_available(target.character_id):
		return CombatSliceInitiationResult.new()
	if cause not in [CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK, CombatTriggerCause.Value.NPC_AGGRESSION] or _entry_sequence == 9223372036854775807:
		return CombatSliceInitiationResult.new()
	for binding: CombatSliceCharacterBinding in [initiator, target]:
		var current: CombatEncounterAuthorityBinding = _session.resolve_encounter_binding(binding.character_id)
		if current == null or binding.state != current.state or binding.relationship != current.relationship or binding.busy != current.busy or binding.armor != current.armor:
			return CombatSliceInitiationResult.new()
		# This bounded production entry composes a pair, never discards an existing
		# third-party fight. Broader established topologies use typed start().
		for opponent_id: StringName in binding.relationship.opponent_ids():
			if opponent_id not in [initiator.character_id, target.character_id]:
				return CombatSliceInitiationResult.new()
	var first_opponents: Array[StringName] = initiator.relationship.opponent_ids()
	var first_lethal: Array[StringName] = initiator.relationship.lethal_target_ids()
	var second_opponents: Array[StringName] = target.relationship.opponent_ids()
	var second_lethal: Array[StringName] = target.relationship.lethal_target_ids()
	var receipt: CombatSliceInitiationResult = CombatSliceOpportunityExecutor.initiate_lethal_combat(initiator, target)
	if receipt.outcome == CombatSliceInitiationResult.Outcome.COMPLETED:
		_entry_sequence += 1
		var candidates: Array[CombatTriggerCandidate] = [
			CombatTriggerCandidate.new(initiator.character_id, &"initiator"),
			CombatTriggerCandidate.new(target.character_id, &"target"),
		]
		var trigger := CombatTrigger.new(StringName("production:%d" % _entry_sequence), cause,
			CombatEncounterMode.Value.LETHAL, initiator.character_id, candidates,
			_session.resolve_encounter_location(initiator.character_id))
		var started: CombatEncounterStartResult = start(trigger)
		if started.succeeded():
			return receipt
		## No completed initiation is reported when the new engine could not start.
		receipt._outcome = CombatSliceInitiationResult.Outcome.ENCOUNTER_START_FAILED
	_restore_entry_relationship(initiator.relationship, first_opponents, first_lethal)
	_restore_entry_relationship(target.relationship, second_opponents, second_lethal)
	return receipt

func _restore_entry_relationship(state: CombatRelationshipState, opponents: Array[StringName], lethal: Array[StringName]) -> void:
	for target_id: StringName in state.lethal_target_ids():
		state.remove_lethal_relation(target_id)
	state.clear_opponents_preserving_lethal_targets()
	for target_id: StringName in lethal:
		state.mark_lethal_target(target_id)
	state.clear_opponents_preserving_lethal_targets()
	for target_id: StringName in opponents:
		state.add_opponent(target_id)


## Content/test composition before encounter start; production Flee is registered below.
func register_tactical_policy(policy: CombatTacticalActionPolicy) -> bool:
	return not has_active_encounter() and _tactical_registry.register_policy(policy)


func action_infos() -> Array[CombatTacticalActionInfo]:
	var infos: Array[CombatTacticalActionInfo] = []
	for info: CombatTacticalActionInfo in _tactical_registry.action_infos():
		if _active_encounter == null or _tactical_registry.find(info.action_id).supports_mode(_active_encounter.mode):
			infos.append(info)
	return infos


func change_player_target(request: CombatTargetRequest) -> CombatTargetResult:
	if _active_encounter == null or _active_scheduler == null or not is_valid():
		return CombatTargetResult.new()
	if request == null:
		return CombatTargetResult.new(CombatTargetResult.Code.INVALID_REQUEST)
	if request.encounter_id != _active_encounter.encounter_id:
		return CombatTargetResult.new(CombatTargetResult.Code.STALE_ENCOUNTER)
	if not _target_input_allowed():
		return CombatTargetResult.new(CombatTargetResult.Code.APPLICATION_BLOCKED)
	if _world_gate.freeze_owner_id() != _active_encounter.encounter_id:
		return CombatTargetResult.new(CombatTargetResult.Code.WORLD_GATE_MISMATCH)
	if request.actor_id != _session.player_runtime().character_id or _active_encounter.participant_for(request.actor_id) == null:
		return CombatTargetResult.new(CombatTargetResult.Code.INVALID_ACTOR)
	var bindings: Array[CombatSliceCharacterBinding] = _session.encounter_combat_bindings(_active_encounter)
	if not _active_scheduler.bindings_match_encounter(bindings):
		return CombatTargetResult.new(CombatTargetResult.Code.BINDING_MISMATCH)
	if not _active_scheduler.can_target(request.actor_id, request.target_id, bindings):
		return CombatTargetResult.new(CombatTargetResult.Code.TARGET_UNAVAILABLE)
	if _active_encounter.current_target_for(request.actor_id) == request.target_id:
		return CombatTargetResult.new(CombatTargetResult.Code.UNCHANGED)
	if not _active_encounter.set_current_target(request.actor_id, request.target_id):
		return CombatTargetResult.new(CombatTargetResult.Code.TARGET_UNAVAILABLE)
	_active_scheduler.record_target_change()
	return CombatTargetResult.new(CombatTargetResult.Code.CHANGED)


## Advisory projection only. Receipt always revalidates exact current bindings.
func player_can_target(target_id: StringName) -> bool:
	if not _target_input_allowed() or _world_gate.freeze_owner_id() != _active_encounter.encounter_id:
		return false
	var bindings: Array[CombatSliceCharacterBinding] = _session.encounter_combat_bindings(_active_encounter)
	return _active_scheduler.bindings_match_encounter(bindings) and _active_scheduler.can_target(
		_session.player_runtime().character_id, target_id, bindings,
	)


func _target_input_allowed() -> bool:
	return (
		is_valid() and _active_encounter != null and _active_scheduler != null
		and _active_encounter.phase == CombatEncounterLifecycle.Value.ACTIVE
		and _session.application_gameplay_allows_encounter_advance()
	)


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
	_tactical_registry.register_policy(CombatFleeTacticalPolicy.new())


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
	# RESOLVING is a one-way barrier, including a failed world-return attempt.
	# Do not re-enter lifecycle reconciliation or completion on later frames.
	if _active_encounter.phase != CombatEncounterLifecycle.Value.ACTIVE:
		return CombatSchedulerAdvanceResult.new()
	if _resolution != null and _resolution.failure != CombatEncounterResolution.Failure.NONE:
		return CombatSchedulerAdvanceResult.new()
	var advanced: CombatSchedulerAdvanceResult = _active_scheduler.advance(
		delta_seconds,
		_session.application_gameplay_allows_encounter_advance(),
		_world_gate.freeze_owner_id(),
		_session.encounter_combat_bindings(_active_encounter),
		_session.combat_random_source(),
		_session.encounter_skill_effect_registry(),
		_resolution,
	)
	if _resolution != null:
		if _resolution.failure != CombatEncounterResolution.Failure.NONE:
			_hold_failed_resolution()
		elif _resolution.result != null:
			_resolution.reconcile_relationships()
			complete(_resolution.result)
	return advanced

func _hold_failed_resolution() -> void:
	if _active_encounter.phase == CombatEncounterLifecycle.Value.ACTIVE:
		var queued: CombatQueuedAction = _active_encounter.queued_player_action()
		_active_encounter.begin_resolving()
		if _active_scheduler.player_tactics() != null:
			_active_scheduler.player_tactics().report_completion_cancellation(queued)


func start(trigger: CombatTrigger) -> CombatEncounterStartResult:
	if trigger == null or not trigger.is_valid():
		return CombatEncounterStartResult.new()
	if trigger.cause == CombatTriggerCause.Value.QUEST:
		return _start_failure(CombatEncounterStartResult.Outcome.UNSUPPORTED_CAUSE, trigger)
	if not CombatEncounterModePolicy.supports(trigger):
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
	if not CombatEncounterModePolicy.equipment_supported(trigger, participants):
		return _start_failure(CombatEncounterStartResult.Outcome.SPAR_WEAPON_NOT_ALLOWED, trigger)
	if not CombatEncounterModePolicy.relationships_match(trigger, participants, _session.player_runtime().character_id):
		return _start_failure(CombatEncounterStartResult.Outcome.MODE_RELATIONSHIP_MISMATCH, trigger)

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
	_last_completion = null
	_resolution = null if encounter.mode == CombatEncounterMode.Value.SCRIPTED else CombatEncounterResolution.new(_session, encounter)
	return CombatEncounterStartResult.new(
		CombatEncounterStartResult.Outcome.STARTED,
		trigger.trigger_id,
		encounter_id,
	)


func complete(result: CombatEncounterResult) -> CombatEncounterCompletionResult:
	if _active_encounter == null:
		return CombatEncounterCompletionResult.new()
	# The first attempted world return owns its receipt. Even FLED cannot retry
	# a failed return or replace the already derived gameplay result.
	if _last_completion != null:
		return _last_completion
	if _resolution != null and _resolution.failure != CombatEncounterResolution.Failure.NONE:
		return CombatEncounterCompletionResult.new()
	if _resolution != null and (_resolution.result == null or result == null or result.kind != _resolution.result.kind):
		return CombatEncounterCompletionResult.new(CombatEncounterCompletionResult.Outcome.INVALID_RESULT)
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
	if not _active_encounter.accepts_completion_result(result):
		return CombatEncounterCompletionResult.new(CombatEncounterCompletionResult.Outcome.INVALID_RESULT, encounter_id)
	var queued: CombatQueuedAction = _active_encounter.queued_player_action()
	if not _active_encounter.begin_resolving():
		return CombatEncounterCompletionResult.new(
			CombatEncounterCompletionResult.Outcome.RESOLVING_TRANSITION_FAILED,
			encounter_id,
		)
	if _active_scheduler != null and _active_scheduler.player_tactics() != null:
		_active_scheduler.player_tactics().report_completion_cancellation(queued)
	# No await or deferred work: the Core stays RESOLVING throughout world return.
	# Local thaw only prepares the map; the same global gate still blocks gameplay.
	if not _session.thaw_world_after_encounter(encounter_id):
		_last_completion = CombatEncounterCompletionResult.new(
			CombatEncounterCompletionResult.Outcome.WORLD_THAW_FAILED,
			encounter_id,
			result,
		)
		return _last_completion
	if not _world_gate.release(encounter_id):
		_last_completion = CombatEncounterCompletionResult.new(
			CombatEncounterCompletionResult.Outcome.WORLD_GATE_RELEASE_FAILED,
			encounter_id,
			result,
		)
		return _last_completion
	# Prevalidated result, unchanged Core, synchronous non-reentrant gate release.
	# Commit terminal state only after both world-return operations succeeded.
	if not _active_encounter.complete(result):
		_last_completion = CombatEncounterCompletionResult.new(
			CombatEncounterCompletionResult.Outcome.COMPLETION_TRANSITION_FAILED, encounter_id, result,
		)
		return _last_completion
	_last_completion = CombatEncounterCompletionResult.new(
		CombatEncounterCompletionResult.Outcome.COMPLETED,
		encounter_id,
		result,
	)
	_active_scheduler = null
	_active_encounter = null
	return _last_completion


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
