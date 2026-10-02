class_name HeldItemFacts
extends RefCounted

## What the item commands read off one item instance, as LPC asks its object.


## LPC value(): only std/money.c defines it (amount times base value); for any other
## object call_other() returns 0. give.c and accept_object() ask this.
static func money_value(id: StringName, content: ItemContentDefinition, stacks: CombinedStackCollection) -> int:
	if content == null or stacks == null or not stacks.has_stack(id) or content.currency_base_value <= 0:
		return 0
	return stacks.stack_state(id).amount * content.currency_base_value


## drop.c's `query("value") || value()`: a stack's money value, a food's current value
## (feature/food.c sets 0 after the first bite), else the authored value.
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
