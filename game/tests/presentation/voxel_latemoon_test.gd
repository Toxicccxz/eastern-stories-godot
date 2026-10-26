extends RefCounted

## 晚月庄 in the fixed-angle voxel view: the cobbled path from 绮云镇 between hedges and woods, the
## arch in the pale green wall under 「晚月庄」, the red door hung with two strings of lanterns;
## the front garden of rare flowers and rocks, the great hall's sandalwood tables of peonies, its
## screen and white cloud pillars, the plum courtyard of red and white blossom, the galleries of
## vermilion columns, the lanes lit by golden lamp stands, the ceremonial gate, the dining halls
## round their great tables, the kitchen, the studies and guest rooms, the rear hall where they
## dance, the secret rooms with the bagua on the floor and the great 『舞』, the changing room and
## the flower pool with its guardian phoenix; upstairs the 佛堂 of 区冥 between 天龙 and 凤凰 and
## its glazed crane screens, the galleries and the terrace over the hills; the 湘园 of pebble
## paths in two hundred figures, osmanthus, willows and the 西府海棠, the rockery tunnel, the
## bridges, 沁芳亭 under purple glaze, the thatched 稻香榭 among the apricots; outside the back
## gate the path through waist-high grass under the cliff and the bamboo grove. The ways are
## wide enough to pass a body standing in them; the 2D maps decide every way through.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
## Decor tall enough to walk into: in a voxel config it must stand on blocking ground (rock, a
## wall, a blocked box) or be raised clear of the floor (`elevation`).
const TALL: Array[String] = ["lantern", "stone_lantern", "standing_rock", "boulder", "banner", "tree", "great_tree", "pavilion",
	"rockery", "stele", "censer", "flagpole", "water_vat", "strange_stone", "stuck_swords", "boundary_stone", "torch", "bush",
	"column", "pavilion_post", "compound_wall", "deity", "spirit_tablets", "training_post", "bookcase", "lamp_stand",
	"lantern_post", "beast_statue", "screen_wall"]
const SCENES: Array[String] = ["latemoon_manor", "latemoon_secret", "latemoon_upper", "latemoon_garden", "latemoon_hills"]
const VIEWS: Array[String] = ["manor", "secret", "upper", "garden", "hills"]
const MAPS: Array[StringName] = [&"latemoon.manor", &"latemoon.secret", &"latemoon.upper", &"latemoon.garden", &"latemoon.hills"]
## Where a test may put the player on each map (TEST-ONLY: past doors and one-way ways).
const ENTRIES: Dictionary[StringName, Array] = {
	&"latemoon.secret": [&"latemoon.miroom2", &"latemoon.miroom2.flower_arrival"],
	&"latemoon.upper": [&"latemoon.upstar.upstar1", &"latemoon.upstar.upstar1.stairs_arrival"],
	&"latemoon.garden": [&"latemoon.park.yard1", &"latemoon.park.yard1.manor_arrival"],
	&"latemoon.hills": [&"latemoon.sroad1", &"latemoon.sroad1.garden_arrival"]}
## The ways a body may stand in: each stretch between neighbouring rooms can be walked round it.
const MANOR_WAYS: Array = [
	[&"latemoon.front_yard", &"latemoon.latemoon1", &"latemoon.latemoonc", &"latemoon.latemoon5"],
	[&"latemoon.latemoonc", &"latemoon.latemoon7", &"latemoon.latebook"],
	[&"latemoon.latemoonc", &"latemoon.latemoon4", &"latemoon.room.twoc", &"latemoon.room.two1", &"latemoon.room.two2"],
	[&"latemoon.room.twoc", &"latemoon.room.eat1", &"latemoon.room.eat2", &"latemoon.room.kitchen"],
	[&"latemoon.room.lcenter", &"latemoon.room.lroad1", &"latemoon.room.eroad2", &"latemoon.room.eroad1", &"latemoon.room.corridor7"],
	[&"latemoon.room.lcenter", &"latemoon.room.lroad3", &"latemoon.room.wroad1", &"latemoon.room.wroad2", &"latemoon.room.corridor7"]]
const GARDEN_WAYS: Array = [
	[&"latemoon.park.yard1", &"latemoon.park.flower2", &"latemoon.park.moonc", &"latemoon.park.bridge1", &"latemoon.park.pavilion1",
		&"latemoon.park.bridge2", &"latemoon.park.paroad1", &"latemoon.park.moondoor"],
	[&"latemoon.park.moonc", &"latemoon.park.moon2", &"latemoon.park.moon5", &"latemoon.park.moon3", &"latemoon.park.paroad2"],
	[&"latemoon.park.moonc", &"latemoon.park.moon1", &"latemoon.park.bridge3"]]
