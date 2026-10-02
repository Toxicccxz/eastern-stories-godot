class_name PlayerInventoryPanel
extends PanelContainer

signal inspect_requested(item_instance_id: StringName)
signal wield_requested(item_instance_id: StringName)
signal unwield_requested(item_instance_id: StringName)
signal wear_requested(item_instance_id: StringName)
signal remove_requested(item_instance_id: StringName)
## give.c, drop.c and put.c; `amount` 0 hands over the whole object.
signal give_requested(item_instance_id: StringName, amount: int)
signal drop_requested(item_instance_id: StringName, amount: int)
signal put_requested(item_instance_id: StringName, amount: int)

@onready var row_container: VBoxContainer = %PlayerInventoryRows
@onready var empty_label: Label = %PlayerInventoryEmptyLabel
@onready var inspect_text: RichTextLabel = %PlayerInventoryInspectText

var _rows: Array[PlayerInventoryRowProjection] = []
## Who can be given things (the selected NPC here) and the container in reach;
## empty when there is none.
var _give_target: String = ""
var _container: String = ""


func set_handling_targets(give_target: String, container: String) -> void:
	_give_target = give_target
	_container = container


func show_inventory(rows: Array[PlayerInventoryRowProjection]) -> void:
	_replace_rows(rows)
	inspect_text.text = ""
	inspect_text.hide()
	visible = true


func close_inventory() -> void:
	visible = false
	_replace_rows([])
	inspect_text.text = ""
	inspect_text.hide()


func is_open() -> bool:
	return visible


func visible_rows() -> Array[PlayerInventoryRowProjection]:
	var result: Array[PlayerInventoryRowProjection] = []
	for row: PlayerInventoryRowProjection in _rows:
		result.append(row.duplicate_snapshot())
	return result


func show_inspection(row: PlayerInventoryRowProjection) -> void:
	if row == null:
		inspect_text.text = ""
		inspect_text.hide()
		return
	var lines: Array[String] = [
		row.display_name,
		row.description.strip_edges(),
		"Category: %s" % String(row.category),
		"Equipped: %s" % row.equipment_label(),
	]
	if row.category == ItemContentDefinition.CATEGORY_WEAPON:
		lines.append("Skill: %s" % String(row.weapon_skill_type))
		lines.append("Damage: %d" % row.weapon_damage)
	elif row.category == ItemContentDefinition.CATEGORY_CURRENCY:
		lines.append("Amount: %d" % row.amount)
		lines.append("Value: %d" % row.total_value)
	elif row.category == ItemContentDefinition.CATEGORY_ARMOR:
		lines.append("Armor slot: %s" % String(row.armor_type))
		lines.append("Armor: %+d" % row.armor_modifiers.armor)
		lines.append("Dodge: %+d" % row.armor_modifiers.dodge)
	inspect_text.text = "\n".join(lines)
	inspect_text.show()


func inspection_display() -> String:
	return inspect_text.text


func _replace_rows(rows: Array[PlayerInventoryRowProjection]) -> void:
	_rows.clear()
	for child: Node in row_container.get_children():
		row_container.remove_child(child)
		child.queue_free()
	for source: PlayerInventoryRowProjection in rows:
		if source == null:
			continue
		var row: PlayerInventoryRowProjection = source.duplicate_snapshot()
		_rows.append(row)
		row_container.add_child(_build_row(row))
	empty_label.visible = _rows.is_empty()


func _build_row(row: PlayerInventoryRowProjection) -> BoxContainer:
	var container: BoxContainer = BoxContainer.new()
	container.name = "InventoryRow"
	container.add_theme_constant_override("separation", 8)
	var label: Label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = _row_label(row)
	label.tooltip_text = row.description.strip_edges()
	container.add_child(label)
	var inspect_button: Button = Button.new()
	inspect_button.text = "Inspect"
	inspect_button.pressed.connect(_on_inspect_pressed.bind(row.item_instance_id))
	container.add_child(inspect_button)
	if row.can_wield:
		var wield_button: Button = Button.new()
		wield_button.text = "Wield"
		wield_button.pressed.connect(_on_wield_pressed.bind(row.item_instance_id))
		container.add_child(wield_button)
	elif row.can_unwield:
		var unwield_button: Button = Button.new()
		unwield_button.text = "Unwield"
		unwield_button.pressed.connect(_on_unwield_pressed.bind(row.item_instance_id))
		container.add_child(unwield_button)
	elif row.can_wear:
		var wear_button: Button = Button.new()
		wear_button.text = "Wear"
		wear_button.pressed.connect(_on_wear_pressed.bind(row.item_instance_id))
		container.add_child(wear_button)
	elif row.can_remove:
		var remove_button: Button = Button.new()
		remove_button.text = "Remove"
		remove_button.pressed.connect(_on_remove_pressed.bind(row.item_instance_id))
		container.add_child(remove_button)
	# A stack can be handed over in part (give 5 silver to ...).
	var amount: SpinBox = null
	if row.category == ItemContentDefinition.CATEGORY_CURRENCY and row.amount > 1:
		amount = SpinBox.new()
		amount.name = "Amount"
		amount.min_value = 1
		amount.max_value = row.amount
		amount.value = row.amount
		amount.rounded = true
		container.add_child(amount)
	if not _give_target.is_empty():
		_handling_button(container, "Give", tr("给%s") % _give_target, give_requested, row, amount)
	if not _container.is_empty():
		_handling_button(container, "Put", tr("放进%s") % _container, put_requested, row, amount)
	_handling_button(container, "Drop", tr("丢下"), drop_requested, row, amount)
	return container


func _handling_button(container: BoxContainer, node_name: String, text: String, requested: Signal, row: PlayerInventoryRowProjection, amount: SpinBox) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.pressed.connect(func() -> void:
		var count: int = 0 if amount == null or int(amount.value) >= row.amount else int(amount.value)
		requested.emit(row.item_instance_id, count))
	container.add_child(button)


func _row_label(row: PlayerInventoryRowProjection) -> String:
	var amount_label: String = " ×%d" % row.amount if row.amount != 1 else ""
	var equipment_label: String = (
		" [%s]" % row.equipment_label()
		if row.equipment_slot != PlayerInventoryRowProjection.EquipmentSlot.NONE
		else ""
	)
	return "%s%s%s" % [row.display_name, amount_label, equipment_label]


func _on_inspect_pressed(item_instance_id: StringName) -> void:
	inspect_requested.emit(item_instance_id)


func _on_wield_pressed(item_instance_id: StringName) -> void:
	wield_requested.emit(item_instance_id)


func _on_unwield_pressed(item_instance_id: StringName) -> void:
	unwield_requested.emit(item_instance_id)


func _on_wear_pressed(item_instance_id: StringName) -> void:
	wear_requested.emit(item_instance_id)


func _on_remove_pressed(item_instance_id: StringName) -> void:
	remove_requested.emit(item_instance_id)


func _on_close_button_pressed() -> void:
	close_inventory()
