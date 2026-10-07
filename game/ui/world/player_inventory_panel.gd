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
signal play_requested(item_instance_id: StringName)
## apply <item> (snake_drug.c, hurt_drug.c) and dissolve <corpse> with 化尸粉 (dust.c).
signal apply_requested(item_instance_id: StringName)
signal dissolve_requested(item_instance_id: StringName)
signal hang_requested(item_instance_id: StringName)
## pour <powder> in <container> (std/medicine/powder.c do_pour()).
signal pour_requested(item_instance_id: StringName, container_id: StringName)

## Words for the item kinds the inspection names (category, weapon_prop skill_type, armor_type).
const CATEGORY_WORDS: Dictionary[StringName, String] = {
	&"weapon": "武器", &"armor": "防具", &"currency": "钱币", &"food": "食物", &"liquid": "饮品", &"misc": "杂物",
}
const WEAPON_WORDS: Dictionary[StringName, String] = {
	&"sword": "剑", &"blade": "刀", &"axe": "斧", &"hammer": "锤", &"dagger": "匕首", &"staff": "杖",
	&"stick": "棍", &"whip": "鞭", &"throwing": "暗器",
}
const ARMOR_WORDS: Dictionary[StringName, String] = {
	&"cloth": "衣服", &"armor": "铠甲", &"surcoat": "外衣", &"boots": "靴子", &"shield": "盾牌", &"head": "头部",
	&"neck": "颈部", &"wrists": "手腕", &"finger": "手指", &"hands": "手部", &"waist": "腰部",
}

@onready var row_container: VBoxContainer = %PlayerInventoryRows
@onready var empty_label: Label = %PlayerInventoryEmptyLabel
@onready var inspect_text: RichTextLabel = %PlayerInventoryInspectText

var _rows: Array[PlayerInventoryRowProjection] = []
## Who can be given things (the selected NPC here) and the container in reach;
## empty when there is none.
var _give_target: String = ""
var _container: String = ""
## The selected corpse lying here (its victim's name), which 化尸粉 can dissolve.
var _corpse: String = ""
## The carried liquid containers a powder can be poured into: [id, shown name] pairs.
var _pour_targets: Array = []


func set_handling_targets(give_target: String, container: String) -> void:
	_give_target = give_target
	_container = container


func set_dissolvable_corpse(victim_name: String) -> void:
	_corpse = victim_name


## `targets`: [item id, container name] pairs, in carried order.
func set_pour_targets(targets: Array) -> void:
	_pour_targets = targets.duplicate()


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
		tr(row.display_name),
		row.description.strip_edges(),
		tr("类别：%s") % _word(CATEGORY_WORDS, row.category),
		tr("装备：%s") % (tr("未装备") if row.equipment_label().is_empty() else tr(row.equipment_label())),
	]
	if row.category == ItemContentDefinition.CATEGORY_WEAPON:
		lines.append(tr("兵器：%s") % _word(WEAPON_WORDS, row.weapon_skill_type))
		lines.append(tr("伤害：%d") % row.weapon_damage)
		if row.amount != 1:
			lines.append(tr("数量：%d") % row.amount)
	elif row.category == ItemContentDefinition.CATEGORY_CURRENCY:
		lines.append(tr("数量：%d") % row.amount)
		lines.append(tr("价值：%d") % row.total_value)
	elif row.category == ItemContentDefinition.CATEGORY_ARMOR:
		lines.append(tr("部位：%s") % _word(ARMOR_WORDS, row.armor_type))
		lines.append(tr("防护：%+d") % row.armor_modifiers.armor)
		lines.append(tr("闪避：%+d") % row.armor_modifiers.dodge)
	elif row.amount != 1:
		lines.append(tr("数量：%d") % row.amount)
	inspect_text.text = "\n".join(lines)
	inspect_text.show()


func inspection_display() -> String:
	return inspect_text.text


