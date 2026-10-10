class_name BribePanel
extends VBoxContainer

## bribe <constable> with <amount> <money> (d/choyin/npc/yamen_po.c accept_bribery()): one row
## for each kind of money the player carries, how much of it, and 行贿; 算了 closes it. A
## refusal's line shows under the rows, so another sum can be tried.
signal bribed(item_id: StringName, amount: int)
signal cancelled

var question: Label
var rows_box: VBoxContainer
var empty_note: Label
var last_lines: Label
var cancel_button: Button


func _init() -> void:
	name = "Bribe"
	add_theme_constant_override("separation", 10)
	question = Label.new()
	question.name = "Question"
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(question)
	rows_box = VBoxContainer.new()
	rows_box.name = "Rows"
	rows_box.add_theme_constant_override("separation", 6)
	add_child(rows_box)
	empty_note = Label.new()
	empty_note.name = "NoMoney"
	# TRANSLATORS: the 行贿 panel when the player carries no money.
	empty_note.text = "你身上没有钱。"
	add_child(empty_note)
	# Not "Feedback": SharedGameplayUI copies a panel's Feedback label into the log, and these
	# lines are there already.
	last_lines = Label.new()
	last_lines.name = "LastLines"
	last_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(last_lines)
	cancel_button = Button.new()
	cancel_button.name = "Cancel"
	# TRANSLATORS: closes the 行贿 panel without bribing.
	cancel_button.text = "算了"
	cancel_button.custom_minimum_size = Vector2(120, 44)
	cancel_button.pressed.connect(func() -> void: cancelled.emit())
	add_child(cancel_button)


## The constable's name shown, and the money stacks: their item IDs, shown names and amounts.
func show_money(npc_name: String, ids: Array[StringName], names: Array[String], amounts: Array[int], lines: Array[String] = []) -> void:
	# TRANSLATORS: the 行贿 panel's question: {npc} the constable leading the player.
	question.text = tr("拿多少钱塞给{npc}？").format({"npc": npc_name})
	for child: Node in rows_box.get_children():
		rows_box.remove_child(child)
		child.queue_free()
	for index: int in range(ids.size()):
		var row := HBoxContainer.new()
		row.name = "Row"
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = names[index]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var amount := SpinBox.new()
		amount.name = "Amount"
		amount.min_value = 1
		amount.max_value = amounts[index]
		amount.value = amounts[index]
		amount.rounded = true
		row.add_child(amount)
		var button := Button.new()
		button.name = "Bribe"
		# TRANSLATORS: hands the chosen sum to the constable (accept_bribery()).
		button.text = "行贿"
		button.custom_minimum_size = Vector2(88, 44)
		var id: StringName = ids[index]
		button.pressed.connect(func() -> void: bribed.emit(id, int(amount.value)))
		row.add_child(button)
		rows_box.add_child(row)
	empty_note.visible = ids.is_empty()
	last_lines.text = "\n".join(lines)
	last_lines.visible = not last_lines.text.is_empty()


## The rows' money names as shown, in order.
func shown_money() -> Array[String]:
	var out: Array[String] = []
	for row: Node in rows_box.get_children():
		if not row.is_queued_for_deletion():
			out.append((row.get_child(0) as Label).text)
	return out
