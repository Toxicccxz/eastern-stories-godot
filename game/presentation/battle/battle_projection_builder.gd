class_name BattleProjectionBuilder
extends RefCounted

## Sole read adapter. UI descendants receive values, never Session/Core references.
static func build(session: WorldSessionController) -> BattlePresentationProjection:
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
	for participant: CombatParticipant in encounter.participants():
		for binding: CombatSliceCharacterBinding in bindings:
			if binding.character_id != participant.participant_id:
				continue
			var state: CharacterState = binding.state
			participants.append(BattleParticipantProjection.new(
				binding.character_id, session.encounter_display_name(binding.character_id),
				participant.side_id, encounter.is_hostile(player_id, binding.character_id),
				encounter.current_target_for(binding.character_id),
				_resource(state.vitality), _resource(state.essence), _resource(state.spirit),
				_internal(state.recovery.inner_force), _internal(state.recovery.mana),
				_internal(state.recovery.atman), binding.busy.busy_value, binding.life_status,
				state.life_threshold(), binding.exists_in_encounter and binding.combat_available,
				coordinator.player_can_target(binding.character_id),
				state.gender, state.skills.mapped_skill(&"dodge"), state.attributes.force_factor,
			))
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
	return BattlePresentationProjection.new(
		encounter.encounter_id, encounter.mode, player_id, encounter.current_target_for(player_id),
		participants, actions,
		encounter.queued_player_action(),
		CombatQueuedAction.Status.EMPTY if tactical == null else tactical.queue_status(),
		-1 if coordinator.last_completion() == null else coordinator.last_completion().outcome,
		enforce_limit,
	)


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


static func _resource(state: CharacterResourceState) -> BattleResourceProjection:
	return BattleResourceProjection.new(state.current, state.effective, state.maximum)


static func _internal(state: CharacterInternalResourceState) -> BattleResourceProjection:
	return BattleResourceProjection.new(state.current, state.maximum, state.maximum)
