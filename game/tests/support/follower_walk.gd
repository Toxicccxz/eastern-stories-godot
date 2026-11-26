extends RefCounted

## Test-only: the player walks somewhere with someone who follows them (an escort, a led NPC): through
## the doors and ways out of town with the move actions, as a player leads them, never a handoff that
## carries the follower along for the suite. go.c's follow_me(): the follower comes after the player
## into the room the player walked into, onto another map only when it stood, awake and not fighting,
## in the room the player left (WorldMapNpcLife._followers_follow, WorldMapSpells.carry_followers), so
## at each door the walk waits for it to come up first (a passage taken before it arrives would leave
## it behind, as it would a player who runs — the walk here is a test's quick one).

const MapPlaces := preload("res://tests/support/map_places.gd")

## Physics frames to wait at a door for the follower to come up (its walk goes on world time).
const WAIT_FRAMES: int = 400
## World time each physics frame of the walk: the suites hold the session's _process, so the walk
## steps the NPC heartbeat itself, a frame's worth a frame, as play does (the arrival in each room
## is noted as the player crosses into it, and who follows walks after them room by room).
const FRAME_SECONDS: float = 1.0 / 60.0

## Why the last walk stopped short ("" when it got there): for a suite's failure message.
static var failure: String = ""


## Walks the player to the middle of `zone_id` (or stops in it on arrival through its door) with
## `follower_id` (an NPC definition id) behind, by the rooms' own ways (route()): the walk on each
## map, then its door or way out, waiting at each for the follower in the room the door leaves from.
## Returns the zone's map, or null when a step fails (failure says which).
static func go_with(tree: SceneTree, session: WorldSessionController, zone_id: StringName, follower_id: StringName) -> WorldMapController:
	failure = ""
	var tick: Callable = await _ticking(tree, session)
	var map: WorldMapController = await _go_with(tree, session, zone_id, follower_id)
	tree.physics_frame.disconnect(tick)
	return map


static func _go_with(tree: SceneTree, session: WorldSessionController, zone_id: StringName, follower_id: StringName) -> WorldMapController:
	var map: WorldMapController = session.active_map() as WorldMapController
	if map == null:
		return _failed("no map")
	var steps: Array = route(_zone(session), zone_id)
	if steps.is_empty() and _zone(session) != zone_id:
		return _failed("no way by the rooms' exits and portals from %s to %s" % [_zone(session), zone_id])
	# The arrival in the room the player stands in noted first: a walk from a room the suite put
	# them in by hand starts from there.
	session.advance_npc_heartbeat(FRAME_SECONDS)
	for step: Variant in steps:
		if not step is PortalDefinition:
			continue # a room on this map on the way to the next door: the walk there crosses it
		var portal: PortalDefinition = step
		if not await _walk(tree, session, map, portal.source_zone_id):
			return null
		if not await _open_doors(tree, map, portal.source_zone_id, portal.destination_zone_id):
			return null
		if not await wait_for(tree, session, portal.source_zone_id, follower_id):
			return _failed("%s not in %s by %s: %s" % [follower_id, portal.source_zone_id, portal.portal_id, where(session, follower_id)])
		if not await MapPlaces.take_passage(tree, map, portal.portal_id):
			return _failed("%s did not take the player off %s (player in %s, fight %s)" % [portal.portal_id, map.map_id(), _zone(session), _fight(session)])
		map = await arrived(tree, session, portal.destination_map_id)
		if map == null:
			return _failed("%s did not lead onto %s" % [portal.portal_id, portal.destination_map_id])
	if not await _walk(tree, session, map, zone_id):
		return null
	return map


## The way from `from_zone` to `to_zone` by fewest steps: a zone id for each room crossed on foot
## (an ES2 exit, or a link, between zones of one map) and a PortalDefinition for each door or way
## onto another map. Hidden passages and ways with an exit rule (a guard, a toll) are not taken: a
## player leading someone walks the open road. Empty when there is none (or already there).
static func route(from_zone: StringName, to_zone: StringName) -> Array:
	var catalog: ContentCatalog = GameContent.catalog()
	var came_by: Dictionary[StringName, Array] = {from_zone: []}
	var queue: Array[StringName] = [from_zone]
	while not queue.is_empty() and not came_by.has(to_zone):
		var here: StringName = queue.pop_front()
		var zone: ZoneDefinition = catalog.zone(here)
		if zone == null:
			continue
		var next: Array = [] # [zone id, the step]
		for portal: PortalDefinition in catalog.portals_for_map(zone.map_id):
			if portal.source_zone_id == here and catalog.hidden_passage_for_portal(portal.portal_id) == null:
				next.append([portal.destination_zone_id, portal])
		var walked: Array[StringName] = zone.link_ids().duplicate()
		for room_id: StringName in zone.room_ids():
			var room: RoomDefinition = catalog.room(room_id)
			if room == null:
				continue
			for target: StringName in room.exits().values():
				var there: ZoneDefinition = catalog.zone_of_room(target)
				if there != null:
					walked.append(there.zone_id)
		for there: StringName in walked:
			var other: ZoneDefinition = catalog.zone(there)
			if other != null and other.map_id == zone.map_id and there != here:
				next.append([there, there])
		for pair: Array in next:
			var there: StringName = pair[0]
			if came_by.has(there) or not catalog.exit_rules_between(here, there).is_empty():
				continue
			var steps: Array = came_by[here].duplicate()
			steps.append(pair[1])
			came_by[there] = steps
			queue.append(there)
	return came_by.get(to_zone, [])


