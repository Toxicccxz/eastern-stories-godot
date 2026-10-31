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
## 战斗决策层 1B (DECISIONS「战斗决策」).
var _decisions: CombatDecisionRules = CombatDecisionRules.classic()
var _player_id: StringName = &""
## The round's standing modifiers (stance, a 守 move, the move tags held), filled each cycle.
var _modifiers: CombatRoundModifiers = CombatRoundModifiers.new()
## Under player_turns: the player's order opened this round; it closes once a cycle ran.
var _round_open: bool = false
## The move the player chose for this round (taken without a draw), and its tag.
var _player_choice: StringName = &""
var _player_choice_tag: StringName = &""
## An NPC's next ordinary move, drawn one beat early (npc_telegraph), by actor.
var _next_moves: Dictionary[StringName, StringName] = {}
## A special an NPC announced, to run on its next beat, by actor.
var _pending_specials: Dictionary[StringName, NpcSpecialAction] = {}
var _pending_labels: Dictionary[StringName, String] = {}
## Whom the player's feint or perform struck this round: their pending special is off.
var _interrupted: Dictionary[StringName, bool] = {}

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
	_tactical.set_cooldown_rounds(_decisions.perform_cooldown_rounds)
	_player_id = player_id
	return true


## The decision layer's knobs, configured once before the first advance.
func configure_decisions(rules: CombatDecisionRules) -> bool:
	if rules == null or _accumulated_input_seconds != 0.0:
		return false
	_decisions = rules.duplicate_snapshot()
	if _tactical != null:
		_tactical.set_cooldown_rounds(_decisions.perform_cooldown_rounds)
	if _npc_chat != null:
		_npc_chat.telegraph = _decisions.npc_telegraph
	return true


func decisions() -> CombatDecisionRules:
	return _decisions


## The fight waits for the player's order each round: pacing player_turns, the 自动
## switch off, and a player who can act (not busy, conscious, someone to fight, nothing
## queued); an open round runs to its end first.
func waiting_for_player(bindings: Array[CombatSliceCharacterBinding]) -> bool:
	if not manual() or _round_open or _tactical == null or _encounter.queued_player_action() != null:
		return false
	var actor: CombatSliceCharacterBinding = _find_binding(bindings, _player_id)
	if (
		actor == null or not actor.exists_in_encounter or not actor.combat_available
		or actor.life_status != CombatSliceLifeStatus.Value.ACTIVE or actor.busy.is_busy()
		or not actor.relationship.is_fighting()
	):
		return false
	var target_id: StringName = _encounter.current_target_for(actor.character_id)
	if target_id.is_empty() or not _target_is_currently_eligible(actor, target_id, bindings):
		target_id = _first_initial_target(actor, bindings)
	return not target_id.is_empty()


func manual() -> bool:
	return _decisions.player_turns and BattlePace.manual_turns and _tactical != null


## The player's order: the round runs (one cycle) and the clock waits again after it.
func open_round() -> void:
	if _round_open:
		return
	_round_open = true
	# A round is a whole cycle from the order: the remainder of the last one is dropped.
	_accumulated_input_seconds = logical_time_seconds


## The moves the player may choose from now (their action set, as reset_action() has it).
func player_moves(bindings: Array[CombatSliceCharacterBinding]) -> Array[CombatActionDefinition]:
	var actor: CombatSliceCharacterBinding = _find_binding(bindings, _player_id)
	if actor == null or not actor.is_valid():
		return []
	var input: CombatActionSelectionInput = CombatSliceProjectionBuilder.build_action_selection_input(actor)
	var set: CombatActionSet = null if input == null else input.current_action_set()
	return [] if set == null or not set.is_valid() else set.actions()


## The player chose `action_id` for this round: it is taken without a draw, and the
## round runs. False when it is not one of their moves now.
func choose_attack(action_id: StringName, bindings: Array[CombatSliceCharacterBinding]) -> bool:
	for action: CombatActionDefinition in player_moves(bindings):
		if action.action_id == action_id:
			_player_choice = action_id
			_player_choice_tag = action.tag
			open_round()
			return true
	return false


func player_choice() -> StringName:
	return _player_choice


## The tag of the move an NPC will use next (npc_telegraph), &"" when none is drawn yet.
func next_move_tag(actor_id: StringName, bindings: Array[CombatSliceCharacterBinding]) -> StringName:
	var action_id: StringName = _next_moves.get(actor_id, &"")
	if action_id.is_empty():
		return &""
	var actor: CombatSliceCharacterBinding = _find_binding(bindings, actor_id)
	if actor == null:
		return &""
	var input: CombatActionSelectionInput = CombatSliceProjectionBuilder.build_action_selection_input(actor)
	var set: CombatActionSet = null if input == null else input.current_action_set()
	if set == null:
		return &""
	for action: CombatActionDefinition in set.actions():
		if action.action_id == action_id:
			return action.tag
	return &""


