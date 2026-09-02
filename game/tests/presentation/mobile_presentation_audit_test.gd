extends "res://tests/presentation/mobile_presentation_test.gd"

var _metric_emissions: int = 0


class CountingSafe extends SafeAreaCapability:
	var calls: int = 0
	func measure(viewport: Viewport) -> SafeAreaMetrics:
		calls += 1
		return super.measure(viewport)


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_adversarial_metrics()
	await _test_sampler(tree)
	await _test_reflow_lifetime(tree)
	return {"assertions": _assertions, "failures": _failures}


func _test_adversarial_metrics() -> void:
	var viewport: Rect2 = Rect2(0, 0, 960, 540)
	for dimensions: Vector2 in [Vector2(1099.999, 640), Vector2(1100, 639.999), Vector2(1100, 640)]:
		var rect: Rect2 = Rect2(Vector2.ZERO, dimensions)
		_check(_metrics(rect, rect).is_compact() == (dimensions != Vector2(1100, 640)), "fractional compact threshold")
	for dimensions: Vector2 in [Vector2(800, 480), Vector2(799.999, 480), Vector2(800, 479.999)]:
		_check(_metrics(viewport, Rect2(Vector2.ZERO, dimensions)).is_qualified() == (dimensions == Vector2(800, 480)), "fractional qualification threshold")
	var extreme_rects: Array[Rect2] = [
		Rect2(2.0e38, 0, 2.0e38, 540), Rect2(-2.0e38, 0, 2.0e38, 540),
		Rect2(1.0e30, 0, 1, 540), Rect2(0, 0, 1.0e30, 1.0e30),
		Rect2(0, 0, -1, 540), Rect2(INF, 0, 960, 540), Rect2(0, NAN, 960, 540),
	]
	for rect: Rect2 in extreme_rects:
		_assert_bounded_metrics(_metrics(rect, rect), "adversarial viewport")
		_assert_bounded_metrics(_metrics(viewport, rect), "adversarial native safe bounds")
	var transforms: Array[Transform2D] = [
		Transform2D(Vector2(0.0001, 0), Vector2(0, 0.0001), Vector2(0.1, 0.2)),
		Transform2D(Vector2(1.0e30, 0), Vector2(0, 1.0e30), Vector2.ZERO),
		Transform2D(Vector2(INF, 0), Vector2(0, 1), Vector2.ZERO),
		Transform2D(Vector2(1, 0), Vector2(0, 1), Vector2(NAN, 0)),
		Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO),
	]
	for index: int in transforms.size():
		var transform: Transform2D = transforms[index]
		var result: SafeAreaMetrics = SafeAreaMetrics.normalize(viewport, transform * viewport, transform * Rect2(40, 8, 888, 508), transform)
		_assert_bounded_metrics(result, "adversarial transform")
		if index == 0:
			_check(not result.used_fallback() and result.safe_rect().is_equal_approx(Rect2(40, 8, 888, 508)), "finite invertible small scaling must not discard real insets")
	var letterbox: Transform2D = Transform2D(Vector2(2, 0), Vector2(0, 2), Vector2(120, 60))
	_check(SafeAreaMetrics.normalize(viewport, letterbox * viewport, Rect2(0, 0, 2160, 1200), letterbox).safe_rect() == viewport, "letterbox content already safe gets no duplicate inset")
	_check(_metrics(viewport, Rect2(-30, 12, 930, 600)).safe_rect() == Rect2(0, 12, 900, 528), "partial intersection uses independently calculated endpoints")
	var metrics: SafeAreaMetrics = _metrics(viewport, viewport)
	var consumer_rect: Rect2 = metrics.safe_rect()
	consumer_rect.size = Vector2.ONE
	_check(metrics.safe_rect() == viewport, "Rect2 accessor is a defensive value copy")
	_check(ProjectSettings.get_setting_with_override("display/window/size/viewport_width") == 1152, "native desktop override resolution keeps desktop width")
	for features: PackedStringArray in [PackedStringArray(["android", "mobile"]), PackedStringArray(["ios", "mobile"]), PackedStringArray(["mobile"])]:
		_check(ProjectSettings.get_setting_with_override_and_custom_features("display/window/size/viewport_width", features) == 960, "native feature-set resolver applies mobile width")
		_check(ProjectSettings.get_setting_with_override_and_custom_features("display/window/size/viewport_height", features) == 540, "native feature-set resolver applies mobile height")
	_check(ProjectSettings.get_setting_with_override_and_custom_features("display/window/size/viewport_height", PackedStringArray(["windows", "pc"])) == 648, "desktop feature set retains base height")
	_check(DisplayServer.SCREEN_SENSOR_LANDSCAPE == 4, "pinned native enum matches project orientation")
	_assert_bounded_metrics(SafeAreaMetrics.new(Rect2(), Rect2(INF, 0, 10, 10)), "direct construction is defensive")


