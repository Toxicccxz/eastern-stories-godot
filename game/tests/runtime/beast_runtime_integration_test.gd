extends RefCounted

const SessionScene := preload("res://scenes/world/oldpine/oldpine_world_session.tscn")
const Publication := preload("res://tests/runtime/bf4_serpent_publication.gd")
var _assertions: int = 0
var _failures: Array[String] = []
var _completed_cases: int = 0


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	for wounded: bool in [false, true]:
		await _run_case(tree, wounded)
	_eq(_completed_cases, 2, "both integration cases reached cleanup without script failure")
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _run_case(tree: SceneTree, wounded: bool) -> void:
	var session: OldPineWorldSessionController = SessionScene.instantiate()
	session.deterministic_npc_seed = true
	session.npc_seed = 37
	session.deterministic_combat_seed = true
	session.combat_seed = 38
	tree.root.add_child(session)
	await tree.process_frame
	var map: OldPineOutdoorController = session.outdoor_map()
	_eq(map.npc_runtimes().size(), 5, "normal bootstrap stays five humans")
	var capture: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-09-10T12:00:00Z")
	_eq(capture.outcome, OldPineWorldCaptureResult.Outcome.SUCCESS, "normal capture remains valid")
	_eq(capture.snapshot.items.item_records.size(), 12, "normal bootstrap stays twelve items")
	var qa: Publication = Publication.new()
	session.add_child(qa)
	_eq(qa.publish(session, wounded), true, "publish real source factory NPC")
	var npc: NpcRuntimeState = qa.npc
	_eq(map.map_character_state().find_npc(npc.character_id), npc, "same map membership authority")
	_eq(map.runtime_body_for_character(npc.character_id), qa.body, "same physical body")
	_eq(map.find_resident_npc(npc.character_id), npc, "same resident authority")
	_eq(session.resolve_encounter_binding(npc.character_id).state, npc.character_state, "same Character authority")
	_eq(session.encounter_display_name(npc.character_id), "黑冠巨蟒", "real presentation identity")
	_eq(npc.body_weight, 62000, "source Beast weight")
	_eq(npc.maximum_encumbrance, 200000, "common capacity")
	_eq(npc.age, 400, "source age")
	_eq(npc.character_state.vitality.maximum, 1800, "authored maximum retained")
	_eq(npc.loadout_items().size(), 0, "no fabricated loadout")
	_eq(map.register_npc_body(npc, qa.body, qa.body.get_node("AggressionPresence"), CombatSliceContentProfile.new()), false, "duplicate registration rejected")
	_eq(OldPineWorldSaveCapture.new().capture(session, &"test", "2026-09-10T12:00:00Z").outcome != OldPineWorldCaptureResult.Outcome.SUCCESS, true, "QA extra slot cannot become normal Save")
	_eq(OldPineSpawnDefinitions.all_spawns().size(), 3, "authored spawn groups unchanged")
	# Removal/republication is precondition work, before the actual approach.
	_eq(qa.remove_publication(), true, "controlled publication removable")
	await tree.process_frame
	_eq(map.npc_runtimes().size(), 5, "membership removed")
	_eq(map.map_character_state().has_character(npc.character_id), false, "map membership removed")
	qa.queue_free()
	await tree.process_frame
	qa = Publication.new()
	session.add_child(qa)
	_eq(qa.publish(session, wounded), true, "fresh publication repeatable")
	npc = qa.npc
	if wounded:
		_eq(qa.prepare_wounded_proof(), true, "owner-authorized fixed QA precondition")
		_eq(qa.prepare_wounded_proof(), false, "cannot reset script mid-run")
		_eq(qa.player_precondition.effective_strength, 200, "actual combat strength projection")
		_eq(qa.player_precondition.base_strength, 20, "base strength unchanged")
		_eq(qa.player_precondition.experience_before, 600, "normal starting experience unchanged")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	# Real physics input in automated integration; no Area callback/combat start.
	Input.action_press("move_right")
	for _frame: int in 100:
		await tree.physics_frame
		if coordinator.has_active_encounter():
			break
	Input.action_release("move_right")
	await tree.process_frame
	_eq(coordinator.has_active_encounter(), true, "physical approach triggers aggression entry")
	if not coordinator.has_active_encounter():
		session.free()
		return
	_eq(map.last_aggression_decisions()[0].outcome, OldPineAggressionDecision.Outcome.READY, "authored aggression READY")
	_eq(coordinator.active_encounter().participants().size(), 2, "existing pair topology")
	_eq(session.world_simulation_gate().is_open(), false, "world frozen")
	_eq(map.cadence_is_running(), false, "no parallel world attack timer")
	_eq(map.unregister_npc_body(npc.character_id), false, "active participant cannot be detached")
	var scheduler: CombatEncounterScheduler = coordinator.active_scheduler()
	_eq(scheduler != null and scheduler.is_valid(), true, "real scheduler")
	var bindings: Array[CombatSliceCharacterBinding] = session.encounter_combat_bindings(coordinator.active_encounter())
	var binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(bindings, npc.character_id)
	_eq(binding.content.limbs().size(), 3, "Beast profile, not human limbs")
	_eq(binding.content.intrinsic_armor, 90, "Beast intrinsic armor")
	# Accelerated typed boundary is automated evidence only, never live proof.
	coordinator.advance_scheduler(300.0)
	var bite_seen: bool = false
	for event: CombatSchedulerEvent in scheduler.events():
		if event.actor_id != npc.character_id or event.resolution == null or event.resolution.forward_result == null:
			continue
		var attack: CombatSingleAttackExecutionResult = event.resolution.forward_result
		if attack.selected_action_id == BeastCombatActionDefinitions.bite().action_id:
			bite_seen = true
			_eq(attack.action_selection_result.random_upper_bounds(), [1], "real single-verb selection draw")
	_eq(bite_seen, true, "source-fresh ordinary bite executed")
	_eq(coordinator.has_active_encounter(), false, "natural terminal ends encounter")
	_eq(coordinator.active_scheduler(), null, "scheduler released")
	_eq(session.world_simulation_gate().is_open(), true, "world reopened")
	if wounded:
		print("BF4 deterministic proof: ", qa.evidence())
		_eq(qa.proof_random.valid, true, "all scripted draws legal; no exhaustion")
		_eq(qa.proof_random.draws.size(), 16, "exact predetermined draw count")
		_eq(qa.proof_random.bounds, [60, 1, 16, 572000, 120, 30, 1, 3, 670500, 250001, 25, 200, 250000, 112, 120, 1799], "source-ordered courage/action/limb/dodge/progression then ordinary hit bounds")
		_eq(qa.proof_random.draws, [0, 0, 0, 0, 0, 0, 0, 0, 670499, 250000, 0, 0, 0, 91, 0, 1798], "fixed draws, not seeded retries")
		var lethal: CombatAttackResult = scheduler.events()[1].resolution.forward_result.ordinary_attack_result.base_result
		_eq(lethal.calculation.requested_damage, 112, "LPC (25+0)/2 + (200+0)/2")
		_eq(lethal.calculation.wound_amount, 22, "LPC 112 - armor 90")
		_eq(lethal.resource_mutation.vitality_effective_after, -1, "LPC negative effective saturates at -1")
		_eq(lethal.threshold_candidate, CombatAttackResult.ThresholdCandidate.DEATH, "resolver observes death, not injected lifecycle")
		_eq(map.last_lifecycle_results()[0].outcome, CombatSliceLifecycleResult.Outcome.DEATH_COMPLETE, "live lifecycle receipt completed")
		_eq(npc.character_state.progression.combat_experience, 250000, "script suppresses incidental progression, not rules")
		_eq(session.player_runtime().life_status, CharacterRuntimeLifeStatus.Value.ACTIVE, "QA proof player survives")
		_eq(npc.life_status, CharacterRuntimeLifeStatus.Value.DEAD, "wounded serpent dies through existing lifecycle")
		if npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			var corpse: CorpseState = map.corpse_states()[0]
			_eq(corpse.maximum_contents_encumbrance, 200000, "corpse capacity")
			_eq(session.inventory_state().own_weight(corpse.corpse_item_instance_id), 62000, "corpse body weight")
			_eq(corpse.victim_display_name, "黑冠巨蟒", "corpse authored identity")
			_eq(corpse.victim_gender, &"雄性", "corpse source gender")
			_eq(corpse.victim_age, 400, "corpse source age")
			_eq(session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id)).size(), 0, "corpse has no invented loot")
			_eq(map.corpse_view_for(corpse.corpse_item_instance_id) != null, true, "corpse published physically")
			_eq(qa.body.visible, false, "dead body not duplicated")
	session.free()
	await tree.process_frame
	_completed_cases += 1


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
