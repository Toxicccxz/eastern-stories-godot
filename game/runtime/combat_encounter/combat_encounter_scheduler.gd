class_name CombatEncounterScheduler
extends RefCounted

const TIME_EPSILON_SECONDS: float = 0.000000001

var _encounter: CombatEncounter
var _config: CombatSchedulerConfig
var _accumulated_input_seconds: float = 0.0
var _logical_cycle: int = 0
var _next_event_sequence: int = 1
var _events: Array[CombatSchedulerEvent] = []
var _progression_order := CombatProgressionOrder.new()
var _tactical: CombatTacticalRuntime

var logical_cycle: int:
	get: return _logical_cycle
var logical_time_seconds: float:
	get:
		return (
			0.0
			if _config == null
			else float(_logical_cycle) * _config.opportunity_interval_seconds
		)
var remainder_seconds: float:
	get:
		if _config == null:
			return 0.0
		return maxf(
			0.0,
			_accumulated_input_seconds - logical_time_seconds,
		)


func _init(
	p_encounter: CombatEncounter = null,
	p_config: CombatSchedulerConfig = null,
) -> void:
	_encounter = p_encounter
	_config = p_config


## Configured once before the first advance. Default registry is deliberately empty.
func configure_player_tactics(player_id: StringName, registry: CombatTacticalActionRegistry) -> bool:
	if _tactical != null or _accumulated_input_seconds != 0.0 or registry == null:
		return false
	if _encounter == null or _encounter.participant_for(player_id) == null:
		return false
	_tactical = CombatTacticalRuntime.new(_encounter, player_id, registry, _progression_order)
	return true


func player_tactics() -> CombatTacticalRuntime:
	return _tactical


func is_valid() -> bool:
	return (
		_encounter != null
		and _encounter.is_valid()
		and _config != null
		and _config.is_valid()
	)


func events() -> Array[CombatSchedulerEvent]:
	var result: Array[CombatSchedulerEvent] = []
	for event: CombatSchedulerEvent in _events:
		result.append(event.duplicate_snapshot())
	return result


func advance(
	delta_seconds: float,
	application_gameplay_active: bool,
	world_gate_owner_id: StringName,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
) -> CombatSchedulerAdvanceResult:
	if not is_valid() or _encounter.phase != CombatEncounterLifecycle.Value.ACTIVE:
		return CombatSchedulerAdvanceResult.new()
	if not application_gameplay_active:
		return CombatSchedulerAdvanceResult.new(
			CombatSchedulerAdvanceResult.Outcome.APPLICATION_PAUSED
		)
	if world_gate_owner_id != _encounter.encounter_id:
		return CombatSchedulerAdvanceResult.new(
			CombatSchedulerAdvanceResult.Outcome.WORLD_GATE_MISMATCH
		)
	if not is_finite(delta_seconds) or delta_seconds < 0.0:
		return CombatSchedulerAdvanceResult.new(
			CombatSchedulerAdvanceResult.Outcome.INVALID_DELTA
		)
	if (
		random_source == null
		or effect_registry == null
		or not _bindings_match_encounter(bindings)
	):
		return CombatSchedulerAdvanceResult.new(
			CombatSchedulerAdvanceResult.Outcome.AUTHORITY_INVALID
		)
	if _tactical != null:
		_tactical.process_command_boundary(bindings, random_source)
	_accumulated_input_seconds += delta_seconds
	var due_total: int = int(floor(
		(
			_accumulated_input_seconds + TIME_EPSILON_SECONDS
		) / _config.opportunity_interval_seconds
	))
	var due_cycles: int = due_total - _logical_cycle
	if due_cycles <= 0:
		return CombatSchedulerAdvanceResult.new(
			CombatSchedulerAdvanceResult.Outcome.ADVANCED_NO_OPPORTUNITY
		)
	var emitted: Array[CombatSchedulerEvent] = []
	for _cycle_index: int in range(due_cycles):
		_logical_cycle += 1
		for participant: CombatParticipant in _encounter.participants():
			var event: CombatSchedulerEvent = _process_participant(
				participant,
				bindings,
				random_source,
				effect_registry,
			)
			if event != null:
				_events.append(event)
				emitted.append(event)
				_next_event_sequence += 1
	return CombatSchedulerAdvanceResult.new(
		CombatSchedulerAdvanceResult.Outcome.ADVANCED,
		due_cycles,
		emitted,
	)