func _test_sampler(tree: SceneTree) -> void:
	var original_size: Vector2i = tree.root.size
	var capability := CountingSafe.new()
	var presenter: SafeAreaPresenter = SafeAreaPresenter.new()
	presenter.set_capability(capability)
	tree.root.add_child(presenter)
	_check(capability.calls == 1, "presenter measures immediately on entry")
	presenter.set_process(false)
	presenter._process(0.249)
	_check(capability.calls == 1, "sampler does not measure before interval")
	presenter._process(0.002)
	_check(capability.calls == 2, "sampler measures after 0.25 seconds without Timer")
	var count: int = capability.calls
	tree.root.size += Vector2i(8, 8)
	_check(capability.calls > count, "viewport resize immediately measures without polling delay")
	tree.root.remove_child(presenter)
	count = capability.calls
	tree.root.size = original_size
	await _settle(tree)
	_check(capability.calls == count, "detached standalone presenter has no viewport subscription")
	tree.root.add_child(presenter)
	_check(capability.calls == count + 1, "reattached presenter measures afresh once")
	presenter.free()
	await _settle(tree)


func _assert_bounded_metrics(metrics: SafeAreaMetrics, label: String) -> void:
	var viewport: Rect2 = metrics.viewport_rect()
	for rect: Rect2 in [viewport, metrics.safe_rect(), metrics.content_rect(), metrics.future_movement_rect(), metrics.future_pause_rect()]:
		_check(rect.position.is_finite() and rect.size.is_finite() and rect.end.is_finite(), label + " finite position/size/end")
		_check(rect.size.x > 0 and rect.size.y > 0 and viewport.encloses(rect), label + " positive bounded geometry")


