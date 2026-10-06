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
var _completed_feedback: CombatCompletedFeedback
var _entry_sequence: int = 0
var _last_abort_detail: String = ""
## What the world printed as the active (or last) fight began; see note_opening().
var _opening_encounter_id: StringName = &""
var _opening_lines: Array[String] = []
var _opening_warnings: Array[String] = []

## Fights aborted by a failure (see _abort_failed_resolution) since the last take.
## SuiteResult turns any untaken abort into a test failure.
static var _aborted_total: int = 0


static func take_aborted_total() -> int:
	var total: int = _aborted_total
	_aborted_total = 0
	return total

func resolution() -> CombatEncounterResolution:
	return _resolution

func last_completion() -> CombatEncounterCompletionResult:
	return _last_completion

func completed_feedback() -> CombatCompletedFeedback:
	return _completed_feedback


## Why the last aborted fight failed (empty when none did).
func last_abort_detail() -> String:
	return _last_abort_detail


## The lines the world printed as the active fight began (fight.c's or kill.c's
## words), then feature/attack.c kill_ob()'s 看起来X想杀死你！ warnings: the
## battle log opens with them and the warnings stay pinned. Kept for the fight's
## encounter ID until the next fight notes its own.
func note_opening(lines: Array[String], warnings: Array[String]) -> void:
	if _active_encounter == null:
		return
	_opening_encounter_id = _active_encounter.encounter_id
	_opening_lines = lines.duplicate()
	_opening_warnings = warnings.duplicate()


func opening_lines(encounter_id: StringName) -> Array[String]:
	var lines: Array[String] = []
	if _is_opening_of(encounter_id):
		lines.assign(_opening_lines)
	return lines


func opening_warnings(encounter_id: StringName) -> Array[String]:
	var warnings: Array[String] = []
	if _is_opening_of(encounter_id):
		warnings.assign(_opening_warnings)
	return warnings


func _is_opening_of(encounter_id: StringName) -> bool:
	return not encounter_id.is_empty() and encounter_id == _opening_encounter_id

## One synchronous production-entry transaction. Reuses the audited playable
## relationship establishment; rollback restores order and preexisting facts.
## `directed_kill`: an NPC_AGGRESSION where only the initiator kills (a spar it
## turned into kill_ob); the target only fights back.
func start_production(initiator: CombatSliceCharacterBinding, target: CombatSliceCharacterBinding, cause: int, directed_kill: bool = false) -> CombatSliceInitiationResult:
	if not is_valid() or not _session.application_gameplay_allows_encounter_advance() or has_active_encounter() or not _world_gate.is_open():
		return CombatSliceInitiationResult.new()
	if initiator == null or target == null or not _session.encounter_participant_is_available(initiator.character_id) or not _session.encounter_participant_is_available(target.character_id):
		return CombatSliceInitiationResult.new()
	if cause not in [CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK, CombatTriggerCause.Value.NPC_AGGRESSION, CombatTriggerCause.Value.PLAYER_SPAR] or _entry_sequence == 9223372036854775807:
		return CombatSliceInitiationResult.new()
	var spar: bool = cause == CombatTriggerCause.Value.PLAYER_SPAR
	if directed_kill and cause != CombatTriggerCause.Value.NPC_AGGRESSION:
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
	var receipt: CombatSliceInitiationResult = (
		CombatSliceOpportunityExecutor.initiate_spar(initiator, target) if spar
		else CombatSliceOpportunityExecutor.initiate_directed_kill(initiator, target) if directed_kill
		else CombatSliceOpportunityExecutor.initiate_lethal_combat(initiator, target)
	)
	if receipt.outcome == CombatSliceInitiationResult.Outcome.COMPLETED:
		_entry_sequence += 1
		var candidates: Array[CombatTriggerCandidate] = [
			CombatTriggerCandidate.new(initiator.character_id, &"initiator"),
			CombatTriggerCandidate.new(target.character_id, &"target"),
		]
		var trigger := CombatTrigger.new(StringName("production:%d" % _entry_sequence), cause,
			CombatEncounterMode.Value.SPAR if spar else CombatEncounterMode.Value.LETHAL, initiator.character_id, candidates,
			_session.resolve_encounter_location(initiator.character_id))
		var started: CombatEncounterStartResult = start(trigger)
		if started.succeeded():
			return receipt
		## No completed initiation is reported when the new engine could not start.
		receipt._outcome = CombatSliceInitiationResult.Outcome.ENCOUNTER_START_FAILED
	_restore_entry_relationship(initiator.relationship, first_opponents, first_lethal)
	_restore_entry_relationship(target.relationship, second_opponents, second_lethal)
	return receipt

