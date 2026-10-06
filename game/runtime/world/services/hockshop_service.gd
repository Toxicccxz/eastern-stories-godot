class_name HockshopService
extends WorldService

## inherit HOCKSHOP (d/snow/hockshop.c): value and sell carried goods. One
## transient view; H2 alone owns appraisal/payout/destruction. No merchant,
## saved UI state, timer, RNG, or duplicated item/equipment authority.
var _title: Label
var _rows: VBoxContainer
var _goods: VBoxContainer
var _actions: HBoxContainer
var _pending: HockshopValuationResult
var _pending_state: Array[int] = []
var _pending_equipment: String = ""
var _ids: Array[StringName] = []
var _labels: Array[String] = []
var _selected_id: StringName = &""
var panel: PanelContainer
var feedback: Label
var holdings: Label
var selection: Label
var value_button: Button
var sell_button: Button
## Asks before a sale (ConfirmPrompt); its confirm button is `confirm_button`.
var sale_prompt: ConfirmPrompt
var confirm_button: Button
var last_valuation: HockshopValuationResult
var last_sell: HockshopSellResult


func setup(p_map: WorldMapController, p_definition: ServiceDefinition, p_point: WorldServicePoint) -> void:
	super.setup(p_map, p_definition, p_point)
	process_mode = Node.PROCESS_MODE_ALWAYS # Hide/disarm during Pause, never advance gameplay.
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.hide()
	ui_layer().add_child(panel)
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(0.07, 0.09, 0.085, 1)
	for side: String in ["left", "right", "top", "bottom"]:
		background.set("content_margin_" + side, 12.0)
	panel.add_theme_stylebox_override("panel", background)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	panel.add_child(_rows)
	_title = _label("", "Title")
	holdings = _label("", "Holdings")
	_goods = VBoxContainer.new()
	_goods.name = "Goods"
	_rows.add_child(_goods)
	selection = _label("请选择随身物品。", "Selection")
	_actions = HBoxContainer.new()
	_rows.add_child(_actions)
	value_button = _button(_actions, "Value", "估价", request_value)
	sell_button = _button(_actions, "Sell", "卖断…", request_confirmation)
	sale_prompt = ConfirmPrompt.new()
	sale_prompt.name = "SaleConfirm"
	sale_prompt.hide()
	_rows.add_child(sale_prompt)
	confirm_button = sale_prompt.confirm_button
	sale_prompt.confirmed.connect(confirm_sale)
	sale_prompt.cancelled.connect(cancel_confirmation)
	feedback = _label("", "Feedback")
	_button(_rows, "Close", "关闭", close_panel)
	panel.visibility_changed.connect(_shared_visibility_changed)


