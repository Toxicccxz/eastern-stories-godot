extends "res://tests/runtime/battle_presentation_test.gd"

const Multi := preload("res://tests/support/cxr7_session_fixture.gd")
const TC := CombatTargetResult.Code


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _targets(tree)
	await _modes(tree)
	await _target_ui(tree)
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _targets(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = SessionScene.instantiate()
	tree.root.add_child(session)
	session.set_process(false)
	var random := Setup.CountingRandom.new()
	session.configure_combat_random_source(random)
	Multi.register_probes(session)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.start(Multi.trigger(session, CombatEncounterMode.Value.SCRIPTED, CombatTriggerCause.Value.SCRIPTED)).succeeded(), "three-side encounter")
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var a: NpcRuntimeState = session.outdoor_map().npc_runtimes()[0]
	var b: NpcRuntimeState = session.outdoor_map().npc_runtimes()[1]
	var encounter: CombatEncounter = coordinator.active_encounter()
	var scheduler: CombatEncounterScheduler = coordinator.active_scheduler()
	var intent := BattleIntentAdapter.new(coordinator, player.character_id)
	_check(intent.change_target(encounter.encounter_id, a.character_id).code == TC.CHANGED, "explicit A")
	player.busy.start_busy(2)
	_check(intent.submit(&"qa.probe", a.character_id).accepted(), "queue A")
	var queued: CombatQueuedAction = encounter.queued_player_action()
	var force_before: int = player.state.recovery.inner_force.current
	var vitality: int = a.character_state.vitality.current
	var event_count: int = encounter.events().size()
	_check(intent.change_target(encounter.encounter_id, b.character_id).code == TC.CHANGED, "busy permits B")
	_check(encounter.events().size() == event_count + 1, "one Core event")
	var event: CombatEncounterEvent = encounter.latest_event()
	_check(event.kind == CombatEncounterEventKind.Value.TARGET_CHANGED and event.previous_target_id == a.character_id and event.current_target_id == b.character_id, "typed old/new event")
	_check(encounter.queued_player_action().resolved_target_id == a.character_id, "accepted queue A not current B")
	_check(random.calls == 0 and force_before == player.state.recovery.inner_force.current and vitality == a.character_state.vitality.current and player.busy.busy_value == 2, "receipt no resource/busy/RNG")
	_check(scheduler.logical_cycle == 0 and scheduler.remainder_seconds == 0, "receipt no scheduler time")
	_check(intent.change_target(encounter.encounter_id, b.character_id).code == TC.UNCHANGED and encounter.events().size() == event_count + 1, "same target no duplicate callback/event")
	for invalid: StringName in [&"", &"missing", player.character_id]:
		_check(intent.change_target(encounter.encounter_id, invalid).code == TC.TARGET_UNAVAILABLE, "invalid/self target")
		_check(encounter.current_target_for(player.character_id) == b.character_id, "invalid preserves B")
	_check(intent.change_target(&"stale", a.character_id).code == TC.STALE_ENCOUNTER, "stale encounter")
	_check(coordinator.change_player_target(CombatTargetRequest.new(encounter.encounter_id, a.character_id, b.character_id)).code == TC.INVALID_ACTOR, "NPC cannot issue player selection")
	_check(coordinator.change_player_target(null).code == TC.INVALID_REQUEST, "null request")
	a.set_combat_available(false)
	_check(intent.change_target(encounter.encounter_id, a.character_id).code == TC.TARGET_UNAVAILABLE, "unavailable rejected")
	a.set_combat_available(true)
	player.relationship.remove_opponent(a.character_id)
	_check(intent.change_target(encounter.encounter_id, a.character_id).code == TC.TARGET_UNAVAILABLE, "side topology cannot fabricate exact relationship")
	player.relationship.add_opponent(a.character_id)
	tree.paused = true
	_check(intent.change_target(encounter.encounter_id, a.character_id).code == TC.APPLICATION_BLOCKED, "paused receipt")
	tree.paused = false
	var gate: WorldSimulationGate = coordinator._world_gate
	gate.release(encounter.encounter_id)
	_check(intent.change_target(encounter.encounter_id, a.character_id).code == TC.WORLD_GATE_MISMATCH, "gate mismatch")
	gate.acquire(encounter.encounter_id)
	session._session_swap_suspended = true # Typed runtime boundary negative fixture only.
	_check(intent.change_target(encounter.encounter_id, a.character_id).code == TC.APPLICATION_BLOCKED, "suspended old Session")
	session._session_swap_suspended = false
	var bindings: Array[CombatSliceCharacterBinding] = session.encounter_combat_bindings(encounter)
	_check(scheduler.bindings_match_encounter(bindings), "exact bindings")
	var original: CombatSliceCharacterBinding = bindings[0]
	bindings[0] = CombatSliceCharacterBinding.new(original.character_id, CharacterState.new(), original.relationship, original.busy, original.armor, original.content, original.location_id)
	_check(not scheduler.bindings_match_encounter(bindings), "different authority rejected")
	_check(encounter.queued_player_action().request.request_id == queued.request.request_id and random.calls == 0, "all rejections preserve queue/RNG")
	var projection: BattlePresentationProjection = BattleProjectionBuilder.build(session)
	_check(projection.current_target_id == b.character_id and projection.participants().size() == 3, "current B three participants")
	_check(not projection.participants()[0].targetable and projection.participants()[1].targetable and projection.participants()[2].targetable, "availability is narrow projection")
	var reader := BattleFeedbackReader.new()
	var feedback: Array[BattleFeedbackProjection] = reader.read_new(coordinator, projection)
	_check(feedback.size() == 5 and feedback.front().text.contains("Target:") and feedback.back().text.contains("Target:"), "target A / REQUESTED, ACCEPTED, QUEUED / target B ordered together")
	_check(feedback[0].progression_order < feedback[1].progression_order and feedback[1].progression_order < feedback[2].progression_order, "shared semantic order")
	_check(reader.read_new(coordinator, projection).is_empty(), "incremental no duplicates")
	var atman_a: int = a.character_state.recovery.atman.current
	var atman_b: int = b.character_state.recovery.atman.current
	coordinator.advance_scheduler(1)
	coordinator.advance_scheduler(1)
	_check(encounter.queued_player_action() != null and player.busy.busy_value == 0, "busy completion does not execute slot early")
	coordinator.advance_scheduler(0)
	_check(a.character_state.recovery.atman.current == atman_a + 1 and b.character_state.recovery.atman.current == atman_b, "QA policy actually executes accepted A, not B")
	_check(player.state.recovery.inner_force.current == force_before - 1, "exact existing QA cost")
	var opportunity: CombatSchedulerAdvanceResult = coordinator.advance_scheduler(1)
	_check(opportunity.events()[0].target_id == b.character_id, "ordinary honors current B")
	b.set_combat_available(false)
	opportunity = coordinator.advance_scheduler(1)
	_check(encounter.current_target_for(player.character_id) == a.character_id and opportunity.events()[0].target_id == a.character_id, "lost B retargets first eligible stable A")
	a.set_combat_available(false)
	opportunity = coordinator.advance_scheduler(1)
	_check(encounter.current_target_for(player.character_id).is_empty() and opportunity.events()[0].skip_reason == CombatSchedulerEvent.SkipReason.TARGET_UNAVAILABLE, "no valid targets clears with typed skip")
	a.set_combat_available(true)
	b.set_combat_available(true)
	_check(intent.submit(&"qa.probe", a.character_id).accepted(), "queue replacement fixture")
	queued = encounter.queued_player_action()
	_check(intent.submit(&"qa.second", b.character_id).accepted(), "replacement retains CXR5")
	_check(intent.cancel(queued.request.request_id).code == Code.STALE_CANCEL, "stale cancel safe")
	_check(encounter.queued_player_action().resolved_target_id == b.character_id, "replacement B unchanged")
	_check(Multi.finish(session), "typed cleanup only")
	session.free()
	await _settle(tree, 2)


