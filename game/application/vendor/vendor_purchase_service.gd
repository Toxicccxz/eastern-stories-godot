class_name VendorPurchaseService
extends RefCounted

## cmds/std/buy.c -> feature/vendor.c for any goods a vendor lists. The price
## is the goods' own value; money is taken first, then the product is created
## at full weight and moved to the buyer. An undeliverable product is destroyed
## without refund.
static func buy(vendor: VendorDefinition, goods_key: String, catalog: ContentCatalog,
	context: MoneyInventoryContext, foods: FoodCollection, liquids: LiquidCollection,
	allocator: SessionItemIdAllocator, maximum_encumbrance: int) -> VendorPurchaseResult:
	var result: VendorPurchaseResult = VendorPurchaseResult.new()
	result.goods_key = goods_key
	result.outcome = VendorPurchaseResult.Outcome.INVALID_OFFER
	if vendor == null or catalog == null:
		return result
	result.item_definition_id = vendor.item_definition_id(goods_key)
	var content: ItemContentDefinition = catalog.item(result.item_definition_id)
	# buy.c: a price below 1 means the owner will not trade. Money is not goods.
	if content == null or not content.is_valid() or content.is_stack or content.value < 1:
		return result
	result.price = content.value
	result.outcome = VendorPurchaseResult.Outcome.AUTHORITY_FAILURE
	if context == null or not context.is_valid() or foods == null or liquids == null:
		return result
	result.stage = VendorPurchaseResult.Stage.AFFORDABILITY
	result.affordability = MoneyPaymentService.can_afford(context, result.price)
	if result.affordability.outcome != MoneyAffordabilityResult.Outcome.AFFORDABLE:
		result.outcome = VendorPurchaseResult.Outcome.AFFORDABILITY_REJECTED
		return result
	result.stage = VendorPurchaseResult.Stage.PAYMENT
	result.payment = MoneyPaymentService.pay(context, result.price)
	if not result.payment.succeeded():
		result.outcome = VendorPurchaseResult.Outcome.PAYMENT_FAILED
		return result
	result.paid = true
	result.stage = VendorPurchaseResult.Stage.ALLOCATION
	result.outcome = VendorPurchaseResult.Outcome.ALLOCATION_FAILED
	if allocator == null:
		return result
	result.allocation = allocator.allocate(context.inventory)
	if not result.allocation.succeeded:
		return result
	result.item_id = result.allocation.item_instance_id
	result.stage = VendorPurchaseResult.Stage.CREATION
	result.outcome = VendorPurchaseResult.Outcome.CREATION_FAILED
	if context.index.has_snapshot(result.item_id) or context.stacks.has_stack(result.item_id) or foods.state(result.item_id) != null or liquids.state(result.item_id) != null:
		return result
	var item: ItemInstance = ItemInstance.new(result.item_id, content.item_definition_id)
	if not context.inventory.register_item(item, content.own_weight):
		return result
	if not context.index.register_snapshot(item) or not _register_role_state(content, result.item_id, foods, liquids):
		return _cleanup(context, foods, liquids, result)
	result.stage = VendorPurchaseResult.Stage.DELIVERY
	# No pre-payment admission. Source creates the full-weight product now.
	result.transfer = InventoryTransferService.new().transfer(context.inventory, result.item_id,
		InventoryTransferDestination.new(context.endpoint(), true, true, maximum_encumbrance))
	if not result.transfer.succeeded:
		result.outcome = VendorPurchaseResult.Outcome.DELIVERY_FAILED if result.transfer.outcome == InventoryTransferResult.Outcome.CAPACITY_EXCEEDED else VendorPurchaseResult.Outcome.AUTHORITY_FAILURE
		return _cleanup(context, foods, liquids, result)
	result.delivered = true
	result.outcome = VendorPurchaseResult.Outcome.SUCCESS
	result.stage = VendorPurchaseResult.Stage.COMPLETE
	return result


static func _register_role_state(content: ItemContentDefinition, id: StringName,
	foods: FoodCollection, liquids: LiquidCollection) -> bool:
	var food: FoodDefinition = content.food_definition()
	if food != null and not foods.register_state(id, FoodState.new(food.initial_portions, food.initial_value)):
		return false
	if content.liquid_definition() != null and not liquids.register_state(id, content.fresh_liquid_state()):
		return false
	return true


static func _cleanup(context: MoneyInventoryContext, foods: FoodCollection,
	liquids: LiquidCollection, result: VendorPurchaseResult) -> VendorPurchaseResult:
	result.stage = VendorPurchaseResult.Stage.CLEANUP
	result.cleanup = VendorPurchaseCleanupResult.new()
	# Never delete an item whose containment changed unexpectedly.
	if context.inventory.direct_parent(result.item_id) == null:
		result.cleanup.removal = ItemLifecycleService.destroy_item(context.inventory, context.stacks,
			result.item_id, ItemLifecycleResult.ChildDisposition.REQUIRE_LEAF, null)
		if result.cleanup.removal.succeeded:
			var removed: Array[StringName] = result.cleanup.removal.removed_instance_ids
			result.cleanup.food_forgotten = foods.forget_removed(removed, context.inventory)
			result.cleanup.liquid_forgotten = liquids.forget_removed(removed, context.inventory)
			result.cleanup.index_forgotten = context.index.forget_destroyed_snapshots(removed, context.inventory)
	if not result.cleanup.succeeded():
		result.outcome = VendorPurchaseResult.Outcome.AUTHORITY_FAILURE
	return result
