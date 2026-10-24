class_name HockshopService
extends WorldService

## inherit HOCKSHOP (d/snow/hockshop.c): value and sell carried goods. One
## transient view; H2 alone owns appraisal/payout/destruction. No merchant,
## saved UI state, timer, RNG, or duplicated item/equipment authority. Its panel is
## HockshopPanel (ui/).
var _pending: HockshopValuationResult
var _pending_state: Array[int] = []
var _pending_equipment: String = ""
var _ids: Array[StringName] = []
var _labels: Array[String] = []
var _selected_id: StringName = &""
var panel: HockshopPanel
var last_valuation: HockshopValuationResult
var last_sell: HockshopSellResult


func setup(p_map: WorldMapController, p_definition: ServiceDefinition, p_point: WorldServicePoint) -> void:
	super.setup(p_map, p_definition, p_point)
	process_mode = Node.PROCESS_MODE_ALWAYS # Hide/disarm during Pause, never advance gameplay.
	panel = HockshopPanel.new()
	panel.hide()
	ui_layer().add_child(panel)
	panel.item_selected.connect(select_item)
	panel.value_requested.connect(request_value)
	panel.sell_requested.connect(request_confirmation)
	panel.sale_confirmed.connect(confirm_sale)
	panel.sale_cancelled.connect(cancel_confirmation)
	panel.close_requested.connect(close_panel)
	panel.visibility_changed.connect(_shared_visibility_changed)


func verb() -> String:
	return tr("交易")


func requires_idle() -> bool:
	return true


func interact() -> void:
	if in_reach() and panel_may_open():
		# The title in the shown language, put together again on each opening.
		panel.title.text = tr("%s · 估价 / 卖断") % tr(definition.display_name)
		open_panel(tr(definition.display_name), panel)
		refresh()
		panel.value_button.grab_focus()


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
	panel.show_selection(item_label(id))
	panel.feedback.text = ""
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
	panel.holdings.text = tr("直接携带的钱：%s") % (tr("无") if money.is_empty() else " / ".join(money))
	if ids != _ids or labels != _labels:
		_ids = ids
		_labels = labels
		panel.show_goods(ids, labels)
		map.session.shared_ui().refresh_panel_rows()
	if _pending == null and not _ids.has(_selected_id):
		_selected_id = &""
		panel.show_selection("")
	var can_value: bool = _selected_id != &"" and _pending == null
	panel.enable(can_value, can_value and quote(_selected_id).outcome == HockshopValuationResult.Outcome.SELLABLE, _pending == null)


func request_value() -> void:
	if not panel.visible or not in_reach() or _pending != null:
		return
	last_valuation = quote(_selected_id)
	panel.feedback.text = HockshopPanel.valuation_text(last_valuation)
	refresh()


func _item_state(id: StringName) -> Array[int]:
	var food: FoodState = map.session.food_collection().state(id)
	var liquid: LiquidState = map.session.liquid_collection().state(id)
	return [map.session.inventory_state().own_weight(id), -1 if food == null else food.remaining_portions, -1 if liquid == null else int(liquid.content), -1 if liquid == null else liquid.remaining]


func request_confirmation() -> void:
	if not panel.visible or not in_reach() or _pending != null:
		return
	var appraisal: HockshopValuationResult = quote(_selected_id)
	if appraisal.outcome != HockshopValuationResult.Outcome.SELLABLE:
		panel.feedback.text = HockshopPanel.valuation_text(appraisal)
		refresh()
		return
	_pending = appraisal
	_pending_state = _item_state(_selected_id)
	_pending_equipment = equipment_label(_selected_id)
	# The question names the item: the selection line waits.
	panel.ask_sale(tr("卖断 {item}\n报价{price}文。物品将永久移除；负重不足可能只收到部分钱款，甚至0文，无退款。").format({
		"item": item_label(_selected_id), "price": appraisal.actual_payout,
	}))
	refresh()
	# Deliberate fresh activation: opening confirmation does not execute a sale.
	panel.sale_prompt.focus_default()


func cancel_confirmation() -> void:
	_pending = null
	_pending_state.clear()
	panel.end_sale()
	panel.show_selection("" if _selected_id == &"" else item_label(_selected_id))
	refresh()


func confirm_sale() -> void:
	if _pending == null:
		return
	var confirmed: HockshopValuationResult = _pending
	var current: HockshopValuationResult = quote(confirmed.item_id)
	var unchanged: bool = current.outcome == HockshopValuationResult.Outcome.SELLABLE and current.definition_id == confirmed.definition_id and current.source_value == confirmed.source_value and current.actual_payout == confirmed.actual_payout and _item_state(confirmed.item_id) == _pending_state and equipment_label(confirmed.item_id) == _pending_equipment
	_pending = null # Consume once, including rejection; no callback replay/retry.
	_pending_state.clear()
	panel.end_sale()
	if not panel.visible or not in_reach() or not unchanged:
		panel.feedback.text = "位置或物品状态已变化，未执行卖断；请重新选择。"
		refresh()
		return
	last_sell = HockshopSellService.sell(context(), map.session.food_collection(), map.session.liquid_collection(), map.session.item_id_allocator(), map.session.player_runtime().maximum_encumbrance, confirmed.item_id)
	panel.feedback.text = HockshopPanel.sell_text(last_sell)
	refresh()


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
	panel.end_sale()
	panel.hide()
	map.session.shared_ui().close_business(panel)
	if was_open and is_instance_valid(map.player_body):
		map.player_body.quarantine_current_movement_input()
