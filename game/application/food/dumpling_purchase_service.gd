class_name DumplingPurchaseService
extends RefCounted

## buy.c -> vendor.c, scoped to the one approved offer. Money remains S3B.
static func buy(context: MoneyInventoryContext, foods: FoodCollection,
	allocator: SessionItemIdAllocator, maximum_encumbrance: int,
	definitions: NativeItemDefinitionProjections) -> DumplingPurchaseResult:
	var result: DumplingPurchaseResult = DumplingPurchaseResult.new()
	result.outcome = DumplingPurchaseResult.Outcome.INVALID_OFFER
	if definitions == null or not definitions.is_valid:
		return result
	var item_definition: ItemDefinition = definitions.item_definition(SourceDumpling.DEFINITION_ID)
	var food: FoodDefinition = definitions.food_definition(SourceDumpling.DEFINITION_ID)
	if item_definition == null or item_definition.legacy_source_path != SourceDumpling.LEGACY_SOURCE_PATH or food == null or food.initial_portions != SourceDumpling.PORTIONS or food.food_supply != SourceDumpling.FOOD_SUPPLY or food.initial_value != SourceDumpling.VALUE or food.own_weight != SourceDumpling.OWN_WEIGHT:
		return result
	result.price = food.initial_value
	result.outcome = DumplingPurchaseResult.Outcome.AUTHORITY_FAILURE
	if context == null or not context.is_valid() or foods == null:
		return result
	result.stage = DumplingPurchaseResult.Stage.AFFORDABILITY
	result.affordability = MoneyPaymentService.can_afford(context, result.price)
	if result.affordability.outcome != MoneyAffordabilityResult.Outcome.AFFORDABLE:
		result.outcome = DumplingPurchaseResult.Outcome.AFFORDABILITY_REJECTED
		return result
	result.stage = DumplingPurchaseResult.Stage.PAYMENT
	result.payment = MoneyPaymentService.pay(context, result.price)
	if not result.payment.succeeded():
		result.outcome = DumplingPurchaseResult.Outcome.PAYMENT_FAILED
		return result
	result.paid = true
	result.stage = DumplingPurchaseResult.Stage.ALLOCATION
	result.outcome = DumplingPurchaseResult.Outcome.ALLOCATION_FAILED
	if allocator == null:
		return result
	result.allocation = allocator.allocate(context.inventory)
	if not result.allocation.succeeded:
		return result
	result.item_id = result.allocation.item_instance_id
	result.stage = DumplingPurchaseResult.Stage.CREATION
	result.outcome = DumplingPurchaseResult.Outcome.CREATION_FAILED
	if context.index.has_snapshot(result.item_id) or context.stacks.has_stack(result.item_id) or foods.state(result.item_id) != null:
		return result
	var item: ItemInstance = ItemInstance.new(result.item_id, item_definition.item_definition_id)
	if not context.inventory.register_item(item, food.own_weight):
		return result
	if not context.index.register_snapshot(item) or not foods.register_state(result.item_id, FoodState.new(food.initial_portions, food.initial_value)):
		return _cleanup(context, foods, result)
	result.stage = DumplingPurchaseResult.Stage.DELIVERY
	# No pre-payment admission. Source creates the full-weight product now.
	result.transfer = InventoryTransferService.new().transfer(context.inventory, result.item_id,
		InventoryTransferDestination.new(context.endpoint(), true, true, maximum_encumbrance))
	if not result.transfer.succeeded:
		result.outcome = DumplingPurchaseResult.Outcome.DELIVERY_FAILED if result.transfer.outcome == InventoryTransferResult.Outcome.CAPACITY_EXCEEDED else DumplingPurchaseResult.Outcome.AUTHORITY_FAILURE
		return _cleanup(context, foods, result)
	result.delivered = true
	result.outcome = DumplingPurchaseResult.Outcome.SUCCESS
	result.stage = DumplingPurchaseResult.Stage.COMPLETE
	return result


static func _cleanup(context: MoneyInventoryContext, foods: FoodCollection,
	result: DumplingPurchaseResult) -> DumplingPurchaseResult:
	result.stage = DumplingPurchaseResult.Stage.CLEANUP
	# Never delete an item whose containment changed unexpectedly.
	result.cleanup = FoodItemLifecycle.remove(context, foods, result.item_id, true)
	if not result.cleanup.succeeded():
		result.outcome = DumplingPurchaseResult.Outcome.AUTHORITY_FAILURE
	return result
