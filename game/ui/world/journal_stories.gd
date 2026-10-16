class_name JournalStories
extends VBoxContainer

## The 任务 page's 江湖见闻 (界面重构 C): the story chains with something recorded
## (JournalLog.shown()), the newest first, each with its entries in the order they
## happened and what was said under them, as the ask showed it.

# TRANSLATORS: the 任务 page before any story entry is recorded.
const NOTHING_YET: String = "你还没有记下什么江湖见闻。"


func _init() -> void:
	name = "Stories"
	add_theme_constant_override("separation", 6)


## `respect`: how NPCs address the player ($RESPECT in quoted lines).
func fill(state: CharacterState, respect: String) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var catalog: ContentCatalog = GameContent.catalog()
	var shown: Array[JournalLog.Shown] = JournalLog.shown(state, catalog.journal_chains())
	if shown.is_empty():
		var nothing := _label(NOTHING_YET, SharedGameplayLayout.MUTED_COLOR)
		nothing.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT
		return
	for view: JournalLog.Shown in shown:
		_label(tr("{title} · {region}").format({"title": tr(view.chain.title), "region": tr(view.chain.region)}), SharedGameplayLayout.ACCENT_COLOR).name = "Chain"
		for entry: JournalEntryDefinition in view.entries:
			_label("· " + tr(entry.text), Color(0, 0, 0, 0)).name = "Entry"
			var npc: NpcDefinition = catalog.npc(entry.quote_npc) if not entry.quote_npc.is_empty() else null
			for line: String in JournalLog.quote_lines(entry, npc, respect):
				# TRANSLATORS: a line an NPC said, quoted under a 任务 page entry (as the ask wrote it).
				_label("    " + tr("{npc}说道：{line}").format({"npc": tr(npc.display_name), "line": line}), SharedGameplayLayout.MUTED_COLOR).name = "Quote"


## Every text the page shows, one per line (tests).
func shown_text() -> String:
	var lines: Array[String] = []
	for child: Node in get_children():
		lines.append((child as Label).text)
	return "\n".join(lines)


## `color` transparent keeps the theme's.
func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if color.a > 0.0:
		label.add_theme_color_override("font_color", color)
	add_child(label)
	return label
