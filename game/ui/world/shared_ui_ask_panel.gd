class_name SharedUiAskPanel
extends RefCounted
## The 打听 panel (ask.c): the topics, the answer, 接话 beside the NPC and its own
## commands (跪下受戒). Code moved from SharedGameplayUI as it was; the HUD is `_ui`.

# TRANSLATORS: asked before 跪下受戒 (daemon/class/bonze/master.c do_kneel()): {npc} the master, {prefixes} the characters a 法名 begins with (空明圆净虚悟方渡慧法), {first} the first character of the player's name, {example} one 法名 it could make.
const ORDINATION_WARNING: String = "跪下受戒就是剃度出家：{npc}会剃去你的头发，你从此是僧人。\n你的名字会改成法名：「{prefixes}」中随机一字，加上你名字的第一个字「{first}」（例如「{example}」），原来的名字从此不再使用。\n确定要跪下受戒吗？"

var _ui: SharedGameplayUI
var _ask_panel: VBoxContainer
var _ask_heading: Label
## Out of the dialogue box (the frame has its own 关闭).
var _ask_leave: Button
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
		_ask_heading = Label.new()
		_ask_heading.text = "你可以打听这些事情："
		_ask_panel.add_child(_ask_heading)
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
		_ask_leave = Button.new()
		_ask_leave.name = "Leave"
		# TRANSLATORS: leaves the conversation in the dialogue box.
		_ask_leave.text = "告辞"
		_ask_leave.theme_type_variation = &"ChipButton"
		_ask_leave.custom_minimum_size = Vector2(80, 40)
		_ask_leave.size_flags_horizontal = Control.SIZE_SHRINK_END
		_ask_leave.pressed.connect(func() -> void: _ui.dialogue_box.close())
		InputGlyphs.decorate(_ask_leave, &"ui_cancel")
		_ask_panel.add_child(_ask_leave)
		_ask_panel.hide()
		_presentation_layout.holding.add_child(_ask_panel)
	for child: Node in _ask_topics.get_children():
		child.queue_free()
	for topic: String in map.ask_topics_selected():
		var button := Button.new()
		button.name = "Topic"
		button.text = tr(topic)
		button.theme_type_variation = &"ChipButton"
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
		say.theme_type_variation = &"ChipButton"
		say.custom_minimum_size = Vector2(80, 40)
		say.pressed.connect(_say_beside.bind(phrase))
		_ask_relay.add_child(say)
	_ask_relay.visible = not map.relay_phrases_selected().is_empty()
	_refresh_ask_verbs(map)
	_ask_answer.text = ""
	var boxed: bool = GameContent.catalog().pacing().feel.shows_dialogue_box()
	_ask_heading.visible = not boxed
	_ask_answer.visible = not boxed
	_ask_leave.visible = boxed
	if boxed:
		# Out of the popup: the box is the conversation (DECISIONS「对话框」).
		_presentation_layout.close_frame(false)
		_ui.dialogue_box.host(tr(_ui.selection.selected_target.definition().display_name), _ask_panel, _ui.selection.selected_target)
		# The topics' prompt is the player's turn, not the NPC's words.
		_ui.dialogue_box.answer_as_written([tr("你可以打听这些事情：")])
		FocusNav.give(FocusNav.first_focusable(_ask_panel, true))
		return
	_ui.message_log.open_panel_with_lines(tr("打听 · %s") % tr(_ui.selection.selected_target.definition().display_name), _ask_panel, _ui.selection.selected_npc_askable)
	_presentation_layout.refresh_rows()


## 战斗拍数 D: 打听 opened straight on `topic` (请教打法 on a school's guide): the conversation
## as open_ask() makes it, the topic asked at once.
func open_ask_topic(topic: String) -> void:
	open_ask()
	var map := _session.active_map() as WorldMapController
	if _shown() and map != null and map.ask_topics_selected().has(topic):
		_ask_topic(topic)


## The 打听 panel shows (in the dialogue box, or the shared frame).
func _shown() -> bool:
	return _ask_panel != null and (_presentation_layout._content == _ask_panel or _ui.dialogue_box.hosted() == _ask_panel)


func ask_topics_shown() -> Array[String]:
	var result: Array[String] = []
	if _ask_topics != null and _shown():
		for child: Node in _ask_topics.get_children():
			if not child.is_queued_for_deletion():
				result.append((child as Button).text)
	return result


func ask_answer_text() -> String:
	return "" if _ask_answer == null else _ask_answer.text


