class_name OldPineLootPanel
extends PanelContainer

signal take_requested(item_instance_id: StringName)

@onready var corpse_title: Label = %LootCorpseTitle
@onready var row_container: VBoxContainer = %LootRows
@onready var empty_label: Label = %LootEmptyLabel

var _rows: Array[WorldItemRowProjection] = []


func show_loot(title: String, rows: Array[WorldItemRowProjection]) -> void:
	corpse_title.text = title
	_replace_rows(rows)
	visible = true


func close_loot() -> void:
	visible = false
	_replace_rows([])


func is_open() -> bool:
	return visible


func visible_rows() -> Array[WorldItemRowProjection]:
	var result: Array[WorldItemRowProjection] = []
	for row: WorldItemRowProjection in _rows:
		result.append(_copy_row(row))
	return result


func _replace_rows(rows: Array[WorldItemRowProjection]) -> void:
	_rows.clear()
	for child: Node in row_container.get_children():
		row_container.remove_child(child)
		child.queue_free()
	for source: WorldItemRowProjection in rows:
		if source == null:
			continue
		var row: WorldItemRowProjection = _copy_row(source)
		_rows.append(row)
		row_container.add_child(_build_row(row))
	empty_label.visible = _rows.is_empty()


func _build_row(row: WorldItemRowProjection) -> HBoxContainer:
	var container: HBoxContainer = HBoxContainer.new()
	container.name = "LootRow"
	var label: Label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = (
		"%s ×%d" % [row.display_name, row.amount]
		if row.amount != 1
		else row.display_name
	)
	label.tooltip_text = row.description.strip_edges()
	container.add_child(label)
	var take_button: Button = Button.new()
	take_button.text = "Take"
	take_button.disabled = not row.can_take
	take_button.pressed.connect(_on_take_pressed.bind(row.item_instance_id))
	container.add_child(take_button)
	return container


func _on_take_pressed(item_instance_id: StringName) -> void:
	take_requested.emit(item_instance_id)


func _on_close_button_pressed() -> void:
	close_loot()


func _copy_row(row: WorldItemRowProjection) -> WorldItemRowProjection:
	return WorldItemRowProjection.new(
		row.item_instance_id,
		row.item_definition_id,
		row.display_name,
		row.description,
		row.amount,
		row.category,
		row.can_take,
		row.corpse_worn,
		row.corpse_worn_locked,
	)
