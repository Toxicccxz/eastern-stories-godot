class_name PlayerInventoryPanel
extends PanelContainer

## The 背包 (owner, 2026-11-04): its sections along the top (InventorySections), the things
## carried listed on the left and the one picked read on the right, with what can be done
## with it there. Moving through the list (a click, keys, pad) reads the row under it, as
## the 百科 does: there is no 观察 button. Every row has the thing's small voxel picture,
## and the one read turns slowly beside its words (VoxelItemLook). The coins are the 钱袋
## under the list, and inventory.c's 负重 under that. 给 is not here: giving is the NPC's
## 给予 page.

signal wield_requested(item_instance_id: StringName)
signal unwield_requested(item_instance_id: StringName)
signal wear_requested(item_instance_id: StringName)
signal remove_requested(item_instance_id: StringName)
## drop.c and put.c; `amount` 0 hands over the whole object.
signal drop_requested(item_instance_id: StringName, amount: int)
signal put_requested(item_instance_id: StringName, amount: int)
signal play_requested(item_instance_id: StringName)
## apply <item> (snake_drug.c, hurt_drug.c) and dissolve <corpse> with 化尸粉 (dust.c).
signal apply_requested(item_instance_id: StringName)
## The item's own command (ItemContentDefinition.act: bracelet.c pray).
signal act_requested(item_instance_id: StringName)
signal dissolve_requested(item_instance_id: StringName)
signal hang_requested(item_instance_id: StringName)
## pour <powder> in <container> (std/medicine/powder.c do_pour()).
signal pour_requested(item_instance_id: StringName, container_id: StringName)
## get <item> from <a carried container> (cmds/std/get.c).
signal take_out_requested(container_id: StringName, item_instance_id: StringName)
## put <item> in <a carried container> (cmds/std/put.c).
signal put_into_requested(item_instance_id: StringName, amount: int, container_id: StringName)
## scribe haunt on a paper for the selected NPC (scribe.c); attach a 僵尸追魂符 (attach.c).
signal scribe_requested(item_instance_id: StringName)
signal attach_requested(item_instance_id: StringName)
## Something was eaten, drunk or filled from the item read (HeldSupplies): `line` is what
## food.c / liquid.c said; the rows change.
signal supplies_used(line: String)

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
## The list column's width; the item read takes the rest.
const LIST_WIDTH: float = 300.0
## A row's picture and the turning one, in pixels.
const ICON_SIZE: int = 36
const MODEL_SIZE: int = 200
## The 钱袋's key where a row's item id would be.
const PURSE: StringName = &"#purse"
## The comparison with what is on, when the picked thing is better or worse.
const BETTER := Color("9fd38a")
const WORSE := UiPalette.WARNING

@onready var section_bar: HBoxContainer = %PlayerInventorySections
@onready var list_column: VBoxContainer = %PlayerInventoryList
@onready var row_container: VBoxContainer = %PlayerInventoryRows
## The rows' scroll; hidden while the section has nothing, so its empty line stands at the top.
@onready var row_scroll: ScrollContainer = %PlayerInventoryScroll
@onready var empty_label: Label = %PlayerInventoryEmptyLabel
@onready var purse_button: Button = %PlayerInventoryPurse
@onready var burden_label: Label = %PlayerInventoryBurden
## The item read's recess beside the list (界面重做 2).
@onready var inspect_well: PanelContainer = %InspectWell
@onready var detail_scroll: ScrollContainer = %PlayerInventoryDetailScroll
@onready var model_mount: CenterContainer = %ItemModelMount
@onready var item_title: Label = %PlayerInventoryItemTitle
@onready var inspect_text: RichTextLabel = %PlayerInventoryInspectText
@onready var compare_label: Label = %PlayerInventoryCompare
@onready var action_rows: VBoxContainer = %PlayerInventoryActions
## What the last 吃 / 喝 / 装水 said; it stays while the same thing is read.
@onready var use_feedback: Label = %PlayerInventoryUseFeedback

var section_buttons: Array[Button] = []
## The listed rows' buttons by item id.
var row_buttons: Dictionary[StringName, Button] = {}
## 吃 and 喝 from the item read; null outside a session (layout tests).
var supplies: HeldSupplies
## The rows' pictures; null outside a session (layout tests): rows go without.
var icons: ItemIcons:
	set(value):
		if icons != null and icons.icon_ready.is_connected(_on_icon_ready):
			icons.icon_ready.disconnect(_on_icon_ready)
		icons = value
		if icons != null:
			icons.icon_ready.connect(_on_icon_ready)
