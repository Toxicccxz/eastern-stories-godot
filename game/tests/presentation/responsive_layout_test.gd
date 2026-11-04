extends RefCounted

## The shared layout on desktop screens (logical 1280x720 base, canvas_items / expand) at each
## 界面缩放: every panel, the HUD and the item panels stay inside the window, focus scrolls into
## view, nothing overlaps. Includes the Steam Deck's 1280x800 (16:10). A desktop screen is never
## below 1280x720 logical, so this is always the wide, mouse-sized layout; the compact one and the
## phone layer (notches, touch-sized controls, orientation, Android Back) are paused and no longer
## tested (DECISIONS「手机端暂停」).

## [screen, 界面缩放]: 16:9 at 100 / 125 / 150%, the Steam Deck's 16:10 at 100 / 150%, 4:3 and 21:9.
const SCREENS: Array[Array] = [
	[Vector2(1280, 720), 1.0], [Vector2(1280, 720), 1.25], [Vector2(1280, 720), 1.5],
	[Vector2(1280, 800), 1.0], [Vector2(1280, 800), 1.5],
	[Vector2(1280, 960), 1.0], [Vector2(1680, 720), 1.0],
]

const FakeSafe := preload("res://tests/presentation/fake_safe_area_capability.gd")
const SettingsFixtures := preload("res://tests/application/application_shell_phase10c1c_test.gd")
const RecoveryFixtures := preload("res://tests/application/application_shell_phase10c1b_test.gd")
const ShellScene: PackedScene = preload("res://scenes/application/application_shell.tscn")

var _assertions: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_metrics()
	await _test_matrix(tree)
	return {"assertions": _assertions, "failures": _failures}


func _test_metrics() -> void:
	var viewport: Rect2 = Rect2(0, 0, 960, 540)
	var zero: SafeAreaMetrics = _metrics(viewport, viewport)
	_check(zero.safe_rect() == viewport and not zero.used_fallback(), "a window's metrics are the window")
	_check(zero.content_rect() == Rect2(16, 16, 928, 508), "16-unit content padding")
	_check(SafeAreaMetrics.normalize(Rect2(), Rect2(), Rect2(), Transform2D.IDENTITY).content_rect().size.x > 0, "invalid viewport has finite positive emergency geometry")
	_check(zero.equivalent(_metrics(viewport, viewport)), "equal samples do not invalidate")
	_check(not zero.equivalent(_metrics(Rect2(0, 0, 1000, 540), Rect2(0, 0, 1000, 540))), "a window size change invalidates")
	_check(not _metrics(Rect2(0, 0, 1100, 640), Rect2(0, 0, 1100, 640)).is_compact(), "exact 1100x640 is wide")
	_check(_metrics(Rect2(0, 0, 1099, 640), Rect2(0, 0, 1099, 640)).is_compact(), "one below width threshold is compact")
	_check(_metrics(Rect2(0, 0, 1100, 639), Rect2(0, 0, 1100, 639)).is_compact(), "one below height threshold is compact")
	var deck: Rect2 = Rect2(0, 0, 1280, 800)
	_check(not _metrics(deck, deck).is_compact() and not _metrics(deck, deck).touch_sized(), "the Steam Deck's 1280x800 is the wide, mouse-sized layout")
	_check(ProjectSettings.get_setting("display/window/size/viewport_width") == 1280, "logical width 1280")
	_check(ProjectSettings.get_setting("display/window/size/viewport_height") == 720, "logical height 720")
	_check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "canvas_items preserved")
	_check(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "expand preserved: a 16:10 window gets the extra height")
	# The 界面缩放 draws a 1280x720 window's interface in 853x480 at 150%: still the
	# desktop layout (mouse-sized), not the compact one a small window gets.
	var at_150: Rect2 = Rect2(0, 0, 1280.0 / 1.5, 720.0 / 1.5)
	_check(not SafeAreaMetrics.new(at_150, at_150, false, false, 1.5).is_compact(), "a UI scale alone makes no window compact")
	_check(SafeAreaMetrics.new(at_150, at_150).is_compact(), "the same logical size unscaled is a small window")
	_check(not SafeAreaMetrics.new(at_150, at_150, false, false, 1.5).equivalent(SafeAreaMetrics.new(at_150, at_150)), "a UI scale change invalidates")


