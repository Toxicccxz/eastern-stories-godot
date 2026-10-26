extends RefCounted

## 灵心观 in the fixed-angle voxel view: the 青石官道 from 雪亭镇's mountain road, the white quartz
## stairs zigzagging up between rows of tall pines with a stone lantern at every landing, 雪亭镇
## far below to the west, the white tower on the far peak, the 山门 inscribed 「灵心观」 with the
## temple's roofs over its wall; inside, the square of white quartz with its lions, dragon
## pillars and great censer, the main hall with its red door and round arches, the walkways of
## vermilion columns round the courtyard and its well, flowers and trees, the rear hall, the
## training hall, the guest rooms, the locked room, the mossy path of blue stones under the pines
## to the 藏经楼 under its blue board, and its tablet; every hall and room inside after its text.
## The colours are the mountain's own (山绿, 纯白, 朱红: no blossom, no maples), every way out has
## its arrow, and every stretch of the climb and the walkways can be walked round a body standing
## in it. The 2D maps decide every way through; the walk comes up from 雪亭镇 to the gate.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
## Decor tall enough to walk into: in a voxel config it must stand on blocking ground (rock, a
## wall, a blocked box) or be raised clear of the floor (`elevation`).
const TALL: Array[String] = ["lantern", "stone_lantern", "standing_rock", "boulder", "banner", "tree", "great_tree", "pavilion",
	"rockery", "stele", "censer", "flagpole", "water_vat", "strange_stone", "stuck_swords", "boundary_stone", "torch", "bush",
	"column", "pavilion_post", "compound_wall", "deity", "spirit_tablets", "training_post", "bookcase"]
const SCENES: Array[String] = ["temple_mountain", "temple_grounds", "temple_library", "temple1_house", "temple2_house",
	"trainroom_house", "restroom1_house", "restroom2_house", "book_room1_house"]
const VIEWS: Array[String] = ["mountain", "grounds", "library", "temple1_house", "temple2_house", "trainroom_house",
	"restroom1_house", "restroom2_house", "book_room1_house"]
const MAPS: Array[StringName] = [&"temple.mountain", &"temple.grounds", &"temple.library", &"temple.temple1_house",
	&"temple.temple2_house", &"temple.trainroom_house", &"temple.restroom1_house", &"temple.restroom2_house",
	&"temple.book_room1_house"]
## The climb, and the walkways round the courtyard to the path behind the rear hall.
const CLIMB: Array[StringName] = [&"temple.sroad", &"temple.ladder5", &"temple.ladder4", &"temple.ladder3", &"temple.ladder2",
	&"temple.ladder1", &"temple.entrance"]
const WEST: Array[StringName] = [&"temple.corridor2", &"temple.corridor6", &"temple.corridor4", &"temple.corridor5",
	&"temple.corridor3", &"temple.road1", &"temple.road2"]
const EAST: Array[StringName] = [&"temple.corridor1", &"temple.corridor7", &"temple.corridor3"]
## Each interior and the spot a test may put the player on (TEST-ONLY, past doors only 茅山派 may
## pass and the rear hall's shut door).
const ROOMS: Dictionary[StringName, StringName] = {&"temple.temple2": &"temple.temple2.corridor5_entry",
	&"temple.trainroom": &"temple.trainroom.corridor4_entry", &"temple.restroom1": &"temple.restroom1.corridor7_entry",
	&"temple.restroom2": &"temple.restroom2.corridor3_entry", &"temple.book_room1": &"temple.book_room1.road2_entry",
	&"temple.book_room2": &"temple.book_room2.stairs_arrival"}
