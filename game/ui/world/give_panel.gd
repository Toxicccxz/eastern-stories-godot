class_name GivePanel
extends VBoxContainer
## 给予 in the interaction popup (give.c; DECISIONS「说话和交互」): what the player carries,
## one row each to tick (a stack's amount beside it, as in the 背包); under the list what
## the gifts ask first (the 背包's questions, as warnings) and 确认给予, which can be pressed
## once something is ticked. SharedUiInventory fills it and makes the gifts.

## The ticked things changed (the warnings follow).
signal picks_changed
## 确认给予: `picks` as [item id, amount] pairs in the list's order; amount 0 is the whole.
signal confirmed(picks: Array)

var _rows: VBoxContainer
var _empty: Label
var _warning: Label
var confirm_button: Button
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
	_warning = Label.new()
	_warning.name = "Warning"
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_warning.theme_type_variation = &"WarningLabel"
	_warning.hide()
	add_child(_warning)
	confirm_button = Button.new()
	confirm_button.name = "Confirm"
	confirm_button.text = "确认给予"
	confirm_button.custom_minimum_size = Vector2(140, 44)
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_button.theme_type_variation = &"AccentButton"
	confirm_button.pressed.connect(func() -> void:
		if not picks().is_empty():
			confirmed.emit(picks()))
	add_child(confirm_button)
	_refresh_confirm()


## The carried things, none ticked; rebuilt only when they changed.
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
	_refresh_confirm()


## A new list: the next fill() rebuilds it with nothing ticked.
func reset() -> void:
	_signature = "-"
	show_warning("")


## The ticked things as [item id, amount] pairs, in the list's order.
func picks() -> Array:
	var picked: Array = []
	for index: int in mini(_shown.size(), _rows.get_child_count()):
		var line: Node = _rows.get_child(index)
		if not (line.get_node("Pick") as Button).button_pressed:
			continue
		var row: PlayerInventoryRowProjection = _shown[index]
		var amount: SpinBox = line.get_node_or_null("Amount") as SpinBox
		picked.append([row.item_instance_id, 0 if amount == null or int(amount.value) >= row.amount else int(amount.value)])
	return picked


## What the ticked gifts ask first, above 确认给予 ("" for nothing).
func show_warning(text: String) -> void:
	_warning.text = text
	_warning.visible = not text.is_empty()


func warning_text() -> String:
	return _warning.text if _warning.visible else ""


## The rows as shown (tests and the walk).
func labels() -> Array[String]:
	var shown: Array[String] = []
	for row: PlayerInventoryRowProjection in _shown:
		shown.append(PlayerInventoryPanel.row_label(row))
	return shown


## The tick (a toggle) of the row shown as `label`, or null.
func pick_box(label: String) -> Button:
	for index: int in _shown.size():
		if PlayerInventoryPanel.row_label(_shown[index]) == label and index < _rows.get_child_count():
			return _rows.get_child(index).get_node("Pick") as Button
	return null


## Keys and pad start on the first row.
func focus_default() -> void:
	if _rows.get_child_count() > 0:
		FocusNav.give(_rows.get_child(0).get_node("Pick") as Control)


static func _picked_style() -> StyleBox:
	return UiSkin.button(UiSkin.TAB_SELECTED)


func _refresh_confirm() -> void:
	if confirm_button != null:
		var none: bool = picks().is_empty()
		confirm_button.disabled = none
		confirm_button.focus_mode = Control.FOCUS_NONE if none else Control.FOCUS_ALL


func _row(row: PlayerInventoryRowProjection) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.name = "Row"
	line.add_theme_constant_override("separation", 8)
	# A row-wide toggle, marked in the accent colour with a tick while picked.
	var pick := Button.new()
	pick.name = "Pick"
	pick.toggle_mode = true
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	pick.custom_minimum_size.y = 38
	pick.tooltip_text = row.description.strip_edges()
	pick.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var label: String = PlayerInventoryPanel.row_label(row)
	pick.text = "○  " + label
	pick.toggled.connect(func(on: bool) -> void:
		pick.text = ("●  " if on else "○  ") + label
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
			if on:
				pick.add_theme_stylebox_override(state, _picked_style())
			else:
				pick.remove_theme_stylebox_override(state)
		_refresh_confirm()
		picks_changed.emit())
	line.add_child(pick)
	# A stack can be handed over in part (give 5 silver to ...).
	var content: ItemContentDefinition = GameContent.catalog().item(row.item_definition_id)
	if content != null and content.is_stack and row.amount > 1:
		var amount := SpinBox.new()
		amount.name = "Amount"
		amount.min_value = 1
		amount.max_value = row.amount
		amount.value = row.amount
		amount.rounded = true
		amount.value_changed.connect(func(_value: float) -> void:
			if pick.button_pressed:
				picks_changed.emit())
		line.add_child(amount)
	return line
