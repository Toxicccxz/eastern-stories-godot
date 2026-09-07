extends "res://tests/runtime/battle_presentation_test.gd"

const Multi := preload("res://tests/support/cxr7_session_fixture.gd")

class MaximumRandom extends CombatRandomSource:
	var calls: int = 0
	func next_below(bound: int) -> int:
		calls += 1
		return bound - 1 if bound > 0 else -1

class ReverseBoundary extends CombatOpportunityBoundary:
	var observed: CombatSchedulerEvent
	var required: CombatSliceOpportunityResult
	func inspect(bindings: Array[CombatSliceCharacterBinding], event: CombatSchedulerEvent = null) -> bool:
		if event == null:
			return true
		observed = event
		required = CombatSliceOpportunityExecutor.inspect_lifecycle(bindings[0])
		return false

func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _entry(tree)
	await _multi_death(tree)
	await _failure(tree)
	await _spar(tree)
	await _player_terminal(tree)
	_reverse_chain_boundary()
	await _spar_mortal_failure(tree)
	return {"assertions": _assertions, "failures": _failures.duplicate()}

func _reverse_chain_boundary() -> void:
	var fixture: RefCounted = preload("res://tests/runtime/combat_slice_opportunity_integration_test.gd").new()
	var pair: Array[CombatSliceCharacterBinding] = fixture._initiated_pair()
	pair[0].state.skills.set_raw_level(&"sword", 20)
	pair[0].state.vitality.current = 20
	pair[1].relationship.set_guarding(true)
	var candidates: Array[CombatTriggerCandidate] = []
	var participants: Array[CombatParticipant] = []
	for index: int in 2:
		var binding: CombatSliceCharacterBinding = pair[index]
		var side := StringName("side%d" % index)
		candidates.append(CombatTriggerCandidate.new(binding.character_id, side))
		participants.append(CombatParticipant.new(binding.character_id, side, CombatEncounterAuthorityBinding.new(binding.character_id, binding.state, binding.relationship, binding.busy, binding.armor)))
	var location := WorldLocationState.new(&"r", &"m", &"z", &"c")
	var trigger := CombatTrigger.new(&"reverse", CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK, CombatEncounterMode.Value.LETHAL, pair[0].character_id, candidates, location)
	var hostilities: Array[CombatDirectedHostility] = [CombatDirectedHostility.new(&"side0", &"side1"), CombatDirectedHostility.new(&"side1", &"side0")]
	var encounter := CombatEncounter.new(&"reverse", trigger, participants, hostilities)
	_check(encounter.activate(), "reverse boundary fixture activation")
	var scheduler := CombatEncounterScheduler.new(encounter, CombatSchedulerConfig.new(1))
	var boundary := ReverseBoundary.new()
	# LPC-derived audited sequence, without legacy random-opponent selection draw.
	var random := preload("res://tests/support/scripted_combat_random_source.gd").new([0, 0, 0, 0, 51, 0, 0, 0, 10, 10, 0, 0, 0, 0, 0])
	var registry := SkillImprovementEffectRegistry.new()
	registry.register_legacy_defaults()
	var receipt: CombatSchedulerAdvanceResult = scheduler.advance(1000, true, encounter.encounter_id, pair, random, registry, boundary)
	_check(receipt.events().size() == 1, "outer barrier prevents next actor and next cycle in large delta")
	_check(boundary.observed.resolution.chain_result.outcome == CombatAttackChainResult.Outcome.REVERSE_COMPLETE, "boundary sees completed forward and reverse")
	_check(pair[0].state.vitality.current == -1, "audited reverse damage 21 crosses current20 to -1")
	_check(boundary.required != null and boundary.required.outcome == CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_UNCONSCIOUS, "threshold only consumed after full reverse chain")
	_check(random.call_count() == 15, "exact shared forward/reverse RNG count; no post-boundary draw")

