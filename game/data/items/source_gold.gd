class_name SourceGold
extends RefCounted

## obj/money/gold.c -> std/money.c -> std/item/combined.c.
const DEFINITION_ID: StringName = &"es2:obj/money/gold"
const LEGACY_SOURCE_PATH: String = "obj/money/gold.c"
const MONEY_ID: StringName = &"gold"
const DISPLAY_NAME: String = "黄金"
const BASE_UNIT: String = "两"
const BASE_WEIGHT: int = 37
const BASE_VALUE: int = 10000


static func item_definition() -> ItemDefinition:
	return ItemDefinition.new(DEFINITION_ID, LEGACY_SOURCE_PATH)


static func stack_definition() -> CombinedStackDefinition:
	return CombinedStackDefinition.new(DEFINITION_ID, &"/obj/money/gold", BASE_WEIGHT)


static func currency_definition() -> CurrencyDefinition:
	return CurrencyDefinition.new(DEFINITION_ID, BASE_VALUE)