## The item read, turning.
var model_view: ItemModelView

## Everything carried directly, coins included, in carried order.
var _rows: Array[PlayerInventoryRowProjection] = []
## The section's rows in list order.
var _shown: Array[PlayerInventoryRowProjection] = []
var _section: int = InventorySections.Section.ALL
## The item read (an item id, PURSE, or "" none); it stays while it is carried.
var _selected: StringName = &""
## The item the 吃 / 喝 line under the actions is about ("" none): it goes when another is read.
var _feedback_for: StringName = &""
## What the right side was last built for, so a rebuild of the same thing keeps its scroll.
var _detail_of: StringName = &""
var _row_group := ButtonGroup.new()
## inventory.c's 负重: carried weight against the most the player can carry, in percent.
var _burden: int = -1
## The container in reach, empty when there is none.
var _container: String = ""
## The selected corpse lying here (its victim's name), which 化尸粉 can dissolve.
var _corpse: String = ""
## The carried liquid containers a powder can be poured into: [id, shown name] pairs.
var _pour_targets: Array = []
## The carried containers (max_encumbrance) something can be put in: [id, shown name] pairs.
var _carried_containers: Array = []
## Whose name a 符 on a paper would carry (the selected NPC here), and the zombie here a
## 僵尸追魂符 goes on; empty when there is none.
var _scribe_target: String = ""
var _sheet_carrier: String = ""


func _ready() -> void:
	var sections := ButtonGroup.new()
	for section: int in InventorySections.TITLES.size():
		var button := Button.new()
		button.name = "Section%d" % section
		button.theme_type_variation = &"ToggleButton"
		button.toggle_mode = true
		button.button_group = sections
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = Vector2(80, 36)
		button.set_pressed_no_signal(section == _section)
		button.pressed.connect(show_section.bind(section))
		section_bar.add_child(button)
		section_buttons.append(button)
	list_column.custom_minimum_size.x = LIST_WIDTH
	list_column.set_meta(ResponsivePanelLayout.KEEPS_WIDTH, true)
	purse_button.button_group = _row_group
	purse_button.add_theme_constant_override("icon_max_width", ICON_SIZE)
	purse_button.add_theme_constant_override("h_separation", 10)
	purse_button.pressed.connect(select_item.bind(PURSE))
	purse_button.focus_entered.connect(select_item.bind(PURSE))
	detail_scroll.add_to_group(PadSupport.SCROLL_GROUP)
	model_view = ItemModelView.new(MODEL_SIZE)
	model_mount.add_child(model_view)
	_section_titles()


func set_handling_targets(container: String) -> void:
	_container = container


func set_dissolvable_corpse(victim_name: String) -> void:
	_corpse = victim_name


func set_spell_targets(scribe_target: String, sheet_carrier: String) -> void:
	_scribe_target = scribe_target
	_sheet_carrier = sheet_carrier


## `targets`: [item id, container name] pairs, in carried order.
func set_pour_targets(targets: Array) -> void:
	_pour_targets = targets.duplicate()


## inventory.c's 负重 in percent; below 0 shows none.
func set_burden(percent: int) -> void:
	_burden = percent


func show_inventory(rows: Array[PlayerInventoryRowProjection]) -> void:
	var focused: Control = _focus_inside()
	# An action pressed with keys or pad (吃一份 again and again) keeps the focus on itself.
	var chip: String = "" if focused == null or not action_rows.is_ancestor_of(focused) else String(focused.name)
	var reading: StringName = _selected
	_replace_rows(rows)
	visible = true
	_refresh(focused != null)
	if not chip.is_empty() and _selected == reading:
		var again: Control = action_rows.find_child(chip, true, false) as Control
		if again != null and again.is_visible_in_tree():
			FocusNav.give(again)


func close_inventory() -> void:
	visible = false
	_replace_rows([])
	_shown.clear()
	_clear_list()
	use_feedback.text = ""
	_feedback_for = &""
	_show_selected()


func is_open() -> bool:
	return visible


func visible_rows() -> Array[PlayerInventoryRowProjection]:
	var result: Array[PlayerInventoryRowProjection] = []
	for row: PlayerInventoryRowProjection in _rows:
		result.append(row.duplicate_snapshot())
	return result