## The special an NPC announced for its next beat, "" when none.
func pending_special_label(actor_id: StringName) -> String:
	return _pending_labels.get(actor_id, "")


## The round's standing modifiers: the player's stance and chosen move, the NPCs' drawn
## moves (a 守 move guards its user this round; the counter ring reads the tags).
func _fill_modifiers(bindings: Array[CombatSliceCharacterBinding]) -> void:
	_modifiers.clear()
	var bonus: int = GameContent.catalog().pacing().combat_rules().action_tag_bonus_percent
	if not _player_id.is_empty():
		var mine: CombatRoundModifiers.Fighter = _modifiers.side(_player_id)
		if _decisions.has_stances():
			CombatStance.apply(mine, BattlePace.stance, _decisions.stance_percent)
		mine.move_tag = _player_choice_tag
		if _player_choice_tag == CombatMoveTags.GUARD:
			mine.add(0, 0, bonus, bonus)
	for actor_id: StringName in _next_moves:
		var tag: StringName = next_move_tag(actor_id, bindings)
		if tag.is_empty():
			continue
		var theirs: CombatRoundModifiers.Fighter = _modifiers.side(actor_id)
		theirs.move_tag = tag
		if tag == CombatMoveTags.GUARD:
			theirs.add(0, 0, bonus, bonus)


## npc_telegraph: the NPC's next ordinary move drawn now, one beat early, so its tag can
## be shown; taken without a draw on its next attack (CombatActionSelector).
func _draw_next_move(actor: CombatSliceCharacterBinding, random_source: CombatRandomSource) -> void:
	_next_moves.erase(actor.character_id)
	if not _decisions.npc_telegraph or actor.is_user or actor.life_status != CombatSliceLifeStatus.Value.ACTIVE or not actor.relationship.is_fighting():
		return
	var input: CombatActionSelectionInput = CombatSliceProjectionBuilder.build_action_selection_input(actor)
	var selection: CombatActionSelectionResult = CombatActionSelector.select_action(input, random_source)
	if selection.succeeded:
		_next_moves[actor.character_id] = selection.selected_action.action_id


## The pending special of `actor`, run before its chat on this beat (or dropped with its
## line when the player's feint or perform struck it meanwhile), as an NPC_CHAT event.
func _run_pending_special(
	actor: CombatSliceCharacterBinding,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
) -> CombatSchedulerEvent:
	if _npc_chat == null or not _pending_specials.has(actor.character_id):
		return null
	var action: NpcSpecialAction = _pending_specials[actor.character_id]
	var label: String = _pending_labels.get(actor.character_id, "")
	_pending_specials.erase(actor.character_id)
	_pending_labels.erase(actor.character_id)
	var result: CombatNpcChatResult = null
	if _interrupted.get(actor.character_id, false):
		# TRANSLATORS: an NPC's announced special is lost: {npc} its name, {move} the special's name.
		var line: String = TranslationServer.translate("{npc}的{move}被打断了。").format({"npc": TranslationServer.translate(_shown_name(actor)), "move": label})
		result = CombatNpcChatResult.new([VisionLine.new(line, actor.character_id, &"", ColoredLine.HIC)])
	elif actor.life_status == CombatSliceLifeStatus.Value.ACTIVE and actor.relationship.is_fighting() and not actor.busy.is_busy():
		var sides: Array = _sides_of(actor, bindings)
		result = _npc_chat.run_special(actor, action, sides[0], sides[1], random_source, effect_registry, _modifiers)
	_interrupted.erase(actor.character_id)
	if result == null:
		return null
	return CombatSchedulerEvent.new(
		_next_event_sequence, _logical_cycle, logical_time_seconds, CombatSchedulerEvent.Kind.NPC_CHAT,
		CombatSchedulerEvent.SkipReason.NONE, actor.character_id, &"", null, _progression_order.take(), result,
	)


func _shown_name(actor: CombatSliceCharacterBinding) -> String:
	return _npc_chat.display_name_of(actor.character_id) if _npc_chat != null else String(actor.character_id)


## The actor's enemies it may still target (its order) and everyone else in the fight.
func _sides_of(actor: CombatSliceCharacterBinding, bindings: Array[CombatSliceCharacterBinding]) -> Array:
	var enemies: Array[CombatSliceCharacterBinding] = []
	for target_id: StringName in actor.relationship.opponent_ids():
		if _target_is_currently_eligible(actor, target_id, bindings):
			enemies.append(_find_binding(bindings, target_id))
	var others: Array[CombatSliceCharacterBinding] = []
	for binding: CombatSliceCharacterBinding in bindings:
		if binding != actor:
			others.append(binding)
	return [enemies, others]