## World collects and revalidates synchronously; no caller-supplied eligible list.
## Player first, enemies in stable lexical CharacterId order; one existing engine.
func start_complete_production(cause: int, requested_target: StringName = &"") -> CombatSliceInitiationResult:
	var failed := CombatSliceInitiationResult.new()
	if not is_valid() or not _session.application_gameplay_allows_encounter_advance() or has_active_encounter() or not _world_gate.is_open() or _entry_sequence == 9223372036854775807:
		return failed
	var map: WorldMapController = _session.active_map() as WorldMapController
	if map == null:
		return failed
	var bindings: Array[CombatSliceCharacterBinding] = map.collect_complete_combat_entry(cause, requested_target)
	if bindings.size() < 2 or bindings[0].character_id != _session.player_runtime().character_id:
		return failed
	var player: CombatSliceCharacterBinding = bindings[0]
	var ids: Array[StringName] = []
	for binding: CombatSliceCharacterBinding in bindings:
		var current: CombatEncounterAuthorityBinding = _session.resolve_encounter_binding(binding.character_id)
		if not binding.is_valid() or current == null or not _session.encounter_participant_is_available(binding.character_id) or binding.state != current.state or binding.relationship != current.relationship or binding.busy != current.busy or binding.armor != current.armor or binding.location_id != player.location_id:
			return failed
		var location: WorldLocationState = _session.resolve_encounter_location(binding.character_id)
		if location == null or not location.shares_combat_location(_session.resolve_encounter_location(player.character_id)) or ids.has(binding.character_id):
			return failed
		for prior: CombatSliceCharacterBinding in bindings.slice(0, ids.size()):
			if not CombatSliceOpportunityExecutor._bindings_are_independent(prior, binding):
				return failed
		ids.append(binding.character_id)
	for binding: CombatSliceCharacterBinding in bindings:
		for opponent: StringName in binding.relationship.opponent_ids() + binding.relationship.lethal_target_ids():
			if not ids.has(opponent) or opponent == binding.character_id or (binding != player and opponent != player.character_id):
				return failed
	var saved_opponents: Array[Array] = []
	var saved_lethal: Array[Array] = []
	for binding: CombatSliceCharacterBinding in bindings:
		saved_opponents.append(binding.relationship.opponent_ids())
		saved_lethal.append(binding.relationship.lethal_target_ids())
	var receipt: CombatSliceInitiationResult = failed
	for enemy: CombatSliceCharacterBinding in bindings.slice(1):
		receipt = CombatSliceOpportunityExecutor.initiate_lethal_combat(player, enemy)
		if receipt.outcome != CombatSliceInitiationResult.Outcome.COMPLETED:
			break
	if receipt.outcome == CombatSliceInitiationResult.Outcome.COMPLETED:
		var candidates: Array[CombatTriggerCandidate] = []
		for binding: CombatSliceCharacterBinding in bindings:
			candidates.append(CombatTriggerCandidate.new(binding.character_id, &"player" if binding == player else &"enemies"))
		var initiator: StringName = player.character_id if cause == CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK else ids[1]
		_entry_sequence += 1
		var trigger := CombatTrigger.new(StringName("production:%d" % _entry_sequence), cause,
			CombatEncounterMode.Value.LETHAL, initiator, candidates, _session.resolve_encounter_location(initiator))
		if start(trigger).succeeded():
			if not requested_target.is_empty():
				_active_encounter.set_current_target(player.character_id, requested_target)
			map.consume_complete_entry_contacts(ids)
			receipt._initiator_id = initiator
			receipt._target_id = player.character_id if cause == CombatTriggerCause.Value.NPC_AGGRESSION else requested_target
			return receipt
	for index: int in bindings.size():
		_restore_entry_relationship(bindings[index].relationship, saved_opponents[index], saved_lethal[index])
	failed._outcome = CombatSliceInitiationResult.Outcome.ENCOUNTER_START_FAILED
	return failed


func _restore_entry_relationship(state: CombatRelationshipState, opponents: Array[StringName], lethal: Array[StringName]) -> void:
	for target_id: StringName in state.lethal_target_ids():
		state.remove_lethal_relation(target_id)
	state.clear_opponents_preserving_lethal_targets()
	for target_id: StringName in lethal:
		state.mark_lethal_target(target_id)
	state.clear_opponents_preserving_lethal_targets()
	for target_id: StringName in opponents:
		state.add_opponent(target_id)


## Content/test composition before encounter start; production Flee and exert are registered below.
func register_tactical_policy(policy: CombatTacticalActionPolicy) -> bool:
	return not has_active_encounter() and _tactical_registry.register_policy(policy)


