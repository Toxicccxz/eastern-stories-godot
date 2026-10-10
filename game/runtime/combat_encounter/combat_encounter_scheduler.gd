class_name CombatEncounterScheduler
extends RefCounted

const TIME_EPSILON_SECONDS: float = 0.000000001
## What an NPC's heart beat did before npc.c chat() runs in it: attack() (std/char.c).
## A busy beat (continue_action()) or a falling one says nothing.
const CHAT_AFTER: Array[int] = [
	CombatSliceOpportunityResult.Outcome.ATTACK_CHAIN_COMPLETE,
	CombatSliceOpportunityResult.Outcome.ENTERED_GUARDING,
	CombatSliceOpportunityResult.Outcome.FIGHT_NO_ACTION,
]


## A timed apply that ran out this round, and whose it was.
class EndedEffect:
	extends RefCounted
	var binding: CombatSliceCharacterBinding
	var entry: CharacterTimedApplies.Entry

	func _init(p_binding: CombatSliceCharacterBinding, p_entry: CharacterTimedApplies.Entry) -> void:
		binding = p_binding
		entry = p_entry


var _encounter: CombatEncounter
var _config: CombatSchedulerConfig
var _accumulated_input_seconds: float = 0.0
var _logical_cycle: int = 0
var _next_event_sequence: int = 1
var _events: Array[CombatSchedulerEvent] = []
var _progression_order := CombatProgressionOrder.new()
var _tactical: CombatTacticalRuntime
var _target_events: Array[CombatOrderedTargetEvent] = []
## Falls and deaths the boundary saw (combatd.c announce()), in progression order.
var _announcements: Array[CombatLifecycleAnnouncement] = []
var _npc_chat: CombatNpcChat

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


## NPCs' npc.c chat() in the fight, configured once before the first advance.
func configure_npc_chat(chat: CombatNpcChat) -> bool:
	if _npc_chat != null or _accumulated_input_seconds != 0.0 or chat == null:
		return false
	_npc_chat = chat
	return true


func target_events_after(order: int) -> Array[CombatOrderedTargetEvent]:
	var result: Array[CombatOrderedTargetEvent] = []
	for index: int in range(_target_events.size() - 1, -1, -1):
		var value: CombatOrderedTargetEvent = _target_events[index]
		if value.progression_order <= order:
			break
		result.append(value) # Read-only wrapper, defensive Core event getter.
	result.reverse()
	return result


func announcements_after(order: int) -> Array[CombatLifecycleAnnouncement]:
	var result: Array[CombatLifecycleAnnouncement] = []
	for value: CombatLifecycleAnnouncement in _announcements:
		if value.progression_order > order:
			result.append(value)
	return result


## The boundary's inspect(), then who fell or died there, each in its place.
func _inspect(
	boundary: CombatOpportunityBoundary, bindings: Array[CombatSliceCharacterBinding],
	event: CombatSchedulerEvent = null, tactical: CombatTacticalExecutionResult = null,
) -> bool:
	var ok: bool = boundary.inspect(bindings, event, tactical)
	for announcement: CombatLifecycleAnnouncement in boundary.take_announcements():
		_announcements.append(announcement.ordered(_progression_order.take()))
	return ok


## Called only after a successful Core target transition. Does not advance time.
func record_target_change() -> void:
	var value: CombatEncounterEvent = _encounter.latest_event()
	if value == null or value.kind != CombatEncounterEventKind.Value.TARGET_CHANGED:
		return
	if not _target_events.is_empty() and _target_events.back().event.sequence >= value.sequence:
		return
	_target_events.append(CombatOrderedTargetEvent.new(value, _progression_order.take()))


func can_target(actor_id: StringName, target_id: StringName, bindings: Array[CombatSliceCharacterBinding]) -> bool:
	var actor: CombatSliceCharacterBinding = _find_binding(bindings, actor_id)
	return (
		actor != null and actor.exists_in_encounter and actor.combat_available
		and actor.life_status == CombatSliceLifeStatus.Value.ACTIVE
		and _target_is_currently_eligible(actor, target_id, bindings)
	)


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


