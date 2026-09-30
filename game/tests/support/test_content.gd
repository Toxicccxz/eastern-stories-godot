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


## Spawn data and the (still GDScript) Old Pine world definitions agree: every
## spawn sits in a zone of the map that lists it, and no native ID is reused.
static func spawns_match_world() -> bool:
	if not OldPineWorldDefinitions.validate() or not GameContent.load_errors().is_empty():
		return false
	var catalog: ContentCatalog = GameContent.catalog()
	for definition: NpcSpawnDefinition in catalog.spawns():
		var map: MapDefinition = OldPineWorldDefinitions.map_by_id(definition.map_id)
		var zone: ZoneDefinition = OldPineWorldDefinitions.zone_by_id(definition.zone_id)
		if (
			map == null
			or not map.spawn_ids().has(definition.spawn_id)
			or zone == null
			or zone.map_id != definition.map_id
		):
			return false
	var listed: Dictionary[StringName, int] = {}
	for map: MapDefinition in OldPineWorldDefinitions.map_definitions():
		for spawn_id: StringName in map.spawn_ids():
			var definition: NpcSpawnDefinition = catalog.spawn(spawn_id)
			if definition == null or definition.map_id != map.map_id:
				return false
			listed[spawn_id] = listed.get(spawn_id, 0) + 1
	var native_ids: Array[StringName] = [OldPineWorldDefinitions.region_definition().region_id]
	for map: MapDefinition in OldPineWorldDefinitions.map_definitions():
		native_ids.append(map.map_id)
	for zone: ZoneDefinition in OldPineWorldDefinitions.zone_definitions():
		native_ids.append(zone.zone_id)
	for portal: PortalDefinition in OldPineWorldDefinitions.portal_definitions():
		native_ids.append(portal.portal_id)
	for definition: NpcDefinition in catalog.npcs():
		native_ids.append(definition.definition_id)
	for definition: NpcSpawnDefinition in catalog.spawns():
		if listed.get(definition.spawn_id, 0) != 1:
			return false
		native_ids.append(definition.spawn_id)
	for definition: ItemContentDefinition in catalog.items():
		native_ids.append(definition.item_definition_id)
	var seen: Dictionary[StringName, bool] = {}
	for id: StringName in native_ids:
		if id.is_empty() or seen.has(id):
			return false
		seen[id] = true
	return true
