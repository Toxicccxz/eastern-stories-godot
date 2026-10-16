class_name WorldSpeechBubbles
extends Control

## What NPCs say, over their heads (DECISIONS「手感」): a chat line, a greeting, a shout, a
## stage of a story, for the feel's speech_bubble_ms (longer for a long line). The log
## keeps every line as before; a bubble only shows who says it. A new line from the same
## NPC replaces its bubble. Hidden while a panel, the menu or a fight has the screen; its
## time runs on meanwhile.

const MAX_WIDTH: float = 220.0
## The bubble's bottom edge above the body's middle (over its name).
const LIFT: float = 54.0
const TEXT_COLOR: Color = Color(0.12, 0.11, 0.1)
const ALERT_TEXT_COLOR: Color = Color(0.78, 0.1, 0.08)
const FILL: Color = Color(0.97, 0.95, 0.88, 0.94)
## A said line opens with who says it and how ("强盗喝道：", "店小二说道："): the bubble is over
## their head already, so it starts after that colon when it comes this soon and follows 道.
const SPEECH_MARK: String = "道："
const SPEECH_MARK_REACH: int = 10

var _ui: SharedGameplayUI
## character id -> [PanelContainer, seconds left]
var _bubbles: Dictionary[StringName, Array] = {}


func configure(ui: SharedGameplayUI) -> void:
	_ui = ui


func _ready() -> void:
	name = "WorldSpeechBubbles"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `speaker` (an NPC on the active map) says `lines` (as the log shows them); `alert`: in
## the alert red (a 喝令).
func say(speaker: NpcRuntimeState, lines: Array[String], alert: bool = false) -> void:
	if speaker == null or lines.is_empty():
		return
	var shown: Array[String] = []
	for line: String in lines:
		var text: String = bubble_text(line)
		if not text.is_empty():
			shown.append(text)
	var text: String = "\n".join(shown)
	var seconds: float = GameContent.catalog().pacing().feel.bubble_seconds(text)
	if seconds <= 0.0 or text.is_empty():
		return
	forget(speaker.character_id)
	var bubble: PanelContainer = PanelContainer.new()
	bubble.name = "Bubble"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = FILL
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6.0)
	bubble.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", ALERT_TEXT_COLOR if alert else TEXT_COLOR)
	var font: Font = label.get_theme_font("font")
	var wide: float = 0.0 if font == null else font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	label.custom_minimum_size.x = minf(MAX_WIDTH, wide + 2.0)
	bubble.add_child(label)
	bubble.visible = false
	add_child(bubble)
	_bubbles[speaker.character_id] = [bubble, seconds]


## The bubble over `character_id` now ("" when none).
func text_of(character_id: StringName) -> String:
	if not _bubbles.has(character_id):
		return ""
	return ((_bubbles[character_id][0] as PanelContainer).get_child(0) as Label).text


func forget(character_id: StringName) -> void:
	if _bubbles.has(character_id):
		(_bubbles[character_id][0] as Node).queue_free()
		_bubbles.erase(character_id)


## What a bubble says for `line`: what is said, without who says it.
static func bubble_text(line: String) -> String:
	var text: String = line.strip_edges()
	var mark: int = text.find(SPEECH_MARK)
	if mark >= 0 and mark <= SPEECH_MARK_REACH:
		text = text.substr(mark + SPEECH_MARK.length()).strip_edges()
	return text


func _process(delta: float) -> void:
	if _bubbles.is_empty():
		return
	var map: WorldMapController = _shown_map()
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	for character_id: StringName in _bubbles.keys():
		var entry: Array = _bubbles[character_id]
		entry[1] = float(entry[1]) - delta
		var bubble: PanelContainer = entry[0]
		var body: WorldCharacterBody2D = null if map == null else map.npcs.runtime_body_for_character(character_id)
		if float(entry[1]) <= 0.0 or (map != null and body == null):
			forget(character_id)
			continue
		bubble.visible = map != null and body.is_visible_in_tree()
		if bubble.visible:
			bubble.reset_size()
			var head: Vector2 = canvas * (body.global_position + Vector2(0.0, -LIFT))
			bubble.position = (head - Vector2(bubble.size.x / 2.0, bubble.size.y)).round()


func _shown_map() -> WorldMapController:
	if _ui == null or not _ui.visible or _ui.menu.is_presented() or _ui.panel_open():
		return null
	var session: WorldSessionController = _ui.session()
	return null if session == null else session.active_map() as WorldMapController
