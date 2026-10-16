extends RefCounted

## 地图重构 1b: what a building's own map needs at runtime. A wanderer goes through the
## portal its exit names (NpcRandomMove across maps): it walks to the passage, then stands
## on the other map beside the arrival marker, clear of the player; leaving the map sends
## anyone on the way through at once; a save keeps it there and a room reset brings it
## home. A door may stand on a portal (two maps, one door: shut on one, shut on both). A
## door's fade is the shorter door_fade_* and names no place. The world revision is
## SOURCE_ENTRY_REMAP_R1_V1 (绮云镇, 玉螺湖村, 天驼关 after the Snow pilot), read and written by
## its enum name.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const TRAVELLERS: StringName = &"snow.inn.travellers"
const INN_EAST: StringName = &"snow.inn.east"

var _count: int = 0
var _failures: Array[String] = []


## The inn's exits are east, up and northwest: the first, east onto the square, for the
## exit draw; every other draw its highest (nobody chats).
class East:
	extends WorldInteractionRandomSource

	func next_below(bound: int) -> int:
		return 0 if bound == 3 else bound - 1


## The square's exits are north, west, south and east: west, the inn's door.
class West:
	extends WorldInteractionRandomSource

	func next_below(bound: int) -> int:
		return 1 if bound == 4 else bound - 1


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_revision()
	_test_who_leaves_home()
	_test_door_data()
	_test_door_feel()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_crossing(tree, session)
	await _test_leaving_sends_through(tree, session)
	await _test_save_on_the_way(tree, session)
	_test_door_on_portal(session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


## Who a save may find next door on another map: one that wanders (in a mood too: 刘老农's
## grief walks him out of 刘家小房), one a COMES act calls over (the 瓜农 out of his 瓜棚);
## not the inn's waiter, who never leaves.
func _test_who_leaves_home() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_check(OldPineWorldRestoreComposition._wandered_to(catalog.npc(&"village.npc.oldliu"), &"village.home", &"village.littlegarden"), "刘老农 in his grief may be in the garden (a mood's random_move)")
	_check(OldPineWorldRestoreComposition._wandered_to(catalog.npc(&"village.npc.meloner"), &"village.melonguard", &"village.melonfarm"), "the 瓜农 may be in the 瓜地 (called over)")
	_check(not OldPineWorldRestoreComposition._wandered_to(catalog.npc(&"snow.npc.waiter"), &"snow.inn.main_floor", &"snow.square"), "the waiter never leaves the inn")


func _test_revision() -> void:
	_check(WorldContentRevision.CURRENT_PUBLIC == WorldContentRevision.Value.SOURCE_ENTRY_REMAP_R1_V1, "the R1 rollout's world revision is current")
	var named: bool = true
	for value: int in WorldContentRevision.Value.values():
		var text: String = WorldContentRevision.serialized(value as WorldContentRevision.Value)
		named = named and text == WorldContentRevision.Value.keys()[value] and WorldContentRevision.parsed(text) == value
	_check(named and WorldContentRevision.parsed("SOURCE_ENTRY_NONE") == -1, "every revision is saved and read by its enum name")
	_check(WorldContentRevision.public_support(WorldContentRevision.Value.SOURCE_ENTRY_REMAP_SNOW_V1).outcome == GameSaveResult.Outcome.INCOMPATIBLE_DEVELOPMENT_CONTRACT, "a save of the revision before is refused (New Game)")


func _test_door_data() -> void:
	var document: Dictionary = {
		"rooms": [
			{"id": "es2:d/x/street", "short": "街", "long": "s\n", "exits": {"west": "es2:d/x/shop"}},
			{"id": "es2:d/x/shop", "short": "店", "long": "o\n", "exits": {"east": "es2:d/x/street"}},
		],
		"regions": [{"id": "x", "name": "X"}],
		"maps": [
			{"id": "x.street_map", "region": "x", "scene": "res://x.tscn", "entry": "x.s"},
			{"id": "x.shop_map", "region": "x", "scene": "res://y.tscn", "entry": "x.s", "interior": true},
		],
		"zones": [
			{"id": "x.street", "map": "x.street_map", "rooms": ["es2:d/x/street"]},
			{"id": "x.shop", "map": "x.shop_map", "rooms": ["es2:d/x/shop"]},
		],
		"doors": [{"id": "x.door", "name": "门", "zones": ["x.street", "x.shop"], "reach": 90, "legacy_room": "es2:d/x/street"}],
	}
	var without: ContentCatalogBuilder = ContentCatalogBuilder.new()
	without.add_document(document.duplicate(true), "x.json")
	_check(without.build() == null and "\n".join(without.errors()).contains("x.json.doors[0].zones: a door's zones share one map or a portal joins them"), "a door between two maps needs the portal it stands on")
	document["portals"] = [{"id": "x.in", "from_zone": "x.street", "to_zone": "x.shop", "to_spawn": "x.s", "legacy_room": "es2:d/x/street", "legacy_command": "west"}]
	var unknown: Dictionary = document.duplicate(true)
	unknown["doors"][0]["zones"] = ["x.street", "x.gone"]
	var broken: ContentCatalogBuilder = ContentCatalogBuilder.new()
	broken.add_document(unknown, "x.json")
	_check(broken.build() == null and "
".join(broken.errors()).contains("x.json.doors[0].zones: unknown zone 'x.gone'"), "a door's unknown zone is reported")
	var builder: ContentCatalogBuilder = ContentCatalogBuilder.new()
	builder.add_document(document, "x.json")
	builder.build()
	_check(not "
".join(builder.errors()).contains("x.json.doors[0]"), "a door on a portal builds: %s" % [builder.errors()])
	var door: DoorDefinition = DoorDefinition.new(&"x.door", &"", "门", [&"x.street", &"x.shop"] as Array[StringName], 90).with_maps([&"x.street_map", &"x.shop_map"])
	_check(door.map_ids() == [&"x.street_map", &"x.shop_map"] and door.map_id == &"x.street_map", "the door is on both maps, its first zone's first")


func _test_door_feel() -> void:
	var feel: FeelDefinition = TestFeel.production
	_check(feel.door_fade_out_seconds == 0.08 and feel.door_fade_in_seconds == 0.12, "a door fades out in 0.08 s and in in 0.12 s (pacing.json)")
	var catalog: ContentCatalog = GameContent.catalog()
	_check(WorldResidentMapCoordinator.is_door(catalog.portal(INN_EAST)) and WorldResidentMapCoordinator.is_door(catalog.portal(SnowWorldDefinitions.INN_RETURN_PORTAL_ID)), "the inn's way out and in is a door")
	_check(catalog.map(SnowWorldDefinitions.INN_MAP_ID).interior and not catalog.map(SnowWorldDefinitions.OUTDOOR_MAP_ID).interior, "the inn is a building's own map, the town is not")
	_check(not WorldResidentMapCoordinator.is_door(catalog.portal(&"snow.crossroad.north")), "the road north to 野羊山 is no door")


## A traveller in the inn draws the exit east: it walks to the door, then stands on the
## square by the way in, and is saved there; a reset of the inn calls it home.
func _test_crossing(tree: SceneTree, session: WorldSessionController) -> void:
	var inn: WorldMapController = session.world_map_of(SnowWorldDefinitions.INN_MAP_ID)
	var square: WorldMapController = session.world_map_of(SnowWorldDefinitions.OUTDOOR_MAP_ID)
	var npc: NpcRuntimeState = _traveller(inn)
	_check(npc != null, "a traveller in the inn")
	if npc == null:
		return
	var move: NpcRandomMove.Move = NpcRandomMove.choose(GameContent.catalog(), npc.world_location().zone_id, npc.world_location().zone_id, East.new(), Callable(), true)
	_check(move != null and move.to_zone_id == &"snow.square" and move.portal_id == INN_EAST, "east is the square by the inn's door")
	_check(NpcRandomMove.choose(GameContent.catalog(), npc.world_location().zone_id, npc.world_location().zone_id, East.new(), Callable()) == null, "without across_maps it goes nowhere (a fight's walk out)")
	session.configure_npc_ambience_random_source(East.new())
	inn.npc_life._advance_ambience(0.0)
	var start: Vector2 = inn.runtime_body_for_character(npc.character_id).global_position
	_check(inn.npc_life.random_move(npc), "random_move() takes the door")
	_check(inn.npc_life.departures.has(npc.character_id) and inn.npc_life.npc_walker().is_walking(npc.character_id), "it walks to the passage first")
	_check(npc.world_location().map_id == SnowWorldDefinitions.INN_MAP_ID, "still in the inn while it walks")
	inn.npc_life.npc_walker().advance(30.0)
	var passage: Vector2 = inn.passage_position(INN_EAST)
	var body: Node2D = inn.runtime_body_for_character(npc.character_id)
	_check(body != null and body.global_position.distance_to(passage) < start.distance_to(passage) and body.global_position.distance_to(passage) < 80.0, "at the door")
	inn.npc_life.finish_departures(true)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new())
	square.npc_life._advance_ambience(0.0)
	_check(inn.find_resident_npc(npc.character_id) == null and square.find_resident_npc(npc.character_id) == npc, "through the door: one of the square's now")
	_check(npc.exists_in_map and npc.world_location().map_id == SnowWorldDefinitions.OUTDOOR_MAP_ID and npc.world_location().zone_id == &"snow.square", "on the square")
	var arrived: Node2D = square.runtime_body_for_character(npc.character_id)
	var marker: Vector2 = square.resolve_spawn_marker(SnowWorldDefinitions.SQUARE_ENTRY_SPAWN_ID).global_position
	_check(arrived != null and arrived.global_position.distance_to(marker) < 160.0 and MapPlacementValidator.is_valid_character_position(square, &"snow.square", arrived.global_position), "beside the way in, on free ground")
	# Saved there; Continue puts it back there.
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "a save with the traveller on the square")
	if snapshot != null:
		var decoded: GameSaveResult = GameSaveJsonCodec.decode(GameSaveJsonCodec.encode(snapshot).text)
		var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, tree.root)
		_check(restored.succeeded(), "Continue accepts a wanderer next door on another map: %s" % restored.path)
		if restored.succeeded():
			var fresh: WorldSessionController = restored.candidate
			_check(fresh.world_map_of(SnowWorldDefinitions.OUTDOOR_MAP_ID).find_resident_npc(npc.character_id) != null and fresh.world_map_of(SnowWorldDefinitions.INN_MAP_ID).find_resident_npc(npc.character_id) == null, "restored on the square")
			fresh.free()
			await tree.process_frame
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(TRAVELLERS)
	session.reset_room(spawn.legacy_source_room_path)
	_check(inn.find_resident_npc(npc.character_id) == npc and square.find_resident_npc(npc.character_id) == null, "the inn's reset calls it home from the square")
	_check(npc.world_location().map_id == SnowWorldDefinitions.INN_MAP_ID and npc.world_location().zone_id == spawn.zone_id, "home in the inn")


