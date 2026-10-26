extends RefCounted

## 青石村 in the fixed-angle voxel view: the slab road from 雪亭镇's col with its ruts, the gravel
## street of stone houses under stone-slab roofs, the lane, the square of great blocks round its
## banyan, the quarry's cut face and the stations' huts, stable, hay and carts; north the chained
## door of the haunted cave, the cave, the mountain road over the chasm, the 八卦 over the way into
## the 迷阵 and the mossy stone door; the eight illusions of the 迷阵 and 绝地; the stone rooms;
## every house, the shop and the 土地庙 inside. Everything the rooms' texts name is there, the
## colours are the village's own (no blossom, no maples), every way out has its arrow, and every
## stretch of the village's ways can be walked round a body standing in it. The 2D maps decide
## every way through; the walk comes east from 雪亭镇 and goes up to the cave.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
## Decor tall enough to walk into: in a voxel config it must stand on blocking ground (rock, a
## wall, a blocked box) or be raised clear of the floor (`elevation`).
const TALL: Array[String] = ["lantern", "stone_lantern", "standing_rock", "boulder", "banner", "tree", "great_tree", "pavilion",
	"rockery", "stele", "censer", "flagpole", "water_vat", "strange_stone", "stuck_swords", "boundary_stone", "torch", "bush",
	"derrick", "haystack", "paper_burner", "mossy_rock", "flames", "quarry_face"]
const SCENES: Array[String] = ["green_village", "green_mountain", "green_maze", "shop0_house", "house0_house", "house1_house",
	"house2_house", "house3_house", "house4_house", "temple0_house", "cave", "stone_house"]
const MAPS: Array[StringName] = [&"green.village", &"green.mountain", &"green.maze", &"green.shop0_house", &"green.house0_house",
	&"green.house1_house", &"green.house2_house", &"green.house3_house", &"green.house4_house", &"green.temple0_house",
	&"green.cave", &"green.stone_house"]
## The village's ways: the road in, the street north, the lane to the square, the quarry, the stations.
const ROAD: Array[StringName] = [&"green.path6", &"green.path5", &"green.path4", &"green.path3", &"green.path2", &"green.path1", &"green.path0"]
const EAST: Array[StringName] = [&"green.path3", &"green.path8", &"green.field0", &"green.field1", &"green.station1", &"green.station0", &"green.path5"]
const CLEARINGS: Array[StringName] = [&"green.eight0", &"green.eight1", &"green.eight2", &"green.eight3", &"green.eight4", &"green.eight5",
	&"green.eight6", &"green.eight7", &"green.closed"]
var assertions: int = 0
var failures: Array[String] = []
var _seen: Dictionary[StringName, bool] = {}


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	for scene: String in SCENES:
		furnishings._check_furnishings(load("res://scenes/world/green/%s.tscn" % scene) as PackedScene, scene)
	assertions += furnishings.assertions
	failures.append_array(furnishings.failures)
	_check_no_other_regions_colours()
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	_check_snow_seam()
	var snow := MapPlaces.enter(session, &"snow.crossroad", &"snow.crossroad.green_return")
	_check(snow != null, "on 雪亭镇's col")
	if snow != null:
		await _frames(tree, 4)
		_check(await MapPlaces.take_passage(tree, snow, &"snow.crossroad.east"), "east from the col onto 青石村's slab road")
		await _frames(tree, 6)
		var village := session.active_map() as WorldMapController
		_check(village != null and village.map_id() == &"green.village", "in 青石村")
		if village != null and village.map_id() == &"green.village":
			await _check_village(tree, session, village)
			await _walk(tree, session, village)
	await _check_maze(tree, session)
	var stone := MapPlaces.enter(session, &"green.outdoor", &"green.outdoor.water_arrival") # TEST-ONLY: past the stream's one-way path
	_check(stone != null, "in the stone rooms")
	if stone != null:
		await _frames(tree, 4)
		await _check_map(tree, session, stone, "the stone rooms")
		_check_interior(stone)
	var missing: Array[StringName] = []
	for map_id: StringName in MAPS:
		if not _seen.has(map_id):
			missing.append(map_id)
	_check(missing.is_empty(), "every map of 青石村 was seen in the voxel view: missing %s" % [missing])
	session.free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


