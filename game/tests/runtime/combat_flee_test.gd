extends "res://tests/runtime/battle_presentation_test.gd"

const Multi := preload("res://tests/support/cxr7_session_fixture.gd")
const FLEE: StringName = CombatFleeTacticalPolicy.ACTION_ID

func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _ready_and_multi(tree)
	await _waiting_replace_cancel(tree)
	await _validation(tree)
	await _invalidated(tree)
	await _armed_spar(tree)
	await _flee_input(tree)
	return {"assertions": _assertions, "failures": _failures.duplicate()}

func _new(tree: SceneTree) -> OldPineWorldSessionController:
	var session: OldPineWorldSessionController = SessionScene.instantiate()
	tree.root.add_child(session)
	session.set_process(false)
	session.outdoor_map().set_process(false)
	session.configure_combat_random_source(Setup.CountingRandom.new())
	return session

func _start(session: OldPineWorldSessionController, mode: int = CombatEncounterMode.Value.LETHAL) -> CombatEncounter:
	var cause: int = CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK if mode == CombatEncounterMode.Value.LETHAL else CombatTriggerCause.Value.PLAYER_SPAR
	var trigger: CombatTrigger = Multi.trigger(session, mode, cause)
	if mode == CombatEncounterMode.Value.LETHAL:
		for npc: NpcRuntimeState in session.outdoor_map().npc_runtimes().slice(0, 2):
			session.player_runtime().relationship.mark_lethal_target(npc.character_id)
			npc.relationship.mark_lethal_target(session.player_runtime().character_id)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.start(trigger).succeeded(), "Flee fixture exact three-participant establishment")
	return coordinator.active_encounter()

func _request(session: OldPineWorldSessionController, id: StringName = &"flee") -> CombatTacticalRequest:
	return CombatTacticalRequest.new(id, session.combat_encounter_coordinator().active_encounter().encounter_id,
		session.player_runtime().character_id, FLEE, CombatTacticalRequest.Category.FLEE)

