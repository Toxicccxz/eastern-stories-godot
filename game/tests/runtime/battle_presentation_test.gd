extends "res://tests/application/mobile_touch_test.gd"

const SessionScene := preload("res://scenes/world/oldpine/oldpine_world_session.tscn")
const Setup := preload("res://tests/support/cxr6_session_fixture.gd")
const LifecycleFixture := preload("res://tests/application/mobile_lifecycle_test.gd")
const Code := CombatTacticalResult.Code
const Queue := CombatQueuedAction.Status


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _test_projection_and_intent(tree)
	await _test_shell_battle(tree)
	await _test_restored_session_battle(tree)
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_projection_and_intent(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = SessionScene.instantiate()
	tree.root.add_child(session)
	session.set_process(false) # Deterministic unit boundary, not live proof.
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	ui.set_process(false)
	var random := Setup.CountingRandom.new()
	session.configure_combat_random_source(random)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(not BattleProjectionBuilder.build(session).active, "inactive projection")
	_check(coordinator.action_infos().is_empty(), "production registry empty")
	_check(Setup.start(session, &"cxr6.empty").succeeded(), "production-empty controlled encounter")
	var empty: BattlePresentationProjection = BattleProjectionBuilder.build(session)
	_check(empty.active and empty.actions().is_empty(), "active production has zero actions")
	ui.refresh_projection()
	_check(ui.action_panel._empty.visible and ui.action_panel.first_action_button() == null, "honest empty state, no six category buttons")
	_check(empty.queue_status == Queue.EMPTY and empty.queued_action() == null, "empty queue projection")
	_check(Setup.complete(session), "empty encounter same-world completion")
	ui.refresh_projection()
	Setup.register_probes(session)
	_check(Setup.start(session, &"cxr6.typed", true).succeeded(), "three participant fixture")
	var encounter: CombatEncounter = coordinator.active_encounter()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var enemy: NpcRuntimeState = session.outdoor_map().npc_runtimes()[0]
	var third: NpcRuntimeState = session.outdoor_map().npc_runtimes()[1]
	encounter.set_current_target(player.character_id, enemy.character_id)
	var intent := BattleIntentAdapter.new(coordinator, player.character_id)
	var force_before: int = player.state.recovery.inner_force.current
	var rng_before: int = random.calls
	var projection: BattlePresentationProjection = BattleProjectionBuilder.build(session)
	_check(projection.participants().size() == 3, "collection not hardcoded pair")
	_check(projection.actions().size() == 2, "only explicit QA registrations visible")
	var people: Array[BattleParticipantProjection] = projection.participants()
	_check(people[0].vitality.current == player.state.vitality.current, "exact current vitality")
	_check(people[0].vitality.effective == player.state.vitality.effective, "exact effective vitality")
	_check(people[0].vitality.maximum == player.state.vitality.maximum, "exact maximum vitality")
	_check(people[0].essence.current == player.state.essence.current and people[0].spirit.current == player.state.spirit.current, "gin/sen from exact CharacterState")
	_check(people[0].force.current == force_before, "exact internal resource")
	_check(people[1].hostile_to_player and people[1].side_id == &"hostile", "directed side projection")
	_check(people[0].display_name == "Player" and people[1].display_name == enemy.definition().display_name, "content names, not Node IDs")
	people.clear()
	var infos: Array[CombatTacticalActionInfo] = projection.actions()
	infos.clear()
	_check(projection.participants().size() == 3 and projection.actions().size() == 2, "defensive collection snapshots")
	_check(random.calls == rng_before and player.state.recovery.inner_force.current == force_before, "projection no mutation/RNG")
	_check(intent.submit(&"metadata.only").code == Code.UNKNOWN_ACTION, "metadata cannot enable action")
	_check(intent.submit(&"qa.probe", third.character_id).accepted(), "typed adapter submit")
	var a: CombatQueuedAction = encounter.queued_player_action()
	_check(a.request.actor_id == player.character_id and a.request.encounter_id == encounter.encounter_id, "exact request actor/encounter")
	_check(a.request.action_id == &"qa.probe" and a.request.category == CombatTacticalRequest.Category.MARTIAL_SPECIAL, "source action metadata")
	_check(a.resolved_target_id == third.character_id, "declared explicit target")
	_check(a.request.request_id.ends_with(":1"), "deterministic correlation, not tactical sequence/RNG")
	_check(player.state.recovery.inner_force.current == force_before and random.calls == rng_before, "receipt zero resource/RNG and no execution")
	projection = BattleProjectionBuilder.build(session)
	_check(projection.queue_status == Queue.READY, "READY projection")
	_check(projection.current_target_id == enemy.character_id and projection.queued_action().resolved_target_id == third.character_id, "current and queued targets distinct")
	encounter.set_current_target(player.character_id, third.character_id)
	encounter.set_current_target(player.character_id, enemy.character_id)
	_check(encounter.queued_player_action().resolved_target_id == third.character_id, "target changes never retarget accepted snapshot")
	player.busy.start_busy(2)
	_check(BattleProjectionBuilder.build(session).queue_status == Queue.WAITING_FOR_BUSY, "busy-derived wait status")
	_check(BattleProjectionBuilder.build(session).participants()[0].busy_value == 2, "exact busy value")
	_check(intent.submit(&"qa.second", enemy.character_id).accepted(), "valid busy replacement")
	var b: CombatQueuedAction = encounter.queued_player_action()
	_check(b.sequence > a.sequence and b.request.request_id != a.request.request_id, "replacement monotonic IDs")
	_check(intent.cancel(a.request.request_id).code == Code.STALE_CANCEL, "stale cancel rejected")
	_check(encounter.queued_player_action().request.request_id == b.request.request_id, "stale cancel preserves authoritative queue")
	player.state.recovery.inner_force.current = 0
	_check(intent.submit(&"qa.probe", third.character_id).code == Code.PREREQUISITE_FAILED, "invalid replacement fails closed")
	_check(encounter.queued_player_action().request.request_id == b.request.request_id, "invalid replacement preserves slot")
	player.state.recovery.inner_force.current = force_before
	_check(intent.cancel(b.request.request_id).code == Code.CANCELLED, "exact cancel")
	_check(BattleProjectionBuilder.build(session).queue_status == Queue.EMPTY, "cancel projection EMPTY")
	_check(intent.submit(&"qa.probe", third.character_id).accepted(), "queue for paused boundary")
	var queued_id: StringName = encounter.queued_player_action().request.request_id
	var reader := BattleFeedbackReader.new()
	var first: Array[BattleFeedbackProjection] = reader.read_new(coordinator, BattleProjectionBuilder.build(session))
	_check(not first.is_empty(), "read tactical events")
	_check(reader.read_new(coordinator, BattleProjectionBuilder.build(session)).is_empty(), "cursor never duplicates history")
	tree.paused = true
	var calls: int = random.calls
	coordinator.advance_scheduler(100)
	_check(encounter.queued_player_action().request.request_id == queued_id and random.calls == calls, "pause keeps queue/RNG, no catch-up")
	_check(BattleProjectionBuilder.build(session).queued_action().request.request_id == queued_id, "paused projection retains slot")
	tree.paused = false
	coordinator.advance_scheduler(1)
	_check(player.busy.busy_value == 1, "ordinary busy 2->1 unchanged")
	coordinator.advance_scheduler(1)
	_check(player.busy.busy_value == 0 and encounter.queued_player_action() != null, "1->0 opportunity does not execute slot")
	var before_execute: int = player.state.recovery.inner_force.current
	var before_atman: int = third.character_state.recovery.atman.current
	coordinator.advance_scheduler(0)
	_check(encounter.queued_player_action() == null, "next boundary consumes slot")
	_check(player.state.recovery.inner_force.current == before_execute - 1 and third.character_state.recovery.atman.current == before_atman + 1, "QA-only exact effect occurs at boundary")
	var after_execute: int = random.calls
	coordinator.advance_scheduler(0)
	_check(random.calls == after_execute, "no double execution")
	var mixed: Array[BattleFeedbackProjection] = reader.read_new(coordinator, BattleProjectionBuilder.build(session))
	var last_order: int = first[-1].progression_order
	for entry: BattleFeedbackProjection in mixed:
		_check(entry.progression_order > last_order, "ordinary+tactical sorted by semantic order")
		last_order = entry.progression_order
	_check(reader.recent().size() == 3 and reader.recent()[-1] == mixed[-1], "latest three semantic entries")
	_check(reader.read_new(coordinator, BattleProjectionBuilder.build(session)).is_empty(), "incremental read remains empty without events")
	_check(coordinator.active_scheduler().events_after(last_order).is_empty(), "ordinary suffix accessor")
	_check(coordinator.active_scheduler().player_tactics().events_after(last_order).is_empty(), "tactical suffix accessor")
	_check(intent.submit(&"qa.probe", third.character_id).accepted(), "execution rejection fixture")
	player.state.recovery.inner_force.current = 0
	calls = random.calls
	coordinator.advance_scheduler(0)
	_check(encounter.queued_player_action() == null and random.calls == calls, "execution rejection clears without RNG")
	var rejected: Array[BattleFeedbackProjection] = reader.read_new(coordinator, BattleProjectionBuilder.build(session))
	_check(rejected[-2].text.contains("Execution Rejected") and rejected[-1].text.contains("Cancelled"), "rejection/cancellation feedback")
	_check(Setup.complete(session), "typed completion fixture")
	ui.refresh_projection()
	_check(not ui.visible and session.outdoor_map().hud.visible, "completion restores HUD")
	_check(reader.read_new(coordinator, BattleProjectionBuilder.build(session)).is_empty() and reader.last_consumed_order == 0, "inactive resets presentation cursor")
	_check(intent.submit(&"qa.probe").code == Code.INACTIVE, "post-completion adapter inert")
	session.free()
	await _settle(tree, 2)


func _test_shell_battle(tree: SceneTree) -> void:
	var original_size: Vector2i = tree.root.size
	var original_scale: Vector2i = tree.root.content_scale_size
	tree.root.content_scale_size = Vector2i.ZERO
	tree.root.size = Vector2i(960, 540)
	var shell: ApplicationShellController = ShellScene.instantiate()
	shell.configure_before_start(GameSaveStorageProfile.isolated_test("cxr6"), Fixtures.MemoryFiles.new(), null, Fixtures.MemoryFiles.new(), Fixtures.FakeWindowCapability.new())
	var touch: MobileTouchAdapter = shell.get_node("TouchCanvas/TouchInput")
	touch.set_capability(EnabledTouch.new())
	var safe := FakeSafe.new()
	safe.metrics = SafeAreaMetrics.new(Rect2(0, 0, 960, 540), Rect2(0, 0, 960, 540), false, true)
	var presenter: SafeAreaPresenter = shell.get_node("SafeAreaPresentation")
	presenter.set_capability(safe)
	tree.root.add_child(shell)
	await _settle(tree)
	await _tap(tree, shell.new_game_button)
	await _settle(tree, 25)
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	_check(session != null and session.is_initialized(), "real Shell New Game input")
	if session == null:
		shell.free()
		return
	session.set_process(false)
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	_check(not ui.visible and session.outdoor_map().hud.visible, "no encounter leaves world UI unchanged")
	var position: Vector2 = touch.pad_rect().position + Vector2(160, 96)
	await _touch(tree, 4, position, true)
	_check(touch.capture_state().pad_index == 4, "pre-battle movement contact captured")
	_check(Setup.start(session, &"cxr6.shell").succeeded(), "Shell encounter start")
	await _settle(tree)
	_check(ui.visible and not session.outdoor_map().hud.visible, "Session overlay active, exploration HUD yielded")
	_check(safe.metrics.content_rect().encloses(ui._content.get_global_rect()), "first-population layout converges without SafeArea change")
	_check(touch.capture_state().pad_index == -1 and not Input.is_action_pressed("move_right"), "activation cancels captured direction")
	_check(not touch._pad.visible and touch.pause_button().visible, "pad blocked, shared Pause remains")
	await _touch(tree, 4, position, false)
	await _tap(tree, ui.log_button)
	_check(ui.log_panel.visible, "touch reaches Battle Log")
	_check(session.outdoor_map().selected_interaction_target() == null, "Battle Log touch does not reach world picking")
	await _back(tree)
	_check(not ui.log_panel.visible and ui.visible and not tree.paused, "Back dismisses child, not Battle")
	await _back(tree)
	_check(shell.pause_visible() and tree.paused and ui.visible, "base Back delegates to Shell Pause")
	await _tap(tree, shell.resume_button)
	_check(not tree.paused and ui.visible, "Resume returns same Battle")
	await _key(tree, KEY_ESCAPE, true)
	await _key(tree, KEY_ESCAPE, false)
	_check(shell.pause_visible(), "desktop Escape uses shared Pause")
	await _tap(tree, shell.resume_button)
	for rect: Rect2 in [Rect2(0, 0, 1280, 720), Rect2(0, 0, 800, 480), Rect2(48, 12, 800, 480), Rect2(8, 12, 840, 480)]:
		safe.metrics = SafeAreaMetrics.new(Rect2(0, 0, 1280, 720), rect, false, true)
		presenter.refresh()
		await _settle(tree)
		var content_rect: Rect2 = safe.metrics.content_rect()
		_check(content_rect.encloses(ui._content.get_global_rect()), "battle content fits safe rect %s actual=%s" % [rect, ui._content.get_global_rect()])
		_check(content_rect.encloses(ui.log_button.get_global_rect()), "log touch target inside safe area")
		_check(ui.log_button.size.y >= 64 and ui.log_button.size.x >= 64, "touch minimum")
		_check(not ui.log_button.get_global_rect().intersects(touch.pause_button().get_global_rect()), "shared Pause never overlapped")
		for card: BattleParticipantCard in ui._cards:
			_check(content_rect.encloses(card.get_global_rect()), "primary participant card inside safe area")
	_check(Setup.complete(session), "same Session completes")
	await _settle(tree)
	_check(not ui.visible and session.outdoor_map().hud.visible and touch._pad.visible, "world UI/pad restored")
	_check(not Input.is_action_pressed("move_right"), "no stale movement replay")
	_check(shell.runtime_host().current_session() == session, "same Session identity")
	# Same production UI, explicitly test-injected policies; no production actions.
	Setup.register_probes(session)
	var random := Setup.CountingRandom.new()
	session.configure_combat_random_source(random)
	_check(Setup.start(session, &"cxr6.shell.qa", true).succeeded(), "QA-only UI composition")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var encounter: CombatEncounter = coordinator.active_encounter()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var enemy: NpcRuntimeState = session.outdoor_map().npc_runtimes()[0]
	var third: NpcRuntimeState = session.outdoor_map().npc_runtimes()[1]
	encounter.set_current_target(player.character_id, enemy.character_id)
	await _settle(tree)
	var force_before: int = player.state.recovery.inner_force.current
	await _tap(tree, ui.action_panel.first_action_button())
	_check(encounter.queued_player_action() != null, "actual touch action queues")
	_check(safe.metrics.content_rect().encloses(ui._content.get_global_rect()), "first QA button/queue reflow stays in current SafeArea")
	_check(player.state.recovery.inner_force.current == force_before and random.calls == 0, "UI touch receipt no resource/RNG/execution")
	_check(ui.current_projection().queue_status == Queue.READY, "UI displays READY")
	var first_id: StringName = encounter.queued_player_action().request.request_id
	player.busy.start_busy(2)
	await _settle(tree)
	_check(ui.current_projection().queue_status == Queue.WAITING_FOR_BUSY, "UI displays WAITING_FOR_BUSY")
	await _tap(tree, ui.action_panel._actions.get_child(1) as Button)
	var replacement_id: StringName = encounter.queued_player_action().request.request_id
	_check(replacement_id != first_id, "actual touch replaces busy slot")
	player.state.recovery.inner_force.current = 0
	await _tap(tree, ui.action_panel.first_action_button())
	_check(encounter.queued_player_action().request.request_id == replacement_id, "invalid UI replacement preserves queue")
	_check(ui.current_projection().queued_action().request.request_id == replacement_id, "invalid UI replacement preserves displayed authoritative queue")
	player.state.recovery.inner_force.current = force_before
	encounter.set_current_target(player.character_id, third.character_id) # Unit setup, not a UI selector.
	await _settle(tree)
	_check(ui.current_projection().current_target_id == third.character_id and ui.current_projection().queued_action().resolved_target_id == enemy.character_id, "UI current/queued target distinction")
	_check(ui.action_panel._queue.text.contains("Queued Target:"), "queued target visibly labeled separately")
	await _tap(tree, touch.pause_button())
	_check(tree.paused and encounter.queued_player_action().request.request_id == replacement_id, "shared Pause keeps exact pending request")
	var busy_before: int = player.busy.busy_value
	await _settle(tree, 20)
	_check(random.calls == 0 and player.busy.busy_value == busy_before, "paused UI advances neither RNG nor busy")
	await _tap(tree, shell.resume_button)
	_check(ui.current_projection().queued_action().request.request_id == replacement_id, "Resume reprojects, never resubmits")
	# Platform boundary simulation, not physical mobile qualification.
	var lifecycle: MobileLifecycleAdapter = shell.get_node("MobileLifecycle")
	lifecycle.set_capability(LifecycleFixture.EnabledLifecycle.new())
	lifecycle.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	lifecycle.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _settle(tree)
	_check(tree.paused and shell.pause_visible(), "Battle lifecycle loss uses existing Shell Pause")
	_check(encounter.queued_player_action().request.request_id == replacement_id and random.calls == 0, "lifecycle loss preserves exact slot and RNG")
	lifecycle.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	lifecycle.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _settle(tree)
	_check(tree.paused and shell.activity().resume_gate() == ApplicationActivity.ResumeGate.EXPLICIT_AFTER_LIFECYCLE, "foreground waits for explicit Resume")
	_check(player.busy.busy_value == busy_before and not touch._pad.visible, "foreground no catch-up or exploration pad")
	await _tap(tree, shell.resume_button)
	_check(not tree.paused and encounter.queued_player_action().request.request_id == replacement_id, "lifecycle Resume preserves slot without resubmission")
	_check(ui.is_ancestor_of(tree.root.gui_get_focus_owner()), "Resume focus returns to Battle, not hidden world")
	await _tap(tree, ui.action_panel._cancel)
	_check(encounter.queued_player_action() == null and ui.current_projection().queue_status == Queue.EMPTY, "actual Cancel touch reflects authoritative EMPTY")
	# Reflow with real registered buttons AND a queued target, the densest CXR6 view.
	await _tap(tree, ui.action_panel.first_action_button())
	for rect: Rect2 in [Rect2(0, 0, 800, 480), Rect2(48, 12, 800, 480)]:
		safe.metrics = SafeAreaMetrics.new(Rect2(0, 0, 960, 540), rect, false, true)
		presenter.refresh()
		await _settle(tree)
		_check(safe.metrics.content_rect().encloses(ui._content.get_global_rect()), "queued QA content fits minimum/inset safe area: %s" % ui._content.get_global_rect())
		if not safe.metrics.content_rect().encloses(ui._content.get_global_rect()):
			for child: Node in ui._content.get_children():
				print("CXR6 LAYOUT ", child.name, " size=", (child as Control).size, " min=", (child as Control).get_combined_minimum_size())
		_check(safe.metrics.content_rect().encloses(ui.action_panel._cancel.get_global_rect()), "cancel target remains inside safe area")
		_check(ui._recent.get_child_count() == 3, "three individual feedback rows cannot hide each other by wrapping")
	_check(Setup.complete(session), "QA encounter completion")
	await _settle(tree)
	shell.free()
	await _settle(tree, 2)
	tree.root.size = original_size
	tree.root.content_scale_size = original_scale


func _test_restored_session_battle(tree: SceneTree) -> void:
	var original_size: Vector2i = tree.root.size
	var original_scale: Vector2i = tree.root.content_scale_size
	tree.root.content_scale_size = Vector2i.ZERO
	tree.root.size = Vector2i(960, 540)
	var bytes: PackedByteArray = await preload("res://tests/application/application_shell_phase10c1b_test.gd").new()._valid_save_bytes(tree)
	var profile := GameSaveStorageProfile.isolated_test("cxr6-restore")
	var files := Fixtures.MemoryFiles.new()
	files.files[profile.canonical_path()] = bytes
	var shell: ApplicationShellController = ShellScene.instantiate()
	_check(shell.configure_before_start(profile, files, null, Fixtures.MemoryFiles.new(), Fixtures.FakeWindowCapability.new()), "restore fixture configures isolated storage")
	var touch: MobileTouchAdapter = shell.get_node("TouchCanvas/TouchInput")
	touch.set_capability(EnabledTouch.new())
	var safe := FakeSafe.new()
	safe.metrics = SafeAreaMetrics.new(Rect2(0, 0, 960, 540), Rect2(0, 0, 960, 540), false, true)
	var presenter: SafeAreaPresenter = shell.get_node("SafeAreaPresentation")
	presenter.set_capability(safe)
	tree.root.add_child(shell)
	await _settle(tree)
	await _tap(tree, shell.continue_button)
	await _settle(tree, 25)
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	_check(session != null and session.is_initialized(), "real Continue restores and commits Session through staging reparent")
	if session == null:
		shell.free()
		tree.root.size = original_size
		tree.root.content_scale_size = original_scale
		return
	session.set_process(false)
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	_check(presenter.metrics_changed.is_connected(ui._apply_metrics), "restored Battle reconnects shared SafeArea after reparent")
	_check(Setup.start(session, &"cxr6.restored").succeeded(), "restored Session can establish controlled encounter")
	await _settle(tree)
	_check(ExplorationPresentationBlocker.is_blocked(tree) and not touch._pad.visible, "restored Battle blocks exploration after reentry")
	safe.metrics = SafeAreaMetrics.new(Rect2(0, 0, 960, 540), Rect2(48, 12, 800, 480), false, true)
	presenter.refresh()
	await _settle(tree)
	_check(ui._content.get_global_rect() == safe.metrics.content_rect(), "restored Battle follows subsequent SafeArea changes")
	_check(Setup.complete(session), "restored controlled encounter completes")
	await _settle(tree)
	_check(not ExplorationPresentationBlocker.is_blocked(tree) and session.outdoor_map().hud.visible, "restored completion releases presentation context")
	shell.free()
	await _settle(tree, 2)
	tree.root.size = original_size
	tree.root.content_scale_size = original_scale