func _modes(tree: SceneTree) -> void:
	for cause: int in CombatTriggerCause.Value.values():
		for mode: int in CombatEncounterMode.Value.values():
			var session: OldPineWorldSessionController = SessionScene.instantiate()
			tree.root.add_child(session)
			session.set_process(false)
			var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
			var player: WorldPlayerRuntimeState = session.player_runtime()
			var a: NpcRuntimeState = session.outdoor_map().npc_runtimes()[0]
			var npc_initiator: bool = cause in [CombatTriggerCause.Value.NPC_AGGRESSION, CombatTriggerCause.Value.VENDETTA_HOSTILITY]
			var trigger: CombatTrigger = Multi.trigger(session, mode, cause, &"matrix", npc_initiator)
			if mode == CombatEncounterMode.Value.LETHAL:
				(a.relationship if npc_initiator else player.relationship).mark_lethal_target(player.character_id if npc_initiator else a.character_id)
			# Expected rows derived independently from fight.c, kill.c, combatd start_*.
			var expected: bool = (cause == CombatTriggerCause.Value.SCRIPTED and mode == CombatEncounterMode.Value.SCRIPTED) or (cause == CombatTriggerCause.Value.PLAYER_SPAR and mode == CombatEncounterMode.Value.SPAR) or (cause in [CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK, CombatTriggerCause.Value.NPC_AGGRESSION, CombatTriggerCause.Value.VENDETTA_HOSTILITY] and mode == CombatEncounterMode.Value.LETHAL)
			var result: CombatEncounterStartResult = coordinator.start(trigger)
			_check(result.succeeded() == expected, "cause/mode matrix %d/%d" % [cause, mode])
			_check(coordinator.action_infos().size() == (0 if expected and mode == CombatEncounterMode.Value.SCRIPTED else 1), "Flee production registration respects supported mode")
			if expected:
				var encounter: CombatEncounter = coordinator.active_encounter()
				_check(encounter.participant_for(player.character_id).binding.state == player.state and encounter.participant_for(a.character_id).binding.relationship == a.relationship, "mode exact authorities")
				_check(coordinator._world_gate.freeze_owner_id() == encounter.encounter_id, "mode freeze owner")
				# This matrix proves establishment/cadence, not a random friendly conclusion.
				for participant: CombatParticipant in encounter.participants():
					participant.binding.busy.start_busy(1)
				_check(coordinator.advance_scheduler(1).progressed(), "same scheduler works each supported mode")
				_check(coordinator.active_encounter() == encounter and encounter.terminal_result == null, "no invented terminal result")
				_check(BattleProjectionBuilder.build(session).mode == mode, "mode projection")
				_check(Multi.finish(session), "mode typed cleanup")
			else:
				_check(coordinator._world_gate.is_open() and not coordinator.has_active_encounter(), "bad combination has no freeze")
			session.free()
			await _settle(tree, 1)
	# Mixed fight/kill and missing/asymmetric facts are not magically repaired.
	var session: OldPineWorldSessionController = SessionScene.instantiate()
	tree.root.add_child(session)
	session.set_process(false)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var a: NpcRuntimeState = session.outdoor_map().npc_runtimes()[0]
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var spar: CombatTrigger = Multi.trigger(session, CombatEncounterMode.Value.SPAR, CombatTriggerCause.Value.PLAYER_SPAR)
	a.relationship.mark_lethal_target(player.character_id)
	_check(coordinator.start(spar).outcome == CombatEncounterStartResult.Outcome.MODE_RELATIONSHIP_MISMATCH, "fight non-speaking reverse-kill is not SPAR")
	a.relationship.remove_lethal_relation(player.character_id)
	_check(not coordinator.start(spar).succeeded(), "spar requires reciprocal accepted fight")
	var lethal: CombatTrigger = Multi.trigger(session, CombatEncounterMode.Value.LETHAL, CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK)
	_check(not coordinator.start(lethal).succeeded(), "mode does not fabricate lethal relation")
	var scripted: CombatTrigger = Multi.trigger(session, CombatEncounterMode.Value.SCRIPTED, CombatTriggerCause.Value.SCRIPTED)
	_check(coordinator.start(scripted).succeeded(), "scripted unchanged after failures")
	var e: CombatEncounter = coordinator.active_encounter()
	var bindings: Array[CombatSliceCharacterBinding] = session.encounter_combat_bindings(e)
	_check(not coordinator.active_scheduler().can_target(a.character_id, bindings[2].character_id, bindings), "B to C lacks directed hostility")
	# Same-side eligibility independently uses existing Core side topology.
	var candidates: Array[CombatParticipant] = e.participants()
	var same_side: Array[CombatParticipant] = [candidates[0], CombatParticipant.new(candidates[1].participant_id, candidates[0].side_id, candidates[1].binding), candidates[2]]
	var same_trigger := CombatTrigger.new(&"same", CombatTriggerCause.Value.SCRIPTED, CombatEncounterMode.Value.SCRIPTED, player.character_id, [CombatTriggerCandidate.new(player.character_id, &"A"), CombatTriggerCandidate.new(a.character_id, &"A"), CombatTriggerCandidate.new(candidates[2].participant_id, &"C")], player.world_location(), &"qa")
	var core := CombatEncounter.new(&"same-side", same_trigger, same_side, [CombatDirectedHostility.new(&"A", &"C")])
	_check(core.is_valid() and core.activate(), "same-side fixture itself valid")
	var scheduler := CombatEncounterScheduler.new(core, CombatSchedulerConfig.new(1))
	_check(not scheduler.can_target(player.character_id, a.character_id, bindings), "same-side despite opponent fact rejected")
	_check(Multi.finish(session), "cleanup negative fixture")
	session.free()
	await _settle(tree, 2)