func _test_reflow_lifetime(tree: SceneTree) -> void:
	var original_size: Vector2i = tree.root.size
	var original_scale: Vector2i = tree.root.content_scale_size
	tree.root.content_scale_size = Vector2i.ZERO
	tree.root.size = Vector2i(1152, 648)
	var files := SettingsFixtures.MemoryFiles.new()
	var settings_files := SettingsFixtures.MemoryFiles.new()
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("phase10c2a-audit")
	files.files[profile.backup_path()] = await RecoveryFixtures.new()._valid_save_bytes(tree)
	var shell: ApplicationShellController = ShellScene.instantiate()
	var window := SettingsFixtures.FakeWindowCapability.new()
	window.editable = false
	shell.configure_before_start(profile, files, null, settings_files, window)
	var presenter: SafeAreaPresenter = shell.get_node("SafeAreaPresentation") as SafeAreaPresenter
	var capability := FakeSafe.new()
	capability.metrics = _metrics(Rect2(0, 0, 1152, 648), Rect2(0, 0, 1152, 648))
	presenter.set_capability(capability)
	presenter.metrics_changed.connect(_on_metrics_changed)
	tree.root.add_child(shell)
	await _settle(tree)
	var host_id: int = shell.runtime_host().get_instance_id()
	var menu_connections: int = presenter.metrics_changed.get_connections().size()
	await _cycle_surface(tree, shell, shell.main_menu_panel, capability, presenter)
	shell.request_settings_from_main_menu()
	await _settle(tree)
	await _cycle_surface(tree, shell, shell.settings_panel, capability, presenter)
	shell.cancel_settings()
	shell.request_recovery_choice_from_menu()
	await _settle(tree)
	await _cycle_surface(tree, shell, shell.recovery_panel, capability, presenter)
	shell.cancel_recovery_choice()
	shell.request_new_game_from_menu()
	await _settle(tree)
	await _cycle_surface(tree, shell, shell.result_overlay, capability, presenter)
	shell.confirm_current_result()
	await _settle(tree)
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	var hud: OldPineOutdoorHud = session.outdoor_map().hud
	var live_connections: int = presenter.metrics_changed.get_connections().size()
	_check(live_connections == menu_connections + 1, "one and only one current HUD consumer added")
	var actions: Array[Button] = [hud.inspect_button, hud.attack_button, hud.portal_button, hud.open_loot_button, hud.inventory_button]
	var signal_counts: Array[int] = []
	for action: Button in actions:
		signal_counts.append(action.pressed.get_connections().size())
	await _cycle_surface(tree, shell, hud.get_node("Overlay") as Control, capability, presenter)
	for index: int in actions.size():
		_check(actions[index].pressed.get_connections().size() == signal_counts[index], "HUD reflow preserves exact action object/signal")
		_check(hud.get_node_or_null(NodePath("%" + String(actions[index].name))) == actions[index], "reparent retains unique-name identity")
	for control: Control in [hud.player_vitality, hud.player_vitality_text, hud.selected_target_label, hud.target_vitality, hud.target_vitality_text, hud.inspection_text, hud.combat_log]:
		_check(hud.get_node_or_null(NodePath("%" + String(control.name))) == control, "reparent preserves authored information identity")
	capability.metrics = _metrics(Rect2(0, 0, 1152, 648), Rect2(0, 0, 800, 480))
	presenter.refresh()
	for landmark: WorldLandmarkDefinition in OldPineLandmarkDefinitions.definitions():
		hud.set_selected_landmark(landmark, true)
		await _settle(tree)
		_check(capability.metrics.content_rect().encloses(hud.portal_button.get_global_rect()), "current authored traversal label fits compact action grid")
	hud.set_selected_target(null)
	await _dynamic_rows(tree, shell, hud, capability, presenter)
	shell.request_pause()
	await _settle(tree)
	await _cycle_surface(tree, shell, shell.pause_panel, capability, presenter)
	shell.request_settings_from_pause()
	await _settle(tree)
	await _cycle_surface(tree, shell, shell.settings_panel, capability, presenter)
	_check(tree.paused and not session.can_process(), "sampler/reflow during paused Settings never advances gameplay")
	shell.cancel_settings()
	shell.request_return_to_main_menu()
	await _settle(tree)
	await _cycle_surface(tree, shell, shell.result_overlay, capability, presenter)
	shell.dismiss_current_result()
	shell.request_resume()
	for cycle: int in 3:
		var to_cave: OldPineMapHandoffResult = session.handoff_to(OldPineWorldDefinitions.CAVE_MAP_ID, OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID, OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID, &"oldpine.cave.waterfall_passage.vine_landing")
		_check(to_cave.succeeded(), "typed handoff fixture enters Cave")
		await _settle(tree)
		_check(presenter.metrics_changed.get_connections().size() == menu_connections, "detached resident Outdoor is not a live layout subscriber")
		_check(session.cave_map().find_children("HUD", "CanvasLayer", true, false).is_empty(), "Cave has no invented Outdoor HUD")
		capability.metrics = _metrics(Rect2(0, 0, 1152, 648), Rect2(48, 0, 800, 480))
		presenter.refresh()
		await _settle(tree)
		var back: OldPineMapHandoffResult = session.handoff_to(OldPineWorldDefinitions.OUTDOOR_MAP_ID, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, &"oldpine.outdoor.central_clearing.player_start")
		_check(back.succeeded(), "typed handoff fixture returns Outdoor")
		await _settle(tree)
		_check(presenter.metrics_changed.get_connections().size() == live_connections, "reattached HUD has exactly one subscription")
		_check(capability.metrics.content_rect().grow(0.5).encloses(hud.get_node("Overlay/ActionPanel").get_global_rect()), "returning resident consumes latest metrics")
		_check(session.outdoor_map().hud == hud, "resident HUD identity preserved")
	_check(files.files.size() == 1 and settings_files.files.is_empty(), "metric changes perform zero Save/settings writes")
	_check(shell.runtime_host().get_instance_id() == host_id, "one persistent Host survives all presentation paths")
	shell.request_pause()
	shell.request_return_to_main_menu()
	shell.confirm_current_result()
	await _settle(tree)
	_check(presenter.metrics_changed.get_connections().size() == menu_connections, "Session teardown removes its only HUD subscription")
	_check(shell.runtime_host().current_session() == null, "Return to Menu leaves no hidden Session")
	presenter.refresh()
	shell.free()
	await _settle(tree)
	tree.root.size = original_size
	tree.root.content_scale_size = original_scale


