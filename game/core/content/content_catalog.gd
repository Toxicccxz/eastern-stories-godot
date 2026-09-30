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
var _rooms: Dictionary[StringName, RoomDefinition] = {}
var _regions: Dictionary[StringName, RegionDefinition] = {}
var _maps: Dictionary[StringName, MapDefinition] = {}
var _zones: Dictionary[StringName, ZoneDefinition] = {}
var _portals: Dictionary[StringName, PortalDefinition] = {}
var _services: Dictionary[StringName, ServiceDefinition] = {}
var _doors: Dictionary[StringName, DoorDefinition] = {}
var _landmarks: Dictionary[StringName, WorldLandmarkDefinition] = {}
var _pacing: PacingDefinition = PacingDefinition.new()
var _zone_of_room: Dictionary[StringName, StringName] = {}
var _currency_items: Dictionary[CurrencyDenomination.Value, ItemContentDefinition] = {}
var _native_item_projections: NativeItemDefinitionProjections


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


## Called once by ContentCatalogBuilder after cross-checking.
func set_world(
	p_rooms: Dictionary[StringName, RoomDefinition],
	p_regions: Dictionary[StringName, RegionDefinition],
	p_maps: Dictionary[StringName, MapDefinition],
	p_zones: Dictionary[StringName, ZoneDefinition],
	p_portals: Dictionary[StringName, PortalDefinition],
) -> void:
	_rooms = p_rooms.duplicate()
	_regions = p_regions.duplicate()
	_maps = p_maps.duplicate()
	_zones = p_zones.duplicate()
	_portals = p_portals.duplicate()
	_zone_of_room.clear()
	for definition: ZoneDefinition in _zones.values():
		for room_id: StringName in definition.room_ids():
			_zone_of_room[room_id] = definition.zone_id


## Called once by ContentCatalogBuilder after cross-checking.
func set_places(
	p_services: Dictionary[StringName, ServiceDefinition],
	p_doors: Dictionary[StringName, DoorDefinition],
	p_landmarks: Dictionary[StringName, WorldLandmarkDefinition] = {},
) -> void:
	_services = p_services.duplicate()
	_doors = p_doors.duplicate()
	_landmarks = p_landmarks.duplicate()


## Called once by ContentCatalogBuilder.
func set_pacing(value: PacingDefinition) -> void:
	_pacing = value


## Game-wide timing (combat rounds); an empty catalog has none (0 s).
func pacing() -> PacingDefinition:
	return _pacing


func landmark(landmark_id: StringName) -> WorldLandmarkDefinition:
	return _landmarks.get(landmark_id)


func landmarks_for_map(map_id: StringName) -> Array[WorldLandmarkDefinition]:
	var result: Array[WorldLandmarkDefinition] = []
	for definition: WorldLandmarkDefinition in _landmarks.values():
		if definition.map_id == map_id:
			result.append(definition)
	return result


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


func room(room_id: StringName) -> RoomDefinition:
	return _rooms.get(room_id)


func region(region_id: StringName) -> RegionDefinition:
	return _regions.get(region_id)


func map(map_id: StringName) -> MapDefinition:
	return _maps.get(map_id)


func maps() -> Array[MapDefinition]:
	var result: Array[MapDefinition] = []
	result.assign(_maps.values())
	return result


func zone(zone_id: StringName) -> ZoneDefinition:
	return _zones.get(zone_id)


func zones() -> Array[ZoneDefinition]:
	var result: Array[ZoneDefinition] = []
	result.assign(_zones.values())
	return result


func zones_for_map(map_id: StringName) -> Array[ZoneDefinition]:
	var result: Array[ZoneDefinition] = []
	for definition: ZoneDefinition in _zones.values():
		if definition.map_id == map_id:
			result.append(definition)
	return result


func portal(portal_id: StringName) -> PortalDefinition:
	return _portals.get(portal_id)


func portals_for_map(map_id: StringName) -> Array[PortalDefinition]:
	var result: Array[PortalDefinition] = []
	for definition: PortalDefinition in _portals.values():
		if definition.source_map_id == map_id:
			result.append(definition)
	return result


func service(service_id: StringName) -> ServiceDefinition:
	return _services.get(service_id)


func services_for_map(map_id: StringName) -> Array[ServiceDefinition]:
	var result: Array[ServiceDefinition] = []
	for definition: ServiceDefinition in _services.values():
		if definition.map_id == map_id:
			result.append(definition)
	return result


func door(door_id: StringName) -> DoorDefinition:
	return _doors.get(door_id)


func doors_for_map(map_id: StringName) -> Array[DoorDefinition]:
	var result: Array[DoorDefinition] = []
	for definition: DoorDefinition in _doors.values():
		if definition.map_id == map_id:
			result.append(definition)
	return result


## Two zones touch when a room of one has an ES2 exit into a room of the other.
func zones_adjacent(from_zone_id: StringName, to_zone_id: StringName) -> bool:
	if from_zone_id == to_zone_id:
		return false
	if _has_exit_into(from_zone_id, to_zone_id) or _has_exit_into(to_zone_id, from_zone_id):
		return true
	var first: ZoneDefinition = _zones.get(from_zone_id)
	var second: ZoneDefinition = _zones.get(to_zone_id)
	return (first != null and first.link_ids().has(to_zone_id)) or (second != null and second.link_ids().has(from_zone_id))


func _has_exit_into(from_zone_id: StringName, to_zone_id: StringName) -> bool:
	var from_zone: ZoneDefinition = _zones.get(from_zone_id)
	if from_zone == null:
		return false
	for room_id: StringName in from_zone.room_ids():
		for target: StringName in _rooms[room_id].exits().values():
			if _zone_of_room.get(target, &"") == to_zone_id:
				return true
	return false


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


## Every authored item role plus the rule-created corpse item. The projection
## object is immutable, so one instance is shared.
func native_item_projections() -> NativeItemDefinitionProjections:
	if _native_item_projections == null:
		_native_item_projections = _build_native_item_projections()
	return _native_item_projections


func _build_native_item_projections() -> NativeItemDefinitionProjections:
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
