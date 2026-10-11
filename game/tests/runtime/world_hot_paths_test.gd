extends RefCounted

## Runtime paths made cheaper must give what they gave before (performance, owner
## 2026-10-11): the walker's KEEP_CLEAR filter, its grids kept by area while the same
## walls stand, the map's static nodes, a fight's bindings made for its participants only.
## Room resets on the maps holding the room's content only are compared whole (same seeds,
## same save) outside the suites.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_test_clear_of(session)
	_test_static_nodes(session)
	await _test_grids_follow_doors(tree, session)
	await _test_fight_bindings(tree, session)
	_test_room_maps()
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _map(session: WorldSessionController, map_id: StringName) -> WorldMapController:
	for map: WorldMapController in session.world_maps():
		if map.map_id() == map_id:
			return map
	return null


## The filter keeps exactly the cells every other body is at least KEEP_CLEAR from.
func _test_clear_of(session: WorldSessionController) -> void:
	var map: WorldMapController = _map(session, &"choyin.town")
	var zone: WorldPhysicalZoneArea2D = map.physical_zones()[0]
	var grid: WorldNpcWalker.Grid = WorldNpcWalker.Grid.new(map, zone.global_rect())
	var cells: Array[Vector2i] = grid.free_cells_in(zone.global_rect())
	var random := RandomNumberGenerator.new()
	random.seed = 1011
	var area: Rect2 = zone.global_rect().grow(80.0)
	var others: Array[Vector2] = []
	for i: int in range(60):
		others.append(Vector2(random.randf_range(area.position.x, area.end.x), random.randf_range(area.position.y, area.end.y)))
	others.append(grid.center_of(cells[0]) + Vector2(WorldNpcWalker.KEEP_CLEAR, 0.0)) # exactly KEEP_CLEAR away: that cell stays
	others.append(Vector2(-100000.0, -100000.0))
	var expected: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if others.all(func(other: Vector2) -> bool: return other.distance_to(grid.center_of(cell)) >= WorldNpcWalker.KEEP_CLEAR):
			expected.append(cell)
	var kept: Array[Vector2i] = WorldNpcWalker._clear_of(grid, cells, others)
	_check(kept == expected, "the KEEP_CLEAR filter keeps the same cells in the same order (%d of %d)" % [kept.size(), cells.size()])
	_check(kept.size() > 0 and kept.size() < cells.size(), "the case is not trivial: %d of %d kept" % [kept.size(), cells.size()])


## What the map keeps is what a walk of its whole tree finds.
func _test_static_nodes(session: WorldSessionController) -> void:
	for map_id: StringName in [&"snow.outdoor", &"cloud.outdoor"]:
		var map: WorldMapController = _map(session, map_id)
		var parts: WorldMapStaticNodes = map.static_nodes()
		var shapes: Array[CollisionShape2D] = []
		for node: Node in map.find_children("*", "CollisionShape2D", true, false):
			if node.get_parent() is StaticBody2D:
				shapes.append(node as CollisionShape2D)
		var layers: Array[TileMapLayer] = []
		layers.assign(map.find_children("*", "TileMapLayer", true, false))
		var passages: Array[WorldPassageArea2D] = []
		var doors: Array[WorldDoor] = []
		for node: Node in map.find_children("*", "", true, false):
			if node is WorldPassageArea2D:
				passages.append(node as WorldPassageArea2D)
			elif node is WorldDoor:
				doors.append(node as WorldDoor)
		_check(parts.static_shapes == shapes and parts.layers == layers and parts.passages == passages and map.doors() == doors, "%s: kept walls, layers, passages and doors are the scene's" % map_id)
		_check(not shapes.is_empty() and not layers.is_empty() and not passages.is_empty(), "%s has each kind" % map_id)


