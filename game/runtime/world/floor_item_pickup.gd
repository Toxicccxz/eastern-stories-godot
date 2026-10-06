class_name FloorItemPickup
extends RefCounted

## cmds/std/get.c `get <item>` for an item lying in the player's room: busy
## first, then whether it is there, then no_get, then feature/move.c's
## encumbrance check; a stack merges into the one the player holds (combined.c).
## Taking it in a fight starts busy(1). A stack too heavy as a whole gives the player
## what still fits (`get <amount> <item>`; the HUD has no amount: DECISIONS 3D) when an
## `allocator` names the part; `taken` then holds how many.
enum Outcome {
	TAKEN,
	INVALID_REQUEST,
	PLAYER_NOT_AVAILABLE,
	BUSY,
	NOT_HERE,
	NO_GET,
	TOO_HEAVY,
	TRANSFER_FAILED,
	## Part of a stack too heavy as a whole (`taken`).
	TAKEN_PART,
}


static func take(
	player: WorldPlayerRuntimeState,
	item_instance_id: StringName,
	world_endpoint: ContainmentEndpoint,
	player_in_reach: bool,
	inventory: InventoryState,
	item_index: WorldItemInstanceIndex,
	stacks: CombinedStackCollection = null,
	allocator: SessionItemIdAllocator = null,
	taken: Array[int] = [],
) -> Outcome:
	if player == null or inventory == null or item_index == null or world_endpoint == null or item_instance_id.is_empty():
		return Outcome.INVALID_REQUEST
	if not player.is_valid() or not player.exists_in_world or player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		return Outcome.PLAYER_NOT_AVAILABLE
	if player.busy.is_busy():
		return Outcome.BUSY
	var item: ItemInstance = item_index.resolve(item_instance_id)
	var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	if content == null or not player_in_reach or not inventory.is_direct_child(item_instance_id, world_endpoint):
		return Outcome.NOT_HERE
	if content.no_get:
		return Outcome.NO_GET
	var destination := InventoryTransferDestination.new(
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id),
		true,
		true,
		player.maximum_encumbrance,
	)
	var transfer: InventoryTransferResult
	if stacks != null and stacks.has_stack(item_instance_id):
		var owner := ItemLifecycleOwnerContext.new(player.character_id, player.state.equipment, player.armor)
		var merged: CombinedStackMergeResult = CombinedStackService.transfer_and_merge(stacks, inventory, item_instance_id, destination, null, null, owner)
		if not item_index.forget_destroyed_snapshots(merged.absorbed_instance_ids, inventory):
			return Outcome.TRANSFER_FAILED
		transfer = merged.inventory_transfer
		if transfer == null or (transfer.succeeded and not merged.succeeded):
			return Outcome.TRANSFER_FAILED
	else:
		transfer = InventoryTransferService.new().transfer(inventory, item_instance_id, destination)
	var outcome: Outcome = Outcome.TAKEN
	if not transfer.succeeded:
		if transfer.outcome != InventoryTransferResult.Outcome.CAPACITY_EXCEEDED:
			return Outcome.TRANSFER_FAILED
		if stacks == null or not stacks.has_stack(item_instance_id) or allocator == null:
			return Outcome.TOO_HEAVY
		outcome = _take_part(player, item, destination, inventory, item_index, stacks, allocator, taken)
		if outcome != Outcome.TAKEN_PART:
			return outcome
	if player.relationship.is_fighting():
		player.busy.start_busy(1)
	return outcome


## Splits off as much of the stack as fits under max_encumbrance and takes it.
@warning_ignore("integer_division")
static func _take_part(
	player: WorldPlayerRuntimeState,
	item: ItemInstance,
	destination: InventoryTransferDestination,
	inventory: InventoryState,
	item_index: WorldItemInstanceIndex,
	stacks: CombinedStackCollection,
	allocator: SessionItemIdAllocator,
	taken: Array[int],
) -> Outcome:
	var definition: CombinedStackDefinition = stacks.stack_definition(item.item_instance_id)
	var amount: int = stacks.stack_state(item.item_instance_id).amount
	var room: int = player.maximum_encumbrance - inventory.contents_weight(destination.endpoint)
	var fit: int = amount if definition.base_weight <= 0 else room / definition.base_weight
	if fit < 1 or fit >= amount:
		return Outcome.TOO_HEAVY
	var allocation: SessionItemIdAllocationResult = allocator.allocate(inventory)
	if not allocation.succeeded:
		return Outcome.TRANSFER_FAILED
	var part := ItemInstance.new(allocation.item_instance_id, item.item_definition_id)
	var split: CombinedStackSplitResult = CombinedStackService.split(stacks, inventory, item.item_instance_id, fit, part)
	if not split.succeeded or not item_index.register_snapshot(part):
		return Outcome.TRANSFER_FAILED
	var owner := ItemLifecycleOwnerContext.new(player.character_id, player.state.equipment, player.armor)
	var merged: CombinedStackMergeResult = CombinedStackService.transfer_and_merge(stacks, inventory, part.item_instance_id, destination, null, null, owner)
	if not item_index.forget_destroyed_snapshots(merged.absorbed_instance_ids, inventory) or not merged.succeeded:
		return Outcome.TRANSFER_FAILED
	taken.append(fit)
	return Outcome.TAKEN_PART
