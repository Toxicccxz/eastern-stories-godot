class_name ItemRoleStates
extends RefCounted

## A new food or liquid item starts with its authored portions or contents
## (F_FOOD food_remaining, F_LIQUID set("liquid")), whoever gets it: a buyer,
## or an NPC that carries it from creation.
static func register_fresh(
	content: ItemContentDefinition,
	item_id: StringName,
	foods: FoodCollection,
	liquids: LiquidCollection,
) -> bool:
	var food: FoodDefinition = content.food_definition()
	if food != null and (foods == null or not foods.register_state(item_id, FoodState.new(food.initial_portions, food.initial_value))):
		return false
	if content.liquid_definition() != null and (liquids == null or not liquids.register_state(item_id, content.fresh_liquid_state())):
		return false
	return true
