class_name BattleProjectionBuilder
extends RefCounted

## Sole read adapter. UI descendants receive values, never Session/Core references.
## `strengths`: character id -> BattleStrength, the 战前预判 the panel read once for each
## enemy when the fight began (DECISIONS「战斗界面」); left out, no card shows one.
static func build(session: WorldSessionController, strengths: Dictionary[StringName, BattleStrength] = {}) -> BattlePresentationProjection:
	if session == null or not session.is_initialized():
		return BattlePresentationProjection.new()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var encounter: CombatEncounter = coordinator.active_encounter()
	if not coordinator.has_active_encounter() or encounter.phase not in [
		CombatEncounterLifecycle.Value.ACTIVE, CombatEncounterLifecycle.Value.RESOLVING,
	]:
		return BattlePresentationProjection.new()
	var player_id: StringName = session.player_runtime().character_id
	var participants: Array[BattleParticipantProjection] = []
	var bindings: Array[CombatSliceCharacterBinding] = session.encounter_combat_bindings(encounter)
	var held: Array[StringName] = coordinator.held_victims()
	for participant: CombatParticipant in encounter.participants():
		# go.c: one who walked out of the fight is no longer in it.
		if coordinator.walked_out_of_active_fight(participant.participant_id):
			continue
		for binding: CombatSliceCharacterBinding in bindings:
			if binding.character_id != participant.participant_id:
				continue
			var state: CharacterState = binding.state
			var shown := BattleParticipantProjection.new(
				binding.character_id, session.encounter_display_name(binding.character_id),
				participant.side_id, encounter.is_hostile(player_id, binding.character_id),
				encounter.current_target_for(binding.character_id),
				_resource(state.vitality), _resource(state.essence), _resource(state.spirit),
				_internal(state.recovery.inner_force), _internal(state.recovery.mana),
				_internal(state.recovery.atman), binding.busy.busy_value, binding.life_status,
				state.life_threshold(), binding.exists_in_encounter and binding.combat_available,
				coordinator.player_can_target(binding.character_id),
				state.gender, state.skills.mapped_skill(&"dodge"), state.attributes.force_factor,
				_knockout(session, binding.character_id) if held.has(binding.character_id) else null,
			)
			if binding.character_id != player_id:
				shown.next_move_tag = coordinator.next_move_tag(binding.character_id)
				shown.telegraph = coordinator.pending_special_label(binding.character_id)
			shown.conditions = state.conditions.sorted_condition_ids()
			shown.has_spells = not state.skills.mapped_skill(SkillIds.SPELLS).is_empty()
			var strength: BattleStrength = strengths.get(binding.character_id)
			if strength != null and shown.hostile_to_player:
				shown.strength = strength.verdict
				shown.strength_line = strength.line
			participants.append(shown)
			break
	var scheduler: CombatEncounterScheduler = coordinator.active_scheduler()
	var tactical: CombatTacticalRuntime = null if scheduler == null else scheduler.player_tactics()
	var actions: Array[CombatTacticalActionInfo] = []
	if tactical != null:
		actions = coordinator.action_infos()
	# The 加力 row only while enforce.c can act: the player's own active fight, conscious.
	var enforce_limit: int = -1
	if session.martial_arts().in_own_fight() and not session.player_runtime().state.skills.mapped_skill(EnforceService.BASIC_FORCE).is_empty():
		enforce_limit = session.martial_arts().enforce_limit()
	# One held for 了结 / 放过 is nobody's target, whatever the fight last named.
	var current: StringName = encounter.current_target_for(player_id)
	if held.has(current):
		current = &""
	var projection := BattlePresentationProjection.new(
		encounter.encounter_id, encounter.mode, player_id, current,
		participants, actions,
		encounter.queued_player_action(),
		CombatQueuedAction.Status.EMPTY if tactical == null else tactical.queue_status(),
		-1 if coordinator.last_completion() == null else coordinator.last_completion().outcome,
		enforce_limit,
	)
	# 战斗决策层 1B: the player's turn, moves and stance (only in the player's own fight).
	if tactical != null:
		var rules: CombatDecisionRules = coordinator.decision_rules()
		projection.moves = coordinator.player_moves()
		projection.chosen_action_id = coordinator.player_choice()
		projection.waiting = coordinator.waiting_for_player()
		projection.turns_offered = rules.player_turns
		projection.manual = coordinator.manual_turns()
		projection.stances_offered = rules.has_stances()
		projection.stance = coordinator.stance()
	return projection


## A finished encounter the panel never projected: who the player is, and the
## names and genders of everyone its retained events mention, for its log.
static func completed_cast(session: WorldSessionController, encounter_id: StringName) -> BattlePresentationProjection:
	var player_id: StringName = session.player_runtime().character_id
	var ids: Array[StringName] = [player_id]
	var feedback: CombatCompletedFeedback = session.combat_encounter_coordinator().completed_feedback()
	if feedback != null and feedback.encounter_id == encounter_id:
		for event: CombatSchedulerEvent in feedback.ordinary_after(0):
			ids.append_array([event.actor_id, event.target_id])
		for ordered: CombatOrderedTargetEvent in feedback.targets_after(0):
			ids.append_array([ordered.event.actor_id, ordered.event.current_target_id])
	return cast_of(session, ids, encounter_id)


## The names, genders and dodge skills the narrator needs for `ids` (the player
## first), with no fight behind them: a do_attack() outside one, as champion.c's test.
static func cast_of(session: WorldSessionController, ids: Array[StringName], encounter_id: StringName = &"") -> BattlePresentationProjection:
	var player_id: StringName = session.player_runtime().character_id
	var participants: Array[BattleParticipantProjection] = []
	var seen: Array[StringName] = []
	for id: StringName in [player_id] + ids:
		if id.is_empty() or id in seen:
			continue
		seen.append(id)
		var none := BattleResourceProjection.new(0, 0, 0)
		participants.append(BattleParticipantProjection.new(
			id, session.encounter_display_name(id), &"", id != player_id, &"",
			none, none, none, none, none, none, 0, 0, 0, false, false, session.encounter_gender(id),
			session.encounter_dodge_skill(id),
		))
	return BattlePresentationProjection.new(encounter_id, -1, player_id, &"", participants)


## One held for 了结 / 放过: when they come to, and what killing them would mean.
static func _knockout(session: WorldSessionController, character_id: StringName) -> BattleKnockoutProjection:
	var map: WorldMapController = session.active_map() as WorldMapController
	var npc: NpcRuntimeState = null if map == null else map.find_resident_npc(character_id)
	if npc == null:
		return BattleKnockoutProjection.new()
	var player: CharacterState = session.player_runtime().state
	# The fight's clock in the real seconds the 战斗速度 makes of it; never 0 while it lies there.
	return BattleKnockoutProjection.new(
		maxi(1, ceili(BattlePace.real_seconds(npc.revive_in_ms / 1000.0))),
		PlayerKillerReward.is_quest_target(player, npc.definition()),
		PlayerKillerReward.is_own_master(player, npc.definition()),
	)


static func _resource(state: CharacterResourceState) -> BattleResourceProjection:
	return BattleResourceProjection.new(state.current, state.effective, state.maximum)


static func _internal(state: CharacterInternalResourceState) -> BattleResourceProjection:
	return BattleResourceProjection.new(state.current, state.maximum, state.maximum)
