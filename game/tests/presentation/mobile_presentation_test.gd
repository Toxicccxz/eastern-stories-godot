extends RefCounted

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
	_check(zero.safe_rect() == viewport and not zero.used_fallback(), "zero-inset identity")
	_check(zero.content_rect() == Rect2(16, 16, 928, 508), "16-unit content padding")
	for rect: Rect2 in [Rect2(40, 0, 920, 540), Rect2(0, 0, 920, 540), Rect2(0, 0, 960, 516), Rect2(40, 8, 888, 508)]:
		_check(_metrics(viewport, rect).safe_rect() == rect, "asymmetric insets retain their side")
	var transform: Transform2D = Transform2D(Vector2(2, 0), Vector2(0, 2), Vector2(100, 50))
	var scaled: SafeAreaMetrics = SafeAreaMetrics.normalize(viewport, Rect2(100, 50, 1920, 1080), Rect2(180, 66, 1776, 1016), transform)
	_check(scaled.safe_rect() == Rect2(40, 8, 888, 508), "OS pixels scale AND offset into logical coordinates exactly once")
	var already_inset: SafeAreaMetrics = SafeAreaMetrics.normalize(viewport, Rect2(180, 50, 1920, 1080), Rect2(100, 0, 2100, 1200), Transform2D(Vector2(2, 0), Vector2(0, 2), Vector2(180, 50)))
	_check(already_inset.safe_rect() == viewport, "content already inside display safe bounds does not receive double inset")
	_check(_metrics(viewport, Rect2(-100, -100, 1200, 800)).safe_rect() == viewport, "out-of-range safe rect clips to content")
	for invalid: Rect2 in [Rect2(), Rect2(0, 0, -1, 500), Rect2(2000, 0, 10, 10), Rect2(NAN, 0, 10, 10), Rect2(0, 0, INF, 10)]:
		var result: SafeAreaMetrics = _metrics(viewport, invalid)
		_check(result.used_fallback() and result.safe_rect() == viewport, "invalid/unavailable safe bounds deterministic full viewport fallback")
	_check(SafeAreaMetrics.normalize(viewport, viewport, viewport, Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)).used_fallback(), "singular transform rejects")
	_check(SafeAreaMetrics.normalize(Rect2(), Rect2(), Rect2(), Transform2D.IDENTITY).content_rect().size.x > 0, "invalid viewport has finite positive emergency geometry")
	_check(zero.equivalent(_metrics(viewport, viewport)), "equal samples do not invalidate")
	_check(not zero.equivalent(_metrics(viewport, Rect2(1, 0, 959, 540))), "safe-area-only change invalidates")
	_check(not zero.equivalent(_metrics(Rect2(0, 0, 1000, 540), viewport)), "viewport-only change invalidates")
	_check(not _metrics(Rect2(0, 0, 1100, 640), Rect2(0, 0, 1100, 640)).is_compact(), "exact 1100x640 is wide")
	_check(_metrics(Rect2(0, 0, 1099, 640), Rect2(0, 0, 1099, 640)).is_compact(), "one below width threshold is compact")
	_check(_metrics(Rect2(0, 0, 1100, 639), Rect2(0, 0, 1100, 639)).is_compact(), "one below height threshold is compact")
	_check(_metrics(viewport, Rect2(0, 0, 800, 480)).is_qualified(), "exact minimum safe area qualifies")
	_check(not _metrics(viewport, Rect2(0, 0, 799, 480)).is_qualified(), "one below minimum does not qualify")
	var extreme: SafeAreaMetrics = _metrics(viewport, Rect2(959, 539, 1, 1))
	_check(extreme.safe_rect().encloses(extreme.content_rect()), "extreme valid area remains finite and bounded")
	_check(zero.content_rect().encloses(zero.future_movement_rect()) and zero.future_movement_rect().size == Vector2(192, 192), "future pad is only a 192-unit layout reservation")
	_check(zero.future_pause_rect().size == Vector2(64, 64), "future Pause reservation is 64-unit")
	var independent := FakeSafe.new()
	var other := FakeSafe.new()
	independent.metrics = extreme
	_check(not independent.metrics.equivalent(other.metrics), "capabilities have no shared mutable metrics")
	_check(ProjectSettings.get_setting("display/window/size/viewport_width") == 1152, "desktop logical width preserved")
	_check(ProjectSettings.get_setting("display/window/size/viewport_width.mobile") == 960, "mobile feature width")
	_check(ProjectSettings.get_setting("display/window/size/viewport_height.mobile") == 540, "mobile feature height")
	_check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "canvas_items preserved")
	_check(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "expand preserved")
	_check(ProjectSettings.get_setting("display/window/handheld/orientation") == 4, "sensor landscape, both landscape directions")
	_check(InputMap.has_action(&"system_back") and InputMap.action_get_events(&"system_back").is_empty(), "Phase10C2B Back is semantic only, never a duplicate key alias")
	var wide_mobile: SafeAreaMetrics = SafeAreaMetrics.normalize(Rect2(0, 0, 1280, 720), Rect2(0, 0, 1280, 720), Rect2(0, 0, 1280, 720), Transform2D.IDENTITY, true)
	_check(wide_mobile.touch_sized() and not wide_mobile.is_compact(), "mobile target size and compact breakpoint are separate facts")


