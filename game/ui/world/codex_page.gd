class_name CodexPage
extends VBoxContainer

## The menu's 百科 page (界面重构 C; 界面重做 2): its sections (CodexContent) along the top,
## a section's entries listed on the left and the entry read on the right. A section opens on
## its first entry; moving through the list (keys, pad, a click) reads the entry under it, and
## Back / Esc closes the menu as on every tab. Its texts come in the shown language from
## CodexContent.

# TRANSLATORS: the 百科 when a section has nothing in it yet.
const EMPTY_LINES: Array[String] = [
	"",
	"你还没有学会任何武学。",
	"你还没有拿过任何东西。",
	"你还没有遇见过任何门派的人。",
	"你还没有遇见过任何人。",
]
## The list column's width; the entry read takes the rest.
const LIST_WIDTH: float = 232.0

var section_buttons: Array[Button] = []
var entry_list: VBoxContainer
var list_scroll: ScrollContainer
var empty_label: Label
var article: VBoxContainer
var article_scroll: ScrollContainer
var article_title: Label
var article_body: VBoxContainer
var entry_buttons: Dictionary[String, Button] = {}
## The group heading above each group's first entry, by that entry's key.
var _group_headings: Dictionary[String, Label] = {}
var _section: int = CodexContent.Section.LORE
var _entries: Array[CodexContent.Entry] = []
## The entry read ("" none: the section is empty).
var _open_key: String = ""
var _state: CharacterState
var _entry_group := ButtonGroup.new()


func _init() -> void:
	name = "CodexPage"
	# The page takes the window's height: the list and the entry scroll on their own.
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	var sections := HBoxContainer.new()
	sections.name = "Sections"
	sections.add_theme_constant_override("separation", 6)
	add_child(sections)
	var group := ButtonGroup.new()
	for section: int in CodexContent.SECTION_TITLES.size():
		var button := Button.new()
		button.name = "Section%d" % section
		button.text = CodexContent.SECTION_TITLES[section]
		button.theme_type_variation = &"ToggleButton"
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(80, 36)
		button.pressed.connect(show_section.bind(section))
		sections.add_child(button)
		section_buttons.append(button)
	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	list_scroll = ScrollContainer.new()
	list_scroll.name = "ListScroll"
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.follow_focus = true
	list_scroll.custom_minimum_size = Vector2(LIST_WIDTH, 0)
	list_scroll.set_meta(ResponsivePanelLayout.KEEPS_WIDTH, true)
	body.add_child(list_scroll)
	entry_list = VBoxContainer.new()
	entry_list.name = "Entries"
	entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_list.add_theme_constant_override("separation", 2)
	list_scroll.add_child(entry_list)
	var well := PanelContainer.new()
	well.name = "Reading"
	well.theme_type_variation = &"WellPanel"
	well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(well)
	article_scroll = ScrollContainer.new()
	article_scroll.name = "ArticleScroll"
	article_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	article_scroll.add_to_group(PadSupport.SCROLL_GROUP)
	well.add_child(article_scroll)
	var reading := VBoxContainer.new()
	reading.name = "ReadingRows"
	reading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	article_scroll.add_child(reading)
	empty_label = Label.new()
	empty_label.name = "Empty"
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.theme_type_variation = &"MutedLabel"
	reading.add_child(empty_label)
	article = VBoxContainer.new()
	article.name = "Article"
	article.add_theme_constant_override("separation", 8)
	reading.add_child(article)
	article_title = Label.new()
	article_title.name = "Title"
	article_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	article_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	article_title.theme_type_variation = &"HeadingLabel"
	article.add_child(article_title)
	article_body = VBoxContainer.new()
	article_body.name = "Body"
	article_body.add_theme_constant_override("separation", 8)
	article.add_child(article_body)
	article.hide()


## Fills the page for `state` (the menu shows the tab): the section and entry read stay; a
## section opens on its first entry.
func fill(state: CharacterState) -> void:
	_state = state
	_entries = CodexContent.entries(_section, _state, GameContent.catalog())
	for index: int in section_buttons.size():
		section_buttons[index].set_pressed_no_signal(index == _section)
	if _entry(_open_key) == null:
		_open_key = "" if _entries.is_empty() else _entries[0].key
	_rebuild_list()
	_show_article(_entry(_open_key))


