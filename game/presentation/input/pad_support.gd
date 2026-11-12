class_name PadSupport
extends Node
## Gamepad support that is not any one panel's (owner, DECISIONS「手柄」):
## every input event tells InputDevices what the player uses; a focused number box
## (SpinBox, or a LineEdit marked STEP_META) steps with ←/→ (a pad has no keys to type
## with); a pad's direction held repeats like a held key, and on a number box the steps grow
## the longer it is held (Godot repeats no pad button); the right stick or PgUp/PgDn scrolls
## the topmost long text (SCROLL_GROUP); a control walked to shows its tooltip (FocusTip).
## The shell adds one; it runs while the tree is paused.

## ScrollContainers and RichTextLabels the right stick scrolls; the last visible one in
## tree order (the topmost) moves.
const SCROLL_GROUP: StringName = &"pad_scroll"
## A LineEdit holding a whole number ≥ 1 that ←/→ step (the bank's amount).
const STEP_META: StringName = &"pad_step"
const SCROLL_SPEED: float = 900.0
## A pad direction held this long starts repeating, once every REPEAT_SECONDS (DECISIONS「手柄」).
const REPEAT_DELAY: float = 0.4
const REPEAT_SECONDS: float = 0.08
## A number box held: each repeat steps ×10 more once the repeats have run this long, up to
## REPEAT_STEP_MOST (30 → 3000 takes three seconds, not three thousand presses).
const REPEAT_GROWTH_SECONDS: float = 0.8
const REPEAT_STEP_MOST: int = 10000
const DIRECTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]

## The stick's direction that stepped a number box last (-1, 1), 0 once it rests.
var _stick_step: int = 0
var focus_tip: FocusTip
## The pad direction held (one of DIRECTIONS, &"" for none), for how long, and the time to
## the next repeat.
var _held: StringName = &""
var _held_seconds: float = 0.0
var _next_repeat: float = 0.0
## The window has no focus: a pad steers nothing (DECISIONS「切出窗口」), whatever
## 切出窗口时暂停 says. project.godot's ignore_joypad_on_unfocused_application asks Godot the
## same; this holds where the platform still delivers the pad's events.
var _window_unfocused: bool = false