## 美术规划 §1: the village's own accents only — no 雪亭镇 blossom, no 水烟阁 maples, no 绮云镇 tiles.
func _check_no_other_regions_colours() -> void:
	var blossom: Array[String] = []
	var maples: Array[String] = []
	var tiles: Array[String] = []
	for scene: String in SCENES:
		var path: String = "res://data/green/voxel/%s.json" % scene.trim_prefix("green_")
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var flora: Dictionary = layout.get("flora", {})
		var parts: Array = [] if layout.get("indoor", false) else [flora]
		parts.append_array(flora.get("areas", []))
		parts.append_array((flora.get("zones", {}) as Dictionary).values())
		for part: Dictionary in parts:
			if float(part.get("blossom_trees", flora.get("blossom_trees", 0.35))) > 0.0 or "blossom" in part.get("tree_types", []):
				blossom.append(scene)
			if "maple" in part.get("tree_types", []) or "maple" in part.get("cliff_tree_types", []):
				maples.append(scene)
		for prop: Dictionary in layout.get("props", []):
			if prop.get("kind", "") == "tree" and String(prop.get("species", "")) in ["blossom", "maple"]:
				maples.append(scene)
		for building: Dictionary in layout.get("buildings", []):
			if String(building.get("roof_tiles", "tiles")) == "tiles":
				tiles.append("%s %s" % [scene, building["rect"]])
	_check(blossom.is_empty(), "no blossom trees in 青石村 (雪亭镇 keeps them): %s" % [blossom])
	_check(maples.is_empty(), "no maples in 青石村 (水烟阁's 官道 keeps them): %s" % [maples])
	_check(tiles.is_empty(), "青石村's roofs are stone slab or thatch, not 绮云镇's fired tiles: %s" % [tiles])


## 雪亭镇's side of the seam: its col's winding path runs on east past the way out, the village's
## moss-greens and grey-green stone begin by it.
func _check_snow_seam() -> void:
	var snow: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/snow/voxel/outdoor.json"))
	_check(snow.get("exit_trails", {}).has("snow.crossroad.east"), "雪亭镇's col runs on east toward 青石村 past its way out")
	var green_ground: bool = false
	for area: Dictionary in snow.get("flora", {}).get("areas", []):
		var r: Array = area.get("rect", [0, 0, 0, 0])
		if Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]).has_point(Vector2(300, -2450)):
			green_ground = (area.get("ground", [""]) as Array)[0] == "56703e" and float(area.get("blossom_trees", 1.0)) == 0.0
			break
	var mossed: bool = false
	for area: Dictionary in snow.get("cliffs", {}).get("areas", []):
		var r: Array = area["rect"]
		if Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]).has_point(Vector2(300, -2600)):
			mossed = area.has("moss")
			break
	_check(green_ground and mossed, "雪亭镇's col turns to 青石村's moss-green ground and mossed grey-green rock at its east end")


