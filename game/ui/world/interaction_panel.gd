class_name InteractionPanel
extends HBoxContainer

## The interaction popup (DECISIONS「说话和交互」), in the shared frame (titled with the
## thing's name and title), one window to the end: on the left everything the thing offers
## (SharedUiNearby.options_for() but 查看), one row each, a row the rules refuse now greyed
## with the reason under it; on the right its 查看 (how it is now, then what looking at it
## shows: the details) or the page a row opened (打听, a shop, 给予, a question), titled, its
## row marked on the left. SharedGameplayLayout puts what opens while the popup shows into
## page_mount(); closing the page (返回, B) shows 查看 again. Choosing a row emits `chosen`.
## Keys and pad start on the first row that can be done and move between the columns.

signal chosen(option: InteractionOption)

const REASON_COLOR: Color = Color(0.62, 0.6, 0.56)
const STATUS_COLOR: Color = Color(1.0, 0.78, 0.45)
const ROW_WIDTH: float = 150.0

var _rows: VBoxContainer
var _options_scroll: ScrollContainer
var _page_scroll: ScrollContainer
var _heading: Label
var _status: VBoxContainer
var _about: VBoxContainer
var _look: VBoxContainer
var _look_text: Label
## Where the details live, never shown here: looking at the thing opens them, which the
## frame takes as "back to 查看" (their text is copied into _look_text).
var _held: Control
var _mount: VBoxContainer
## What the rows offer now ("label:reason|…"): unchanged, nothing is rebuilt.
var _signature: String = ""
var _options: Array[InteractionOption] = []
## The row whose page shows ("" on 查看).
var _current: String = ""
## 查看 shows the details (the thing was looked at); else the lines about it.
var _looked: bool = false


func _ready() -> void:
	name = "InteractionPanel"
	add_theme_constant_override("separation", 14)
	# The frame keeps one size (SharedGameplayLayout.HOST_SHARE): each column scrolls itself.
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows = VBoxContainer.new()
	_rows.name = "Options"
	_rows.add_theme_constant_override("separation", 6)
	_options_scroll = _scroll("OptionsScroll", _rows, false)
	add_child(_options_scroll)
	var rule := VSeparator.new()
	rule.name = "Rule"
	add_child(rule)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	_heading = Label.new()
	_heading.name = "Heading"
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_heading.add_theme_color_override("font_color", SharedGameplayLayout.ACCENT_COLOR)
	column.add_child(_heading)
	var page := VBoxContainer.new()
	page.name = "Page"
	page.add_theme_constant_override("separation", 8)
	_page_scroll = _scroll("PageScroll", page, true)
	# The right stick scrolls a long page (a teacher's list) as it does the frame.
	_page_scroll.add_to_group(PadSupport.SCROLL_GROUP)
	column.add_child(_page_scroll)
	_status = _box(page, "Status")
	_about = _box(page, "About")
	_look = _box(page, "Look")
	_look_text = Label.new()
	_look_text.name = "LookText"
	_look_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_look_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_look.add_child(_look_text)
	_held = Control.new()
	_held.name = "Held"
	_held.hide()
	page.add_child(_held)
	_mount = _box(page, "Mount")
	show_look()


## Where 查看's details live (hidden): opening them while the popup shows is its 查看.
func hold_look(details: Control) -> void:
	details.reparent(_held, false)


## The page's place (SharedGameplayLayout puts what opens over the popup there).
func page_mount() -> Control:
	return _mount


## The right column shows 查看; no row is marked. `fresh`: a new popup (no row chosen yet;
## else the row stays known, its page may come back: 给予 after its question).
func show_look(fresh: bool = false) -> void:
	if fresh:
		_current = ""
		_options_scroll.scroll_vertical = 0
	if fresh or _mount.visible:
		_page_scroll.scroll_vertical = 0
	_heading.hide()
	_mount.hide()
	_status.visible = _status.get_child_count() > 0
	_about.visible = not _looked and _about.get_child_count() > 0
	_look.visible = _looked
	_mark_current()


## The right column shows a page titled `title`; the row that opened it is marked.
func show_page(title: String) -> void:
	_page_scroll.scroll_vertical = 0
	_heading.text = title
	_heading.show()
	_status.hide()
	_about.hide()
	_look.hide()
	_mount.show()
	_mark_current()


## Whether the right column shows a page.
func page_shown() -> bool:
	return _mount.visible


## What looking at the thing showed (the details' text), kept for 查看 while the popup
## shows (a row selects the thing again, which clears the details); "" for none: 查看 then
## shows the lines about it.
func set_look(text: String) -> void:
	_looked = not text.is_empty()
	_look_text.text = text
	if not page_shown():
		show_look()


