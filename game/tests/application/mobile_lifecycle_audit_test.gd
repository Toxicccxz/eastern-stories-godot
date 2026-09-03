extends "res://tests/application/mobile_lifecycle_test.gd"

var _activations: int = 0
var _activation_rect: Rect2
var _activation_focus: Control


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _test_reactivation_race(tree)
	await _test_presenter_reentry(tree)
	await _test_inactive_hardware_actions(tree)
	return {"assertions": _assertions, "failures": _failures}


func _test_reactivation_race(tree: SceneTree) -> void:
	var shell: ApplicationShellController = await _shell(tree)
	var presenter: SafeAreaPresenter = shell.get_node("SafeAreaPresentation")
	var safe: FakeSafe = FakeSafe.new()
	var viewport: Rect2 = Rect2(0, 0, 1152, 648)
	safe.metrics = SafeAreaMetrics.normalize(viewport, viewport, viewport, Transform2D.IDENTITY, true)
	presenter.set_capability(safe)
	await _settle(tree)
	var layout: ApplicationShellLayout = shell.get_node("PresentationLayout")
	var panel: PanelContainer = layout._dialogs[0].panel
	shell.interaction_changed.connect(func() -> void:
		if shell.interaction_allowed():
			_activations += 1
			_activation_rect = panel.get_rect()
			_activation_focus = tree.root.gui_get_focus_owner()
	)
	_loss(shell)
	_gain(shell) # Unchanged metrics: old completion queued, no new layout.
	_loss(shell)
	safe.metrics = SafeAreaMetrics.normalize(viewport, viewport, Rect2(200, 40, 800, 540), Transform2D.IDENTITY, true)
	_gain(shell, true) # New geometry must win over the already queued completion.
	await _settle(tree)
	_check(_activations == 1, "only latest reactivation is published")
	_check(_activation_rect == panel.get_rect(), "activation waits for latest panel geometry, not stale deferred completion")
	_check(_activation_focus == shell.new_game_button, "valid highest-surface focus is ready when interaction is published")
	_loss(shell)
	_gain(shell)
	_loss(shell) # Queued positive completion cannot undo a newer loss.
	await _settle(tree)
	_check(not shell.interaction_allowed() and tree.paused, "late completion cannot undo newer inactivity")
	_gain(shell)
	await _settle(tree)
	_check(shell.interaction_allowed() and _activations == 2, "unchanged-metrics retry does not deadlock")
	shell.free()
	_activation_focus = null
	await _settle(tree, 2)


func _test_inactive_hardware_actions(tree: SceneTree) -> void:
	var shell: ApplicationShellController = await _shell(tree)
	var touch: MobileTouchAdapter = shell.get_node("TouchCanvas/TouchInput")
	touch.set_capability(EnabledTouch.new())
	shell.request_new_game_from_menu()
	await _settle(tree)
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	var body: WorldCharacterBody2D = session.outdoor_map().player_body
	await tree.physics_frame
	await tree.physics_frame
	await tree.process_frame
	await _key(tree, KEY_RIGHT, true)
	_loss(shell)
	var frozen_position: Vector2 = body.global_position
	var frozen_location: StringName = session.player_runtime().world_location().zone_id
	for key: Key in [KEY_RIGHT, KEY_ENTER, KEY_ESCAPE]:
		await _key(tree, key, true)
		_check(not Input.is_action_pressed(&"move_right") and not Input.is_action_pressed(&"ui_accept") and not Input.is_action_pressed(&"pause_game") and not Input.is_action_pressed(&"ui_cancel"), "inactive hardware action cache is cleared")
		await _key(tree, key, false)
	# Keep another actual hardware press held over reactivation and replay an
	# OS echo. No synthetic Input action may leak into a later physics frame.
	await _key(tree, KEY_RIGHT, true)
	for frame: int in 4:
		await tree.physics_frame
		await tree.process_frame
	_check(body.global_position == frozen_position, "inactive physics frames cannot move player")
	await _back(tree)
	_gain(shell)
	await _settle(tree)
	_check(shell.pause_visible() and tree.paused and not shell.result_visible(), "inactive keyboard/Back neither resumes nor confirms")
	var echo: InputEventKey = InputEventKey.new()
	echo.keycode = KEY_RIGHT
	echo.pressed = true
	echo.echo = true
	Input.parse_input_event(echo)
	await _settle(tree)
	_check(not Input.is_action_pressed(&"move_right"), "reactivation does not resurrect held-key echo")
	_check(shell.request_resume(), "fresh explicit Resume still works")
	Input.parse_input_event(echo)
	for frame: int in 4:
		await tree.physics_frame
		await tree.process_frame
	_check(body.global_position == frozen_position, "Resume plus stale echo cannot move player")
	_check(session.player_runtime().world_location().zone_id == frozen_location, "inactive input and Resume retain map zone")
	await _key(tree, KEY_RIGHT, false)
	await _key(tree, KEY_RIGHT, true)
	await tree.physics_frame
	await tree.physics_frame
	_check(body.global_position.x > frozen_position.x, "fresh hardware press after Resume works")
	await _key(tree, KEY_RIGHT, false)
	_check(not Input.is_action_pressed(&"move_right"), "audit fixture releases hardware state before teardown")
	shell.free()
	await _settle(tree, 2)


func _test_presenter_reentry(tree: SceneTree) -> void:
	var shell: ApplicationShellController = await _shell(tree)
	var presenter: SafeAreaPresenter = shell.get_node("SafeAreaPresentation")
	_loss(shell)
	shell.remove_child(presenter)
	_gain(shell)
	await _settle(tree)
	_check(not shell.interaction_allowed(), "detached metrics source cannot authorize stale presentation")
	shell.add_child(presenter)
	await _settle(tree)
	_check(shell.interaction_allowed() and not tree.paused, "presenter reentry completes pending foreground without another OS event")
	_check(presenter.is_processing(), "reentered foreground presenter resumes observation")
	_check(tree.root.size_changed.get_connections().filter(func(c: Dictionary) -> bool: return c.callable.get_object() == presenter).size() == 1, "presenter reentry subscribes once")
	shell.free()
	await _settle(tree, 2)
