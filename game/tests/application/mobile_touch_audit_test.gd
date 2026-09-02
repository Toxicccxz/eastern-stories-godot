extends "res://tests/application/mobile_touch_test.gd"

class DisabledTouch extends MobileTouchCapability:
	func enabled() -> bool:
		return false

class EventLedger extends Node:
	var edges: Array[String] = []
	var backs: Array[bool] = []
	func _input(event: InputEvent) -> void:
		if event is InputEventAction:
			if event.device == MobileTouchAdapter.SOURCE_DEVICE:
				edges.append("%s:%s" % [event.action, event.pressed])
			if event.action == &"system_back":
				backs.append(event.pressed)
	func popup_event(event: InputEvent) -> void:
		if event is InputEventAction and event.action == &"system_back":
			backs.append(event.pressed)


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var size_before: Vector2i = tree.root.size
	var scale_before: Vector2i = tree.root.content_scale_size
	var mouse_touch_before: bool = Input.is_emulating_touch_from_mouse()
	var mouse_before: bool = Input.is_emulating_mouse_from_touch()
	Input.set_emulate_touch_from_mouse(true)
	Input.set_emulate_mouse_from_touch(true)
	tree.root.content_scale_size = Vector2i.ZERO
	tree.root.size = Vector2i(960, 540)
	var shell: ApplicationShellController = ShellScene.instantiate()
	var files := Fixtures.MemoryFiles.new()
	var window := Fixtures.FakeWindowCapability.new()
	shell.configure_before_start(GameSaveStorageProfile.isolated_test("10c2b-audit"), files, null, Fixtures.MemoryFiles.new(), window)
	var exits := ExitCounter.new()
	shell.set_exit_capability(exits)
	var touch: MobileTouchAdapter = shell.get_node("TouchCanvas/TouchInput")
	touch.set_capability(EnabledTouch.new())
	var presenter: SafeAreaPresenter = shell.get_node("SafeAreaPresentation")
	var safe := FakeSafe.new()
	safe.metrics = SafeAreaMetrics.normalize(Rect2(0, 0, 960, 540), Rect2(0, 0, 960, 540), Rect2(0, 0, 960, 540), Transform2D.IDENTITY, true)
	presenter.set_capability(safe)
	tree.root.add_child(shell)
	await _settle(tree)
	await _lifetime(tree, shell, touch, presenter)
	var ledger := EventLedger.new()
	ledger.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(ledger)
	await _scroll_adversarial(tree, shell, presenter)
	await _menu_back(tree, shell, exits, ledger)
	var menu_clicks: Array[int] = [0]
	shell.new_game_button.pressed.connect(func() -> void: menu_clicks[0] += 1)
	await _tap(tree, shell.new_game_button)
	_check(menu_clicks[0] == 1, "New Game one raw touch pair activates button once")
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	if session != null:
		await _edges(tree, touch, ledger)
		await _source_collision(tree, touch)
		await _world_cancel(tree, shell, session)
		await _mouse_collision(tree, touch, shell)
		await _reflow_and_blocker(tree, shell, touch, presenter, safe)
		await _session_cycles(tree, shell, touch, ledger, menu_clicks)
		await _multi_owner_handoff(tree, shell, touch)
		await _scaled_and_disabled(tree, shell, touch)
	ledger.free()
	shell.free()
	await _settle(tree)
	_check(Input.is_emulating_mouse_from_touch(), "Shell teardown restores prior true emulation")
	Input.set_emulate_mouse_from_touch(mouse_before)
	Input.set_emulate_touch_from_mouse(mouse_touch_before)
	tree.root.size = size_before
	tree.root.content_scale_size = scale_before
	return {"assertions": _assertions, "failures": _failures}


