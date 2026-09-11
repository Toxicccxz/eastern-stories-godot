class_name SourceSilver
extends RefCounted

## obj/money/silver.c -> std/money.c -> std/item/combined.c.
const DEFINITION_ID: StringName = &"es2:obj/money/silver"
const LEGACY_SOURCE_PATH: String = "obj/money/silver.c"
const MONEY_ID: StringName = &"silver"
const DISPLAY_NAME: String = "银子"
const BASE_UNIT: String = "两"
const BASE_WEIGHT: int = 37
const BASE_VALUE: int = 100


static func item_definition() -> ItemDefinition:
	return ItemDefinition.new(DEFINITION_ID, LEGACY_SOURCE_PATH)


static func stack_definition() -> CombinedStackDefinition:
	return CombinedStackDefinition.new(DEFINITION_ID, &"/obj/money/silver", BASE_WEIGHT)


static func currency_definition() -> CurrencyDefinition:
	return CurrencyDefinition.new(DEFINITION_ID, BASE_VALUE)
