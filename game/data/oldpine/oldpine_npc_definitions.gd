class_name OldPineNpcDefinitions
extends RefCounted

const BANDIT_DEFINITION_ID: StringName = &"oldpine.npc.bandit"
const TALL_BANDIT_DEFINITION_ID: StringName = &"oldpine.npc.tall_bandit"
const LONG_SWORD_ITEM_ID: StringName = (
	OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID
)
const SHORT_SWORD_ITEM_ID: StringName = &"es2:d/oldpine/obj/short_sword"
const SILVER_ITEM_ID: StringName = &"es2:obj/money/silver"
const AGGRESSIVE_ON_PLAYER_PRESENCE: StringName = (
	&"aggressive_on_player_presence"
)

const SHORT_SWORD_WEIGHT: int = 3_000
const SHORT_SWORD_DAMAGE: int = 15
const SILVER_BASE_VALUE: int = 100
const SILVER_BASE_WEIGHT: int = 37


static func bandit_definition() -> NpcDefinition:
	return NpcDefinition.new(
		BANDIT_DEFINITION_ID,
		"d/oldpine/npc/bandit.c",
		"土匪探哨",
		[&"bandit"],
		NpcCharacterStateFactory.HUMAN_RACE_ID,
		true,
		CharacterState.GENDER_MALE,
		true,
		19,
		NpcBaseAttributeOverrides.new(),
		NpcResourceOverrides.new(),
		600,
		60,
		NpcDefinition.Attitude.AGGRESSIVE,
		[
			NpcSkillLevelDefinition.new(&"sword", 10),
			NpcSkillLevelDefinition.new(&"parry", 10),
			NpcSkillLevelDefinition.new(&"dodge", 10),
		],
		[
			NpcLoadoutEntry.new(
				SHORT_SWORD_ITEM_ID,
				1,
				NpcLoadoutEntry.EquipmentIntent.WIELD_PRIMARY,
				"d/oldpine/npc/obj/short_sword.c",
			),
			NpcLoadoutEntry.new(
				SILVER_ITEM_ID,
				3,
				NpcLoadoutEntry.EquipmentIntent.NONE,
				"obj/money/silver.c",
			),
		],
		[AGGRESSIVE_ON_PLAYER_PRESENCE],
		"这人满脸匪气，一付百无聊赖的模样，令人望而生厌。\n",
	)


static func tall_bandit_definition() -> NpcDefinition:
	return NpcDefinition.new(
		TALL_BANDIT_DEFINITION_ID,
		"d/oldpine/npc/tall_bandit.c",
		"土匪",
		[&"bandit"],
		NpcCharacterStateFactory.HUMAN_RACE_ID,
		true,
		CharacterState.GENDER_MALE,
		true,
		27,
		NpcBaseAttributeOverrides.new(),
		NpcResourceOverrides.new(),
		900,
		100,
		NpcDefinition.Attitude.AGGRESSIVE,
		[
			NpcSkillLevelDefinition.new(&"sword", 15),
			NpcSkillLevelDefinition.new(&"parry", 15),
			NpcSkillLevelDefinition.new(&"dodge", 10),
		],
		[
			NpcLoadoutEntry.new(
				LONG_SWORD_ITEM_ID,
				1,
				NpcLoadoutEntry.EquipmentIntent.WIELD_PRIMARY,
				"d/oldpine/npc/obj/long_sword.c",
			),
			NpcLoadoutEntry.new(
				SILVER_ITEM_ID,
				6,
				NpcLoadoutEntry.EquipmentIntent.NONE,
				"obj/money/silver.c",
			),
		],
		[AGGRESSIVE_ON_PLAYER_PRESENCE],
		"这家伙长得高高瘦瘦，脸色苍白，一付无精打采的样子。\n",
	)


static func long_sword_content() -> NpcLoadoutItemDefinition:
	var authored: OldPineItemContentDefinition = (
		OldPineItemContentDefinitions.content_by_id(LONG_SWORD_ITEM_ID)
	)
	if authored == null:
		return null
	var sources: Array[String] = authored.legacy_source_paths()
	return NpcLoadoutItemDefinition.new(
		ItemDefinition.new(
			authored.item_definition_id,
			sources[0],
		),
		authored.own_weight,
		WeaponDefinition.new(
			authored.item_definition_id,
			authored.weapon_skill_type,
			authored.can_wield_secondary,
			authored.is_two_handed,
			sources[0],
		),
		authored.weapon_damage,
		null,
		null,
		sources,
	)


static func short_sword_content() -> NpcLoadoutItemDefinition:
	return NpcLoadoutItemDefinition.new(
		ItemDefinition.new(
			SHORT_SWORD_ITEM_ID,
			"d/oldpine/obj/short_sword.c",
		),
		SHORT_SWORD_WEIGHT,
		WeaponDefinition.new(
			SHORT_SWORD_ITEM_ID,
			&"sword",
			true,
			false,
			"d/oldpine/obj/short_sword.c",
		),
		SHORT_SWORD_DAMAGE,
		null,
		null,
		[
			"d/oldpine/obj/short_sword.c",
			"d/oldpine/npc/obj/short_sword.c",
		],
	)


static func silver_content() -> NpcLoadoutItemDefinition:
	return NpcLoadoutItemDefinition.new(
		ItemDefinition.new(SILVER_ITEM_ID, "obj/money/silver.c"),
		SILVER_BASE_WEIGHT,
		null,
		0,
		CombinedStackDefinition.new(
			SILVER_ITEM_ID,
			&"/obj/money/silver",
			SILVER_BASE_WEIGHT,
		),
		CurrencyDefinition.new(SILVER_ITEM_ID, SILVER_BASE_VALUE),
		["obj/money/silver.c", "std/money.c"],
	)


static func loadout_item_definitions() -> Array[NpcLoadoutItemDefinition]:
	return [long_sword_content(), short_sword_content(), silver_content()]


static func npc_by_id(definition_id: StringName) -> NpcDefinition:
	match definition_id:
		BANDIT_DEFINITION_ID:
			return bandit_definition()
		TALL_BANDIT_DEFINITION_ID:
			return tall_bandit_definition()
	return null


static func loadout_content_by_id(
	item_definition_id: StringName,
) -> NpcLoadoutItemDefinition:
	for content: NpcLoadoutItemDefinition in loadout_item_definitions():
		if content.item_definition().item_definition_id == item_definition_id:
			return content
	return null


static func validate() -> bool:
	var definitions: Array[NpcDefinition] = [
		bandit_definition(),
		tall_bandit_definition(),
	]
	for definition: NpcDefinition in definitions:
		if not definition.is_valid():
			return false
	var content_ids: Dictionary[StringName, bool] = {}
	for content: NpcLoadoutItemDefinition in loadout_item_definitions():
		if content == null or not content.is_valid():
			return false
		var content_id: StringName = content.item_definition().item_definition_id
		if content_id.is_empty() or content_ids.has(content_id):
			return false
		content_ids[content_id] = true
	for definition: NpcDefinition in definitions:
		for entry: NpcLoadoutEntry in definition.loadout_entries():
			var content: NpcLoadoutItemDefinition = loadout_content_by_id(
				entry.item_definition_id
			)
			if content == null or not content.is_valid():
				return false
	return true
