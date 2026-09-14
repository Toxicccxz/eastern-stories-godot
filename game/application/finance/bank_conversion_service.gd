class_name BankConversionService
extends RefCounted

## std/room/bank.c::do_convert with explicit canonical inputs, no room/UI/parser.
@warning_ignore("integer_division")
static func convert(context: MoneyInventoryContext, allocator: SessionItemIdAllocator,
	maximum_encumbrance: int, from: CurrencyDenomination.Value,
	to: CurrencyDenomination.Value, requested: int) -> BankConversionResult:
	var result: BankConversionResult = BankConversionResult.new()
	var target_content: GDScript = SourceCurrencyDefinitions.source(to)
	if target_content == null:
		result.outcome = BankConversionResult.Outcome.UNSUPPORTED_TARGET
		return result
	var source_content: GDScript = SourceCurrencyDefinitions.source(from)
	if source_content == null:
		result.outcome = BankConversionResult.Outcome.UNSUPPORTED_SOURCE
		return result
	if context == null or not context.is_valid():
		return result
	var source: CurrencyStackSelection = context.select(from)
	var target: CurrencyStackSelection = context.select(to)
	result.source_id = source.item_id
	result.target_id = target.item_id
	if source.outcome == CurrencyStackSelection.Outcome.AUTHORITY_FAILURE or target.outcome == CurrencyStackSelection.Outcome.AUTHORITY_FAILURE:
		return result
	if source.outcome == CurrencyStackSelection.Outcome.ABSENT:
		result.outcome = BankConversionResult.Outcome.SOURCE_MISSING
		return result
	if requested < 1:
		result.outcome = BankConversionResult.Outcome.INVALID_QUANTITY
		return result
	if source.amount < requested:
		result.outcome = BankConversionResult.Outcome.INSUFFICIENT_SOURCE
		return result
	var q: int = requested
	var bv1: int = source_content.BASE_VALUE
	var bv2: int = target_content.BASE_VALUE
	if bv1 < bv2:
		q -= q % (bv2 / bv1)
	result.source_quantity = q
	if q == 0:
		result.outcome = BankConversionResult.Outcome.ROUNDED_TO_ZERO
		return result
	var created: bool = target.outcome == CurrencyStackSelection.Outcome.ABSENT
	if created:
		result.stage = BankConversionResult.Stage.ALLOCATION
		if allocator == null:
			result.outcome = BankConversionResult.Outcome.ALLOCATION_FAILED
			return result
		result.allocation = allocator.allocate(context.inventory)
		if not result.allocation.succeeded:
			result.outcome = BankConversionResult.Outcome.ALLOCATION_FAILED
			return result
		result.target_id = result.allocation.item_instance_id
		result.stage = BankConversionResult.Stage.CREATION
		result.outcome = BankConversionResult.Outcome.CREATION_FAILED
		if context.index.has_snapshot(result.target_id) or context.stacks.has_stack(result.target_id):
			return result
		var item: ItemInstance = ItemInstance.new(result.target_id, target_content.DEFINITION_ID)
		if not context.inventory.register_item(item, 0):
			return result
		if not context.index.register_snapshot(item):
			return _cleanup_failed_creation(context, result)
		result.creation = CombinedStackService.register_stack(context.stacks, context.inventory, item, target_content.stack_definition(), 1)
		if not result.creation.accepted:
			return _cleanup_failed_creation(context, result)
		result.stage = BankConversionResult.Stage.TRANSFER
		var contents: int = context.checked_contents_weight()
		if contents < 0 or CurrencyArithmetic.add(contents, target_content.BASE_WEIGHT) < 0:
			result.outcome = BankConversionResult.Outcome.ARITHMETIC_FAILURE
			return _cleanup_failed_creation(context, result)
		result.transfer = CombinedStackService.transfer_and_merge(context.stacks, context.inventory,
			result.target_id, InventoryTransferDestination.new(context.endpoint(), true, true, maximum_encumbrance),
			null, null, context.owner)
		if not context.index.forget_destroyed_snapshots(result.transfer.absorbed_instance_ids, context.inventory):
			result.outcome = BankConversionResult.Outcome.AUTHORITY_FAILURE
			return result
		if not result.transfer.succeeded and (result.transfer.inventory_transfer == null or result.transfer.inventory_transfer.outcome != InventoryTransferResult.Outcome.CAPACITY_EXCEEDED):
			result.outcome = BankConversionResult.Outcome.AUTHORITY_FAILURE
			return result
	# Multiplication is deliberately at the source set/add argument position,
	# AFTER new()/move(), not a transactional preflight.
	result.stage = BankConversionResult.Stage.TARGET_AMOUNT
	var product: int = CurrencyArithmetic.multiply(q, bv1)
	if product < 0:
		result.outcome = BankConversionResult.Outcome.ARITHMETIC_FAILURE
		return _cleanup_if_undelivered(context, result)
	var k: int = product / bv2
	result.target_quantity = k
	var target_after: int = k if created else CurrencyArithmetic.add(target.amount, k)
	if target_after < 0:
		result.outcome = BankConversionResult.Outcome.ARITHMETIC_FAILURE
		return result
	result.target_change = context.set_amount(result.target_id, target_after)
	if not result.target_change.succeeded():
		result.outcome = BankConversionResult.Outcome.ARITHMETIC_FAILURE if result.target_change.outcome == MoneyMutationResult.Outcome.ARITHMETIC_FAILURE else BankConversionResult.Outcome.AUTHORITY_FAILURE
		return _cleanup_if_undelivered(context, result)
	result.stage = BankConversionResult.Stage.SOURCE_AMOUNT
	# Same-type reads the just-grown stack, not the earlier selection amount.
	var current: CombinedStackState = context.stacks.stack_state(result.source_id)
	if current == null:
		result.outcome = BankConversionResult.Outcome.AUTHORITY_FAILURE
		return _cleanup_if_undelivered(context, result)
	result.source_change = context.set_amount(result.source_id, current.amount - q)
	if not result.source_change.succeeded():
		result.outcome = BankConversionResult.Outcome.ARITHMETIC_FAILURE if result.source_change.outcome == MoneyMutationResult.Outcome.ARITHMETIC_FAILURE else BankConversionResult.Outcome.AUTHORITY_FAILURE
		return _cleanup_if_undelivered(context, result)
	if created and not result.transfer.succeeded:
		result.stage = BankConversionResult.Stage.CLEANUP
		result.outcome = BankConversionResult.Outcome.DELIVERY_FAILED
		return _cleanup_if_undelivered(context, result)
	result.stage = BankConversionResult.Stage.COMPLETE
	result.outcome = BankConversionResult.Outcome.SUCCESS
	return result


static func _cleanup_if_undelivered(context: MoneyInventoryContext, result: BankConversionResult) -> BankConversionResult:
	if result.transfer != null and not result.transfer.succeeded:
		result.cleanup = context.destroy_undelivered(result.target_id)
		if not result.cleanup.succeeded():
			result.outcome = BankConversionResult.Outcome.AUTHORITY_FAILURE
	return result


static func _cleanup_failed_creation(context: MoneyInventoryContext, result: BankConversionResult) -> BankConversionResult:
	result.cleanup = context.destroy_undelivered(result.target_id)
	if not result.cleanup.succeeded():
		result.outcome = BankConversionResult.Outcome.AUTHORITY_FAILURE
	return result
