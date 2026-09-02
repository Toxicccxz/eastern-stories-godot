extends "res://tests/application/mobile_touch_test.gd"

const Previous = preload("res://tests/application/application_shell_phase10c1b_test.gd")
const A = preload("res://application/lifecycle/application_activity.gd")

class EnabledLifecycle extends MobileLifecycleCapability:
	func enabled() -> bool:
		return true

class CountFiles extends Previous.MemoryFiles:
	var writes: int = 0
	var fail_write: bool = false
	func write_bytes(path: String, bytes: PackedByteArray) -> int:
		writes += 1
		return ERR_CANT_CREATE if fail_write else super.write_bytes(path, bytes)

class CountCoordinator extends OldPineSessionLoadCoordinator:
	var saves: int = 0
	func save_current(session: OldPineWorldSessionController) -> OldPineRuntimeSaveLoadResult:
		saves += 1
		return super.save_current(session)

class PhysicsProbe extends Node:
	var ticks: int = 0
	func _physics_process(_delta: float) -> void:
		ticks += 1

var _profile: GameSaveStorageProfile
var _files: CountFiles
var _coordinator: CountCoordinator
var _notifications: int = 0


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_model()
	await _test_desktop_and_lifetime(tree)
	await _test_freeze_and_input(tree)
	await _test_modals(tree)
	var bytes: PackedByteArray = await Previous.new()._valid_save_bytes(tree)
	await _test_recovery_choice(tree, bytes)
	for foreground_first: bool in [false, true]:
		for operation: String in ["new", "continue", "backup", "temp"]:
			await _test_pending_start(tree, operation, foreground_first, bytes)
		await _test_pending_end(tree, foreground_first)
		for outcome: String in ["success", "blocked", "write_failure"]:
			await _test_pending_save(tree, foreground_first, outcome)
	await _test_load_failure(tree, bytes)
	await _test_failed_new_and_pending_guard(tree)
	await _test_cave(tree)
	return {"assertions": _assertions, "failures": _failures}


func _test_model() -> void:
	for reverse_loss: bool in [false, true]:
		for reverse_gain: bool in [false, true]:
			var model: ApplicationActivity = A.new()
			var loss: Array[A.Event] = [A.Event.PAUSED, A.Event.FOCUS_OUT]
			var gain: Array[A.Event] = [A.Event.RESUMED, A.Event.FOCUS_IN]
			if reverse_loss: loss.reverse()
			if reverse_gain: gain.reverse()
			_check(model.receive(loss[0]) == A.Change.INTERACTION_LOST, "first independent loss freezes")
			_check(model.receive(loss[0]) == A.Change.NONE, "duplicate loss no transition")
			_check(model.receive(loss[1]) == A.Change.NONE, "second fact recorded without duplicate freeze")
			_check(not model.foreground() and not model.focused(), "independent facts retained")
			model.require_explicit_resume()
			_check(model.receive(gain[0]) == A.Change.NONE and not model.interaction_allowed(), "one positive fact insufficient")
			_check(model.receive(gain[1]) == A.Change.REACTIVATING and not model.interaction_allowed(), "both facts wait for presentation")
			_check(model.receive(gain[1]) == A.Change.NONE, "duplicate gain idempotent")
			_check(model.finish_reactivation() and model.interaction_allowed(), "layout completion opens interaction")
			_check(not model.finish_reactivation(), "duplicate layout finish no activation")
			_check(model.resume_gate() == A.ResumeGate.EXPLICIT_AFTER_LIFECYCLE, "foreground never clears resume gate")
			model.clear_resume_gate()
			_check(model.resume_gate() == A.ResumeGate.NORMAL, "explicit clear")
	_check(A.new().interaction_allowed(), "independent fresh activity")


