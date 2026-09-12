class_name MoneyInventoryContext
extends RefCounted

## Borrowed authorities for one synchronous call. No owned graph/cached balance.
var owner: ItemLifecycleOwnerContext
var inventory: InventoryState
var stacks: CombinedStackCollection
var index: WorldItemInstanceIndex


func _init(p_owner: ItemLifecycleOwnerContext, p_inventory: InventoryState, p_stacks: CombinedStackCollection, p_index: WorldItemInstanceIndex) -> void:
	owner = p_owner
	inventory = p_inventory
	stacks = p_stacks
	index = p_index


func is_valid() -> bool:
	return owner != null and owner.is_complete() and inventory != null and stacks != null and index != null


func endpoint() -> ContainmentEndpoint:
	return ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, owner.character_id)


func select(denomination: CurrencyDenomination.Value) -> CurrencyStackSelection:
	var result: CurrencyStackSelection = CurrencyStackSelection.new()
	var content: GDScript = SourceCurrencyDefinitions.source(denomination)
	if not is_valid() or content == null:
		result.outcome = CurrencyStackSelection.Outcome.AUTHORITY_FAILURE
		return result
	# direct_children supplies ascending String(instance_id) order, independent of insertion.
	for id: StringName in inventory.direct_children(endpoint()):
		var item: ItemInstance = index.resolve(id)
		if item == null:
			result.outcome = CurrencyStackSelection.Outcome.AUTHORITY_FAILURE
			return result
		if item.item_definition_id != content.DEFINITION_ID:
			continue
		result.item_id = id
		var state: CombinedStackState = stacks.stack_state(id)
		var definition: CombinedStackDefinition = stacks.stack_definition(id)
		if state == null or state.amount < 0 or definition == null or definition.item_definition_id != item.item_definition_id or definition.base_weight != content.BASE_WEIGHT or definition.stack_compatibility_id != content.stack_definition().stack_compatibility_id:
			result.outcome = CurrencyStackSelection.Outcome.AUTHORITY_FAILURE
			return result
		result.outcome = CurrencyStackSelection.Outcome.FOUND
		result.amount = state.amount
		return result
	return result


## Check represented nonnegative weight sums before calling legacy-unchecked
## Inventory arithmetic. This is overflow safety, never a capacity veto.
func checked_contents_weight() -> int:
	var total: int = 0
	for id: StringName in inventory.registered_item_ids():
		if inventory.is_ancestor(endpoint(), id):
			total = CurrencyArithmetic.add(total, inventory.own_weight(id))
			if total < 0:
				return -1
	return total


func set_amount(id: StringName, amount: int) -> MoneyMutationResult:
	var result: MoneyMutationResult = MoneyMutationResult.new()
	result.item_id = id
	result.requested_amount = amount
	if not is_valid() or not inventory.is_registered(id) or not stacks.has_stack(id):
		return result
	var definition: CombinedStackDefinition = stacks.stack_definition(id)
	var weight: int = CurrencyArithmetic.multiply(amount, definition.base_weight)
	if weight < 0:
		result.outcome = MoneyMutationResult.Outcome.ARITHMETIC_FAILURE
		return result
	if amount > 0 and inventory.is_ancestor(endpoint(), id):
		var contents: int = checked_contents_weight()
		var old_weight: int = inventory.own_weight(id)
		if contents < 0 or old_weight < 0 or CurrencyArithmetic.add(contents - old_weight, weight) < 0:
			result.outcome = MoneyMutationResult.Outcome.ARITHMETIC_FAILURE
			return result
	result.amount_change = CombinedStackService.set_amount(stacks, inventory, id, amount)
	if not result.amount_change.accepted:
		return result
	if amount == 0:
		# OWNER APPROVED S3B G: consume intent here, no global timer or amount rewrite.
		result.removal = ItemLifecycleService.destroy_item(inventory, stacks, id,
			ItemLifecycleResult.ChildDisposition.REQUIRE_LEAF, owner)
		if not result.removal.succeeded:
			return result
		result.index_forgotten = index.forget_destroyed_snapshots(result.removal.removed_instance_ids, inventory)
		if not result.index_forgotten:
			return result
	result.outcome = MoneyMutationResult.Outcome.SUCCESS
	return result


func destroy_undelivered(id: StringName) -> MoneyMutationResult:
	var result: MoneyMutationResult = MoneyMutationResult.new()
	result.item_id = id
	if not is_valid() or inventory.direct_parent(id) != null:
		return result
	result.removal = ItemLifecycleService.destroy_item(inventory, stacks, id)
	if not result.removal.succeeded:
		return result
	result.index_forgotten = index.forget_destroyed_snapshots(result.removal.removed_instance_ids, inventory)
	if result.index_forgotten:
		result.outcome = MoneyMutationResult.Outcome.SUCCESS
	return result
