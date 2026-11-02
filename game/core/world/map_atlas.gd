class_name MapAtlas
extends RefCounted

## What the player knows of the world (地图页; DECISIONS「总图」): the places they have reached,
## the ones an ordinary way off those leads to, what stands in them and where the way goes now.
## Pure: it reads the definitions and CharacterState.visited_maps, and hides what a player has
## to find (a landmark's way, a door behind a clue, a room command).

## How much of a place the player knows.
enum Seen { UNSEEN, ROAD, REACHED }

const MASTER: StringName = &"master"
const SHOP: StringName = &"shop"
const BANK: StringName = &"bank"
const HOCKSHOP: StringName = &"hockshop"
const BOUNTY: StringName = &"bounty"
const ERRAND: StringName = &"errand"
const TARGET: StringName = &"target"
## Marks in the order the page lists them.
const MARK_KINDS: Array[StringName] = [TARGET, MASTER, SHOP, BANK, HOCKSHOP, BOUNTY, ERRAND]


## Something worth walking to: `who` a name, the service's or an objective.
class Mark:
	extends RefCounted
	var kind: StringName
	var who: String
	var map_id: StringName
	var zone_id: StringName


## Where the marker leads: the player's 指路 or else the tracked quest's target.
class Goal:
	extends RefCounted
	var map_id: StringName
	var zone_id: StringName
	var waypoint: bool = false


## `map_id` is under the player's feet: the first time counts.
static func note_visit(state: CharacterState, map_id: StringName) -> void:
	if state == null or map_id.is_empty() or state.visited_maps.has(String(map_id)):
		return
	state.visited_maps[String(map_id)] = state.visited_maps.size() + 1


static func seen(catalog: ContentCatalog, state: CharacterState, cell: StringName) -> Seen:
	var table: AtlasTable = catalog.atlas()
	var known: Seen = Seen.UNSEEN
	for map_id: StringName in table.maps_of(catalog, cell):
		if state.visited_maps.has(String(map_id)):
			return Seen.REACHED
	for visited: String in state.visited_maps:
		for portal: PortalDefinition in catalog.portals_for_map(StringName(visited)):
			if table.home_of(catalog, portal.destination_map_id) == cell and plain(catalog, portal):
				known = Seen.ROAD
	return known


## A way any passer-by sees: neither a landmark's nor behind a door a clue finds.
static func plain(catalog: ContentCatalog, portal: PortalDefinition) -> bool:
	var table: AtlasTable = catalog.atlas()
	if table.landmark_portal(catalog, portal.portal_id) or table.behind_door(catalog, portal.source_map_id, portal.source_zone_id):
		return false
	for door: DoorDefinition in catalog.doors_for_map(portal.source_map_id):
		if door.found_by.is_empty():
			continue
		if door.zone_ids().has(portal.source_zone_id) and door.zone_ids().has(portal.destination_zone_id):
			return false
	return true


## The maps of `cell` the player knows of: those they stood on and those a plain way off them
## leads to, the place's own map first.
static func known_maps(catalog: ContentCatalog, state: CharacterState, cell: StringName) -> Array[StringName]:
	var table: AtlasTable = catalog.atlas()
	var result: Array[StringName] = []
	var queue: Array[StringName] = []
	for map_id: StringName in table.maps_of(catalog, cell):
		if state.visited_maps.has(String(map_id)):
			result.append(map_id)
			queue.append(map_id)
	while not queue.is_empty():
		for portal: PortalDefinition in catalog.portals_for_map(queue.pop_front()):
			var there: StringName = portal.destination_map_id
			if result.has(there) or table.home_of(catalog, there) != cell or not plain(catalog, portal):
				continue
			result.append(there)
			queue.append(there)
	return result


## How many of the maps known of in `cell` the player has not been in yet.
static func unvisited(catalog: ContentCatalog, state: CharacterState, cell: StringName) -> int:
	var count: int = 0
	for map_id: StringName in known_maps(catalog, state, cell):
		if not state.visited_maps.has(String(map_id)):
			count += 1
	return count