func _shell(tree: SceneTree, bytes: PackedByteArray = PackedByteArray(), source: String = "") -> ApplicationShellController:
	_profile = GameSaveStorageProfile.isolated_test("phase10c2c")
	_files = CountFiles.new()
	if not bytes.is_empty():
		_files.files[_profile.canonical_path() + source] = bytes
	_coordinator = CountCoordinator.new(GameSaveRepository.new(_profile, _files))
	var shell: ApplicationShellController = ShellScene.instantiate()
	shell.configure_before_start(_profile, _files, _coordinator, Fixtures.MemoryFiles.new(), Fixtures.FakeWindowCapability.new())
	(shell.get_node("MobileLifecycle") as MobileLifecycleAdapter).set_capability(EnabledLifecycle.new())
	tree.root.add_child(shell)
	await _settle(tree)
	return shell


func _loss(shell: ApplicationShellController, reverse: bool = false) -> void:
	var adapter: MobileLifecycleAdapter = shell.get_node("MobileLifecycle")
	var events: Array[int] = [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_FOCUS_OUT]
	if reverse: events.reverse()
	for event: int in events:
		adapter.notification(event)
		adapter.notification(event)


func _gain(shell: ApplicationShellController, reverse: bool = false) -> void:
	var adapter: MobileLifecycleAdapter = shell.get_node("MobileLifecycle")
	var events: Array[int] = [Node.NOTIFICATION_APPLICATION_RESUMED, Node.NOTIFICATION_APPLICATION_FOCUS_IN]
	if reverse: events.reverse()
	for event: int in events:
		adapter.notification(event)
		adapter.notification(event)


func _test_desktop_and_lifetime(tree: SceneTree) -> void:
	var shell: ApplicationShellController = await _shell(tree)
	var adapter: MobileLifecycleAdapter = shell.get_node("MobileLifecycle")
	adapter.set_capability(MobileLifecycleCapability.new())
	_loss(shell)
	_check(shell.interaction_allowed() and not tree.paused, "desktop focus unchanged")
	adapter.set_capability(EnabledLifecycle.new())
	adapter.activity_event.connect(func(_event: A.Event) -> void: _notifications += 1)
	for cycle: int in 22:
		var before: int = _notifications
		shell.remove_child(adapter)
		adapter.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		_check(_notifications == before, "off-tree adapter ignores platform events")
		shell.add_child(adapter)
		adapter.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		_check(_notifications == before + 1, "reentry delivers once")
		_check(tree.paused and not shell.request_new_game_from_menu(), "empty inactive Menu blocks New")
		adapter.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		await _settle(tree, 2)
		_check(shell.menu_visible() and not tree.paused and shell.runtime_host().current_session() == null, "foreground empty menu contract")
		_check(adapter.activity_event.get_connections().size() == 2, "one Shell and one observer connection")
	_check(_coordinator.saves == 0 and _files.writes == 0, "menu cycles zero Save/preflight/write")
	shell.free()
	await _settle(tree, 2)


func _test_pending_start(tree: SceneTree, operation: String, foreground_first: bool, bytes: PackedByteArray) -> void:
	var source: String = ".bak" if operation == "backup" else (".tmp" if operation == "temp" else "")
	var shell: ApplicationShellController = await _shell(tree, PackedByteArray() if operation == "new" else bytes, source)
	var files_before: Dictionary[String, PackedByteArray] = _files.files.duplicate(true)
	var probe: PhysicsProbe = PhysicsProbe.new()
	shell.runtime_host().session_slot.add_child(probe) # Remove before request invariant check.
	probe.get_parent().remove_child(probe)
	var slot: Node = shell.runtime_host().session_slot
	slot.child_entered_tree.connect(func(child: Node) -> void:
		if child is OldPineWorldSessionController: child.add_child(probe)
	)
	var accepted: bool
	match operation:
		"new": accepted = shell.request_new_game_from_menu()
		"continue": accepted = shell.request_continue_from_menu()
		_:
			shell.request_recovery_choice_from_menu()
			accepted = shell.request_recovery_source(GameSaveRecoverySource.Value.BACKUP if operation == "backup" else GameSaveRecoverySource.Value.TEMP)
	_check(accepted and shell.runtime_host().request_pending(), operation + " actually queued")
	_loss(shell, foreground_first)
	_check(tree.paused and shell.busy_visible(), "pending start frozen without cancelling Busy")
	if foreground_first:
		_gain(shell, true)
		# Deterministic coordination boundary: finish layout before queued Host execution.
		shell._finish_mobile_reactivation()
		_check(shell.interaction_allowed() and tree.paused and shell.runtime_host().request_pending(), "foreground precedes actual completion, gate keeps tree paused")
	await _settle(tree, 8)
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	_check(session != null and shell.runtime_host().session_invariant_holds(), operation + " one validated commit/staging empty")
	_check(probe.ticks == 0 and not session.can_process(), "zero gameplay tick across commit")
	_check(shell.pause_visible() and tree.paused, "successful interrupted start is PAUSED")
	_check(_files.files == files_before and _coordinator.saves == 0, "start/recovery never writes/promotes/autosaves")
	if not foreground_first:
		_gain(shell)
		await _settle(tree, 3)
	_check(shell.activity().resume_gate() == A.ResumeGate.EXPLICIT_AFTER_LIFECYCLE, "start gate survives completion and foreground")
	_check(shell.request_resume() and not tree.paused, "fresh explicit Resume only")
	_check(shell.runtime_host().current_session() == session, "Resume retains committed graph")
	shell.free()
	await _settle(tree, 2)