var assertions: int = 0
var failures: Array[String] = []
var _seen: Dictionary[StringName, bool] = {}


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	for scene: String in SCENES:
		furnishings._check_furnishings(load("res://scenes/world/temple/%s.tscn" % scene) as PackedScene, scene)
	assertions += furnishings.assertions
	failures.append_array(furnishings.failures)
	_check_own_colours()
	_check_snow_seam()
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	var snow := MapPlaces.enter(session, &"snow.eroad3", &"snow.eroad3.temple_return")
	_check(snow != null, "on 雪亭镇's mountain road")
	if snow != null:
		await _frames(tree, 4)
		_check(await MapPlaces.take_passage(tree, snow, &"snow.eroad3.east"), "east from 雪亭镇 onto the 青石官道")
		await _frames(tree, 6)
		var mountain := session.active_map() as WorldMapController
		_check(mountain != null and mountain.map_id() == &"temple.mountain", "on 茅山's climb")
		if mountain != null and mountain.map_id() == &"temple.mountain":
			await _check_map(tree, session, mountain, "the climb")
			_check_mountain(mountain)
			_check_passing(mountain, CLIMB)
			_check(await MapPlaces.drive_through(tree, mountain, CLIMB.slice(1)), "up the white stairs to the 山门")
			_check(await MapPlaces.take_passage(tree, mountain, &"temple.entrance.north"), "through the 山门")
			await _frames(tree, 6)
			var grounds := session.active_map() as WorldMapController
			_check(grounds != null and grounds.map_id() == &"temple.grounds", "inside 灵心观")
			if grounds != null and grounds.map_id() == &"temple.grounds":
				await _check_map(tree, session, grounds, "灵心观")
				_check_grounds(grounds)
				var hall: WorldMapController = await MapPlaces.go_to(tree, session, &"temple.temple1")
				_check(hall != null and hall.projected_view, "on foot through the red door into the great hall, in its voxel view")
				if hall != null:
					await _check_map(tree, session, hall, "the great hall")
					_check_interior(hall)
	var back := MapPlaces.enter(session, &"temple.corridor5", &"temple.corridor5.temple2_return") # TEST-ONLY: round to the walkways
	_check(back != null, "on the walkways")
	if back != null:
		await _frames(tree, 4)
		_check_passing(back, WEST)
		_check_passing(back, EAST)
	for zone: StringName in ROOMS:
		var room := MapPlaces.enter(session, zone, ROOMS[zone]) # TEST-ONLY: each room as it is drawn
		await _frames(tree, 4)
		_check(room != null and room.projected_view, "in %s, in its voxel view" % zone)
		if room == null:
			continue
		await _check_map(tree, session, room, String(zone))
		_check_interior(room)
	var missing: Array[StringName] = []
	for map_id: StringName in MAPS:
		if not _seen.has(map_id):
			missing.append(map_id)
	_check(missing.is_empty(), "every map of 灵心观 was seen in the voxel view: missing %s" % [missing])
	session.free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


## 美术规划 §1: 山绿, 纯白, 朱红 — no 雪亭镇 blossom, no 水烟阁 maples; grey tiles over white walls
## and vermilion timber.
func _check_own_colours() -> void:
	var blossom: Array[String] = []
	var maples: Array[String] = []
	var roofs: Array[String] = []
	for view: String in VIEWS:
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/temple/voxel/%s.json" % view))
		var flora: Dictionary = layout.get("flora", {})
		if not layout.get("indoor", false) and float(flora.get("blossom_trees", 0.35)) > 0.0:
			blossom.append(view)
		for part: Dictionary in [flora] + flora.get("areas", []):
			if "maple" in part.get("tree_types", []) or "blossom" in part.get("tree_types", []):
				maples.append(view)
		for building: Dictionary in layout.get("buildings", []):
			var grey: bool = Color(String(building.get("roof", "000000")).get_slice(":", 0)).s < 0.2
			var hall: bool = building.get("gate", "") == "red"
			if not grey or hall and not String(building.get("timber", "")) in ["a8382a", "9a3226"]:
				roofs.append("%s %s" % [view, building["rect"]])
	_check(blossom.is_empty(), "no blossom trees on 茅山 (雪亭镇 keeps them): %s" % [blossom])
	_check(maples.is_empty(), "no maples or blossom species on 茅山: %s" % [maples])
	_check(roofs.is_empty(), "灵心观's roofs are grey tiles, its halls' timber vermilion: %s" % [roofs])