func _check_village(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	await _check_map(tree, session, map, "青石村")
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["great_tree", "stone_blocks", "quarry_face", "derrick", "well", "cart", "haystack", "paper_burner", "lantern",
			"far_peak", "stone_seat", "rock_pile"]:
		_check(kind in kinds, "the village has its %s" % kind)
	var banyan: Dictionary = {}
	var pillars: int = 0
	var stone_carts: int = 0
	for node: Node in map.get_node("Furnishings").get_children():
		var look: Dictionary = node.get_meta("look")
		if look["kind"] == "great_tree":
			banyan = look
		pillars += 1 if look["kind"] == "pillar_root" else 0
		if look["kind"] == "cart" and look.get("cargo", "") == "stone":
			stone_carts += 1
	_check(int(banyan.get("aerial_roots", 0)) >= 10 and banyan.get("occludes", false) and pillars >= 4,
		"the great banyan in the square, its roots grown into posts like a pavilion's, each on its own blocked cell (field0.c)")
	_check(stone_carts == 2, "station0.c: 空地上停著几辆载满石料的车")
	var stone_houses: int = 0
	var slate: int = 0
	var sign_worn: bool = false
	for building: Dictionary in view.layout.get("buildings", []):
		stone_houses += 1 if building.get("construction", "") == "rubble" else 0
		slate += 1 if building.get("roof_tiles", "") == "slate" else 0
		var sign: Dictionary = building.get("signboard", {})
		sign_worn = sign_worn or sign.get("worn", false) and float(sign.get("tilt", 0.0)) != 0.0 and String(sign.get("text", "")) == "沈记商行"
	_check(stone_houses >= 4 and slate >= 5, "stone houses (path5.c: 石屋) under stone-slab roofs")
	_check(sign_worn, "path4.c: 一片快要散掉似的木牌悬挂在门口, 上面的字迹已经不是很清楚了")
	var quarry: Dictionary = view.geometry.cliffs._look(Vector2i(2168, 1160))
	_check(float(quarry.get("grooves", 0.0)) > 0.15 and view.geometry.cliffs.heights.get(Vector2i(2200, 1160), 0.0) > 5.0,
		"the quarry's tall face, cut and scored (field1.c: 高耸的石璧经过多年的采挖已经看不出原来的模样)")
	_check(float(view.layout.get("cliffs", {}).get("moss", {}).get("amount", 0.0)) > 0.4, "README: 山壁上覆满青苔")
	var hills: Array[bool] = [false, false, false]
	for cell: Vector2i in view.geometry.cliffs.heights:
		if view.geometry.cliffs.heights[cell] > 2.0:
			hills[0] = hills[0] or cell.y < 640
			hills[1] = hills[1] or cell.x > 2112
			hills[2] = hills[2] or cell.y > 2064
	_check(hills == [true, true, true], "README: 三面环山 — hills north, east and south of the village")
	var ruts: Dictionary = view.geometry._ground_style(Vector2(400, 1720), "path")
	var road: Dictionary = view.geometry._ground_style(Vector2(400, 1640), "street")
	_check(road.get("style", "") == "slabs" and ruts.get("colors", [""])[0] == "5e5546", "path5/6.c: 平整的石板路, 两道很深的车轮")
	_check(view.geometry._ground_style(Vector2(1440, 1300), "town_ground").get("style", "") == "slabs"
		and (view.geometry._ground_style(Vector2(1440, 1300), "town_ground").get("lengths", [0, 0]) as Array)[1] >= 4,
		"field0.c: 地上铺著切割整齐的大石块 — great blocks, old and worn")
	_check(view.geometry._ground_style(Vector2(1900, 1100), "path").get("colors", [""])[0] == "b09a68", "field1.c: 这是一片黄土空地")
	var ambience: VoxelAmbience = view.geometry.ambience
	_check(ambience._falling.size() >= 20, "leaves drift down from the banyan")
	_check(ambience._motes.size() >= 20, "stone dust blows off the quarry")
	_check(ambience._puffs.size() >= 6, "smoke from the chimneys")
	_check(view.lighting.lamps.size() >= 6, "lamps and lit windows for the night")


## The road in and up the street, the lane to the square, the quarry and back by the stations; into
## every house, the shop and the 土地庙; north out of the village to the cave, through it and up the
## mountain road to its end.
func _walk(tree: SceneTree, session: WorldSessionController, village: WorldMapController) -> void:
	_check_passing(village, ROAD)
	_check_passing(village, EAST)
	for zone: StringName in [&"green.path5", &"green.path4", &"green.path3", &"green.path8", &"green.field0", &"green.field1", &"green.station1", &"green.station0"]:
		_check(await MapPlaces.drive_to_zone(tree, village, zone), "walk into " + String(zone))
	for zone: StringName in [&"green.shop0", &"green.house0", &"green.house1", &"green.house2", &"green.house3", &"green.house4", &"green.temple0"]:
		var there: WorldMapController = await MapPlaces.go_to(tree, session, zone)
		_check(there != null and there.projected_view, "on foot into %s, in its voxel view" % zone)
		if there == null:
			return
		if not _seen.has(there.map_id()):
			await _check_map(tree, session, there, String(zone))
			_check_interior(there)
	var foot: WorldMapController = await MapPlaces.go_to(tree, session, &"green.cave0")
	_check(foot != null and foot.projected_view, "north out of the village to the cave's chained door, in the voxel view")
	if foot == null:
		return
	await _check_map(tree, session, foot, "the mountain")
	_check_mountain(foot)
	var cave := MapPlaces.enter(session, &"green.cave1", &"green.cave1.cave0_entry") # TEST-ONLY: past the chained door
	_check(cave != null, "in the cave")
	if cave == null:
		return
	await _frames(tree, 4)
	await _check_map(tree, session, cave, "the cave")
	_check_interior(cave)
	_check(await MapPlaces.drive_to_zone(tree, cave, &"green.cave2"), "north through the low cave")
	_check(await MapPlaces.take_passage(tree, cave, &"green.cave2.north"), "out of the cave's north end")
	await _frames(tree, 4)
	var road := session.active_map() as WorldMapController
	_check(road != null and road.map_id() == &"green.mountain", "through the cave and out onto the mountain road")
	if road == null:
		return
	for zone: StringName in [&"green.mpath1", &"green.mpath2", &"green.entrance"]:
		_check(await MapPlaces.drive_to_zone(tree, road, zone), "up the mountain road into " + String(zone))
	_check_passing(road, [&"green.mpath0", &"green.mpath1", &"green.mpath2", &"green.entrance"])
	var stream := MapPlaces.enter(session, &"green.water", &"green.water.stoneroom_return") # TEST-ONLY: the stream lies behind the stone rooms
	_check(stream != null and stream.map_id() == &"green.mountain", "at the stream behind the stone rooms")


func _check_mountain(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["cave_mouth", "bagua", "reeds", "trail", "glow", "boulder"]:
		_check(kind in kinds, "the mountain has its %s" % kind)
	var doors: Dictionary = view.layout.get("door_looks", {})
	_check(doors.get("green.cave.door", {}).get("kind", "") == "chained_door", "cave0.c: 一道厚厚的木门, 上面用一条手臂粗的铁链拴著")
	_check(doors.get("green.entrance.door", {}).get("kind", "") == "stone_door", "entrance.c: 北面是一扇大石门，门上苔迹斑斑")
	_check(view.geometry.cliffs.holes().size() > 150, "mpath.c: 西面是深不见底的悬崖")
	_check(view.geometry.water.levels.size() > 40, "water.c: 溪水很清澈，缓缓地向南流去")
	_check(view.geometry.ambience._bolts.size() >= 1 and view.geometry.ambience._motes.size() >= 20, "洞内隐隐发出风雷之声; 一股寒气从里面透出来")


## The eight illusions: each under its own sky and on its own ground, its sign naming its 卦; 离's
## fire, 震's lightning, the waters of 坎 and 兑 unlike each other; 绝地's great stone in its fog.
func _check_maze(tree: SceneTree, session: WorldSessionController) -> void:
	var maze := MapPlaces.enter(session, &"green.eight0", &"green.eight0.west_arrival") # TEST-ONLY: past the 100000 combat_exp wind
	_check(maze != null, "in the 迷阵")
	if maze == null:
		return
	await _frames(tree, 4)
	await _check_map(tree, session, maze, "the 迷阵")
	var view: WorldVoxelView = _view_of(maze)
	var skies: Dictionary[String, bool] = {}
	var grounds: Dictionary[String, bool] = {}
	for zone: StringName in CLEARINGS:
		var at: Vector2 = MapPlaces.zone_centre(maze, zone)
		_check(maze.place_player(zone, MapPlaces.spot(maze, zone, at)), "into " + String(zone))
		await _frames(tree, 2)
		view.lighting.advance(0.0, VoxelMapGeometry.point(maze.player_body.global_position))
		skies[view.lighting.environment.background_color.to_html(false)] = true
		var kind: String = view.geometry.terrain_cells.get(Vector2i(floori(at.x / 16.0) * 16 + 8, floori(at.y / 16.0) * 16 + 8), "")
		var style: Dictionary = view.geometry._ground_style(at, kind)
		var tint: String = String(style.get("colors", view.geometry._flora_at(at).get("ground", [kind]))[0]) if kind in ["grass", "rock", "cave_floor", "floor_yard"] else kind
		if kind in ["water", "deep_water"]:
			tint = String(view.layout["water"]["kinds"][kind]["colors"][0])
		grounds[kind + ":" + tint] = true
	_check(skies.size() == CLEARINGS.size(), "every illusion of the 迷阵 has a sky of its own: %d of %d" % [skies.size(), CLEARINGS.size()])
	_check(grounds.size() == CLEARINGS.size(), "every illusion of the 迷阵 has a ground of its own: %s" % [grounds.keys()])
	var signs: Dictionary[String, bool] = {}
	for node: Node in maze.get_node("Furnishings").get_children():
		var look: Dictionary = node.get_meta("look")
		if look["kind"] == "notice_post":
			signs[String(look.get("text", ""))] = true
	_check(signs.size() == 8, "a 路牌 in each of the eight, naming its 卦: %s" % [signs.keys()])
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["flames", "far_peak", "cloud_sea", "boulder", "dead_log", "notice_post"]:
		_check(kind in kinds, "the 迷阵 has its %s" % kind)
	_check(view.geometry.ambience._bolts.size() >= 1, "震: 忽然一道闪电")
	var sparks: bool = false
	for spark: Dictionary in view.geometry.ambience._falling:
		sparks = sparks or spark["up"]
	_check(sparks, "离: sparks rise from the fire")


## What every room shows inside, after its text.
func _check_interior(map: WorldMapController) -> void:
	var kinds: Array[String] = _kinds(_view_of(map))
	var looks: Array[Dictionary] = []
	for node: Node in map.get_node("Furnishings").get_children():
		looks.append(node.get_meta("look"))
	match map.map_id():
		&"green.shop0_house":
			for kind: String in ["shop_counter", "sundry_shelf", "tool_rack", "coffin", "chest_stack"]:
				_check(kind in kinds, "沈记商行 has its %s (shop0.c: 日常生活用品, 工具, 甚至于棺材)" % kind)
		&"green.house0_house":
			var stove: bool = false
			for look: Dictionary in looks:
				stove = stove or look["kind"] == "hearth" and look.get("fire", "") == "low" and look.get("pot", false)
			_check(stove and "bed" in kinds and "chair" in kinds and "tool_rack" in kinds, "house0.c: 石炉上闪著微弱的火光，一锅…冒出阵阵香味; 木床和几张椅子; 各式工具")
		&"green.house1_house":
			_check(kinds.count("stone_slabs") >= 2 and kinds.count("stone_goods") >= 2, "house1.c: 一排排的石板; 石桌、石椅、墓碑")
		&"green.house2_house":
			_check("firewood" in kinds and kinds.count("light_shaft") >= 2, "house2.c: 墙角堆著些柴火; 屋顶…一些破洞")
		&"green.house3_house":
			var bare: bool = true
			for look: Dictionary in looks:
				bare = bare and look["kind"] == "stone_bed"
			_check(bare and "cobweb" in kinds, "house3.c: 屋内除了一张石床外其他一无所有; 屋角有一个形状很奇怪的蜘蛛网")
		&"green.house4_house":
			var blaze: bool = false
			for look: Dictionary in looks:
				blaze = blaze or look["kind"] == "hearth" and look.get("fire", "") == "high"
			_check(blaze and "bookcase" in kinds and "grand_chair" in kinds and kinds.count("wall_scroll") >= 2,
				"house4.c: 熊熊的火光; 木制的书架; 手工精美的石椅; 墙上挂著几幅字画")
		&"green.temple0_house":
			_check("earth_god" in kinds and "altar_table" in kinds and "candles" in kinds, "temple0.c: 供桌…一尊木刻的土地公像")
		&"green.cave":
			_check("overhang" in kinds and "bones" in kinds and "light_shaft" in kinds, "cave1/2.c: 山洞很矮…些莫名其妙的东西…北面隐隐地有些亮光")
		&"green.stone_house":
			var inscription: bool = false
			for prop: Dictionary in _view_of(map).layout.get("props", []):
				inscription = inscription or prop["kind"] == "sign" and String(prop.get("text", "")).contains("非我弟子")
			_check(inscription and kinds.count("stone_seat") == 2 and "wall_sword" in kinds and "buddha" in kinds and kinds.count("prayer_cushion") == 2,
				"石室: 两张石椅, 木剑, 非我弟子莫入此门; 佛像与夜明珠; 两个蒲团")


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
				solid = solid and (rock or TerrainProbe.blocks_at(map, cell))
		if not solid:
			loose.append("%s %s" % [kind, prop["at"]])
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
	_check(GameSaveJsonCodec.encode(Work.capture(session)).text == saved, "%s: light, view side, mist, fire and lightning leave the save and RNG unchanged" % map.map_id())
	session.set_process(true)


## A way to `to` from where the player stands; on a map of parts that passages join (the 迷阵, the
## mountain, the stone rooms), from where one of its ways in comes out.
func _walkable_to(map: WorldMapController, start: Vector2, to: Vector2) -> bool:
	if not to.is_finite():
		return false
	if not MapRoute.path(map, start, to).is_empty():
		return true
	if not map.map_id() in [&"green.maze", &"green.mountain", &"green.stone_house"]:
		return false
	for node: Node in map.find_children("*", "Marker2D", true, false):
		var from: Vector2 = (node as Node2D).global_position
		if not MapRoute.path(map, from, to).is_empty():
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