func _test_pending_end(tree: SceneTree, foreground_first: bool) -> void:
	var shell: ApplicationShellController = await _shell(tree)
	shell.request_new_game_from_menu()
	await _settle(tree)
	shell.request_pause()
	shell.request_return_to_main_menu()
	_check(shell.confirm_current_result(), "real End queued")
	_loss(shell)
	if foreground_first:
		_gain(shell)
		shell._finish_mobile_reactivation()
	await _settle(tree)
	_check(shell.runtime_host().current_session() == null and shell.runtime_host().session_invariant_holds(), "End removes exact graph once")
	_check(shell.activity().resume_gate() == A.ResumeGate.NORMAL, "empty completion has no meaningless gate")
	if not foreground_first:
		_check(tree.paused and not shell.interaction_allowed(), "empty inactive Menu still blocks interaction")
		_gain(shell)
		await _settle(tree)
	_check(shell.menu_visible() and not tree.paused and _coordinator.saves == 0, "empty foreground Menu no Save/recreation")
	shell.free()
	await _settle(tree, 2)


func _test_pending_save(tree: SceneTree, foreground_first: bool, outcome: String) -> void:
	var shell: ApplicationShellController = await _shell(tree)
	shell.request_new_game_from_menu()
	await _settle(tree)
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	shell.request_pause()
	# Existing canonical baseline proves rollback, not merely absence of a new file.
	shell.request_save_from_pause()
	await _settle(tree)
	_check(shell.last_result().succeeded(), "manual baseline Save succeeds")
	shell.dismiss_current_result()
	var before: Dictionary[String, PackedByteArray] = _files.files.duplicate(true)
	if outcome == "blocked": session.player_runtime().relationship.add_opponent(&"lifecycle.blocker")
	_files.fail_write = outcome == "write_failure"
	var saves: int = _coordinator.saves
	_check(shell.request_save_from_pause(), "manual Save actually requested before interruption")
	_loss(shell)
	_check(shell.busy_visible() and _coordinator.saves == saves, "no optimistic Save success")
	if foreground_first:
		_gain(shell)
		shell._finish_mobile_reactivation()
	await _settle(tree)
	_check(_coordinator.saves == saves + 1, "exactly one explicit Save, zero lifecycle retry")
	_check(shell.result_visible() and tree.paused and shell.runtime_host().current_session() == session, "honest paused Save Result same Session")
	match outcome:
		"success": _check(shell.last_result().succeeded(), "interrupted manual Save success")
		"blocked":
			_check(shell.last_result().outcome() == ApplicationOperationResult.Outcome.SAVE_BLOCKED_COMBAT_OR_ACTION, "unchanged blocker product result")
			_check(session.player_runtime().relationship.has_opponent(&"lifecycle.blocker"), "blocker not cleared")
		"write_failure": _check(not shell.last_result().succeeded() and shell.runtime_host().last_save_result().outcome == OldPineRuntimeSaveLoadResult.Outcome.REPOSITORY_FAILED, "actual write failure retained")
	if outcome != "success": _check(_files.files == before, "blocked/failing Save keeps canonical/bak/tmp bytes")
	var result: ApplicationOperationResult = shell.last_result()
	if not foreground_first:
		_gain(shell)
		await _settle(tree)
	_check(shell.last_result() == result and shell.shell_state().result_origin() == ApplicationShellState.ResultOrigin.PAUSED, "foreground preserves exact Save result/origin")
	shell.free()
	await _settle(tree, 2)


