class_name QuestPage
extends VBoxContainer

## The 任务 page (任务系统; DECISIONS「任务系统」): four columns in turn, 主线 / 势力 / 地区 /
## 差事 (StoryQuestDefinition.LINES), each with the quests begun on that line
## (StoryQuestLog.shown: the one with the newest news first, what to do next, what was
## recorded) and the story chains of that line (JournalStories). 朱鸿雪's task (quest.c's
## lines) and the 雪亭驿 board's chain stand under 差事. A column with nothing is not shown.
## Each quest and each chain is a card of its own (界面重做 2).

# TRANSLATORS: the 任务 page before any quest began or story entry was recorded.
const NOTHING_YET: String = "你还没有记下什么江湖见闻。"
# TRANSLATORS: the 任务 page: the heading over where the player's corpse lies and who waits apart (DECISIONS「尸体和走散的同伴」).
const LEFT_BEHIND: String = "留在路上的"

## quest.c's lines for 朱鸿雪's task (the 差事 column).
var quest_text: Label
var _sections: Dictionary[String, VBoxContainer] = {}
var _stories: Dictionary[String, JournalStories] = {}
var _quests: Dictionary[String, VBoxContainer] = {}
var _nothing: Label
## Native (DECISIONS「尸体和走散的同伴」): where the player's corpses with things in them lie and who
## waits apart from them (WorldLeftBehind), one line each, above the columns; hidden when none.
var _left_behind: PanelContainer
var _left_lines: VBoxContainer


func _init() -> void:
	name = "QuestPage"
	add_theme_constant_override("separation", 12)
	_nothing = _label(self, NOTHING_YET, Color(0, 0, 0, 0))
	_nothing.name = "Nothing"
	_nothing.theme_type_variation = &"MutedLabel"
	_left_behind = card(self)
	_left_behind.name = "LeftBehind"
	_left_lines = _left_behind.get_child(0) as VBoxContainer
	var left_heading := _label(_left_lines, LEFT_BEHIND, Color(0, 0, 0, 0))
	left_heading.name = "Heading"
	left_heading.theme_type_variation = &"HeadingLabel"
	# A message of its own (the POT knows it): translated as the page shows, as the columns' names.
	left_heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT
	_left_behind.visible = false
	for line: String in StoryQuestDefinition.LINES:
		var section := VBoxContainer.new()
		section.name = line.capitalize()
		section.add_theme_constant_override("separation", 6)
		add_child(section)
		var heading := _label(section, StoryQuestDefinition.LINE_TITLES[line], Color(0, 0, 0, 0))
		heading.name = "Heading"
		heading.theme_type_variation = &"HeadingLabel"
		# The column's name is a message of its own (the POT knows it): translated as the page shows.
		heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT
		if line == StoryQuestDefinition.LINE_ERRAND:
			var task := card(section)
			task.name = "Task"
			quest_text = _label(task.get_child(0), "", Color(0, 0, 0, 0))
			quest_text.name = "Quest"
		var quests := VBoxContainer.new()
		quests.name = "Quests"
		quests.add_theme_constant_override("separation", 6)
		section.add_child(quests)
		var stories := JournalStories.new()
		section.add_child(stories)
		_sections[line] = section
		_stories[line] = stories
		_quests[line] = quests


## `respect`: how NPCs address the player ($RESPECT in quoted lines); `task_lines` quest.c's
## lines for 朱鸿雪's task ("" for none); `test` a condition -> whether it holds for the player now
## (WorldSessionController.quest_condition_test(): the current steps' checklists; none, no rows).
## `left_behind`: one line for each corpse with things in it and each follower apart
## (WorldLeftBehind.line()).
func fill(state: CharacterState, respect: String, task_lines: String, test: Callable = Callable(), left_behind: Array[String] = []) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_fill_left_behind(left_behind)
	var anything: bool = not left_behind.is_empty()
	for line: String in StoryQuestDefinition.LINES:
		var quests: VBoxContainer = _quests[line]
		for child: Node in quests.get_children():
			quests.remove_child(child)
			child.queue_free()
		var shown: Array[StoryQuestLog.Shown] = StoryQuestLog.shown(state, catalog.story_quests(), line, test)
		for view: StoryQuestLog.Shown in shown:
			_show_quest(quests, view)
		_stories[line].fill(state, respect, line, false)
		var task: bool = line == StoryQuestDefinition.LINE_ERRAND and not task_lines.is_empty()
		if line == StoryQuestDefinition.LINE_ERRAND:
			# The text goes with the task (the menu's refresh compares it with quest.c's lines).
			quest_text.text = task_lines
			quest_text.visible = task
			(quest_text.get_parent().get_parent() as Control).visible = task
		var something: bool = not shown.is_empty() or _stories[line].get_child_count() > 0 or task
		_sections[line].visible = something
		anything = anything or something
	_nothing.visible = not anything