## The rows the shown section lists, in its order (tests).
func listed_rows() -> Array[PlayerInventoryRowProjection]:
	return _shown.duplicate()


func current_section() -> int:
	return _section


func selected_item() -> StringName:
	return _selected


## Where keys and pad start: the row read, else the section shown.
func focus_target() -> Control:
	if _selected == PURSE:
		return purse_button
	if row_buttons.has(_selected):
		return row_buttons[_selected]
	return null if section_buttons.is_empty() else section_buttons[_section]


func show_section(section: int) -> void:
	# The chip shown pressed again (a button group presses it anew): nothing changes.
	if section < 0 or section >= InventorySections.TITLES.size() or section == _section:
		return
	_mark_section(section)
	if _selected != PURSE:
		_selected = &""
	use_feedback.text = ""
	_feedback_for = &""
	_refresh(false)


func _mark_section(section: int) -> void:
	_section = section
	for index: int in section_buttons.size():
		section_buttons[index].set_pressed_no_signal(index == section)


## Reads `id` beside the list (a click, or keys or pad moving onto its row); PURSE reads the 钱袋.
func select_item(id: StringName) -> void:
	if id != PURSE and _row(id) == null:
		return
	if id != PURSE and not row_buttons.has(id):
		# Carried but not in the section shown (read from a helper): 全部 lists it.
		_mark_section(InventorySections.Section.ALL)
		_selected = id
		use_feedback.text = ""
		_feedback_for = &""
		_refresh(false)
	if id != _selected:
		_selected = id
		use_feedback.text = ""
		_show_selected()
	var button: Button = purse_button if id == PURSE else row_buttons.get(id)
	if button == null:
		return
	# Pressing it in its group lifts the one read before (set_pressed_no_signal would not).
	button.button_pressed = true
	if not button.has_focus() and button.is_visible_in_tree():
		FocusNav.give(button)


## Reads `row` beside the list, carried or not (tests and the inspect helpers).
func show_inspection(row: PlayerInventoryRowProjection) -> void:
	if row == null:
		_selected = &""
		_show_selected()
		return
	_selected = row.item_instance_id
	_show_item(row)


## The item read as text: its name, then what the right side says of it.
func inspection_display() -> String:
	if item_title.text.is_empty():
		return ""
	var lines: Array[String] = [item_title.text, inspect_text.text]
	if compare_label.visible:
		lines.append(compare_label.text)
	return "\n".join(lines)


func _replace_rows(rows: Array[PlayerInventoryRowProjection]) -> void:
	_rows.clear()
	_carried_containers.clear()
	for source: PlayerInventoryRowProjection in rows:
		if source == null:
			continue
		var row: PlayerInventoryRowProjection = source.duplicate_snapshot()
		_rows.append(row)
		var held: ItemContentDefinition = GameContent.catalog().item(row.item_definition_id)
		if held != null and held.max_encumbrance > 0:
			_carried_containers.append([row.item_instance_id, row.display_name])


## Lists the section and reads the item picked (when the one read is gone, the row that took
## its place: dropping things one after another goes down the list).
## `focused`: the focus was in the page, so it goes back to the row read once rebuilt.
func _refresh(focused: bool) -> void:
	var was: int = _shown.find_custom(func(row: PlayerInventoryRowProjection) -> bool: return row.item_instance_id == _selected)
	_shown = _ordered(_section)
	_section_titles()
	_clear_list()
	for row: PlayerInventoryRowProjection in _shown:
		var button: Button = _build_row(row)
		row_container.add_child(button)
		row_buttons[row.item_instance_id] = button
	empty_label.text = InventorySections.EMPTY_LINES[_section]
	empty_label.visible = _shown.is_empty()
	row_scroll.visible = not _shown.is_empty()
	purse_button.text = _purse_title()
	var dearest: PlayerInventoryRowProjection = _dearest_coin()
	purse_button.icon = null if icons == null or dearest == null else icons.icon(dearest.item_definition_id)
	# TRANSLATORS: inventory.c's 负重: how much of the most the player can carry they carry, in percent.
	burden_label.text = "" if _burden < 0 else tr("负重 {percent}%").format({"percent": _burden})
	burden_label.visible = _burden >= 0
	if _selected != PURSE and not row_buttons.has(_selected):
		_selected = &"" if _shown.is_empty() else _shown[clampi(was, 0, _shown.size() - 1)].item_instance_id
	# The 吃 / 喝 line is about one thing: it goes with it (the log keeps it).
	if _selected != _feedback_for:
		use_feedback.text = ""
		_feedback_for = &""
	var button: Button = purse_button if _selected == PURSE else row_buttons.get(_selected)
	if button != null:
		button.set_pressed_no_signal(true)
	elif _row_group.get_pressed_button() != null:
		_row_group.get_pressed_button().set_pressed_no_signal(false)
	_show_selected()
	if focused:
		var target: Control = focus_target()
		if target != null and target.is_visible_in_tree():
			FocusNav.give(target)


