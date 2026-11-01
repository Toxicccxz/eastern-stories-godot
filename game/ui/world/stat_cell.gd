class_name StatCell
extends Label
## One number on a page (现代基线 C; DECISIONS「数值用到才出现」): the mouse rests on it for its
## line, the keys and the pad stop on it (FocusTip shows the same line).

const FOCUS_FRAME: Color = Color("75d9ee") # The cyan of input focus, as on the battle cards.


func _init(node_name: String) -> void:
	name = node_name
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	# Filled in the shown language (tr()).
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func show_stat(text_now: String, hint: String) -> void:
	text = text_now
	tooltip_text = hint
	# The menu's layout wraps a flow's labels at the width their text had: a number that
	# grew since then stays on one line.
	if get_parent() is FlowContainer:
		autowrap_mode = TextServer.AUTOWRAP_OFF


## The number's name and its line from the table, in the shown language.
static func stat_name(stat_id: StringName) -> String:
	var stat: StatDisplayDefinition = GameContent.catalog().stats_display().stat(stat_id)
	return "" if stat == null else TranslationServer.translate(stat.display_name)


static func stat_hint(stat_id: StringName) -> String:
	var stat: StatDisplayDefinition = GameContent.catalog().stats_display().stat(stat_id)
	return "" if stat == null else TranslationServer.translate(stat.hint)


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()


func _draw() -> void:
	if has_focus():
		draw_rect(Rect2(Vector2.ZERO, size), FOCUS_FRAME, false, 1.0)