func _test_matrix(tree: SceneTree) -> void:
	var original_size: Vector2i = tree.root.size
	var original_scale: Vector2i = tree.root.content_scale_size
	tree.root.content_scale_size = Vector2i.ZERO
	var recovery_bytes: PackedByteArray = await RecoveryFixtures.new()._valid_save_bytes(tree)
	var cases: Array[Rect2] = [
		Rect2(0, 0, 1152, 648), Rect2(0, 0, 1920, 1080), Rect2(0, 0, 960, 540),
		Rect2(0, 0, 1212, 540), Rect2(48, 0, 912, 540), Rect2(0, 0, 912, 540),
		Rect2(0, 0, 960, 516), Rect2(0, 0, 1024, 768), Rect2(0, 0, 800, 480),
		Rect2(0, 0, 480, 320), Rect2(0, 0, 1280, 720),
	]
	for index: int in cases.size():
		var safe: Rect2 = cases[index]
		var viewport: Rect2 = Rect2(Vector2.ZERO, Vector2(960, 540) if index in [4, 5, 6] else safe.end)
		tree.root.size = Vector2i(viewport.size)
		var capability := FakeSafe.new()
		capability.metrics = _metrics(viewport, safe)
		if index == 10:
			capability.metrics = SafeAreaMetrics.normalize(viewport, viewport, safe, Transform2D.IDENTITY, true)
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
		var session: OldPineWorldSessionController = shell.runtime_host().current_session()
		_check(session != null, "New Game still owns exactly one Session")
		if session != null:
			await _hud(tree, session.outdoor_map().hud, capability.metrics)
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
			capability.metrics = _metrics(viewport, safe.grow(-1))
			presenter.refresh()
			await _settle(tree)
			_check(shell.shell_state() == state and shell.runtime_host().current_session() == session, "safe-only invalidation changes no Shell/Session authority")
		_check(capability.metrics.content_rect().grow(0.5).encloses(shell.busy_label.get_global_rect()), "Busy text bounded, blocking overlay unchanged")
		shell.free()
		await _settle(tree)
	tree.root.size = original_size
	tree.root.content_scale_size = original_scale