## The blows the player landed on others this round: a feint or a perform that lands
## interrupts the victim's announced special.
func _note_interrupts(blows: Array, feint: bool) -> void:
	if not feint:
		return
	for blow: Array in blows:
		if blow[0] != _player_id:
			_interrupted[blow[0]] = true


func player_tactics() -> CombatTacticalRuntime:
	return _tactical


## NPCs' npc.c chat() in the fight, configured once before the first advance.
func configure_npc_chat(chat: CombatNpcChat) -> bool:
	if _npc_chat != null or _accumulated_input_seconds != 0.0 or chat == null:
		return false
	_npc_chat = chat
	_npc_chat.telegraph = _decisions.npc_telegraph
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


## The player may pick `target_id`; one they cannot see (a ghost: char.c visible(), name.c
## id()) cannot be named, though fight() may still turn on it.
func can_target(actor_id: StringName, target_id: StringName, bindings: Array[CombatSliceCharacterBinding]) -> bool:
	var actor: CombatSliceCharacterBinding = _find_binding(bindings, actor_id)
	var target: CombatSliceCharacterBinding = _find_binding(bindings, target_id)
	return (
		actor != null and actor.exists_in_encounter and actor.combat_available
		and actor.life_status == CombatSliceLifeStatus.Value.ACTIVE
		and _target_is_currently_eligible(actor, target_id, bindings)
		and actor.sees(target)
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
	if tactical_result != null and tactical_result.special != null:
		var special_blows: Array = _report_blows(tactical_result.special)
		_note_interrupts(special_blows, true)
		_hurts(special_blows, bindings, random_source, boundary)
	# An NPC the action sent away (meloner.c do_return()) walks out of the fight.
	if boundary != null and tactical_result != null:
		var walked: Dictionary[StringName, StringName] = tactical_result.walk_outs()
		for character_id: StringName in walked:
			boundary.depart(bindings, character_id, walked[character_id])
	# A perform's attacks fell nobody yet: char.c heart_beat() does, here.
	if boundary != null and not _inspect(boundary, bindings, null, tactical_result):
		return CombatSchedulerAdvanceResult.new()
	# 战斗决策层 1B: under player_turns the clock waits for the player's order; the enemies'
	# first moves are drawn now, so the first order is not made blind.
	if waiting_for_player(bindings):
		for binding: CombatSliceCharacterBinding in bindings:
			if not binding.is_user and not _next_moves.has(binding.character_id) and binding.exists_in_encounter:
				_draw_next_move(binding, random_source)
		return CombatSchedulerAdvanceResult.new(CombatSchedulerAdvanceResult.Outcome.WAITING_FOR_PLAYER)
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
		_fill_modifiers(bindings)
		if _tactical != null:
			_tactical.note_round()
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
				if event.kind == CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED and event.resolution != null:
					var blows: Array = _blows(event.resolution.forward_result, event.resolution.chain_result)
					if participant.participant_id == _player_id:
						_note_interrupts(blows, _player_choice_tag == CombatMoveTags.FEINT)
						_player_choice = &""
						_player_choice_tag = &""
					emitted.append_array(_hurts(blows, bindings, random_source, boundary))
			if boundary != null and not _inspect(boundary, bindings, event):
				return CombatSchedulerAdvanceResult.new(
					CombatSchedulerAdvanceResult.Outcome.ADVANCED, processed_cycles, emitted,
				)
			var npc_actor: CombatSliceCharacterBinding = _find_binding(bindings, participant.participant_id)
			if npc_actor != null and not npc_actor.is_user and event != null and event.kind == CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED:
				# Its announced special runs now, after its attack and before its chat.
				var pending: CombatSchedulerEvent = _run_pending_special(npc_actor, bindings, random_source, effect_registry)
				if pending != null:
					_events.append(pending)
					emitted.append(pending)
					_next_event_sequence += 1
					var ran: CombatNpcChatResult = pending.chat
					if ran != null and ran.special() != null:
						emitted.append_array(_hurts(_report_blows(ran.special()), bindings, random_source, boundary))
					if boundary != null and ran != null and not ran.joins().is_empty():
						boundary.admit(bindings, CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.APPLIED).with_joins(ran.joins()))
					if boundary != null and not _inspect(boundary, bindings, pending):
						return CombatSchedulerAdvanceResult.new(
							CombatSchedulerAdvanceResult.Outcome.ADVANCED, processed_cycles, emitted,
						)
				# Its next ordinary move, drawn one beat early (npc_telegraph).
				_draw_next_move(npc_actor, random_source)
			var chat: CombatSchedulerEvent = _chat_after(event, bindings, random_source, effect_registry)
			if chat == null:
				continue
			_events.append(chat)
			emitted.append(chat)
			_next_event_sequence += 1
			if chat.chat != null and chat.chat.telegraph() != null:
				_pending_specials[chat.actor_id] = chat.chat.telegraph()
				_pending_labels[chat.actor_id] = chat.chat.telegraph_label()
				_interrupted.erase(chat.actor_id)
			# ask_for_help(): the partner's kill_ob() brings it in before anyone acts on.
			var said: CombatNpcChatResult = chat.chat
			if said != null and said.special() != null:
				emitted.append_array(_hurts(_report_blows(said.special()), bindings, random_source, boundary))
			if boundary != null and said != null and not said.joins().is_empty():
				boundary.admit(bindings, CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.APPLIED).with_joins(said.joins()))
			# go.c: the NPC walked out of the room and out of the fight.
			if boundary != null and said != null and not said.departure_zone_id().is_empty():
				boundary.depart(bindings, chat.actor_id, said.departure_zone_id())
			if boundary != null and not _inspect(boundary, bindings, chat):
				return CombatSchedulerAdvanceResult.new(
					CombatSchedulerAdvanceResult.Outcome.ADVANCED, processed_cycles, emitted,
				)
	if manual() and processed_cycles > 0:
		# The order's round ran: the clock waits for the next.
		_round_open = false
		_player_choice = &""
		_player_choice_tag = &""
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
	# The player's chosen move, or the NPC's move drawn a beat early: taken without a draw.
	var chosen: StringName = _player_choice if actor.is_user else _next_moves.get(actor.character_id, &"")
	_next_moves.erase(actor.character_id)
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
				chosen,
				_modifiers,
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
			chosen,
			_modifiers,
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