func action_infos() -> Array[CombatTacticalActionInfo]:
	var infos: Array[CombatTacticalActionInfo] = []
	var player: CharacterState = null
	if _session != null and _session.player_runtime() != null:
		player = _session.player_runtime().state
	for info: CombatTacticalActionInfo in _tactical_registry.action_infos():
		var policy: CombatTacticalActionPolicy = _tactical_registry.find(info.action_id)
		if _active_encounter != null and not policy.supports_mode(_active_encounter.mode):
			continue
		if not policy.offered_to(player):
			continue
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
	_tactical_registry.register_policy(CombatSurrenderTacticalPolicy.new(_player_age))
	for function_id: StringName in ExertFunctions.ORDER:
		_tactical_registry.register_policy(CombatExertTacticalPolicy.new(function_id))
	for function_id: StringName in SpecialFunctions.PERFORMS:
		_tactical_registry.register_policy(CombatPerformTacticalPolicy.new(function_id))


func is_valid() -> bool:
	return _session != null and _world_gate != null


func _player_age() -> int:
	var player: WorldPlayerRuntimeState = null if _session == null else _session.player_runtime()
	return 0 if player == null else player.facts.age


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
			_abort_failed_resolution()
		elif _resolution.result != null:
			_resolution.reconcile_relationships()
			complete(_resolution.result)
	return advanced


## A failed opportunity, attack chain or lifecycle ends the fight where it stood instead of
## freezing it: damage dealt so far stays, anyone already below zero kee falls
## (char.c heart_beat does that outside any fight), both sides disengage and the
## world returns. Development builds log the cause; tests fail on it.
func _abort_failed_resolution() -> void:
	if _active_encounter.phase != CombatEncounterLifecycle.Value.ACTIVE:
		return
	_last_abort_detail = _failure_detail()
	_aborted_total += 1
	if OS.is_debug_build():
		push_error("Combat encounter %s aborted: %s" % [_active_encounter.encounter_id, _last_abort_detail])
	var map: WorldMapController = _session.active_map() as WorldMapController
	var bindings: Array[CombatSliceCharacterBinding] = _session.encounter_combat_bindings(_active_encounter)
	if map != null:
		for victim: CombatSliceCharacterBinding in bindings:
			var required: CombatSliceOpportunityResult = CombatSliceOpportunityExecutor.inspect_lifecycle(victim)
			if required != null and victim.exists_in_encounter:
				map.execute_encounter_lifecycle(victim, required, bindings)
	_resolution.disengage_all()
	_return_world(CombatEncounterResult.new(_active_encounter.encounter_id, _active_encounter.mode,
		CombatEncounterResultKind.Value.ABORTED, [], [], []))


func _failure_detail() -> String:
	var parts: Array[String] = ["failure=%s" % CombatEncounterResolution.Failure.find_key(_resolution.failure)]
	var special: SpecialReport = _resolution.failed_special
	if special != null:
		for attack: SpecialAttack in special.attacks():
			parts.append("special %s>%s chain=%s" % [attack.attacker_id, attack.victim_id, "none" if attack.chain == null else CombatAttackChainResult.Outcome.find_key(attack.chain.outcome)])
			if attack.forward != null:
				parts.append(_ordinary_detail("special", attack.forward.ordinary_attack_result))
		return " ".join(parts)
	var events: Array[CombatSchedulerEvent] = _active_scheduler.events_after(0)
	var opportunity: CombatSliceOpportunityResult = null
	for index: int in range(events.size() - 1, -1, -1):
		if events[index].resolution != null:
			opportunity = events[index].resolution
			parts.append("actor=%s target=%s" % [events[index].actor_id, events[index].target_id])
			break
	if opportunity != null:
		parts.append("opportunity=%s@%s" % [CombatSliceOpportunityResult.Outcome.find_key(opportunity.outcome), CombatSliceOpportunityResult.ReachedStage.find_key(opportunity.reached_stage)])
		if opportunity.opponent_selection_result != null:
			parts.append("selection=%s" % CombatOpponentSelectionResult.Outcome.find_key(opportunity.opponent_selection_result.outcome))
		if opportunity.fight_decision_result != null:
			parts.append("fight=%s@%s" % [CombatFightDecisionResult.Outcome.find_key(opportunity.fight_decision_result.outcome), CombatFightDecisionResult.FailureStage.find_key(opportunity.fight_decision_result.failure_stage)])
		var forward: CombatSingleAttackExecutionResult = opportunity.forward_result
		if forward != null:
			parts.append("forward=%s@%s" % [CombatSingleAttackExecutionResult.Outcome.find_key(forward.outcome), CombatSingleAttackExecutionResult.FailureStage.find_key(forward.failure_stage)])
			parts.append(_ordinary_detail("forward", forward.ordinary_attack_result))
		if opportunity.chain_result != null and opportunity.chain_result.reverse_execution_reached:
			parts.append(_ordinary_detail("reverse", opportunity.chain_result.reverse_ordinary_result))
		if opportunity.chain_result != null:
			parts.append("chain@%s" % CombatAttackChainResult.FailureStage.find_key(opportunity.chain_result.failure_stage))
	return " ".join(parts)