const HILLS_WAYS: Array = [[&"latemoon.sroad1", &"latemoon.sroad2", &"latemoon.sroad3", &"latemoon.sroad4", &"latemoon.sroad5",
	&"latemoon.bamboo3"]]
const UPPER_WAYS: Array = [[&"latemoon.upstar.upstar1", &"latemoon.upstar.upstar4", &"latemoon.upstar.upstarc",
	&"latemoon.upstar.upstar3", &"latemoon.upstar.upstar2"]]
var assertions: int = 0
var failures: Array[String] = []
var _seen: Dictionary[StringName, bool] = {}


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	for scene: String in SCENES:
		furnishings._check_furnishings(load("res://scenes/world/latemoon/%s.tscn" % scene) as PackedScene, scene)
	assertions += furnishings.assertions
	failures.append_array(furnishings.failures)
	_check_own_colours()
	_check_cloud_seam()
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	_check(session.handoff_to(&"cloud.outdoor", &"cloud.wroad0", &"cloud.wroad0", &"cloud.wroad0.latemoon_return").succeeded(), "at 绮云镇's west end")
	var cloud := session.active_map() as WorldMapController
	_check(cloud != null and await MapPlaces.take_passage(tree, cloud, &"cloud.wroad0.west"), "west from 绮云镇 onto the cobbled path")
	await _frames(tree, 6)
	var manor := session.active_map() as WorldMapController
	_check(manor != null and manor.map_id() == &"latemoon.manor", "on 晚月庄's cobbled path")
	if manor != null and manor.map_id() == &"latemoon.manor":
		await _check_map(tree, session, manor, "晚月庄")
		_check_manor(manor)
		for way: Array in MANOR_WAYS:
			_check_passing(manor, way)
		_check(await MapPlaces.drive(tree, manor, MapPlaces.door_spot(manor, &"latemoon.entrance.door", &"latemoon.entrance")) and manor.open_door(&"latemoon.entrance.door"), "the arch opens")
		_check(await MapPlaces.drive_through(tree, manor, [&"latemoon.gate", &"latemoon.front_yard", &"latemoon.latemoon1"]), "on foot past the lanterns and through the front garden into the hall")
	for map_id: StringName in ENTRIES:
		var entry: Array = ENTRIES[map_id]
		var map := MapPlaces.enter(session, entry[0], entry[1]) # TEST-ONLY: each map as it is drawn
		await _frames(tree, 4)
		_check(map != null and map.projected_view, "%s in its voxel view" % map_id)
		if map == null:
			continue
		await _check_map(tree, session, map, String(map_id))
		match map_id:
			&"latemoon.secret": _check_secret(map)
			&"latemoon.upper":
				_check_upper(map)
				for way: Array in UPPER_WAYS:
					_check_passing(map, way)
			&"latemoon.garden":
				_check_garden(map)
				for way: Array in GARDEN_WAYS:
					_check_passing(map, way)
			&"latemoon.hills":
				_check_hills(map)
				for way: Array in HILLS_WAYS:
					_check_passing(map, way)
	var missing: Array[StringName] = []
	for map_id: StringName in MAPS:
		if not _seen.has(map_id):
			missing.append(map_id)
	_check(missing.is_empty(), "every map of 晚月庄 was seen in the voxel view: missing %s" % [missing])
	session.free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


## 美术规划 §1: 米白, 淡青, 墨绿, 朱红 with purple glaze — no maples; the garden's own flowering
## trees (梅, 西府海棠, 桂, 杏), the pale green wall, the 沁芳亭's purple roof.
func _check_own_colours() -> void:
	var maples: Array[String] = []
	for view: String in VIEWS:
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/latemoon/voxel/%s.json" % view))
		var flora: Dictionary = layout.get("flora", {})
		for part: Dictionary in [flora] + flora.get("areas", []):
			if "maple" in part.get("tree_types", []):
				maples.append(view)
	_check(maples.is_empty(), "no maples at 晚月庄 (水烟阁 keeps them): %s" % [maples])
	var manor: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/latemoon/voxel/manor.json"))
	var pale: int = 0
	for prop: Dictionary in manor.get("props", []):
		if prop["kind"] == "compound_wall":
			var wall := Color(String(prop.get("wall", "ffffff")))
			pale += 1 if wall.g > wall.r and wall.v > 0.7 else 0
	_check(pale >= 8, "entrance.c: 一座用淡青色围墙围住的庭院 — the wall round the manor pale green (%d)" % pale)
	var garden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/latemoon/voxel/garden.json"))
	var purple: bool = false
	for prop: Dictionary in garden.get("props", []):
		if prop["kind"] == "pavilion_roof":
			var roof := Color(String(prop.get("roof", "000000")).get_slice(":", 0))
			purple = purple or roof.b > roof.g and roof.r > roof.g and String(prop["roof"]).ends_with(":gloss")
	_check(purple, "pavilion1.c: 钻尖式紫琉璃瓦顶")