## A perform or spell file's remove_effect() for an entry that ended this round
## (fakefault.c's strike, astral_vision.c's line), as an event, or null when it showed
## and did nothing.
func _remove_effect(
	ended: EndedEffect,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
) -> CombatSchedulerEvent:
	var function: PerformFunction = SpecialFunctions.ending(ended.entry.effect_id)
	var spell: CastFunction = SpecialFunctions.cast_ending(ended.entry.effect_id)
	if function == null and spell == null:
		return null
	var context: SpecialContext = CombatSpecialAttackSource.context_for(ended.binding, bindings, random_source, effect_registry, _modifiers)
	context.target = context.other(ended.entry.target_id)
	if function != null:
		function.remove_effect(context, ended.entry)
	else:
		spell.remove_effect(context, ended.entry)
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


## An NPC's own receive_damage() (NpcHooks: oldman.c) for each of `blows` ([victim, kee
## damage]) that reached a hooked NPC still standing: its lines, its walk out of the fight, a
## pill (CombatNpcChat.hurt()), recorded as they happen. It runs inside the blow in ES2:
## before combatd.c ends a spar on it and before char.c heart_beat() fells anyone, so the
## caller inspects the fight after these.
func _hurts(
	blows: Array,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	boundary: CombatOpportunityBoundary,
) -> Array[CombatSchedulerEvent]:
	var felt: Array[CombatSchedulerEvent] = []
	if _npc_chat == null:
		return felt
	for blow: Array in blows:
		var victim: CombatSliceCharacterBinding = _find_binding(bindings, blow[0])
		if victim == null or victim.life_status != CombatSliceLifeStatus.Value.ACTIVE:
			continue
		var result: CombatNpcChatResult = _npc_chat.hurt(victim, blow[1], random_source)
		if result == null:
			continue
		var hurt := CombatSchedulerEvent.new(
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
		_events.append(hurt)
		_next_event_sequence += 1
		felt.append(hurt)
		if boundary != null and not result.departure_zone_id().is_empty():
			boundary.depart(bindings, victim.character_id, result.departure_zone_id())
	return felt


## The kee each hit of an attack (and its chain's reverse blow) drew: [victim, damage].
static func _blows(forward: CombatSingleAttackExecutionResult, chain: CombatAttackChainResult) -> Array:
	var blows: Array = []
	if forward != null:
		blows.append(_blow(forward.ordinary_attack_result))
	if chain != null and chain.reverse_execution_reached:
		blows.append(_blow(chain.reverse_ordinary_result))
	return blows.filter(func(blow: Array) -> bool: return not blow.is_empty())


## A special file's attacks' blows, then those it hurt itself (a spell: no kee damage known,
## the pill still checked).
static func _report_blows(report: SpecialReport) -> Array:
	var blows: Array = []
	for attack: SpecialAttack in report.attacks():
		blows.append_array(_blows(attack.forward, attack.chain))
	for character_id: StringName in report.damaged():
		blows.append([character_id, 0])
	return blows


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
	var chosen: StringName = _next_moves.get(actor.character_id, &"")
	_next_moves.erase(actor.character_id)
	var resolution: CombatSliceOpportunityResult = CombatSliceOpportunityExecutor.execute_opportunity(
		actor, bindings, random_source, effect_registry, &"", chosen, _modifiers,
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
