class_name MobileTouchAdapter
extends Control

const SOURCE_DEVICE: int = 10_202
const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]

var _capability: MobileTouchCapability = MobileTouchCapability.new()
var _captures: TouchCaptureState = TouchCaptureState.new()
var _shell: ApplicationShellController
var _presenter: SafeAreaPresenter
var _metrics: SafeAreaMetrics
var _active: bool = false
var _attached: bool = false
var _previous_emulation: bool = false
var _direction: Vector2i = Vector2i.ZERO
var _pointer_position: Vector2 = Vector2.ZERO
var _pointer_pressed: bool = false
var _world_pointer_pending: bool = false
var _routing: bool = false
var _filters: Dictionary[Control, int] = {}
var _blocker_id: int = 0
var _pad: GridContainer
var _pause: Button


func _enter_tree() -> void:
	if is_instance_valid(_pad):
		_attach_runtime.call_deferred()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_controls()
	_attach_runtime()


func _attach_runtime() -> void:
	if not is_inside_tree() or _attached:
		return
	_attached = true
	_shell = get_parent().get_parent() as ApplicationShellController
	_shell.input_context_changing.connect(cancel_contacts)
	_shell.state_changed.connect(_state_changed)
	(_shell.get_node("%WindowModeOption") as OptionButton).get_popup().window_input.connect(_popup_input)
	_presenter = SafeAreaPresenter.find_or_create(self)
	_presenter.metrics_changed.connect(_metrics_changed)
	get_tree().node_added.connect(_node_added)
	get_tree().node_removed.connect(_node_removed)
	for node: Node in _shell.find_children("*", "Control", true, false):
		_node_added(node)
	_metrics_changed(_presenter.current_metrics())
	set_capability(_capability)


func _exit_tree() -> void:
	cancel_contacts()
	if _active:
		Input.set_emulate_mouse_from_touch(_previous_emulation)
	_active = false
	if _attached and is_instance_valid(_shell):
		_shell.input_context_changing.disconnect(cancel_contacts)
		_shell.state_changed.disconnect(_state_changed)
		_shell.window_mode_option.get_popup().window_input.disconnect(_popup_input)
		for node: Node in _shell.find_children("*", "Control", true, false):
			_node_removed(node)
	if is_instance_valid(_presenter) and _presenter.metrics_changed.is_connected(_metrics_changed):
		_presenter.metrics_changed.disconnect(_metrics_changed)
	if _attached:
		get_tree().node_added.disconnect(_node_added)
		get_tree().node_removed.disconnect(_node_removed)
	_attached = false
	_presenter = null
	_shell = null


func set_capability(capability: MobileTouchCapability) -> void:
	if capability == null:
		return
	_capability = capability
	if not is_node_ready() or not _attached:
		return
	var enabled: bool = capability.enabled()
	if enabled != _active:
		cancel_contacts()
		if enabled:
			_previous_emulation = Input.is_emulating_mouse_from_touch()
			Input.set_emulate_mouse_from_touch(false)
		else:
			Input.set_emulate_mouse_from_touch(_previous_emulation)
		_active = enabled
	_sync_presentation()


func pad_rect() -> Rect2:
	return Rect2() if _metrics == null else _metrics.future_movement_rect()


func pause_button() -> Button:
	return _pause


func capture_state() -> TouchCaptureState:
	return _captures


func _build_controls() -> void:
	_pad = GridContainer.new()
	_pad.name = "MovementPad"
	_pad.columns = 3
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.add_theme_constant_override("h_separation", 0)
	_pad.add_theme_constant_override("v_separation", 0)
	add_child(_pad)
	for text: String in ["↖", "↑", "↗", "←", "·", "→", "↙", "↓", "↘"]:
		var cell: Label = Label.new()
		cell.text = text
		cell.custom_minimum_size = Vector2(64, 64)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_theme_font_size_override("font_size", 28)
		var background: StyleBoxFlat = StyleBoxFlat.new()
		background.bg_color = Color(0.07, 0.12, 0.10, 0.9)
		background.set_border_width_all(1)
		background.border_color = Color(0.4, 0.55, 0.45)
		cell.add_theme_stylebox_override("normal", background)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pad.add_child(cell)
	_pause = Button.new()
	_pause.name = "TouchPause"
	_pause.text = "Ⅱ"
	_pause.tooltip_text = "Pause"
	_pause.custom_minimum_size = Vector2(64, 64)
	_pause.add_theme_font_size_override("font_size", 24)
	_pause.focus_mode = Control.FOCUS_NONE
	_pause.pressed.connect(_pause_intent)
	add_child(_pause)


