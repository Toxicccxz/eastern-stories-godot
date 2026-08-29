class_name OldPineItemContentDefinitions
extends RefCounted

const LONG_SWORD_ITEM_ID: StringName = &"es2:d/oldpine/obj/long_sword"
const SHORT_SWORD_ITEM_ID: StringName = &"es2:d/oldpine/obj/short_sword"
const SILVER_ITEM_ID: StringName = &"es2:obj/money/silver"
const LEATHER_ITEM_ID: StringName = &"es2:d/oldpine/obj/leather"

const CATEGORY_WEAPON: StringName = &"weapon"
const CATEGORY_CURRENCY: StringName = &"currency"
const CATEGORY_ARMOR: StringName = &"armor"


static func content_by_id(item_definition_id: StringName) -> OldPineItemContentDefinition:
	match item_definition_id:
		LONG_SWORD_ITEM_ID:
			return OldPineItemContentDefinition.new(
				LONG_SWORD_ITEM_ID,
				"长剑",
				"一把粗制滥造的长剑，把手部份用布缠绕了好几圈以防止武器脱手。\n",
				CATEGORY_WEAPON,
				7_000,
				&"sword",
				25,
				false,
				false,
				false,
				0,
				0,
				["d/oldpine/obj/long_sword.c", "d/oldpine/npc/obj/long_sword.c"],
			)
		SHORT_SWORD_ITEM_ID:
			return OldPineItemContentDefinition.new(
				SHORT_SWORD_ITEM_ID,
				"短剑",
				"一把粗制滥造的短剑，把手部份用布缠绕了好几圈以防止武器脱手。\n",
				CATEGORY_WEAPON,
				3_000,
				&"sword",
				15,
				true,
				false,
				false,
				0,
				0,
				["d/oldpine/obj/short_sword.c", "d/oldpine/npc/obj/short_sword.c"],
			)
		SILVER_ITEM_ID:
			return OldPineItemContentDefinition.new(
				SILVER_ITEM_ID,
				"银子",
				"白花花的银子，人见人爱的银子。\n",
				CATEGORY_CURRENCY,
				37,
				&"",
				0,
				false,
				false,
				true,
				37,
				100,
				["obj/money/silver.c", "std/money.c"],
			)
		LEATHER_ITEM_ID:
			return OldPineItemContentDefinition.new(
				LEATHER_ITEM_ID,
				"皮衣",
				"皮衣(Leather)。\n",
				CATEGORY_ARMOR,
				6_000,
				&"",
				0,
				false,
				false,
				false,
				0,
				0,
				["d/oldpine/obj/leather.c", "d/oldpine/npc/obj/leather.c"],
				ArmorDefinition.new(
					LEATHER_ITEM_ID,
					&"cloth",
					ArmorNumericModifiers.new(5, 0, 0, 0, -2),
				),
			)
	return null


static func validate() -> bool:
	for item_id: StringName in [
		LONG_SWORD_ITEM_ID,
		SHORT_SWORD_ITEM_ID,
		SILVER_ITEM_ID,
		LEATHER_ITEM_ID,
	]:
		var content: OldPineItemContentDefinition = content_by_id(item_id)
		if content == null or not content.is_valid():
			return false
		if item_id == LEATHER_ITEM_ID:
			var armor: ArmorDefinition = content.armor_definition()
			if armor == null or armor.numeric_modifiers.armor != 5 or armor.numeric_modifiers.dodge != -2:
				return false
	return true
