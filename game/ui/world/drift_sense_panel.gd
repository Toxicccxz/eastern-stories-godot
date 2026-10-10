class_name DriftSensePanel
extends VBoxContainer

## 游识神通's question (drift_sense.c: 你要移动到哪一个人身边？): one button for each name
## the player may go to (the NPCs met: owner, DECISIONS 山烟寺 A Q3), and 中止施法. The
## lines the last answer printed (你无法感受到这个人的灵力 ....) show under the question.
signal chosen(name: String)
signal cancelled

var question: Label
var names_box: VBoxContainer
var empty_note: Label
var last_lines: Label
var cancel_button: Button


func _init() -> void:
	name = "DriftSense"
	add_theme_constant_override("separation", 10)
	question = Label.new()
	question.name = "Question"
	question.text = DriftSenseConjure.PROMPT
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(question)
	names_box = VBoxContainer.new()
	names_box.name = "Names"
	names_box.add_theme_constant_override("separation", 6)
	add_child(names_box)
	empty_note = Label.new()
	empty_note.name = "NoNames"
	# TRANSLATORS: 游识神通's question when the player has met nobody it could go to yet.
	empty_note.text = "你还没有见过什么人。"
	empty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(empty_note)
	# Not "Feedback": SharedGameplayUI copies a panel's Feedback label into the log, and
	# these lines are there already.
	last_lines = Label.new()
	last_lines.name = "LastLines"
	last_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(last_lines)
	cancel_button = Button.new()
	cancel_button.name = "Cancel"
	# TRANSLATORS: drift_sense.c: an empty answer to its question stops the conjuring (中止施法。).
	cancel_button.text = "中止施法"
	cancel_button.custom_minimum_size = Vector2(120, 44)
	cancel_button.pressed.connect(func() -> void: cancelled.emit())
	add_child(cancel_button)


## The names (authored, shown translated) and the lines of the last answer.
func show_names(names: Array[String], lines: Array[ColoredLine] = []) -> void:
	for child: Node in names_box.get_children():
		names_box.remove_child(child)
		child.queue_free()
	for npc_name: String in names:
		var button := Button.new()
		button.name = "Name"
		button.text = npc_name
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(func() -> void: chosen.emit(npc_name))
		names_box.add_child(button)
	empty_note.visible = names.is_empty()
	last_lines.text = "\n".join(ColoredLine.texts(lines))
	last_lines.visible = not last_lines.text.is_empty()


## The buttons' names as shown, in order.
func shown_names() -> Array[String]:
	var out: Array[String] = []
	for child: Node in names_box.get_children():
		if child is Button and not child.is_queued_for_deletion():
			out.append((child as Button).text)
	return out
