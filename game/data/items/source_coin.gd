class_name SourceCoin
extends RefCounted

## obj/money/coin.c -> std/money.c -> std/item/combined.c.
const DEFINITION_ID: StringName = &"es2:obj/money/coin"
const LEGACY_SOURCE_PATH: String = "obj/money/coin.c"
const MONEY_ID: StringName = &"coin"
const DISPLAY_NAME: String = "钱"
const BASE_UNIT: String = "文"
const BASE_WEIGHT: int = 1
const BASE_VALUE: int = 1


static func item_definition() -> ItemDefinition:
	return ItemDefinition.new(DEFINITION_ID, LEGACY_SOURCE_PATH)


static func stack_definition() -> CombinedStackDefinition:
	return CombinedStackDefinition.new(DEFINITION_ID, &"/obj/money/coin", BASE_WEIGHT)


static func currency_definition() -> CurrencyDefinition:
	return CurrencyDefinition.new(DEFINITION_ID, BASE_VALUE)
