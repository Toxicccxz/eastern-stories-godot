extends RefCounted

## 黑松山 in the fixed-angle voxel view (d/chuenyu, four maps): the 黄土大道 past the roadside tea house,
## the paddies and the clear stream, the 羊肠小路 up between pine-dark slopes and 面目狰狞的巨石 to the
## granite street, the 铁索桥 over the 万丈深渊, the castle's vine-hung walls and its gate under the gold
## board 黑松淳于; inside, the sandalwood halls and the four gardens; 淳于's rooms upstairs; the 地牢's
## dark passages and 刑房. The 2D maps decide every way through: each is walked past the furniture.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
const COVERED: float = 0.11
const SCENES: Array[String] = ["chuenyu_main", "castle", "chuenyu_upstairs", "chuenyu_prison"]
const MAPS: Array[StringName] = [&"chuenyu.main", &"chuenyu.castle", &"chuenyu.upstairs", &"chuenyu.prison"]
## No rooms of a house: the mountain, and the dungeon (a cave: no lived-in layer).
const NO_ROOMS: Array[StringName] = [&"chuenyu.main", &"chuenyu.prison"]
const ENTRIES: Dictionary[StringName, Array] = {
	&"chuenyu.main": [&"chuenyu.croad1", &"chuenyu.croad1.village_arrival"],
	&"chuenyu.castle": [&"chuenyu.east_garden", &"chuenyu.east_garden.wall_arrival"],
	&"chuenyu.upstairs": [&"chuenyu.bedroom", &"chuenyu.bedroom.west_stairs_arrival"],
	&"chuenyu.prison": [&"chuenyu.tunnel1", &"chuenyu.tunnel1.north_arrival"]}
const CALM: Array[StringName] = [&"chuenyu.npc.wolfdog", &"chuenyu.npc.chuenyu", &"chuenyu.npc.guard", &"chuenyu.npc.guard2", &"chuenyu.npc.jiading3",
	&"chuenyu.npc.cook", &"chuenyu.npc.highrat", &"chuenyu.npc.bee"]
var assertions: int = 0
var failures: Array[String] = []
var _seen: Dictionary[StringName, bool] = {}


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	for scene: String in SCENES:
		furnishings._check_furnishings(load("res://scenes/world/chuenyu/%s.tscn" % scene) as PackedScene, scene)
	assertions += furnishings.assertions
	failures.append_array(furnishings.failures)
	_check_own_colours()
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
			&"chuenyu.main": await _check_main(tree, session, map)
			&"chuenyu.castle": _check_castle(map)
			&"chuenyu.prison": _check_prison(map)
	var missing: Array[StringName] = []
	for map_id: StringName in MAPS:
		if not _seen.has(map_id):
			missing.append(map_id)
	_check(missing.is_empty(), "every map of 黑松山 was seen in the voxel view: missing %s" % [missing])
	session.free()
	await _frames(tree, 2)
	for id: StringName in kept:
		GameContent.catalog().npc(id).attitude = kept[id][0]
		GameContent.catalog().npc(id)._capability_ids.assign(kept[id][1])
	return {"assertions": assertions, "failures": failures}


## 美术规划 §1: 墨绿、冷灰、暗褐 — its own light and its black pines, told apart from 老松林's.
func _check_own_colours() -> void:
	var light: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chuenyu/voxel/light.json"))
	var frames: int = 0
	for key: String in ["sky", "ambient", "sun"]:
		frames += (light["outdoor"][key] as Dictionary).size()
	var overcast := Color(String(light["outdoor"]["overcast"]["sky"]))
	_check(frames == 15 and overcast.g >= overcast.r, "the region's light: five frames each, cloud a green-grey")
	var flora: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chuenyu/voxel/flora.json"))
	var pine := Color(String(flora["crown_colors"]["old_pine"][0]))
	_check(pine.v < 0.25 and (flora["grass_colors"] as Array).size() >= 4 and (flora["flower_colors"] as Array).size() >= 4, "base_b_m.c: 黑湮湮的松林 — the pines near black")


