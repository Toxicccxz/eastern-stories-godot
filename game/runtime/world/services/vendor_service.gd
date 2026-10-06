class_name VendorService
extends NpcService

## feature/vendor.c `buy` from the vendor NPC's vendors[] record (its `vendor`).
var panel: PanelContainer
var goods_rows: VBoxContainer
var feedback: Label
var last_purchase: VendorPurchaseResult
var _title: Label
var _goods_buttons: Dictionary[String, Button] = {}


func bind_npc(p_map: WorldMapController, p_npc: NpcRuntimeState) -> void:
	super.bind_npc(p_map, p_npc)
	var catalog: ContentCatalog = GameContent.catalog()
	var vendor: VendorDefinition = catalog.vendor(vendor_id())
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.hide()
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Rows"
	panel.add_child(rows)
	_title = _label(rows, "Title")
	goods_rows = VBoxContainer.new()
	goods_rows.name = "Goods"
	rows.add_child(goods_rows)
	feedback = _label(rows, "Feedback")
	for key: String in sellable_keys():
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(request_purchase.bind(key))
		goods_rows.add_child(button)
		_goods_buttons[key] = button
	_present()
	ui_layer().add_child(panel)


## The title and the goods in the shown language, put together again on each opening.
func _present() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var vendor: VendorDefinition = catalog.vendor(vendor_id())
	var names: Array[String] = []
	for key: String in sellable_keys():
		var content: ItemContentDefinition = catalog.item(vendor.item_definition_id(key))
		_goods_buttons[key].text = goods_label(content, vendor.price(key, content))
		names.append(tr(content.display_name))
	_title.text = "%s · %s" % [tr(display_name()), " / ".join(names)]


## The goods buy.c sells: vendor.c lists one priced 0 (0两黄金, the weapon shop's 飞镖)
## that buy.c then refuses. Deviation (owner, modern fixes): such goods are not listed.
func sellable_keys() -> Array[String]:
	var catalog: ContentCatalog = GameContent.catalog()
	var vendor: VendorDefinition = catalog.vendor(vendor_id())
	var keys: Array[String] = []
	for key: String in vendor.goods_keys():
		if vendor.sells(key, catalog.item(vendor.item_definition_id(key))):
			keys.append(key)
	return keys


func _label(rows: VBoxContainer, node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(label)
	return label


func vendor_id() -> StringName:
	return npc.definition().dealings().vendor_id


func verb() -> String:
	return tr("购买")


func interact() -> void:
	if in_reach():
		_present()
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
	last_purchase = VendorPurchaseService.buy(catalog.vendor(vendor_id()), goods_key, catalog, context, map.food_collection(), map.liquid_collection(), map.item_id_allocator(), player.maximum_encumbrance)
	var content: ItemContentDefinition = catalog.item(last_purchase.item_definition_id)
	var goods_name: String = goods_key if content == null else tr(content.display_name)
	if last_purchase.delivered:
		feedback.text = tr("已付款，%s已放入你的随身物品。") % goods_name
		if content.liquid_definition() != null and content.fresh_liquid_state().content == LiquidState.Content.RED_WINE:
			feedback.text += tr("酒精饮用暂未开放；可到瀑布换装清水。")
	elif last_purchase.paid:
		feedback.text = tr("已付款，但未收到%s。") % goods_name + (tr("负重过高。") if last_purchase.outcome == VendorPurchaseResult.Outcome.DELIVERY_FAILED else tr("物品状态异常，请停止操作。"))
	# buy.c: can_afford() 0 and 2.
	elif last_purchase.affordability != null and last_purchase.affordability.outcome == MoneyAffordabilityResult.Outcome.INSUFFICIENT_TOTAL:
		feedback.text = "你的钱不够。"
	elif last_purchase.affordability != null and last_purchase.affordability.outcome == MoneyAffordabilityResult.Outcome.DENOMINATION_REJECTED:
		feedback.text = "你没有足够的零钱，而对方也找不开...。"
	else:
		feedback.text = "交易未完成，状态异常；已发生的扣款不会退回。"
	return last_purchase


## In the shown language.
static func goods_label(content: ItemContentDefinition, price: int) -> String:
	var parts: Array[String] = [TranslationServer.translate(content.display_name)]
	if content.liquid_definition() != null:
		# TRANSLATORS: what a container holds when it is sold: 红酒15份.
		parts.append(TranslationServer.translate("{liquid}{portions}份").format({
			"liquid": TranslationServer.translate(content.liquid_initial_name), "portions": content.fresh_liquid_state().remaining,
		}))
	parts.append(price_string(price))
	parts.append(TranslationServer.translate("买一%s") % TranslationServer.translate(content.unit))
	return " · ".join(parts)


## feature/vendor.c price_string(), as `list` shows a price, in the shown language.
@warning_ignore("integer_division")
static func price_string(value: int) -> String:
	if value % 10000 == 0:
		return TranslationServer.translate("%d两黄金") % (value / 10000)
	if value % 100 == 0:
		return TranslationServer.translate("%d两银子") % (value / 100)
	return TranslationServer.translate("%d文钱") % value
