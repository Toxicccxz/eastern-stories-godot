extends RefCounted

## A pad's direction held (审查修补 M; DECISIONS「手柄」): Godot repeats no pad button, so
## PadSupport does: after REPEAT_DELAY the focus walks on, and a number box steps faster the
## longer it is held. The 钱庄's amount starts at the most that converts evenly.

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _test_engine_alone(tree)
	var pad := PadSupport.new()
	tree.root.add_child(pad)
	await tree.process_frame
	await _test_focus_repeat(tree)
	await _test_number_boxes(tree)
	_test_bank_amount()
	pad.queue_free()
	await tree.process_frame
	InputDevices.shared().set_kind(InputDevices.Kind.KEYBOARD_MOUSE)
	return {"assertions": _count, "failures": _failures.duplicate()}


## What Godot 4.7.2 does by itself: a D-pad held for a second moves the focus once.
func _test_engine_alone(tree: SceneTree) -> void:
	var column: VBoxContainer = _column(tree)
	column.get_child(0).grab_focus()
	await _hold(tree, JOY_BUTTON_DPAD_DOWN, 60)
	_check(_focused_index(tree, column) == 1, "Godot alone: a D-pad held a second steps once (at %d)" % _focused_index(tree, column))
	column.queue_free()
	await tree.process_frame


func _test_focus_repeat(tree: SceneTree) -> void:
	var column: VBoxContainer = _column(tree)
	column.get_child(0).grab_focus()
	await _hold(tree, JOY_BUTTON_DPAD_DOWN, 18)
	_check(_focused_index(tree, column) == 1, "under the delay: one step (at %d)" % _focused_index(tree, column))
	column.get_child(0).grab_focus()
	await _hold(tree, JOY_BUTTON_DPAD_DOWN, 60)
	var reached: int = _focused_index(tree, column)
	_check(reached >= 6, "held a second: the focus walks on (at %d)" % reached)
	# The stick held as well.
	column.get_child(0).grab_focus()
	Input.parse_input_event(_motion(JOY_AXIS_LEFT_Y, 1.0))
	await _frames(tree, 60)
	Input.parse_input_event(_motion(JOY_AXIS_LEFT_Y, 0.0))
	await _frames(tree, 2)
	_check(_focused_index(tree, column) >= 6, "the stick held a second walks on too (at %d)" % _focused_index(tree, column))
	var stopped: int = _focused_index(tree, column)
	await _frames(tree, 20)
	_check(_focused_index(tree, column) == stopped, "let go, it stops")
	column.queue_free()
	await tree.process_frame


## 打坐's amount (10–100000, from 30) and a give's (the whole stack down to a few).
func _test_number_boxes(tree: SceneTree) -> void:
	var spin := SpinBox.new()
	spin.min_value = 10
	spin.max_value = 100000
	spin.value = 30
	tree.root.add_child(spin)
	await tree.process_frame
	spin.get_line_edit().grab_focus()
	await tree.process_frame
	await _hold(tree, JOY_BUTTON_DPAD_RIGHT, 1)
	_check(is_equal_approx(spin.value, 31), "a press: one step (%d)" % spin.value)
	await _hold(tree, JOY_BUTTON_DPAD_RIGHT, 60)
	_check(spin.value > 35, "held a second: more than one step (%d)" % spin.value)
	spin.value = 30
	await _hold(tree, JOY_BUTTON_DPAD_RIGHT, 180)
	_check(spin.value >= 1000, "held three seconds: the steps have grown (%d)" % spin.value)
	await _hold(tree, JOY_BUTTON_DPAD_RIGHT, 300)
	_check(is_equal_approx(spin.value, 100000), "and stop at the top (%d)" % spin.value)
	spin.value = 2000
	spin.min_value = 1
	await _hold(tree, JOY_BUTTON_DPAD_LEFT, 150)
	_check(spin.value < 1500, "2000 held down two and a half seconds: hundreds gone (%d)" % spin.value)
	await _hold(tree, JOY_BUTTON_DPAD_LEFT, 240)
	_check(is_equal_approx(spin.value, 1), "and down to the bottom in four (%d)" % spin.value)
	spin.queue_free()
	_check(PadSupport.repeat_step(0.5) == 1 and PadSupport.repeat_step(1.3) == 10 and PadSupport.repeat_step(2.1) == 100 and PadSupport.repeat_step(9.0) == PadSupport.REPEAT_STEP_MOST, "the steps grow ×10 each 0.8 s of repeating")
	# The 钱庄's box: a LineEdit marked STEP_META, at least 1.
	var line := LineEdit.new()
	line.set_meta(PadSupport.STEP_META, true)
	line.text = "300"
	tree.root.add_child(line)
	await tree.process_frame
	line.grab_focus()
	await tree.process_frame
	await _hold(tree, JOY_BUTTON_DPAD_LEFT, 180)
	_check(line.text == "1", "the 钱庄's amount held left: down to 1 (%s)" % line.text)
	line.queue_free()
	await tree.process_frame


func _test_bank_amount() -> void:
	_check(BankConversionService.largest_even(350, CurrencyDenomination.Value.COIN, CurrencyDenomination.Value.SILVER) == 300, "350 文 to 银子: 300 converts evenly")
	_check(BankConversionService.largest_even(99, CurrencyDenomination.Value.COIN, CurrencyDenomination.Value.SILVER) == 0, "99 文: none")
	_check(BankConversionService.largest_even(7, CurrencyDenomination.Value.SILVER, CurrencyDenomination.Value.COIN) == 7, "银子 to 文: all of it")


# --- helpers -------------------------------------------------------------------------

func _column(tree: SceneTree) -> VBoxContainer:
	var column := VBoxContainer.new()
	tree.root.add_child(column)
	for index: int in 30:
		var button := Button.new()
		button.text = str(index)
		column.add_child(button)
	return column


func _focused_index(tree: SceneTree, column: VBoxContainer) -> int:
	var focused: Control = tree.root.gui_get_focus_owner()
	return focused.get_index() if focused != null and focused.get_parent() == column else -1


## A pad button held `frames` frames (60 a second under --fixed-fps 60), then let go.
func _hold(tree: SceneTree, button: JoyButton, frames: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(tree, frames)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(tree, 2)


func _motion(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.process_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
