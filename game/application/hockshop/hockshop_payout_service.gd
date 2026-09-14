class_name HockshopPayoutService
extends RefCounted


## std/room/hockshop.c::pay_player, after validated sell arithmetic.
## Synchronous/non-atomic. No Bank conversion, preflight capacity or rollback.
@warning_ignore("integer_division")
static func pay(context: MoneyInventoryContext, allocator: SessionItemIdAllocator,
	maximum_encumbrance: int, amount: int) -> HockshopPayoutResult:
	var result: HockshopPayoutResult = HockshopPayoutResult.new()
	result.requested_value = amount
	if context == null or not context.is_valid() or allocator == null or amount < 1:
		return result
	for denomination: CurrencyDenomination.Value in [CurrencyDenomination.Value.SILVER, CurrencyDenomination.Value.COIN]:
		var quantity: int = amount / 100 if denomination == CurrencyDenomination.Value.SILVER else amount % 100
		if quantity == 0:
			continue
		var attempt: HockshopPayoutAttempt = HockshopPayoutAttempt.new()
		attempt.denomination = denomination
		attempt.quantity = quantity
		result.attempts.append(attempt)
		attempt.allocation = allocator.allocate(context.inventory)
		if not attempt.allocation.succeeded:
			return result
		attempt.item_id = attempt.allocation.item_instance_id
		attempt.stage = HockshopPayoutAttempt.Stage.CREATION
		var content: GDScript = SourceCurrencyDefinitions.source(denomination)
		var weight: int = CurrencyArithmetic.multiply(quantity, content.BASE_WEIGHT)
		if weight < 0 or context.index.has_snapshot(attempt.item_id) or context.stacks.has_stack(attempt.item_id):
			return result
		var item: ItemInstance = ItemInstance.new(attempt.item_id, content.DEFINITION_ID)
		if not context.inventory.register_item(item, 0) or not context.index.register_snapshot(item):
			return result
		attempt.creation = CombinedStackService.register_stack(context.stacks, context.inventory, item, content.stack_definition(), quantity)
		if not attempt.creation.accepted:
			return result
		attempt.stage = HockshopPayoutAttempt.Stage.ADMISSION
		# Arithmetic/association defense, NOT capacity preflight. All direct matching
		# siblings matter for Combined's sum (finance.select sees only one).
		if not _safe_admission(context, content, quantity, weight):
			return result
		attempt.transfer = CombinedStackService.transfer_and_merge(context.stacks, context.inventory,
			attempt.item_id, InventoryTransferDestination.new(context.endpoint(), true, true, maximum_encumbrance),
			null, null, context.owner)
		attempt.delivered = attempt.transfer.inventory_transfer != null and attempt.transfer.inventory_transfer.succeeded
		if attempt.delivered:
			result.delivered_value += quantity * content.BASE_VALUE
		attempt.absorbed_index_forgotten = context.index.forget_destroyed_snapshots(attempt.transfer.absorbed_instance_ids, context.inventory)
		if not attempt.absorbed_index_forgotten:
			return result
		if not attempt.transfer.succeeded:
			attempt.capacity_rejected = attempt.transfer.inventory_transfer != null and attempt.transfer.inventory_transfer.outcome == InventoryTransferResult.Outcome.CAPACITY_EXCEEDED
			if not attempt.capacity_rejected:
				return result
			# H2 I ONLY: immediate cleanup before next denomination, no refund/reuse.
			attempt.stage = HockshopPayoutAttempt.Stage.CLEANUP
			attempt.cleanup = context.destroy_undelivered(attempt.item_id)
			if not attempt.cleanup.succeeded():
				return result
		attempt.stage = HockshopPayoutAttempt.Stage.COMPLETE
	result.outcome = HockshopPayoutResult.Outcome.COMPLETE
	return result


static func _safe_admission(context: MoneyInventoryContext, content: GDScript, quantity: int, weight: int) -> bool:
	var contents: int = context.checked_contents_weight()
	if contents < 0 or CurrencyArithmetic.add(contents, weight) < 0:
		return false
	var total: int = quantity
	for id: StringName in context.inventory.direct_children(context.endpoint()):
		var item: ItemInstance = context.index.resolve(id)
		if item == null:
			return false
		if item.item_definition_id != content.DEFINITION_ID:
			continue
		var state: CombinedStackState = context.stacks.stack_state(id)
		var definition: CombinedStackDefinition = context.stacks.stack_definition(id)
		if state == null or definition == null or definition.item_definition_id != content.DEFINITION_ID or definition.base_weight != content.BASE_WEIGHT or definition.stack_compatibility_id != content.stack_definition().stack_compatibility_id:
			return false
		var old_weight: int = CurrencyArithmetic.multiply(state.amount, content.BASE_WEIGHT)
		if old_weight < 0 or context.inventory.own_weight(id) != old_weight:
			return false
		total = CurrencyArithmetic.add(total, state.amount)
		if total < 0 or CurrencyArithmetic.multiply(total, content.BASE_WEIGHT) < 0:
			return false
	return true