func _clear_list() -> void:
	for child: Node in row_container.get_children():
		row_container.remove_child(child)
		child.queue_free()
	row_buttons.clear()


## The keyboard / pad focus when it is somewhere in this page now, else null.
func _focus_inside() -> Control:
	if not is_inside_tree():
		return null
	var owner_now: Control = get_viewport().gui_get_focus_owner()
	return owner_now if owner_now != null and is_ancestor_of(owner_now) else null


## The section's rows: what is on first (in hand, then worn), then by section, else as carried.
func _ordered(section: int) -> Array[PlayerInventoryRowProjection]:
	var keyed: Array = []
	for index: int in _rows.size():
		var row: PlayerInventoryRowProjection = _rows[index]
		var content: ItemContentDefinition = GameContent.catalog().item(row.item_definition_id)
		if not InventorySections.shows(section, content):
			continue
		var worn: int = 0 if row.equipment_slot != PlayerInventoryRowProjection.EquipmentSlot.NONE else 1
		keyed.append([(worn * 100 + InventorySections.of(content)) * 100000 + index, row])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var ordered: Array[PlayerInventoryRowProjection] = []
	for pair: Array in keyed:
		ordered.append(pair[1])
	return ordered


func _section_titles() -> void:
	for index: int in section_buttons.size():
		var count: int = 0
		for row: PlayerInventoryRowProjection in _rows:
			if InventorySections.shows(index, GameContent.catalog().item(row.item_definition_id)):
				count += 1
		# TRANSLATORS: a 背包 section and how many things it lists: 装备 4.
		section_buttons[index].text = tr("{section} {count}").format({"section": tr(InventorySections.TITLES[index]), "count": count})


func _build_row(row: PlayerInventoryRowProjection) -> Button:
	var button := Button.new()
	button.name = "InventoryRow%d" % row_buttons.size()
	button.text = row_label(row)
	button.theme_type_variation = &"RowButton"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggle_mode = true
	button.button_group = _row_group
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.custom_minimum_size = Vector2(0, ICON_SIZE + 8)
	button.add_theme_constant_override("icon_max_width", ICON_SIZE)
	button.add_theme_constant_override("h_separation", 10)
	if icons != null:
		button.icon = icons.icon(row.item_definition_id)
	button.set_pressed_no_signal(row.item_instance_id == _selected)
	var colour: Color = name_color_of(row.item_definition_id)
	if colour != Color.TRANSPARENT:
		for slot: StringName in [&"font_color", &"font_pressed_color", &"font_hover_color", &"font_focus_color", &"font_hover_pressed_color"]:
			button.add_theme_color_override(slot, colour)
	button.pressed.connect(select_item.bind(row.item_instance_id))
	button.focus_entered.connect(select_item.bind(row.item_instance_id))
	return button


## The 钱袋's line under the list: every kind of coin carried, counted (三两黄金、二十文钱).
func _purse_title() -> String:
	var counted: Array[String] = []
	for row: PlayerInventoryRowProjection in _coins():
		counted.append(HeldItemFacts.counted(GameContent.catalog().item(row.item_definition_id), row.amount))
	# TRANSLATORS: the 背包's purse line: {coins} the coins carried (三两黄金、二十文钱), or 空 when none.
	return tr("钱袋：{coins}").format({"coins": tr("空") if counted.is_empty() else tr("、").join(counted)})


func _coins() -> Array[PlayerInventoryRowProjection]:
	var coins: Array[PlayerInventoryRowProjection] = []
	for row: PlayerInventoryRowProjection in _rows:
		if InventorySections.is_money(GameContent.catalog().item(row.item_definition_id)):
			coins.append(row)
	return coins