func _check_main(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	_check(not "rock" in (view.layout["cliffs"]["kinds"] as Array), "rock is walkable ground in 2D: never raised into a cliff")
	for kind: String in ["gate_tower", "city_wall", "vines", "overpass", "iron_chain", "flagpole", "boulder", "tea_stall", "bench", "far_peak", "compound_wall"]:
		_check(kind in kinds, "黑松山 has its %s" % kind)
	var gate: Dictionary = {}
	var flag: Dictionary = {}
	for prop: Dictionary in view.layout["props"]:
		if prop["kind"] == "gate_tower":
			gate = prop
		elif prop["kind"] == "flagpole":
			flag = prop
	_check(not gate.is_empty() and String(gate["plaque"]["text"]) == "黑松淳于", "gate_castle.c: 金匾上龙飞凤舞的写着四个大字“黑松淳于”")
	_check(not flag.is_empty() and String(flag["text"]) == "淳于", "sunnyroad.c: 城堡的最顶端插着一面大旗…两个斗大的金字：淳于")
	var sink: Dictionary = view.layout["cliffs"]["sink"]
	_check(float(sink["depth"]) >= 12.0 and "chasm" in (sink["kinds"] as Array), "rope_bridge.c: 脚下的万丈深渊")
	_check(String(view.geometry._ground_style(Vector2(2000, 2100), "forest").get("style", "")) == "paddy", "sunnyroad.c: 你的两侧是茂盛的稻田")
	# The seam with 玉螺湖村 as wide as the village's spur west (its passage 160 tall).
	var tall: float = 0.0
	for node: Node in map.find_children("*", "Area2D", true, false):
		var passage := node as WorldPassageArea2D
		if passage != null and passage.portal_id == &"chuenyu.croad1.south":
			for child: Node in passage.get_children():
				if child is CollisionShape2D:
					tall = ((child as CollisionShape2D).shape as RectangleShape2D).size.y
	_check(tall >= 160.0, "the way east to 玉螺湖村 as wide as the village's end of it: %d" % tall)
	var arrow: Node3D = view.arrows.get(&"chuenyu.croad1.south")
	_check(arrow != null, "the way to the village has its bobbing arrow")
	_check_passing(map, [&"chuenyu.croad1", &"chuenyu.croad2", &"chuenyu.sunnyroad", &"chuenyu.base_b_m", &"chuenyu.foot_b_mtn", &"chuenyu.high_b_mtn", &"chuenyu.gate_castle"])
	_check(await MapPlaces.drive_through(tree, map, [&"chuenyu.croad2", &"chuenyu.sunnyroad", &"chuenyu.base_b_m", &"chuenyu.foot_b_mtn", &"chuenyu.high_b_mtn"]),
		"up past the paddies and the 羊肠小路 to the granite street")
	_check(map.place_player(&"chuenyu.base_b_m", MapPlaces.zone_spot(map, &"chuenyu.base_b_m")), "TEST-ONLY: back at the mountain's foot")
	await _frames(tree, 2)
	# The east street, not the bridge: the 家丁 guard it (jiading3.c), the walk is the way's.
	session.player_runtime().state.progression.combat_experience = 2000 # TEST-ONLY: past the gate's 杀气 (gate_castle.c: combat_exp < 2000)
	_check(await MapPlaces.drive_through(tree, map, [&"chuenyu.high_b_mtn2", &"chuenyu.gate_castle"]), "up the east street to the gate")


func _check_castle(map: WorldMapController) -> void:
	var scroll: bool = false
	var rock: bool = false
	for look: Dictionary in _looks(map):
		scroll = scroll or (look["kind"] == "wall_scroll" and look.get("calligraphy", false))
		rock = rock or look["kind"] == "boulder"
	_check(scroll, "center.c: 厅口悬着一幅字画")
	var view: WorldVoxelView = _view_of(map)
	var rope: Vector2 = Vector2.INF
	for prop: Dictionary in view.layout["props"]:
		if prop["kind"] == "hanging_rope":
			rope = Vector2(float(prop["at"][0]), float(prop["at"][1]))
	var pull: WorldService = map.service(&"chuenyu.center.pull")
	_check(rope.is_finite() and pull != null and pull.anchor().distance_to(rope) <= 64.0, "center.c: 这根绳子顺着墙垂下来 — pulled where it hangs")
	var hold: Vector2 = MapPlaces.service_spot(map, &"chuenyu.center.pull")
	_check(hold.is_finite() and hold.distance_to(pull.anchor()) <= 96.0, "there is room to stand at the rope and pull it")
	_check(rock, "north_garden.c: 再通向北面的路被一块巨石(rock)堵死")
	var life: Dictionary = map.get_node("RoomLife").get_meta("rooms", {})
	_check(String(life.get("chuenyu.center", {}).get("use", "")) == "parlour", "center.c: the sandalwood hall receives guests")


func _check_prison(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	_check(kinds.count("torch") == 9, "tunnel1.c: 唯一的光亮来自墙上忽明忽暗的松油灯 — one in each of the nine rooms")
	_check("light_shaft" in kinds, "tunnel4.c: 从石板的缝隙间射进几束阳光")
	_check(kinds.count("chained_bones") == 2 and kinds.count("punishment_tools") == 4, "dungeon.c: 骷髅被生锈的铁链绑在墙上; tortureroom.c: 墙上挂满了各式各样的邢具")
	var life: Node = map.get_node_or_null("RoomLife")
	_check(life == null or (life.get_meta("rooms", {}) as Dictionary).is_empty(), "a dungeon: no lived-in layer")


func _check_map(tree: SceneTree, session: WorldSessionController, map: WorldMapController, place: String) -> void:
	_seen[map.map_id()] = true
	var view: WorldVoxelView = _view_of(map)
	_check(map.projected_view and view.camera.current, "%s uses its voxel view" % place)
	_check(view.geometry.unknown_kinds.is_empty(), "every prop kind in %s is drawn: %s" % [place, view.geometry.unknown_kinds])
	_check(view.geometry.find_children("*", "OmniLight3D", true, false).size() > 0, "%s has a light for the night" % place)
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


## A house's floor is furnished to its edges (美术规划 §2); the balcony is open air.
func _check_covered(map: WorldMapController, place: String) -> void:
	if map.map_id() in NO_ROOMS:
		return
	var floor: float = 0.0
	for zone: ZoneDefinition in GameContent.catalog().zones_for_map(map.map_id()):
		if zone.zone_id == &"chuenyu.yiantai":
			continue
		floor += MapPlaces.zone_rect(map, zone.zone_id).grow(-32.0).get_area()
	var taken: float = 0.0
	for node: Node in map.get_node("Furnishings").get_children():
		var box: Vector2 = node.get_meta("footprint")
		taken += box.x * box.y
	_check(taken / floor >= COVERED, "%s: its furniture covers %.1f%% of its floor" % [place, taken / floor * 100.0])


## On the 2D map the voxel view never changes: every room has a way to it, every NPC a spot within
## reach, and day, night, the view side and the animations leave the save (and RNG) as they were.
func _check_access_and_saves(tree: SceneTree, session: WorldSessionController, map: WorldMapController, view: WorldVoxelView) -> void:
	await _frames(tree, 2)
	var starts: Array[Vector2] = [map.player_body.global_position]
	for node: Node in map.find_children("*", "Marker2D", true, false):
		var id: String = str(node.get("spawn_point_id"))
		if id.ends_with("_arrival") or id.ends_with("_entry") or id.ends_with("_return"):
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
	_check(GameSaveJsonCodec.encode(Work.capture(session)).text == saved, "%s: light, view side, wind and smoke leave the save and RNG unchanged" % map.map_id())
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