## Incremental defensive read: walks only the new suffix, never clones old history.
func events_after(progression_order: int) -> Array[CombatSchedulerEvent]:
	var result: Array[CombatSchedulerEvent] = []
	for index: int in range(_events.size() - 1, -1, -1):
		var event: CombatSchedulerEvent = _events[index]
		if event.progression_order <= progression_order:
			break
		result.append(event.duplicate_snapshot())
	result.reverse()
	return result


func advance(
	delta_seconds: float,
	application_gameplay_active: bool,
	world_gate_owner_id: StringName,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
	boundary: CombatOpportunityBoundary = null,
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
		or not bindings_match_encounter(bindings)
	):
		return CombatSchedulerAdvanceResult.new(
			CombatSchedulerAdvanceResult.Outcome.AUTHORITY_INVALID
		)
	if boundary != null and not _inspect(boundary, bindings):
		return CombatSchedulerAdvanceResult.new()
	var tactical_result: CombatTacticalExecutionResult = null
	if _tactical != null:
		tactical_result = _tactical.process_command_boundary(bindings, random_source, effect_registry)
		if tactical_result != null and tactical_result.outcome == CombatTacticalExecutionResult.Outcome.DISENGAGED:
			if boundary != null:
				boundary.accept_tactical(tactical_result)
			# Never accumulate delta or execute an ordinary opportunity after escape,
			# even if a standalone scheduler has no completion adapter installed.
			return CombatSchedulerAdvanceResult.new(CombatSchedulerAdvanceResult.Outcome.ADVANCED_NO_OPPORTUNITY)
	if boundary != null and tactical_result != null and not (tactical_result.joiners.is_empty() and tactical_result.allies.is_empty() and tactical_result.joins.is_empty()):
		boundary.admit(bindings, tactical_result)
	# A perform's attacks fell nobody yet: char.c heart_beat() does, here.
	if boundary != null and not _inspect(boundary, bindings, null, tactical_result):
		return CombatSchedulerAdvanceResult.new()
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
	var processed_cycles: int = 0
	for _cycle_index: int in range(due_cycles):
		_logical_cycle += 1
		processed_cycles += 1
		for ended: EndedEffect in _wear_timed_applies(bindings):
			var effect: CombatSchedulerEvent = _remove_effect(ended, bindings, random_source, effect_registry)
			if effect == null:
				continue
			_events.append(effect)
			emitted.append(effect)
			_next_event_sequence += 1
			if boundary != null and not _inspect(boundary, bindings, effect):
				return CombatSchedulerAdvanceResult.new(
					CombatSchedulerAdvanceResult.Outcome.ADVANCED, processed_cycles, emitted,
				)
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
			if boundary != null and not _inspect(boundary, bindings, event):
				return CombatSchedulerAdvanceResult.new(
					CombatSchedulerAdvanceResult.Outcome.ADVANCED, processed_cycles, emitted,
				)
			# oldman.c receive_damage(): the one hit says its own after the blow.
			var hurt: CombatSchedulerEvent = _hurt_after(event, bindings, random_source)
			if hurt != null:
				_events.append(hurt)
				emitted.append(hurt)
				_next_event_sequence += 1
				var felt: CombatNpcChatResult = hurt.chat
				if boundary != null and not felt.departure_zone_id().is_empty():
					boundary.depart(bindings, hurt.actor_id, felt.departure_zone_id())
				if boundary != null and not _inspect(boundary, bindings, hurt):
					return CombatSchedulerAdvanceResult.new(
						CombatSchedulerAdvanceResult.Outcome.ADVANCED, processed_cycles, emitted,
					)
			var chat: CombatSchedulerEvent = _chat_after(event, bindings, random_source, effect_registry)
			if chat == null:
				continue
			_events.append(chat)
			emitted.append(chat)
			_next_event_sequence += 1
			# ask_for_help(): the partner's kill_ob() brings it in before anyone acts on.
			var said: CombatNpcChatResult = chat.chat
			if boundary != null and said != null and not said.joins().is_empty():
				boundary.admit(bindings, CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.APPLIED).with_joins(said.joins()))
			# go.c: the NPC walked out of the room and out of the fight.
			if boundary != null and said != null and not said.departure_zone_id().is_empty():
				boundary.depart(bindings, chat.actor_id, said.departure_zone_id())
			if boundary != null and not _inspect(boundary, bindings, chat):
				return CombatSchedulerAdvanceResult.new(
					CombatSchedulerAdvanceResult.Outcome.ADVANCED, processed_cycles, emitted,
				)
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
	if not actor.is_user and _eligible_targets(actor, bindings) > 1:
		return _select_opponent(actor, bindings, random_source, effect_registry)
	if target_id.is_empty() or not _target_is_currently_eligible(actor, target_id, bindings):
		target_id = _first_initial_target(actor, bindings)
		if target_id.is_empty():
			if _encounter.clear_current_target(actor.character_id):
				record_target_change()
			return _skipped_event(
				actor.character_id,
				target_id,
				CombatSchedulerEvent.SkipReason.TARGET_UNAVAILABLE,
			)
		if _encounter.set_current_target(actor.character_id, target_id):
			record_target_change()
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


