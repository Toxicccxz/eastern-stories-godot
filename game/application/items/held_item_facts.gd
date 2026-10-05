class_name HeldItemFacts
extends RefCounted

## What the item commands read off one item instance, as LPC asks its object.


## LPC value(): only std/money.c defines it (amount times base value); for any other
## object call_other() returns 0. give.c and accept_object() ask this.
static func money_value(id: StringName, content: ItemContentDefinition, stacks: CombinedStackCollection) -> int:
	if content == null or stacks == null or not stacks.has_stack(id) or content.currency_base_value <= 0:
		return 0
	return stacks.stack_state(id).amount * content.currency_base_value


## drop.c's `query("value") || value()`: the authored value (蛇药's 1000 for the whole
## stack), else a stack's money value; a food's current value (feature/food.c sets 0
## after the first bite). 飞刀 has neither (THROWING sets only base_value).
static func value_of(id: StringName, content: ItemContentDefinition, stacks: CombinedStackCollection, foods: FoodCollection) -> int:
	if content == null:
		return 0
	if stacks != null and stacks.has_stack(id):
		return content.value if content.value > 0 else stacks.stack_state(id).amount * content.currency_base_value
	var food: FoodState = null if foods == null else foods.state(id)
	return content.value if food == null else food.current_value


## short() without the "(Id)", in the shown language: combined.c counts a stack,
## chinese_number(amount) + base_unit + name (十文钱); anything else is its name.
## The count phrases here are where a language without measure words (a coin, ten
## coins) would put its own rule.
static func short_name(id: StringName, content: ItemContentDefinition, stacks: CombinedStackCollection) -> String:
	if stacks != null and stacks.has_stack(id):
		# TRANSLATORS: a counted stack, e.g. 十文钱: {count} in words, {unit} its measure word, {item} its name.
		return TranslationServer.translate("{count}{unit}{item}").format({
			"count": ChineseNumber.of(stacks.stack_state(id).amount),
			"unit": TranslationServer.translate(content.base_unit),
			"item": TranslationServer.translate(content.display_name),
		})
	return TranslationServer.translate(content.display_name)


## "一个牛皮酒袋", "一些钱", in the shown language: the 一%s%s of give.c, drop.c,
## put.c and get.c.
static func one_unit(content: ItemContentDefinition) -> String:
	# TRANSLATORS: one of an item, e.g. 一个牛皮酒袋: {unit} is its measure word, {item} its name.
	return TranslationServer.translate("一{unit}{item}").format({
		"unit": TranslationServer.translate(content.unit),
		"item": TranslationServer.translate(content.display_name),
	})