func _spar_mortal_failure(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = _new_session(tree)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.start(Multi.trigger(session, CombatEncounterMode.Value.SPAR, CombatTriggerCause.Value.PLAYER_SPAR, &"mortal-spar")).succeeded(), "mortal SPAR setup")
	session.outdoor_map().npc_runtimes()[0].character_state.vitality.effective = -1
	coordinator.advance_scheduler(100)
	_check(coordinator.resolution().failure == CombatEncounterResolution.Failure.SPAR_MORTAL_WOUND, "armed-friendly death conflict explicitly blocked")
	_check(session.outdoor_map().corpse_states().is_empty() and coordinator.has_active_encounter() and not session.world_simulation_gate().is_open(), "no SPAR corpse/clamp/false completion")
	_check(not OldPineSaveEligibility.inspect(session).allowed(), "unresolved SPAR cannot save")
	session.free()
	await _settle(tree, 2)

func _new_session(tree: SceneTree) -> OldPineWorldSessionController:
	var session: OldPineWorldSessionController = SessionScene.instantiate()
	tree.root.add_child(session)
	session.set_process(false)
	session.outdoor_map().set_process(false)
	return session

func _entry(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = _new_session(tree)
	var map: OldPineOutdoorController = session.outdoor_map()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var npc: NpcRuntimeState = map.npc_runtimes()[0]
	var rng := MaximumRandom.new()
	session.configure_combat_random_source(rng)
	_check(map.select_npc(npc.character_id), "select production NPC")
	_check(map.attack_selected().outcome != CombatSliceInitiationResult.Outcome.COMPLETED, "different location rejected")
	_check(not player.relationship.is_fighting() and not npc.relationship.is_fighting() and rng.calls == 0, "failed entry leaves relationships/resources/RNG untouched")
	npc.set_world_location(player.world_location())
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "production Attack cutover")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var encounter: CombatEncounter = coordinator.active_encounter()
	_check(encounter != null and encounter.mode == CombatEncounterMode.Value.LETHAL, "LETHAL encounter")
	_check(encounter.accepted_trigger().cause == CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK, "player cause")
	_check(encounter.participants().size() == 2 and coordinator.action_infos().is_empty(), "no proximity sweep / honest empty tactics")
	_check(not map.cadence_is_running() and not session.world_simulation_gate().is_open(), "one cadence / frozen world")
	_check(OldPineSaveEligibility.inspect(session).outcome == OldPineSaveEligibilityResult.Outcome.ACTIVE_COMBAT_ENCOUNTER, "explicit active Save block")
	player.relationship.clear_opponents_preserving_lethal_targets()
	_check(OldPineSaveEligibility.inspect(session).outcome == OldPineSaveEligibilityResult.Outcome.ACTIVE_COMBAT_ENCOUNTER, "Save block independent of old relationship predicate")
	player.relationship.add_opponent(npc.character_id)
	tree.paused = true
	coordinator.advance_scheduler(500)
	_check(coordinator.active_scheduler().logical_cycle == 0 and rng.calls == 0, "pause has no catch-up/RNG")
	tree.paused = false
	_check(map.attack_selected().outcome != CombatSliceInitiationResult.Outcome.COMPLETED, "no concurrent entry")
	var invalid := CombatEncounterResult.new(encounter.encounter_id, encounter.mode, CombatEncounterResultKind.Value.FLED, [], [], [&"not-a-participant"])
	_check(not coordinator.complete(invalid).succeeded(), "foreign terminal subject rejected")
	_check(encounter.phase == CombatEncounterLifecycle.Value.ACTIVE, "invalid completion cannot enter resolving or cancel queue")
	_check(Multi.finish(session), "controlled FLED remains supported")
	_check(not map.cadence_is_running(), "thaw cannot wake legacy cadence")
	session.free()
	await _settle(tree, 2)
	# Failed coordinator start after source relationship establishment restores exact order.
	session = _new_session(tree)
	map = session.outdoor_map()
	player = session.player_runtime()
	npc = map.npc_runtimes()[0]
	npc.set_world_location(player.world_location())
	player.relationship.add_opponent(npc.character_id)
	var before: Array[StringName] = player.relationship.opponent_ids()
	var bindings: Array[CombatSliceCharacterBinding] = map._build_participants()
	var receipt: CombatSliceInitiationResult = session.combat_encounter_coordinator().start_production(bindings[0], bindings[1], CombatTriggerCause.Value.NPC_AGGRESSION)
	_check(receipt.outcome == CombatSliceInitiationResult.Outcome.ENCOUNTER_START_FAILED, "mode/cause failure after attempted establishment")
	_check(player.relationship.opponent_ids() == before and player.relationship.lethal_target_ids().is_empty() and not npc.relationship.is_fighting(), "rollback exact prior ordered facts")
	_check(session.world_simulation_gate().is_open() and not map.cadence_is_running(), "rollback no hybrid state")
	player.relationship.clear_opponents_preserving_lethal_targets()
	map.aggression_adapter().enter_player_presence(npc, player, true)
	var aggression: Array[CombatSliceInitiationResult] = map.process_pending_aggression()
	_check(aggression.size() == 1 and aggression[0].outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "real aggression adapter entry")
	_check(session.combat_encounter_coordinator().active_encounter().accepted_trigger().cause == CombatTriggerCause.Value.NPC_AGGRESSION and not map.cadence_is_running(), "aggression cutover no old cadence")
	session.free()
	await _settle(tree, 2)