func _lifetime(tree: SceneTree, shell: ApplicationShellController, touch: MobileTouchAdapter, presenter: SafeAreaPresenter) -> void:
	for index: int in 3:
		touch.set_capability(EnabledTouch.new())
		_check(not Input.is_emulating_mouse_from_touch(), "repeat enable preserves one emulation owner")
		touch.set_capability(DisabledTouch.new())
		_check(Input.is_emulating_mouse_from_touch(), "disable restores previous engine state")
		touch.set_capability(EnabledTouch.new())
	var parent: Node = touch.get_parent()
	parent.remove_child(touch)
	_check(Input.is_emulating_mouse_from_touch(), "detach restores original emulation")
	parent.add_child(touch)
	# Two reentries before deferred reattachment: one subscription, no disconnect error.
	parent.remove_child(touch)
	parent.add_child(touch)
	await _settle(tree)
	_check(not Input.is_emulating_mouse_from_touch(), "reentry reacquires emulation without rebuilding controls")
	var listeners: int = 0
	for connection: Dictionary in presenter.metrics_changed.get_connections():
		if (connection["callable"] as Callable).get_object() == touch:
			listeners += 1
	_check(listeners == 1, "reentry reconnects exactly one metric listener")
	_check(touch.get_child_count() == 2, "reentry retains one pad and one Pause control")
	_check(shell.get_node("TouchCanvas").get_child_count() == 1, "Shell owns one adapter")
	touch.set_capability(DisabledTouch.new())
	Input.set_emulate_mouse_from_touch(false)
	touch.set_capability(EnabledTouch.new())
	touch.set_capability(DisabledTouch.new())
	_check(not Input.is_emulating_mouse_from_touch(), "prior false emulation also restored exactly")
	Input.set_emulate_mouse_from_touch(true)
	touch.set_capability(EnabledTouch.new())


func _edges(tree: SceneTree, touch: MobileTouchAdapter, ledger: EventLedger) -> void:
	var pad: Rect2 = touch.pad_rect()
	ledger.edges.clear()
	await _touch(tree, 91, pad.position + Vector2(160, 96), true)
	_check(ledger.edges == ["move_right:true"], "right press exactly one edge")
	ledger.edges.clear()
	await _drag(tree, 91, pad.position + Vector2(160, 32))
	_check(ledger.edges == ["move_up:true"], "right to upright retains right without repress")
	ledger.edges.clear()
	await _drag(tree, 91, pad.position + Vector2(32, 32))
	_check(ledger.edges.size() == 2 and ledger.edges.has("move_left:true") and ledger.edges.has("move_right:false"), "upright to upleft changes horizontal edges only")
	ledger.edges.clear()
	await _drag(tree, 91, pad.get_center())
	_check(ledger.edges.size() == 2 and ledger.edges.has("move_left:false") and ledger.edges.has("move_up:false"), "diagonal to center releases exactly two")
	await _touch(tree, 91, pad.get_center(), false)
	_check(Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "all pad directions released")
	var directions: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
	for direction: Vector2i in directions:
		var point: Vector2 = pad.get_center() + Vector2(direction) * 64
		ledger.edges.clear()
		await _touch(tree, 103, point, true)
		var expected_edges: int = absi(direction.x) + absi(direction.y)
		_check(ledger.edges.size() == expected_edges, "digital cell produces exactly its axis edges %s" % direction)
		_check(Input.get_vector("move_left", "move_right", "move_up", "move_down").is_equal_approx(Vector2(direction).normalized()), "native vector for digital cell %s" % direction)
		await _drag(tree, 103, point)
		_check(ledger.edges.size() == expected_edges, "stationary contact does not repress %s" % direction)
		await _touch(tree, 103, point, false, true)
		_check(ledger.edges.size() == expected_edges * 2 and Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "cancel releases only emitted axes %s" % direction)


func _world_cancel(tree: SceneTree, _shell: ApplicationShellController, session: OldPineWorldSessionController) -> void:
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	var landmark: WorldLandmarkArea2D = outdoor.get_node("Interactions/VineInteraction")
	# Before-route proximity/camera fixture. Stimulus is actual touch and physics picking.
	outdoor.player_body.global_position = landmark.global_position + Vector2(0, 60)
	for frame: int in 30:
		await tree.physics_frame
	var point: Vector2 = landmark.get_global_transform_with_canvas().origin
	var selections: Array[int] = [0]
	landmark.selection_requested.connect(func(_id: StringName) -> void: selections[0] += 1)
	await _touch(tree, 44, point, true)
	for frame: int in 5:
		await tree.physics_frame
	await _touch(tree, 44, point, false, true)
	_check(selections[0] == 0 and outdoor.selected_interaction_target() == null, "cancelled world contact never commits selection")
	await _mouse_click(tree, point)
	_check(selections[0] == 1, "fresh completed world tap picks exactly once")