func _pause_intent() -> void:
	for pressed: bool in [true, false]:
		_emit_action(&"pause_game", pressed)


func _state_changed(_state: ApplicationShellState) -> void:
	_sync_presentation()


func _metrics_changed(metrics: SafeAreaMetrics) -> void:
	cancel_contacts()
	_metrics = metrics
	if metrics != null:
		_pad.position = pad_rect().position
		_pause.position = metrics.future_pause_rect().position
	_sync_presentation()


func _node_added(node: Node) -> void:
	if node is Control and node.name in [&"PlayerInventoryPanel", &"LootPanel", &"DetailPanel"]:
		if not (node as Control).visibility_changed.is_connected(_sync_presentation):
			(node as Control).visibility_changed.connect(_sync_presentation)
	if node is OldPineResidentMapController:
		cancel_contacts()


func _node_removed(node: Node) -> void:
	if node is Control and (node as Control).visibility_changed.is_connected(_sync_presentation):
		(node as Control).visibility_changed.disconnect(_sync_presentation)
	if node is OldPineResidentMapController:
		cancel_contacts()
		_blocker_id = 0


func _sync_presentation() -> void:
	if not is_instance_valid(_pad) or not is_instance_valid(_shell):
		return
	var blocker: ResponsivePanelLayout = ResponsivePanelLayout.top_interaction_panel(get_tree())
	var id: int = blocker.get_instance_id() if blocker != null else 0
	if id != _blocker_id:
		cancel_contacts()
		_blocker_id = id
	var playing: bool = _active and _shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING
	_pause.visible = playing
	_pad.visible = playing and blocker == null and pad_rect().size == Vector2(192, 192)


func _input(event: InputEvent) -> void:
	if not _active and event is InputEventScreenTouch and not event.pressed:
		_captures.release(event.index) # Observe lift while disabled, without consuming it.
	if not _active or _routing:
		return
	# Own pointer events are synchronous and guarded by _routing, not by a guessed
	# hardware device-number range. A real mouse may use any numeric device label.
	if event is InputEventMouseButton and event.pressed:
		_cancel_pointer()
		_captures.quarantine_pointer()
		return
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	# Raw touch would also activate BaseButton in 4.7.2. Exactly one custom pointer
	# route is delivered; native ScrollContainer receives its normal mouse gesture.
	_sync_presentation()
	if event.device == -1:
		get_viewport().set_input_as_handled() # mouse-to-touch emulation is not a new contact
		return
	if event is InputEventScreenTouch:
		_touch(event as InputEventScreenTouch)
	else:
		_drag(event as InputEventScreenDrag)
	get_viewport().set_input_as_handled()


func _popup_input(event: InputEvent) -> void:
	if not _active or _routing:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		var popup: PopupMenu = _shell.window_mode_option.get_popup()
		var offset: Vector2 = Vector2(popup.position)
		_input(event.xformed_by(Transform2D(0, offset)))
		popup.set_input_as_handled()


func _touch(event: InputEventScreenTouch) -> void:
	if event.pressed and not event.canceled:
		var busy: bool = _shell.shell_state().mode() in [ApplicationShellState.Mode.BOOT, ApplicationShellState.Mode.STARTING_SESSION, ApplicationShellState.Mode.SAVING]
		var allowed: bool = not busy and _pointer_allowed(event.position)
		var owner: TouchCaptureState.Owner = _captures.press(event.index, _pad.visible and pad_rect().has_point(event.position), _pad.visible, allowed)
		if owner == TouchCaptureState.Owner.PAD:
			_set_direction(TouchCaptureState.pad_direction(event.position, pad_rect()))
		elif owner == TouchCaptureState.Owner.POINTER:
			_pointer_position = event.position
			_mouse_motion(event.position, Vector2.ZERO)
			# World consumers select on mouse-down. Keep that press cancellable until
			# a completed touch; deliver the eventual click through ordinary picking.
			_world_pointer_pending = get_viewport().gui_get_hovered_control() == null
			if _world_pointer_pending:
				return
			_prepare_scroll_route(event.position)
			_pointer_pressed = true
			_mouse_button(event.position, true)
	else:
		var owner: TouchCaptureState.Owner = _captures.release(event.index)
		if owner == TouchCaptureState.Owner.PAD:
			_set_direction(Vector2i.ZERO)
		elif owner == TouchCaptureState.Owner.POINTER:
			if event.canceled:
				_cancel_pointer()
			else:
				if _world_pointer_pending:
					_world_pointer_pending = false
					_mouse_motion(event.position, Vector2.ZERO)
					# A world-origin contact cannot become a GUI click on release.
					if get_viewport().gui_get_hovered_control() != null:
						return
					_pointer_pressed = true
					_mouse_button(event.position, true)
				_pointer_pressed = false
				_mouse_button(event.position, false)
				_restore_filters()