func _multi_death(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = _new_session(tree)
	var map: OldPineOutdoorController = session.outdoor_map()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var a: NpcRuntimeState = map.npc_runtimes()[0]
	var b: NpcRuntimeState = map.npc_runtimes()[1]
	var trigger: CombatTrigger = Multi.trigger(session, CombatEncounterMode.Value.LETHAL, CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK)
	player.relationship.mark_lethal_target(a.character_id)
	player.relationship.mark_lethal_target(b.character_id)
	a.relationship.mark_lethal_target(player.character_id)
	b.relationship.mark_lethal_target(player.character_id)
	var random := MaximumRandom.new()
	var durable_random: CombatRandomSource = session.combat_random_source()
	session.configure_combat_random_source(random)
	# Deterministic strong actor; these are test values, not authored balance.
	map.bandit_bodies[0].global_position = map.player_body.global_position
	map.bandit_bodies[1].global_position = map.player_body.global_position
	player.state.attributes.courage = 100000
	player.state.skills.set_raw_level(&"sword", 1000)
	player.state.progression.combat_experience = 1000000
	player.state.vitality = CharacterResourceState.new(100000, 100000, 100000)
	a.character_state.vitality = CharacterResourceState.new(1, 1, 220)
	b.character_state.vitality = CharacterResourceState.new(100000, 100000, 100000)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.start(trigger).succeeded(), "three-participant source relationship establishment")
	var encounter: CombatEncounter = coordinator.active_encounter()
	var scheduler: CombatEncounterScheduler = coordinator.active_scheduler()
	var first: CombatSchedulerAdvanceResult = coordinator.advance_scheduler(1)
	_check(first.events().size() > 0 and first.events()[0].resolution.outcome == CombatSliceOpportunityResult.Outcome.ATTACK_CHAIN_COMPLETE, "full ordinary chain precedes lifecycle")
	_check(a.life_status == CharacterRuntimeLifeStatus.Value.DEAD and not a.exists_in_map, "A death committed at same outer boundary")
	_check(map.corpse_states().size() == 1 and coordinator.has_active_encounter(), "one corpse, B keeps encounter active")
	_check(not coordinator.player_can_target(a.character_id), "dead A no longer targetable")
	var corpse_a: CorpseState = map.corpse_states()[0]
	var sword_id: StringName = a.loadout_items()[0].item_instance_id
	_check(session.inventory_state().is_direct_child(sword_id, ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse_a.corpse_item_instance_id)), "exact A sword in corpse")
	b.character_state.vitality = CharacterResourceState.new(1, 1, 100000)
	var second: CombatSchedulerAdvanceResult = coordinator.advance_scheduler(1000)
	_check(second.events().size() == 1 and second.events()[0].target_id == b.character_id, "large delta retarget B and stops immediately after lethal chain")
	_check(b.life_status == CharacterRuntimeLifeStatus.Value.DEAD and map.corpse_states().size() == 2, "B dies once before result")
	_check(not coordinator.has_active_encounter() and session.world_simulation_gate().is_open(), "world resumes only after all hostiles complete")
	_check(encounter.terminal_result != null and encounter.terminal_result.kind == CombatEncounterResultKind.Value.VICTORY, "collection result Victory")
	_check(not map.cadence_is_running(), "completion no old cadence")
	var calls: int = random.calls
	coordinator.advance_scheduler(1000)
	scheduler.advance(1000, true, encounter.encounter_id, [], random, SkillImprovementEffectRegistry.new())
	_check(random.calls == calls and map.corpse_states().size() == 2, "terminal monotonic no extra RNG/corpse")
	_check(OldPineSaveEligibility.inspect(session).allowed(), "normal eligibility restored after clean completion")
	# Return from the explicitly synthetic RNG to the preserved production stream
	# before the separate codec/restore test; not a claim of custom-RNG persistence.
	session.configure_combat_random_source(durable_random)
	var captured: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-09-07T00:00:00Z")
	_check(captured.succeeded(), "post-combat native snapshot: %s %s" % [captured.path, captured.detail])
	if captured.succeeded():
		var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(captured.snapshot, tree.root)
		_check(restored.outcome == OldPineWorldRestoreResult.Outcome.SUCCESS, "completed corpse graph restores: %s %s" % [restored.path, restored.detail])
		if restored.candidate != null:
			_check(not restored.candidate.combat_encounter_coordinator().has_active_encounter() and restored.candidate.combat_encounter_coordinator().active_scheduler() == null, "no active combat serialization/reconstruction")
			_check(restored.candidate.outdoor_map().corpse_states().size() == 2, "restore two corpses without NPC respawn")
			_check(restored.candidate.inventory_state().direct_parent(sword_id).same_identity(session.inventory_state().direct_parent(sword_id)), "exact item semantic ID/parent restored")
			_check(restored.candidate.player_runtime().state != player.state, "new graph, not duplicated active Session authority")
			restored.candidate.free()
	session.free()
	await _settle(tree, 2)

