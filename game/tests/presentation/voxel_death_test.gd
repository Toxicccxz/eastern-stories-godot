extends RefCounted

## 阴间 in the fixed-angle voxel view (d/death, three maps): the fog everywhere and nothing under it,
## the long stone 奈何桥 with the dead going north in the fog and the stele at its head, the tall
## black tower of 鬼门关, 酆都城's black wall with red fires deep in its gate, 鬼门大道 between the
## two wooden houses and its few pale lanterns, a wall of fog at its end; inside, the warm 小店 with
## its fire and the four in black cloaks, and the cold 黑店 with the scrawl on its wall. No sun and no
## night. The 2D maps decide every way through: each is walked past the furniture.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
const COVERED: float = 0.11
const SCENES: Array[String] = ["death_realm", "inn1_house", "inn2_house"]
const MAPS: Array[StringName] = [&"death.realm", &"death.inn1_house", &"death.inn2_house"]
## No rooms of a house: the way through the fog.
const NO_ROOMS: Array[StringName] = [&"death.realm"]
const ENTRIES: Dictionary[StringName, Array] = {
	&"death.realm": [&"death.gate", &"death.gate.arrival"],
	&"death.inn1_house": [&"death.inn1", &"death.inn1.road1_entry"],
	&"death.inn2_house": [&"death.inn2", &"death.inn2.road1_entry"]}
const CALM: Array[StringName] = [&"death.npc.hell_guard", &"death.npc.wgargoyle", &"death.npc.bgargoyle"]
var assertions: int = 0
var failures: Array[String] = []
var _seen: Dictionary[StringName, bool] = {}


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	for scene: String in SCENES:
		furnishings._check_furnishings(load("res://scenes/world/death/%s.tscn" % scene) as PackedScene, scene)
	assertions += furnishings.assertions
	failures.append_array(furnishings.failures)
	_check_own_light()
	var kept: Dictionary[StringName, Array] = {}
	for id: StringName in CALM: # TEST-ONLY: they stay calm while the maps are walked
		var calm: NpcDefinition = GameContent.catalog().npc(id)
		if calm == null:
			continue
		kept[id] = [calm.attitude, calm._capability_ids.duplicate()]
		calm.attitude = NpcDefinition.Attitude.PEACEFUL
		calm._capability_ids.clear()
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	for map_id: StringName in MAPS:
		var entry: Array = ENTRIES[map_id]
		var map := MapPlaces.enter(session, entry[0], entry[1]) # TEST-ONLY: each map as it is drawn
		await _frames(tree, 4)
		_check(map != null and map.projected_view, "%s in its voxel view" % map_id)
		if map == null:
			continue
		for npc: NpcRuntimeState in map.npc_runtimes(): # TEST-ONLY: nobody on these maps starts a fight
			npc.character_state.attributes.bellicosity = 0
		await _check_map(tree, session, map, String(map_id))
		match map_id:
			&"death.realm": await _check_realm(tree, map)
			&"death.inn1_house": _check_inn1(map)
			&"death.inn2_house": _check_inn2(map)
	var missing: Array[StringName] = []
	for map_id: StringName in MAPS:
		if not _seen.has(map_id):
			missing.append(map_id)
	_check(missing.is_empty(), "every map of 阴间 was seen in the voxel view: missing %s" % [missing])
	session.free()
	await _frames(tree, 2)
	for id: StringName in kept:
		GameContent.catalog().npc(id).attitude = kept[id][0]
		GameContent.catalog().npc(id)._capability_ids.assign(kept[id][1])
	return {"assertions": assertions, "failures": failures}


## 美术规划 §1: no sun and no night here — every frame the same murk.
func _check_own_light() -> void:
	var light: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/death/voxel/light.json"))
	var same: bool = true
	for key: String in ["sky", "ambient", "ambient_energy", "sun", "sun_energy"]:
		var frames: Dictionary = light["outdoor"][key]
		same = same and frames.size() == 5 and frames.values().all(func(v: Variant) -> bool: return str(v) == str(frames["day"]))
	_check(same, "阴间's light: the same at every hour (no room of it is outdoors)")


