class_name SlotListPanel
extends ColorRect

## The slot list (现代基线 A; DECISIONS「存档位」): one button per slot, the shell's choice to
## make of it (ApplicationShellController). A row names its slot, then what the save says.

signal chosen(index: int)
signal cancelled

const WIDTH: float = 640.0
const ROW_HEIGHT: float = 88.0
const EMPTY_ROW_HEIGHT: float = 52.0

var _title: Label
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _back: Button
var _buttons: Array[Button] = []


func _init() -> void:
	name = "SlotListPanel"
	visible = false
	color = Color(0.015, 0.02, 0.03, 0.94)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	column.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	_scroll.add_child(_rows)
	_back = Button.new()
	_back.name = "SlotBack"
	_back.text = "返回"
	_back.custom_minimum_size = Vector2(0, 52)
	_back.pressed.connect(func() -> void: cancelled.emit())
	column.add_child(_back)
	InputGlyphs.decorate(_back, &"ui_cancel")


## Shows `rows`, each [text, enabled]; a press answers chosen(its index).
func present(title: String, rows: Array[Array]) -> void:
	_title.text = title
	for button: Button in _buttons:
		_rows.remove_child(button)
		button.queue_free()
	_buttons.clear()
	var height: float = 0.0
	for index: int in rows.size():
		var button := Button.new()
		button.name = "Slot%d" % index
		button.text = String(rows[index][0])
		button.disabled = not bool(rows[index][1])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = Vector2(0, ROW_HEIGHT if button.text.contains("\n") else EMPTY_ROW_HEIGHT)
		button.pressed.connect(func() -> void: chosen.emit(index))
		_rows.add_child(button)
		_buttons.append(button)
		height += button.custom_minimum_size.y + 8.0
	_scroll.custom_minimum_size.y = minf(height, get_viewport_rect().size.y * 0.7) if is_inside_tree() else height


func buttons() -> Array[Button]:
	return _buttons


func back_button() -> Button:
	return _back


func title() -> String:
	return _title.text