func _mouse_collision(tree: SceneTree, touch: MobileTouchAdapter, shell: ApplicationShellController) -> void:
	var pause: Vector2 = touch.pause_button().get_global_rect().get_center()
	await _touch(tree, 72, pause, true)
	var physical := InputEventMouseButton.new()
	physical.device = MobileTouchAdapter.SOURCE_DEVICE
	physical.position = Vector2(750, 450)
	physical.button_index = MOUSE_BUTTON_LEFT
	physical.pressed = true
	Input.parse_input_event(physical)
	await _settle(tree)
	_check(touch.capture_state().pointer_index == -1, "real mouse takeover does not assume hardware ID cannot equal synthetic label")
	physical = physical.duplicate() as InputEventMouseButton
	physical.pressed = false
	Input.parse_input_event(physical)
	await _touch(tree, 72, pause, false)
	_check(not shell.pause_visible(), "cancelled synthetic pointer never clicks after numeric ID collision")


func _source_collision(tree: SceneTree, touch: MobileTouchAdapter) -> void:
	var right: Vector2 = touch.pad_rect().position + Vector2(160, 96)
	for keyboard_first: bool in [true, false]:
		var key := InputEventKey.new()
		key.device = MobileTouchAdapter.SOURCE_DEVICE
		key.keycode = KEY_D
		key.pressed = true
		if keyboard_first:
			Input.parse_input_event(key)
		await _touch(tree, 102, right, true)
		if not keyboard_first:
			Input.parse_input_event(key)
		await _settle(tree)
		if keyboard_first:
			await _touch(tree, 102, right, false)
		else:
			key = key.duplicate() as InputEventKey
			key.pressed = false
			Input.parse_input_event(key)
		await _settle(tree)
		_check(Input.is_action_pressed("move_right"), "equal numeric device labels still isolate binding and InputEventAction sources")
		key = key.duplicate() as InputEventKey
		key.pressed = false
		Input.parse_input_event(key)
		await _touch(tree, 102, right, false)
		_check(not Input.is_action_pressed("move_right"), "source collision test final release zero")


func _menu_back(tree: SceneTree, shell: ApplicationShellController, exits: ExitCounter, ledger: EventLedger) -> void:
	_check(InputMap.action_get_events(&"system_back").is_empty(), "system_back has no keyboard/hardware alias")
	_check(not ProjectSettings.get_setting("application/config/quit_on_go_back", true), "effective quit_on_go_back disabled")
	await _tap(tree, shell.menu_settings_button)
	var settings: ApplicationShellState = shell.shell_state()
	await _tap(tree, shell.window_mode_option)
	shell.window_mode_option.get_popup().window_input.connect(ledger.popup_event)
	ledger.backs.clear()
	(shell.get_node("AndroidBack") as AndroidBackAdapter).notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(tree)
	_check(ledger.backs == [true, false], "one Android notification emits one paired semantic Back")
	shell.window_mode_option.get_popup().window_input.disconnect(ledger.popup_event)
	_check(shell.shell_state() == settings and not shell.window_mode_option.get_popup().visible, "native popup Back changes no Shell state")
	await _back(tree)
	_check(shell.menu_visible() and exits.count == 0, "fresh second Back cancels Settings only")
	for state: ApplicationShellState in [ApplicationShellState.boot_inspecting(), ApplicationShellState.starting(ApplicationShellState.Operation.NEW_GAME), ApplicationShellState.saving()]:
		shell._set_state(state) # Isolate transient busy window; stimulus remains normal input.
		await _touch(tree, 66, Vector2(470, 210), true)
		await _back(tree)
		await _touch(tree, 66, Vector2(470, 210), false)
		_check(shell.shell_state() == state and exits.count == 0, "busy state rejects touch and Back without fallthrough")
		shell._set_state(ApplicationShellState.main_menu())


