extends RefCounted

const ShellScene: PackedScene = preload("res://scenes/application/application_shell.tscn")
const Fixtures = preload("res://tests/application/application_shell_phase10c1c_test.gd")
const FakeSafe = preload("res://tests/presentation/fake_safe_area_capability.gd")
var _assertions: int = 0
var _failures: Array[String] = []
var _clicks: int = 0
var _save_completions: int = 0
var _takes: int = 0

class EnabledTouch extends MobileTouchCapability:
	func enabled() -> bool:
		return true

class ExitCounter extends ApplicationExitCapability:
	var count: int = 0
	func request_quit(_tree: SceneTree) -> void:
		count += 1

class InputCounter extends Node:
	var action_edges: int = 0
	func _input(event: InputEvent) -> void:
		if event is InputEventAction and event.device == MobileTouchAdapter.SOURCE_DEVICE:
			action_edges += 1


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_capture()
	await _test_viewport(tree)
	return {"assertions": _assertions, "failures": _failures}


func _check(value: bool, label: String) -> void:
	_assertions += 1
	if not value:
		_failures.append(label)


func _test_capture() -> void:
	var bounds: Rect2 = Rect2(16, 100, 192, 192)
	for row: int in 3:
		for col: int in 3:
			_check(TouchCaptureState.pad_direction(bounds.position + Vector2(col * 64 + 32, row * 64 + 32), bounds) == Vector2i(col - 1, row - 1), "all nine digital pad cells")
	_check(TouchCaptureState.pad_direction(bounds.end, bounds) == Vector2i.ZERO, "outside/exclusive end neutral")
	for first_pad: bool in [true, false]:
		var capture: TouchCaptureState = TouchCaptureState.new()
		_check(capture.press(4, first_pad, true, true) == (TouchCaptureState.Owner.PAD if first_pad else TouchCaptureState.Owner.POINTER), "first owner")
		_check(capture.press(1, not first_pad, true, true) == (TouchCaptureState.Owner.POINTER if first_pad else TouchCaptureState.Owner.PAD), "second owner reverse order")
		_check(capture.press(2, false, true, true) == TouchCaptureState.Owner.IGNORED, "third finger ignored")
		capture.release(4)
		_check(capture.owner_of(2) == TouchCaptureState.Owner.IGNORED, "held finger never promoted")
		capture.cancel()
		_check(capture.pad_index == -1 and capture.pointer_index == -1, "cancel clears owners")
		_check(capture.press(2, true, true, true) == TouchCaptureState.Owner.IGNORED, "quarantined press duplicate ignored")
		capture.release(2)
		_check(capture.press(2, true, true, true) == TouchCaptureState.Owner.PAD, "fresh reused index valid")
	var other: TouchCaptureState = TouchCaptureState.new()
	_check(other.pad_index == -1, "independent state")


func _settle(tree: SceneTree, frames: int = 12) -> void:
	for frame: int in frames:
		await tree.process_frame


