class_name FocusPauseLayer
extends CanvasLayer

## The pause the window's lost focus brings (DECISIONS「切出窗口」): a page over whatever was
## open, which it leaves as it was (the interaction window, a menu page, a continuous 打坐 or
## 请教, a dialogue line); 继续 (the button, Enter / Space / A, Esc / Back, Start) takes it
## away and the game goes on from there. Keys and buttons go to nothing under it. It also says
## that this pause can be turned off in 设置.

signal resume_requested

## Over the game menu (60), the shared frame's dialogs (61) and the shell's canvas (100).
const LAYER: int = 110

var resume_button: Button
var _scrim: ColorRect
var _note: Label


func _init() -> void:
	name = "FocusPauseLayer"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = UiPalette.SCRIM
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.theme = GameTheme.shared()
	add_child(_scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"MenuWindow"
	center.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	panel.add_child(rows)
	var title := Label.new()
	title.theme_type_variation = &"HeadingLabel"
	# TRANSLATORS: the title of the pause the window's lost focus brings.
	title.text = "暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	var text := Label.new()
	text.name = "Why"
	# TRANSLATORS: why the game stopped (切出窗口时暂停).
	text.text = "切到别的窗口时，游戏暂停了。"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(text)
	_note = Label.new()
	_note.name = "Note"
	_note.theme_type_variation = &"SmallLabel"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(420, 0)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# TRANSLATORS: under the focus pause; 切出窗口时暂停 is the setting's name.
	_note.text = "不想这样暂停，可以在「设置」里关掉「切出窗口时暂停」。"
	rows.add_child(_note)
	resume_button = Button.new()
	resume_button.name = "Resume"
	resume_button.theme_type_variation = &"PrimaryButton"
	# TRANSLATORS: the focus pause's only button.
	resume_button.text = "继续"
	resume_button.custom_minimum_size = Vector2(200, 52)
	resume_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume_button.pressed.connect(_on_resume_pressed)
	# A click takes no focus: what had it keeps it (the keys reach 继续 through _input).
	resume_button.focus_mode = Control.FOCUS_NONE
	InputGlyphs.decorate(resume_button, &"ui_accept")
	rows.add_child(resume_button)


## `setting_note`: whether to say that the pause can be turned off (the desktop's setting;
## a phone sent to the background has none). The focus stays where it was: the keys come
## here first, so what had the focus has it again when the layer goes.
func present(setting_note: bool) -> void:
	_note.visible = setting_note
	visible = true


func withdraw() -> void:
	visible = false


func shown() -> bool:
	return visible


## Before anything under it (the shell keeps this layer its last child, so it hears first):
## 继续's keys resume; every other key or pad button goes nowhere. The mouse reaches 继续
## through the GUI and the scrim stops it there.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	get_viewport().set_input_as_handled()
	if event.is_echo() or not event.is_pressed():
		return
	for action: StringName in [&"ui_accept", &"ui_cancel", &"pause_game", &"menu_open", &"interact"]:
		if event.is_action_pressed(action):
			resume_requested.emit()
			return


func _on_resume_pressed() -> void:
	resume_requested.emit()