func _show_quest(parent: Node, view: StoryQuestLog.Shown) -> void:
	var title: String
	if view.done:
		# TRANSLATORS: a quest on the 任务 page once done: {title} its name, {region} where it happened.
		title = tr("{title} · {region} · 已完成").format({"title": tr(view.quest.title), "region": tr(view.quest.region)})
	elif view.lapsed:
		# TRANSLATORS: a quest on the 任务 page cut short before its end (the player left the family whose line it was): {title} its name, {region} where it happened.
		title = tr("{title} · {region} · 已中止").format({"title": tr(view.quest.title), "region": tr(view.quest.region)})
	else:
		# TRANSLATORS: a quest on the 任务 page: {title} its name, {region} where it happens.
		title = tr("{title} · {region}").format({"title": tr(view.quest.title), "region": tr(view.quest.region)})
	var rows: VBoxContainer = card(parent).get_child(0) as VBoxContainer
	_label(rows, title, UiPalette.MUTED if view.done or view.lapsed else UiPalette.LANTERN).name = "Title"
	_label(rows, tr(view.quest.summary), UiPalette.MUTED).name = "Summary"
	if not view.objective.is_empty():
		# TRANSLATORS: under a quest on the 任务 page: {next} what to do now.
		_label(rows, tr("下一步：{next}").format({"next": tr(view.objective)}), UiPalette.GOLD).name = "Objective"
	for checked: StoryQuestLog.Checked in view.checklist:
		_label(rows, checklist_text(checked), UiPalette.GOLD if checked.tick == StoryQuestLog.Checked.Tick.DONE else UiPalette.MUTED).name = "Check"
	for entry: String in view.entries:
		_label(rows, "· " + tr(entry), UiPalette.MUTED if view.done or view.lapsed else Color(0, 0, 0, 0)).name = "Entry"


## A checklist row as the page writes it (DECISIONS「任务清单」): ticked ✓ or not ✗ as the 拜师
## page's conditions are, a count with how many of how many, what is missing after a dash; a note
## with a dot.
static func checklist_text(checked: StoryQuestLog.Checked) -> String:
	var label: String = TranslationServer.translate(checked.row.label)
	if checked.row.counts:
		# TRANSLATORS: a quest checklist row that counts: {label} what is counted, {have} how many there are, {want} how many are wanted.
		label = TranslationServer.translate("{label}：{have}／{want}").format({"label": label, "have": checked.have, "want": checked.want})
	match checked.tick:
		StoryQuestLog.Checked.Tick.DONE:
			# TRANSLATORS: a quest checklist row that holds: {row} the row.
			return TranslationServer.translate("  {row} ✓").format({"row": label})
		StoryQuestLog.Checked.Tick.LACKING:
			if not checked.row.missing.is_empty():
				# TRANSLATORS: a quest checklist row that does not hold: {row} the row, {missing} what is missing.
				return TranslationServer.translate("  {row} ✗——{missing}").format({"row": label, "missing": TranslationServer.translate(checked.row.missing)})
			# TRANSLATORS: a quest checklist row that does not hold: {row} the row.
			return TranslationServer.translate("  {row} ✗").format({"row": label})
	# TRANSLATORS: a quest checklist note (no tick): {row} the note.
	return TranslationServer.translate("  · {row}").format({"row": label})


## A quest's or a chain's card: a recess with its rows.
static func card(parent: Node) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Card"
	card.theme_type_variation = &"WellPanel"
	parent.add_child(card)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 4)
	card.add_child(rows)
	return card


func _fill_left_behind(left_behind: Array[String]) -> void:
	for index: int in range(_left_lines.get_child_count() - 1, 0, -1):
		var old: Node = _left_lines.get_child(index)
		_left_lines.remove_child(old)
		old.queue_free()
	for text: String in left_behind:
		_label(_left_lines, text, Color(0, 0, 0, 0)).name = "Line"
	_left_behind.visible = not left_behind.is_empty()


## Every text the page shows, one per line, the hidden columns left out (tests).
func shown_text() -> String:
	var lines: Array[String] = []
	if _nothing.visible:
		lines.append(_nothing.text)
	if _left_behind.visible:
		for node: Node in _left_lines.get_children():
			lines.append((node as Label).text)
	for line: String in StoryQuestDefinition.LINES:
		if not _sections[line].visible:
			continue
		for node: Node in _sections[line].find_children("*", "Label", true, false):
			var label := node as Label
			if label.visible and not label.text.is_empty():
				lines.append(label.text)
	return "\n".join(lines)


## `color` transparent keeps the theme's.
func _label(parent: Node, text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = ShownText.of(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if color.a > 0.0:
		label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