## call_out() runs on the driver's clock: a round of the fight is combat_round_ms of
## it for every timed apply (CharacterTimedApplies). Returns the entries that ended,
## in the bindings' order. powerup's remove_effect() tells only its user (an NPC).
func _wear_timed_applies(bindings: Array[CombatSliceCharacterBinding]) -> Array[EndedEffect]:
	var ended: Array[EndedEffect] = []
	var round_ms: int = roundi(_config.opportunity_interval_seconds * 1000.0)
	for binding: CombatSliceCharacterBinding in bindings:
		for entry: CharacterTimedApplies.Entry in binding.state.timed_applies.advance_entries(round_ms):
			ended.append(EndedEffect.new(binding, entry))
	return ended


## A perform file's remove_effect() for an entry that ended this round
## (fakefault.c's strike), as an event, or null when it showed and did nothing.
func _remove_effect(
	ended: EndedEffect,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
) -> CombatSchedulerEvent:
	var function: PerformFunction = SpecialFunctions.ending(ended.entry.effect_id)
	if function == null:
		return null
	var context: SpecialContext = CombatSpecialAttackSource.context_for(ended.binding, bindings, random_source, effect_registry)
	context.target = context.other(ended.entry.target_id)
	function.remove_effect(context, ended.entry)
	var report: SpecialReport = context.report()
	if report.is_empty():
		return null
	return CombatSchedulerEvent.new(
		_next_event_sequence,
		_logical_cycle,
		logical_time_seconds,
		CombatSchedulerEvent.Kind.SPECIAL_EFFECT_ENDED,
		CombatSchedulerEvent.SkipReason.NONE,
		ended.binding.character_id,
		ended.entry.target_id,
		null,
		_progression_order.take(),
		null,
		report,
	)


## An NPC's own receive_damage() (NpcHooks: oldman.c) after a blow of this opportunity drew
## kee from it: its lines, its walk out of the fight, a pill (CombatNpcChat.hurt()).
func _hurt_after(
	event: CombatSchedulerEvent,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
) -> CombatSchedulerEvent:
	if _npc_chat == null or event == null or event.kind != CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED or event.resolution == null:
		return null
	var blows: Array = []
	var forward: CombatSingleAttackExecutionResult = event.resolution.forward_result
	if forward != null:
		blows.append(_blow(forward.ordinary_attack_result))
	var chain: CombatAttackChainResult = event.resolution.chain_result
	if chain != null and chain.reverse_execution_reached:
		blows.append(_blow(chain.reverse_ordinary_result))
	for blow: Array in blows:
		if blow.is_empty():
			continue
		var victim: CombatSliceCharacterBinding = _find_binding(bindings, blow[0])
		if victim == null or victim.life_status != CombatSliceLifeStatus.Value.ACTIVE:
			continue
		var result: CombatNpcChatResult = _npc_chat.hurt(victim, blow[1], random_source)
		if result == null:
			continue
		return CombatSchedulerEvent.new(
			_next_event_sequence,
			_logical_cycle,
			logical_time_seconds,
			CombatSchedulerEvent.Kind.NPC_CHAT,
			CombatSchedulerEvent.SkipReason.NONE,
			victim.character_id,
			&"",
			null,
			_progression_order.take(),
			result,
		)
	return null


