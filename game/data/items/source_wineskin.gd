class_name SourceWineskin
extends RefCounted

## obj/example/wineskin.c + feature/liquid.c. Fill retains authored drunk_apply6.
const DEFINITION_ID: StringName = &"es2:obj/example/wineskin"
const LEGACY_SOURCE_PATH: String = "obj/example/wineskin.c"
const DISPLAY_NAME: String = "牛皮酒袋"
const ALIASES: Array[String] = ["wineskin", "skin"]
const UNIT: String = "个"
const OWN_WEIGHT: int = 700
const VALUE: int = 20
const MAXIMUM: int = 15
const HYDRATION: int = 30
const DRUNK_APPLY: int = 6


static func item_definition() -> ItemDefinition:
	return ItemDefinition.new(DEFINITION_ID, LEGACY_SOURCE_PATH)


static func liquid_definition() -> LiquidDefinition:
	return LiquidDefinition.new(DEFINITION_ID, MAXIMUM, HYDRATION, DRUNK_APPLY, OWN_WEIGHT, VALUE)


static func fresh_state() -> LiquidState:
	return LiquidState.new(LiquidState.Content.RED_WINE, MAXIMUM)


static func is_canonical(definition: LiquidDefinition) -> bool:
	return definition != null and definition.is_valid() and definition.item_definition_id == DEFINITION_ID and definition.maximum_portions == MAXIMUM and definition.hydration == HYDRATION and definition.drunk_apply == DRUNK_APPLY and definition.own_weight == OWN_WEIGHT and definition.value == VALUE


static func content_name(content: LiquidState.Content) -> String:
	return "红酒" if content == LiquidState.Content.RED_WINE else "清水"