## The coin worth most a piece among those carried (the purse's picture), or null.
func _dearest_coin() -> PlayerInventoryRowProjection:
	var dearest: PlayerInventoryRowProjection = null
	var worth: int = -1
	for row: PlayerInventoryRowProjection in _coins():
		var each: int = GameContent.catalog().item(row.item_definition_id).currency_base_value
		if each > worth:
			dearest = row
			worth = each
	return dearest


func _row(id: StringName) -> PlayerInventoryRowProjection:
	for row: PlayerInventoryRowProjection in _rows:
		if row.item_instance_id == id:
			return row
	return null


func _show_selected() -> void:
	if _selected == PURSE:
		_show_purse()
		return
	_show_item(_row(_selected))


## A picture taken: the rows of that kind of thing show it.
func _on_icon_ready(item_definition_id: StringName, texture: Texture2D) -> void:
	for row: PlayerInventoryRowProjection in _shown:
		if row.item_definition_id == item_definition_id and row_buttons.has(row.item_instance_id):
			row_buttons[row.item_instance_id].icon = texture
	var dearest: PlayerInventoryRowProjection = _dearest_coin()
	if dearest != null and dearest.item_definition_id == item_definition_id:
		purse_button.icon = texture


## The turning picture shows `item_definition_id` ("" none).
func _show_model(item_definition_id: StringName) -> void:
	model_mount.visible = not item_definition_id.is_empty()
	if model_view != null:
		model_view.show_item(item_definition_id)


func _clear_detail() -> void:
	for child: Node in action_rows.get_children():
		action_rows.remove_child(child)
		child.queue_free()
	compare_label.visible = false
	compare_label.text = ""
	item_title.remove_theme_color_override("font_color")


## The right side is built for `key` (an item id, PURSE): back to its top when it is another thing.
func _detail_for(key: StringName) -> void:
	if key != _detail_of:
		detail_scroll.scroll_vertical = 0
		_detail_of = key


## Keys and pad: left from any action goes back to the row read (not to the row nearest the
## action, which would read another thing), and right from that row to its first action.
func _link_focus() -> void:
	var reading: Control = purse_button if _selected == PURSE else row_buttons.get(_selected)
	if reading == null:
		return
	var first: Control = null
	for node: Node in action_rows.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control is SpinBox:
			control = (control as SpinBox).get_line_edit()
		if control.focus_mode == Control.FOCUS_NONE:
			continue
		control.focus_neighbor_left = control.get_path_to(reading)
		if first == null:
			first = control
	reading.focus_neighbor_right = NodePath() if first == null else reading.get_path_to(first)


func _show_item(row: PlayerInventoryRowProjection) -> void:
	_clear_detail()
	if row == null:
		item_title.text = ""
		inspect_text.text = ""
		use_feedback.text = ""
		_show_model(&"")
		return
	_detail_for(row.item_instance_id)
	_show_model(row.item_definition_id)
	item_title.text = tr(row.display_name)
	var colour: Color = name_color_of(row.item_definition_id)
	if colour != Color.TRANSPARENT:
		item_title.add_theme_color_override("font_color", colour)
	inspect_text.text = "\n".join(_facts(row))
	var compared: Array = _comparison(row)
	if not compared.is_empty():
		compare_label.text = compared[0]
		compare_label.add_theme_color_override("font_color", compared[1])
		compare_label.visible = true
	action_rows.add_child(_actions(row))
	_link_focus()


## The 钱袋 read: every kind of coin, what it is worth, and putting or dropping some.
func _show_purse() -> void:
	_clear_detail()
	_detail_for(PURSE)
	item_title.text = tr("钱袋")
	var coins: Array[PlayerInventoryRowProjection] = _coins()
	if coins.is_empty():
		inspect_text.text = tr("身上一文钱也没有。")
		_show_model(&"")
		return
	# The purse shows its dearest coin.
	_show_model(_dearest_coin().item_definition_id)
	var worth: int = 0
	for row: PlayerInventoryRowProjection in coins:
		worth += row.total_value
	# TRANSLATORS: what all the coins in the 背包's purse are worth together, in 文.
	inspect_text.text = tr("合计价值：{value} 文").format({"value": worth})
	for row: PlayerInventoryRowProjection in coins:
		var block := VBoxContainer.new()
		block.name = "Coin"
		block.add_theme_constant_override("separation", 4)
		var label := Label.new()
		label.text = HeldItemFacts.counted(GameContent.catalog().item(row.item_definition_id), row.amount)
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		block.add_child(label)
		block.add_child(_actions(row))
		action_rows.add_child(block)
	_link_focus()