func _failure(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = _new_session(tree)
	Multi.register_probes(session) # Synthetic queue only; never production catalog.
	var map: OldPineOutdoorController = session.outdoor_map()
	var npc: NpcRuntimeState = map.npc_runtimes()[0]
	npc.set_world_location(session.player_runtime().world_location())
	map.select_npc(npc.character_id)
	map.attack_selected()
	var tactics: CombatTacticalRuntime = session.combat_encounter_coordinator().active_scheduler().player_tactics()
	var request := CombatTacticalRequest.new(&"pending-at-failure", session.combat_encounter_coordinator().active_encounter().encounter_id, session.player_runtime().character_id, &"qa.probe", CombatTacticalRequest.Category.MARTIAL_SPECIAL, npc.character_id)
	_check(session.combat_encounter_coordinator().submit_player_action(request).accepted(), "pending queue before lifecycle failure")
	# Existing item index seam: absent facts cause death inventory partial failure.
	map._item_index._items.erase(npc.loadout_items()[0].item_instance_id)
	npc.character_state.vitality.effective = -1
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var random := MaximumRandom.new()
	session.configure_combat_random_source(random)
	coordinator.advance_scheduler(100)
	_check(coordinator.resolution().failure == CombatEncounterResolution.Failure.LIFECYCLE_FAILED, "partial death typed failure")
	_check(coordinator.has_active_encounter() and not session.world_simulation_gate().is_open(), "failure retains frozen encounter")
	_check(coordinator.active_encounter().phase == CombatEncounterLifecycle.Value.RESOLVING and coordinator.active_encounter().terminal_result == null, "no false Victory")
	_check(not OldPineSaveEligibility.inspect(session).allowed() and map.lifecycle_is_pending(), "partial Save blocked")
	var count: int = map.corpse_states().size()
	coordinator.advance_scheduler(100)
	_check(random.calls == 0 and map.corpse_states().size() == count, "partial mutation never automatically retried")
	_check(not Multi.finish(session), "external completion cannot thaw failed lifecycle")
	_check(coordinator.active_encounter().queued_player_action() == null and tactics.events()[-1].kind == CombatTacticalEvent.Kind.CANCELLED, "failed resolution clears single queue with cancellation")
	var event_count: int = tactics.events().size()
	coordinator.advance_scheduler(100)
	_check(tactics.events().size() == event_count, "failure cancellation cannot repeat")
	session.free()
	await _settle(tree, 2)

func _spar(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = _new_session(tree)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var npc: NpcRuntimeState = session.outdoor_map().npc_runtimes()[0]
	npc.set_world_location(player.world_location())
	player.relationship.add_opponent(npc.character_id)
	npc.relationship.add_opponent(player.character_id)
	player.state.attributes.courage = 100000
	player.state.skills.set_raw_level(&"sword", 1000)
	player.state.progression.combat_experience = 1000000
	npc.character_state.vitality = CharacterResourceState.new(100000, 100000, 100000)
	var candidates: Array[CombatTriggerCandidate] = [CombatTriggerCandidate.new(player.character_id, &"a"), CombatTriggerCandidate.new(npc.character_id, &"b")]
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.start(CombatTrigger.new(&"spar", CombatTriggerCause.Value.PLAYER_SPAR, CombatEncounterMode.Value.SPAR, player.character_id, candidates, player.world_location())).succeeded(), "source-backed SPAR")
	var random := MaximumRandom.new()
	session.configure_combat_random_source(random)
	coordinator.advance_scheduler(100)
	_check(not coordinator.has_active_encounter(), "friendly positive hit ends SPAR without threshold invention")
	_check(npc.character_state.vitality.current > 0 and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and session.outdoor_map().corpse_states().is_empty(), "SPAR ends conscious with no corpse")
	_check(coordinator.last_completion().succeeded(), "SPAR completion receipt")
	session.free()
	await _settle(tree, 2)

func _player_terminal(tree: SceneTree) -> void:
	for mortal: bool in [false, true]:
		var session: OldPineWorldSessionController = _new_session(tree)
		var map: OldPineOutdoorController = session.outdoor_map()
		var player: WorldPlayerRuntimeState = session.player_runtime()
		var npc: NpcRuntimeState = map.npc_runtimes()[0]
		npc.set_world_location(player.world_location())
		map.select_npc(npc.character_id)
		map.attack_selected()
		player.state.vitality.current = -1
		if mortal:
			player.state.vitality.effective = -1
		var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
		var encounter: CombatEncounter = coordinator.active_encounter()
		coordinator.advance_scheduler(100)
		_check(not coordinator.has_active_encounter() and encounter.terminal_result != null and encounter.terminal_result.kind == CombatEncounterResultKind.Value.DEFEAT, "authoritative player defeat")
		_check(player.life_status == (CharacterRuntimeLifeStatus.Value.DEAD if mortal else CharacterRuntimeLifeStatus.Value.UNCONSCIOUS), "existing life status; no invented respawn")
		_check(map.corpse_states().size() == (1 if mortal else 0), "corpse only on actual death")
		_check(map.hud.player_vitality_text.text.begins_with("-1 / -1" if mortal else "0 /"), "returned world HUD refreshes authoritative post-lifecycle resources")
		session.free()
		await _settle(tree, 2)