func _scroll_adversarial(tree: SceneTree, shell: ApplicationShellController, presenter: SafeAreaPresenter) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 110
	shell.add_child(layer)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(280, 80)
	scroll.size = Vector2(380, 220)
	layer.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var clicks: Array[int] = [0]
	for index: int in 12:
		var button := Button.new()
		button.text = "Audit native row %d" % index
		button.custom_minimum_size = Vector2(320, 64)
		button.pressed.connect(func() -> void: clicks[0] += 1)
		rows.add_child(button)
	await _settle(tree)
	for attempt: int in 3:
		scroll.scroll_vertical = 0
		await _settle(tree)
		var first: Button = rows.get_child(0)
		var point: Vector2 = first.get_global_rect().get_center()
		await _touch(tree, 205, point, true)
		for offset: int in [20, 40, 60]:
			await _drag(tree, 205, point - Vector2(0, offset))
		await _touch(tree, 205, point - Vector2(0, 60), false)
		_check(scroll.scroll_vertical > 0 and clicks[0] == attempt, "repeated native drag scrolls without row activation")
		_check(first.mouse_filter == Control.MOUSE_FILTER_STOP and rows.mouse_filter == Control.MOUSE_FILTER_PASS, "all nested original filters restored")
		# End native inertia by a cancelled stationary contact, then test a fresh tap.
		await _touch(tree, 205, scroll.get_global_rect().get_center(), true)
		await _touch(tree, 205, scroll.get_global_rect().get_center(), false, true)
		scroll.scroll_vertical = 0
		await _settle(tree)
		await _tap(tree, first)
		_check(clicks[0] == attempt + 1, "fresh tap after scrolling activates once")
	for cancellation: String in ["cancel", "reflow", "remove"]:
		scroll.scroll_vertical = 0
		await _settle(tree)
		var first: Button = rows.get_child(0)
		var point: Vector2 = first.get_global_rect().get_center()
		await _touch(tree, 205, point, true)
		if cancellation == "reflow":
			presenter.metrics_changed.emit(presenter.current_metrics()) # Boundary-only reflow stimulus.
		elif cancellation == "remove":
			layer.remove_child(scroll)
			(shell.get_node("TouchCanvas/TouchInput") as MobileTouchAdapter).cancel_contacts()
		await _touch(tree, 205, point, false, true)
		_check(clicks[0] == 3, "cancel/reflow/removed scroll never activates row")
		_check(first.mouse_filter == Control.MOUSE_FILTER_STOP and not first.is_pressed(), "cancel restores filter and native pressed visual")
		if cancellation == "remove":
			scroll.free()
	layer.free()
	await _settle(tree)


func _reflow_and_blocker(tree: SceneTree, shell: ApplicationShellController, touch: MobileTouchAdapter, presenter: SafeAreaPresenter, safe: SafeAreaCapability) -> void:
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	var hud: OldPineOutdoorHud = session.outdoor_map().hud
	for extent: Vector2 in [Vector2(960, 540), Vector2(1280, 720)]:
		tree.root.size = Vector2i(extent)
		(safe as FakeSafe).metrics = SafeAreaMetrics.normalize(Rect2(Vector2.ZERO, extent), Rect2(Vector2.ZERO, extent), Rect2(Vector2.ZERO, extent), Transform2D.IDENTITY, true)
		presenter.refresh()
		await _settle(tree)
		var right: Vector2 = touch.pad_rect().position + Vector2(160, 96)
		await _touch(tree, 55, right, true)
		await _tap(tree, hud.inventory_button, 61)
		_check(hud.inventory_panel.visible and not tree.paused and not Input.is_action_pressed("move_right"), "Inventory opens with second finger and cancels held pad, not gameplay")
		var inspections: Array[int] = [0]
		var count_inspect: Callable = func(_id: StringName) -> void: inspections[0] += 1
		hud.inventory_panel.inspect_requested.connect(count_inspect)
		var inspect: Button = hud.inventory_panel.row_container.get_child(0).get_child(1)
		var inspect_point: Vector2 = inspect.get_global_rect().get_center()
		await _touch(tree, 61, inspect_point, true)
		await _touch(tree, 61, inspect_point, false, true)
		_check(inspections[0] == 0 and not inspect.is_pressed(), "cancelled item row does not inspect or leave pressed visual")
		await _tap(tree, inspect, 61)
		_check(inspections[0] == 1, "fresh item Inspect requests exactly once")
		hud.inventory_panel.inspect_requested.disconnect(count_inspect)
		await _back(tree)
		await _drag(tree, 55, right)
		_check(not Input.is_action_pressed("move_right"), "closing blocker cannot promote held finger")
		await _touch(tree, 55, right, false)
		await _touch(tree, 55, right, true)
		await _touch(tree, 61, touch.pause_button().get_global_rect().get_center(), true)
		(safe as FakeSafe).metrics = SafeAreaMetrics.normalize(Rect2(Vector2.ZERO, extent), Rect2(Vector2.ZERO, extent), Rect2(32, 0, extent.x - 32, extent.y - 24), Transform2D.IDENTITY, true)
		presenter.refresh()
		await _drag(tree, 55, touch.pad_rect().get_center())
		await _touch(tree, 61, touch.pause_button().get_global_rect().get_center(), false)
		_check(touch.capture_state().pad_index == -1 and touch.capture_state().pointer_index == -1 and not shell.pause_visible(), "safe reflow quarantines both owners without Pause activation")
		await _touch(tree, 55, right, false)
		_check(Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "reflow leaves no movement source")
	tree.root.size = Vector2i(960, 540)
	(safe as FakeSafe).metrics = SafeAreaMetrics.normalize(Rect2(0, 0, 960, 540), Rect2(0, 0, 960, 540), Rect2(0, 0, 960, 540), Transform2D.IDENTITY, true)
	presenter.refresh()
	await _settle(tree)


