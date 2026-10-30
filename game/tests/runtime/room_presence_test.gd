extends RefCounted

## 室内察觉 (DECISIONS): indoors an aggressive NPC notices whoever is in its room, as ES2's
## init() did, wherever in the room they stand; nobody in the next room, however near; outdoors
## its presence circle still stands in for the room. 黑松堡's west hall (indoors) and its west
## garden (a yard, outdoors) next to it; 雪亭镇's 南大道 (outdoors) with its crazy dog.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const CASTLE: StringName = &"chuenyu.castle"
const HALL: StringName = &"chuenyu.west_blackge"
const GARDEN: StringName = &"chuenyu.west_garden"
const GUARD: StringName = &"chuenyu.npc.guard"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody wanders off
	await _test_down_the_stairs(tree, session)
	await _test_together(tree, session)
	await _test_next_room(tree, session)
	await _test_dragons_again(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_check(catalog.zone(HALL).indoors and not catalog.zone(GARDEN).indoors, "the hall is indoors, its garden (a yard) is not")
	_check(catalog.zone(&"oldpine.outdoor.keep_hall").indoors and not catalog.zone(&"oldpine.outdoor.keep_yard").indoors, "老松寨's hall is indoors on the outdoor map, its yard is not")
	_check(catalog.zone(&"chuenyu.dungeon").indoors and catalog.zone(&"village.lakebottom2").indoors and not catalog.zone(&"snow.sroad4").indoors, "a dungeon and the ice cave are indoors, a road is not")
	_check(not catalog.zone(&"chuenyu.yiantai").indoors, "the 阳台 is open air (its LPC sets outdoors)")


## Down the stairs into the hall, far from both 护院: they fall on the player at once.
func _test_down_the_stairs(tree: SceneTree, session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var map: WorldMapController = MapPlaces.enter(session, HALL, &"chuenyu.west_blackge.stairs_return") # TEST-ONLY: down from 淳于's bedroom
	if not _check(map != null and map.map_id() == CASTLE, "TEST-ONLY: down the stairs into the west hall"):
		return
	var nearest: float = INF
	for npc: NpcRuntimeState in _guards(map):
		nearest = minf(nearest, map.runtime_body_for_character(npc.character_id).global_position.distance_to(map.runtime_player_body().global_position))
	_check(nearest > float(NpcSpawnDefinition.DEFAULT_PRESENCE_RADIUS) + 17.0, "both 护院 beyond the old circle's reach: %d px" % nearest)
	await _frames(tree, coordinator)
	_check(coordinator.has_active_encounter() and _guards(map).any(func(npc: NpcRuntimeState) -> bool: return npc.relationship.has_opponent(session.player_runtime().character_id)), "the 护院 fall on whoever comes into their hall")


## Both 护院 fall on the player together, in one fight (DECISIONS「进门一起上」); the player
## flees them and stands still in the hall: they let them be until they leave the room and
## come back (a flight stands where it was), then both come on again.
func _test_together(tree: SceneTree, session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var map: WorldMapController = session.active_map() as WorldMapController
	var encounter: CombatEncounter = coordinator.active_encounter()
	if not _check(encounter != null, "the fight is on"):
		return
	var fighting: Array[NpcRuntimeState] = _guards(map).filter(func(npc: NpcRuntimeState) -> bool: return encounter.participant_for(npc.character_id) != null)
	if not _check(fighting.size() == 2 and encounter.participants().size() == 3, "both 护院 in the one fight: %d" % fighting.size()):
		_finish_fight(session)
		return
	player.state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY: the player outlasts them
	_flee(session)
	_check(not coordinator.has_active_encounter() and player.world_location().zone_id == HALL, "fled, still in the hall")
	await _frames(tree, coordinator)
	_check(not coordinator.has_active_encounter(), "standing still after the flight: they let the player be")
	# TEST-ONLY: the garden's 杀人蜂 (bellicosity 3000: attack.c's berserk dice on the player's
	# arrival, drawn from the shared NPC stream) sent away: the garden is here for the 护院 only.
	var bee: NpcRuntimeState = map.npcs.first_npc_in_zone(&"chuenyu.npc.bee", GARDEN)
	while bee != null:
		map.npcs.leave_for_good(bee)
		bee = map.npcs.first_npc_in_zone(&"chuenyu.npc.bee", GARDEN)
	var out: bool = await MapPlaces.drive_to_zone(tree, map, GARDEN)
	_check(out and not coordinator.has_active_encounter(), "out into the garden: drove %s, fight %s, at %s" % [out, coordinator.has_active_encounter(), player.world_location().zone_id])
	_check(await MapPlaces.drive_to_zone(tree, map, HALL) or coordinator.has_active_encounter(), "and back into the hall")
	await _frames(tree, coordinator)
	encounter = coordinator.active_encounter()
	_check(encounter != null and fighting.all(func(npc: NpcRuntimeState) -> bool: return encounter.participant_for(npc.character_id) != null), "back in their room: both come on again: %s" % [null if encounter == null else encounter.participants().size()])
	_finish_fight(session)


func _flee(session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		for info: CombatTacticalActionInfo in coordinator.action_infos():
			if info.action_id == CombatFleeTacticalPolicy.ACTION_ID:
				coordinator.submit_player_action(CombatTacticalRequest.new(StringName("flee:%d" % rounds), coordinator.active_encounter().encounter_id, player.character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
		rounds += 1
	session.shared_ui().dismiss_current_panel()


## In the garden by the hall's doorway, a 护院 just inside it (TEST-ONLY): within the old circle
## but in the next room, he lets the player be; one step in and he does not.
func _test_next_room(tree: SceneTree, session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var map: WorldMapController = MapPlaces.enter(session, GARDEN, &"chuenyu.west_garden.wall_arrival") # TEST-ONLY: over the wall
	if not _check(map != null and map.map_id() == CASTLE, "TEST-ONLY: in the west garden"):
		return
	for npc: NpcRuntimeState in map.npc_runtimes():
		if NpcDefinition.unnamed_id(npc.definition_id) in [&"chuenyu.npc.bee", &"chuenyu.npc.gardener"]:
			map.npcs.vanish(npc) # TEST-ONLY: only the 护院 here
	var door: Vector2 = MapPlaces.doorway(map, GARDEN, HALL)
	if not _check(door.is_finite(), "the doorway between the garden and the hall"):
		return
	var guard: NpcRuntimeState = _guards(map)[0]
	var inside: Vector2 = MapPlaces.spot(map, HALL, door + (MapPlaces.zone_centre(map, HALL) - door).normalized() * 48.0)
	var outside: Vector2 = MapPlaces.spot(map, GARDEN, door + (MapPlaces.zone_centre(map, GARDEN) - door).normalized() * 48.0)
	map.runtime_body_for_character(guard.character_id).global_position = inside # TEST-ONLY: by the doorway, inside
	_check(await MapPlaces.drive(tree, map, outside) and session.player_runtime().world_location().zone_id == GARDEN, "by the doorway, in the garden")
	_check(inside.distance_to(map.runtime_player_body().global_position) < float(NpcSpawnDefinition.DEFAULT_PRESENCE_RADIUS), "within the old circle of him")
	await _frames(tree, coordinator)
	_check(not coordinator.has_active_encounter(), "in the next room: he lets the player be")
	_check(await MapPlaces.drive_to_zone(tree, map, HALL) or coordinator.has_active_encounter(), "a step into the hall")
	await _frames(tree, coordinator)
	_check(coordinator.has_active_encounter() and guard.relationship.has_opponent(session.player_runtime().character_id), "in his room: he falls on the player")
	_finish_fight(session)


## The ice cave's dragons (a complete-set room, indoors) fall on the player together; fled
## and gone up the slope at once (another map), the player comes back down: they fall on
## them again.
func _test_dragons_again(tree: SceneTree, session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.vitality = CharacterResourceState.new(10000000, 10000000, 10000000) # TEST-ONLY: the player outlasts six dragons
	var cave: WorldMapController = MapPlaces.enter(session, &"village.lakebottom2", &"village.lakebottom2.valley_arrival") # TEST-ONLY: down from the valley
	if not _check(cave != null and cave.map_id() == &"village.icecave", "TEST-ONLY: down into the dragons' cave"):
		return
	await _frames(tree, coordinator)
	_check(coordinator.has_active_encounter() and coordinator.active_encounter().participants().size() > 2, "the dragons fall on the player together")
	_flee(session)
	_check(not coordinator.has_active_encounter() and player.world_location().zone_id == &"village.lakebottom2", "fled, still in the cave")
	for _frame: int in range(10): # the move keys come back a few frames after the fight
		await tree.physics_frame
	_check(await MapPlaces.take_passage(tree, cave, &"village.lakebottom2.westup") and session.active_map_id() == &"village.main", "up the slope at once, onto the village's map")
	var back: WorldMapController = await MapPlaces.go_to(tree, session, &"village.lakebottom2")
	_check(back != null or coordinator.has_active_encounter(), "back down into the cave")
	await _frames(tree, coordinator)
	_check(coordinator.has_active_encounter() and player.world_location().zone_id == &"village.lakebottom2", "back in their cave: they fall on the player again")
	_flee(session)


func _guards(map: WorldMapController) -> Array[NpcRuntimeState]:
	var found: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		if NpcDefinition.unnamed_id(npc.definition_id) == GUARD and npc.world_location().zone_id == HALL and npc.exists_in_map:
			found.append(npc)
	return found


func _frames(tree: SceneTree, coordinator: CombatEncounterCoordinator) -> void:
	for _frame: int in range(4):
		if coordinator.has_active_encounter():
			return
		await tree.process_frame
		await tree.physics_frame


func _finish_fight(session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY: the fight is not the point
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		var flee: CombatTacticalActionInfo = null
		for info: CombatTacticalActionInfo in coordinator.action_infos():
			if info.action_id == CombatFleeTacticalPolicy.ACTION_ID:
				flee = info
		var info: CombatTacticalActionInfo = flee if flee != null else coordinator.action_infos()[0]
		coordinator.submit_player_action(CombatTacticalRequest.new(StringName("end:%d" % rounds), coordinator.active_encounter().encounter_id, player.character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
		rounds += 1
	session.shared_ui().dismiss_current_panel()


func _check(ok: bool, label: String) -> bool:
	_count += 1
	if not ok:
		_failures.append("room presence: " + label)
	return ok