## The player goes out while a traveller is on its way to the door: it is through at once,
## and does not land on them.
func _test_leaving_sends_through(tree: SceneTree, session: WorldSessionController) -> void:
	var inn: WorldMapController = session.world_map_of(SnowWorldDefinitions.INN_MAP_ID)
	var square: WorldMapController = session.world_map_of(SnowWorldDefinitions.OUTDOOR_MAP_ID)
	var npc: NpcRuntimeState = _traveller(inn)
	if npc == null:
		_check(false, "a traveller in the inn again")
		return
	session.configure_npc_ambience_random_source(East.new())
	inn.npc_life._advance_ambience(0.0)
	_check(inn.npc_life.random_move(npc) and inn.npc_life.departures.has(npc.character_id), "on its way out")
	session.configure_npc_ambience_random_source(SouthRoad.Still.new())
	_check(session.handoff_to(SnowWorldDefinitions.OUTDOOR_MAP_ID, &"snow.square", &"snow.square", SnowWorldDefinitions.SQUARE_ENTRY_SPAWN_ID).succeeded(), "the player goes out")
	await tree.physics_frame
	_check(not inn.npc_life.departures.has(npc.character_id) and square.find_resident_npc(npc.character_id) == npc, "the one on its way is through")
	var body: Node2D = square.runtime_body_for_character(npc.character_id)
	_check(body != null and body.global_position.distance_to(square.runtime_player_body().global_position) >= 44.0, "beside the player, not on them")
	session.reset_room(GameContent.catalog().spawn(TRAVELLERS).legacy_source_room_path)
	_check(inn.find_resident_npc(npc.character_id) == npc, "home again")


