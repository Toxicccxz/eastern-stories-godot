class_name ContentCatalogBuilder
extends RefCounted

## Collects parsed data documents and cross-checks them. A document is one
## JSON object with any of the `items`, `npcs`, `spawns`, `item_spawns`,
## `vendors`, `rooms`, `regions`, `maps`, `zones`, `portals`, `services`,
## `doors`, `landmarks`, `traps`, `skills`, `families`, `race_actions`, `weapon_actions`
## arrays, and at most one document has the `pacing` object.
## build() returns null when anything was reported; errors() says what.
var _errors: Array[String] = []
var _items: Dictionary[StringName, ItemContentDefinition] = {}
var _npcs: Dictionary[StringName, NpcDefinition] = {}
var _spawns: Dictionary[StringName, NpcSpawnDefinition] = {}
var _item_spawns: Dictionary[StringName, ItemSpawnDefinition] = {}
var _vendors: Dictionary[StringName, VendorDefinition] = {}
var _rooms: Dictionary[StringName, RoomDefinition] = {}
var _regions: Dictionary[StringName, RegionDefinition] = {}
var _maps: Dictionary[StringName, MapDefinition] = {}
var _zones: Dictionary[StringName, ZoneDefinition] = {}
var _portals: Dictionary[StringName, PortalDefinition] = {}
var _services: Dictionary[StringName, ServiceDefinition] = {}
var _doors: Dictionary[StringName, DoorDefinition] = {}
var _landmarks: Dictionary[StringName, WorldLandmarkDefinition] = {}
var _traps: Dictionary[StringName, RoomTrapDefinition] = {}
var _skills: Dictionary[StringName, SkillDefinition] = {}
var _families: Dictionary[StringName, FamilyDefinition] = {}
var _combat_actions: CombatActionTables = CombatActionTables.new()
var _pacing: PacingDefinition
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
	for record: ContentRecordReader in reader.children("item_spawns"):
		var definition: ItemSpawnDefinition = ItemSpawnDefinition.from_record(record)
		if _claim(definition.spawn_id, record):
			_item_spawns[definition.spawn_id] = definition
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
	for record: ContentRecordReader in reader.children("services"):
		var definition: ServiceDefinition = ServiceDefinition.from_record(record)
		if _claim(definition.service_id, record):
			_services[definition.service_id] = definition
	for record: ContentRecordReader in reader.children("doors"):
		var definition: DoorDefinition = DoorDefinition.from_record(record)
		if _claim(definition.door_id, record):
			_doors[definition.door_id] = definition
	for record: ContentRecordReader in reader.children("landmarks"):
		var definition: WorldLandmarkDefinition = WorldLandmarkDefinition.from_record(record)
		if _claim(definition.landmark_id, record):
			_landmarks[definition.landmark_id] = definition
	for record: ContentRecordReader in reader.children("traps"):
		var definition: RoomTrapDefinition = RoomTrapDefinition.from_record(record)
		if _claim(definition.trap_id, record):
			_traps[definition.trap_id] = definition
	for record: ContentRecordReader in reader.children("skills"):
		var definition: SkillDefinition = SkillDefinition.from_record(record)
		if _claim(definition.skill_id, record):
			_skills[definition.skill_id] = definition
	for record: ContentRecordReader in reader.children("families"):
		var definition: FamilyDefinition = FamilyDefinition.from_record(record)
		if _claim(definition.family_id, record):
			_families[definition.family_id] = definition
	for record: ContentRecordReader in reader.children("race_actions"):
		_combat_actions.add_race(record)
	for record: ContentRecordReader in reader.children("weapon_actions"):
		_combat_actions.add_weapon_actions(record)
	var pacing: ContentRecordReader = reader.child("pacing")
	if pacing != null:
		if _pacing != null:
			pacing.fail("", "pacing is already defined")
		_pacing = PacingDefinition.from_record(pacing)
	reader.finish()


func build() -> ContentCatalog:
	_check_money()
	_check_npc_loadouts()
	_resolve_npc_dealings()
	_check_spawns()
	_check_vendors()
	_check_maps()
	_resolve_zones()
	_resolve_portals()
	_check_spawn_locations()
	_resolve_services()
	_resolve_doors()
	_resolve_landmarks()
	_check_traps()
	_check_combat_data()
	if _pacing == null:
		_errors.append("pacing: no document defines it")
	if not _errors.is_empty():
		return null
	var catalog: ContentCatalog = ContentCatalog.new(_items, _npcs, _spawns, _vendors)
	catalog.set_world(_rooms, _regions, _maps, _zones, _portals)
	catalog.set_places(_services, _doors, _landmarks, _traps)
	catalog.set_item_spawns(_item_spawns)
	catalog.set_pacing(_pacing)
	catalog.set_teaching(_skills, _families)
	catalog.set_combat_actions(_combat_actions)
	# Backstop for role combinations the item rules cannot represent; saves
	# validate against these projections.
	if not catalog.native_item_projections().is_valid:
		_errors.append("items: item roles are inconsistent (NativeItemDefinitionProjections)")
		return null
	return catalog


