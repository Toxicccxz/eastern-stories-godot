extends "res://tests/support/cxr6_session_fixture.gd"


static func trigger(session: OldPineWorldSessionController, mode: int, cause: int, id: StringName = &"cxr7", npc_initiator: bool = false) -> CombatTrigger:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	# Supported V1 SPAR fixture explicitly unwields; production never auto-unwields.
	if mode == CombatEncounterMode.Value.SPAR:
		_unarm(player.state.equipment)
	var candidates: Array[CombatTriggerCandidate] = [CombatTriggerCandidate.new(player.character_id, &"A")]
	for index: int in 2:
		var npc: NpcRuntimeState = session.outdoor_map().npc_runtimes()[index]
		if mode == CombatEncounterMode.Value.SPAR:
			_unarm(npc.character_state.equipment)
		npc.set_world_location(player.world_location()) # QA setup, not physical traversal evidence.
		player.relationship.add_opponent(npc.character_id)
		npc.relationship.add_opponent(player.character_id)
		candidates.append(CombatTriggerCandidate.new(npc.character_id, &"B" if index == 0 else &"C"))
	var initiator: StringName = candidates[1].participant_id if npc_initiator else player.character_id
	return CombatTrigger.new(id, cause, mode, initiator, candidates, player.world_location(), &"cxr7.qa")


static func finish(session: OldPineWorldSessionController) -> bool:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var encounter: CombatEncounter = coordinator.active_encounter()
	if encounter == null or encounter.phase != CombatEncounterLifecycle.Value.ACTIVE:
		return false
	var scripted: bool = encounter.mode == CombatEncounterMode.Value.SCRIPTED
	if not scripted:
		var request := CombatTacticalRequest.new(&"qa.cleanup.flee", encounter.encounter_id,
			session.player_runtime().character_id, CombatFleeTacticalPolicy.ACTION_ID, CombatTacticalRequest.Category.FLEE)
		if not coordinator.submit_player_action(request).accepted():
			return false
		coordinator.advance_scheduler(0.0)
		return coordinator.last_completion() != null and coordinator.last_completion().succeeded()
	var subjects: Array[StringName] = []
	if not scripted:
		subjects.append(session.player_runtime().character_id)
	return coordinator.complete(CombatEncounterResult.new(encounter.encounter_id, encounter.mode,
		CombatEncounterResultKind.Value.SCRIPTED if scripted else CombatEncounterResultKind.Value.FLED,
		[], [], subjects, &"cxr7.qa.cleanup" if scripted else &"",
	)).succeeded()

static func _unarm(equipment: EquipmentState) -> void:
	for weapon: EquippedWeaponRef in [equipment.primary_weapon(), equipment.secondary_weapon()]:
		if weapon != null:
			equipment.unwield(weapon.instance_id)
