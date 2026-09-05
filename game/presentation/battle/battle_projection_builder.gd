class_name BattleProjectionBuilder
extends RefCounted

## Sole read adapter. UI descendants receive values, never Session/Core references.
static func build(session: OldPineWorldSessionController) -> BattlePresentationProjection:
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
			))
			break
	var scheduler: CombatEncounterScheduler = coordinator.active_scheduler()
	var tactical: CombatTacticalRuntime = null if scheduler == null else scheduler.player_tactics()
	return BattlePresentationProjection.new(
		encounter.encounter_id, encounter.mode, player_id, encounter.current_target_for(player_id),
		participants, [] if tactical == null else coordinator.action_infos(),
		encounter.queued_player_action(),
		CombatQueuedAction.Status.EMPTY if tactical == null else tactical.queue_status(),
	)


static func _resource(state: CharacterResourceState) -> BattleResourceProjection:
	return BattleResourceProjection.new(state.current, state.effective, state.maximum)


static func _internal(state: CharacterInternalResourceState) -> BattleResourceProjection:
	return BattleResourceProjection.new(state.current, state.maximum, state.maximum)
