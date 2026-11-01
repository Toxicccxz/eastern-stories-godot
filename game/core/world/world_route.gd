class_name WorldRoute
extends RefCounted

## The way from one map to another as a player who knows the roads would walk it: the fewest
## maps, through the catalog's portals (ContentCatalog.portals_for_map) and the room commands
## that move the player to another map (an `act` service whose step moves: 铁链崖's 铁索 down
## to 黄石隘口). Native (任务系统; DECISIONS「任务系统」): the quest marker on the current map
## stands over the way out this names, and the 总图, once there is one, draws the same chain.
## Pure: it reads the catalog and moves nothing.


## One way off a map: a portal, or an act service (one of the two is set).
class Step:
	extends RefCounted
	var from_map: StringName
	var to_map: StringName
	var portal: PortalDefinition
	var service: ServiceDefinition

	## The zone the way is taken from.
	func zone_id() -> StringName:
		return portal.source_zone_id if portal != null else service.zone_id


## The steps from `from_map` to `to_map` in order (a building's door, then the street's way out
## of town, then the climb down). Empty when they are one map or no chain joins them. With
## `known`, only through those maps (指路: the roads the player has walked; `to_map` always counts).
static func chain(catalog: ContentCatalog, from_map: StringName, to_map: StringName, known: Dictionary[String, int] = {}) -> Array[Step]:
	var result: Array[Step] = []
	if catalog == null or from_map.is_empty() or to_map.is_empty() or from_map == to_map:
		return result
	var came_by: Dictionary[StringName, Step] = {}
	var queue: Array[StringName] = [from_map]
	var seen: Dictionary[StringName, bool] = {from_map: true}
	while not queue.is_empty() and not seen.has(to_map):
		var here: StringName = queue.pop_front()
		for step: Step in ways_off(catalog, here):
			if step.to_map == here or seen.has(step.to_map):
				continue
			if not known.is_empty() and step.to_map != to_map and not known.has(String(step.to_map)):
				continue
			seen[step.to_map] = true
			came_by[step.to_map] = step
			queue.append(step.to_map)
	if not seen.has(to_map):
		return result
	var at: StringName = to_map
	while at != from_map:
		result.push_front(came_by[at])
		at = came_by[at].from_map
	return result


## The first step on `from_map` towards `to_map`; null when there or no way.
static func next_step(catalog: ContentCatalog, from_map: StringName, to_map: StringName, known: Dictionary[String, int] = {}) -> Step:
	var steps: Array[Step] = chain(catalog, from_map, to_map, known)
	return null if steps.is_empty() else steps[0]


## Every way off `map_id` onto another map: its portals, then its act services that move the
## player to a zone of another map (each service once, by the first such step).
static func ways_off(catalog: ContentCatalog, map_id: StringName) -> Array[Step]:
	var result: Array[Step] = []
	for portal: PortalDefinition in catalog.portals_for_map(map_id):
		if portal.destination_map_id == map_id:
			continue
		var step := Step.new()
		step.from_map = map_id
		step.to_map = portal.destination_map_id
		step.portal = portal
		result.append(step)
	for service: ServiceDefinition in catalog.services_for_map(map_id):
		var there: StringName = moves_to(catalog, service)
		if there.is_empty() or there == map_id:
			continue
		var step := Step.new()
		step.from_map = map_id
		step.to_map = there
		step.service = service
		result.append(step)
	return result


## The map an act service's command moves the player to (its first MOVE step's zone), or "".
static func moves_to(catalog: ContentCatalog, service: ServiceDefinition) -> StringName:
	if service == null or service.act == null:
		return &""
	for act: ScriptedAct in service.act.acts:
		for step: ScriptedAct.Step in act.steps:
			if step.kind == ScriptedAct.Kind.MOVE and not step.zone_id.is_empty():
				var zone: ZoneDefinition = catalog.zone(step.zone_id)
				if zone != null:
					return zone.map_id
	return &""