## A traveller on the square on its way into the inn: a save then is one Continue takes (its
## walk ends where a body may stand, not on the passage); stopped short (a fight), it does
## not jump through the door afterwards.
func _test_save_on_the_way(tree: SceneTree, session: WorldSessionController) -> void:
	var square: WorldMapController = session.world_map_of(SnowWorldDefinitions.OUTDOOR_MAP_ID)
	var npc: NpcRuntimeState = null
	for candidate: NpcRuntimeState in square.npc_runtimes():
		if candidate.spawn_id == &"snow.outdoor.square.trav_blades" and candidate.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			npc = candidate
			break
	if not _check(npc != null and session.active_map() == square, "a 飞刀 traveller on the square, the player there"):
		return
	session.configure_npc_ambience_random_source(West.new())
	square.npc_life._advance_ambience(0.0)
	_check(square.npc_life.random_move(npc) and square.npc_life.departures.has(npc.character_id), "west: on its way into the inn")
	session.configure_npc_ambience_random_source(SouthRoad.Still.new())
	var end: Vector2 = square.npc_life.npc_walker().rest_position(npc.character_id, square.runtime_body_for_character(npc.character_id))
	_check(MapPlacementValidator.is_valid_character_position(square, &"snow.square", end), "its walk ends where a body may stand: %s" % end)
	var snapshot: GameSaveSnapshot = Work.capture(session)
	if _check(snapshot != null, "a save while it walks"):
		var decoded: GameSaveResult = GameSaveJsonCodec.decode(GameSaveJsonCodec.encode(snapshot).text)
		var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, tree.root)
		_check(restored.succeeded(), "and Continue takes it: %s" % restored.path)
		if restored.succeeded():
			var fresh: WorldSessionController = restored.candidate
			_check(fresh.world_map_of(SnowWorldDefinitions.INN_MAP_ID).find_resident_npc(npc.character_id) != null and fresh.world_map_of(SnowWorldDefinitions.OUTDOOR_MAP_ID).find_resident_npc(npc.character_id) == null, "saved through the door (its 往西离开 was told): Continue has it in the inn")
			fresh.free()
			await tree.process_frame
		# A save that puts one who never wanders on another map is refused (the inn's waiter on the square).
		var data: Dictionary = JSON.parse_string(GameSaveJsonCodec.encode(snapshot).text)
		for record: Dictionary in data["npc_spawn_states"]:
			if String(record["spawn_point_id"]).contains("waiter"):
				record["world_location"] = {"region_id": "snow", "map_id": "snow.outdoor", "zone_id": "snow.square", "combat_location_id": "snow.square"}
				record["map_position"] = {"x": 96.0, "y": 96.0}
		var edited: GameSaveResult = GameSaveJsonCodec.decode(JSON.stringify(data))
		var refused: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(edited.snapshot, tree.root) if edited.succeeded() else null
		_check(refused != null and not refused.succeeded() and refused.outcome == OldPineWorldRestoreResult.Outcome.INCONSISTENT_SPAWN_STATE, "the waiter on the square is refused")
		if refused != null and refused.succeeded():
			refused.candidate.free()
	# Stopped short (a fight cancels its walk): it stays, and may wander again.
	square.npc_life.npc_walker().cancel(npc.character_id)
	square.npc_life.finish_departures(true)
	_check(square.find_resident_npc(npc.character_id) == npc and not square.npc_life.departures.has(npc.character_id), "stopped short, it stays on the square")


