class_name SharedUiMessageLog
extends RefCounted
## The HUD's messages: the log (消息) in ES2's colours, the toasts and when they are held
## back, lines kept for after a fight, a room's text on arrival, and a panel's Feedback
## copied into the log. Code moved from SharedGameplayUI as it was; the HUD is `_ui`.


var _ui: SharedGameplayUI
var _log_lines: Array[String] = []
## The ES2 colour of each log line (ColoredLine; &"" plain), e.g. kill_ob()'s
## 看起来X想杀死你！ in HIR bright red.
var _log_colors: Array[StringName] = []
## Lines the world printed while a fight ran that read best after its result
## (killer_reward()'s quest reward): shown with show_combat_result().
var _after_fight_lines: Array[ColoredLine] = []
## Zone whose description was last written to the log; entering another zone
## writes the new one, as ES2 printed a room on arrival.
var _described_zone_id: StringName = &""
var business_feedback: String = ""
## The open panel shows its own lines (an NPC's panel, 打听): no toasts while it is open.
var _panel_shows_lines: bool = false

# The HUD's authorities, read as SharedGameplayUI reads them.
var _session: WorldSessionController:
	get: return _ui._session
var _presentation_layout: SharedGameplayLayout:
	get: return _ui._presentation_layout


func _init(ui: SharedGameplayUI) -> void:
	_ui = ui


func show_combat_result(text: String) -> void:
	_append(_colored([text]), false)
	# The result's first line as a toast, not a modal input blocker on compact HUDs.
	_presentation_layout.toasts.push(text.get_slice("\n", 0))
	_ui.world_title.tooltip_text = text
	if not _after_fight_lines.is_empty():
		var lines: Array[ColoredLine] = _after_fight_lines.duplicate()
		_after_fight_lines.clear()
		append_colored_lines(lines)


## Lines for the log once the running fight's result is shown (at once outside a fight).
func append_after_fight(lines: Array[ColoredLine]) -> void:
	if _session != null and _session.is_initialized() and _session.combat_encounter_coordinator().has_active_encounter():
		_after_fight_lines.append_array(lines)
	else:
		append_colored_lines(lines)


## `alert`: the lines are warnings ES2 prints in bright red (HIR).
func append_log_lines(lines: Array[String], alert: bool = false) -> void:
	append_colored_lines(_colored(lines, alert))


static func _colored(lines: Array[String], alert: bool = false) -> Array[ColoredLine]:
	var colored: Array[ColoredLine] = []
	for line: String in lines:
		colored.append(ColoredLine.new(line, ColoredLine.HIR if alert else ColoredLine.PLAIN))
	return colored


## Lines in the colours ES2 prints them in: in 消息, and as toasts while no panel or
## fight shows its own lines.
func append_colored_lines(lines: Array[ColoredLine]) -> void:
	_append(lines, true)


func _append(lines: Array[ColoredLine], toast: bool) -> void:
	var stack: MessageToasts = _presentation_layout.toasts
	stack.set_suppressed(_toasts_suppressed())
	for line: ColoredLine in lines:
		if not line.text.is_empty():
			_log_lines.append(line.text)
			_log_colors.append(line.color)
			if toast:
				# A message of several lines (god.c's 朱鸿雪沉思了一会儿，说道： / 请在…) is shown whole.
				stack.push(line.text.replace("\n", " "), SharedGameplayUI.ES2_COLORS.get(line.color, MessageToasts.PLAIN_TEXT), SharedGameplayUI.ES2_COLORS.has(line.color))
	while _log_lines.size() > SharedGameplayUI.MAX_LOG_LINES:
		_log_lines.pop_front()
		_log_colors.pop_front()
	var shown: PackedStringArray = []
	for index: int in _log_lines.size():
		var plain: String = _log_lines[index].replace("[", "[lb]")
		var color: StringName = _log_colors[index]
		shown.append("[color=#%s]%s[/color]" % [SharedGameplayUI.ES2_COLORS[color].to_html(false), plain] if SharedGameplayUI.ES2_COLORS.has(color) else plain)
	_ui.combat_log.text = "\n".join(shown)


## The bottom left's toasts (MessageToasts).
func toasts() -> MessageToasts:
	return _presentation_layout.toasts


func refresh_toasts() -> void:
	if not _presentation_layout.frame.visible:
		_panel_shows_lines = false
	_presentation_layout.toasts.set_suppressed(_toasts_suppressed())


## SharedGameplayLayout opened a panel: one that shows its own lines says so after.
func panel_opened() -> void:
	_panel_shows_lines = false
	refresh_toasts()


## A panel that shows its own lines (打听, a teacher, a shop: dialogue stays in its
## panel) or a fight shows them then. Other panels (背包, 拾取, 角色) let toasts through.
func _toasts_suppressed() -> bool:
	return (_presentation_layout.frame.visible and _panel_shows_lines) or (
		_session != null and _session.is_initialized() and _session.combat_encounter_coordinator().has_active_encounter()
	)


func log_lines() -> Array[String]:
	return _log_lines.duplicate()


## ES2 room text keeps the MUD's hard line breaks; the UI wraps it itself.
static func room_prose(text: String) -> String:
	return text.strip_edges().replace("\n", "")


## The room's text now, if the player came into it since it was last described: what
## happens there on arrival (the player's berserk) reads after it, as ES2's move()
## looks before init()'s call_out()s.
func describe_arrival() -> void:
	describe_new_zone()


## The player came into the room they left (a 迷阵 exit back to itself): ES2 shows
## the room again, as on any move.
func describe_again() -> void:
	_described_zone_id = &""
	describe_new_zone()


func describe_new_zone() -> void:
	var zone: ZoneDefinition = _ui.current_zone()
	if zone == null or zone.zone_id == _described_zone_id:
		return
	var previous: ZoneDefinition = GameContent.catalog().zone(_described_zone_id)
	_described_zone_id = zone.zone_id
	# Owner: neighbouring rooms of one name (黄土小径, 雪亭镇街道) are one place; walking on
	# into the next tells nothing new (观察 still reads its text). A `distinct` room (the
	# hall of 老松寨, cave5) has its own say.
	if (previous != null and previous.map_id == zone.map_id and previous.display_name == zone.display_name
			and not previous.distinct and not zone.distinct and GameContent.catalog().zones_adjacent(previous.zone_id, zone.zone_id)):
		return
	# TRANSLATORS: a room's title and its description, as the log shows them on arrival.
	append_log_lines([tr("【{title}】{description}").format({"title": tr(zone.display_name), "description": room_prose(tr(zone.description))})])


## Opens a panel that shows its own lines: toasts stay off while it is open.
func open_panel_with_lines(title: String, content: Control, validate: Callable = Callable()) -> void:
	_presentation_layout.open_panel(title, content, validate)
	_panel_shows_lines = _presentation_layout._content == content
	refresh_toasts()


func open_messages() -> void:
	if _session.portable_inventory_available():
		_presentation_layout.open_panel("消息", _presentation_layout.messages)


func collect_feedback() -> void:
	if not _presentation_layout.frame.visible: return
	var lines: Array[String] = []
	for node: Node in _presentation_layout.mount.find_children("*", "Label", true, false):
		var label := node as Label
		# A fixed feedback holds its source text and translates itself: the log takes what it shows.
		if label.name == "Feedback" and not label.text.is_empty(): lines.append(label.atr(label.text) if label.can_auto_translate() else label.text)
	var text := "\n".join(lines)
	if not text.is_empty() and text != business_feedback:
		business_feedback = text
		append_log_lines(lines)