func _test_load_failure(tree: SceneTree, bytes: PackedByteArray) -> void:
	for source: String in ["", ".bak", ".tmp"]:
		var shell: ApplicationShellController = await _shell(tree, bytes, source)
		if source == "": shell.request_continue_from_menu()
		else:
			shell.request_recovery_choice_from_menu()
			shell.request_recovery_source(GameSaveRecoverySource.Value.BACKUP if source == ".bak" else GameSaveRecoverySource.Value.TEMP)
		_files.files[_profile.canonical_path() + source] = "invalid".to_utf8_buffer()
		_loss(shell)
		await _settle(tree)
		_check(shell.result_visible() and not shell.last_result().succeeded() and shell.runtime_host().current_session() == null, "actual re-read failure no fallback/phantom Session")
		_gain(shell)
		await _settle(tree)
		_check(not tree.paused and shell.result_visible() and shell.activity().resume_gate() == A.ResumeGate.NORMAL, "failed start keeps menu result and clears gate")
		shell.free()
		await _settle(tree, 2)


func _test_modals(tree: SceneTree) -> void:
	var shell: ApplicationShellController = await _shell(tree)
	for playing: bool in [false, true]:
		if playing:
			shell.request_new_game_from_menu()
			await _settle(tree)
			shell.request_pause()
		if playing: shell.request_settings_from_pause()
		else: shell.request_settings_from_main_menu()
		shell.window_mode_option.select(1)
		var state: ApplicationShellState = shell.shell_state()
		_loss(shell)
		_check(not shell.apply_settings() and not shell.cancel_settings(), "inactive Settings commands blocked")
		await _back(tree)
		_gain(shell)
		await _settle(tree)
		_check(shell.shell_state() == state and shell.window_mode_option.selected == 1, "exact Settings origin and draft survive")
		_check(tree.paused == playing, "Settings correct tree boundary")
		shell.cancel_settings()
		if playing: shell.request_return_to_main_menu()
		else: shell._show_new_game_confirmation()
		var result: ApplicationOperationResult = shell.last_result()
		state = shell.shell_state()
		_loss(shell)
		_check(not shell.confirm_current_result() and not shell.dismiss_current_result(), "inactive confirmation cannot act")
		_gain(shell)
		await _settle(tree)
		_check(shell.shell_state() == state and shell.last_result() == result, "same confirmation/origin on foreground")
		shell.dismiss_current_result()
	_check(_coordinator.saves == 0 and _files.writes == 0, "modal transitions no gameplay or settings Save")
	shell.free()
	await _settle(tree, 2)


func _test_recovery_choice(tree: SceneTree, bytes: PackedByteArray) -> void:
	var shell: ApplicationShellController = await _shell(tree, bytes, ".bak")
	_files.files[_profile.canonical_path() + ".tmp"] = bytes
	_check(shell.request_recovery_choice_from_menu(), "existing candidate opens Recovery without starting restore")
	var state: ApplicationShellState = shell.shell_state()
	var before: Dictionary[String, PackedByteArray] = _files.files.duplicate(true)
	_loss(shell)
	_check(not shell.request_recovery_source(GameSaveRecoverySource.Value.BACKUP) and not shell.cancel_recovery_choice(), "inactive Recovery cannot select/cancel")
	await _back(tree)
	_gain(shell)
	await _settle(tree)
	_check(shell.shell_state() == state and shell.recovery_visible() and not tree.paused, "same empty-Host Recovery screen survives")
	_check(shell.runtime_host().current_session() == null and not shell.runtime_host().request_pending(), "Recovery interruption creates no hidden request/Session")
	_check(_files.files == before and _files.writes == 0 and _coordinator.saves == 0, "unselected recovery bytes neither promoted nor deleted")
	shell.free()
	await _settle(tree, 2)


