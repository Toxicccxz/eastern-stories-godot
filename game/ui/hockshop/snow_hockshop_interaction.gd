class_name SnowHockshopInteraction
extends CanvasLayer

## One transient resident-owned view. H2 alone owns appraisal/payout/destruction.
## No merchant, saved UI state, timer, RNG, or duplicated item/equipment authority.
var _session: OldPineWorldSessionController
var _map: SnowOutdoorController
var _presenter: SafeAreaPresenter
var _layout: ResponsivePanelLayout
var _rows: VBoxContainer
var _goods: VBoxContainer
var _actions: HBoxContainer
var _confirm_actions: HBoxContainer
var _pending: HockshopValuationResult
var _pending_state: Array[int] = []
var _pending_equipment: String = ""
var _ids: Array[StringName] = []
var _labels: Array[String] = []
var _door_open: bool = false
var _selected_id: StringName = &""
var contact: Button
var panel: PanelContainer
var feedback: Label
var holdings: Label
var selection: Label
var value_button: Button
var sell_button: Button
var confirm_button: Button
var last_valuation: HockshopValuationResult
var last_sell: HockshopSellResult


func configure(session: OldPineWorldSessionController, map: SnowOutdoorController) -> void:
	_session = session
	_map = map


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Hide/disarm during Pause, never advance gameplay.
	layer = 12
	contact = Button.new()
	contact.name = "Contact"
	contact.custom_minimum_size = Vector2(220, 64)
	contact.pressed.connect(interact)
	add_child(contact)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.hide()
	add_child(panel)
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(0.07, 0.09, 0.085, 1)
	for side: String in ["left", "right", "top", "bottom"]:
		background.set("content_margin_" + side, 12.0)
	panel.add_theme_stylebox_override("panel", background)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	panel.add_child(_rows)
	_label("丰登当铺 · 估价 / 卖断", "Title")
	holdings = _label("", "Holdings")
	_goods = VBoxContainer.new()
	_goods.name = "Goods"
	_rows.add_child(_goods)
	selection = _label("请选择随身物品。", "Selection")
	_actions = HBoxContainer.new()
	_rows.add_child(_actions)
	value_button = _button(_actions, "Value", "估价", request_value)
	sell_button = _button(_actions, "Sell", "卖断…", request_confirmation)
	_confirm_actions = HBoxContainer.new()
	_rows.add_child(_confirm_actions)
	confirm_button = _button(_confirm_actions, "ConfirmSell", "确认卖断（不可撤销）", confirm_sale)
	_button(_confirm_actions, "CancelSale", "取消", cancel_confirmation)
	_confirm_actions.hide()
	feedback = _label("", "Feedback")
	_button(_rows, "Close", "关闭", close_panel)
	_layout = ResponsivePanelLayout.new()
	add_child(_layout)
	_layout.initialize(panel)
	_layout.blocks_touch_gameplay = true
	_layout.dismiss_requested.connect(dismiss)
	panel.add_child(ExplorationPresentationBlocker.new())
	tree_entered.connect(_attach_presenter)
	tree_exiting.connect(_detach_presenter)
	_attach_presenter()
	_process(0.0)


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


func _attach_presenter() -> void:
	_presenter = SafeAreaPresenter.find_or_create(self)
	if not _presenter.metrics_changed.is_connected(_reflow):
		_presenter.metrics_changed.connect(_reflow)
	_reflow(_presenter.current_metrics())


func _detach_presenter() -> void:
	close_panel()
	if is_instance_valid(_presenter) and _presenter.metrics_changed.is_connected(_reflow):
		_presenter.metrics_changed.disconnect(_reflow)
	_presenter = null


func _reflow(metrics: SafeAreaMetrics) -> void:
	if metrics == null:
		return
	_layout.apply(metrics, metrics.content_rect(), true, 620)
	contact.position = metrics.content_rect().position + Vector2(0, 96)
	contact.size = Vector2(minf(300, metrics.content_rect().size.x), 64)


func available() -> bool:
	return is_inside_tree() and _session != null and not get_tree().paused and _session.liquid_interaction_available() and _session.active_map() == _map and not _session.player_runtime().busy.is_busy() and not _session.player_runtime().relationship.is_fighting() and not _session.combat_encounter_coordinator().has_active_encounter()


func can_open_door() -> bool:
	if not available() or _door_open:
		return false
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	return player.world_location().zone_id in [SnowWorldDefinitions.MSTREET3_ZONE_ID, SnowWorldDefinitions.HOCKSHOP_ZONE_ID] and _map.player_body.global_position.distance_squared_to((_map.get_node("Walls/HockshopDoor") as CollisionShape2D).global_position) <= 85.0 * 85.0