func _drag(event: InputEventScreenDrag) -> void:
	match _captures.owner_of(event.index):
		TouchCaptureState.Owner.PAD:
			_set_direction(TouchCaptureState.pad_direction(event.position, pad_rect()))
		TouchCaptureState.Owner.POINTER:
			var delta: Vector2 = event.position - _pointer_position
			_pointer_position = event.position
			_mouse_motion(event.position, delta)


func _pointer_allowed(position: Vector2) -> bool:
	var panel: ResponsivePanelLayout = ResponsivePanelLayout.top_interaction_panel(get_tree())
	if _shell.shell_state().mode() != ApplicationShellState.Mode.PLAYING or panel == null:
		return true
	return panel.panel.get_global_rect().has_point(position) or (_pause.visible and _pause.get_global_rect().has_point(position))


func _prepare_scroll_route(_position: Vector2) -> void:
	_restore_filters()
	var target: Control = get_viewport().gui_get_hovered_control()
	var ancestor: Node = target
	var scroll: ScrollContainer
	while ancestor is Control:
		if ancestor is ScrollContainer:
			scroll = ancestor as ScrollContainer
			break
		ancestor = ancestor.get_parent()
	if scroll == null:
		return
	ancestor = target
	# Permit this gesture to bubble to native ScrollContainer. Its deadzone,
	# scroll notifications (cancel row activation), inertia and bounds remain native.
	while ancestor != scroll and ancestor is Control:
		var control: Control = ancestor as Control
		_filters[control] = control.mouse_filter
		control.mouse_filter = Control.MOUSE_FILTER_PASS
		ancestor = ancestor.get_parent()


func _restore_filters() -> void:
	for control: Variant in _filters.keys():
		if is_instance_valid(control):
			control.mouse_filter = _filters[control]
	_filters.clear()


func cancel_contacts() -> void:
	_captures.cancel()
	_set_direction(Vector2i.ZERO)
	_cancel_pointer()


func _cancel_pointer() -> void:
	_world_pointer_pending = false
	if _pointer_pressed and is_inside_tree():
		_pointer_pressed = false
		# Move outside before release: cancel must never be a click, including buttons
		# whose native handler does not inspect the canceled flag itself.
		_mouse_motion(Vector2(-10000, -10000), Vector2.ZERO)
		_mouse_button(Vector2(-10000, -10000), false, true)
	_restore_filters()


func _set_direction(direction: Vector2i) -> void:
	var previous: Array[bool] = [_direction.x < 0, _direction.x > 0, _direction.y < 0, _direction.y > 0]
	var next: Array[bool] = [direction.x < 0, direction.x > 0, direction.y < 0, direction.y > 0]
	_direction = direction
	for index: int in 4:
		if previous[index] != next[index]:
			_emit_action(MOVE_ACTIONS[index], next[index])


func _emit_action(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.device = SOURCE_DEVICE
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _mouse_motion(position: Vector2, relative: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.device = SOURCE_DEVICE
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if _pointer_pressed else 0
	_route_pointer(event)


func _mouse_button(position: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.device = SOURCE_DEVICE
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.canceled = canceled
	_route_pointer(event)


func _route_pointer(event: InputEventMouse) -> void:
	var previous: bool = _routing
	_routing = true
	get_viewport().push_input(event, true)
	_routing = previous