## A kept grid is the one Grid.new() builds now; a door opened or shut builds it again.
func _test_grids_follow_doors(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = _map(session, &"snow.outdoor")
	var door_id: StringName = &"snow.school.gate"
	var door: WorldDoor = map.door(door_id)
	var walker: WorldNpcWalker = map.npc_life.npc_walker()
	var area: Rect2 = Rect2(door.wall_shape().global_position - Vector2(96.0, 96.0), Vector2(192.0, 192.0))
	var first: WorldNpcWalker.Grid = walker._grid(area)
	_check(walker._grid(area) == first, "the same area while the same walls stand: the same grid")
	_check(_same_solids(first, WorldNpcWalker.Grid.new(map, area)), "the kept grid is the grid built now")
	var was_open: bool = door.is_open()
	door.set_open(not was_open)
	await tree.process_frame
	var other: WorldNpcWalker.Grid = walker._grid(area)
	_check(other != first, "the door %s: the grid is built again" % ("shut" if was_open else "opened"))
	_check(_same_solids(other, WorldNpcWalker.Grid.new(map, area)), "and it is the grid built now")
	_check(not _same_solids(other, first), "the doorway is walkable in one and not the other")
	door.set_open(was_open)
	await tree.process_frame
	_check(_same_solids(walker._grid(area), first), "back as it was: the first grid's cells again")


func _same_solids(a: WorldNpcWalker.Grid, b: WorldNpcWalker.Grid) -> bool:
	if a._size != b._size or a._origin != b._origin:
		return false
	for y: int in a._size.y:
		for x: int in a._size.x:
			if a._astar.is_point_solid(Vector2i(x, y)) != b._astar.is_point_solid(Vector2i(x, y)):
				return false
	return true


## A fight on a map full of people: each participant's binding is the one binding every
## resident would give it.
func _test_fight_bindings(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = _map(session, &"choyin.town")
	var definition: MapDefinition = GameContent.catalog().map(map.map_id())
	var entry: WorldSpawnMarker2D = map.resolve_spawn_marker(definition.entry_spawn_id)
	var zone_id: StringName = &""
	for zone: WorldPhysicalZoneArea2D in map.physical_zones():
		if zone.contains_center(entry.global_position):
			zone_id = zone.zone_id
	_check(session.handoff_to(map.map_id(), zone_id, GameContent.catalog().zone(zone_id).combat_location_id, definition.entry_spawn_id).succeeded(), "to 乔阴 town")
	for i: int in range(3):
		await tree.physics_frame
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	for npc: NpcRuntimeState in map.npcs.residents:
		if not npc.exists_in_map or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
			continue
		# TEST-ONLY: the NPC brought beside the player.
		map.runtime_body_for_character(npc.character_id).global_position = map.player_body.global_position + Vector2(40.0, 0.0)
		npc.set_world_location(session.player_runtime().world_location())
		await tree.physics_frame
		if map.select_npc(npc.character_id):
			map.spar_selected()
			if coordinator.has_active_encounter():
				break
	_check(coordinator.has_active_encounter() and map.npcs.residents.size() > 40, "a spar among %d residents" % map.npcs.residents.size())
	if not coordinator.has_active_encounter():
		return
	var encounter: CombatEncounter = coordinator.active_encounter()
	var bindings: Array[CombatSliceCharacterBinding] = session.encounter_combat_bindings(encounter)
	var everyone: Array[CombatSliceCharacterBinding] = map.combat_lifecycle.build_participants(true)
	_check(bindings.size() == encounter.participants().size(), "one binding per participant")
	for index: int in range(bindings.size()):
		var participant: CombatParticipant = encounter.participants()[index]
		var made: CombatSliceCharacterBinding = bindings[index]
		var full: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(everyone, participant.participant_id)
		_check(
			made.character_id == full.character_id and made.state == full.state and made.relationship == full.relationship
			and made.busy == full.busy and made.armor == full.armor and made.location_id == full.location_id
			and made.exists_in_encounter == full.exists_in_encounter and made.life_status == full.life_status
			and made.is_user == full.is_user and made.combat_available == full.combat_available
			and made.content.limbs() == full.content.limbs() and made.content.is_valid() == full.content.is_valid()
			and made.post_actions == full.post_actions,
			"%s: the binding all residents' list gives it" % participant.participant_id,
		)
	coordinator.advance_scheduler(1.0)
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "the fight goes on")


## Every room a map's reset acts on lists that map.
func _test_room_maps() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var maps_by_room: Dictionary[String, Array] = WorldRoomResets.maps_by_room()
	var missing: Array[String] = []
	for map: MapDefinition in catalog.maps():
		for spawn: NpcSpawnDefinition in catalog.spawns_for_map(map.map_id):
			if not maps_by_room.get(spawn.legacy_source_room_path, []).has(map.map_id):
				missing.append(spawn.spawn_id)
		for spawn: ItemSpawnDefinition in catalog.item_spawns_for_map(map.map_id):
			if not maps_by_room.get(spawn.legacy_source_room_path, []).has(map.map_id):
				missing.append(spawn.spawn_id)
		for landmark: WorldLandmarkDefinition in catalog.landmarks_for_map(map.map_id):
			if not maps_by_room.get(landmark.legacy_source_path, []).has(map.map_id):
				missing.append(landmark.landmark_id)
	_check(missing.is_empty(), "every spawn, item spawn and landmark's room lists its map: %s" % [missing])


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures.append(label)
