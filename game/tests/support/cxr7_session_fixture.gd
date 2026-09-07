extends "res://tests/support/cxr6_session_fixture.gd"


static func trigger(session: OldPineWorldSessionController, mode: int, cause: int, id: StringName = &"cxr7", npc_initiator: bool = false) -> CombatTrigger:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var candidates: Array[CombatTriggerCandidate] = [CombatTriggerCandidate.new(player.character_id, &"A")]
	for index: int in 2:
		var npc: NpcRuntimeState = session.outdoor_map().npc_runtimes()[index]
		npc.set_world_location(player.world_location()) # QA setup, not physical traversal evidence.
		player.relationship.add_opponent(npc.character_id)
		npc.relationship.add_opponent(player.character_id)
		candidates.append(CombatTriggerCandidate.new(npc.character_id, &"B" if index == 0 else &"C"))
	var initiator: StringName = candidates[1].participant_id if npc_initiator else player.character_id
	return CombatTrigger.new(id, cause, mode, initiator, candidates, player.world_location(), &"cxr7.qa")


static func finish(session: OldPineWorldSessionController) -> bool:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var encounter: CombatEncounter = coordinator.active_encounter()
	if encounter == null:
		return false
	var scripted: bool = encounter.mode == CombatEncounterMode.Value.SCRIPTED
	var subjects: Array[StringName] = []
	if not scripted:
		subjects.append(session.player_runtime().character_id)
	return coordinator.complete(CombatEncounterResult.new(encounter.encounter_id, encounter.mode,
		CombatEncounterResultKind.Value.SCRIPTED if scripted else CombatEncounterResultKind.Value.FLED,
		[], [], subjects, &"cxr7.qa.cleanup" if scripted else &"",
	)).succeeded()
