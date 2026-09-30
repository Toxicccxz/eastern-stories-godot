class_name ContentCatalogBuilder
extends RefCounted

## Collects parsed data documents and cross-checks them. A document is one
## JSON object with any of the `items`, `npcs`, `spawns`, `vendors`, `rooms`,
## `regions`, `maps`, `zones`, `portals` arrays.
## build() returns null when anything was reported; errors() says what.
var _errors: Array[String] = []
var _items: Dictionary[StringName, ItemContentDefinition] = {}
var _npcs: Dictionary[StringName, NpcDefinition] = {}
var _spawns: Dictionary[StringName, NpcSpawnDefinition] = {}
var _vendors: Dictionary[StringName, VendorDefinition] = {}
var _rooms: Dictionary[StringName, RoomDefinition] = {}
var _regions: Dictionary[StringName, RegionDefinition] = {}
var _maps: Dictionary[StringName, MapDefinition] = {}
var _zones: Dictionary[StringName, ZoneDefinition] = {}
var _portals: Dictionary[StringName, PortalDefinition] = {}
var _origins: Dictionary[StringName, String] = {}


func errors() -> Array[String]:
	return _errors.duplicate()


func report(message: String) -> void:
	_errors.append(message)


func add_document(document: Variant, origin: String) -> void:
	if not document is Dictionary:
		_errors.append("%s: expected a JSON object" % origin)
		return
	var reader: ContentRecordReader = ContentRecordReader.new(document, origin, _errors)
	for record: ContentRecordReader in reader.children("items"):
		var definition: ItemContentDefinition = ItemContentDefinition.from_record(record)
		if _claim(definition.item_definition_id, record):
			_items[definition.item_definition_id] = definition
	for record: ContentRecordReader in reader.children("npcs"):
		var definition: NpcDefinition = NpcContentRecords.npc_from_record(record)
		if _claim(definition.definition_id, record):
			_npcs[definition.definition_id] = definition
	for record: ContentRecordReader in reader.children("spawns"):
		var definition: NpcSpawnDefinition = NpcContentRecords.spawn_from_record(record)
		if _claim(definition.spawn_id, record):
			_spawns[definition.spawn_id] = definition
	for record: ContentRecordReader in reader.children("vendors"):
		var definition: VendorDefinition = VendorDefinition.from_record(record)
		if _claim(definition.vendor_id, record):
			_vendors[definition.vendor_id] = definition
	for record: ContentRecordReader in reader.children("rooms"):
		var definition: RoomDefinition = RoomDefinition.from_record(record)
		if _claim(definition.room_id, record):
			_rooms[definition.room_id] = definition
	for record: ContentRecordReader in reader.children("regions"):
		var definition: RegionDefinition = RegionDefinition.from_record(record)
		if _claim(definition.region_id, record):
			_regions[definition.region_id] = definition
	for record: ContentRecordReader in reader.children("maps"):
		var definition: MapDefinition = MapDefinition.from_record(record)
		if _claim(definition.map_id, record):
			_maps[definition.map_id] = definition
	for record: ContentRecordReader in reader.children("zones"):
		var definition: ZoneDefinition = ZoneDefinition.from_record(record)
		if _claim(definition.zone_id, record):
			_zones[definition.zone_id] = definition
	for record: ContentRecordReader in reader.children("portals"):
		var definition: PortalDefinition = PortalDefinition.from_record(record)
		if _claim(definition.portal_id, record):
			_portals[definition.portal_id] = definition
	reader.finish()


func build() -> ContentCatalog:
	_check_money()
	_check_npc_loadouts()
	_check_spawns()
	_check_vendors()
	_check_maps()
	_resolve_zones()
	_resolve_portals()
	_check_spawn_locations()
	if not _errors.is_empty():
		return null
	var catalog: ContentCatalog = ContentCatalog.new(_items, _npcs, _spawns, _vendors)
	catalog.set_world(_rooms, _regions, _maps, _zones, _portals)
	# Backstop for role combinations the item rules cannot represent; saves
	# validate against these projections.
	if not catalog.native_item_projections().is_valid:
		_errors.append("items: item roles are inconsistent (NativeItemDefinitionProjections)")
		return null
	return catalog


## IDs are unique across every kind, so one ID never means two things.
func _claim(id: StringName, record: ContentRecordReader) -> bool:
	if id.is_empty():
		return false
	if _origins.has(id):
		record.fail("id", "'%s' is already defined at %s" % [id, _origins[id]])
		return false
	_origins[id] = record.path
	return true


func _check_money() -> void:
	var seen: Dictionary[StringName, StringName] = {}
	for definition: ItemContentDefinition in _items.values():
		if definition.money_id.is_empty():
			continue
		var origin: String = _origins[definition.item_definition_id]
		if not ContentCatalog.MONEY_DENOMINATIONS.has(definition.money_id):
			_errors.append("%s.money.money_id: unsupported money '%s'" % [
				origin, definition.money_id,
			])
		elif seen.has(definition.money_id):
			_errors.append("%s.money.money_id: '%s' is already %s" % [
				origin, definition.money_id, seen[definition.money_id],
			])
		seen[definition.money_id] = definition.item_definition_id
	# feature/finance.c pays in gold, silver and coin; all three must exist.
	for money_id: StringName in ContentCatalog.MONEY_DENOMINATIONS:
		if not seen.has(money_id):
			_errors.append("items: no money item with money_id '%s'" % money_id)