func _test_matrix(tree: SceneTree) -> void:
	var original_size: Vector2i = tree.root.size
	var original_scale: Vector2i = tree.root.content_scale_size
	tree.root.content_scale_size = Vector2i.ZERO
	var recovery_bytes: PackedByteArray = await RecoveryFixtures.new()._valid_save_bytes(tree)
	for index: int in SCREENS.size():
		var scale: float = SCREENS[index][1]
		var viewport: Rect2 = Rect2(Vector2.ZERO, (SCREENS[index][0] as Vector2) / scale)
		tree.root.size = Vector2i(viewport.size)
		var capability := FakeSafe.new()
		capability.metrics = _window(viewport, scale)
		_check(not capability.metrics.is_compact() and not capability.metrics.touch_sized(), "%s at %d%% is the wide, mouse-sized layout" % [SCREENS[index][0], roundi(scale * 100)])
		var files := SettingsFixtures.MemoryFiles.new()
		var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("phase10c2a-%d" % index)
		files.files[profile.backup_path()] = recovery_bytes.duplicate()
		var window := SettingsFixtures.FakeWindowCapability.new()
		window.editable = not capability.metrics.is_compact()
		var shell: ApplicationShellController = ShellScene.instantiate()
		_check(shell.configure_before_start(profile, files, null, SettingsFixtures.MemoryFiles.new(), window), "matrix configures isolated Shell")
		var presenter: SafeAreaPresenter = shell.get_node("SafeAreaPresentation") as SafeAreaPresenter
		presenter.set_capability(capability)
		tree.root.add_child(shell)
		await _settle(tree)
		_check(tree.root.gui_get_focus_owner() == shell.new_game_button, "menu primary focus after reflow")
		await _surface(tree, shell.main_menu_panel, capability.metrics)
		_check(shell.request_settings_from_main_menu(), "settings route remains available")
		await _settle(tree)
		await _surface(tree, shell.settings_panel, capability.metrics)
		_check(shell.window_mode_row.visible == window.editable, "platform-managed mode stays hidden")
		_check(window.editable or shell.window_mode_option.focus_mode == Control.FOCUS_NONE, "hidden setting cannot focus")
		shell.cancel_settings()
		_check(shell.request_recovery_choice_from_menu(), "explicit backup candidate remains inspectable")
		await _settle(tree)
		await _surface(tree, shell.recovery_panel, capability.metrics)
		_check(not shell.temp_recovery_button.visible and shell.temp_recovery_button.focus_mode == Control.FOCUS_NONE, "unavailable recovery skipped")
		shell.cancel_recovery_choice()
		shell.request_new_game_from_menu()
		await _settle(tree)
		await _surface(tree, shell.result_overlay, capability.metrics)
		shell.confirm_current_result()
		await _settle(tree)
		await _surface(tree, shell.new_game_setup_panel, capability.metrics)
		TechnicalShellFixture.start(shell) # Preserve old HUD/Old Pine regression subject.
		await _settle(tree)
		var session: WorldSessionController = shell.runtime_host().current_session()
		_check(session != null, "New Game still owns exactly one Session")
		if session != null:
			await _hud(tree, session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID).session.shared_ui(), capability.metrics)
			_check(shell.request_pause(), "Pause still available after panel use")
			await _settle(tree)
			await _surface(tree, shell.pause_panel, capability.metrics)
			shell.request_settings_from_pause()
			await _settle(tree)
			await _surface(tree, shell.settings_panel, capability.metrics)
			_check(not session.can_process(), "paused Settings leaves Session frozen")
			shell.cancel_settings()
			shell.request_return_to_main_menu()
			await _settle(tree)
			await _surface(tree, shell.result_overlay, capability.metrics)
			var state: ApplicationShellState = shell.shell_state()
			var smaller: Rect2 = viewport.grow(-1)
			capability.metrics = _window(smaller, scale)
			presenter.refresh()
			await _settle(tree)
			_check(shell.shell_state() == state and shell.runtime_host().current_session() == session, "a window resize changes no Shell/Session authority")
		_check(capability.metrics.content_rect().grow(0.5).encloses(shell.busy_label.get_global_rect()), "Busy text bounded, blocking overlay unchanged")
		shell.free()
		await _settle(tree)
	tree.root.size = original_size
	tree.root.content_scale_size = original_scale


