class_name AtlasTable
extends RefCounted

## The places on the 地图 page (atlas.json) by map ID, and which of them each map of the world
## belongs to (DECISIONS「总图」): the nearest place by the ways between maps, walked either way,
## one of the map's own region first.

var _cells: Dictionary[StringName, AtlasCell] = {}
var _homes: Dictionary[StringName, StringName] = {}
var _landmark_portals: Dictionary[StringName, bool] = {}
## The zones a door a clue finds keeps from a map's way in, by map.
var _behind_doors: Dictionary[StringName, Dictionary] = {}


func add(cell: AtlasCell, reader: ContentRecordReader = null) -> void:
	if _cells.has(cell.map_id):
		if reader != null:
			reader.fail("map", "map '%s' already has a place" % cell.map_id)
		return
	_cells[cell.map_id] = cell
	_homes.clear()


func cells() -> Array[AtlasCell]:
	var result: Array[AtlasCell] = []
	result.assign(_cells.values())
	return result


func cell(map_id: StringName) -> AtlasCell:
	return _cells.get(map_id)


## The place `map_id` belongs to, "" for a map no way joins to one.
func home_of(catalog: ContentCatalog, map_id: StringName) -> StringName:
	if _homes.is_empty():
		_fold(catalog)
	return _homes.get(map_id, &"")


## Whether a landmark (a hidden door, a vine) holds the portal, on either of its ends.
func landmark_portal(catalog: ContentCatalog, portal_id: StringName) -> bool:
	if _homes.is_empty():
		_fold(catalog)
	return _landmark_portals.has(portal_id)


## Whether a door a clue finds stands between `zone_id` and its map's way in.
func behind_door(catalog: ContentCatalog, map_id: StringName, zone_id: StringName) -> bool:
	if _homes.is_empty():
		_fold(catalog)
	return _behind_doors.get(map_id, {}).has(zone_id)


## The maps that belong to `home`, itself first.
func maps_of(catalog: ContentCatalog, home: StringName) -> Array[StringName]:
	if _homes.is_empty():
		_fold(catalog)
	var result: Array[StringName] = [home]
	for map_id: StringName in _homes:
		if _homes[map_id] == home and map_id != home:
			result.append(map_id)
	return result


func _fold(catalog: ContentCatalog) -> void:
	var near: Dictionary[StringName, Array] = {}
	for map: MapDefinition in catalog.maps():
		for step: WorldRoute.Step in WorldRoute.ways_off(catalog, map.map_id):
			if not near.has(step.from_map):
				near[step.from_map] = []
			if not near.has(step.to_map):
				near[step.to_map] = []
			near[step.from_map].append(step.to_map)
			near[step.to_map].append(step.from_map)
		for landmark: WorldLandmarkDefinition in catalog.landmarks_for_map(map.map_id):
			for portal_id: StringName in landmark.portal_ids():
				_landmark_portals[portal_id] = true
		_note_doors(catalog, map)
	for map: MapDefinition in catalog.maps():
		_homes[map.map_id] = map.map_id if _cells.has(map.map_id) else _nearest(catalog, map, near)


## From the map's way in across its zones, no clue's door crossed: the zones left over.
func _note_doors(catalog: ContentCatalog, map: MapDefinition) -> void:
	var shut: Array[DoorDefinition] = []
	for door: DoorDefinition in catalog.doors_for_map(map.map_id):
		if not door.found_by.is_empty():
			shut.append(door)
	if shut.is_empty():
		return
	var zones: Array[ZoneDefinition] = catalog.zones_for_map(map.map_id)
	var entry: StringName = &""
	for zone: ZoneDefinition in zones:
		if String(map.entry_spawn_id).begins_with(String(zone.zone_id) + ".") and String(zone.zone_id).length() > String(entry).length():
			entry = zone.zone_id
	var reached: Dictionary[StringName, bool] = {entry: true}
	var queue: Array[StringName] = [entry]
	while not queue.is_empty():
		var here: StringName = queue.pop_back()
		for zone: ZoneDefinition in zones:
			if reached.has(zone.zone_id) or not catalog.zones_adjacent(here, zone.zone_id) or _door_between(shut, here, zone.zone_id):
				continue
			reached[zone.zone_id] = true
			queue.append(zone.zone_id)
	var left: Dictionary[StringName, bool] = {}
	for zone: ZoneDefinition in zones:
		if not reached.has(zone.zone_id):
			left[zone.zone_id] = true
	_behind_doors[map.map_id] = left


func _door_between(doors: Array[DoorDefinition], a: StringName, b: StringName) -> bool:
	for door: DoorDefinition in doors:
		if door.zone_ids().has(a) and door.zone_ids().has(b):
			return true
	return false


func _nearest(catalog: ContentCatalog, map: MapDefinition, near: Dictionary[StringName, Array]) -> StringName:
	var seen: Dictionary[StringName, bool] = {map.map_id: true}
	var level: Array[StringName] = [map.map_id]
	while not level.is_empty():
		var following: Array[StringName] = []
		var found: Array[StringName] = []
		for here: StringName in level:
			var ways: Array = near.get(here, [])
			ways.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
			for there: StringName in ways:
				if seen.has(there):
					continue
				seen[there] = true
				if _cells.has(there):
					found.append(there)
				else:
					following.append(there)
		for candidate: StringName in found:
			if catalog.map(candidate).region_id == map.region_id:
				return candidate
		if not found.is_empty():
			return found[0]
		level = following
	return &""