## What stands in the part of `cell` the player knows of, in MARK_KINDS order, by name within
## a kind. Who only comes with the story (`starts_absent`) is not marked.
static func marks(catalog: ContentCatalog, state: CharacterState, cell: StringName) -> Array[Mark]:
	var found: Dictionary[String, Mark] = {}
	for map_id: StringName in known_maps(catalog, state, cell):
		for spawn: NpcSpawnDefinition in catalog.spawns_for_map(map_id):
			var npc: NpcDefinition = null if spawn.starts_absent else catalog.npc(spawn.npc_definition_id)
			if npc == null:
				continue
			if takes_students(npc):
				_mark(found, MASTER, npc.display_name, map_id, spawn.zone_id)
			if not npc.dealings().vendor_id.is_empty():
				_mark(found, SHOP, npc.display_name, map_id, spawn.zone_id)
			if npc.dealings().quest_giver:
				_mark(found, ERRAND, npc.display_name, map_id, spawn.zone_id)
		for service: ServiceDefinition in catalog.services_for_map(map_id):
			if service.kind in [BANK, HOCKSHOP, BOUNTY]:
				_mark(found, service.kind, service.display_name, map_id, service.zone_id)
	var target: StoryQuestDefinition.Target = StoryQuestLog.target(state, catalog.story_quests())
	if target != null and known_maps(catalog, state, cell).has(target.map_id):
		_mark(found, TARGET, StoryQuestLog.objective(state, catalog.story_quests()), target.map_id, target.zone_id)
	var result: Array[Mark] = []
	result.assign(found.values())
	result.sort_custom(func(a: Mark, b: Mark) -> bool:
		var order: int = MARK_KINDS.find(a.kind) - MARK_KINDS.find(b.kind)
		return order < 0 if order != 0 else a.who < b.who)
	return result


static func _mark(found: Dictionary[String, Mark], kind: StringName, who: String, map_id: StringName, zone_id: StringName) -> void:
	var key: String = "%s/%s/%s" % [kind, who, zone_id]
	if found.has(key):
		return
	var mark := Mark.new()
	mark.kind = kind
	mark.who = who
	mark.map_id = map_id
	mark.zone_id = zone_id
	found[key] = mark


## An NPC one can ask to be taught by, whatever comes of asking.
static func takes_students(npc: NpcDefinition) -> bool:
	var teaching: NpcTeaching = npc.teaching()
	if teaching == null:
		return false
	if not teaching.recognize_rules.is_empty():
		return true
	return teaching.apprentice != null and teaching.apprentice.kind not in [NpcTeaching.Kind.REFUSES, NpcTeaching.Kind.SILENT]


## The way from `from_map` to `to_map` over the roads the player has walked; empty when they
## are one map or none joins them.
static func route(catalog: ContentCatalog, state: CharacterState, from_map: StringName, to_map: StringName) -> Array[WorldRoute.Step]:
	return WorldRoute.guided(catalog, from_map, to_map, state.visited_maps)


## Whether the player can be shown the way from `from_map` to `to_map`.
static func can_walk(catalog: ContentCatalog, state: CharacterState, from_map: StringName, to_map: StringName) -> bool:
	return from_map == to_map or not route(catalog, state, from_map, to_map).is_empty()


## The player asks to be shown the way; "" takes it back.
static func point_to(state: CharacterState, map_id: StringName, zone_id: StringName = &"") -> void:
	state.waypoint_map = map_id
	state.waypoint_zone = zone_id if not map_id.is_empty() else &""


## Whether the player stands where they asked to be shown: on the map, in the zone if one was named.
static func arrived(state: CharacterState, map_id: StringName, zone_id: StringName) -> bool:
	if state.waypoint_map.is_empty() or state.waypoint_map != map_id:
		return false
	return state.waypoint_zone.is_empty() or state.waypoint_zone == zone_id


## Where the marker leads now; null when nowhere.
static func goal(catalog: ContentCatalog, state: CharacterState) -> Goal:
	var result := Goal.new()
	if not state.waypoint_map.is_empty() and catalog.map(state.waypoint_map) != null:
		result.map_id = state.waypoint_map
		result.zone_id = state.waypoint_zone
		result.waypoint = true
	else:
		var target: StoryQuestDefinition.Target = StoryQuestLog.target(state, catalog.story_quests())
		if target == null:
			return null
		result.map_id = target.map_id
		result.zone_id = target.zone_id
	return result


## The place the 沙盘's arrow stands on: the goal's when the player knows of its map, else the
## last place they know on the way there.
static func arrow_cell(catalog: ContentCatalog, state: CharacterState, from_map: StringName, goal_map: StringName) -> StringName:
	var table: AtlasTable = catalog.atlas()
	var home: StringName = table.home_of(catalog, goal_map)
	if not home.is_empty() and known_maps(catalog, state, home).has(goal_map):
		return home
	var last: StringName = from_map
	for step: WorldRoute.Step in WorldRoute.guided(catalog, from_map, goal_map):
		if state.visited_maps.has(String(step.from_map)):
			last = step.from_map
	return table.home_of(catalog, last)
