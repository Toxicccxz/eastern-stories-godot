extends RefCounted

const SessionScene := preload("res://scenes/world/oldpine/oldpine_world_session.tscn")
const SaveFixture := preload("res://tests/support/oldpine_world_save_fixture.gd")
var _assertions: int = 0
var _failures: Array[String] = []

func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _authored_and_restore(tree)
	_feedback_failures()
	for seed_value: int in [103, 211, 509]:
		for npc_index: int in [0, 3, 4]:
			for experience: int in [10, 600]:
				await _authored_encounter(tree, seed_value, npc_index, experience)
	var closure: Dictionary[String, Variant] = await preload("res://tests/runtime/combat_flee_test.gd").new().run_all(tree)
	_assertions += closure["assertions"]
	_failures.append_array(closure["failures"])
	return {"assertions": _assertions, "failures": _failures.duplicate()}

func _session(tree: SceneTree, seed_value: int) -> OldPineWorldSessionController:
	var session: OldPineWorldSessionController = SessionScene.instantiate()
	# Production initialization/RNG adapters; ONLY the seeds are fixed here.
	session.deterministic_npc_seed = true
	session.npc_seed = 7021
	session.deterministic_combat_seed = true
	session.combat_seed = seed_value
	tree.root.add_child(session)
	session.set_process(false)
	session.outdoor_map().set_process(false)
	(session.get_node("BattlePresentationLayer/BattleSurface") as BattlePresentationController).set_process(false)
	return session

func _authored_and_restore(tree: SceneTree) -> void:
	var s: OldPineWorldSessionController = _session(tree, 103)
	var p: CharacterState = s.player_runtime().state
	_check(p.progression.combat_experience == 600, "Old Pine product bootstrap is exactly 600")
	_check(CombatSliceDemoFactory.create_player().state.progression.combat_experience == 10, "generic symmetric Phase 6 fixture stays 10")
	for attribute: String in ["strength", "courage", "intelligence", "spirituality", "composure", "personality", "constitution", "karma"]:
		_check(p.attributes.get(attribute) == 20, "unchanged authored base " + attribute)
	for resource: CharacterResourceState in [p.essence, p.vitality]:
		_check(resource.current == 220 and resource.effective == 220 and resource.maximum == 220, "unchanged gin/kee, no QA HP")
	_check(p.spirit.current == 100 and p.spirit.effective == 100 and p.spirit.maximum == 100, "unchanged sen")
	for id: StringName in [&"sword", &"dodge", &"parry", &"unarmed"]:
		_check(p.skills.raw_level(id) == 10, "unchanged raw " + String(id))
	_check(p.skills.raw_level(&"force") == 0 and p.skills.raw_level(&"perception") == 0, "no granted force/perception")
	_check(p.skills.enabled_use_ids().is_empty(), "no invented starter mapping")
	_check(p.recovery.inner_force.current == 0 and p.recovery.mana.current == 0 and p.recovery.atman.current == 0, "no internal-resource buff")
	_check(p.equipment.primary_weapon().weapon_id == CombatSliceContentProfile.LONG_SWORD_ID, "unchanged starting sword")
	_check(s.inventory_state().registered_item_ids().size() == 12, "unchanged twelve bootstrap items")
	_check(s.combat_encounter_coordinator().action_infos().size() == 1 and s.combat_encounter_coordinator().action_infos()[0].action_id == CombatFleeTacticalPolicy.ACTION_ID, "one real production Flee, no invented starter technique")
	_check(s.encounter_opportunity_interval_seconds() == 1.0, "unchanged one-second opportunity configuration")
	_check(s.outdoor_map().opportunity_timer.is_stopped(), "old cadence Timer remains non-production")
	var exp_values: Array[int] = [600, 600, 600, 900, 500]
	var sword_values: Array[int] = [10, 10, 10, 15, 20]
	for i: int in 5:
		var n: CharacterState = s.outdoor_map().npc_runtimes()[i].character_state
		_check(n.progression.combat_experience == exp_values[i], "LPC NPC experience unchanged")
		_check(n.skills.raw_level(&"sword") == sword_values[i], "LPC NPC sword unchanged")
		_check(n.vitality.maximum == (200 if i < 3 else 220), "NPC resource unchanged")
	# Independent literal expectations from combatd::skill_power staged divisions:
	# (5^3)/3/100*100 = 0; the following experience is the entire result.
	_check(CombatMath.skill_power(CombatSkillPowerInput.new(true, 5, 0, 10, 100, 100)) == 10, "legacy prototype power exact")
	_check(CombatMath.skill_power(CombatSkillPowerInput.new(true, 5, 0, 600, 100, 100)) == 600, "new entry power exact, not a formula adjustment")
	# A saved pre-CXR9 player must NOT be silently upgraded by New Game policy.
	p.progression.combat_experience = 10
	var snapshot: GameSaveSnapshot = SaveFixture.from_new_game(s)
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(snapshot, tree.root)
	_check(restored.succeeded(), "pre-adjustment experience snapshot restores")
	if restored.candidate != null:
		_check(restored.candidate.player_runtime().state.progression.combat_experience == 10, "RESTORE preserves saved 10 exactly")
		restored.candidate.free()
	s.free()
	await tree.process_frame