## Where keys and pad start: the entry read, else the section shown.
func focus_target() -> Control:
	return entry_buttons.get(_open_key, section_buttons[_section])


func current_section() -> int:
	return _section


func open_key() -> String:
	return _open_key


func entries() -> Array[CodexContent.Entry]:
	return _entries


func show_section(section: int) -> void:
	_section = section
	_open_key = ""
	fill(_state)


## Reads `key` beside the list (a click, or keys or pad moving onto it).
func open_entry(key: String) -> void:
	var entry: CodexContent.Entry = _entry(key)
	if entry == null:
		return
	var button: Button = entry_buttons.get(key)
	if key != _open_key:
		_open_key = key
		_show_article(entry)
	# Pressing it in its group lifts the one read before (set_pressed_no_signal would not).
	button.button_pressed = true
	if not button.has_focus() and button.is_visible_in_tree():
		FocusNav.give(button)
	if _group_headings.has(key):
		# A group's first entry keeps its heading in view (follow_focus would scroll it off).
		list_scroll.ensure_control_visible.call_deferred(_group_headings[key])


## Everything the page shows now (tests).
func shown_text() -> String:
	if _open_key.is_empty():
		return empty_label.text
	var lines: Array[String] = [article_title.text]
	for label: Node in article_body.get_children():
		lines.append((label as Label).text)
	return "\n".join(lines)


## The titles listed on the left (tests).
func listed_titles() -> Array[String]:
	var titles: Array[String] = []
	for button: Button in entry_buttons.values():
		titles.append(button.text)
	return titles


func _rebuild_list() -> void:
	for child: Node in entry_list.get_children():
		entry_list.remove_child(child)
		child.queue_free()
	entry_buttons.clear()
	_group_headings.clear()
	var group: String = ""
	for entry: CodexContent.Entry in _entries:
		if entry.group != group and not entry.group.is_empty():
			# A group's heading above its first entry (江湖常识: 入门, 传说); not a stop for keys or pad.
			var heading := Label.new()
			heading.name = "Group%d" % entry_list.get_child_count()
			heading.text = entry.group
			heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			heading.theme_type_variation = &"MutedLabel"
			entry_list.add_child(heading)
			_group_headings[entry.key] = heading
		group = entry.group
		var button := Button.new()
		button.name = "Entry%d" % entry_buttons.size()
		button.text = entry.title
		button.theme_type_variation = &"RowButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = _entry_group
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = Vector2(0, 36)
		button.set_pressed_no_signal(entry.key == _open_key)
		button.pressed.connect(open_entry.bind(entry.key))
		button.focus_entered.connect(open_entry.bind(entry.key))
		entry_list.add_child(button)
		entry_buttons[entry.key] = button
	empty_label.text = EMPTY_LINES[_section]
	list_scroll.visible = not entry_buttons.is_empty()


func _show_article(entry: CodexContent.Entry) -> void:
	empty_label.visible = entry == null
	article.visible = entry != null
	article_scroll.scroll_vertical = 0
	for child: Node in article_body.get_children():
		article_body.remove_child(child)
		child.queue_free()
	if entry == null:
		article_title.text = ""
		return
	article_title.text = entry.title
	for paragraph: CodexContent.Paragraph in entry.paragraphs:
		var label := Label.new()
		label.text = paragraph.text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		match paragraph.kind:
			CodexContent.Paragraph.Kind.HEADING:
				label.add_theme_color_override("font_color", UiPalette.GOLD)
			CodexContent.Paragraph.Kind.NOTE:
				label.theme_type_variation = &"MutedLabel"
		article_body.add_child(label)


func _entry(key: String) -> CodexContent.Entry:
	if key.is_empty():
		return null
	for entry: CodexContent.Entry in _entries:
		if entry.key == key:
			return entry
	return null