## The player uses the act service `service_id` that moves them (a climb down a chain, up a rope: a
## way the player leads, onto another map) with `follower_id` beside them first. Returns the map the
## act took them to, or null when they could not reach it, the follower never came up or the act
## did not move them off this map (failure says which).
static func act_with(tree: SceneTree, session: WorldSessionController, service_id: StringName, follower_id: StringName) -> WorldMapController:
	failure = ""
	var tick: Callable = await _ticking(tree, session)
	var to: WorldMapController = await _act_with(tree, session, service_id, follower_id)
	tree.physics_frame.disconnect(tick)
	return to


static func _act_with(tree: SceneTree, session: WorldSessionController, service_id: StringName, follower_id: StringName) -> WorldMapController:
	var map: WorldMapController = session.active_map() as WorldMapController
	var service: ActService = null if map == null else map.service(service_id) as ActService
	if service == null:
		return _failed("no act %s here" % service_id)
	session.advance_npc_heartbeat(FRAME_SECONDS)
	var zone_id: StringName = service.definition.zone_id
	if not await _walk(tree, session, map, zone_id):
		return null
	var spot: Vector2 = MapPlaces.service_spot(map, service_id, zone_id)
	if not await MapPlaces.drive(tree, map, spot) or not service.in_reach():
		return _failed("%s out of reach (player at %s in %s, the spot %s)" % [service_id, map.runtime_player_body().global_position, _zone(session), spot])
	if not await wait_for(tree, session, zone_id, follower_id):
		return _failed("%s not in %s by %s: %s" % [follower_id, zone_id, service_id, where(session, follower_id)])
	service.interact()
	for _frame: int in WAIT_FRAMES:
		if session.active_map() != map:
			break
		await tree.physics_frame
	var to: WorldMapController = session.active_map() as WorldMapController
	if to == null or to == map:
		return _failed("%s did not move the player off %s" % [service_id, map.map_id()])
	return await arrived(tree, session, to.map_id())


## Frames until `follower_id` stands in `zone_id` (its walk goes on world time); false when it never does.
static func wait_for(tree: SceneTree, session: WorldSessionController, zone_id: StringName, follower_id: StringName) -> bool:
	for _frame: int in WAIT_FRAMES:
		if count_in(session, zone_id, follower_id) > 0:
			return true
		session.advance_npc_heartbeat(0.2)
		await tree.physics_frame
	return false


## How many of `definition_id` stand in `zone_id`, on whichever map (present, not gone).
static func count_in(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> int:
	var found: int = 0
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				found += 1
	return found


## Where every `definition_id` is: [zone, exists_in_map, follows, life_status, fighting] each (a failure's message).
static func where(session: WorldSessionController, definition_id: StringName) -> Array:
	var found: Array = []
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
				found.append([npc.world_location().zone_id, npc.exists_in_map, npc.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), npc.life_status, npc.relationship.is_fighting()])
	return found


## The player walks into `zone_id` on `map` (no walk when already there).
static func _walk(tree: SceneTree, session: WorldSessionController, map: WorldMapController, zone_id: StringName) -> bool:
	if _zone(session) == zone_id or await MapPlaces.drive_to_zone(tree, map, zone_id):
		return true
	_failed("could not walk into %s on %s (player in %s, fight %s)" % [zone_id, map.map_id(), _zone(session), _fight(session)])
	return false


## A shut door between `from_zone` and `to_zone` (a portal's, seen from this side) opened as the
## player opens it: from in front of it. False when it will not open (locked, out of reach).
static func _open_doors(tree: SceneTree, map: WorldMapController, from_zone: StringName, to_zone: StringName) -> bool:
	for door_id: StringName in map.doors_by_id:
		var definition: DoorDefinition = GameContent.catalog().door(door_id)
		if definition == null or not definition.zone_ids().has(from_zone) or not definition.zone_ids().has(to_zone) or map.door(door_id).is_open():
			continue
		if not await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, door_id, from_zone)) or not map.open_door(door_id):
			_failed("the door %s between %s and %s would not open" % [door_id, from_zone, to_zone])
			return false
	return true


## Who is in the fight under way (empty when none): a failure's message.
static func _fight(session: WorldSessionController) -> Array[StringName]:
	var who: Array[StringName] = []
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	if coordinator.has_active_encounter():
		for participant: CombatParticipant in coordinator.active_encounter().participants():
			who.append(participant.participant_id)
	return who


static func _zone(session: WorldSessionController) -> StringName:
	return session.player_runtime().world_location().zone_id


static func _failed(why: String) -> WorldMapController:
	failure = why
	return null


## The NPC heartbeat stepped each physics frame from now (FRAME_SECONDS); disconnect the callable
## returned when the walk is over. A frame with no move key held first, the world running: a walk
## held through a freeze (a fight the suite stopped, its world back without a heartbeat) is not
## taken up until the keys are let go (WorldCharacterBody2D's movement quarantine), as a player
## lets go of them.
static func _ticking(tree: SceneTree, session: WorldSessionController) -> Callable:
	var tick: Callable = func() -> void: session.advance_npc_heartbeat(FRAME_SECONDS)
	tree.physics_frame.connect(tick)
	MapPlaces.release()
	await tree.physics_frame
	await tree.physics_frame
	return tick


## The player is on `map_id` after a crossing: the arrival's zone Areas report a frame later, the
## arrival is noted (as the next frame does in play) and the map's world is up. Null when not there.
static func arrived(tree: SceneTree, session: WorldSessionController, map_id: StringName) -> WorldMapController:
	var map: WorldMapController = session.active_map() as WorldMapController
	if map == null or map.map_id() != map_id:
		return null
	await tree.physics_frame
	session.advance_npc_heartbeat(FRAME_SECONDS)
	await MapPlaces.until_built(tree, session)
	return map
