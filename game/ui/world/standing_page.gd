class_name StandingPage
extends VBoxContainer

## The menu's 声望 page (势力线第一批; DECISIONS「势力名册」): one card for each 势力 the player has
## had dealings with (FactionDefinition: a house none of whose lines holds is left out), its name,
## its layer (门派 / 交情 / 秘密) and where it is, then what that house thinks of the player — the
## sentences whose conditions hold now, in authored order. Sentences only, never a number
## (owner 2026-11-09).

# TRANSLATORS: the 声望 page while no house has anything to say of the player.
const NOTHING_YET: String = "江湖上还没有哪一家记得你。"

var _nothing: Label
var _cards: VBoxContainer


func _init() -> void:
	name = "StandingPage"
	add_theme_constant_override("separation", 12)
	_nothing = _label(self, NOTHING_YET, Color(0, 0, 0, 0))
	_nothing.name = "Nothing"
	_nothing.theme_type_variation = &"MutedLabel"
	# The sentence is a message of its own (the POT knows it): translated as the page shows.
	_nothing.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT
	_cards = VBoxContainer.new()
	_cards.name = "Cards"
	_cards.add_theme_constant_override("separation", 6)
	add_child(_cards)


## `test`: a condition -> whether it holds for the player now
## (WorldSessionController.quest_condition_test()); none, no cards.
func fill(test: Callable) -> void:
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for faction: FactionDefinition in GameContent.catalog().factions():
		var lines: Array[String] = faction.shown(test)
		if lines.is_empty():
			continue
		var rows: VBoxContainer = QuestPage.card(_cards).get_child(0) as VBoxContainer
		# TRANSLATORS: a house on the 声望 page: {name} its name, {layer} 门派 / 交情 / 秘密, {place} where it is.
		_label(rows, tr("{name} · {layer} · {place}").format({"name": tr(faction.name), "layer": tr(FactionDefinition.LAYER_TITLES[faction.layer]), "place": tr(faction.place)}), UiPalette.LANTERN).name = "Title"
		for line: String in lines:
			_label(rows, "· " + tr(line), Color(0, 0, 0, 0)).name = "Line"
	_nothing.visible = _cards.get_child_count() == 0


## Every text the page shows, one per line (tests).
func shown_text() -> String:
	var lines: Array[String] = []
	if _nothing.visible:
		lines.append(_nothing.text)
	for node: Node in _cards.find_children("*", "Label", true, false):
		var label := node as Label
		if not label.is_queued_for_deletion() and not label.text.is_empty():
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