func can_trade() -> bool:
	if not available():
		return false
	return _session.player_runtime().world_location().zone_id == SnowWorldDefinitions.HOCKSHOP_ZONE_ID and _map.player_body.global_position.distance_squared_to((_map.get_node("HockshopCounter") as Marker2D).global_position) <= 90.0 * 90.0 and OldPineMapPlacementValidator.is_valid_character_position(_map, SnowWorldDefinitions.HOCKSHOP_ZONE_ID, _map.player_body.global_position)


func door_is_open() -> bool:
	return _door_open


func open_door() -> bool:
	if not can_open_door():
		return false
	# Approved Type B open-only local door; same resident retains it, cold Session does not.
	_door_open = true
	(_map.get_node("Walls/HockshopDoor") as CollisionShape2D).set_deferred("disabled", true)
	(_map.get_node("Ground/HockshopShutter") as Polygon2D).hide()
	return true


func interact() -> void:
	if can_open_door():
		open_door()
	elif can_trade() and not ExplorationPresentationBlocker.is_blocked(get_tree()):
		panel.show()
		refresh()
		value_button.grab_focus()
		_map.player_body.quarantine_current_movement_input()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept") and not event.is_echo() and contact.visible:
		interact()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not is_instance_valid(panel):
		return
	if panel.visible and not can_trade():
		close_panel()
	contact.visible = not panel.visible and available() and not ExplorationPresentationBlocker.is_blocked(get_tree()) and (can_open_door() or can_trade())
	contact.text = "打开当铺木门 [Enter / A]" if can_open_door() else "丰登当铺 · 估价 / 卖断 [Enter / A]"
	if panel.visible:
		refresh()


func _physics_process(_delta: float) -> void:
	# UI navigation must not double as walking. Recovery still advances normally.
	if is_instance_valid(panel) and panel.visible:
		_map.player_body.quarantine_current_movement_input()


func context() -> MoneyInventoryContext:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	return MoneyInventoryContext.new(ItemLifecycleOwnerContext.new(player.character_id, player.state.equipment, player.armor), _session.inventory_state(), _session.stack_collection(), _session.item_instance_index())


func quote(id: StringName) -> HockshopValuationResult:
	return HockshopValuation.appraise(context(), _session.food_collection(), _session.liquid_collection(), id)


func equipment_label(id: StringName) -> String:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	if player.armor.is_worn(id):
		return "已穿戴"
	var primary: EquippedWeaponRef = player.state.equipment.primary_weapon()
	if primary != null and primary.instance_id == id:
		return "已持用 · 主手"
	var secondary: EquippedWeaponRef = player.state.equipment.secondary_weapon()
	return "已持用 · 副手" if secondary != null and secondary.instance_id == id else "未装备"


func item_label(id: StringName) -> String:
	var item: ItemInstance = _session.item_instance_index().resolve(id)
	if item == null:
		return String(id)
	var content: OldPineItemContentDefinition = OldPineItemContentDefinitions.content_by_id(item.item_definition_id)
	var display_name: String = String(item.item_definition_id) if content == null else content.display_name
	var names: Dictionary[StringName, String] = {SourcePlayerCloth.DEFINITION_ID:SourcePlayerCloth.DISPLAY_NAME, SourceDumpling.DEFINITION_ID:SourceDumpling.DISPLAY_NAME, SourceWineskin.DEFINITION_ID:SourceWineskin.DISPLAY_NAME}
	display_name = names.get(item.item_definition_id, display_name)
	return "%s · %s\n%s" % [display_name, equipment_label(id), String(id)]


func visible_ids() -> Array[StringName]:
	return _ids.duplicate()


func selected_id() -> StringName:
	return _selected_id


