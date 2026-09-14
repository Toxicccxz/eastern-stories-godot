class_name SourceDumpling
extends RefCounted

## reference/es2/mudlib/obj/example/dumpling.c; no finish_eat/drink_func.
const DEFINITION_ID: StringName = &"es2:obj/example/dumpling"
const LEGACY_SOURCE_PATH: String = "obj/example/dumpling.c"
const DISPLAY_NAME: String = "包子"
const ALIAS: String = "dumpling"
const UNIT: String = "个"
const VALUE: int = 15
const OWN_WEIGHT: int = 80
const PORTIONS: int = 3
const FOOD_SUPPLY: int = 60


static func item_definition() -> ItemDefinition:
	return ItemDefinition.new(DEFINITION_ID, LEGACY_SOURCE_PATH)


static func food_definition() -> FoodDefinition:
	return FoodDefinition.new(DEFINITION_ID, PORTIONS, FOOD_SUPPLY, VALUE, OWN_WEIGHT)