## 绮云镇's side of the seam: its west road runs on past the way out in 晚月庄's cobbles, among the
## same woods.
func _check_cloud_seam() -> void:
	var cloud: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cloud/voxel/outdoor.json"))
	_check(cloud.get("exit_trails", {}).has("cloud.wroad0.west"), "绮云镇's west road runs on toward 晚月庄 past its way out")
	var dressed: bool = false
	for area: Dictionary in cloud.get("flora", {}).get("areas", []):
		var r: Array = area.get("rect", [0, 0, 0, 0])
		if Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]).has_point(Vector2(500, 2420)):
			dressed = "locust" in area.get("tree_types", []) and area.get("ground_styles", {}).get("path", {}).get("style", "") == "mosaic"
	_check(dressed, "绮云镇's end of the seam has 晚月庄's cobbles and woods")


func _check_manor(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	var plums: int = 0
	var white: bool = false
	for look: Dictionary in _looks(map):
		if look["kind"] == "tree" and look.get("species", "") == "plum":
			plums += 1
			white = white or look.has("colors")
	_check(plums >= 6 and white, "latemoonc.c: 竟种满了无数梅花 — red and white plums")
	_check(kinds.count("table_row") >= 4 and "folding_screen" in kinds and kinds.count("column") >= 2,
		"latemoon1.c: 东西两面各设著七张紫檀雕案…一面屏风将宽敞的大厅隔成两半; 屏风两旁的白石嵌云柱")
	var tables: int = 0
	for look: Dictionary in _looks(map):
		tables += int(look.get("count", 0)) if look["kind"] == "table_row" else 0
	_check(tables == 14, "七张 on each side: %d" % tables)
	_check(kinds.count("round_table") == 3, "eat1.c: 一张大圆桌; eat2.c: 中央摆了二张大圆桌")
	_check(kinds.count("lamp_stand") >= 12, "lroad1.c etc.: 纯金铸成的长灯架上挂了一排饰丽的宫灯")
	_check(kinds.count("lantern_post") == 2, "gate.c: 门口挂著两串灯笼")
	_check("chair_row" in kinds and "wardrobe" in kinds and "shelf" in kinds, "latemoon2.c: 十二张雕漆椅, 一个木隔架, 一碧纱橱")
	var bagua: bool = false
	var dance: bool = false
	var mural: bool = false
	for prop: Dictionary in view.layout.get("props", []):
		bagua = bagua or prop["kind"] == "bagua" and prop.get("floor", false)
		dance = dance or prop["kind"] == "sign" and prop.get("text", "") == "舞"
	for look: Dictionary in _looks(map):
		mural = mural or look["kind"] == "screen_wall" and look.get("mural", false)
	_check(bagua and dance and "stone_bed" in kinds, "latemoon8.c: 大理石床; 偌大的『舞』字; 地板上隐约看到一幅先天八卦图")
	_check(mural, "latemoon5.c: 一边的尽头则是一幅大石壁画")
	var gate_high: bool = true
	for rect: Array in view.layout.get("low_walls", []):
		gate_high = gate_high and not Rect2(rect[0], rect[1], rect[2] - rect[0], rect[3] - rect[1]).has_point(Vector2(3376, 600))
	_check(gate_high, "the arch's wall stands full height, 「晚月庄」 under its eaves")
	_check(view.geometry._ground_style(Vector2(3600, 600), "path").get("style", "") == "mosaic", "entrance.c: 这是条用鹅卵石铺成的小路")
	_check(view.geometry._ground_style(Vector2(1328, 2144), "riverbank").get("stones", [""])[0] == "4e7a62", "lcenter.c: 连地上踏的砖, 皆是碧绿凿花")
	_check(view.geometry.water.levels.size() > 100, "bathroom.c: the flower pool's water")
	var phoenix: Dictionary = view.layout.get("actors", {}).get("latemoon.npc.room.fireangel", {})
	_check(phoenix.get("body", "") == "statue" and not (phoenix.get("wings", []) as Array).is_empty(), "fireangel.c: 护庄神像, 火神「凤凰」")
	_check(view.geometry.ambience._falling.size() >= 20, "plum petals on the wind (latemoonc.c: 清风徐来)")
	_check(view.lighting.lamps.size() >= 20, "lanterns for the night in the halls and the lanes")


func _check_secret(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	_check("stone_bed" in kinds and "bagua" in kinds and "bookcase" in kinds and "folding_screen" in kinds,
		"miroom2.c: 左一架书, 右一架屏; miroom.c: 大理石床, 先天八卦图")


func _check_upper(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var beasts: Array[String] = []
	var cranes: int = 0
	for look: Dictionary in _looks(map):
		if look["kind"] == "beast_statue":
			beasts.append(String(look.get("beast", "")))
		cranes += 1 if look["kind"] == "screen_wall" and look.get("cranes", false) else 0
	_check("dragon" in beasts and "phoenix" in beasts, "uproom.c: 旁有雨神「天龙」、火神「凤凰」")
	_check(cranes == 2, "uproom.c: 两翼有琉璃鹤照壁")
	_check(view.layout.get("actors", {}).get("latemoon.npc.upstar.statue", {}).get("body", "") == "statue", "uproom.c: 堂内供奉人灵「区冥」 — a statue")
	var kinds: Array[String] = _kinds(view)
	_check(kinds.count("balustrade") >= 7 and kinds.count("lamp_stand") >= 4, "upstar1-4.c: the galleries' railings and golden lamp stands")
	_check(kinds.count("far_peak") >= 2, "uplook.c: 瀚烟山美丽景色尽收眼里, 远处山寺")
	var steps: int = 0
	for prop: Dictionary in view.layout.get("props", []):
		steps += 1 if prop["kind"] == "wall_scroll" and prop.get("steps", false) else 0
	_check(steps >= 3, "uproom2.c: 墙上刻画著各种基本步法")


func _check_garden(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	var species: Dictionary = {}
	for look: Dictionary in _looks(map):
		if look["kind"] == "tree":
			species[look.get("species", "")] = int(species.get(look.get("species", ""), 0)) + 1
	_check(int(species.get("osmanthus", 0)) >= 10, "moon5.c: 园内种植桂花树十万多株")
	_check(species.has("crabapple") and species.has("willow") and species.has("banana") and int(species.get("apricot", 0)) >= 3 and species.has("bamboo"),
		"moonc.c 西府海棠 and willows, moon1.c 芭蕉, paroad2.c 杏花, paroad1.c 翠竹")
	var peacocks: bool = false
	for prop: Dictionary in view.layout.get("props", []):
		peacocks = peacocks or prop["kind"] == "balustrade" and prop.get("peacocks", false) and prop.get("jade", false)
	_check(peacocks, "bridge2.c: 汉白玉雕石栏杆…二十个望柱头上各有一小孔雀")
	_check(kinds.count("pavilion_post") == 4 and "pavilion_roof" in kinds, "pavilion1.c: 沁芳亭 on its posts")
	_check("moon_gate" in kinds and kinds.count("rockery") >= 6, "flower2.c: 走进月洞门, 只见迎面一带翠嶂; moon1.c: 园内假山开凿的通道")
	var path: Dictionary = view.geometry._ground_style(Vector2(560, 1200), "path")
	_check(path.get("style", "") == "mosaic" and path.get("figures", true), "moon2.c: 以不同颜色的细石砌成各种图案")
	var thatch: int = 0
	for building: Dictionary in view.layout.get("buildings", []):
		thatch += 1 if building.get("roof_tiles", "") == "thatch" else 0
	_check(thatch == 2 and "well" in kinds and "stele" in kinds, "paroad2.c: 数楹茅屋; 一土井, 旁有一石牌")
	_check(not view.geometry.low_walls.is_empty() and view.geometry.cuts, "the little rooms among the trees cut low on the near side")
	_check(view.geometry.water.levels.size() > 500, "the pond under the bridges")
	_check(view.geometry.ambience._falling.size() >= 20, "apricot petals, osmanthus flowers drifting")
	_check(view.lighting.lamps.size() >= 4, "lanterns for the night")


func _check_hills(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var flora: Dictionary = view.layout.get("flora", {})
	_check(flora.get("tree_types", []) == ["bamboo"], "bamboo*.c: 这是一座茂密的竹林")
	_check(not (flora.get("meadows", []) as Array).is_empty(), "sroad1.c: 小径的两旁是半个人高的杂草")
	_check(view.geometry.cliffs != null and "cave_mouth" in _kinds(view), "sroad2.c: 一道峭壁; sroad5.c: the tunnel to 山烟寺")


## Each stretch of the way between neighbouring rooms, with a body standing anywhere on it, can
## still be walked round, never touching it (a 5-cell square about the body is solid).
func _check_passing(map: WorldMapController, zones: Array) -> void:
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
	var rooms: Dictionary = map.get_node("RoomLife").get_meta("rooms", {}) if map.has_node("RoomLife") else {}
	_check(map.map_id() == &"latemoon.hills" or not rooms.is_empty(), "%s says what its rooms are used for (lived-in)" % place)
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
	_check(GameSaveJsonCodec.encode(Work.capture(session)).text == saved, "%s: light, view side, petals and smoke leave the save and RNG unchanged" % map.map_id())
	session.set_process(true)


## A way to `to` from where the player stands or from a marker (the manor's doors are shut, so
## the halls behind them are reached from their own markers, as the 2D map lets a body do).
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


## Every prop kind on a map: its voxel config's and the layout's blocked furniture.
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