func _test_failed_new_and_pending_guard(tree: SceneTree) -> void:
	var shell: ApplicationShellController = await _shell(tree)
	shell.request_new_game_from_menu()
	var orphan: Node = Node.new()
	shell.runtime_host().staging_slot.add_child(orphan)
	_loss(shell)
	await _settle(tree)
	_check(shell.result_visible() and not shell.last_result().succeeded() and shell.runtime_host().current_session() == null, "New failure preserves result/no phantom Session")
	orphan.free()
	_gain(shell)
	await _settle(tree)
	shell.dismiss_current_result()
	shell.request_new_game_from_menu()
	await _settle(tree)
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	_check(shell.runtime_host().request_save() and not shell.request_pause(), "normal user Pause still rejects pending Host")
	_loss(shell)
	_check(tree.paused and not session.can_process(), "lifecycle bypass freezes pending committed Session immediately")
	await _settle(tree)
	_check(_coordinator.saves == 1 and shell.last_result().succeeded(), "preexisting Host request completes once under lifecycle freeze")
	shell.free()
	await _settle(tree, 2)


func _freeze_facts(session: OldPineWorldSessionController, timer: Timer) -> Array:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var facts: Array = [session.get_instance_id(), session.active_map_id(), session.get_viewport().get_camera_2d(), session.outdoor_map().player_body.position, session.outdoor_map().player_body.velocity, player.life_status, player.exists_in_world, player.relationship.opponent_ids(), player.relationship.lethal_target_ids(), player.relationship.guarding, session.item_id_allocator().next_dynamic_sequence, session.inventory_state().registered_item_ids(), player.state.equipment.primary_weapon().instance_id, player.armor.occupied_slots(), timer.time_left, player.state.equipment.get_instance_id(), player.armor.get_instance_id(), player.busy.busy_value, player.busy.interrupt_threshold, session.outdoor_map().cadence_is_running(), session.outdoor_map().opportunity_timer.time_left]
	for rng: RandomStreamSnapshot in [session.combat_random_source().capture_random_state(), session.npc_random_source().capture_random_state(), session.world_interaction_random_source().capture_random_state()]:
		facts.append_array([rng.seed, rng.state])
	for npc: NpcRuntimeState in session.outdoor_map().npc_runtimes():
		var body: WorldCharacterBody2D = session.outdoor_map().runtime_body_for_character(npc.character_id)
		facts.append_array([npc.get_instance_id(), body.position, body.velocity, npc.life_status, npc.relationship.opponent_ids(), npc.relationship.guarding])
		facts.append_array([npc.busy.busy_value, npc.busy.interrupt_threshold, npc.exists_in_map, npc.character_state.equipment.get_instance_id(), npc.armor.get_instance_id(), npc.armor.occupied_slots()])
		for resource: CharacterResourceState in [npc.character_state.essence, npc.character_state.vitality, npc.character_state.spirit]:
			facts.append_array([resource.current, resource.effective, resource.maximum])
	for resource: CharacterResourceState in [player.state.essence, player.state.vitality, player.state.spirit]:
		facts.append_array([resource.current, resource.effective, resource.maximum])
	return facts