func _ready() -> void:
	name = "PadSupport"
	process_mode = Node.PROCESS_MODE_ALWAYS
	focus_tip = FocusTip.new()
	add_child(focus_tip)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)
	if get_viewport().gui_focus_changed.is_connected(_on_focus_changed):
		get_viewport().gui_focus_changed.disconnect(_on_focus_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_unfocused = true
		_held = &""
		_release_pad_actions()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_window_unfocused = false


func _input(event: InputEvent) -> void:
	if _window_unfocused and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		get_viewport().set_input_as_handled()
		_release_pad_actions(event)
		return
	InputDevices.shared().observe(event)
	focus_tip.observe(event)
	_track_hold(event)


func _process(delta: float) -> void:
	_repeat_hold(delta)
	var axis: float = Input.get_axis(&"scroll_up", &"scroll_down")
	if is_zero_approx(axis):
		return
	var target: Control = scroll_target(get_tree())
	if target != null:
		scroll(target, axis * SCROLL_SPEED * delta)


## Lets go of every action a pad holds (or `event` would press): Godot set them before this
## node saw the event, and walking reads them (Input.get_vector).
func _release_pad_actions(event: InputEvent = null) -> void:
	for action: StringName in InputMap.get_actions():
		if event != null and not event.is_action(action):
			continue
		for bound: InputEvent in InputMap.action_get_events(action):
			if (bound is InputEventJoypadButton or bound is InputEventJoypadMotion) and Input.is_action_pressed(action):
				Input.action_release(action)
				break


## A pad's direction (D-pad or stick) pressed starts a hold; let go, it ends.
func _track_hold(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	for action: StringName in DIRECTIONS:
		if not event.is_action(action):
			continue
		if event.is_action_pressed(action):
			if _held != action:
				_held = action
				_held_seconds = 0.0
				_next_repeat = REPEAT_DELAY
		elif _held == action:
			_held = &""


## The held direction once more, as a held key's echo moves the focus: through
## the focused control, else the viewport's focus navigation; a number box steps itself.
func _repeat_hold(delta: float) -> void:
	if _held.is_empty():
		return
	if not Input.is_action_pressed(_held):
		_held = &"" # Let go where this node did not see it (the window lost the pad).
		return
	_held_seconds += delta
	while _held_seconds >= _next_repeat:
		_next_repeat += REPEAT_SECONDS
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused == null or not focused.is_visible_in_tree():
			return
		var line := focused as LineEdit
		if line != null and (line.get_parent() is SpinBox or line.has_meta(STEP_META)) and _held in [&"ui_left", &"ui_right"]:
			step_number(line, -1 if _held == &"ui_left" else 1, repeat_step(_held_seconds))
			continue
		var echo := InputEventAction.new()
		echo.action = _held
		echo.pressed = true
		get_viewport().push_input(echo)
		echo = echo.duplicate()
		echo.pressed = false
		get_viewport().push_input(echo)


## How much one repeat steps a number box after `held` seconds of holding: 1, then ×10 each
## REPEAT_GROWTH_SECONDS of repeating, at most REPEAT_STEP_MOST.
static func repeat_step(held: float) -> int:
	var grown: int = maxi(0, floori((held - REPEAT_DELAY) / REPEAT_GROWTH_SECONDS))
	return mini(int(pow(10.0, grown)), REPEAT_STEP_MOST)


## The last pulled pad goes: hints show the keys again.
func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	var devices: InputDevices = InputDevices.shared()
	if not connected and devices.is_gamepad() and Input.get_connected_joypads().is_empty():
		devices.set_kind(InputDevices.Kind.KEYBOARD_MOUSE)


func _on_focus_changed(control: Control) -> void:
	focus_tip.focus_moved(control)
	var line := control as LineEdit
	if line == null or not (line.get_parent() is SpinBox or line.has_meta(STEP_META)):
		return
	var step: Callable = _on_number_input.bind(line)
	if not line.gui_input.is_connected(step):
		line.gui_input.connect(step)


## ←/→ on a number box: one step down or up (on a pad always: it has no keys to type
## with; with keys while the box is not being typed into).
func _on_number_input(event: InputEvent, line: LineEdit) -> void:
	var motion := event as InputEventJoypadMotion
	if motion != null and motion.axis == JOY_AXIS_LEFT_X and absf(motion.axis_value) < InputDevices.MOTION_THRESHOLD:
		_stick_step = 0 # The stick rests: the next tilt steps again.
		return
	if not event.is_pressed() or (line.is_editing() and not InputDevices.shared().is_gamepad()):
		return
	var direction: int = -1 if event.is_action_pressed(&"ui_left", true) else 1 if event.is_action_pressed(&"ui_right", true) else 0
	if motion != null:
		# A tilt sends a stream of motion events: one step until the stick rests.
		if direction == 0 or direction == _stick_step:
			if direction != 0:
				line.accept_event()
			return
		_stick_step = direction
	if direction == 0:
		return
	step_number(line, direction)
	line.accept_event()


## Steps a SpinBox (its LineEdit) or a STEP_META LineEdit by `times` steps (clamped to the
## box's range).
static func step_number(line: LineEdit, direction: int, times: int = 1) -> void:
	var spin := line.get_parent() as SpinBox
	if spin != null:
		spin.value += direction * times * (spin.step if spin.step > 0.0 else 1.0)
		return
	var value: int = int(line.text) if line.text.is_valid_int() else 1
	line.text = str(maxi(1, value + direction * times))
	line.text_changed.emit(line.text)


## The topmost visible SCROLL_GROUP member with more than it shows, or null.
static func scroll_target(tree: SceneTree) -> Control:
	var found: Control = null
	for node: Node in tree.get_nodes_in_group(SCROLL_GROUP):
		var control := node as Control
		var bar: VScrollBar = _bar(control)
		if control != null and control.is_visible_in_tree() and bar != null and bar.max_value - bar.page > 1.0:
			found = control
	return found


static func scroll(target: Control, pixels: float) -> void:
	var bar: VScrollBar = _bar(target)
	if bar != null:
		bar.value = clampf(bar.value + pixels, bar.min_value, bar.max_value - bar.page)


static func _bar(target: Control) -> VScrollBar:
	if target is ScrollContainer:
		return (target as ScrollContainer).get_v_scroll_bar()
	if target is RichTextLabel:
		return (target as RichTextLabel).get_v_scroll_bar()
	return null
