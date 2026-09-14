class_name LiquidItemLifecycle
extends RefCounted


static func remove(context: MoneyInventoryContext, liquids: LiquidCollection, id: StringName,
	parentless_only: bool = false) -> LiquidItemRemovalResult:
	var result: LiquidItemRemovalResult = LiquidItemRemovalResult.new()
	if context == null or not context.is_valid() or liquids == null or (parentless_only and context.inventory.direct_parent(id) != null):
		return result
	result.removal = ItemLifecycleService.destroy_item(context.inventory, context.stacks, id,
		ItemLifecycleResult.ChildDisposition.REQUIRE_LEAF, null if parentless_only else context.owner)
	if not result.removal.succeeded:
		return result
	result.liquid_forgotten = liquids.forget_removed(result.removal.removed_instance_ids, context.inventory)
	if result.liquid_forgotten:
		result.index_forgotten = context.index.forget_destroyed_snapshots(result.removal.removed_instance_ids, context.inventory)
	return result