static func _ordinary_detail(label: String, ordinary: CombatOrdinaryAttackResult) -> String:
	if ordinary == null:
		return "%s.ordinary=none" % label
	var text: String = "%s.ordinary=%s@%s" % [label, CombatOrdinaryAttackResult.Outcome.find_key(ordinary.outcome), CombatOrdinaryAttackResult.FailureStage.find_key(ordinary.failure_stage)]
	if ordinary.has_base_result:
		text += " %s.attack=%s@%s" % [label, CombatAttackResult.Outcome.find_key(ordinary.base_result.outcome), CombatAttackResult.FailureStage.find_key(ordinary.base_result.failure_stage)]
	if ordinary.progression_result != null:
		text += " %s.progression@%s" % [label, CombatProgressionResult.FailureStage.find_key(ordinary.progression_result.failure_stage)]
	return text


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
	if trigger.cause != CombatTriggerCause.Value.SCRIPTED and not _connected_to_initiator(trigger.initiator_id, participants):
		return _start_failure(CombatEncounterStartResult.Outcome.RELATIONSHIP_TOPOLOGY_MISSING, trigger)
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
	scheduler.configure_npc_chat(CombatNpcChat.new(_resident_npc, _npc_wield, _respect_of))
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
	_completed_feedback = null
	_resolution = null if encounter.mode == CombatEncounterMode.Value.SCRIPTED else CombatEncounterResolution.new(_session, encounter)
	return CombatEncounterStartResult.new(
		CombatEncounterStartResult.Outcome.STARTED,
		trigger.trigger_id,
		encounter_id,
	)


## command("wield <type>") / command("unwield <type>") for an NPC in the fight.
func _npc_wield(character_id: StringName, weapon_type: StringName, on: bool) -> bool:
	var map: WorldMapController = _session.active_map() as WorldMapController
	return map != null and map.npc_wield_by_type(character_id, weapon_type, on)


## RANK_D->query_respect() of a participant, in the shown language.
func _respect_of(character_id: StringName) -> String:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	if player != null and player.character_id == character_id:
		return tr(RankWords.query_respect(player.state.gender, player.facts.age, player.state.affiliation.class_id))
	var npc: NpcRuntimeState = _resident_npc(character_id)
	if npc == null:
		return ""
	return tr(RankWords.query_respect(npc.character_state.gender, npc.age, &"", npc.definition().rank_respect))


## The NPC a participant is (npc.c chat() in the fight), or null.
func _resident_npc(character_id: StringName) -> NpcRuntimeState:
	var map: WorldMapController = _session.active_map() as WorldMapController
	return null if map == null else map.find_resident_npc(character_id)


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
	return _return_world(result)


## Prevalidated result: RESOLVING, cancel the queued action, thaw, release, commit.
func _return_world(result: CombatEncounterResult) -> CombatEncounterCompletionResult:
	var encounter_id: StringName = _active_encounter.encounter_id
	var queued: CombatQueuedAction = _active_encounter.queued_player_action()
	if not _active_encounter.begin_resolving():
		return CombatEncounterCompletionResult.new(
			CombatEncounterCompletionResult.Outcome.RESOLVING_TRANSITION_FAILED,
			encounter_id,
		)
	if _active_scheduler != null and _active_scheduler.player_tactics() != null:
		_active_scheduler.player_tactics().report_completion_cancellation(queued)
	# Owner: fakefault.c's strike only in the fight it began in; a timed apply that
	# outlives the fight only takes its applies back.
	for participant: CombatParticipant in _active_encounter.participants():
		participant.binding.state.timed_applies.forget_targets()
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
	_completed_feedback = CombatCompletedFeedback.new(encounter_id, _active_scheduler)
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


## Side hostility is not proof that each individual participates. Follow actual
## directed opponent edges in either direction; do not invent reciprocal fights.
func _connected_to_initiator(id: StringName, participants: Array[CombatParticipant]) -> bool:
	var reached: Array[StringName] = [id]
	var cursor: int = 0
	while cursor < reached.size():
		for actor: CombatParticipant in participants:
			if actor.participant_id != reached[cursor]:
				continue
			for target: CombatParticipant in participants:
				if target.participant_id in reached or actor.side_id == target.side_id:
					continue
				if actor.binding.relationship.has_opponent(target.participant_id) or target.binding.relationship.has_opponent(actor.participant_id):
					reached.append(target.participant_id)
		cursor += 1
	return reached.size() == participants.size()

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