## A kind's word, or the ES2 id when there is none.
func _word(words: Dictionary[StringName, String], id: StringName) -> String:
	return tr(words[id]) if words.has(id) else String(id)


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
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	container.add_child(label)
	var inspect_button: Button = Button.new()
	inspect_button.text = "观察"
	inspect_button.pressed.connect(_on_inspect_pressed.bind(row.item_instance_id))
	container.add_child(inspect_button)
	if row.can_wield:
		var wield_button: Button = Button.new()
		wield_button.text = "装备"
		wield_button.pressed.connect(_on_wield_pressed.bind(row.item_instance_id))
		container.add_child(wield_button)
	elif row.can_unwield:
		var unwield_button: Button = Button.new()
		unwield_button.text = "放下"
		unwield_button.pressed.connect(_on_unwield_pressed.bind(row.item_instance_id))
		container.add_child(unwield_button)
	elif row.can_wear:
		var wear_button: Button = Button.new()
		wear_button.text = "穿戴"
		wear_button.pressed.connect(_on_wear_pressed.bind(row.item_instance_id))
		container.add_child(wear_button)
	elif row.can_remove:
		var remove_button: Button = Button.new()
		remove_button.text = "脱掉"
		remove_button.pressed.connect(_on_remove_pressed.bind(row.item_instance_id))
		container.add_child(remove_button)
	# bamboo_pipe.c add_action("do_play", ({ "play", "blow" })).
	var content: ItemContentDefinition = GameContent.catalog().item(row.item_definition_id)
	if content != null and not content.play.is_empty():
		var play_button: Button = Button.new()
		play_button.name = "Play"
		play_button.text = "吹奏"
		play_button.pressed.connect(func() -> void: play_requested.emit(row.item_instance_id))
		container.add_child(play_button)
	if content != null and not content.apply.is_empty():
		var apply_button: Button = Button.new()
		apply_button.name = "Apply"
		apply_button.text = "使用"
		apply_button.pressed.connect(func() -> void: apply_requested.emit(row.item_instance_id))
		container.add_child(apply_button)
	# rope.c add_action("hang_self", "hang").
	if content != null and content.hang:
		var hang_button: Button = Button.new()
		hang_button.name = "Hang"
		hang_button.text = "上吊"
		hang_button.pressed.connect(func() -> void: hang_requested.emit(row.item_instance_id))
		container.add_child(hang_button)
	if content != null and content.dissolves and not _corpse.is_empty():
		var dissolve_button: Button = Button.new()
		dissolve_button.name = "Dissolve"
		# TRANSLATORS: dust.c's dissolve on the selected corpse ({corpse}, e.g. 狼狗的尸体).
		dissolve_button.text = tr("化去{corpse}").format({"corpse": tr("%s的尸体") % tr(_corpse)})
		dissolve_button.pressed.connect(func() -> void: dissolve_requested.emit(row.item_instance_id))
		container.add_child(dissolve_button)
	if content != null and content.pour != null:
		var names: Array[String] = []
		for target: Array in _pour_targets:
			names.append(tr(target[1]))
		for index: int in range(_pour_targets.size()):
			var target: Array = _pour_targets[index]
			var pour_button: Button = Button.new()
			pour_button.name = "Pour"
			# TRANSLATORS: pour the powder into a carried drink ({container}: 牛皮酒袋).
			pour_button.text = tr("倒进{container}").format({"container": names[index]})
			if names.count(names[index]) > 1:
				pour_button.text += " #%d" % (index + 1)
			var container_id: StringName = target[0]
			pour_button.pressed.connect(func() -> void: pour_requested.emit(row.item_instance_id, container_id))
			container.add_child(pour_button)
	# A stack can be handed over in part (give 5 silver to ..., drop 10 throwing knives).
	var amount: SpinBox = null
	if content != null and content.is_stack and row.amount > 1:
		amount = SpinBox.new()
		amount.name = "Amount"
		amount.min_value = 1
		amount.max_value = row.amount
		amount.value = row.amount
		amount.rounded = true
		container.add_child(amount)
	if not _give_target.is_empty():
		_handling_button(container, "Give", tr("给%s") % tr(_give_target), give_requested, row, amount)
	if not _container.is_empty():
		_handling_button(container, "Put", tr("放进%s") % tr(_container), put_requested, row, amount)
	_handling_button(container, "Drop", "丢下", drop_requested, row, amount)
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
	var label: String = tr(row.display_name)
	if row.amount != 1:
		label = tr("{item} ×{amount}").format({"item": label, "amount": row.amount})
	if row.equipment_slot != PlayerInventoryRowProjection.EquipmentSlot.NONE:
		# TRANSLATORS: an item the player has on, and how: 短剑 · 主手.
		label = tr("{item} · {slot}").format({"item": label, "slot": tr(row.equipment_label())})
	return label


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
