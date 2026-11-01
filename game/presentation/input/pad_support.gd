class_name PadSupport
extends Node
## Gamepad support that is not any one panel's (owner, DECISIONS「手柄」):
## every input event tells InputDevices what the player uses; a focused number box
## (SpinBox, or a LineEdit marked STEP_META) steps with ←/→ (a pad has no keys to type
## with); the right stick or PgUp/PgDn scrolls the topmost long text (SCROLL_GROUP); a
## control walked to shows its tooltip (FocusTip).
## The shell adds one; it runs while the tree is paused.

## ScrollContainers and RichTextLabels the right stick scrolls; the last visible one in
## tree order (the topmost) moves.
const SCROLL_GROUP: StringName = &"pad_scroll"
## A LineEdit holding a whole number ≥ 1 that ←/→ step (the bank's amount).
const STEP_META: StringName = &"pad_step"
const SCROLL_SPEED: float = 900.0

## The stick's direction that stepped a number box last (-1, 1), 0 once it rests.
var _stick_step: int = 0
var focus_tip: FocusTip


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


func _input(event: InputEvent) -> void:
	InputDevices.shared().observe(event)
	focus_tip.observe(event)


func _process(delta: float) -> void:
	var axis: float = Input.get_axis(&"scroll_up", &"scroll_down")
	if is_zero_approx(axis):
		return
	var target: Control = scroll_target(get_tree())
	if target != null:
		scroll(target, axis * SCROLL_SPEED * delta)


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


## Steps a SpinBox (its LineEdit) or a STEP_META LineEdit by one step.
static func step_number(line: LineEdit, direction: int) -> void:
	var spin := line.get_parent() as SpinBox
	if spin != null:
		spin.value += direction * (spin.step if spin.step > 0.0 else 1.0)
		return
	var value: int = int(line.text) if line.text.is_valid_int() else 1
	line.text = str(maxi(1, value + direction))
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