func _hud(tree: SceneTree, hud: OldPineOutdoorHud, metrics: SafeAreaMetrics) -> void:
	_check(hud.get_node("PresentationLayout").get("_presenter") == SafeAreaPresenter.find_or_create(hud), "HUD shares Shell metrics provider")
	var overlay: Control = hud.get_node("Overlay") as Control
	var action_panel: PanelContainer = overlay.get_node("ActionPanel") as PanelContainer
	_check(metrics.content_rect().grow(0.5).encloses(action_panel.get_global_rect()), "HUD action panel safe")
	var buttons: Array[BaseButton] = []
	_collect_buttons(action_panel, buttons)
	_check(buttons.size() == (6 if metrics.is_compact() else 5), "all five actions preserved; compact disclosure is presentation-only")
	await _buttons(tree, action_panel, metrics)
	if metrics.is_compact() and metrics.is_qualified():
		_check(not action_panel.get_global_rect().intersects(metrics.future_movement_rect()), "action panel leaves future pad clear")
		_check(not action_panel.get_global_rect().intersects(metrics.future_pause_rect()), "action panel leaves future Pause clear")
	var rows: Array[PlayerInventoryRowProjection] = []
	for index: int in 5:
		rows.append(PlayerInventoryRowProjection.new(StringName("qa:%d" % index), &"qa", "A long readable item name", "Long description ".repeat(20), 1, &"weapon", PlayerInventoryRowProjection.EquipmentSlot.NONE, &"sword", 25, 0, true))
	hud.show_inventory(rows)
	await _settle(tree)
	await _surface(tree, hud.inventory_panel, metrics)
	for row: Node in hud.inventory_panel.row_container.get_children():
		_check((row as BoxContainer).vertical == metrics.touch_sized(), "every dynamic row reflows, including automatically renamed siblings")
	_check(not tree.paused, "item panel does not pause gameplay")
	hud.close_inventory()
	var loot: Array[WorldItemRowProjection] = [WorldItemRowProjection.new(&"qa:loot", &"qa", "Long loot name ".repeat(8), "Visible without hover ".repeat(12), 3, &"currency", true)]
	hud.show_loot("Long corpse title ".repeat(10), loot)
	await _settle(tree)
	await _surface(tree, hud.loot_panel, metrics)
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
		_check(metrics.content_rect().grow(0.5).encloses(panel.get_global_rect()), "safe panel %s: %s within %s" % [root.name, panel.get_global_rect(), metrics.content_rect()])
		_check(panel.size.is_finite() and panel.size.x > 0 and panel.size.y > 0, "positive finite panel")
	await _buttons(tree, root, metrics)


func _buttons(tree: SceneTree, root: Control, metrics: SafeAreaMetrics) -> void:
	var buttons: Array[BaseButton] = []
	_collect_buttons(root, buttons)
	for button: BaseButton in buttons:
		if metrics.touch_sized():
			_check(button.size.x >= 64 and button.size.y >= 64, "mobile target minimum: %s" % button.name)
		for other: BaseButton in buttons:
			if button.get_instance_id() < other.get_instance_id():
				_check(not button.get_global_rect().intersects(other.get_global_rect()), "primary actions do not overlap")
		if button.disabled:
			continue
		button.grab_focus()
		await _settle(tree)
		var rect: Rect2 = button.get_global_rect()
		_check(metrics.safe_rect().grow(0.5).encloses(rect), "focused action inside safe rect: %s %s" % [button.name, rect])
		var parent: Node = button.get_parent()
		while parent != null and parent != root.get_parent():
			if parent is ScrollContainer:
				_check((parent as Control).get_global_rect().grow(0.5).encloses(rect), "focus scroll reveals %s" % button.name)
			parent = parent.get_parent()


func _collect_buttons(node: Node, result: Array[BaseButton]) -> void:
	if node is BaseButton and (node as BaseButton).is_visible_in_tree():
		result.append(node as BaseButton)
	for child: Node in node.get_children():
		_collect_buttons(child, result)


func _metrics(viewport: Rect2, safe: Rect2) -> SafeAreaMetrics:
	return SafeAreaMetrics.normalize(viewport, viewport, safe, Transform2D.IDENTITY)


func _settle(tree: SceneTree) -> void:
	for frame: int in 8:
		await tree.process_frame


func _check(value: bool, description: String) -> void:
	_assertions += 1
	if not value:
		_failures.append(description)