func _ready_and_multi(tree: SceneTree) -> void:
	for mode: int in [CombatEncounterMode.Value.LETHAL, CombatEncounterMode.Value.SPAR]:
		var session: OldPineWorldSessionController = _new(tree)
		var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
		var encounter: CombatEncounter = _start(session, mode)
		var scheduler: CombatEncounterScheduler = coordinator.active_scheduler()
		var rng: Setup.CountingRandom = session.combat_random_source()
		var player: WorldPlayerRuntimeState = session.player_runtime()
		var position: Transform2D = session.outdoor_map().player_body.global_transform
		var values: Array[int] = []
		for participant: CombatParticipant in encounter.participants():
			participant.binding.relationship.set_guarding(true)
			values.append(participant.binding.state.vitality.current)
		var info: CombatTacticalActionInfo = coordinator.action_infos()[0]
		_check(coordinator.action_infos().size() == 1 and info.action_id == FLEE, "production set exactly Flee, not QA policy")
		_check(info.category == CombatTacticalRequest.Category.FLEE and info.target_rule == CombatTacticalRequest.TargetRule.SELF and info.blocks_when_busy, "exact Flee metadata")
		_check(not coordinator.complete(CombatEncounterResult.new(encounter.encounter_id, mode, CombatEncounterResultKind.Value.FLED)).succeeded(), "cannot inject FLED bypassing policy/result boundary")
		_check(coordinator.submit_player_action(_request(session)).accepted(), "ready Flee receipt accepted")
		_check(encounter.queued_player_action().resolved_target_id == player.character_id and scheduler.player_tactics().queue_status() == Queue.READY, "SELF queue uses player, not current hostile")
		_check(rng.calls == 0 and coordinator.last_completion() == null and scheduler.events().is_empty(), "input receipt executes nothing")
		var advanced: CombatSchedulerAdvanceResult = coordinator.advance_scheduler(10000)
		_check(advanced.events().is_empty() and scheduler.events().is_empty() and scheduler.logical_cycle == 0 and rng.calls == 0, "Flee stops enormous same-advance batch before ALL ordinary opportunities/RNG")
		_check(encounter.phase == CombatEncounterLifecycle.Value.COMPLETED and encounter.terminal_result.kind == CombatEncounterResultKind.Value.FLED, "typed FLED, not Victory/Defeat")
		_check(encounter.terminal_result.winning_side_ids().is_empty() and encounter.terminal_result.losing_side_ids().is_empty() and encounter.terminal_result.subject_participant_ids() == [player.character_id], "no fake winner or selected enemy victim")
		_check(coordinator.last_completion().succeeded() and not coordinator.has_active_encounter() and session.world_simulation_gate().is_open(), "same Session successful world thaw")
		_check(session.outdoor_map().player_body.global_transform == position and session.outdoor_map().opportunity_timer.is_stopped(), "same transform, no teleport/legacy cadence")
		_check(session.outdoor_map().corpse_states().is_empty() and session.inventory_state().registered_item_ids().size() == 12, "multi Flee produces no corpse/loot/item")
		var index: int = 0
		for participant: CombatParticipant in encounter.participants():
			_check(participant.binding.relationship.opponent_ids().is_empty() and participant.binding.relationship.lethal_target_ids().is_empty() and not participant.binding.relationship.guarding, "all included opponent/lethal/guard relations reconciled")
			_check(participant.binding.state.vitality.current == values[index], "each participant resource preserved")
			index += 1
		_check(player.state.progression.combat_experience == 600 and player.state.recovery.inner_force.current == 0 and player.state.recovery.mana.current == 0, "no progression or internal-resource cost/reward")
		_check(OldPineSaveEligibility.inspect(session).allowed(), "normal post-Flee Save authority allows safe state")
		var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
		ui.refresh_projection()
		_check(not ui.visible and session.outdoor_map().hud.world_title.text.begins_with("Escaped"), "only successful completion closes Battle and shows Escaped")
		var history: int = encounter.events().size()
		coordinator.advance_scheduler(10000)
		scheduler.advance(10000, true, encounter.encounter_id, [], rng, SkillImprovementEffectRegistry.new())
		_check(encounter.events().size() == history and rng.calls == 0 and scheduler.player_tactics().events().size() == 5, "one resolution exactly once; no retained-scheduler execution")
		session.free()
		await _settle(tree, 2)

