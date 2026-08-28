class_name PlayerInventoryPanel
extends PanelContainer

signal inspect_requested(item_instance_id: StringName)
signal wield_requested(item_instance_id: StringName)
signal unwield_requested(item_instance_id: StringName)

@onready var row_container: VBoxContainer = %PlayerInventoryRows
@onready var empty_label: Label = %PlayerInventoryEmptyLabel
@onready var inspect_text: RichTextLabel = %PlayerInventoryInspectText

var _rows: Array[PlayerInventoryRowProjection] = []


func show_inventory(rows: Array[PlayerInventoryRowProjection]) -> void:
	_replace_rows(rows)
	inspect_text.text = ""
	visible = true


func close_inventory() -> void:
	visible = false
	_replace_rows([])
	inspect_text.text = ""


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
		return
	var lines: Array[String] = [
		row.display_name,
		row.description.strip_edges(),
		"Category: %s" % String(row.category),
		"Equipped: %s" % row.equipment_label(),
	]
	if row.category == OldPineItemContentDefinitions.CATEGORY_WEAPON:
		lines.append("Skill: %s" % String(row.weapon_skill_type))
		lines.append("Damage: %d" % row.weapon_damage)
	elif row.category == OldPineItemContentDefinitions.CATEGORY_CURRENCY:
		lines.append("Amount: %d" % row.amount)
		lines.append("Value: %d" % row.total_value)
	inspect_text.text = "\n".join(lines)


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


func _build_row(row: PlayerInventoryRowProjection) -> HBoxContainer:
	var container: HBoxContainer = HBoxContainer.new()
	container.name = "InventoryRow"
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
	return container


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


func _on_close_button_pressed() -> void:
	close_inventory()