## Shows the lines about the thing (`status` in a warmer colour, then `about`, which 查看
## shows only without the details) and `options`; rebuilds the rows only when what they
## offer changed.
func show_thing(status: Array[String], about: Array[String], options: Array[InteractionOption]) -> void:
	var changed: bool = _lines(_status, status, STATUS_COLOR)
	changed = _lines(_about, about, REASON_COLOR) or changed
	if changed and not page_shown():
		show_look()
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
		var row: VBoxContainer = VBoxContainer.new()
		row.name = "Option"
		row.add_theme_constant_override("separation", 2)
		_rows.add_child(row)
		var button: Button = Button.new()
		button.name = "Do"
		button.text = option.label
		button.custom_minimum_size = Vector2(ROW_WIDTH, 38)
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
			why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			why.add_theme_font_size_override("font_size", 13)
			why.add_theme_color_override("font_color", REASON_COLOR)
			row.add_child(why)
	_mark_current()
	if place >= 0:
		_focus_row(place)


func _choose(index: int) -> void:
	if index < _options.size() and _options[index].available():
		_current = _options[index].label
		chosen.emit(_options[index])


## The rows as [label, reason] (tests and the walk).
func shown() -> Array[Array]:
	var rows: Array[Array] = []
	for option: InteractionOption in _options:
		rows.append([option.label, option.reason])
	return rows


## Presses the row `label` (source text) when it can be done. False otherwise.
func press(label: String) -> bool:
	for index: int in _options.size():
		if _options[index].label == label and _options[index].available():
			_choose(index)
			return true
	return false


## The button of row `label` (source text), or null.
func button_of(label: String) -> Button:
	for index: int in _options.size():
		if _options[index].label == label and index < _rows.get_child_count():
			return _rows.get_child(index).get_node("Do") as Button
	return null


## The row whose page shows (source text), "" on 查看.
func current() -> String:
	return _current if page_shown() else ""


## What 查看 shows now, as plain text (tests and the walk).
func look_text() -> String:
	var parts: PackedStringArray = []
	for box: VBoxContainer in [_status, _about]:
		if box.visible:
			for line: Node in box.get_children():
				parts.append((line as Label).text)
	if _look.visible:
		parts.append(_look_text.text)
	return "\n".join(parts)


## Keys and pad start on the first row that can be done.
func focus_default() -> void:
	_focus_row(0)


## Back from a page: the focus on the row `label` that opened it (else the first).
func focus_row(label: String) -> void:
	var button: Button = button_of(label)
	_focus_row(0 if button == null else button.get_parent().get_index())


func _focus_row(from: int) -> void:
	var count: int = _rows.get_child_count()
	for step: int in count:
		var button: Button = _rows.get_child((from + step) % count).get_node("Do") as Button
		if not button.disabled and FocusNav.give(button):
			return


## The row whose page shows is marked in the accent colour.
func _mark_current() -> void:
	var marked: Button = button_of(_current) if page_shown() else null
	for row: Node in _rows.get_children():
		var button: Button = row.get_node("Do") as Button
		if button == marked:
			for state: StringName in [&"normal", &"hover"]:
				button.add_theme_stylebox_override(state, _marked_style())
			for color: StringName in [&"font_color", &"font_hover_color", &"font_focus_color"]:
				button.add_theme_color_override(color, SharedGameplayLayout.ACCENT_COLOR.lightened(0.3))
		else:
			for state: StringName in [&"normal", &"hover"]:
				button.remove_theme_stylebox_override(state)
			for color: StringName in [&"font_color", &"font_hover_color", &"font_focus_color"]:
				button.remove_theme_color_override(color)


static func _marked_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(SharedGameplayLayout.ACCENT_COLOR, 0.24)
	style.border_color = Color(SharedGameplayLayout.ACCENT_COLOR, 0.6)
	style.border_width_left = 3
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


## Puts `lines` into `box`; false when it showed them already.
func _lines(box: VBoxContainer, lines: Array[String], color: Color) -> bool:
	var shown: Array[String] = []
	for child: Node in box.get_children():
		shown.append((child as Label).text)
	if shown == lines:
		return false
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()
	for text: String in lines:
		var label: Label = Label.new()
		label.text = text
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", color)
		box.add_child(label)
	return true


## A column that scrolls up and down, `content` filling its width.
static func _scroll(node_name: String, content: Control, expand: bool) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if expand:
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return scroll


static func _box(parent: Node, node_name: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = node_name
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	return box