func _waiting_replace_cancel(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = _new(tree)
	var encounter: CombatEncounter = _start(session)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var scheduler: CombatEncounterScheduler = coordinator.active_scheduler()
	var rng: Setup.CountingRandom = session.combat_random_source()
	session.player_runtime().busy.start_busy(2)
	for npc: NpcRuntimeState in session.outdoor_map().npc_runtimes().slice(0, 2):
		npc.busy.start_busy(4) # Deterministic no-attack setup, not live/player stats.
	_check(coordinator.submit_player_action(_request(session, &"old")).accepted(), "busy accepts one slot")
	_check(coordinator.submit_player_action(_request(session, &"replacement")).accepted(), "busy permits valid replacement")
	_check(encounter.queued_player_action().request.request_id == &"replacement" and scheduler.player_tactics().queue_status() == Queue.WAITING_FOR_BUSY, "one visible waiting slot")
	_check(coordinator.cancel_player_action(&"old").code == Code.STALE_CANCEL, "stale cancel cannot erase replacement")
	_check(coordinator.cancel_player_action(&"replacement").code == Code.CANCELLED, "cancel queued Flee")
	coordinator.advance_scheduler(0)
	_check(encounter.queued_player_action() == null and coordinator.last_completion() == null and rng.calls == 0, "cancelled Flee never executes")
	_check(coordinator.submit_player_action(_request(session, &"retained")).accepted(), "queue after cancel")
	tree.paused = true
	coordinator.advance_scheduler(10000)
	_check(scheduler.logical_cycle == 0 and rng.calls == 0 and session.player_runtime().busy.busy_value == 2 and encounter.queued_player_action().request.request_id == &"retained", "Pause retains exact queue, busy, clock and RNG")
	_check(not OldPineSaveEligibility.inspect(session).allowed(), "queued paused encounter cannot save")
	tree.paused = false
	coordinator.advance_scheduler(1)
	_check(session.player_runtime().busy.busy_value == 1 and encounter.queued_player_action() != null, "busy 2->1 ordinary opportunity, Flee waits")
	coordinator.advance_scheduler(1)
	_check(session.player_runtime().busy.busy_value == 0 and encounter.queued_player_action() != null and coordinator.last_completion() == null, "busy 1->0 is NOT early Flee execution")
	var ordinary_count: int = scheduler.events().size()
	coordinator.advance_scheduler(10000)
	_check(coordinator.last_completion().succeeded() and encounter.terminal_result.kind == CombatEncounterResultKind.Value.FLED and scheduler.events().size() == ordinary_count and rng.calls == 0, "next boundary executes once without catch-up")
	_check(session.outdoor_map().npc_runtimes()[0].busy.busy_value == 2 and not OldPineSaveEligibility.inspect(session).allowed(), "Flee never clears other busy to force Save permission")
	session.free()
	await _settle(tree, 2)

func _validation(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = _new(tree)
	var encounter: CombatEncounter = _start(session)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var valid: CombatTacticalRequest = _request(session)
	var npc: NpcRuntimeState = session.outdoor_map().npc_runtimes()[0]
	for request: CombatTacticalRequest in [
		CombatTacticalRequest.new(&"foreign", &"wrong", valid.actor_id, FLEE, valid.category),
		CombatTacticalRequest.new(&"npc", valid.encounter_id, npc.character_id, FLEE, valid.category),
		CombatTacticalRequest.new(&"target", valid.encounter_id, valid.actor_id, FLEE, valid.category, npc.character_id),
		CombatTacticalRequest.new(&"category", valid.encounter_id, valid.actor_id, FLEE, CombatTacticalRequest.Category.ITEM),
		CombatTacticalRequest.new(&"unknown", valid.encounter_id, valid.actor_id, &"qa.probe", valid.category),
	]:
		_check(not coordinator.submit_player_action(request).accepted() and encounter.queued_player_action() == null, "invalid request cannot mutate slot")
	_check(coordinator.submit_player_action(valid).accepted(), "valid after invalid requests")
	_check(coordinator.submit_player_action(valid).code == Code.DUPLICATE_REQUEST, "same request cannot fire twice")
	var scheduler: CombatEncounterScheduler = coordinator.active_scheduler()
	var bindings: Array[CombatSliceCharacterBinding] = session.encounter_combat_bindings(encounter)
	var random: Setup.CountingRandom = session.combat_random_source()
	scheduler.advance(100, true, &"wrong-owner", bindings, random, session.encounter_skill_effect_registry(), coordinator.resolution())
	_check(encounter.queued_player_action() != null and random.calls == 0 and coordinator.last_completion() == null, "execution rechecks exact world gate")
	bindings[0]._state = CharacterState.new() # Deliberately corrupted test projection, not authority mutation.
	scheduler.advance(100, true, encounter.encounter_id, bindings, random, session.encounter_skill_effect_registry(), coordinator.resolution())
	_check(encounter.queued_player_action() != null and random.calls == 0, "execution rejects replaced character authority")
	coordinator.advance_scheduler(0)
	_check(coordinator.last_completion().succeeded(), "valid exact bindings resume same request")
	session.free()
	await _settle(tree, 2)
	session = _new(tree)
	coordinator = session.combat_encounter_coordinator()
	_check(Setup.start(session, &"scripted-flee").succeeded(), "controlled SCRIPTED fixture")
	_check(coordinator.action_infos().is_empty() and coordinator.submit_player_action(_request(session)).code == Code.POLICY_UNSUPPORTED, "SCRIPTED never automatically enables escape")
	_check(coordinator.active_encounter().queued_player_action() == null, "unsupported mode no queue")
	session.free()
	await _settle(tree, 2)

func _invalidated(tree: SceneTree) -> void:
	for mortal: bool in [false, true]:
		var session: OldPineWorldSessionController = _new(tree)
		var encounter: CombatEncounter = _start(session)
		var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
		var tactics: CombatTacticalRuntime = coordinator.active_scheduler().player_tactics()
		session.player_runtime().busy.start_busy(2)
		_check(coordinator.submit_player_action(_request(session)).accepted(), "pending before lifecycle change")
		session.player_runtime().state.vitality.current = -1
		if mortal:
			session.player_runtime().state.vitality.effective = -1
		coordinator.advance_scheduler(100)
		_check(encounter.terminal_result.kind == CombatEncounterResultKind.Value.DEFEAT, "death/unconscious takes precedence, never FLED")
		_check(tactics.events()[-1].kind == CombatTacticalEvent.Kind.CANCELLED and tactics.events().size() == 4, "lifecycle cancels once, no Flee execution")
		_check(session.player_runtime().life_status != CharacterRuntimeLifeStatus.Value.ACTIVE, "no Flee resurrection")
		session.free()
		await _settle(tree, 2)

func _armed_spar(tree: SceneTree) -> void:
	for armed_index: int in [0, 1, 2]:
		var session: OldPineWorldSessionController = _new(tree)
		var player: WorldPlayerRuntimeState = session.player_runtime()
		var actors: Array[CharacterState] = [player.state, session.outdoor_map().npc_runtimes()[0].character_state, session.outdoor_map().npc_runtimes()[1].character_state]
		# Capture current production weapon; establish truthful friendly facts without auto-unwield.
		var trigger: CombatTrigger = Multi.trigger(session, CombatEncounterMode.Value.LETHAL, CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK)
		trigger = CombatTrigger.new(&"armed-spar", CombatTriggerCause.Value.PLAYER_SPAR, CombatEncounterMode.Value.SPAR, player.character_id, trigger.candidates(), player.world_location())
		for index: int in actors.size():
			if index != armed_index:
				Multi._unarm(actors[index].equipment)
		var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
		_check(coordinator.start(trigger).outcome == CombatEncounterStartResult.Outcome.SPAR_WEAPON_NOT_ALLOWED, "reject each armed SPAR participant, including noncurrent hostile")
		_check(not actors[armed_index].equipment.is_primary_hand_empty() and session.world_simulation_gate().is_open() and not coordinator.has_active_encounter(), "rejection never unwields, freezes or starts")
		Multi._unarm(actors[armed_index].equipment)
		_check(coordinator.start(trigger).succeeded(), "all empty primary hands accepted")
		session.free()
		await _settle(tree, 2)

func _flee_input(tree: SceneTree) -> void:
	var original_size: Vector2i = tree.root.size
	var original_scale: Vector2i = tree.root.content_scale_size
	tree.root.content_scale_size = Vector2i.ZERO
	tree.root.size = Vector2i(960, 540)
	var shell: ApplicationShellController = ShellScene.instantiate()
	shell.configure_before_start(GameSaveStorageProfile.isolated_test("cxr9-flee"), Fixtures.MemoryFiles.new(), null, Fixtures.MemoryFiles.new(), Fixtures.FakeWindowCapability.new())
	var touch: MobileTouchAdapter = shell.get_node("TouchCanvas/TouchInput")
	touch.set_capability(EnabledTouch.new())
	var safe := FakeSafe.new()
	safe.metrics = SafeAreaMetrics.new(Rect2(0, 0, 960, 540), Rect2(0, 0, 960, 540), false, true)
	(shell.get_node("SafeAreaPresentation") as SafeAreaPresenter).set_capability(safe)
	tree.root.add_child(shell)
	await _settle(tree)
	await _tap(tree, shell.new_game_button)
	await _settle(tree, 25)
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	session.set_process(false)
	session.outdoor_map().set_process(false)
	session.configure_combat_random_source(Setup.CountingRandom.new())
	var encounter: CombatEncounter = _start(session)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	await _settle(tree)
	var button: Button = ui.action_panel.first_action_button()
	_check(button != null and button.text == "Flee / Disengage" and button.size.x >= 64 and button.size.y >= 64, "registry/catalog Flee with native touch target")
	await _tap(tree, button)
	_check(encounter.queued_player_action() != null and coordinator.last_completion() == null, "Viewport touch queues, never completes synchronously")
	_check(session.outdoor_map().selected_interaction_target() == null, "touch does not leak world selection")
	if encounter.queued_player_action() == null:
		shell.free()
		tree.root.size = original_size
		tree.root.content_scale_size = original_scale
		return
	var saved_request: StringName = encounter.queued_player_action().request.request_id
	await _tap(tree, ui.log_button)
	await _back(tree)
	_check(not ui.log_panel.visible and not tree.paused and ui.visible, "Back closes child log first, not Flee")
	await _back(tree)
	_check(tree.paused and shell.pause_visible() and encounter.queued_player_action().request.request_id == saved_request, "root Back pauses and retains Flee instead of executing")
	coordinator.advance_scheduler(1000)
	_check(coordinator.last_completion() == null and coordinator.active_scheduler().logical_cycle == 0, "paused Flee cannot execute")
	await _tap(tree, shell.resume_button)
	_check(not tree.paused and encounter.queued_player_action().request.request_id == saved_request, "explicit Resume keeps same request")
	# Simulated platform boundary; physical Android qualification is separate.
	var lifecycle: MobileLifecycleAdapter = shell.get_node("MobileLifecycle")
	lifecycle.set_capability(LifecycleFixture.EnabledLifecycle.new())
	lifecycle.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	lifecycle.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _settle(tree)
	coordinator.advance_scheduler(1000)
	_check(tree.paused and encounter.queued_player_action().request.request_id == saved_request and coordinator.last_completion() == null, "Home retains Flee without execution")
	_check(coordinator.active_scheduler().logical_cycle == 0 and (session.combat_random_source() as Setup.CountingRandom).calls == 0 and not OldPineSaveEligibility.inspect(session).allowed(), "background has no clock/RNG/Save")
	lifecycle.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	lifecycle.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _settle(tree)
	_check(tree.paused and shell.activity().resume_gate() == ApplicationActivity.ResumeGate.EXPLICIT_AFTER_LIFECYCLE, "foreground never executes queued Flee implicitly")
	await _tap(tree, shell.resume_button)
	_check(not tree.paused and encounter.queued_player_action().request.request_id == saved_request and coordinator.active_scheduler().logical_cycle == 0, "explicit lifecycle Resume retains queue without catch-up")
	coordinator.cancel_player_action(encounter.queued_player_action().request.request_id)
	button.grab_focus() # Focus setup; actual semantic input below.
	await _key(tree, KEY_ENTER, true)
	await _key(tree, KEY_ENTER, false)
	_check(encounter.queued_player_action() != null, "keyboard accept uses same action")
	coordinator.cancel_player_action(encounter.queued_player_action().request.request_id)
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = pressed
		Input.parse_input_event(event)
		await _settle(tree, 2)
	_check(encounter.queued_player_action() != null, "controller accept uses same Flee queue")
	coordinator.advance_scheduler(0)
	await _settle(tree)
	_check(not ui.visible and session.world_simulation_gate().is_open(), "Flee restores world presentation")
	shell.free()
	tree.root.size = original_size
	tree.root.content_scale_size = original_scale
	await _settle(tree, 2)
