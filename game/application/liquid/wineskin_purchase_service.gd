class_name WineskinPurchaseService
extends RefCounted

## Scoped second waiter offer. S6B explicitly adopts Vendor cleanup, not Bank's policy.
static func buy(context: MoneyInventoryContext, liquids: LiquidCollection,
	allocator: SessionItemIdAllocator, maximum_encumbrance: int,
	definitions: NativeItemDefinitionProjections) -> WineskinPurchaseResult:
	var result: WineskinPurchaseResult = WineskinPurchaseResult.new()
	result.outcome = WineskinPurchaseResult.Outcome.INVALID_OFFER
	if definitions == null or not definitions.is_valid:
		return result
	var item_definition: ItemDefinition = definitions.item_definition(SourceWineskin.DEFINITION_ID)
	var liquid: LiquidDefinition = definitions.liquid_definition(SourceWineskin.DEFINITION_ID)
	if item_definition == null or item_definition.legacy_source_path != SourceWineskin.LEGACY_SOURCE_PATH or not SourceWineskin.is_canonical(liquid):
		return result
	# The restriction describes this authored product, not all liquid definitions.
	if definitions.food_definition(SourceWineskin.DEFINITION_ID) != null or definitions.weapon_definition(SourceWineskin.DEFINITION_ID) != null or definitions.armor_definition(SourceWineskin.DEFINITION_ID) != null or definitions.stack_definition(SourceWineskin.DEFINITION_ID) != null:
		return result
	result.price = liquid.value
	result.outcome = WineskinPurchaseResult.Outcome.AUTHORITY_FAILURE
	if context == null or not context.is_valid() or liquids == null:
		return result
	result.stage = WineskinPurchaseResult.Stage.AFFORDABILITY
	result.affordability = MoneyPaymentService.can_afford(context, result.price)
	if result.affordability.outcome != MoneyAffordabilityResult.Outcome.AFFORDABLE:
		result.outcome = WineskinPurchaseResult.Outcome.AFFORDABILITY_REJECTED
		return result
	result.stage = WineskinPurchaseResult.Stage.PAYMENT
	result.payment = MoneyPaymentService.pay(context, result.price)
	if not result.payment.succeeded():
		result.outcome = WineskinPurchaseResult.Outcome.PAYMENT_FAILED
		return result
	result.paid = true
	result.stage = WineskinPurchaseResult.Stage.ALLOCATION
	result.outcome = WineskinPurchaseResult.Outcome.ALLOCATION_FAILED
	if allocator == null:
		return result
	result.allocation = allocator.allocate(context.inventory)
	if not result.allocation.succeeded:
		return result
	result.item_id = result.allocation.item_instance_id
	result.stage = WineskinPurchaseResult.Stage.CREATION
	result.outcome = WineskinPurchaseResult.Outcome.CREATION_FAILED
	if context.index.has_snapshot(result.item_id) or context.stacks.has_stack(result.item_id) or liquids.state(result.item_id) != null:
		return result
	var item: ItemInstance = ItemInstance.new(result.item_id, item_definition.item_definition_id)
	if not context.inventory.register_item(item, liquid.own_weight):
		return result
	if not context.index.register_snapshot(item) or not liquids.register_state(result.item_id, SourceWineskin.fresh_state()):
		return _cleanup(context, liquids, result)
	result.stage = WineskinPurchaseResult.Stage.DELIVERY
	result.transfer = InventoryTransferService.new().transfer(context.inventory, result.item_id,
		InventoryTransferDestination.new(context.endpoint(), true, true, maximum_encumbrance))
	if not result.transfer.succeeded:
		result.outcome = WineskinPurchaseResult.Outcome.DELIVERY_FAILED if result.transfer.outcome == InventoryTransferResult.Outcome.CAPACITY_EXCEEDED else WineskinPurchaseResult.Outcome.AUTHORITY_FAILURE
		return _cleanup(context, liquids, result)
	result.delivered = true
	result.outcome = WineskinPurchaseResult.Outcome.SUCCESS
	result.stage = WineskinPurchaseResult.Stage.COMPLETE
	return result


static func _cleanup(context: MoneyInventoryContext, liquids: LiquidCollection,
	result: WineskinPurchaseResult) -> WineskinPurchaseResult:
	result.stage = WineskinPurchaseResult.Stage.CLEANUP
	result.cleanup = LiquidItemLifecycle.remove(context, liquids, result.item_id, true)
	if not result.cleanup.succeeded():
		result.outcome = WineskinPurchaseResult.Outcome.AUTHORITY_FAILURE
	return result