func _check_npc_loadouts() -> void:
	for definition: NpcDefinition in _npcs.values():
		var origin: String = _origins[definition.definition_id]
		var entries: Array[NpcLoadoutEntry] = definition.loadout_entries()
		for index: int in range(entries.size()):
			var entry: NpcLoadoutEntry = entries[index]
			var path: String = "%s.carry[%d]" % [origin, index]
			var item: ItemContentDefinition = _items.get(entry.item_definition_id)
			if item == null:
				_errors.append("%s.item: unknown item '%s'" % [path, entry.item_definition_id])
			elif (
				entry.equipment_intent == NpcLoadoutEntry.EquipmentIntent.WIELD_PRIMARY
				and item.weapon_definition() == null
			):
				_errors.append("%s.equip: '%s' is not a weapon" % [path, entry.item_definition_id])
			elif (
				entry.equipment_intent == NpcLoadoutEntry.EquipmentIntent.WEAR
				and item.armor_definition() == null
			):
				_errors.append("%s.equip: '%s' is not armor" % [path, entry.item_definition_id])


func _check_spawns() -> void:
	var point_owners: Dictionary[StringName, StringName] = {}
	for definition: NpcSpawnDefinition in _spawns.values():
		var origin: String = _origins[definition.spawn_id]
		if not _npcs.has(definition.npc_definition_id):
			_errors.append("%s.npc: unknown NPC '%s'" % [origin, definition.npc_definition_id])
		for point_id: StringName in definition.spawn_point_ids():
			if point_owners.has(point_id):
				_errors.append("%s.points: '%s' is already used by %s" % [
					origin, point_id, point_owners[point_id],
				])
			point_owners[point_id] = definition.spawn_id


func _check_vendors() -> void:
	for definition: VendorDefinition in _vendors.values():
		var origin: String = _origins[definition.vendor_id]
		for key: String in definition.goods_keys():
			var item_id: StringName = definition.item_definition_id(key)
			if not _items.has(item_id):
				_errors.append("%s.goods.%s: unknown item '%s'" % [origin, key, item_id])


func _check_maps() -> void:
	for definition: MapDefinition in _maps.values():
		if not _regions.has(definition.region_id):
			_errors.append("%s.region: unknown region '%s'" % [
				_origins[definition.map_id], definition.region_id,
			])


## Each room belongs to at most one zone; the zone takes its text from its
## first room.
func _resolve_zones() -> void:
	var room_owners: Dictionary[StringName, StringName] = {}
	for zone_id: StringName in _zones.keys():
		var definition: ZoneDefinition = _zones[zone_id]
		var origin: String = _origins[zone_id]
		if not _maps.has(definition.map_id):
			_errors.append("%s.map: unknown map '%s'" % [origin, definition.map_id])
		for room_id: StringName in definition.room_ids():
			if not _rooms.has(room_id):
				_errors.append("%s.rooms: unknown room '%s'" % [origin, room_id])
			elif room_owners.has(room_id):
				_errors.append("%s.rooms: '%s' is already in %s" % [origin, room_id, room_owners[room_id]])
			room_owners[room_id] = zone_id
		var room_ids: Array[StringName] = definition.room_ids()
		if not room_ids.is_empty() and _rooms.has(room_ids[0]):
			_zones[zone_id] = definition.with_primary_room(_rooms[room_ids[0]])


func _resolve_portals() -> void:
	for portal_id: StringName in _portals.keys():
		var definition: PortalDefinition = _portals[portal_id]
		var origin: String = _origins[portal_id]
		var source: ZoneDefinition = _zones.get(definition.source_zone_id)
		var destination: ZoneDefinition = _zones.get(definition.destination_zone_id)
		if source == null:
			_errors.append("%s.from_zone: unknown zone '%s'" % [origin, definition.source_zone_id])
		if destination == null:
			_errors.append("%s.to_zone: unknown zone '%s'" % [origin, definition.destination_zone_id])
		if not _rooms.has(definition.legacy_room_id):
			_errors.append("%s.legacy_room: unknown room '%s'" % [origin, definition.legacy_room_id])
		if source != null and destination != null:
			_portals[portal_id] = definition.with_maps(source.map_id, destination.map_id)


func _check_spawn_locations() -> void:
	for definition: NpcSpawnDefinition in _spawns.values():
		var origin: String = _origins[definition.spawn_id]
		var zone: ZoneDefinition = _zones.get(definition.zone_id)
		if not _maps.has(definition.map_id):
			_errors.append("%s.map: unknown map '%s'" % [origin, definition.map_id])
		elif zone == null or zone.map_id != definition.map_id:
			_errors.append("%s.zone: '%s' is not a zone of %s" % [origin, definition.zone_id, definition.map_id])