func _process_participant(
	participant: CombatParticipant,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
) -> CombatSchedulerEvent:
	var actor: CombatSliceCharacterBinding = _find_binding(
		bindings,
		participant.participant_id,
	)
	if (
		actor == null
		or not actor.exists_in_encounter
		or not actor.combat_available
		or actor.life_status != CombatSliceLifeStatus.Value.ACTIVE
	):
		return _skipped_event(
			participant.participant_id,
			&"",
			CombatSchedulerEvent.SkipReason.PARTICIPANT_UNAVAILABLE,
		)
	if not actor.relationship.is_fighting():
		return _skipped_event(
			actor.character_id,
			&"",
			CombatSchedulerEvent.SkipReason.RELATIONSHIP_INACTIVE,
		)

	var target_id: StringName = _encounter.current_target_for(actor.character_id)
	if actor.busy.is_busy():
		return _resolved_event(
			actor.character_id,
			target_id,
			CombatSliceOpportunityExecutor.execute_opportunity(
				actor,
				bindings,
				random_source,
				effect_registry,
				target_id,
			),
		)
	if target_id.is_empty():
		target_id = _first_initial_target(actor, bindings)
		if target_id.is_empty() or not _encounter.set_current_target(
			actor.character_id,
			target_id,
		):
			return _skipped_event(
				actor.character_id,
				target_id,
				CombatSchedulerEvent.SkipReason.TARGET_UNAVAILABLE,
			)
	elif not _target_is_currently_eligible(actor, target_id, bindings):
		return _skipped_event(
			actor.character_id,
			target_id,
			CombatSchedulerEvent.SkipReason.TARGET_UNAVAILABLE,
		)
	return _resolved_event(
		actor.character_id,
		target_id,
		CombatSliceOpportunityExecutor.execute_opportunity(
			actor,
			bindings,
			random_source,
			effect_registry,
			target_id,
		),
	)


func _first_initial_target(
	actor: CombatSliceCharacterBinding,
	bindings: Array[CombatSliceCharacterBinding],
) -> StringName:
	for candidate: CombatParticipant in _encounter.participants():
		if _target_is_currently_eligible(
			actor,
			candidate.participant_id,
			bindings,
		):
			return candidate.participant_id
	return &""


func _target_is_currently_eligible(
	actor: CombatSliceCharacterBinding,
	target_id: StringName,
	bindings: Array[CombatSliceCharacterBinding],
) -> bool:
	var target: CombatSliceCharacterBinding = _find_binding(bindings, target_id)
	return (
		target != null
		and target.exists_in_encounter
		and target.combat_available
		and target.life_status == CombatSliceLifeStatus.Value.ACTIVE
		and target.location_id == actor.location_id
		and _encounter.is_hostile(actor.character_id, target_id)
		and actor.relationship.has_opponent(target_id)
	)


func _bindings_match_encounter(
	bindings: Array[CombatSliceCharacterBinding],
) -> bool:
	var participants: Array[CombatParticipant] = _encounter.participants()
	if bindings.size() != participants.size():
		return false
	for index: int in range(participants.size()):
		var participant: CombatParticipant = participants[index]
		var binding: CombatSliceCharacterBinding = bindings[index]
		if (
			binding == null
			or not binding.is_valid()
			or binding.character_id != participant.participant_id
			or binding.state != participant.binding.state
			or binding.relationship != participant.binding.relationship
			or binding.busy != participant.binding.busy
			or binding.armor != participant.binding.armor
		):
			return false
	return true


func _find_binding(
	bindings: Array[CombatSliceCharacterBinding],
	participant_id: StringName,
) -> CombatSliceCharacterBinding:
	for binding: CombatSliceCharacterBinding in bindings:
		if binding != null and binding.character_id == participant_id:
			return binding
	return null


func _skipped_event(
	actor_id: StringName,
	target_id: StringName,
	reason: int,
) -> CombatSchedulerEvent:
	return CombatSchedulerEvent.new(
		_next_event_sequence,
		_logical_cycle,
		logical_time_seconds,
		CombatSchedulerEvent.Kind.PARTICIPANT_SKIPPED,
		reason,
		actor_id,
		target_id,
		null,
		_progression_order.take(),
	)


func _resolved_event(
	actor_id: StringName,
	target_id: StringName,
	resolution: CombatSliceOpportunityResult,
) -> CombatSchedulerEvent:
	return CombatSchedulerEvent.new(
		_next_event_sequence,
		_logical_cycle,
		logical_time_seconds,
		CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED,
		CombatSchedulerEvent.SkipReason.NONE,
		actor_id,
		target_id,
		resolution,
		_progression_order.take(),
	)