## What the item read says of it: the description, then its kind and numbers.
func _facts(row: PlayerInventoryRowProjection) -> Array[String]:
	var lines: Array[String] = [
		row.description.strip_edges(),
		tr("类别：%s") % _word(CATEGORY_WORDS, row.category),
		tr("装备：%s") % (tr("未装备") if row.equipment_label().is_empty() else tr(row.equipment_label())),
	]
	if row.category == ItemContentDefinition.CATEGORY_WEAPON:
		lines.append(tr("兵器：%s") % _word(WEAPON_WORDS, row.weapon_skill_type))
		lines.append(tr("伤害：%d") % row.weapon_damage)
		_append_dodge(lines, row.weapon_dodge)
		if row.amount != 1:
			lines.append(tr("数量：%d") % row.amount)
	elif row.category == ItemContentDefinition.CATEGORY_CURRENCY:
		lines.append(tr("数量：%d") % row.amount)
		lines.append(tr("价值：%d") % row.total_value)
	elif row.category == ItemContentDefinition.CATEGORY_ARMOR:
		lines.append(tr("部位：%s") % _word(ARMOR_WORDS, row.armor_type))
		lines.append(tr("防护：%+d") % row.armor_modifiers.armor)
		_append_dodge(lines, row.armor_modifiers.dodge)
	elif row.amount != 1:
		lines.append(tr("数量：%d") % row.amount)
	if supplies != null:
		if supplies.is_food(row.item_instance_id):
			lines.append(supplies.food_status(row.item_instance_id))
		elif supplies.is_liquid(row.item_instance_id):
			lines.append(supplies.liquid_status(row.item_instance_id))
	# look.c look_item(): what a container holds.
	if not row.contents.is_empty():
		var names: Array[String] = []
		for held: Array in row.contents:
			names.append(held_label(held))
		# TRANSLATORS: what a container holds (look.c), one name a line after it.
		lines.append(tr("里面有：") + "\n  " + "\n  ".join(names))
	return lines


## A weapon or armour not on, against the one on in its place: [line, colour], or [] when
## there is nothing to say (it is on, or it is neither).
func _comparison(row: PlayerInventoryRowProjection) -> Array:
	if row.equipment_slot != PlayerInventoryRowProjection.EquipmentSlot.NONE:
		return []
	if row.category == ItemContentDefinition.CATEGORY_WEAPON:
		var held: PlayerInventoryRowProjection = _on(func(each: PlayerInventoryRowProjection) -> bool:
			return each.equipment_slot == PlayerInventoryRowProjection.EquipmentSlot.PRIMARY)
		if held == null:
			return [tr("现在手上没有兵器。"), UiPalette.MUTED]
		var damage: int = row.weapon_damage - held.weapon_damage
		# TRANSLATORS: a weapon in the 背包 against the one in hand ({item}): {damage} the difference in 伤害 (+8, -3).
		var line: String = tr("和手上的{item}比：伤害 {damage}").format({"item": tr(held.display_name), "damage": "%+d" % damage})
		return [line + _dodge_difference(row.weapon_dodge - held.weapon_dodge), _better(damage)]
	if row.category == ItemContentDefinition.CATEGORY_ARMOR:
		var worn: PlayerInventoryRowProjection = _on(func(each: PlayerInventoryRowProjection) -> bool:
			return each.equipment_slot == PlayerInventoryRowProjection.EquipmentSlot.WORN and each.armor_type == row.armor_type)
		if worn == null:
			return [tr("这个部位现在什么也没穿。"), UiPalette.MUTED]
		var armor: int = row.armor_modifiers.armor - worn.armor_modifiers.armor
		# TRANSLATORS: armour in the 背包 against the one worn in its place ({item}): {armor} the difference in 防护.
		var said: String = tr("和身上的{item}比：防护 {armor}").format({"item": tr(worn.display_name), "armor": "%+d" % armor})
		return [said + _dodge_difference(row.armor_modifiers.dodge - worn.armor_modifiers.dodge), _better(armor)]
	return []


func _on(matches: Callable) -> PlayerInventoryRowProjection:
	for each: PlayerInventoryRowProjection in _rows:
		if matches.call(each):
			return each
	return null


