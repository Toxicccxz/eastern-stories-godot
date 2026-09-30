class_name SnowInnController
extends SnowResidentMapController

## d/snow/npc/waiter.c stands in this map; his goods come from the vendor data.
const WAITER_VENDOR_ID: StringName = &"snow.vendor.waiter"

@onready var floor_area: Area2D = %MainFloor
@onready var waiter_marker: Marker2D = $WaiterContact
@onready var shop_panel: Control = $WaiterUI/Panel
@onready var shop_title: Label = $WaiterUI/Panel/Rows/Title
@onready var goods_rows: VBoxContainer = $WaiterUI/Panel/Rows/Goods
@onready var shop_feedback: Label = $WaiterUI/Panel/Rows/Feedback
var last_purchase: VendorPurchaseResult


func _ready() -> void:
	super._ready()
	var catalog: ContentCatalog = GameContent.catalog()
	var vendor: VendorDefinition = catalog.vendor(WAITER_VENDOR_ID)
	var names: Array[String] = []
	var goods_keys: Array[String] = []
	if vendor != null:
		goods_keys = vendor.goods_keys()
	for key: String in goods_keys:
		var content: ItemContentDefinition = catalog.item(vendor.item_definition_id(key))
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 44)
		button.text = _goods_label(content)
		button.pressed.connect(request_purchase.bind(key))
		goods_rows.add_child(button)
		names.append(content.display_name)
	shop_title.text = "店小二 · " + " / ".join(names)
	shop_panel.hide()


func _process(_delta: float) -> void:
	if shop_panel.visible and not can_purchase_here():
		shop_panel.hide()


func can_purchase_here() -> bool:
	return is_inside_tree() and _initialized and not get_tree().paused and player_body.player_controlled and _world_simulation_gate.is_open() and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not _player.relationship.is_fighting() and _player.world_location().map_id == map_id() and _player.world_location().zone_id == SnowWorldDefinitions.MAIN_FLOOR_ZONE_ID and player_body.global_position.distance_squared_to(waiter_marker.global_position) <= 96.0 * 96.0 and OldPineMapPlacementValidator.is_valid_character_position(self, SnowWorldDefinitions.MAIN_FLOOR_ZONE_ID, player_body.global_position)


func request_purchase(goods_key: String) -> VendorPurchaseResult:
	last_purchase = VendorPurchaseResult.new()
	if not can_purchase_here():
		last_purchase.outcome = VendorPurchaseResult.Outcome.INTERACTION_BLOCKED
		return last_purchase
	var catalog: ContentCatalog = GameContent.catalog()
	var context: MoneyInventoryContext = MoneyInventoryContext.new(ItemLifecycleOwnerContext.new(_player.character_id, _player.state.equipment, _player.armor), _inventory, _stacks, _item_index)
	last_purchase = VendorPurchaseService.buy(catalog.vendor(WAITER_VENDOR_ID), goods_key, catalog, context, _foods, _liquids, _item_id_allocator, _player.maximum_encumbrance)
	var content: ItemContentDefinition = catalog.item(last_purchase.item_definition_id)
	var goods_name: String = goods_key if content == null else content.display_name
	if last_purchase.delivered:
		shop_feedback.text = "已付款，%s已放入你的随身物品。" % goods_name
		if content.liquid_definition() != null and content.fresh_liquid_state().content == LiquidState.Content.RED_WINE:
			shop_feedback.text += "酒精饮用暂未开放；可到瀑布换装清水。"
	elif last_purchase.paid:
		shop_feedback.text = "已付款，但未收到%s。" % goods_name + ("负重过高。" if last_purchase.outcome == VendorPurchaseResult.Outcome.DELIVERY_FAILED else "物品状态异常，请停止操作。")
	elif last_purchase.affordability != null and last_purchase.affordability.outcome == MoneyAffordabilityResult.Outcome.INSUFFICIENT_TOTAL:
		shop_feedback.text = "钱不够。"
	elif last_purchase.affordability != null and last_purchase.affordability.outcome == MoneyAffordabilityResult.Outcome.DENOMINATION_REJECTED:
		shop_feedback.text = "零钱不足，请先去钱庄兑换。"
	else:
		shop_feedback.text = "交易未完成，状态异常；已发生的扣款不会退回。"
	return last_purchase


static func _goods_label(content: ItemContentDefinition) -> String:
	var parts: Array[String] = [content.display_name]
	if content.liquid_definition() != null:
		parts.append("%s%d份" % [content.liquid_initial_name, content.fresh_liquid_state().remaining])
	parts.append("%d文" % content.value)
	parts.append("买一%s" % content.unit)
	return " · ".join(parts)


func map_id() -> StringName:
	return SnowWorldDefinitions.INN_MAP_ID


func default_spawn_id() -> StringName:
	return SnowWorldDefinitions.BIRTH_SPAWN_ID


func local_passages() -> Array[PortalDefinition]:
	return [GameContent.catalog().portal(SnowWorldDefinitions.INN_EXIT_PORTAL_ID)]