func _label(text: String, node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(label)
	return label


func _button(parent: Node, node_name: String, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func verb() -> String:
	return tr("交易")


func requires_idle() -> bool:
	return true


func interact() -> void:
	if in_reach() and not ExplorationPresentationBlocker.is_blocked(get_tree()):
		# The title in the shown language, put together again on each opening.
		_title.text = tr("%s · 估价 / 卖断") % tr(definition.display_name)
		open_panel(tr(definition.display_name), panel)
		refresh()
		value_button.grab_focus()


func _process(_delta: float) -> void:
	if not is_instance_valid(panel):
		return
	if panel.visible and not in_reach():
		close_panel()
	if panel.visible:
		refresh()


func _physics_process(_delta: float) -> void:
	# UI navigation must not double as walking. Recovery still advances normally.
	if is_instance_valid(panel) and panel.visible:
		map.player_body.quarantine_current_movement_input()


func context() -> MoneyInventoryContext:
	var player: WorldPlayerRuntimeState = map.session.player_runtime()
	return MoneyInventoryContext.new(ItemLifecycleOwnerContext.new(player.character_id, player.state.equipment, player.armor), map.session.inventory_state(), map.session.stack_collection(), map.session.item_instance_index())


func quote(id: StringName) -> HockshopValuationResult:
	return HockshopValuation.appraise(context(), map.session.food_collection(), map.session.liquid_collection(), id)


func equipment_label(id: StringName) -> String:
	var player: WorldPlayerRuntimeState = map.session.player_runtime()
	if player.armor.is_worn(id):
		return "已穿戴"
	var primary: EquippedWeaponRef = player.state.equipment.primary_weapon()
	if primary != null and primary.instance_id == id:
		return "已持用 · 主手"
	var secondary: EquippedWeaponRef = player.state.equipment.secondary_weapon()
	return "已持用 · 副手" if secondary != null and secondary.instance_id == id else "未装备"


func item_label(id: StringName) -> String:
	var item: ItemInstance = map.session.item_instance_index().resolve(id)
	if item == null:
		return String(id)
	var content: ItemContentDefinition = GameContent.catalog().item(item.item_definition_id)
	var display_name: String = String(item.item_definition_id) if content == null else tr(content.display_name)
	if content != null and content.is_stack:
		# A stack is sold whole: 两份蛇药.
		display_name = HeldItemFacts.short_name(id, content, map.session.stack_collection())
	# Two of the same are told apart by their place among the carried ones, not the ID.
	var current: MoneyInventoryContext = context()
	var same: Array[StringName] = []
	for carried: StringName in current.inventory.direct_children(current.endpoint()):
		var other: ItemInstance = current.index.resolve(carried)
		if other != null and other.item_definition_id == item.item_definition_id:
			same.append(carried)
	if same.size() > 1:
		display_name += " #%d" % (same.find(id) + 1)
	return "%s · %s" % [display_name, tr(equipment_label(id))]


func visible_ids() -> Array[StringName]:
	return _ids.duplicate()


func selected_id() -> StringName:
	return _selected_id


func select_item(id: StringName) -> void:
	if not in_reach() or not _ids.has(id) or _pending != null:
		return
	_selected_id = id
	selection.text = item_label(id)
	feedback.text = ""
	refresh()


func refresh() -> void:
	var ids: Array[StringName] = []
	var labels: Array[String] = []
	var money: Array[String] = []
	var current: MoneyInventoryContext = context()
	for id: StringName in current.inventory.direct_children(current.endpoint()):
		var item: ItemInstance = current.index.resolve(id)
		if item == null:
			continue
		var denomination: CurrencyDenomination.Value = GameContent.catalog().denomination_of(item.item_definition_id)
		if denomination != CurrencyDenomination.Value.UNSUPPORTED and current.stacks.has_stack(id):
			var source: ItemContentDefinition = GameContent.catalog().currency_item(denomination)
			# TRANSLATORS: money the player carries: 银子 ×2两.
			money.append(tr("{money} ×{amount}{unit}").format({
				"money": tr(source.display_name), "amount": current.stacks.stack_state(id).amount, "unit": tr(source.base_unit),
			}))
		var appraisal: HockshopValuationResult = quote(id)
		if appraisal.outcome in [HockshopValuationResult.Outcome.SELLABLE, HockshopValuationResult.Outcome.WORTHLESS]:
			ids.append(id)
			labels.append(item_label(id))
	holdings.text = tr("直接携带的钱：%s") % (tr("无") if money.is_empty() else " / ".join(money))
	if ids != _ids or labels != _labels:
		_ids = ids
		_labels = labels
		for child: Node in _goods.get_children():
			_goods.remove_child(child)
			child.queue_free()
		for i: int in range(ids.size()):
			var button: Button = _button(_goods, "Item%d" % i, labels[i], select_item.bind(ids[i]))
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		map.session.shared_ui().refresh_panel_rows()
	if _pending == null and not _ids.has(_selected_id):
		_selected_id = &""
		selection.text = "请选择随身物品。"
	value_button.disabled = _selected_id == &"" or _pending != null
	sell_button.disabled = value_button.disabled or quote(_selected_id).outcome != HockshopValuationResult.Outcome.SELLABLE
	for child: Node in _goods.get_children():
		(child as Button).disabled = _pending != null


func request_value() -> void:
	if not panel.visible or not in_reach() or _pending != null:
		return
	last_valuation = quote(_selected_id)
	feedback.text = valuation_text(last_valuation)
	refresh()


static func valuation_text(result: HockshopValuationResult) -> String:
	if result.outcome == HockshopValuationResult.Outcome.SELLABLE:
		return TranslationServer.translate("价值{value}文 · 卖断可得{payout}文（以实际交付为准）。").format({
			"value": result.source_value, "payout": result.actual_payout,
		})
	if result.outcome == HockshopValuationResult.Outcome.WORTHLESS:
		return TranslationServer.translate("一文不值，不能卖断。")
	return TranslationServer.translate("物品已变化或现在不可交易，请重新选择。")


func _item_state(id: StringName) -> Array[int]:
	var food: FoodState = map.session.food_collection().state(id)
	var liquid: LiquidState = map.session.liquid_collection().state(id)
	return [map.session.inventory_state().own_weight(id), -1 if food == null else food.remaining_portions, -1 if liquid == null else int(liquid.content), -1 if liquid == null else liquid.remaining]


func request_confirmation() -> void:
	if not panel.visible or not in_reach() or _pending != null:
		return
	var appraisal: HockshopValuationResult = quote(_selected_id)
	if appraisal.outcome != HockshopValuationResult.Outcome.SELLABLE:
		feedback.text = valuation_text(appraisal)
		refresh()
		return
	_pending = appraisal
	_pending_state = _item_state(_selected_id)
	_pending_equipment = equipment_label(_selected_id)
	sale_prompt.ask(tr("卖断 {item}\n报价{price}文。物品将永久移除；负重不足可能只收到部分钱款，甚至0文，无退款。").format({
		"item": item_label(_selected_id), "price": appraisal.actual_payout,
	}), "确认卖断（不可撤销）")
	_actions.hide()
	refresh()
	# Deliberate fresh activation: opening confirmation does not execute a sale.
	sale_prompt.focus_default()


func cancel_confirmation() -> void:
	_pending = null
	_pending_state.clear()
	sale_prompt.dismiss()
	_actions.show()
	selection.text = "请选择随身物品。" if _selected_id == &"" else item_label(_selected_id)
	refresh()


func confirm_sale() -> void:
	if _pending == null:
		return
	var confirmed: HockshopValuationResult = _pending
	var current: HockshopValuationResult = quote(confirmed.item_id)
	var unchanged: bool = current.outcome == HockshopValuationResult.Outcome.SELLABLE and current.definition_id == confirmed.definition_id and current.source_value == confirmed.source_value and current.actual_payout == confirmed.actual_payout and _item_state(confirmed.item_id) == _pending_state and equipment_label(confirmed.item_id) == _pending_equipment
	_pending = null # Consume once, including rejection; no callback replay/retry.
	_pending_state.clear()
	sale_prompt.dismiss()
	_actions.show()
	if not panel.visible or not in_reach() or not unchanged:
		feedback.text = "位置或物品状态已变化，未执行卖断；请重新选择。"
		refresh()
		return
	last_sell = HockshopSellService.sell(context(), map.session.food_collection(), map.session.liquid_collection(), map.session.item_id_allocator(), map.session.player_runtime().maximum_encumbrance, confirmed.item_id)
	feedback.text = sell_text(last_sell)
	refresh()


static func sell_text(result: HockshopSellResult) -> String:
	var delivered: int = 0 if result.payout == null else result.payout.delivered_value
	if result.outcome == HockshopSellResult.Outcome.SOLD:
		if delivered < result.valuation.actual_payout:
			return TranslationServer.translate("卖断完成，物品已移除；实际收到%d文。部分钱款因负重不足未能交付，已销毁，不会补发或退款。") % delivered
		return TranslationServer.translate("卖断完成，物品已移除；实际收到%d文。") % delivered
	if result.outcome == HockshopSellResult.Outcome.AUTHORITY_FAILURE:
		return TranslationServer.translate("交易技术异常（阶段{stage}），请停止操作。已交付{delivered}文；物品与钱款以当前实际状态为准，未回滚，请勿重复尝试。").format({
			"stage": result.stage, "delivered": delivered,
		})
	return TranslationServer.translate("卖断未执行，物品状态已变化；请重新选择。")


## Back first cancels a pending sale confirmation, then closes the panel.
func dismiss(content: Control) -> bool:
	if content != panel:
		return false
	if _pending != null:
		cancel_confirmation()
	else:
		close_panel()
	return true


func _shared_visibility_changed() -> void:
	if not panel.visible:
		close_panel()


func close_panel() -> void:
	if not is_instance_valid(panel):
		return
	var was_open: bool = panel.visible
	_pending = null
	_pending_state.clear()
	_selected_id = &""
	sale_prompt.dismiss()
	_actions.show()
	panel.hide()
	map.session.shared_ui().close_business(panel)
	if was_open and is_instance_valid(map.player_body):
		map.player_body.quarantine_current_movement_input()
