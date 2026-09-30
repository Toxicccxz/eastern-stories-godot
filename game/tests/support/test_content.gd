class_name TestContent
extends RefCounted

## IDs of shipped content that tests exercise, plus short lookups into the
## loaded catalog. The facts themselves live in game/data/.
const LONG_SWORD_ITEM_ID: StringName = &"es2:d/oldpine/obj/long_sword"
const SHORT_SWORD_ITEM_ID: StringName = &"es2:d/oldpine/obj/short_sword"
const LEATHER_ITEM_ID: StringName = &"es2:d/oldpine/obj/leather"
const COIN_ITEM_ID: StringName = &"es2:obj/money/coin"
const SILVER_ITEM_ID: StringName = &"es2:obj/money/silver"
const GOLD_ITEM_ID: StringName = &"es2:obj/money/gold"
const CLOTH_ITEM_ID: StringName = &"es2:obj/cloth"
const DUMPLING_ITEM_ID: StringName = &"es2:obj/example/dumpling"
const WINESKIN_ITEM_ID: StringName = &"es2:obj/example/wineskin"

const BANDIT_NPC_ID: StringName = &"oldpine.npc.bandit"
const TALL_BANDIT_NPC_ID: StringName = &"oldpine.npc.tall_bandit"
const FAT_BANDIT_NPC_ID: StringName = &"oldpine.npc.fat_bandit"
const SERPENT_NPC_ID: StringName = &"oldpine.npc.serpent"

const SPATH1_BANDIT_SPAWN_ID: StringName = &"oldpine.outdoor.spath1.bandits"
const PINE1_TALL_BANDIT_SPAWN_ID: StringName = &"oldpine.outdoor.pine1.tall_bandit"
const PINE1_FAT_BANDIT_SPAWN_ID: StringName = &"oldpine.outdoor.pine1.fat_bandit"
const LAKE_SERPENT_SPAWN_ID: StringName = &"oldpine.outdoor.lake.serpents"

const WAITER_VENDOR_ID: StringName = &"snow.vendor.waiter"


static func item(item_definition_id: StringName) -> ItemContentDefinition:
	return GameContent.catalog().item(item_definition_id)


static func loadout(item_definition_id: StringName) -> NpcLoadoutItemDefinition:
	var content: ItemContentDefinition = GameContent.catalog().item(item_definition_id)
	return null if content == null else content.loadout_item_definition()


static func npc(npc_definition_id: StringName) -> NpcDefinition:
	return GameContent.catalog().npc(npc_definition_id)


static func spawn(spawn_id: StringName) -> NpcSpawnDefinition:
	return GameContent.catalog().spawn(spawn_id)


static func projections() -> NativeItemDefinitionProjections:
	return GameContent.catalog().native_item_projections()


static func waiter() -> VendorDefinition:
	return GameContent.catalog().vendor(WAITER_VENDOR_ID)


## The loader cross-checks spawns against the world data (map, zone of that
## map) and keeps native IDs unique across every kind.
static func spawns_match_world() -> bool:
	return GameContent.load_errors().is_empty()