## 雪亭镇's side of the seam: its mountain road runs on paved past the way to 灵心观, the
## mountain's pines and greens and the 青石 of temple/sroad.c begin there, no blossom.
func _check_snow_seam() -> void:
	var snow: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/snow/voxel/outdoor.json"))
	_check(snow.get("exit_trails", {}).has("snow.eroad3.east"), "雪亭镇's mountain road runs on toward 灵心观 past its way out")
	var dressed: bool = false
	for area: Dictionary in snow.get("flora", {}).get("areas", []):
		var r: Array = area.get("rect", [0, 0, 0, 0])
		if Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]).has_point(Vector2(1488, 240)):
			dressed = float(area.get("blossom_trees", 1.0)) == 0.0 and "tall_pine" in area.get("tree_types", []) \
				and (area.get("ground_styles", {}).get("street", {}).get("stones", [""]) as Array)[0] == "7d8d8f"
			break
	_check(dressed, "雪亭镇's end of the seam has 茅山's pines, greens and 青石, no blossom")


func _check_mountain(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	_check(kinds.count("stair_flight") >= 6, "ladder1-5.c: the flights of white quartz stairs")
	_check(kinds.count("stone_lantern") >= 8, "a stone lantern at every landing and before the gate")
	for kind: String in ["far_peak", "far_ground", "ferns", "mushrooms", "rock_pile"]:
		_check(kind in kinds, "the climb has its %s" % kind)
	var tower: bool = false
	var town: bool = false
	for prop: Dictionary in view.layout.get("props", []):
		tower = tower or prop["kind"] == "far_peak" and int(prop.get("tower", 0)) > 0
		town = town or prop["kind"] == "far_ground" and int(prop.get("roofs", 0)) >= 10 and prop["at"][0] < 0
	_check(tower, "ladder2.c: 在云雾飘渺的山顶上, 矗立著一座雄伟的白色楼阁")
	_check(town, "ladder3/4.c: 雪亭镇就在西边不远的山下")
	var gate: Dictionary = (view.layout.get("buildings", []) as Array)[0]
	_check("temple.entrance.north" in gate.get("portals", []) and gate.get("signboard", {}).get("text", "") == "灵心观" and gate.get("gate", "") == "red",
		"entrance.c: 一座古色古香的山门, 上面以龙飞凤舞的笔迹书写著「灵心观」三字")
	var stairs: Dictionary = view.geometry._ground_style(Vector2(736, 1664), "floor_yard")
	_check(stairs.get("style", "") == "slabs" and Color(String((stairs.get("stones", ["000000"]) as Array)[0])).v > 0.85 and float(stairs.get("cracks", 0.0)) > 0.0,
		"ladder5.c: 纯白色宽敞的石英岩阶梯 — white, worn by the years")
	_check(view.geometry._ground_style(Vector2(200, 1824), "street").get("stones", [""])[0] == "7d8d8f", "sroad.c: 一条宽敞坚实的青石大道")
	var tall: int = 0
	for prop: Dictionary in view.layout.get("flora", {}).get("bands", []):
		tall += 1 if "tall_pine" in prop.get("types", []) else 0
	_check(tall >= 1 and float(view.layout["flora"].get("south_reach", 1.0)) > 4.0,
		"ladder2-5.c: 两侧种植著一排高耸的松树, kept low on the near side so the stairs show")
	_check(view.geometry.ambience._falling.size() >= 20, "pine needles drift down on the stairs")
	_check(view.lighting.lamps.size() >= 6, "lamps for the night on the climb")


func _check_grounds(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	_check(kinds.count("stone_lion") == 2, "square.c: 一对雄伟的石狮子站在庙门的两侧")
	_check(kinds.count("censer") == 1, "square.c: 广场的中央还有一个大香炉")
	_check("well" in kinds and kinds.count("camellia_bed") >= 2 and "tree" in kinds, "inneryard.c: 种植著一些花草树木, 在西北角落里有著一口水井")
	_check("stele" in kinds, "road2.c: 门旁立著一个石碑")
	_check(kinds.count("pavilion_post") >= 12 and kinds.count("pavilion_roof") >= 3, "the walkways (回廊) round the courtyard: vermilion columns under their eaves")
	_check(kinds.count("compound_wall") >= 10 and "gateway" in kinds, "the old wall round 灵心观 and its 山门 from inside")
	var dragons: int = 0
	for node: Node in map.get_node("Furnishings").get_children():
		var look: Dictionary = node.get_meta("look")
		dragons += 1 if look["kind"] == "column" and look.has("dragon") else 0
	_check(dragons == 2, "square.c: 狮子的两侧立著两根雕著龙纹的石柱")
	var arches: bool = false
	var library: bool = false
	var locked: bool = false
	for building: Dictionary in view.layout.get("buildings", []):
		arches = arches or (building.get("arches", []) as Array).size() == 2 and "temple.square.north" in building.get("portals", [])
		var sign: Dictionary = building.get("signboard", {})
		library = library or sign.get("text", "") == "藏经楼" and String(sign.get("board", "")).begins_with("2f6a8a") and building.has("skirt") and building.get("doorway", "") == "shut"
		locked = locked or not building.has("portals") and building.get("doorway", "") == "shut"
	_check(arches and view.geometry.arches_built == 2, "temple1.c: 东西两侧的圆形拱门 (both drawn in the hall's walls); 走过南边的红漆木门就是广场")
	var doors: Dictionary = view.layout.get("door_looks", {})
	_check(doors.get("temple.square.door", {}).get("kind", "") == "red_door" and doors.get("temple.corridor5.door", {}).get("kind", "") == "red_door",
		"square.c, corridor5.c: 红漆木门")
	_check(library, "road2.c: 一栋木造两层高的屋子…门窗都紧紧的关著, 门口上方挂著一方蓝色琉璃匾额, 上书『藏经楼』三个金字")
	_check(locked, "corridor6.c: 西边是一间上了锁的房间")
	var path: Dictionary = view.geometry._ground_style(Vector2(1160, 800), "path")
	_check(float(path.get("moss_chance", 0.0)) >= 0.3, "road1.c: 一条铺著青石板的小径…青苔…甚至还有些蔓延到石板上")
	_check(view.geometry._ground_style(Vector2(800, 2300), "street").get("stones", [""])[0] == "e6e3da", "square.c: 一片用石英岩铺成的广场")
	var ambience: VoxelAmbience = view.geometry.ambience
	_check(ambience._falling.size() >= 20, "road1.c: 偶有松针缓缓飘落; petals in the courtyard")
	_check(ambience._puffs.size() >= 3, "square.c: 香炉里正冒著袅袅的香烟")
	_check(view.lighting.lamps.size() >= 8, "lanterns for the night round the courtyard and at the doors")


## What every hall and room shows inside, after its text.
func _check_interior(map: WorldMapController) -> void:
	var kinds: Array[String] = _kinds(_view_of(map))
	var looks: Array[Dictionary] = []
	for node: Node in map.get_node("Furnishings").get_children():
		looks.append(node.get_meta("look"))
	match map.map_id():
		&"temple.temple1_house":
			var fresh: bool = false
			for look: Dictionary in looks:
				fresh = fresh or look["kind"] == "altar_table" and look.get("fresh", false)
			_check("deity" in kinds and fresh and kinds.count("prayer_cushion") >= 3 and kinds.count("column") >= 4,
				"temple1.c: 真武大帝的金身; 朱红色的大供桌, 上面排满了鲜花素果; 三四个蒲团")
			_check("notices" in kinds, "the taoists' board in their hall")
			_check(kinds.count("moon_gate") == 2, "temple1.c: 东西两侧的圆形拱门, seen from inside too")
		&"temple.temple2_house":
			var portrait: bool = false
			for prop: Dictionary in _view_of(map).layout.get("props", []):
				portrait = portrait or prop["kind"] == "wall_scroll" and prop.get("portrait", false) and prop.has("beard")
			_check(portrait and "sword_stand" in kinds and kinds.count("spirit_tablets") == 2,
				"temple2.c: 张天师的画像; 宝剑; 剑的两旁陪祀著历代掌门人的牌位")
			_check(_view_of(map).layout.get("door_looks", {}).get("temple.corridor5.door", {}).get("kind", "") == "red_door", "temple2.c: 走出南边的红漆木门")
		&"temple.trainroom_house":
			var charts: int = 0
			for prop: Dictionary in _view_of(map).layout.get("props", []):
				charts += 1 if prop["kind"] == "wall_scroll" and prop.get("chart", false) else 0
			_check(charts >= 4 and kinds.count("training_post") >= 4, "trainroom.c: 四周的墙壁上画著一幅幅经脉穴道图; 一个个练功用的木人")
		&"temple.restroom1_house", &"temple.restroom2_house":
			_check("bed" in kinds and "window" in kinds, "%s: 屋子里只是简单地摆放著几件家俱" % map.map_id())
		&"temple.book_room1_house":
			_check(kinds.count("bookcase") >= 4 and "stairs" in kinds, "book_room1.c: 四周的书架上堆了满满的书; 角落里有一座小小的木梯")
			var shut: bool = true
			for prop: Dictionary in _view_of(map).layout.get("props", []):
				shut = shut and (prop["kind"] != "window" or prop.get("shut", false))
			_check(shut, "road2.c: 屋子四周的门窗都紧紧的关著")
		&"temple.library":
			var portrait: bool = false
			for look: Dictionary in looks:
				portrait = portrait or look["kind"] == "wall_scroll" and look.get("portrait", false)
			_check(portrait and "scripture_table" in kinds, "book_room2.c: 张天师的画像; 一张覆著红布的桌子, 桌上整齐地放著茅山的镇教秘籍")
	var rooms: Dictionary = map.get_node("RoomLife").get_meta("rooms", {}) if map.has_node("RoomLife") else {}
	_check(not rooms.is_empty(), "%s says what its rooms are used for (lived-in)" % map.map_id())


## Each stretch of the way between neighbouring rooms, with a body standing anywhere on it, can
## still be walked round, never touching it (a 5-cell square about the body is solid).
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


## What every map must show: its view, every prop kind drawn, a light for the night, an arrow at
## every way out, tall decor standing clear of the walkable ground, every room and NPC still
## reachable, and the save and RNG untouched by the view.
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
	_check_footing(map, view, place)
	await _check_access_and_saves(tree, session, map, view)


func _check_footing(map: WorldMapController, view: WorldVoxelView, place: String) -> void:
	var loose: Array[String] = []
	for prop: Dictionary in view.layout.get("props", []):
		var kind: String = String(prop["kind"])
		if not kind in TALL or float(prop.get("elevation", 0.0)) >= 0.9:
			continue
		var at := Vector2(float(prop["at"][0]), float(prop["at"][1]))
		var size: Array = prop.get("size", [64, 32])
		var box := Vector2(float(size[0]), float(size[1]))
		if absi(roundi(float(prop.get("rotation", 0)))) % 180 == 90:
			box = Vector2(box.y, box.x)
		var area := Rect2(at - box / 2.0, box)
		var solid: bool = true
		for y: int in range(floori(area.position.y / 16.0), ceili(area.end.y / 16.0)):
			for x: int in range(floori(area.position.x / 16.0), ceili(area.end.x / 16.0)):
				var cell := Vector2(x * 16 + 8, y * 16 + 8)
				var rock: bool = prop.get("on_cliff", false) and view.geometry.cliffs != null and view.geometry.cliffs.heights.has(Vector2i(cell))
				if not (rock or TerrainProbe.blocks_at(map, cell)) and solid:
					solid = false
					loose.append("%s %s (open at %s)" % [kind, prop["at"], cell])
	_check(loose.is_empty(), "tall decor in %s stands on blocking ground: %s" % [place, loose])


## On the 2D map the voxel view never changes: every room has a way to it from where the
## player stands, every NPC a spot within interaction reach on that way, and day, night, the view
## side and the animations leave the save (and gameplay RNG) as they were.
func _check_access_and_saves(tree: SceneTree, session: WorldSessionController, map: WorldMapController, view: WorldVoxelView) -> void:
	await _frames(tree, 2)
	var start: Vector2 = map.player_body.global_position
	var cut_off: Array[String] = []
	for zone: ZoneDefinition in GameContent.catalog().zones_for_map(map.map_id()):
		var at: Vector2 = MapPlaces.zone_spot(map, zone.zone_id)
		if not _walkable_to(map, start, at):
			cut_off.append(String(zone.zone_id))
	_check(cut_off.is_empty(), "every room of %s can be walked to: cut off %s" % [map.map_id(), cut_off])
	var blocked_ways: Array[String] = []
	for node: Node in map.find_children("*", "Area2D", true, false):
		var passage := node as WorldPassageArea2D
		if passage != null and not _walkable_to(map, start, MapPlaces.passage_spot(map, passage.portal_id)):
			blocked_ways.append(String(passage.portal_id))
	_check(blocked_ways.is_empty(), "every way out of %s can be walked to past the furniture: %s" % [map.map_id(), blocked_ways])
	var out_of_reach: Array[String] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
		if body == null or not npc.exists_in_map:
			continue
		var reach: float = WorldMapSelection.NEARBY_REACH
		var at: Vector2 = MapPlaces.spot(map, npc.world_location().zone_id, body.global_position, reach)
		if not at.is_finite() or at.distance_to(body.global_position) > reach or not _walkable_to(map, start, at):
			out_of_reach.append(String(npc.spawn_point_id))
	_check(out_of_reach.is_empty(), "every NPC of %s can be walked up to within reach: %s" % [map.map_id(), out_of_reach])
	session.set_process(false)
	var saved: String = GameSaveJsonCodec.encode(Work.capture(session)).text
	for left: bool in [true, false]:
		view.set_view_side(left, true)
		for night: bool in [true, false]:
			view.set_night(night, true)
			view._process(0.1)
	_check(GameSaveJsonCodec.encode(Work.capture(session)).text == saved, "%s: light, view side, smoke and falling needles leave the save and RNG unchanged" % map.map_id())
	session.set_process(true)


## A way to `to` from where the player stands; on the grounds, whose square and walkways the
## great hall's map joins, from where one of its ways in comes out.
func _walkable_to(map: WorldMapController, start: Vector2, to: Vector2) -> bool:
	if not to.is_finite():
		return false
	if not MapRoute.path(map, start, to).is_empty():
		return true
	if map.map_id() != &"temple.grounds":
		return false
	for node: Node in map.find_children("*", "Marker2D", true, false):
		if not MapRoute.path(map, (node as Node2D).global_position, to).is_empty():
			return true
	return false


func _view_of(map: WorldMapController) -> WorldVoxelView:
	return map.get_node("MapView") as WorldVoxelView


## Every prop kind on a map: its voxel config's and the layout's blocked furniture.
func _kinds(view: WorldVoxelView) -> Array[String]:
	var result: Array[String] = []
	for prop: Dictionary in view.layout.get("props", []):
		result.append(String(prop["kind"]))
	var furnishings: Node = view.map.get_node_or_null("Furnishings")
	if furnishings != null:
		for node: Node in furnishings.get_children():
			result.append(String((node.get_meta("look") as Dictionary)["kind"]))
	return result


func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.physics_frame
		await tree.process_frame


func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
