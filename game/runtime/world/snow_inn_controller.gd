class_name SnowInnController
extends SnowResidentMapController

@onready var floor_area: Area2D = %MainFloor
@onready var waiter_marker: Marker2D = $WaiterContact
@onready var shop_panel: Control = $WaiterUI/Panel
@onready var buy_button: Button = $WaiterUI/Panel/Rows/Buy
@onready var shop_feedback: Label = $WaiterUI/Panel/Rows/Feedback
var last_purchase: DumplingPurchaseResult


func _ready() -> void:
	super._ready()
	buy_button.text = "%s · %d文 · 买一个" % [SourceDumpling.DISPLAY_NAME, SourceDumpling.VALUE]
	buy_button.pressed.connect(request_dumpling)
	shop_panel.hide()


func _process(_delta: float) -> void:
	shop_panel.visible = can_purchase_here()


func can_purchase_here() -> bool:
	return is_inside_tree() and _initialized and not get_tree().paused and player_body.player_controlled and _world_simulation_gate.is_open() and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not _player.relationship.is_fighting() and _player.world_location().map_id == map_id() and _player.world_location().zone_id == SnowWorldDefinitions.MAIN_FLOOR_ZONE_ID and player_body.global_position.distance_squared_to(waiter_marker.global_position) <= 96.0 * 96.0 and OldPineMapPlacementValidator.is_valid_character_position(self, SnowWorldDefinitions.MAIN_FLOOR_ZONE_ID, player_body.global_position)


func request_dumpling() -> DumplingPurchaseResult:
	last_purchase = DumplingPurchaseResult.new()
	if not can_purchase_here():
		last_purchase.outcome = DumplingPurchaseResult.Outcome.INTERACTION_BLOCKED
		return last_purchase
	var context: MoneyInventoryContext = MoneyInventoryContext.new(ItemLifecycleOwnerContext.new(_player.character_id, _player.state.equipment, _player.armor), _inventory, _stacks, _item_index)
	last_purchase = DumplingPurchaseService.buy(context, _foods, _item_id_allocator, _player.maximum_encumbrance, OldPineNativeItemDefinitionProjections.create(WorldContentRevision.Value.SOURCE_ENTRY_V1))
	if last_purchase.delivered:
		shop_feedback.text = "已付款，包子已放入你的随身物品。"
	elif last_purchase.paid:
		shop_feedback.text = "已付款，但未收到包子。" + ("负重过高。" if last_purchase.outcome == DumplingPurchaseResult.Outcome.DELIVERY_FAILED else "物品状态异常，请停止操作。")
	elif last_purchase.affordability != null and last_purchase.affordability.outcome == MoneyAffordabilityResult.Outcome.INSUFFICIENT_TOTAL:
		shop_feedback.text = "钱不够。"
	elif last_purchase.affordability != null and last_purchase.affordability.outcome == MoneyAffordabilityResult.Outcome.DENOMINATION_REJECTED:
		shop_feedback.text = "零钱不足，请先去钱庄兑换。"
	else:
		shop_feedback.text = "交易未完成，状态异常；已发生的扣款不会退回。"
	return last_purchase


func map_id() -> StringName:
	return SnowWorldDefinitions.INN_MAP_ID


func default_spawn_id() -> StringName:
	return SnowWorldDefinitions.BIRTH_SPAWN_ID


func local_passages() -> Array[PortalDefinition]:
	return [SnowWorldDefinitions.portal_by_id(SnowWorldDefinitions.INN_EXIT_PORTAL_ID)]