func _dodge_difference(dodge: int) -> String:
	# TRANSLATORS: added to a 背包 comparison when 轻功 differs too: {dodge} (+1, -2).
	return "" if dodge == 0 else tr("，轻功 {dodge}").format({"dodge": "%+d" % dodge})


func _better(difference: int) -> Color:
	return BETTER if difference > 0 else (WORSE if difference < 0 else UiPalette.MUTED)


## What can be done with the item read, as stone chips: put it on or take it off, eat or
## drink, its own verbs, then the handling (an amount of a stack, put, drop).
func _actions(row: PlayerInventoryRowProjection) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.name = "Actions"
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	var id: StringName = row.item_instance_id
	if row.can_wield:
		_chip(flow, "Wield", "装备", func() -> void: wield_requested.emit(id))
	elif row.can_unwield:
		_chip(flow, "Unwield", "放下", func() -> void: unwield_requested.emit(id))
	elif row.can_wear:
		_chip(flow, "Wear", "穿戴", func() -> void: wear_requested.emit(id))
	elif row.can_remove:
		_chip(flow, "Remove", "脱掉", func() -> void: remove_requested.emit(id))
	if supplies != null:
		if supplies.is_food(id) and supplies.food_available():
			_chip(flow, "Eat", "吃一份", _use.bind(supplies.eat, id))
		if supplies.is_liquid(id) and supplies.liquid_available():
			_chip(flow, "Drink", supplies.drink_label(id), _use.bind(supplies.drink, id))
			if supplies.can_fill():
				_chip(flow, "Fill", "装满清水（倒掉现有内容）", _use.bind(supplies.fill, id))
	var content: ItemContentDefinition = GameContent.catalog().item(row.item_definition_id)
	# bamboo_pipe.c add_action("do_play", ({ "play", "blow" })).
	if content != null and not content.play.is_empty():
		_chip(flow, "Play", "吹奏", func() -> void: play_requested.emit(id))
	if content != null and not content.apply.is_empty():
		_chip(flow, "Apply", ItemApplyFunctions.verb(content.apply), func() -> void: apply_requested.emit(id))
	# The item's own add_action() (bracelet.c pray, book.c dancing, letter.c fire).
	if content != null and content.act != null:
		_chip(flow, "Act", content.act.verb, func() -> void: act_requested.emit(id))
	# rope.c add_action("hang_self", "hang").
	if content != null and content.hang:
		_chip(flow, "Hang", "上吊", func() -> void: hang_requested.emit(id))
	if content != null and content.dissolves and not _corpse.is_empty():
		# TRANSLATORS: dust.c's dissolve on the selected corpse ({corpse}, e.g. 狼狗的尸体).
		_chip(flow, "Dissolve", tr("化去{corpse}").format({"corpse": _corpse}), func() -> void: dissolve_requested.emit(id))
	# scribe.c: 僵尸追魂符 on a 桃符纸, with the selected NPC's name (haunt.c).
	if content != null and content.scribe and not _scribe_target.is_empty():
		# TRANSLATORS: draw a 僵尸追魂符 on the paper with someone's name ({name}) on it (scribe.c, haunt.c).
		_chip(flow, "Scribe", tr("画追魂符：{name}").format({"name": tr(_scribe_target)}), func() -> void: scribe_requested.emit(id))
	# attach.c: put the sheet on the zombie here.
	if content != null and not content.haunts.is_empty() and not _sheet_carrier.is_empty():
		# TRANSLATORS: put the 僵尸追魂符 on the zombie ({zombie}) here (attach.c).
		_chip(flow, "Attach", tr("贴到{zombie}身上").format({"zombie": tr(_sheet_carrier)}), func() -> void: attach_requested.emit(id))
	if content != null and content.pour != null:
		var names: Array[String] = []
		for target: Array in _pour_targets:
			names.append(tr(target[1]))
		for index: int in range(_pour_targets.size()):
			var container_id: StringName = _pour_targets[index][0]
			# TRANSLATORS: pour the powder into a carried drink ({container}: 牛皮酒袋).
			var text: String = tr("倒进{container}").format({"container": names[index]})
			if names.count(names[index]) > 1:
				text += " #%d" % (index + 1)
			_chip(flow, "Pour", text, func() -> void: pour_requested.emit(id, container_id))
	# get <item> from <container>: what a carried container holds (slipcase.c's book).
	for held: Array in row.contents:
		var held_id: StringName = held[0]
		# TRANSLATORS: take something ({item}: 悟疾风劲竹书) out of a carried container (get.c).
		_chip(flow, "TakeOut", tr("取出{item}").format({"item": held_label(held)}), func() -> void: take_out_requested.emit(id, held_id))
	# A stack can be handled in part (drop 10 throwing knives, put 5 silver in the 功德箱).
	var amount: SpinBox = null
	if content != null and content.is_stack and row.amount > 1:
		amount = SpinBox.new()
		amount.name = "Amount"
		amount.min_value = 1
		amount.max_value = row.amount
		amount.value = row.amount
		amount.rounded = true
		flow.add_child(amount)
	var count: Callable = func() -> int:
		return 0 if amount == null or int(amount.value) >= row.amount else int(amount.value)
	if not _container.is_empty():
		_chip(flow, "Put", tr("放进%s") % tr(_container), func() -> void: put_requested.emit(id, count.call()))
	# put <item> in <a carried container> (put.c looks on the player first); two of one name
	# are numbered, as the pour targets are.
	var carried_names: Array[String] = []
	for target: Array in _carried_containers:
		carried_names.append(tr(target[1]))
	for index: int in range(_carried_containers.size()):
		var target_id: StringName = _carried_containers[index][0]
		if target_id == id:
			continue
		var text: String = tr("放进%s") % carried_names[index]
		if carried_names.count(carried_names[index]) > 1:
			text += " #%d" % (index + 1)
		_chip(flow, "PutCarried", text, func() -> void: put_into_requested.emit(id, count.call(), target_id))
	_chip(flow, "Drop", "丢下", func() -> void: drop_requested.emit(id, count.call()))
	return flow