func _test_freeze_and_input(tree: SceneTree) -> void:
	var old_size: Vector2i = tree.root.size
	var old_scale: Vector2i = tree.root.content_scale_size
	tree.root.content_scale_size = Vector2i.ZERO
	tree.root.size = Vector2i(960, 540)
	var shell: ApplicationShellController = await _shell(tree)
	var adapter: MobileTouchAdapter = shell.get_node("TouchCanvas/TouchInput")
	adapter.set_capability(EnabledTouch.new())
	var presenter: SafeAreaPresenter = shell.get_node("SafeAreaPresentation")
	var emulation_before: bool = Input.is_emulating_mouse_from_touch()
	shell.request_new_game_from_menu()
	await _settle(tree)
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	var timer: Timer = Timer.new()
	timer.wait_time = 10.0
	session.add_child(timer)
	timer.start()
	var right: Vector2 = adapter.pad_rect().position + Vector2(160, 96)
	await _touch(tree, 71, right, true)
	session.player_runtime().relationship.add_opponent(&"lifecycle.unsafe")
	session.player_runtime().relationship.guarding = true
	session.player_runtime().busy.start_busy(7, 3)
	session.outdoor_map().opportunity_timer.start(5.0)
	var facts: Array = _freeze_facts(session, timer)
	_loss(shell)
	_check(tree.paused and shell.pause_visible() and not session.can_process(), "immediate mobile freeze")
	_check(not presenter.is_processing(), "inactive safe-area polling suspended")
	_check(not Input.is_action_pressed(&"move_right") and adapter.capture_state().pad_index == -1, "touch release before frozen gameplay")
	await _touch(tree, 82, right, true)
	await _back(tree)
	await _key(tree, KEY_ENTER, true)
	_check(not shell.request_resume() and not shell.request_save_from_pause(), "inactive typed and real input rejected")
	await _settle(tree, 35)
	var during: Array = _freeze_facts(session, timer)
	for index: int in facts.size():
		_check(during[index] == facts[index], "frozen fact %d: before=%s during=%s" % [index, facts[index], during[index]])
	for cycle: int in 22:
		_gain(shell, cycle % 2 == 0)
		await _settle(tree, 3)
		_check(shell.pause_visible() and tree.paused and shell.runtime_host().current_session() == session, "repeated return never resumes")
		_check(presenter.is_processing() and Input.is_emulating_mouse_from_touch() == emulation_before, "foreground restarts same presenter without emulation drift")
		_loss(shell, cycle % 2 == 1)
	_check(_coordinator.saves == 0 and _files.files.is_empty(), "unsafe state background zero preflight/capture/writes")
	_gain(shell)
	await _settle(tree)
	await _drag(tree, 71, right)
	await _drag(tree, 82, right)
	_check(not Input.is_action_pressed(&"move_right"), "pre/during background contacts quarantined")
	await _key(tree, KEY_ENTER, false)
	await _touch(tree, 71, right, false)
	await _touch(tree, 82, right, false)
	_check(shell.interaction_changed.get_connections().size() == 1, "one touch lifecycle subscription after cycles")
	_check(_freeze_facts(session, timer) == facts, "foreground without Resume still frozen")
	_check(shell.request_resume(), "explicit Resume accepts after inactive")
	await tree.physics_frame
	await tree.physics_frame
	_check(timer.time_left > 9.8, "no wall-clock timer catch-up")
	shell.free()
	tree.root.size = old_size
	tree.root.content_scale_size = old_scale
	await _settle(tree, 2)


func _test_cave(tree: SceneTree) -> void:
	var shell: ApplicationShellController = await _shell(tree)
	shell.request_new_game_from_menu()
	await _settle(tree)
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	# Boundary-only test. Real Android route is separate and must use physical entry.
	_check(session.handoff_to(OldPineWorldDefinitions.CAVE_MAP_ID, OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID, OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID, &"oldpine.cave.waterfall_passage.vine_landing").succeeded(), "Cave lifecycle fixture enters resident map")
	await _settle(tree)
	var map_id: StringName = session.active_map_id()
	_loss(shell)
	await _settle(tree)
	_gain(shell)
	await _settle(tree)
	_check(session.active_map_id() == map_id and shell.runtime_host().current_session() == session and tree.paused, "Cave same frozen Session/map")
	shell.free()
	await _settle(tree, 2)
