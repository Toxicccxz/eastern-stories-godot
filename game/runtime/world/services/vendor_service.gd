class_name VendorService
extends WorldService

## feature/vendor.c `buy` from the vendors[] record the service names.
var panel: PanelContainer
var goods_rows: VBoxContainer
var feedback: Label
var last_purchase: VendorPurchaseResult


func setup(p_map: WorldMapController, p_definition: ServiceDefinition, p_point: WorldServicePoint) -> void:
	super.setup(p_map, p_definition, p_point)
	var catalog: ContentCatalog = GameContent.catalog()
	var vendor: VendorDefinition = catalog.vendor(definition.vendor_id)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.hide()
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Rows"
	panel.add_child(rows)
	var title: Label = _label(rows, "Title")
	goods_rows = VBoxContainer.new()
	goods_rows.name = "Goods"
	rows.add_child(goods_rows)
	feedback = _label(rows, "Feedback")
	var names: Array[String] = []
	for key: String in vendor.goods_keys():
		var content: ItemContentDefinition = catalog.item(vendor.item_definition_id(key))
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 44)
		button.text = goods_label(content)
		button.pressed.connect(request_purchase.bind(key))
		goods_rows.add_child(button)
		names.append(content.display_name)
	title.text = "%s · %s" % [definition.display_name, " / ".join(names)]
	ui_layer().add_child(panel)


func _label(rows: VBoxContainer, node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(label)
	return label


func verb() -> String:
	return tr("补给")


func interact() -> void:
	if in_reach():
		open_panel(context_title(), panel)


func _process(_delta: float) -> void:
	if panel.visible and not in_reach():
		panel.hide()


func request_purchase(goods_key: String) -> VendorPurchaseResult:
	last_purchase = VendorPurchaseResult.new()
	if not in_reach():
		last_purchase.outcome = VendorPurchaseResult.Outcome.INTERACTION_BLOCKED
		return last_purchase
	var catalog: ContentCatalog = GameContent.catalog()
	var player: WorldPlayerRuntimeState = map.player_runtime()
	var context: MoneyInventoryContext = MoneyInventoryContext.new(ItemLifecycleOwnerContext.new(player.character_id, player.state.equipment, player.armor), map.inventory_state(), map.stack_collection(), map.item_instance_index())
	last_purchase = VendorPurchaseService.buy(catalog.vendor(definition.vendor_id), goods_key, catalog, context, map.food_collection(), map.liquid_collection(), map.item_id_allocator(), player.maximum_encumbrance)
	var content: ItemContentDefinition = catalog.item(last_purchase.item_definition_id)
	var goods_name: String = goods_key if content == null else content.display_name
	if last_purchase.delivered:
		feedback.text = tr("已付款，%s已放入你的随身物品。") % goods_name
		if content.liquid_definition() != null and content.fresh_liquid_state().content == LiquidState.Content.RED_WINE:
			feedback.text += tr("酒精饮用暂未开放；可到瀑布换装清水。")
	elif last_purchase.paid:
		feedback.text = tr("已付款，但未收到%s。") % goods_name + (tr("负重过高。") if last_purchase.outcome == VendorPurchaseResult.Outcome.DELIVERY_FAILED else tr("物品状态异常，请停止操作。"))
	elif last_purchase.affordability != null and last_purchase.affordability.outcome == MoneyAffordabilityResult.Outcome.INSUFFICIENT_TOTAL:
		feedback.text = tr("钱不够。")
	elif last_purchase.affordability != null and last_purchase.affordability.outcome == MoneyAffordabilityResult.Outcome.DENOMINATION_REJECTED:
		feedback.text = tr("零钱不足，请先去钱庄兑换。")
	else:
		feedback.text = tr("交易未完成，状态异常；已发生的扣款不会退回。")
	return last_purchase


static func goods_label(content: ItemContentDefinition) -> String:
	var parts: Array[String] = [content.display_name]
	if content.liquid_definition() != null:
		parts.append("%s%d份" % [content.liquid_initial_name, content.fresh_liquid_state().remaining])
	parts.append("%d文" % content.value)
	parts.append("买一%s" % content.unit)
	return " · ".join(parts)
