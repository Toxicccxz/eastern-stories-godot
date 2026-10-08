class_name FoodItemLifecycle
extends RefCounted


## food.c with finish_eat() returning 1: the object stays as what the food leaves
## (`leftover`, its own definition and weight) and is food no more.
static func leave(context: MoneyInventoryContext, foods: FoodCollection, id: StringName, leftover: ItemContentDefinition) -> bool:
	if context == null or not context.is_valid() or foods == null or leftover == null:
		return false
	return (
		context.index.transmute(id, leftover.item_definition_id)
		and context.inventory.update_own_weight(id, leftover.own_weight)
		and foods.forget_eaten(id)
	)


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