func _cycle_surface(tree: SceneTree, shell: ApplicationShellController, surface: Control, capability: FakeSafe, presenter: SafeAreaPresenter) -> void:
	var state: ApplicationShellState = shell.shell_state()
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	var focus: Control = tree.root.gui_get_focus_owner()
	var scroll_count: int = shell.find_children("*", "ScrollContainer", true, false).size()
	var node_count: int = shell.find_children("*", "", true, false).size()
	for rect: Rect2 in [Rect2(0, 0, 1152, 648), Rect2(48, 0, 912, 516), Rect2(0, 0, 1920, 1080), Rect2(0, 0, 800, 480), Rect2(0, 0, 480, 320), Rect2(0, 0, 1152, 648)]:
		tree.root.size = Vector2i(maxf(960, rect.end.x), maxf(540, rect.end.y))
		await _settle(tree)
		var before: int = _metric_emissions
		var next: SafeAreaMetrics = _metrics(tree.root.get_visible_rect(), rect)
		var changed: bool = not next.equivalent(presenter.current_metrics())
		capability.metrics = next
		presenter.refresh()
		await _settle(tree)
		_check(_metric_emissions == before + int(changed), "one emission per meaningful sample")
		before = _metric_emissions
		for repeat: int in 5:
			presenter.refresh()
		await _settle(tree)
		_check(_metric_emissions == before, "equivalent metrics do not repeat reflow")
		_check(shell.shell_state() == state and shell.runtime_host().current_session() == session, "reflow preserves typed state/origin and Session")
		_check(tree.root.gui_get_focus_owner() == focus, "reflow never chooses a different focus owner")
		_check(shell.find_children("*", "ScrollContainer", true, false).size() == scroll_count, "resize does not accumulate scroll wrappers")
		_check(shell.find_children("*", "", true, false).size() == node_count, "resize does not duplicate presentation nodes")
		for panel: Node in surface.find_children("*", "PanelContainer", true, false):
			if (panel as Control).is_visible_in_tree():
				_check(next.content_rect().grow(0.5).encloses((panel as Control).get_global_rect()), "reflow visible panel remains safe-bounded")


func _dynamic_rows(tree: SceneTree, shell: ApplicationShellController, hud: OldPineOutdoorHud, capability: FakeSafe, presenter: SafeAreaPresenter) -> void:
	var stale_row_ids: Array[int] = []
	for cycle: int in 3:
		var rows: Array[PlayerInventoryRowProjection] = []
		for index: int in 12:
			rows.append(PlayerInventoryRowProjection.new(StringName("audit:%d" % index), &"audit", "Long item name ".repeat(index + 1), "Description ".repeat(30), 1, &"weapon", PlayerInventoryRowProjection.EquipmentSlot.NONE, &"sword", 25, 0, true))
		hud.show_inventory(rows)
		await _settle(tree)
		await _cycle_surface(tree, shell, hud.inventory_panel, capability, presenter)
		_check(hud.inventory_panel.row_container.get_child_count() == rows.size(), "one node per item identity after repeated open/update")
		for row: Node in hud.inventory_panel.row_container.get_children():
			stale_row_ids.append(row.get_instance_id())
			for child: Node in row.get_children():
				if child is Button:
					_check(child.pressed.get_connections().size() == 1, "each current row action has one handler")
		var focused: BaseButton = hud.inventory_panel.row_container.get_child(11).get_child(1) as BaseButton
		focused.grab_focus()
		hud.close_inventory()
		await _settle(tree)
		for id: int in stale_row_ids:
			_check(not is_instance_id_valid(id), "closed dynamic row is freed")
		var layout: ResponsivePanelLayout = hud.get_node("PresentationLayout").get("_inventory") as ResponsivePanelLayout
		var cache_clean: bool = true
		for key: Variant in layout.get("_minimums").keys():
			cache_clean = cache_clean and is_instance_valid(key)
		_check(cache_clean, "closed inventory has no cached freed Control keys")
		var loot: Array[WorldItemRowProjection] = []
		for index: int in 12:
			loot.append(WorldItemRowProjection.new(StringName("loot:%d" % index), &"audit", "Loot name ".repeat(index + 1), "Inline description ".repeat(30), 1, &"item", true))
		hud.show_loot("Corpse", loot)
		await _settle(tree)
		await _cycle_surface(tree, shell, hud.loot_panel, capability, presenter)
		loot.remove_at(0)
		hud.show_loot("Corpse", loot)
		await _settle(tree)
		_check(hud.loot_panel.row_container.get_child_count() == 11, "Take refresh removes exactly the represented row")
		hud.close_loot()
		await _settle(tree)


func _on_metrics_changed(_metrics: SafeAreaMetrics) -> void:
	_metric_emissions += 1
