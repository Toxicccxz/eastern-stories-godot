class_name OldPineItemContentDefinitions
extends RefCounted

const LONG_SWORD_ITEM_ID: StringName = &"es2:d/oldpine/obj/long_sword"
const SHORT_SWORD_ITEM_ID: StringName = &"es2:d/oldpine/obj/short_sword"
const SILVER_ITEM_ID: StringName = &"es2:obj/money/silver"

const CATEGORY_WEAPON: StringName = &"weapon"
const CATEGORY_CURRENCY: StringName = &"currency"


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
	return null


static func validate() -> bool:
	for item_id: StringName in [LONG_SWORD_ITEM_ID, SHORT_SWORD_ITEM_ID, SILVER_ITEM_ID]:
		var content: OldPineItemContentDefinition = content_by_id(item_id)
		if content == null or not content.is_valid():
			return false
	return true