func _feedback_failures() -> void:
	var terminal := CombatEncounterResult.new(&"test", CombatEncounterMode.Value.LETHAL, CombatEncounterResultKind.Value.VICTORY)
	for outcome: int in CombatEncounterCompletionResult.Outcome.values():
		var receipt := CombatEncounterCompletionResult.new(outcome, &"test", terminal)
		_check(BattleFeedbackReader.completion_text(receipt, CharacterRuntimeLifeStatus.Value.ACTIVE).is_empty() == (outcome != CombatEncounterCompletionResult.Outcome.COMPLETED), "never advertise victory before successful world return")
	_check(BattleFeedbackReader.completion_text(null, 0).is_empty(), "no receipt no result")
	var fled := CombatEncounterResult.new(&"flee", CombatEncounterMode.Value.LETHAL, CombatEncounterResultKind.Value.FLED)
	for outcome: int in CombatEncounterCompletionResult.Outcome.values():
		var receipt := CombatEncounterCompletionResult.new(outcome, &"flee", fled)
		_check(BattleFeedbackReader.completion_text(receipt, CharacterRuntimeLifeStatus.Value.ACTIVE).begins_with("Escaped") == (outcome == CombatEncounterCompletionResult.Outcome.COMPLETED), "FLED never advertises escape on failed world return")
	var spar := CombatEncounterCompletionResult.new(CombatEncounterCompletionResult.Outcome.COMPLETED, &"spar", CombatEncounterResult.new(&"spar", CombatEncounterMode.Value.SPAR, CombatEncounterResultKind.Value.SPAR_CONCLUDED))
	_check(BattleFeedbackReader.completion_text(spar, 0).begins_with("Spar concluded"), "SPAR text never implies kill/loot")

func _authored_encounter(tree: SceneTree, seed_value: int, npc_index: int, experience: int) -> void:
	var s: OldPineWorldSessionController = _session(tree, seed_value)
	var map: OldPineOutdoorController = s.outdoor_map()
	var p: WorldPlayerRuntimeState = s.player_runtime()
	var npc: NpcRuntimeState = map.npc_runtimes()[npc_index]
	# Counterfactual before/after experience ONLY. This is a deterministic typed
	# boundary test, not claimed real-player acceptance or production QA setup.
	p.state.progression.combat_experience = experience
	p.set_world_location(npc.world_location())
	map.select_npc(npc.character_id)
	var entry: CombatSliceInitiationResult = map.attack_selected()
	_check(entry.outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "authored-state production entry")
	var c: CombatEncounterCoordinator = s.combat_encounter_coordinator()
	var scheduler: CombatEncounterScheduler = c.active_scheduler()
	var ui: BattlePresentationController = s.get_node("BattlePresentationLayer/BattleSurface")
	ui.refresh_projection()
	var count: int = 0
	while c.has_active_encounter() and count < 300:
		c.advance_scheduler(1.0)
		count += 1
		if c.resolution().failure != CombatEncounterResolution.Failure.NONE:
			break
	_check(not c.has_active_encounter(), "representative battle terminates without stuck resolution")
	_check(c.last_completion() != null and c.last_completion().succeeded(), "successful authoritative world return")
	_check(s.world_simulation_gate().is_open(), "same world thawed")
	_check(scheduler.player_tactics().events().is_empty(), "authored ordinary sword battle produces no special/telegraph tactical events")
	var hp_before: int = p.state.vitality.current
	var exp_before: int = p.state.progression.combat_experience
	var rng_before: RandomStreamSnapshot = s.combat_random_source().capture_random_state()
	ui.refresh_projection()
	var lines: Array[String] = map.hud.log_lines()
	ui.refresh_projection()
	_check(map.hud.log_lines() == lines, "result shown exactly once")
	_check(not lines.is_empty() and (lines[-1].begins_with("Victory") or lines[-1].begins_with("Defeat")), "result visible in world HUD")
	_check(map.hud.world_title.text.ends_with(" — see Details"), "result remains visible even when compact Details is closed")
	_check(not map.hud._presentation_layout._details_open, "result does not open a movement-blocking Details overlay")
	_check(p.state.vitality.current == hp_before and p.state.progression.combat_experience == exp_before, "presentation cannot mutate resources/progression")
	_check(s.combat_random_source().capture_random_state().state == rng_before.state, "presentation consumes zero RNG")
	var result_kind: int = c.last_completion().terminal_result.kind if c.last_completion() != null else -1
	# This emits evidence, NOT an arbitrary required win-rate or guaranteed win.
	print("CXR9_MATRIX seed=%d npc=%d exp=%d cycles=%d result=%d player=%d/%d enemy=%d/%d opportunities=%d" % [seed_value, npc_index, experience, count, result_kind, p.state.vitality.current, p.state.vitality.effective, npc.character_state.vitality.current, npc.character_state.vitality.effective, scheduler.events().size()])
	s.free()
	await tree.process_frame

func _check(value: bool, message: String) -> void:
	_assertions += 1
	if not value:
		_failures.append("CXR9: " + message)
