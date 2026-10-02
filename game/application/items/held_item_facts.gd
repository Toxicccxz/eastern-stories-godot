class_name HeldItemFacts
extends RefCounted

## What the item commands read off one item instance, as LPC asks its object.


## value(): a stack's amount times its base value (std/money.c), a food's current
## value (feature/food.c sets 0 after the first bite), else query("value").
static func value_of(id: StringName, content: ItemContentDefinition, stacks: CombinedStackCollection, foods: FoodCollection) -> int:
	if content == null:
		return 0
	if stacks != null and stacks.has_stack(id):
		return stacks.stack_state(id).amount * content.currency_base_value
	var food: FoodState = null if foods == null else foods.state(id)
	return content.value if food == null else food.current_value


## short() without the "(Id)": combined.c counts a stack, chinese_number(amount)
## + base_unit + name (十文钱); anything else is its name.
static func short_name(id: StringName, content: ItemContentDefinition, stacks: CombinedStackCollection) -> String:
	if stacks != null and stacks.has_stack(id):
		return ChineseNumber.of(stacks.stack_state(id).amount) + content.base_unit + content.display_name
	return content.display_name


## "一个牛皮酒袋", "一些钱": the 一%s%s of give.c, drop.c, put.c and get.c.
static func one_unit(content: ItemContentDefinition) -> String:
	return "一%s%s" % [content.unit, content.display_name]