## A catalog that defines skills is a game's: its fights need the race and weapon
## moves and the dodge.c and parry.c lines every narration falls back to.
func _check_combat_data() -> void:
	if _skills.is_empty():
		return
	if _combat_actions.race_action_set(&"human") == null:
		_errors.append("race_actions: no moves for race 'human'")
	if not _combat_actions.weapon_action_set(&"").is_valid():
		_errors.append("weapon_actions: no 'slash' action")
	var dodge: SkillDefinition = _skills.get(&"dodge")
	if dodge == null or dodge.dodge_messages.is_empty():
		_errors.append("skills: 'dodge' needs dodge_messages")
	var parry: SkillDefinition = _skills.get(&"parry")
	if parry == null or parry.parry_messages_armed.is_empty() or parry.parry_messages_unarmed.is_empty():
		_errors.append("skills: 'parry' needs parry_messages armed and unarmed")


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


## A vendor NPC's goods exist; a family an NPC heads or rules test is defined.
func _resolve_npc_dealings() -> void:
	for definition: NpcDefinition in _npcs.values():
		var origin: String = _origins[definition.definition_id]
		var vendor_id: StringName = definition.dealings().vendor_id
		if not vendor_id.is_empty() and not _vendors.has(vendor_id):
			_errors.append("%s.vendor: unknown vendor '%s'" % [origin, vendor_id])
		var teaching: NpcTeaching = definition.teaching()
		if teaching == null:
			continue
		if teaching.has_family():
			var family_id: StringName = &""
			for family: FamilyDefinition in _families.values():
				if family.display_name == teaching.family_name:
					family_id = family.family_id
			if family_id.is_empty():
				_errors.append("%s.family.name: no family named '%s' (families.json)" % [origin, teaching.family_name])
			teaching.family_id = family_id
		for rule: NpcTeaching.RecognizeRule in teaching.recognize_rules:
			if not rule.family_id.is_empty() and not _families.has(rule.family_id):
				_errors.append("%s.recognize_apprentice: unknown family '%s'" % [origin, rule.family_id])


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
	for definition: ItemSpawnDefinition in _item_spawns.values():
		var origin: String = _origins[definition.spawn_id]
		var item: ItemContentDefinition = _items.get(definition.item_definition_id)
		if item == null:
			_errors.append("%s.item: unknown item '%s'" % [origin, definition.item_definition_id])
		elif item.is_stack:
			# A combined item lies as one stack with an amount, which the floor does not hold yet.
			_errors.append("%s.item: '%s' is a combined item" % [origin, definition.item_definition_id])
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
		for link_id: StringName in definition.link_ids():
			var linked: ZoneDefinition = _zones.get(link_id)
			if linked == null or linked.map_id != definition.map_id or link_id == zone_id:
				_errors.append("%s.links: '%s' is not another zone of %s" % [origin, link_id, definition.map_id])
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
	var places: Array[Array] = []
	for definition: NpcSpawnDefinition in _spawns.values():
		places.append([definition.spawn_id, definition.map_id, definition.zone_id])
	for definition: ItemSpawnDefinition in _item_spawns.values():
		places.append([definition.spawn_id, definition.map_id, definition.zone_id])
	for place: Array in places:
		var origin: String = _origins[place[0]]
		var zone: ZoneDefinition = _zones.get(place[2])
		if not _maps.has(place[1]):
			_errors.append("%s.map: unknown map '%s'" % [origin, place[1]])
		elif zone == null or zone.map_id != place[1]:
			_errors.append("%s.zone: '%s' is not a zone of %s" % [origin, place[2], place[1]])


func _resolve_services() -> void:
	for service_id: StringName in _services.keys():
		var definition: ServiceDefinition = _services[service_id]
		var origin: String = _origins[service_id]
		var zone: ZoneDefinition = _zones.get(definition.zone_id)
		if zone == null:
			_errors.append("%s.zone: unknown zone '%s'" % [origin, definition.zone_id])
			continue
		_services[service_id] = definition.with_map(zone.map_id)


