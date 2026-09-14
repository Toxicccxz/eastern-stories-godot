class_name SnowWorkService
extends RefCounted

## One room-specific action, not a job/reward framework. Physical eligibility
## belongs to the caller. No RNG, time, recovery or copied character authority.
static func work(
	character: CharacterState, character_id: StringName, maximum_encumbrance: int,
	armor: ArmorState, inventory: InventoryState, stacks: CombinedStackCollection,
	index: WorldItemInstanceIndex, allocator: SessionItemIdAllocator,
) -> SnowWorkResult:
	var result: SnowWorkResult = SnowWorkResult.new()
	if character == null or character_id.is_empty() or armor == null or inventory == null or stacks == null or index == null or allocator == null or not allocator.is_valid():
		return result
	# LPC has one combined failure response, not separate gin/sen outcomes.
	if character.essence.current < 30 or character.spirit.current < 30:
		result.outcome = SnowWorkResult.Outcome.TOO_TIRED
		return result
	# d/snow/workplace.c::do_work: sen first, gin second, then new silver.
	character.spirit.apply_damage(30)
	character.essence.apply_damage(30)
	result.costs_applied = true
	result.allocation = allocator.allocate(inventory)
	if not result.allocation.succeeded:
		result.outcome = SnowWorkResult.Outcome.ALLOCATION_FAILED
		return result
	result.reward_id = result.allocation.item_instance_id
	var item: ItemInstance = ItemInstance.new(result.reward_id, SourceSilver.DEFINITION_ID)
	result.outcome = SnowWorkResult.Outcome.AUTHORITY_FAILURE
	if not inventory.register_item(item, 0) or not index.register_snapshot(item):
		return result
	if not CombinedStackService.register_stack(stacks, inventory, item, SourceSilver.stack_definition(), 1).accepted:
		return result
	var destination: InventoryTransferDestination = InventoryTransferDestination.new(
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, character_id), true, true, maximum_encumbrance)
	result.transfer = CombinedStackService.transfer_and_merge(stacks, inventory, item.item_instance_id, destination,
		null, null, ItemLifecycleOwnerContext.new(character_id, character.equipment, armor))
	# Lifecycle already removed these absorbed items. This only maintains a derived index.
	if not index.forget_destroyed_snapshots(result.transfer.absorbed_instance_ids, inventory):
		return result
	if result.transfer.succeeded:
		result.outcome = SnowWorkResult.Outcome.SUCCESS
		return result
	if result.transfer.inventory_transfer != null and result.transfer.inventory_transfer.outcome == InventoryTransferResult.Outcome.CAPACITY_EXCEEDED:
		# Owner-approved S2-only substitution: immediate cleanup, no refund/drop/timer.
		result.cleanup = ItemLifecycleService.destroy_item(inventory, stacks, result.reward_id)
		if not result.cleanup.succeeded or not index.forget_destroyed_snapshots(result.cleanup.removed_instance_ids, inventory):
			push_error("Snow work reward lifecycle cleanup failed; no fallback is permitted.")
			return result
		result.outcome = SnowWorkResult.Outcome.DELIVERY_FAILED_CAPACITY
	return result