func _ask_topic(topic: String) -> void:
	var map := _session.active_map() as WorldMapController
	# The first press while an answer types out finishes it, as on any page.
	if map == null or _ui.dialogue_box.finish_typing():
		return
	# An ask that turns the NPC on the player (guard.c's 刘老三) is confirmed first
	# (DECISIONS「Ask before an important or deadly choice」).
	var npc: NpcRuntimeState = map.selected_npc()
	var confirm: String = "" if npc == null else npc.definition().talk().ask_confirm(topic)
	# 番坊 D: a question with conditions (confirm_marks / confirm_lacks) is asked only of one it is for.
	if not confirm.is_empty() and map.player_runtime() != null and not npc.definition().talk().confirm_applies(topic, map.player_runtime().state.marks):
		confirm = ""
	if not confirm.is_empty():
		# TRANSLATORS: the confirm's choice for asking an NPC a topic it may turn on the player for.
		_ui.questions.ask_first(tr(confirm), tr("问"), _ask_now.bind(topic), map.can_ask_selected, Callable(), tr(topic))
		return
	_ask_now(topic)


func _ask_now(topic: String) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null:
		var waiting: Dictionary[String, float] = map.npc_life.npc_ambience().snapshot()
		var lines: Array[String] = map.ask_selected(topic)
		_ask_answer.text = "\n".join(lines)
		_refresh_ask_verbs(map)
		_presentation_layout.refresh_rows()
		_answered(map, waiting, lines)


## The kneel command of a master whose 剃度 the player asked for (daemon/class/bonze/master.c).
func _refresh_ask_verbs(map: WorldMapController) -> void:
	for child: Node in _ask_verbs.get_children():
		child.queue_free()
	if map.ordination_selected() != null:
		var kneel := Button.new()
		kneel.name = "Kneel"
		kneel.text = tr(NpcOrdination.LABEL)
		kneel.theme_type_variation = &"PrimaryButton"
		kneel.custom_minimum_size = Vector2(80, 40)
		kneel.pressed.connect(_kneel)
		_ask_verbs.add_child(kneel)
	_ask_verbs.visible = map.ordination_selected() != null


## The NPC commands the open 打听 panel offers (as shown).
func ask_verbs_shown() -> Array[String]:
	var result: Array[String] = []
	if _ask_verbs != null and _shown():
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
		if map != null and _shown():
			_refresh_ask_verbs(map)
		return
	var first: String = _player.facts.display_name.substr(0, 1)
	var text: String = tr(ORDINATION_WARNING).format({
		"npc": tr(_ui.selection.selected_target.definition().display_name), "prefixes": "".join(ordination.prefixes),
		"first": first, "example": ordination.prefixes[0] + first,
	})
	var kneel: Callable = func() -> void:
		_ui.dialogue_box.close()
		map.kneel_selected()
	_ui.questions.ask_first(text, "确定受戒", kneel, func() -> bool: return map.ordination_selected() != null, open_ask)


func _say_beside(phrase: String) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null and not _ui.dialogue_box.finish_typing():
		var waiting: Dictionary[String, float] = map.npc_life.npc_ambience().snapshot()
		var lines: Array[String] = map.say_beside_selected(phrase)
		_ask_answer.text = "\n".join(lines)
		_answered(map, waiting, lines)


## The answer: in the dialogue box over the topics, or under them in the frame. World time
## stands still in both: an answer that starts something an NPC goes on with later (大队长's
## story told line by line, a call_out of its own) lets it run (owner Q2, 2026-10-17). The box
## reads the answer out and closes; the popup closes and the answer shows as toasts.
func _answered(map: WorldMapController, waiting: Dictionary[String, float], lines: Array[String]) -> void:
	var started: bool = map.npc_life.npc_ambience().started_since(waiting)
	if _ui.dialogue_box.hosted() == _ask_panel:
		# ask.c's 你向…打听 and say.c's 你说道 are what the player just pressed: the box starts
		# at the answer. With none, that line is all there is, as it stands.
		var answer: Array[String] = lines.slice(1)
		if answer.is_empty():
			_ui.dialogue_box.answer_as_written(lines)
		# Someone who has left (陈显祖's 走吧) is not asked on: the farewell is read and the box goes.
		elif started or not _ui.selection.selected_npc_askable():
			var asked: NpcRuntimeState = map.selected_npc()
			_ui.dialogue_box.tell(_ui.dialogue_box.speaker(), answer, &"" if asked == null else asked.character_id)
		else:
			_ui.dialogue_box.answer(answer)
		return
	if not _ui.interaction_open() or not started:
		return
	_presentation_layout.close_frame()
	for line: String in lines:
		_presentation_layout.toasts.push(line.replace("\n", " "))


## The 接话 lines the open 打听 panel offers (as shown).
func relay_buttons_shown() -> Array[String]:
	var result: Array[String] = []
	if _ask_relay != null and _shown():
		for child: Node in _ask_relay.get_children():
			if not child.is_queued_for_deletion():
				result.append((child as Button).text)
	return result
