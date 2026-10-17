class_name GivePanel
extends VBoxContainer
## 给予 in the interaction popup (give.c; DECISIONS「说话和交互」): what the player carries,
## one row each with 给 (a stack's amount beside it, as in the 背包), and what came of the
## gifts made here. SharedUiInventory fills it and gives, asking first as the 背包's 给 does.

## `amount` 0 hands over the whole object.
signal give_requested(item_instance_id: StringName, amount: int)

var _rows: VBoxContainer
var _empty: Label
var _answer: Label
## The rows shown ("id:amount:slot|…"): unchanged, nothing is rebuilt.
var _signature: String = ""
var _shown: Array[PlayerInventoryRowProjection] = []


func _ready() -> void:
	name = "GivePanel"
	add_theme_constant_override("separation", 10)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.add_theme_constant_override("separation", 6)
	add_child(_rows)
	_empty = Label.new()
	_empty.name = "Empty"
	_empty.text = "空无一物"
	add_child(_empty)
	_answer = Label.new()
	_answer.name = "Answer"
	_answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_answer.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(_answer)


## The carried things; rebuilt only when they changed.
func fill(rows: Array[PlayerInventoryRowProjection]) -> void:
	var parts: PackedStringArray = []
	for row: PlayerInventoryRowProjection in rows:
		parts.append("%s:%d:%d" % [row.item_instance_id, row.amount, row.equipment_slot])
	var signature: String = "|".join(parts)
	if signature == _signature:
		return
	_signature = signature
	_shown.clear()
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for source: PlayerInventoryRowProjection in rows:
		var row: PlayerInventoryRowProjection = source.duplicate_snapshot()
		_shown.append(row)
		_rows.add_child(_row(row))
	_empty.visible = _shown.is_empty()


## What came of the gifts made here (the player's line, the NPC's answer).
func show_answer(lines: Array[String]) -> void:
	_answer.text = "\n".join(lines)


func answer_text() -> String:
	return _answer.text


## The rows as shown (tests and the walk).
func labels() -> Array[String]:
	var shown: Array[String] = []
	for row: PlayerInventoryRowProjection in _shown:
		shown.append(PlayerInventoryPanel.row_label(row))
	return shown


## The 给 of the row shown as `label`, or null.
func give_button(label: String) -> Button:
	for index: int in _shown.size():
		if PlayerInventoryPanel.row_label(_shown[index]) == label and index < _rows.get_child_count():
			return _rows.get_child(index).get_node("Give") as Button
	return null


## A new list: the next fill() rebuilds it, the last gift's lines go.
func reset() -> void:
	_signature = "-"
	_answer.text = ""


func _row(row: PlayerInventoryRowProjection) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.name = "Row"
	line.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.name = "Item"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = PlayerInventoryPanel.row_label(row)
	label.tooltip_text = row.description.strip_edges()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(label)
	# A stack can be handed over in part (give 5 silver to ...).
	var content: ItemContentDefinition = GameContent.catalog().item(row.item_definition_id)
	var amount: SpinBox = null
	if content != null and content.is_stack and row.amount > 1:
		amount = SpinBox.new()
		amount.name = "Amount"
		amount.min_value = 1
		amount.max_value = row.amount
		amount.value = row.amount
		amount.rounded = true
		line.add_child(amount)
	var give := Button.new()
	give.name = "Give"
	give.text = "给"
	give.custom_minimum_size = Vector2(64, 36)
	give.pressed.connect(func() -> void:
		var count: int = 0 if amount == null or int(amount.value) >= row.amount else int(amount.value)
		give_requested.emit(row.item_instance_id, count))
	line.add_child(give)
	return line
