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

## quest.c's lines for 朱鸿雪's task (the 差事 column).
var quest_text: Label
var _sections: Dictionary[String, VBoxContainer] = {}
var _stories: Dictionary[String, JournalStories] = {}
var _quests: Dictionary[String, VBoxContainer] = {}
var _nothing: Label


func _init() -> void:
	name = "QuestPage"
	add_theme_constant_override("separation", 12)
	_nothing = _label(self, NOTHING_YET, Color(0, 0, 0, 0))
	_nothing.name = "Nothing"
	_nothing.theme_type_variation = &"MutedLabel"
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
## lines for 朱鸿雪's task ("" for none).
func fill(state: CharacterState, respect: String, task_lines: String) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var anything: bool = false
	for line: String in StoryQuestDefinition.LINES:
		var quests: VBoxContainer = _quests[line]
		for child: Node in quests.get_children():
			quests.remove_child(child)
			child.queue_free()
		var shown: Array[StoryQuestLog.Shown] = StoryQuestLog.shown(state, catalog.story_quests(), line)
		for view: StoryQuestLog.Shown in shown:
			_show_quest(quests, view)
		_stories[line].fill(state, respect, line, false)
		var task: bool = line == StoryQuestDefinition.LINE_ERRAND and not task_lines.is_empty()
		if task:
			quest_text.text = task_lines
		if line == StoryQuestDefinition.LINE_ERRAND:
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
	else:
		# TRANSLATORS: a quest on the 任务 page: {title} its name, {region} where it happens.
		title = tr("{title} · {region}").format({"title": tr(view.quest.title), "region": tr(view.quest.region)})
	var rows: VBoxContainer = card(parent).get_child(0) as VBoxContainer
	_label(rows, title, UiPalette.MUTED if view.done else UiPalette.LANTERN).name = "Title"
	_label(rows, tr(view.quest.summary), UiPalette.MUTED).name = "Summary"
	if not view.objective.is_empty():
		# TRANSLATORS: under a quest on the 任务 page: {next} what to do now.
		_label(rows, tr("下一步：{next}").format({"next": tr(view.objective)}), UiPalette.GOLD).name = "Objective"
	for entry: String in view.entries:
		_label(rows, "· " + tr(entry), UiPalette.MUTED if view.done else Color(0, 0, 0, 0)).name = "Entry"


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


## Every text the page shows, one per line, the hidden columns left out (tests).
func shown_text() -> String:
	var lines: Array[String] = []
	if _nothing.visible:
		lines.append(_nothing.text)
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
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if color.a > 0.0:
		label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
