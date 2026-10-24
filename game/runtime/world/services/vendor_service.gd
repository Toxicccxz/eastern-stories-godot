class_name VendorService
extends NpcService

## feature/vendor.c `buy` from the vendor NPC's vendors[] record (its `vendor`). Its
## panel is VendorPanel (ui/).
var panel: VendorPanel
var last_purchase: VendorPurchaseResult


func bind_npc(p_map: WorldMapController, p_npc: NpcRuntimeState) -> void:
	super.bind_npc(p_map, p_npc)
	panel = VendorPanel.new()
	panel.hide()
	panel.build_goods(sellable_keys())
	panel.purchase_requested.connect(request_purchase)
	_present()
	ui_layer().add_child(panel)


## The title and the goods in the shown language, put together again on each opening.
func _present() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var vendor: VendorDefinition = catalog.vendor(vendor_id())
	var names: Array[String] = []
	var labels: Dictionary[String, String] = {}
	for key: String in sellable_keys():
		var content: ItemContentDefinition = catalog.item(vendor.item_definition_id(key))
		labels[key] = goods_label(content, vendor.price(key, content))
		names.append(tr(content.display_name))
	panel.present("%s · %s" % [tr(display_name()), " / ".join(names)], labels)


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
	panel.show_purchase(last_purchase, goods_key if content == null else tr(content.display_name))
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