func _session_cycles(tree: SceneTree, shell: ApplicationShellController, touch: MobileTouchAdapter, ledger: EventLedger, menu_clicks: Array[int]) -> void:
	var touch_id: int = touch.get_instance_id()
	await _tap(tree, touch.pause_button())
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	var saves: Array[int] = [0]
	shell.runtime_host().save_completed.connect(func(_result: OldPineRuntimeSaveLoadResult) -> void: saves[0] += 1)
	var point: Vector2 = shell.save_button.get_global_rect().get_center()
	await _touch(tree, 71, point, true)
	await _touch(tree, 71, point, false, true)
	_check(saves[0] == 0 and not shell.save_button.is_pressed(), "cancelled Save never requests transaction or leaves pressed button")
	await _tap(tree, shell.save_button)
	_check(saves[0] == 1 and shell.result_visible(), "fresh Save exactly one existing Host transaction")
	await _back(tree)
	await _repeat_sessions(tree, shell, touch, ledger, menu_clicks, touch_id, session)


func _repeat_sessions(tree: SceneTree, shell: ApplicationShellController, touch: MobileTouchAdapter, ledger: EventLedger, menu_clicks: Array[int], touch_id: int, session: OldPineWorldSessionController) -> void:
	for cycle: int in 2:
		await _tap(tree, shell.return_button)
		var confirms: Array[int] = [0]
		shell.confirm_button.pressed.connect(func() -> void: confirms[0] += 1, CONNECT_ONE_SHOT)
		await _back(tree)
		_check(confirms[0] == 0 and shell.runtime_host().current_session() == session and shell.pause_visible(), "Back destructive confirmation cannot confirm or dispose Session")
		await _tap(tree, shell.return_button)
		await _tap(tree, shell.confirm_button)
		_check(confirms[0] == 1 and shell.runtime_host().current_session() == null and shell.menu_visible(), "one fresh confirmation disposes Session exactly once")
		_check(touch.get_instance_id() == touch_id and not Input.is_emulating_mouse_from_touch(), "Return retains Shell adapter and emulation ownership")
		if cycle == 0:
			await _tap(tree, shell.continue_button)
		else:
			await _tap(tree, shell.new_game_button)
			await _back(tree)
			_check(shell.menu_visible() and shell.runtime_host().current_session() == null, "Back New Game replacement never starts Session")
			await _tap(tree, shell.new_game_button)
			await _tap(tree, shell.confirm_button)
		session = shell.runtime_host().current_session()
		_check(session != null and touch.get_instance_id() == touch_id and shell.get_node("TouchCanvas").get_child_count() == 1, "Continue/New Game has exactly one persistent adapter")
		ledger.edges.clear()
		await _tap(tree, touch.pause_button())
		_check(ledger.edges == ["pause_game:true", "pause_game:false"] and shell.pause_visible(), "one Pause gesture is one paired semantic intent after Session cycles")
	_check(menu_clicks[0] == 3, "initial and two replacement New Game taps each activate once")
	await _back(tree)