## [victim, damage] of a blow that drew kee, or [] for one that did not.
static func _blow(ordinary: CombatOrdinaryAttackResult) -> Array:
	if ordinary == null or not ordinary.has_base_result:
		return []
	var base: CombatAttackResult = ordinary.base_result
	if base.outcome != CombatAttackResult.Outcome.HIT or base.resource_mutation == null or base.resource_mutation.requested_damage <= 0:
		return []
	return [base.defender_id, base.resource_mutation.requested_damage]


## npc.c chat() after the attack of an NPC that is still fighting (CombatNpcChat),
## against its enemies as they are now: those it may still target, in its order.
func _chat_after(
	event: CombatSchedulerEvent,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
) -> CombatSchedulerEvent:
	if _npc_chat == null or event == null or event.kind != CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED:
		return null
	if event.resolution == null or event.resolution.outcome not in CHAT_AFTER:
		return null
	var actor: CombatSliceCharacterBinding = _find_binding(bindings, event.actor_id)
	if actor == null or actor.life_status != CombatSliceLifeStatus.Value.ACTIVE or not actor.relationship.is_fighting():
		return null
	var enemies: Array[CombatSliceCharacterBinding] = []
	for target_id: StringName in actor.relationship.opponent_ids():
		if _target_is_currently_eligible(actor, target_id, bindings):
			enemies.append(_find_binding(bindings, target_id))
	var others: Array[CombatSliceCharacterBinding] = []
	for binding: CombatSliceCharacterBinding in bindings:
		if binding != actor:
			others.append(binding)
	var result: CombatNpcChatResult = _npc_chat.beat(actor, enemies, others, random_source, effect_registry)
	if result == null:
		return null
	return CombatSchedulerEvent.new(
		_next_event_sequence,
		_logical_cycle,
		logical_time_seconds,
		CombatSchedulerEvent.Kind.NPC_CHAT,
		CombatSchedulerEvent.SkipReason.NONE,
		actor.character_id,
		&"",
		null,
		_progression_order.take(),
		result,
	)


## feature/attack.c attack() for an NPC with several enemies here (the player and the
## soldier they called): select_opponent() takes one of them, random(MAX_OPPONENT) or
## else the first; that one becomes its target. An NPC with one enemy keeps its target
## and draws nothing, as before.
func _select_opponent(
	actor: CombatSliceCharacterBinding,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
) -> CombatSchedulerEvent:
	var resolution: CombatSliceOpportunityResult = CombatSliceOpportunityExecutor.execute_opportunity(
		actor, bindings, random_source, effect_registry,
	)
	var selection: CombatOpponentSelectionResult = resolution.opponent_selection_result
	var target_id: StringName = _encounter.current_target_for(actor.character_id)
	if selection != null and selection.outcome == CombatOpponentSelectionResult.Outcome.SELECTED:
		target_id = selection.selected_opponent_id
		if _encounter.is_hostile(actor.character_id, target_id) and _encounter.set_current_target(actor.character_id, target_id):
			record_target_change()
	return _resolved_event(actor.character_id, target_id, resolution)


func _eligible_targets(actor: CombatSliceCharacterBinding, bindings: Array[CombatSliceCharacterBinding]) -> int:
	var count: int = 0
	for candidate: CombatParticipant in _encounter.participants():
		if _target_is_currently_eligible(actor, candidate.participant_id, bindings):
			count += 1
	return count


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
		and (target.life_status == CombatSliceLifeStatus.Value.ACTIVE or (
			_encounter.mode == CombatEncounterMode.Value.LETHAL
			and target.life_status == CombatSliceLifeStatus.Value.UNCONSCIOUS
			and actor.relationship.has_lethal_target(target_id)
		))
		and target.location_id == actor.location_id
		and _encounter.is_hostile(actor.character_id, target_id)
		and actor.relationship.has_opponent(target_id)
	)


func bindings_match_encounter(
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
