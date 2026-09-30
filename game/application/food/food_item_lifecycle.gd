class_name FoodItemLifecycle
extends RefCounted


static func remove(context: MoneyInventoryContext, foods: FoodCollection, id: StringName) -> FoodItemRemovalResult:
	var result: FoodItemRemovalResult = FoodItemRemovalResult.new()
	if context == null or not context.is_valid() or foods == null:
		return result
	result.removal = ItemLifecycleService.destroy_item(context.inventory, context.stacks, id,
		ItemLifecycleResult.ChildDisposition.REQUIRE_LEAF, context.owner)
	if not result.removal.succeeded:
		return result
	result.food_forgotten = foods.forget_removed(result.removal.removed_instance_ids, context.inventory)
	if result.food_forgotten:
		result.index_forgotten = context.index.forget_destroyed_snapshots(result.removal.removed_instance_ids, context.inventory)
	return result