func select_item(id: StringName) -> void:
	if not can_trade() or not _ids.has(id) or _pending != null:
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
		var denomination: CurrencyDenomination.Value = SourceCurrencyDefinitions.identify(item.item_definition_id)
		if denomination != CurrencyDenomination.Value.UNSUPPORTED and current.stacks.has_stack(id):
			var source: GDScript = SourceCurrencyDefinitions.source(denomination)
			money.append("%s ×%d%s" % [source.DISPLAY_NAME, current.stacks.stack_state(id).amount, source.BASE_UNIT])
		var appraisal: HockshopValuationResult = quote(id)
		if appraisal.outcome in [HockshopValuationResult.Outcome.SELLABLE, HockshopValuationResult.Outcome.WORTHLESS]:
			ids.append(id)
			labels.append(item_label(id))
	holdings.text = "直接携带的钱：" + ("无" if money.is_empty() else " / ".join(money))
	if ids != _ids or labels != _labels:
		_ids = ids
		_labels = labels
		for child: Node in _goods.get_children():
			_goods.remove_child(child)
			child.queue_free()
		for i: int in range(ids.size()):
			var button: Button = _button(_goods, "Item%d" % i, labels[i], select_item.bind(ids[i]))
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_layout.restyle_dynamic_content()
	if _pending == null and not _ids.has(_selected_id):
		_selected_id = &""
		selection.text = "请选择随身物品。"
	value_button.disabled = _selected_id == &"" or _pending != null
	sell_button.disabled = value_button.disabled or quote(_selected_id).outcome != HockshopValuationResult.Outcome.SELLABLE
	for child: Node in _goods.get_children():
		(child as Button).disabled = _pending != null


func request_value() -> void:
	if not panel.visible or not can_trade() or _pending != null:
		return
	last_valuation = quote(_selected_id)
	feedback.text = valuation_text(last_valuation)
	refresh()


static func valuation_text(result: HockshopValuationResult) -> String:
	if result.outcome == HockshopValuationResult.Outcome.SELLABLE:
		return "价值%d文 · 卖断可得%d文（以实际交付为准）。" % [result.source_value, result.actual_payout]
	if result.outcome == HockshopValuationResult.Outcome.WORTHLESS:
		return "一文不值，不能卖断。"
	return "物品已变化或现在不可交易，请重新选择。"


func _item_state(id: StringName) -> Array[int]:
	var food: FoodState = _session.food_collection().state(id)
	var liquid: LiquidState = _session.liquid_collection().state(id)
	return [_session.inventory_state().own_weight(id), -1 if food == null else food.remaining_portions, -1 if liquid == null else int(liquid.content), -1 if liquid == null else liquid.remaining]


func request_confirmation() -> void:
	if not panel.visible or not can_trade() or _pending != null:
		return
	var appraisal: HockshopValuationResult = quote(_selected_id)
	if appraisal.outcome != HockshopValuationResult.Outcome.SELLABLE:
		feedback.text = valuation_text(appraisal)
		refresh()
		return
	_pending = appraisal
	_pending_state = _item_state(_selected_id)
	_pending_equipment = equipment_label(_selected_id)
	selection.text = "卖断 %s\n报价%d文。物品将永久移除；负重不足可能只收到部分钱款，甚至0文，无退款。" % [item_label(_selected_id), appraisal.actual_payout]
	_confirm_actions.show()
	_actions.hide()
	refresh()
	# Deliberate fresh activation: opening confirmation does not execute a sale.
	(_confirm_actions.get_node("CancelSale") as Button).grab_focus()


func cancel_confirmation() -> void:
	_pending = null
	_pending_state.clear()
	_confirm_actions.hide()
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
	_confirm_actions.hide()
	_actions.show()
	if not panel.visible or not can_trade() or not unchanged:
		feedback.text = "位置或物品状态已变化，未执行卖断；请重新选择。"
		refresh()
		return
	last_sell = HockshopSellService.sell(context(), _session.food_collection(), _session.liquid_collection(), _session.item_id_allocator(), _session.player_runtime().maximum_encumbrance, confirmed.item_id)
	feedback.text = sell_text(last_sell)
	refresh()


static func sell_text(result: HockshopSellResult) -> String:
	var delivered: int = 0 if result.payout == null else result.payout.delivered_value
	if result.outcome == HockshopSellResult.Outcome.SOLD:
		var message: String = "卖断完成，物品已移除；实际收到%d文。" % delivered
		if delivered < result.valuation.actual_payout:
			message += " 部分钱款因负重不足未能交付，已销毁，不会补发或退款。"
		return message
	if result.outcome == HockshopSellResult.Outcome.AUTHORITY_FAILURE:
		return "交易技术异常（阶段%d），请停止操作。已交付%d文；物品与钱款以当前实际状态为准，未回滚，请勿重复尝试。" % [result.stage, delivered]
	return "卖断未执行，物品状态已变化；请重新选择。"


func dismiss() -> void:
	if _pending != null:
		cancel_confirmation()
	else:
		close_panel()


func close_panel() -> void:
	if not is_instance_valid(panel):
		return
	var was_open: bool = panel.visible
	_pending = null
	_pending_state.clear()
	_selected_id = &""
	_confirm_actions.hide()
	_actions.show()
	panel.hide()
	if was_open and is_instance_valid(_map.player_body):
		_map.player_body.quarantine_current_movement_input()
