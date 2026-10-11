class_name SharedUiAskPanel
extends RefCounted
## The 打听 panel (ask.c): the topics, the answer, 接话 beside the NPC and its own
## commands (跪下受戒). Code moved from SharedGameplayUI as it was; the HUD is `_ui`.

# TRANSLATORS: asked before 跪下受戒 (daemon/class/bonze/master.c do_kneel()): {npc} the master, {prefixes} the characters a 法名 begins with (空明圆净虚悟方渡慧法), {first} the first character of the player's name, {example} one 法名 it could make.
const ORDINATION_WARNING: String = "跪下受戒就是剃度出家：{npc}会剃去你的头发，你从此是僧人。\n你的名字会改成法名：「{prefixes}」中随机一字，加上你名字的第一个字「{first}」（例如「{example}」），原来的名字从此不再使用。\n确定要跪下受戒吗？"

var _ui: SharedGameplayUI
var _ask_panel: VBoxContainer
var _ask_topics: HFlowContainer
var _ask_relay: HFlowContainer
## The NPC's own commands the player can use beside it now (跪下受戒).
var _ask_verbs: HFlowContainer
var _ask_answer: Label

# The HUD's authorities, read as SharedGameplayUI reads them.
var _session: WorldSessionController:
	get: return _ui._session
var _presentation_layout: SharedGameplayLayout:
	get: return _ui._presentation_layout
var _player: WorldPlayerRuntimeState:
	get: return _ui._player


func _init(ui: SharedGameplayUI) -> void:
	_ui = ui


## ask.c without a topic: "你可以打听这些事情：" and the list; each topic asks, and
## the answer shows under the list (and in the log).
func open_ask() -> void:
	var map := _session.active_map() as WorldMapController
	if map == null or not _session.portable_inventory_available() or not map.can_ask_selected():
		return
	if _ask_panel == null:
		_ask_panel = VBoxContainer.new()
		_ask_panel.name = "AskPanel"
		_ask_panel.add_theme_constant_override("separation", 10)
		var heading := Label.new()
		heading.text = "你可以打听这些事情："
		_ask_panel.add_child(heading)
		_ask_topics = HFlowContainer.new()
		_ask_topics.name = "Topics"
		_ask_topics.add_theme_constant_override("h_separation", 8)
		_ask_topics.add_theme_constant_override("v_separation", 8)
		_ask_panel.add_child(_ask_topics)
		# say.c beside the NPC for what its relay_say() answers (owner: a 接话 button).
		_ask_relay = HFlowContainer.new()
		_ask_relay.name = "Relay"
		_ask_relay.add_theme_constant_override("h_separation", 8)
		_ask_relay.add_theme_constant_override("v_separation", 8)
		_ask_panel.add_child(_ask_relay)
		_ask_verbs = HFlowContainer.new()
		_ask_verbs.name = "Verbs"
		_ask_verbs.add_theme_constant_override("h_separation", 8)
		_ask_verbs.add_theme_constant_override("v_separation", 8)
		_ask_panel.add_child(_ask_verbs)
		_ask_answer = Label.new()
		_ask_answer.name = "Answer"
		_ask_answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_ask_panel.add_child(_ask_answer)
		_ask_panel.hide()
		_presentation_layout.holding.add_child(_ask_panel)
	for child: Node in _ask_topics.get_children():
		child.queue_free()
	for topic: String in map.ask_topics_selected():
		var button := Button.new()
		button.name = "Topic"
		button.text = tr(topic)
		button.custom_minimum_size = Vector2(80, 40)
		button.pressed.connect(_ask_topic.bind(topic))
		_ask_topics.add_child(button)
	for child: Node in _ask_relay.get_children():
		child.queue_free()
	for phrase: String in map.relay_phrases_selected():
		var say := Button.new()
		say.name = "Relay"
		# TRANSLATORS: say a line beside the NPC that it answers ({line}: 必有妖孽).
		say.text = tr("接话：{line}").format({"line": tr(phrase)})
		say.custom_minimum_size = Vector2(80, 40)
		say.pressed.connect(_say_beside.bind(phrase))
		_ask_relay.add_child(say)
	_ask_relay.visible = not map.relay_phrases_selected().is_empty()
	_refresh_ask_verbs(map)
	_ask_answer.text = ""
	_ui.message_log.open_panel_with_lines(tr("打听 · %s") % tr(_ui.selection.selected_target.definition().display_name), _ask_panel, _ui.selection.selected_npc_askable)
	_presentation_layout.refresh_rows()


func ask_topics_shown() -> Array[String]:
	var result: Array[String] = []
	if _ask_topics != null and _presentation_layout._content == _ask_panel:
		for child: Node in _ask_topics.get_children():
			if not child.is_queued_for_deletion():
				result.append((child as Button).text)
	return result


func ask_answer_text() -> String:
	return "" if _ask_answer == null else _ask_answer.text


func _ask_topic(topic: String) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null:
		_ask_answer.text = "\n".join(map.ask_selected(topic))
		_refresh_ask_verbs(map)
		_presentation_layout.refresh_rows()


## The kneel command of a master whose 剃度 the player asked for (daemon/class/bonze/master.c).
func _refresh_ask_verbs(map: WorldMapController) -> void:
	for child: Node in _ask_verbs.get_children():
		child.queue_free()
	if map.ordination_selected() != null:
		var kneel := Button.new()
		kneel.name = "Kneel"
		kneel.text = tr(NpcOrdination.LABEL)
		kneel.custom_minimum_size = Vector2(80, 40)
		kneel.pressed.connect(_kneel)
		_ask_verbs.add_child(kneel)
	_ask_verbs.visible = map.ordination_selected() != null


## The NPC commands the open 打听 panel offers (as shown).
func ask_verbs_shown() -> Array[String]:
	var result: Array[String] = []
	if _ask_verbs != null and _presentation_layout._content == _ask_panel:
		for child: Node in _ask_verbs.get_children():
			if not child.is_queued_for_deletion():
				result.append((child as Button).text)
	return result


## kneel (do_kneel()), asked first: the player's name becomes a 法名 for good (owner).
## 取消 goes back to the 打听 panel.
func _kneel() -> void:
	var map := _session.active_map() as WorldMapController
	var ordination: NpcOrdination = null if map == null else map.ordination_selected()
	if ordination == null:
		# The master was knocked out (or the like) while the panel stood open: the button goes.
		if map != null and _presentation_layout._content == _ask_panel:
			_refresh_ask_verbs(map)
		return
	var first: String = _player.facts.display_name.substr(0, 1)
	var text: String = tr(ORDINATION_WARNING).format({
		"npc": tr(_ui.selection.selected_target.definition().display_name), "prefixes": "".join(ordination.prefixes),
		"first": first, "example": ordination.prefixes[0] + first,
	})
	var kneel: Callable = func() -> void:
		map.kneel_selected()
	_ui.questions.ask_first(text, "确定受戒", kneel, func() -> bool: return map.ordination_selected() != null, open_ask)


func _say_beside(phrase: String) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null:
		_ask_answer.text = "\n".join(map.say_beside_selected(phrase))


## The 接话 lines the open 打听 panel offers (as shown).
func relay_buttons_shown() -> Array[String]:
	var result: Array[String] = []
	if _ask_relay != null and _presentation_layout._content == _ask_panel:
		for child: Node in _ask_relay.get_children():
			if not child.is_queued_for_deletion():
				result.append((child as Button).text)
	return result
