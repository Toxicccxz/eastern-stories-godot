class_name KeyBindingsPage
extends ColorRect

## 按键一览 (owner 2026-11-12「按推荐做」; DECISIONS「按键」): every action the player uses
## with its keys and its pad buttons, read from the InputMap as it stands; read-only (the
## rebinding screen is a pre-release item, a pad's own remapping is Steam Input's). Opened from
## 设置; 返回, Esc or B closes it and the focus goes back where it came from.

signal closed

## [label, actions]: one row each, the keys and buttons of all its actions together.
const ROWS: Array[Array] = [
	["走路", [&"move_up", &"move_left", &"move_down", &"move_right"]],
	["交互 · 继续", [&"interact"]],
	["确认", [&"ui_accept"]],
	["返回 · 取消", [&"ui_cancel"]],
	["换目标", [&"nearby_focus", &"menu_tab_previous"]],
	["观察", [&"look_around"]],
	["切换视角", [&"view_side"]],
	["菜单", [&"menu_open"]],
	["菜单翻页", [&"menu_tab_previous", &"menu_tab_next"]],
	["角色", [&"menu_character"]],
	["武学", [&"menu_martial_arts"]],
	["背包", [&"menu_inventory"]],
	["任务", [&"menu_journal"]],
	["地图", [&"menu_map"]],
	["地图：移动", [&"map_pan"]],
	["地图：缩放", [&"map_zoom_out", &"map_zoom_in"]],
	["地图：回到所在", [&"map_here"]],
	["地图：全图 / 近看", [&"map_overview"]],
	["暂停（系统）", [&"pause_game"]],
	["滚动长文", [&"scroll_up", &"scroll_down"]],
	["战斗：换目标", [&"battle_target_previous", &"battle_target_next"]],
	["战斗：记录", [&"battle_log"]],
	["战斗：收回指令", [&"battle_back"]],
]

var back_button: Button
var grid: GridContainer
var _return_focus: Control


func _init() -> void:
	name = "KeyBindingsPage"
	color = UiPalette.SCRIM
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = GameTheme.shared()
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"MenuWindow"
	center.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	panel.add_child(rows)
	var title := Label.new()
	title.theme_type_variation = &"HeadingLabel"
	title.text = "按键一览"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	var note := Label.new()
	note.theme_type_variation = &"SmallLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(620, 0)
	# TRANSLATORS: under 按键一览's title (DECISIONS「按键」).
	note.text = "字母键按键盘上的位置算，这里写的是你的键盘在那个位置印的字。暂时不能改键；手柄可以在 Steam 的控制器设置里改。"
	rows.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_to_group(PadSupport.SCROLL_GROUP)
	rows.add_child(scroll)
	grid = GridContainer.new()
	grid.name = "Rows"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = "返回"
	back_button.custom_minimum_size = Vector2(140, 48)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(close)
	InputGlyphs.decorate(back_button, &"ui_cancel")
	# The focus stays on the page: 设置 under it is out of reach until it closes.
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		back_button.set_focus_neighbor(side, NodePath("."))
	back_button.focus_next = NodePath(".")
	back_button.focus_previous = NodePath(".")
	rows.add_child(back_button)


## Shows the bindings as they stand now (the pad's names as the last pad seen prints them).
func open(return_focus: Control = null) -> void:
	_return_focus = return_focus
	_fill()
	visible = true
	back_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	_return_focus = null
	closed.emit()


## The keys and buttons shown on the row of `label` ("" when it has none of that kind).
func row_text(label: String) -> Array[String]:
	for index: int in range(0, grid.get_child_count(), 3):
		if (grid.get_child(index) as Label).text == tr(label):
			var pads: Control = grid.get_child(index + 2) as Control
			return [(grid.get_child(index + 1) as Label).text, String(pads.get_meta(&"names", ""))]
	return []


func _fill() -> void:
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for heading: String in ["动作", "键盘", "手柄"]:
		_cell(heading, &"MutedLabel")
	var style: int = InputDevices.shared().pad_style
	for row: Array in ROWS:
		var keys := PackedStringArray()
		var pads: Array[InputGlyphs.Glyph] = []
		var pad_names := PackedStringArray()
		for action: StringName in row[1]:
			for key: String in InputGlyphs.key_names(action):
				if not keys.has(key):
					keys.append(key)
			for pad: InputGlyphs.Glyph in InputGlyphs.pad_glyphs(action, style):
				if not pad_names.has(InputGlyphs.shown_name(pad)):
					pad_names.append(InputGlyphs.shown_name(pad))
					pads.append(pad)
		keys = _collapse(keys, ["Up", "Left", "Down", "Right"], tr("方向键"))
		_cell(row[0], &"")
		_cell(" / ".join(keys) if not keys.is_empty() else "—", &"", false)
		_pad_cell(_collapse_pad(pads))


## The four arrows (or the D-pad's four) written once, as one name at the end, where all four are there.
static func _collapse(names: PackedStringArray, four: Array[String], one: String) -> PackedStringArray:
	for name: String in four:
		if not names.has(name):
			return names
	var shown := PackedStringArray()
	for name: String in names:
		if not four.has(name):
			shown.append(name)
	shown.append(one)
	return shown


## The D-pad's four arms shown once, as the whole pad, where all four are there.
static func _collapse_pad(glyphs: Array[InputGlyphs.Glyph]) -> Array[InputGlyphs.Glyph]:
	var arms: int = 0
	for glyph: InputGlyphs.Glyph in glyphs:
		arms += 1 if glyph.shape == InputGlyphs.Shape.DPAD else 0
	if arms < 4:
		return glyphs
	var shown: Array[InputGlyphs.Glyph] = []
	for glyph: InputGlyphs.Glyph in glyphs:
		if glyph.shape != InputGlyphs.Shape.DPAD:
			shown.append(glyph)
	shown.append(InputGlyphs.Glyph.new(InputGlyphs.Shape.DPAD, "", InputGlyphs.PLATE, TranslationServer.translate("十字键")))
	return shown


## The pad column: the buttons drawn as the pad shows them, their names in the tooltip.
func _pad_cell(glyphs: Array[InputGlyphs.Glyph]) -> void:
	var names := PackedStringArray()
	for glyph: InputGlyphs.Glyph in glyphs:
		names.append(InputGlyphs.shown_name(glyph))
	if glyphs.is_empty():
		_cell("—", &"", false)
		grid.get_child(grid.get_child_count() - 1).set_meta(&"names", "—")
		return
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 6)
	cell.set_meta(&"names", " / ".join(names))
	cell.tooltip_text = " / ".join(names)
	for glyph: InputGlyphs.Glyph in glyphs:
		var icon := TextureRect.new()
		icon.texture = InputGlyphTexture.of(glyph)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.add_child(icon)
	grid.add_child(cell)


func _cell(text: String, variation: StringName, translated: bool = true) -> void:
	var label := Label.new()
	label.text = text
	if not variation.is_empty():
		label.theme_type_variation = variation
	if not translated:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	grid.add_child(label)


## Esc, B and the system Back close the page, and only the page.
func _input(event: InputEvent) -> void:
	if not visible or event.is_echo() or not event.is_pressed():
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"system_back") or event.is_action_pressed(&"pause_game"):
		get_viewport().set_input_as_handled()
		close()