func _chip(flow: HFlowContainer, node_name: String, text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.theme_type_variation = &"ChipButton"
	button.custom_minimum_size.y = 36
	button.pressed.connect(pressed)
	flow.add_child(button)
	return button


## 吃 / 喝 / 装水 on the item read: what it said stays under it, and the rows refresh.
func _use(how: Callable, id: StringName) -> void:
	var line: String = how.call(id)
	use_feedback.text = line
	_feedback_for = id
	supplies_used.emit(line)


## What the item adds to apply/dodge (the 武学 page's 轻功), when it adds anything: a heavy
## weapon or armor costs -weight/3000 (std/equip.c, std/armor/*.c setup()).
func _append_dodge(lines: Array[String], dodge: int) -> void:
	if dodge != 0:
		# TRANSLATORS: an item's apply/dodge, e.g. 轻功：-2 (the 武学 page's 轻功 use).
		lines.append(tr("轻功：%+d") % dodge)


## A kind's word, or the ES2 id when there is none.
func _word(words: Dictionary[StringName, String], id: StringName) -> String:
	return tr(words[id]) if words.has(id) else String(id)


## What a container holds, as its row says it: a stack with its amount (combined.c short()).
static func held_label(held: Array) -> String:
	var label: String = TranslationServer.translate(held[1])
	if held.size() > 2 and int(held[2]) != 1:
		label = TranslationServer.translate("{item} ×{amount}").format({"item": label, "amount": held[2]})
	return label


## The colour an item's name is written in (ItemContentDefinition.name_color: seal.c's HIY 印鉴),
## as the log shows that colour; TRANSPARENT for a plain name (关北 A; DECISIONS「关北 A」).
static func name_color_of(item_definition_id: StringName) -> Color:
	var definition: ItemContentDefinition = GameContent.catalog().item(item_definition_id)
	if definition == null or definition.name_color.is_empty():
		return Color.TRANSPARENT
	return SharedGameplayUI.ES2_COLORS.get(definition.name_color, Color.TRANSPARENT)


## A carried thing as its row names it: a stack with its amount, what is on with how.
static func row_label(row: PlayerInventoryRowProjection) -> String:
	var label: String = TranslationServer.translate(row.display_name)
	if row.amount != 1:
		label = TranslationServer.translate("{item} ×{amount}").format({"item": label, "amount": row.amount})
	if row.equipment_slot != PlayerInventoryRowProjection.EquipmentSlot.NONE:
		# TRANSLATORS: an item the player has on, and how: 短剑 · 主手.
		label = TranslationServer.translate("{item} · {slot}").format({"item": label, "slot": TranslationServer.translate(row.equipment_label())})
	return label


func _on_close_button_pressed() -> void:
	close_inventory()
