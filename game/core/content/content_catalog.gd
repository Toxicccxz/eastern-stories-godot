class_name ContentCatalog
extends RefCounted

## Read-only lookup over everything loaded from game/data/. Built only by
## ContentCatalogBuilder; definitions are immutable and shared.
const MONEY_DENOMINATIONS: Dictionary[StringName, CurrencyDenomination.Value] = {
	&"coin": CurrencyDenomination.Value.COIN,
	&"silver": CurrencyDenomination.Value.SILVER,
	&"gold": CurrencyDenomination.Value.GOLD,
}

var _items: Dictionary[StringName, ItemContentDefinition] = {}
var _npcs: Dictionary[StringName, NpcDefinition] = {}
var _spawns: Dictionary[StringName, NpcSpawnDefinition] = {}
var _vendors: Dictionary[StringName, VendorDefinition] = {}
var _currency_items: Dictionary[CurrencyDenomination.Value, ItemContentDefinition] = {}


func _init(
	p_items: Dictionary[StringName, ItemContentDefinition] = {},
	p_npcs: Dictionary[StringName, NpcDefinition] = {},
	p_spawns: Dictionary[StringName, NpcSpawnDefinition] = {},
	p_vendors: Dictionary[StringName, VendorDefinition] = {},
) -> void:
	_items = p_items.duplicate()
	_npcs = p_npcs.duplicate()
	_spawns = p_spawns.duplicate()
	_vendors = p_vendors.duplicate()
	for definition: ItemContentDefinition in _items.values():
		if MONEY_DENOMINATIONS.has(definition.money_id):
			_currency_items[MONEY_DENOMINATIONS[definition.money_id]] = definition


func item(item_definition_id: StringName) -> ItemContentDefinition:
	return _items.get(item_definition_id)


## All items in authored (manifest, then file) order.
func items() -> Array[ItemContentDefinition]:
	var result: Array[ItemContentDefinition] = []
	result.assign(_items.values())
	return result


func npc(npc_definition_id: StringName) -> NpcDefinition:
	return _npcs.get(npc_definition_id)


func npcs() -> Array[NpcDefinition]:
	var result: Array[NpcDefinition] = []
	result.assign(_npcs.values())
	return result


func spawn(spawn_id: StringName) -> NpcSpawnDefinition:
	return _spawns.get(spawn_id)


## All spawns in authored order. The order is significant: NPCs are created in
## it, which fixes their random draws and loadout item identities.
func spawns() -> Array[NpcSpawnDefinition]:
	var result: Array[NpcSpawnDefinition] = []
	result.assign(_spawns.values())
	return result


func spawns_for_map(map_id: StringName) -> Array[NpcSpawnDefinition]:
	var result: Array[NpcSpawnDefinition] = []
	for definition: NpcSpawnDefinition in _spawns.values():
		if definition.map_id == map_id:
			result.append(definition)
	return result


func vendor(vendor_id: StringName) -> VendorDefinition:
	return _vendors.get(vendor_id)


func vendors() -> Array[VendorDefinition]:
	var result: Array[VendorDefinition] = []
	result.assign(_vendors.values())
	return result


func currency_item(denomination: CurrencyDenomination.Value) -> ItemContentDefinition:
	return _currency_items.get(denomination)


func denomination_of(item_definition_id: StringName) -> CurrencyDenomination.Value:
	var definition: ItemContentDefinition = _items.get(item_definition_id)
	if definition == null:
		return CurrencyDenomination.Value.UNSUPPORTED
	return MONEY_DENOMINATIONS.get(definition.money_id, CurrencyDenomination.Value.UNSUPPORTED)


func loadout_item_definitions() -> Array[NpcLoadoutItemDefinition]:
	var result: Array[NpcLoadoutItemDefinition] = []
	for definition: ItemContentDefinition in _items.values():
		result.append(definition.loadout_item_definition())
	return result


## Every authored item role plus the rule-created corpse item.
func native_item_projections() -> NativeItemDefinitionProjections:
	var item_definitions: Array[ItemDefinition] = []
	var weapons: Array[WeaponDefinition] = []
	var armor: Array[ArmorDefinition] = []
	var stacks: Array[CombinedStackDefinition] = []
	var foods: Array[FoodDefinition] = []
	var liquids: Array[LiquidDefinition] = []
	for definition: ItemContentDefinition in _items.values():
		item_definitions.append(definition.item_definition())
		if definition.weapon_definition() != null:
			weapons.append(definition.weapon_definition())
		if definition.armor_definition() != null:
			armor.append(definition.armor_definition())
		if definition.stack_definition() != null:
			stacks.append(definition.stack_definition())
		if definition.food_definition() != null:
			foods.append(definition.food_definition())
		if definition.liquid_definition() != null:
			liquids.append(definition.liquid_definition())
	item_definitions.append(
		ItemDefinition.new(CorpseState.ITEM_DEFINITION_ID, CorpseState.LEGACY_SOURCE_PATH)
	)
	return NativeItemDefinitionProjections.new(
		item_definitions, weapons, armor, stacks, foods, liquids,
	)
