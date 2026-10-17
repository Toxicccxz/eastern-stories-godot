class_name InteractionPanel
extends VBoxContainer

## The interaction popup (DECISIONS「说话和交互」), in the shared frame (titled with the
## thing's name and title): at the top how it is and what it is to the player, then everything
## it offers (SharedUiNearby.options_for()), one row each; one the rules refuse now is greyed
## with the reason beside it. Choosing a row emits `chosen`; the HUD closes the popup and
## does it. Keys and pad start on the first row that can be done.

signal chosen(option: InteractionOption)

const REASON_COLOR: Color = Color(0.62, 0.6, 0.56)
const STATUS_COLOR: Color = Color(1.0, 0.78, 0.45)

var _lines: VBoxContainer
var _rows: VBoxContainer
## What the rows offer now ("label:reason|…"): unchanged, nothing is rebuilt.
var _signature: String = ""
var _options: Array[InteractionOption] = []


func _ready() -> void:
	name = "InteractionPanel"
	add_theme_constant_override("separation", 10)
	_lines = VBoxContainer.new()
	_lines.name = "About"
	_lines.add_theme_constant_override("separation", 2)
	add_child(_lines)
	_rows = VBoxContainer.new()
	_rows.name = "Options"
	_rows.add_theme_constant_override("separation", 6)
	add_child(_rows)


## Shows the lines about the thing (`status` in a warmer colour, then `about`) and
## `options`; rebuilds the rows only when what they offer changed.
func show_thing(status: Array[String], about: Array[String], options: Array[InteractionOption]) -> void:
	for child: Node in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	for line: String in status:
		_line(line, STATUS_COLOR)
	for line: String in about:
		_line(line, REASON_COLOR)
	_lines.visible = _lines.get_child_count() > 0
	_options = options
	var parts: PackedStringArray = []
	for option: InteractionOption in options:
		parts.append("%s:%s" % [option.label, option.reason])
	var signature: String = "|".join(parts)
	if signature == _signature:
		return
	_signature = signature
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var place: int = focused.get_parent().get_index() if focused != null and _rows.is_ancestor_of(focused) else -1
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for index: int in options.size():
		var option: InteractionOption = options[index]
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Option"
		row.add_theme_constant_override("separation", 10)
		_rows.add_child(row)
		var button: Button = Button.new()
		button.name = "Do"
		button.text = option.label
		button.custom_minimum_size = Vector2(120, 38)
		button.tooltip_text = option.hint
		button.disabled = not option.available()
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		if option.accent:
			button.theme_type_variation = &"AccentButton"
		# The row's place, not its option: the same rows on another thing are not rebuilt.
		button.pressed.connect(_choose.bind(index))
		# A service's verb comes in the shown language already.
		if option.accent:
			button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		row.add_child(button)
		if not option.available():
			var why: Label = Label.new()
			why.name = "Reason"
			why.text = option.reason
			why.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			why.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			why.add_theme_font_size_override("font_size", 14)
			why.add_theme_color_override("font_color", REASON_COLOR)
			row.add_child(why)
	if place >= 0:
		_focus_row(place)


func _choose(index: int) -> void:
	if index < _options.size() and _options[index].available():
		chosen.emit(_options[index])


## The rows as [label, reason] (tests and the walk).
func shown() -> Array[Array]:
	var rows: Array[Array] = []
	for option: InteractionOption in _options:
		rows.append([option.label, option.reason])
	return rows


## Presses the row `label` (source text) when it can be done. False otherwise.
func press(label: String) -> bool:
	for option: InteractionOption in _options:
		if option.label == label and option.available():
			chosen.emit(option)
			return true
	return false


## The button of row `label` (source text), or null.
func button_of(label: String) -> Button:
	for index: int in _options.size():
		if _options[index].label == label and index < _rows.get_child_count():
			return _rows.get_child(index).get_node("Do") as Button
	return null


## Keys and pad start on the first row that can be done.
func focus_default() -> void:
	_focus_row(0)


func _focus_row(from: int) -> void:
	var count: int = _rows.get_child_count()
	for step: int in count:
		var button: Button = _rows.get_child((from + step) % count).get_node("Do") as Button
		if not button.disabled and FocusNav.give(button):
			return


func _line(text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	_lines.add_child(label)
