class_name SourcePlayerCloth
extends RefCounted

## obj/cloth.c -> std/armor/cloth.c (overrides std/equip.setup).
## At exactly 3000, weight > 3000 is false: no dodge penalty.
const DEFINITION_ID: StringName = &"es2:obj/cloth"
const DISPLAY_NAME: String = "布衣"
const OWN_WEIGHT: int = 3000
const LEGACY_SOURCE_PATH: String = "obj/cloth.c"


static func item_definition() -> ItemDefinition:
	return ItemDefinition.new(DEFINITION_ID, LEGACY_SOURCE_PATH)


static func armor_definition() -> ArmorDefinition:
	return ArmorDefinition.new(DEFINITION_ID, &"cloth", ArmorNumericModifiers.new(1))
