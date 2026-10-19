class_name CodexPage
extends VBoxContainer

## The menu's 百科 page (界面重构 C): its sections (CodexContent), a section's entries as
## buttons, and one entry read at a time; 返回列表 (or Back / Esc) goes back to the
## entries. Its texts come in the shown language from CodexContent.

# TRANSLATORS: the 百科 when a section has nothing in it yet.
const EMPTY_LINES: Array[String] = [
	"",
	"你还没有学会任何武学。",
	"你还没有拿过任何东西。",
	"你还没有遇见过任何门派的人。",
	"你还没有遇见过任何人。",
]

var section_buttons: Array[Button] = []
var entry_list: HFlowContainer
var empty_label: Label
var article: VBoxContainer
var back_button: Button
var article_title: Label
var article_body: VBoxContainer
var entry_buttons: Dictionary[String, Button] = {}
var _section: int = CodexContent.Section.LORE
var _entries: Array[CodexContent.Entry] = []
## The entry being read ("" the list).
var _open_key: String = ""
var _state: CharacterState
## True while a question shows over the menu: Back / Esc is the question's.
var blocked: Callable


func _init() -> void:
	name = "CodexPage"
	add_theme_constant_override("separation", 10)
	var sections := HFlowContainer.new()
	sections.name = "Sections"
	sections.add_theme_constant_override("h_separation", 8)
	sections.add_theme_constant_override("v_separation", 8)
	add_child(sections)
	var group := ButtonGroup.new()
	for section: int in CodexContent.SECTION_TITLES.size():
		var button := Button.new()
		button.name = "Section%d" % section
		button.text = CodexContent.SECTION_TITLES[section]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(80, 38)
		button.pressed.connect(show_section.bind(section))
		sections.add_child(button)
		section_buttons.append(button)
	entry_list = HFlowContainer.new()
	entry_list.name = "Entries"
	entry_list.add_theme_constant_override("h_separation", 8)
	entry_list.add_theme_constant_override("v_separation", 8)
	add_child(entry_list)
	empty_label = Label.new()
	empty_label.name = "Empty"
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.theme_type_variation = &"MutedLabel"
	add_child(empty_label)
	article = VBoxContainer.new()
	article.name = "Article"
	article.add_theme_constant_override("separation", 8)
	add_child(article)
	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = "返回列表"
	back_button.custom_minimum_size = Vector2(96, 38)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(close_entry)
	article.add_child(back_button)
	article_title = Label.new()
	article_title.name = "Title"
	article_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	article_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	article_title.add_theme_font_size_override("font_size", 18)
	article_title.theme_type_variation = &"AccentLabel"
	article.add_child(article_title)
	article_body = VBoxContainer.new()
	article_body.name = "Body"
	article_body.add_theme_constant_override("separation", 8)
	article.add_child(article_body)
	article.hide()


## Fills the page for `state` (the menu shows the tab): the section and entry read stay.
func fill(state: CharacterState) -> void:
	_state = state
	_entries = CodexContent.entries(_section, _state, GameContent.catalog())
	for index: int in section_buttons.size():
		section_buttons[index].set_pressed_no_signal(index == _section)
	if not _open_key.is_empty() and _entry(_open_key) == null:
		_open_key = ""
	_rebuild_list()
	if _open_key.is_empty():
		_show_list()
	else:
		_show_article(_entry(_open_key))


## Where keys and pad start: the entry's 返回列表, else the section shown.
func focus_target() -> Control:
	return back_button if not _open_key.is_empty() else section_buttons[_section]


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


func open_entry(key: String) -> void:
	var entry: CodexContent.Entry = _entry(key)
	if entry == null:
		return
	_open_key = key
	_show_article(entry)
	FocusNav.give(back_button)


func close_entry() -> void:
	var key: String = _open_key
	_open_key = ""
	_show_list()
	FocusNav.give(entry_buttons.get(key))


## Everything the page shows now (tests).
func shown_text() -> String:
	if not _open_key.is_empty():
		var lines: Array[String] = [article_title.text]
		for label: Node in article_body.get_children():
			lines.append((label as Label).text)
		return "\n".join(lines)
	if entry_buttons.is_empty():
		return empty_label.text
	var titles: Array[String] = []
	for button: Button in entry_buttons.values():
		titles.append(button.text)
	return "\n".join(titles)


func _rebuild_list() -> void:
	for child: Node in entry_list.get_children():
		entry_list.remove_child(child)
		child.queue_free()
	entry_buttons.clear()
	for entry: CodexContent.Entry in _entries:
		var button := Button.new()
		button.name = "Entry%d" % entry_buttons.size()
		button.text = entry.title
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = Vector2(72, 38)
		button.pressed.connect(open_entry.bind(entry.key))
		entry_list.add_child(button)
		entry_buttons[entry.key] = button
	empty_label.text = EMPTY_LINES[_section]


func _show_list() -> void:
	article.hide()
	entry_list.visible = not entry_buttons.is_empty()
	empty_label.visible = entry_buttons.is_empty()


func _show_article(entry: CodexContent.Entry) -> void:
	entry_list.hide()
	empty_label.hide()
	article.show()
	article_title.text = entry.title
	for child: Node in article_body.get_children():
		article_body.remove_child(child)
		child.queue_free()
	for paragraph: CodexContent.Paragraph in entry.paragraphs:
		var label := Label.new()
		label.text = paragraph.text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		match paragraph.kind:
			CodexContent.Paragraph.Kind.HEADING:
				label.theme_type_variation = &"AccentLabel"
			CodexContent.Paragraph.Kind.NOTE:
				label.theme_type_variation = &"MutedLabel"
		article_body.add_child(label)


func _entry(key: String) -> CodexContent.Entry:
	for entry: CodexContent.Entry in _entries:
		if entry.key == key:
			return entry
	return null


## Back / Esc while reading an entry goes back to the list, not out of the menu.
func _unhandled_input(event: InputEvent) -> void:
	if _open_key.is_empty() or not is_visible_in_tree() or event.is_echo() or not event.is_action_pressed(&"ui_cancel"):
		return
	if blocked.is_valid() and blocked.call():
		return
	close_entry()
	get_viewport().set_input_as_handled()