func _check_realm(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	view.set_frame("", true) # TEST-ONLY: let go of the suite's own hold: the layout's is the map's
	view.set_cloud(-1, true)
	_check(view.lighting.weights.get("night", 0.0) > 0.99 and is_zero_approx(view.lighting.cloud), "no hours and no weather here: the view holds its one frame, the lamps lit, no cloud")
	var kinds: Array[String] = _kinds(view)
	var plaques: Array[String] = []
	var shades: int = 0
	for prop: Dictionary in view.layout["props"]:
		if prop["kind"] == "gate_tower":
			plaques.append(String(prop["plaque"]["text"]))
		elif prop["kind"] == "shades" and prop.get("ghostly", false):
			shades += int(prop["count"])
	_check("鬼门关" in plaques, "gate.c: 鬼门关 — 一座高大的黑色城楼")
	_check("酆都城" in plaques, "gateway.c: 城楼上刻著三个大字：酆都城")
	_check(shades >= 20, "bridge.c: 浓雾中有许多朦胧的人影; gate.c: 许多亡魂正哭哭啼啼地列队前进: %d" % shades)
	_check("overpass" in kinds, "bridge.c: 一条极长的石桥")
	var stele: bool = false
	var lanterns: int = 0
	for look: Dictionary in _looks(map):
		stele = stele or (look["kind"] == "stele" and String(look.get("text", "")) == "奈何桥")
		if look["kind"] == "lantern_post":
			lanterns += 1
	_check(stele, "bridge.c: 桥头一块石碑上面刻著「奈何桥」三个古篆")
	_check(lanterns == 3, "road2.c: 整条路前后只看到零星的几盏灯笼")
	var sink: Dictionary = view.layout["cliffs"]["sink"]
	_check("chasm" in (sink["kinds"] as Array), "bridge.c: 东、西两面都是大雾，连桥底下是不是水都看不到")
	_check(view.layout["light"].has("fog"), "road1.c: 浓浓的雾环绕在你的四周, 好像永远都不会散去似的")
	var red_lamps: int = 0
	for prop: Dictionary in view.layout["props"]:
		if prop["kind"] == "hanging_lantern" and absf(float(prop["at"][1]) - 1024.0) < 1.0 and float(prop.get("elevation", 0.0)) <= -0.9:
			red_lamps += 1
	_check(red_lamps == 2, "gateway.c: 只有少许暗红色的火光若隐若现地闪烁著 — two red lamps hung under the arch's vault, not in its wall")
	_check_passing(map, [&"death.gate", &"death.gateway", &"death.road1", &"death.road2"])
	_check(await MapPlaces.drive_through(tree, map, [&"death.gateway", &"death.road1", &"death.road2"]), "through 酆都城's gate and up 鬼门大道")
	_check(map.place_player(&"death.bridge1", MapPlaces.zone_spot(map, &"death.bridge1")), "TEST-ONLY: far out on the 奈何桥")
	await _frames(tree, 2)
	_check(await MapPlaces.drive_through(tree, map, [&"death.bridge", &"death.gate"]), "north over the 奈何桥 to 鬼门关")


func _check_inn1(map: WorldMapController) -> void:
	var hearth: bool = false
	var cloaked: int = 0
	for look: Dictionary in _looks(map):
		hearth = hearth or look["kind"] == "hearth"
		if look["kind"] == "shades" and not look.get("ghostly", false):
			cloaked += int(look["count"])
	_check(hearth, "inn1.c: 墙角壁炉里微弱的火光")
	_check(cloaked == 4, "inn1.c: 四个披著黑斗蓬的人斜靠在壁炉边的角落")
	var life: Dictionary = map.get_node("RoomLife").get_meta("rooms", {})
	_check(life.has("death.inn1"), "inn1.c: 一切看来非常的详和宁静 — a room lived in")


func _check_inn2(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	_check("scratches" in kinds, "inn2.c: 墙上(wall)刻著一些潦草的字体")
	var dim: bool = false
	for look: Dictionary in _looks(map):
		dim = dim or (look["kind"] == "lantern_post" and look.get("dim", false))
	_check(dim, "inn2.c: 墙角的一盏灯笼挣扎似地发出一阵阵微弱的光芒")
	_check(not (view.layout.get("ambience", {}).get("dust", []) as Array).is_empty(), "inn2.c: 外面的浓雾还不时地从半开著的门缝飘进来")


func _check_map(tree: SceneTree, session: WorldSessionController, map: WorldMapController, place: String) -> void:
	_seen[map.map_id()] = true
	var view: WorldVoxelView = _view_of(map)
	_check(map.projected_view and view.camera.current, "%s uses its voxel view" % place)
	_check(view.geometry.unknown_kinds.is_empty(), "every prop kind in %s is drawn: %s" % [place, view.geometry.unknown_kinds])
	_check(view.geometry.find_children("*", "OmniLight3D", true, false).size() > 0, "%s has a light" % place)
	var passages: int = 0
	for node: Node in map.find_children("*", "Area2D", true, false):
		if node is WorldPassageArea2D:
			passages += 1
	_check(view.arrows.size() == view.entrances.size() + map.doors_by_id.size() and view.entrances.size() == passages, "every way out of %s has its bobbing arrow" % place)
	var rooms: Dictionary = map.get_node("RoomLife").get_meta("rooms", {}) if map.has_node("RoomLife") else {}
	_check(map.map_id() in NO_ROOMS or not rooms.is_empty(), "%s says what its rooms are used for (lived-in)" % place)
	_check_covered(map, place)
	for door_id: StringName in map.doors_by_id: # TEST-ONLY: the doors open for the walk
		map.set_door_open(door_id, true)
	await _check_access_and_saves(tree, session, map, view)


## A house's floor is furnished to its edges (美术规划 §2).
func _check_covered(map: WorldMapController, place: String) -> void:
	if map.map_id() in NO_ROOMS:
		return
	var floor: float = 0.0
	for zone: ZoneDefinition in GameContent.catalog().zones_for_map(map.map_id()):
		floor += MapPlaces.zone_rect(map, zone.zone_id).grow(-32.0).get_area()
	var taken: float = 0.0
	for node: Node in map.get_node("Furnishings").get_children():
		var box: Vector2 = node.get_meta("footprint")
		taken += box.x * box.y
	_check(taken / floor >= COVERED, "%s: its furniture covers %.0f%% of its floor" % [place, taken / floor * 100.0])


## On the 2D map the voxel view never changes: every room has a way to it, every NPC a spot within
## reach, and the view side and the animations leave the save (and RNG) as they were.
func _check_access_and_saves(tree: SceneTree, session: WorldSessionController, map: WorldMapController, view: WorldVoxelView) -> void:
	await _frames(tree, 2)
	var starts: Array[Vector2] = [map.player_body.global_position]
	for node: Node in map.find_children("*", "Marker2D", true, false):
		starts.append((node as Node2D).global_position)
	var cut_off: Array[String] = []
	for zone: ZoneDefinition in GameContent.catalog().zones_for_map(map.map_id()):
		if not _walkable_to(map, starts, MapPlaces.zone_spot(map, zone.zone_id)):
			cut_off.append(String(zone.zone_id))
	_check(cut_off.is_empty(), "every room of %s can be walked to: cut off %s" % [map.map_id(), cut_off])
	var blocked_ways: Array[String] = []
	for node: Node in map.find_children("*", "Area2D", true, false):
		var passage := node as WorldPassageArea2D
		if passage != null and not _walkable_to(map, starts, MapPlaces.passage_spot(map, passage.portal_id)):
			blocked_ways.append(String(passage.portal_id))
	_check(blocked_ways.is_empty(), "every way out of %s can be walked to past the furniture: %s" % [map.map_id(), blocked_ways])
	var out_of_reach: Array[String] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
		if body == null or not npc.exists_in_map:
			continue
		var reach: float = WorldMapSelection.NEARBY_REACH
		var at: Vector2 = MapPlaces.spot(map, npc.world_location().zone_id, body.global_position, reach)
		if not at.is_finite() or at.distance_to(body.global_position) > reach or not _walkable_to(map, starts, at):
			out_of_reach.append(String(npc.spawn_point_id))
	_check(out_of_reach.is_empty(), "every NPC of %s can be walked up to within reach: %s" % [map.map_id(), out_of_reach])
	session.set_process(false)
	var saved: String = GameSaveJsonCodec.encode(Work.capture(session)).text
	for left: bool in [true, false]:
		view.set_view_side(left, true)
		for night: bool in [true, false]:
			view.set_night(night, true)
			view._process(0.1)
	_check(GameSaveJsonCodec.encode(Work.capture(session)).text == saved, "%s: light, view side, fog and smoke leave the save and RNG unchanged" % map.map_id())
	session.set_process(true)


## 美术规划 §2 路和空间: a body standing anywhere on the way can be walked round.
func _check_passing(map: WorldMapController, zones: Array[StringName]) -> void:
	var blocked: Array[String] = []
	var stand := Node2D.new()
	map.add_child(stand)
	for i: int in zones.size() - 1:
		var from: Vector2 = MapPlaces.zone_spot(map, zones[i])
		var to: Vector2 = MapPlaces.zone_spot(map, zones[i + 1])
		var way: PackedVector2Array = MapRoute.path(map, from, to)
		if way.is_empty():
			blocked.append("%s-%s: no way" % [zones[i], zones[i + 1]])
			continue
		for step: int in range(4, way.size() - 4, 5):
			stand.global_position = way[step]
			if MapRoute.path(map, from, to, [stand]).is_empty():
				blocked.append("%s-%s at %s" % [zones[i], zones[i + 1], way[step]])
	stand.queue_free()
	_check(blocked.is_empty(), "every stretch on %s can be walked round a body standing in it: %s" % [map.map_id(), blocked])


func _walkable_to(map: WorldMapController, starts: Array[Vector2], to: Vector2) -> bool:
	if not to.is_finite():
		return false
	for start: Vector2 in starts:
		if not MapRoute.path(map, start, to).is_empty():
			return true
	return false


func _view_of(map: WorldMapController) -> WorldVoxelView:
	return map.get_node("MapView") as WorldVoxelView


func _looks(map: WorldMapController) -> Array[Dictionary]:
	var looks: Array[Dictionary] = []
	var furnishings: Node = map.get_node_or_null("Furnishings")
	if furnishings != null:
		for node: Node in furnishings.get_children():
			looks.append(node.get_meta("look"))
	return looks


func _kinds(view: WorldVoxelView) -> Array[String]:
	var result: Array[String] = []
	for prop: Dictionary in view.layout.get("props", []):
		result.append(String(prop["kind"]))
	for look: Dictionary in _looks(view.map):
		result.append(String(look["kind"]))
	return result


func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.physics_frame
		await tree.process_frame


func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