func _touch(tree: SceneTree, index: int, position: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.device = 3
	event.index = index
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	await _settle(tree)


func _tap(tree: SceneTree, control: Control, index: int = 0) -> void:
	var center: Vector2 = control.get_global_rect().get_center()
	await _touch(tree, index, center, true)
	await _touch(tree, index, center, false)


func _drag(tree: SceneTree, index: int, position: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.device = 3
	event.index = index
	event.position = position
	Input.parse_input_event(event)
	await _settle(tree)


func _key(tree: SceneTree, key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	await _settle(tree)


func _back(tree: SceneTree) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"system_back"
		event.pressed = pressed
		Input.parse_input_event(event)
	await _settle(tree)


func _test_native_scroll(tree: SceneTree, shell: ApplicationShellController) -> void:
	# Real Controls, native ScrollContainer deadzone/cancellation, no scroll setter.
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
	for index: int in 12:
		var button := Button.new()
		button.text = "Long native scroll row %d" % index
		button.custom_minimum_size = Vector2(300, 64)
		button.pressed.connect(func() -> void: _clicks += 1)
		rows.add_child(button)
	await _settle(tree)
	var start: Vector2 = scroll.position + Vector2(170, 100)
	var clicks_before: int = _clicks
	await _touch(tree, 6, start, true)
	for offset: int in [20, 40, 60, 80]:
		await _drag(tree, 6, start - Vector2(0, offset))
	await _touch(tree, 6, start - Vector2(0, 80), false)
	_check(scroll.scroll_vertical > 0, "native finger scroll advances actual ScrollContainer")
	_check(_clicks == clicks_before, "scroll cancels initially pressed row")
	var button: Button = rows.get_child(0) as Button
	_check(button.mouse_filter == Control.MOUSE_FILTER_STOP, "gesture restores original Control mouse filter")
	layer.free()
	await _settle(tree)


func _test_back_busy(tree: SceneTree, shell: ApplicationShellController, exits: ExitCounter) -> void:
	# Typed state setup isolates normally short synchronous busy windows; the stimulus is input.
	for state: ApplicationShellState in [ApplicationShellState.boot_inspecting(), ApplicationShellState.starting(ApplicationShellState.Operation.NEW_GAME), ApplicationShellState.saving()]:
		shell._set_state(state)
		await _back(tree)
		_check(shell.shell_state() == state, "Back consumed in typed busy state %d" % state.mode())
	shell._set_state(ApplicationShellState.main_menu())
	shell.runtime_host()._request_pending = true
	var count: int = exits.count
	await _back(tree)
	_check(exits.count == count and shell.menu_visible(), "Host pending blocks destructive Back")
	shell.runtime_host()._request_pending = false
	shell._set_state(ApplicationShellState.recovery_choice())
	await _back(tree)
	_check(shell.menu_visible(), "Back Recovery cancels to menu")
	shell._set_state(ApplicationShellState.result(ApplicationShellState.ResultOrigin.MAIN_MENU))
	await _back(tree)
	_check(shell.menu_visible() and exits.count == count, "Back Result main dismisses without quit")


func _test_viewport(tree: SceneTree) -> void:
	var original_size: Vector2i = tree.root.size
	var original_scale: Vector2i = tree.root.content_scale_size
	var original_mouse_touch: bool = Input.is_emulating_touch_from_mouse()
	var original_emulation: bool = Input.is_emulating_mouse_from_touch()
	# Native ScrollContainer uses DisplayServer touchscreen availability. This enables
	# that engine capability on desktop; synthesized mouse goes through Viewport only.
	Input.set_emulate_touch_from_mouse(true)
	tree.root.content_scale_size = Vector2i.ZERO
	tree.root.size = Vector2i(960, 540)
	var shell: ApplicationShellController = ShellScene.instantiate()
	var files := Fixtures.MemoryFiles.new()
	var settings_files := Fixtures.MemoryFiles.new()
	var window := Fixtures.FakeWindowCapability.new()
	window.editable = true
	shell.configure_before_start(GameSaveStorageProfile.isolated_test("10c2b"), files, null, settings_files, window)
	var exit_counter := ExitCounter.new()
	shell.set_exit_capability(exit_counter)
	var touch: MobileTouchAdapter = shell.get_node("TouchCanvas/TouchInput") as MobileTouchAdapter
	touch.set_capability(EnabledTouch.new())
	var presenter: SafeAreaPresenter = shell.get_node("SafeAreaPresentation") as SafeAreaPresenter
	var safe := FakeSafe.new()
	safe.metrics = SafeAreaMetrics.normalize(Rect2(0, 0, 960, 540), Rect2(0, 0, 960, 540), Rect2(0, 0, 960, 540), Transform2D.IDENTITY, true)
	presenter.set_capability(safe)
	tree.root.add_child(shell)
	await _settle(tree)
	_check(not Input.is_emulating_mouse_from_touch(), "custom touch owns emulation once")
	_check(not touch.pause_button().visible, "menu hides gameplay touch UI")
	await _test_back_busy(tree, shell, exit_counter)
	await _test_native_scroll(tree, shell)
	await _key(tree, KEY_ESCAPE, true)
	await _key(tree, KEY_ESCAPE, false)
	_check(exit_counter.count == 0, "desktop generic cancel never exits")
	await _back(tree)
	await _back(tree)
	_check(exit_counter.count == 1, "empty Main Menu only requests quit once")
	await _tap(tree, shell.menu_settings_button)
	_check(shell.shell_state().mode() == ApplicationShellState.Mode.SETTINGS, "touch Main Menu Settings")
	await _tap(tree, shell.window_mode_option)
	_check(shell.window_mode_option.get_popup().visible, "real OptionButton popup opens")
	await _back(tree)
	_check(not shell.window_mode_option.get_popup().visible and shell.settings_visible(), "one Back closes popup only")
	await _tap(tree, shell.settings_cancel_button)
	_check(shell.menu_visible(), "touch Settings Cancel to menu")
	await _tap(tree, shell.menu_settings_button)
	await _back(tree)
	_check(shell.menu_visible(), "Back Settings main preserves typed origin")
	await _tap(tree, shell.new_game_button)
	_check(shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING, "touch New Game normal viewport path")
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	if session == null:
		shell.free()
		return
	_check(touch.pause_button().visible, "gameplay touch Pause visible")
	var pad: Rect2 = touch.pad_rect()
	var right: Vector2 = pad.position + Vector2(160, 96)
	var left: Vector2 = pad.position + Vector2(32, 96)
	var counter := InputCounter.new()
	tree.root.add_child(counter)
	await _touch(tree, 4, right, true)
	_check(Input.is_action_pressed("move_right"), "pad feeds existing action")
	var edges: int = counter.action_edges
	await _drag(tree, 4, right)
	_check(counter.action_edges == edges, "same cell emits no press spam")
	await _drag(tree, 4, pad.position + Vector2(160, 32))
	_check(Input.is_action_pressed("move_up") and Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_down"), "diagonal exactly two existing actions")
	await _drag(tree, 4, pad.position - Vector2.ONE)
	_check(Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO and touch.capture_state().pad_index == 4, "outside neutral retains pad owner")
	await _drag(tree, 4, right)
	await _key(tree, KEY_D, true)
	await _touch(tree, 4, right, false)
	_check(Input.is_action_pressed("move_right"), "touch release does not release held keyboard")
	await _touch(tree, 4, right, true)
	await _key(tree, KEY_D, false)
	_check(Input.is_action_pressed("move_right"), "keyboard release does not release touch")
	await _key(tree, KEY_A, true)
	_check(Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "opposite sources use native vector cancellation")
	await _key(tree, KEY_A, false)
	await _touch(tree, 4, right, false)
	_check(not Input.is_action_pressed("move_right"), "both sources released")
	# A third contact cannot click Pause or steal the pointer; a real mouse cancels
	# only the pointer owner, not the independent pad owner.
	await _touch(tree, 4, right, true)
	var pause_center: Vector2 = touch.pause_button().get_global_rect().get_center()
	await _touch(tree, 1, pause_center, true)
	await _touch(tree, 2, pause_center, true)
	var mouse := InputEventMouseButton.new()
	mouse.device = 0
	mouse.position = Vector2(700, 500)
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	Input.parse_input_event(mouse)
	await _settle(tree)
	_check(Input.is_action_pressed("move_right") and touch.capture_state().pointer_index == -1, "physical mouse takeover preserves pad only")
	mouse = mouse.duplicate() as InputEventMouseButton
	mouse.pressed = false
	Input.parse_input_event(mouse)
	await _touch(tree, 1, pause_center, false)
	await _drag(tree, 2, pause_center)
	await _touch(tree, 2, pause_center, false)
	_check(not shell.pause_visible(), "quarantined pointer and ignored third cannot click after takeover")
	await _touch(tree, 4, right, false)
	await _touch(tree, 4, left, true)
	await _tap(tree, touch.pause_button(), 1)
	_check(shell.pause_visible() and not Input.is_action_pressed("move_left"), "movement then second finger Pause clears movement")
	await _drag(tree, 4, right)
	_check(not Input.is_action_pressed("move_right"), "held pad cannot cross Pause transition")
	await _back(tree)
	await _drag(tree, 4, right)
	_check(not Input.is_action_pressed("move_right"), "Resume cannot recapture old finger")
	await _touch(tree, 4, right, false)
	await _touch(tree, 1, touch.pause_button().get_global_rect().get_center(), true)
	await _touch(tree, 4, right, true)
	_check(Input.is_action_pressed("move_right"), "pointer first permits second movement owner")
	await _touch(tree, 1, touch.pause_button().get_global_rect().get_center(), false)
	_check(shell.pause_visible() and not Input.is_action_pressed("move_right"), "reverse acquisition order Pause once")
	await _touch(tree, 4, right, false)
	await _tap(tree, shell.pause_settings_button)
	await _back(tree)
	_check(shell.pause_visible() and tree.paused, "Back Settings paused origin does not Resume")
	await _tap(tree, shell.return_button)
	await _back(tree)
	_check(shell.pause_visible() and shell.runtime_host().current_session() == session, "Back cancels destructive Return confirmation")
	await _tap(tree, shell.resume_button)
	await _tap(tree, touch.pause_button())
	shell.runtime_host().save_completed.connect(func(_result: OldPineRuntimeSaveLoadResult) -> void: _save_completions += 1)
	await _tap(tree, shell.save_button)
	_check(_save_completions == 1 and shell.result_visible(), "touch Save requests exactly one completion")
	await _back(tree)
	_check(shell.pause_visible() and tree.paused, "Back Save Result paused origin does not Resume")
	await _back(tree)
	await _tap(tree, session.outdoor_map().hud.inventory_button)
	_check(session.outdoor_map().hud.inventory_panel.visible and not tree.paused, "touch Inventory no gameplay pause")
	var inventory: PlayerInventoryPanel = session.outdoor_map().hud.inventory_panel
	await _tap(tree, inventory.row_container.get_child(0).get_child(1) as Button)
	_check(inventory.inspection_display().contains("Skill: sword"), "touch Inspect uses existing stable item row path")
	await _touch(tree, 4, right, true)
	_check(not Input.is_action_pressed("move_right"), "item panel blocks movement capture")
	await _touch(tree, 4, right, false, true)
	await _back(tree)
	_check(not session.outdoor_map().hud.inventory_panel.visible and not tree.paused, "Back closes item panel only")
	await _touch(tree, 4, right, true)
	safe.metrics = SafeAreaMetrics.normalize(Rect2(0, 0, 960, 540), Rect2(0, 0, 960, 540), Rect2(48, 0, 912, 516), Transform2D.IDENTITY, true)
	presenter.refresh()
	await _drag(tree, 4, right)
	_check(not Input.is_action_pressed("move_right"), "safe reflow quarantines held contact")
	await _touch(tree, 4, right, false)
	await _test_item_and_handoff(tree, shell, touch, session)
	await _test_panel_scroll_and_geometry(tree, session.outdoor_map().hud, safe, presenter, touch)
	counter.free()
	shell.free()
	await _settle(tree)
	_check(Input.is_emulating_mouse_from_touch() == original_emulation, "teardown restores emulation")
	Input.set_emulate_touch_from_mouse(original_mouse_touch)
	tree.root.size = original_size
	tree.root.content_scale_size = original_scale


func _mouse_click(tree: SceneTree, position: Vector2) -> void:
	await _touch(tree, 7, position, true)
	await _touch(tree, 7, position, false)
	for frame: int in 5:
		await tree.physics_frame


func _test_item_and_handoff(tree: SceneTree, shell: ApplicationShellController, touch: MobileTouchAdapter, session: OldPineWorldSessionController) -> void:
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	var original_rng: CombatRandomSource = outdoor.combat_random_source()
	# Corpse/proximity are pre-route fixtures, not a claim that touch killed the NPC.
	await preload("res://tests/runtime/oldpine_full_loot_loop_test.gd").new()._kill_bandit(outdoor, outdoor.npc_runtimes()[0], tree)
	outdoor.configure_combat_random_source(original_rng)
	var corpse: CorpseState = outdoor.corpse_states()[0]
	var view: Node2D = outdoor.corpse_view_for(corpse.corpse_item_instance_id)
	outdoor.player_body.global_position = view.global_position + Vector2(0, 60)
	for frame: int in 30:
		await tree.physics_frame
	await _mouse_click(tree, view.get_global_transform_with_canvas().origin)
	await _tap(tree, outdoor.hud.open_loot_button)
	var loot: OldPineLootPanel = outdoor.hud.loot_panel
	_check(loot.visible and loot.visible_rows().size() == 2, "touch world corpse picking and existing Open Loot HUD")
	if loot.visible and not loot.visible_rows().is_empty():
		loot.take_requested.connect(func(_id: StringName) -> void: _takes += 1)
		var before: int = loot.visible_rows().size()
		await _tap(tree, loot.row_container.get_child(0).get_child(1) as Button)
		_check(_takes == 1 and loot.visible_rows().size() == before - 1, "touch Take once removes exactly one authoritative row")
		await _tap(tree, loot.get_node("%LootCloseButton") as Button)
		_check(not loot.visible, "touch Loot Close")
	await _tap(tree, outdoor.hud.inventory_button)
	var inventory: PlayerInventoryPanel = outdoor.hud.inventory_panel
	_check(inventory.visible_rows().size() == 2, "taken item appears in existing Inventory authority")
	await _tap(tree, inventory.get_node("%PlayerInventoryCloseButton") as Button)
	_check(not inventory.visible, "touch Inventory Close")
	var id: int = touch.get_instance_id()
	var right: Vector2 = touch.pad_rect().position + Vector2(160, 96)
	await _touch(tree, 4, right, true)
	# Unit-level handoff boundary setup; live player route is separately validated.
	var to_cave: OldPineMapHandoffResult = session.handoff_to(OldPineWorldDefinitions.CAVE_MAP_ID, OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID, OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID, &"oldpine.cave.waterfall_passage.vine_landing")
	await _settle(tree)
	await _drag(tree, 4, right)
	_check(to_cave.succeeded() and not Input.is_action_pressed("move_right"), "map handoff cancels held pad without recapture")
	await _touch(tree, 4, right, false)
	_check(touch.get_instance_id() == id and touch.pause_button().visible and session.cave_map().find_children("HUD", "CanvasLayer", true, false).is_empty(), "same Shell touch adapter in Cave without Outdoor HUD")
	await _tap(tree, touch.pause_button())
	_check(shell.pause_visible(), "Cave touch Pause uses same semantic path")
	await _back(tree)
	var back: OldPineMapHandoffResult = session.handoff_to(OldPineWorldDefinitions.OUTDOOR_MAP_ID, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, &"oldpine.outdoor.central_clearing.player_start")
	await _settle(tree)
	_check(back.succeeded() and touch.get_instance_id() == id, "return retains one adapter identity")
	# A pointer still down on a dismissed surface is quarantined, not retargeted.
	await _tap(tree, touch.pause_button())
	for use_settings: bool in [true, false]:
		await _tap(tree, shell.pause_settings_button if use_settings else shell.return_button)
		var old_control: Button = shell.settings_cancel_button if use_settings else shell.cancel_button
		await _touch(tree, 6, old_control.get_global_rect().get_center(), true)
		await _back(tree)
		await _drag(tree, 6, shell.resume_button.get_global_rect().get_center())
		await _touch(tree, 6, shell.resume_button.get_global_rect().get_center(), false)
		_check(shell.pause_visible() and tree.paused, "held pointer cannot Resume after Settings/Result dismissal")
	await _back(tree)


func _test_panel_scroll_and_geometry(tree: SceneTree, hud: OldPineOutdoorHud, safe: SafeAreaCapability, presenter: SafeAreaPresenter, touch: MobileTouchAdapter) -> void:
	for extent: Vector2 in [Vector2(960, 540), Vector2(800, 480), Vector2(1280, 720), Vector2(700, 420)]:
		(safe as FakeSafe).metrics = SafeAreaMetrics.normalize(Rect2(Vector2.ZERO, extent), Rect2(Vector2.ZERO, extent), Rect2(Vector2.ZERO, extent), Transform2D.IDENTITY, true)
		presenter.refresh()
		await _settle(tree)
		for panel: Control in [hud.inventory_panel, hud.loot_panel]:
			_check(not panel.get_global_rect().intersects(touch.pause_button().get_global_rect()), "item panel never overlaps shared Pause at %s" % extent)
		if extent == Vector2(1280, 720):
			_check(not hud.get_node("Overlay/DetailPanel").get_global_rect().intersects(touch.pad_rect()), "mobile wide details reserve movement pad")
	(safe as FakeSafe).metrics = SafeAreaMetrics.normalize(Rect2(0, 0, 960, 540), Rect2(0, 0, 960, 540), Rect2(0, 0, 960, 540), Transform2D.IDENTITY, true)
	presenter.refresh()
	var inventory_rows: Array[PlayerInventoryRowProjection] = []
	var loot_rows: Array[WorldItemRowProjection] = []
	for index: int in 12:
		inventory_rows.append(PlayerInventoryRowProjection.new(StringName("qa:%d" % index), &"qa", "Long scrolling item label %d" % index, "Long description ".repeat(4), 1, &"weapon", PlayerInventoryRowProjection.EquipmentSlot.NONE, &"sword", 25, 0, true))
		loot_rows.append(WorldItemRowProjection.new(StringName("qa:%d" % index), &"qa", "Long loot label %d" % index, "Long description ".repeat(4), 1, &"weapon", true, false, false))
	# Display-only projections intentionally do not register new gameplay items.
	hud.show_inventory(inventory_rows)
	await _settle(tree)
	await _drag_rows(tree, hud.inventory_panel.row_container, "Inventory")
	await _back(tree)
	hud.show_loot("Scroll fixture", loot_rows)
	await _settle(tree)
	await _drag_rows(tree, hud.loot_panel.row_container, "Loot")
	await _back(tree)
	_check(not hud.inventory_panel.visible and not hud.loot_panel.visible, "Back closes native scroll fixtures without gameplay pause")


func _drag_rows(tree: SceneTree, rows: VBoxContainer, label: String) -> void:
	var scroll: ScrollContainer = rows.get_parent() as ScrollContainer
	var before: int = scroll.scroll_vertical
	var point: Vector2 = scroll.get_global_rect().get_center()
	var activations: Array[int] = [0]
	for button: Node in rows.find_children("*", "Button", true, false):
		(button as Button).pressed.connect(func() -> void: activations[0] += 1)
	await _touch(tree, 6, point, true)
	for offset: int in [15, 30, 50, 70]:
		await _drag(tree, 6, point - Vector2(0, offset))
	await _touch(tree, 6, point - Vector2(0, 70), false)
	_check(scroll.scroll_vertical > before, label + " native touch scroll advances")
	_check(activations[0] == 0, label + " scrolling never activates item action")