func _resolve_doors() -> void:
	for door_id: StringName in _doors.keys():
		var definition: DoorDefinition = _doors[door_id]
		var origin: String = _origins[door_id]
		var maps: Dictionary[StringName, bool] = {}
		for zone_id: StringName in definition.zone_ids():
			var zone: ZoneDefinition = _zones.get(zone_id)
			if zone == null:
				_errors.append("%s.zones: unknown zone '%s'" % [origin, zone_id])
			else:
				maps[zone.map_id] = true
		if not _rooms.has(definition.legacy_room_id):
			_errors.append("%s.legacy_room: unknown room '%s'" % [origin, definition.legacy_room_id])
		if maps.size() > 1:
			_errors.append("%s.zones: a door's zones must share one map" % origin)
		elif maps.size() == 1:
			_doors[door_id] = definition.with_map(maps.keys()[0])


## A trap shuts a door a rule alone operates, between the zone it is left from
## and the one outside; what it calls in is a summoned spawn of that zone.
func _check_traps() -> void:
	for trap_id: StringName in _traps.keys():
		var trap: RoomTrapDefinition = _traps[trap_id]
		var origin: String = _origins[trap_id]
		var door: DoorDefinition = _doors.get(trap.door_id)
		if door == null:
			_errors.append("%s.door: unknown door '%s'" % [origin, trap.door_id])
		elif door.operable or not door.starts_open or not door.zone_ids().has(trap.from_zone_id):
			_errors.append("%s.door: '%s' must start open, be a rule's (operable false) and border %s" % [origin, trap.door_id, trap.from_zone_id])
		for zone_id: StringName in [trap.from_zone_id, trap.to_zone_id]:
			if not _zones.has(zone_id):
				_errors.append("%s: unknown zone '%s'" % [origin, zone_id])
		if not _rooms.has(trap.room_id):
			_errors.append("%s.room: unknown room '%s'" % [origin, trap.room_id])
		if not trap.summon_spawn_id.is_empty():
			var spawn: NpcSpawnDefinition = _spawns.get(trap.summon_spawn_id)
			if spawn == null or not spawn.summoned or spawn.zone_id != trap.from_zone_id:
				_errors.append("%s.summon: '%s' must be a summoned spawn of %s" % [origin, trap.summon_spawn_id, trap.from_zone_id])


## A landmark's portals leave from its own zone; a hidden passage's second
## portal is the way back, from where the first leads to the landmark's zone.
func _resolve_landmarks() -> void:
	var hidden_owners: Dictionary[StringName, StringName] = {}
	for landmark_id: StringName in _landmarks.keys():
		if _landmarks[landmark_id].policy != &"hidden_passage":
			for portal_id: StringName in _landmarks[landmark_id].portal_ids():
				hidden_owners[portal_id] = landmark_id
	for landmark_id: StringName in _landmarks.keys():
		var definition: WorldLandmarkDefinition = _landmarks[landmark_id]
		var origin: String = _origins[landmark_id]
		var zone: ZoneDefinition = _zones.get(definition.zone_id)
		if zone == null:
			_errors.append("%s.zone: unknown zone '%s'" % [origin, definition.zone_id])
			continue
		var portal_ids: Array[StringName] = definition.portal_ids()
		for index: int in portal_ids.size():
			var portal: PortalDefinition = _portals.get(portal_ids[index])
			if portal == null:
				_errors.append("%s.portals: unknown portal '%s'" % [origin, portal_ids[index]])
			elif definition.policy == &"hidden_passage" and index == 1:
				var down: PortalDefinition = _portals.get(portal_ids[0])
				if down != null and (portal.source_zone_id != down.destination_zone_id or portal.destination_zone_id != definition.zone_id):
					_errors.append("%s.portals: '%s' does not lead from %s back to %s" % [origin, portal.portal_id, down.destination_zone_id, definition.zone_id])
			elif portal.source_zone_id != definition.zone_id:
				_errors.append("%s.portals: '%s' does not leave from %s" % [origin, portal.portal_id, definition.zone_id])
			if definition.policy == &"hidden_passage":
				# A hidden portal is closed until its one landmark opens it; no other landmark uses it.
				if hidden_owners.has(portal_ids[index]):
					_errors.append("%s.portals: '%s' is already used by %s" % [origin, portal_ids[index], hidden_owners[portal_ids[index]]])
				hidden_owners[portal_ids[index]] = landmark_id
		for role: String in ["buried", "reward"]:
			if not definition.item(role).is_empty() and not _items.has(definition.item(role)):
				_errors.append("%s.items: unknown item '%s'" % [origin, definition.item(role)])
		_landmarks[landmark_id] = definition.with_map(zone.map_id)