func _multi_owner_handoff(tree: SceneTree, shell: ApplicationShellController, touch: MobileTouchAdapter) -> void:
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	var identity: int = touch.get_instance_id()
	for to_cave: bool in [true, false]:
		var right: Vector2 = touch.pad_rect().position + Vector2(160, 96)
		var pause: Vector2 = touch.pause_button().get_global_rect().get_center()
		await _touch(tree, 800, pause, true)
		await _touch(tree, 19, right, true)
		await _touch(tree, 47, right, true)
		_check(touch.capture_state().pointer_index == 800 and touch.capture_state().pad_index == 19 and touch.capture_state().owner_of(47) == TouchCaptureState.Owner.IGNORED, "nonsequential IDs retain two owners and ignored third")
		# Integration boundary stimulus only; the player route is independently live-tested.
		var result: OldPineMapHandoffResult
		if to_cave:
			result = session.handoff_to(OldPineWorldDefinitions.CAVE_MAP_ID, OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID, OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID, &"oldpine.cave.waterfall_passage.vine_landing")
		else:
			result = session.handoff_to(OldPineWorldDefinitions.OUTDOOR_MAP_ID, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, &"oldpine.outdoor.central_clearing.player_start")
		await _settle(tree)
		await _touch(tree, 800, pause, false)
		await _drag(tree, 19, right)
		await _drag(tree, 47, right)
		_check(result.succeeded() and not shell.pause_visible() and Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "handoff cancels both owners and ignored third cannot promote")
		_check(touch.get_instance_id() == identity and shell.get_node("TouchCanvas").get_child_count() == 1, "both directions preserve sole adapter identity")
		await _touch(tree, 19, right, false)
		await _touch(tree, 47, right, false)
		await _touch(tree, 47, right, true)
		_check(Input.is_action_pressed("move_right"), "only fresh reused index after handoff may reacquire pad")
		await _touch(tree, 47, right, false)


func _scaled_and_disabled(tree: SceneTree, shell: ApplicationShellController, touch: MobileTouchAdapter) -> void:
	tree.root.size = Vector2i(1920, 1080)
	tree.root.content_scale_size = Vector2i(960, 540)
	await _settle(tree)
	var logical: Vector2 = touch.pad_rect().position + Vector2(160, 96)
	await _touch(tree, 34, logical * 2, true)
	_check(Input.is_action_pressed("move_right"), "physical screen coordinates transform to logical pad under 2x stretch")
	await _touch(tree, 34, logical * 2, false)
	tree.root.content_scale_size = Vector2i.ZERO
	tree.root.size = Vector2i(960, 540)
	await _settle(tree)
	logical = touch.pad_rect().position + Vector2(160, 96)
	await _touch(tree, 34, logical, true)
	touch.set_capability(DisabledTouch.new())
	await _touch(tree, 34, logical, false)
	_check(not touch.pause_button().visible and not Input.is_action_pressed("move_right"), "disable hides controls and clears held source")
	touch.set_capability(EnabledTouch.new())
	await _touch(tree, 34, logical, true)
	_check(Input.is_action_pressed("move_right"), "lift while disabled allows later fresh index reuse")
	await _touch(tree, 34, logical, false)
	touch.set_capability(DisabledTouch.new())
	await _key(tree, KEY_D, true)
	_check(Input.is_action_pressed("move_right"), "disabled overlay does not intercept physical keyboard")
	await _key(tree, KEY_D, false)
	await _key(tree, KEY_ESCAPE, true)
	await _key(tree, KEY_ESCAPE, false)
	_check(shell.pause_visible(), "desktop pause_game retains existing Escape behavior")
	await _key(tree, KEY_ESCAPE, true)
	await _key(tree, KEY_ESCAPE, false)
	_check(not shell.pause_visible(), "desktop ui_cancel resumes without Android exit policy")
	touch.set_capability(EnabledTouch.new())