## One door seen from both maps: shut on one, it is shut on the other (TEST-ONLY: a door put
## on the inn's portal; the first real one is Snow's 当铺 door).
func _test_door_on_portal(session: WorldSessionController) -> void:
	var inn: WorldMapController = session.world_map_of(SnowWorldDefinitions.INN_MAP_ID)
	var square: WorldMapController = session.world_map_of(SnowWorldDefinitions.OUTDOOR_MAP_ID)
	var catalog: ContentCatalog = GameContent.catalog()
	var id: StringName = &"test.inn.door"
	var zones: Array[StringName] = [SnowWorldDefinitions.MAIN_FLOOR_ZONE_ID, &"snow.square"]
	catalog._doors[id] = DoorDefinition.new(id, &"", "门", zones, 90, true, &"es2:d/snow/inn").with_maps([SnowWorldDefinitions.INN_MAP_ID, SnowWorldDefinitions.OUTDOOR_MAP_ID])
	_check(catalog.doors_for_map(SnowWorldDefinitions.INN_MAP_ID).has(catalog.door(id)) and catalog.doors_for_map(SnowWorldDefinitions.OUTDOOR_MAP_ID).has(catalog.door(id)), "both maps place it")
	var nodes: Array[WorldDoor] = [_door_node(inn, id), _door_node(square, id)]
	inn.set_door_open(id, false)
	_check(not nodes[0].is_open() and not nodes[1].is_open(), "shut from inside, shut from the square")
	square.set_door_open(id, true)
	_check(nodes[0].is_open() and nodes[1].is_open(), "opened from the square, open inside")
	catalog._doors.erase(id)
	for pair: Array in [[inn, nodes[0]], [square, nodes[1]]]:
		(pair[0] as WorldMapController).doors_by_id.erase(id)
		(pair[1] as WorldDoor).free()


func _door_node(map: WorldMapController, id: StringName) -> WorldDoor:
	var door: WorldDoor = WorldDoor.new()
	door.door_id = id
	var wall: CollisionShape2D = CollisionShape2D.new()
	wall.name = "Wall"
	wall.shape = RectangleShape2D.new()
	var shutter: Polygon2D = Polygon2D.new()
	shutter.name = "Shutter"
	door.add_child(wall)
	door.add_child(shutter)
	door.wall = NodePath("Wall")
	door.shutter = NodePath("Shutter")
	map.doors_by_id[id] = door
	return door


func _traveller(map: WorldMapController) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_id == TRAVELLERS and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			return npc
	return null


func _check(ok: bool, label: String) -> bool:
	_count += 1
	if not ok:
		_failures.append(label)
	return ok