func _target_ui(tree: SceneTree) -> void:
	var original: Vector2i = tree.root.size
	var scale: Vector2i = tree.root.content_scale_size
	tree.root.content_scale_size = Vector2i.ZERO
	tree.root.size = Vector2i(1152, 648)
	var shell: ApplicationShellController = ShellScene.instantiate()
	shell.configure_before_start(GameSaveStorageProfile.isolated_test("cxr7-ui"), Fixtures.MemoryFiles.new(), null, Fixtures.MemoryFiles.new(), Fixtures.FakeWindowCapability.new())
	var touch: MobileTouchAdapter = shell.get_node("TouchCanvas/TouchInput")
	touch.set_capability(EnabledTouch.new())
	tree.root.add_child(shell)
	await _settle(tree)
	await _tap(tree, shell.new_game_button)
	await _settle(tree, 25)
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	session.set_process(false)
	Multi.register_probes(session)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.start(Multi.trigger(session, CombatEncounterMode.Value.SCRIPTED, CombatTriggerCause.Value.SCRIPTED)).succeeded(), "UI controlled start")
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	await _settle(tree)
	_check(ui._cards.size() == 3 and ui._cards[0].target_button.disabled, "UI collection/self disabled")
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.busy.start_busy(2)
	await _tap(tree, ui._cards[1].target_button)
	var a: StringName = ui.current_projection().current_target_id
	_check(a == session.outdoor_map().npc_runtimes()[0].character_id, "real touch selects A while busy")
	await _tap(tree, ui.action_panel.first_action_button())
	await _tap(tree, ui._cards[2].target_button)
	var b: StringName = session.outdoor_map().npc_runtimes()[1].character_id
	_check(ui.current_projection().current_target_id == b and ui.current_projection().queued_action().resolved_target_id == a, "touch current B vs queued A")
	_check(ui._cards[2]._title.text.contains("Current Target") and ui._cards[1]._status.text.contains("QUEUED TARGET"), "visibly distinct labels")
	_check(session.outdoor_map().selected_interaction_target() == null and not touch._pad.visible, "target touch does not leak to world")
	ui._cards[1].target_button.grab_focus()
	await _key(tree, KEY_ENTER, true)
	await _key(tree, KEY_ENTER, false)
	_check(ui.current_projection().current_target_id == a, "keyboard accept targets focused card")
	for card: BattleParticipantCard in ui._cards:
		_check(card.target_button.size.x >= 64 and card.target_button.size.y >= 64, "target touch minima")
	await _tap(tree, ui.log_button)
	await _back(tree)
	_check(not ui.log_panel.visible and ui.visible and not tree.paused, "child Back first")
	await _back(tree)
	_check(tree.paused and shell.pause_visible() and ui.visible, "root Back pauses not hides")
	await _tap(tree, shell.resume_button)
	_check(shell.runtime_host().current_session() == session and ui.current_projection().current_target_id == a, "same Session/target after Resume")
	var safe := FakeSafe.new()
	safe.metrics = SafeAreaMetrics.new(Rect2(0, 0, 1152, 648), Rect2(0, 0, 800, 480), false, true)
	(shell.get_node("SafeAreaPresentation") as SafeAreaPresenter).set_capability(safe)
	await _settle(tree)
	_check(safe.metrics.content_rect().encloses(ui._content.get_global_rect()), "three-card compact content inside safe bounds")
	var scroll: ScrollContainer = ui._participants.get_parent()
	_check(scroll.get_h_scroll_bar().max_value > scroll.get_h_scroll_bar().page, "three cards have native horizontal navigation")
	ui._cards[2].target_button.grab_focus()
	await _settle(tree)
	_check(scroll.scroll_horizontal > 0, "focused third participant scrolled into view")
	_check(safe.metrics.content_rect().encloses(ui._cards[2].target_button.get_global_rect()), "third target wholly visible after focus navigation")
	_check(ui.current_projection().current_target_id == a, "focus alone is not a gameplay target change")
	_check(Multi.finish(session), "UI cleanup")
	shell.free()
	await _settle(tree, 2)
	tree.root.size = original
	tree.root.content_scale_size = scale