func _hud(tree: SceneTree, hud: SharedGameplayUI, metrics: SafeAreaMetrics) -> void:
	_check(hud.get_node("PresentationLayout").get("_safe") == SafeAreaPresenter.find_or_create(hud), "HUD shares Shell metrics provider")
	var overlay: Control = hud.get_node("Overlay") as Control
	var action_panel: PanelContainer = overlay.get_node("ExplorationHUD") as PanelContainer
	_check(metrics.content_rect().grow(0.5).encloses(action_panel.get_global_rect()), "HUD action panel inside the window")
	var buttons: Array[BaseButton] = []
	_collect_buttons(action_panel, buttons)
	_check(buttons.size() >= 1 and buttons.size() <= 9, "the 菜单 entry persists; context controls appear only when available")
	await _buttons(tree, action_panel, metrics)
	var rows: Array[PlayerInventoryRowProjection] = []
	for index: int in 5:
		rows.append(PlayerInventoryRowProjection.new(StringName("qa:%d" % index), &"qa", "A long readable item name", "Long description ".repeat(20), 1, &"weapon", PlayerInventoryRowProjection.EquipmentSlot.NONE, &"sword", 25, 0, true))
	hud.show_inventory(rows)
	await _settle(tree)
	await _surface(tree, hud._presentation_layout.frame, metrics)
	for row: Node in hud.inventory_panel.row_container.get_children():
		_check(not (row as BoxContainer).vertical, "every dynamic row stays one line at %s, including automatically renamed siblings" % metrics.viewport_rect().size)
	_check(not tree.paused, "item panel does not pause gameplay")
	hud.close_inventory()
	var loot: Array[WorldItemRowProjection] = [WorldItemRowProjection.new(&"qa:loot", &"qa", "Long loot name ".repeat(8), "Visible without hover ".repeat(12), 3, &"currency", true)]
	hud.show_loot("Long corpse title ".repeat(10), loot)
	await _settle(tree)
	await _surface(tree, hud._presentation_layout.frame, metrics)
	var description: Label = hud.loot_panel.row_container.get_child(0).get_node("Description") as Label
	_check(description.visible and description.text == loot[0].description.strip_edges(), "loot description is inline, not tooltip-only")
	hud.close_loot()


func _surface(tree: SceneTree, root: Control, metrics: SafeAreaMetrics) -> void:
	var panels: Array[Node] = root.find_children("*", "PanelContainer", true, false)
	if root is PanelContainer:
		panels.append(root)
	for node: Node in panels:
		var panel: PanelContainer = node as PanelContainer
		if not panel.is_visible_in_tree():
			continue
		_check(metrics.content_rect().grow(0.5).encloses(_visible_rect(panel)), "safe panel %s: %s within %s" % [root.name, panel.get_global_rect(), metrics.content_rect()])
		_check(panel.size.is_finite() and panel.size.x > 0 and panel.size.y > 0, "positive finite panel")
	await _buttons(tree, root, metrics)


func _buttons(tree: SceneTree, root: Control, metrics: SafeAreaMetrics) -> void:
	var buttons: Array[BaseButton] = []
	_collect_buttons(root, buttons)
	for button: BaseButton in buttons:
		for other: BaseButton in buttons:
			if button.get_instance_id() < other.get_instance_id():
				_check(not button.get_global_rect().intersects(other.get_global_rect()), "primary actions do not overlap")
		if button.disabled:
			continue
		button.grab_focus()
		await _settle(tree)
		var rect: Rect2 = button.get_global_rect()
		_check(metrics.safe_rect().grow(0.5).encloses(rect), "focused action inside the window: %s %s" % [button.name, rect])
		var parent: Node = button.get_parent()
		while parent != null and parent != root.get_parent():
			if parent is ScrollContainer:
				_check((parent as Control).get_global_rect().grow(0.5).encloses(rect), "focus scroll reveals %s at %s" % [button.name, metrics.viewport_rect().size])
			parent = parent.get_parent()


func _collect_buttons(node: Node, result: Array[BaseButton]) -> void:
	if node is BaseButton and (node as BaseButton).is_visible_in_tree():
		result.append(node as BaseButton)
	for child: Node in node.get_children():
		_collect_buttons(child, result)


func _metrics(viewport: Rect2, safe: Rect2) -> SafeAreaMetrics:
	return SafeAreaMetrics.normalize(viewport, viewport, safe, Transform2D.IDENTITY)


## A desktop window's metrics: its logical rect at a 界面缩放.
func _window(viewport: Rect2, scale: float = 1.0) -> SafeAreaMetrics:
	return SafeAreaMetrics.new(viewport, viewport, false, false, scale)


func _settle(tree: SceneTree) -> void:
	for frame: int in 8:
		await tree.process_frame


func _check(value: bool, description: String) -> void:
	_assertions += 1
	if not value:
		_failures.append(description)


func _visible_rect(control: Control) -> Rect2:
	var rect: Rect2 = control.get_global_rect()
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is Control and (ancestor as Control).clip_contents:
			rect = rect.intersection((ancestor as Control).get_global_rect())
		ancestor = ancestor.get_parent()
	return rect
