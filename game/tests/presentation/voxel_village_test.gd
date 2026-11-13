extends RefCounted

## 玉螺湖村 in the fixed-angle voxel view (d/village, seven maps): the 黄土大道 greening south from
## 天驼关, the 青石小路 worn bright past the farmhouse, 刘家's garden and the melon field behind its
## ditch to the wall of tall grass, south between willows past the lakeside's boats, the rice and
## 田老财's grey walls; 玉螺湖 and the path along its far shore; the boat alone at the lake's
## middle; the ice cave under it, its vault, weed and white dragons; the four houses, the shed open
## on its bamboo poles. The 2D maps decide every way through: each is walked past the furniture.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
const TradeProps := preload("res://presentation/voxel/props/voxel_trade_props.gd")
## How much of a house's floor its furniture covers at least (美术规划 §2: 地面边缘要满): 青石村 and
## 绮云镇's rooms stand at 11–25%, 饮风客栈二楼 at about 15%.
const COVERED: float = 0.11
## The boat has nothing that blocks but the water round it: it has no furnishings.
const SCENES: Array[String] = ["village_main", "village_icecave", "village_seal_chamber", "farmhouse_house", "liu_house", "lord_house", "melonguard_house"]
const MAPS: Array[StringName] = [&"village.main", &"village.midlake", &"village.icecave", &"village.seal_chamber", &"village.farmhouse_house", &"village.liu_house", &"village.lord_house", &"village.melonguard_house"]
## Maps that are no rooms of a house: no lived-in life expected.
const NO_ROOMS: Array[StringName] = [&"village.main", &"village.midlake", &"village.icecave", &"village.seal_chamber"]
## The facade keys that read as age or use (voxel_facade.gd).
const AGE: Array[String] = ["damp", "stains", "patches", "cracks", "foot_weeds", "roof_weeds", "soot", "notices"]
## Where a test may put the player on each map (TEST-ONLY).
const ENTRIES: Dictionary[StringName, Array] = {
	&"village.main": [&"village.road1", &"village.road1.canyon_arrival"],
	&"village.midlake": [&"village.lake", &"village.lake.boat_arrival"],
	&"village.icecave": [&"village.lakebottom1", &"village.lakebottom1.dive_arrival"],
	&"village.seal_chamber": [&"village.seal_altar", &"village.seal_altar.pool_arrival"],
	&"village.farmhouse_house": [&"village.farmhouse1", &"village.farmhouse1.road4_entry"],
	&"village.liu_house": [&"village.home", &"village.home.littlegarden_entry"],
	&"village.lord_house": [&"village.lordhouse1", &"village.lordhouse1.road9_entry"],
	&"village.melonguard_house": [&"village.melonguard", &"village.melonguard.road7_entry"]}
var assertions: int = 0
var failures: Array[String] = []
var _seen: Dictionary[StringName, bool] = {}


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	for scene: String in SCENES:
		furnishings._check_furnishings(load("res://scenes/world/village/%s.tscn" % scene) as PackedScene, scene)
	assertions += furnishings.assertions
	failures.append_array(furnishings.failures)
	_check_own_colours()
	var kept: Dictionary[StringName, Array] = {}
	for id: StringName in [&"village.npc.dragon", &"village.npc.rat"]: # TEST-ONLY: they stay calm while the maps are walked
		var calm: NpcDefinition = GameContent.catalog().npc(id)
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
			&"village.main": await _check_main(tree, session, map)
			&"village.midlake": _check_midlake(map)
			&"village.icecave": await _check_icecave(tree, map)
			&"village.seal_chamber": await _check_seal_chamber(tree, map)
			&"village.farmhouse_house": await _check_farmhouse(tree, map)
			&"village.liu_house": await _check_liu(tree, map)
			&"village.lord_house": await _check_lord(tree, map)
			&"village.melonguard_house": await _check_shed(tree, map)
	var missing: Array[StringName] = []
	for map_id: StringName in MAPS:
		if not _seen.has(map_id):
			missing.append(map_id)
	_check(missing.is_empty(), "every map of 玉螺湖村 was seen in the voxel view: missing %s" % [missing])
	session.free()
	await _frames(tree, 2)
	for id: StringName in kept:
		GameContent.catalog().npc(id).attitude = kept[id][0]
		GameContent.catalog().npc(id)._capability_ids.assign(kept[id][1])
	return {"assertions": assertions, "failures": failures}


## 美术规划 §1: 湖蓝、稻绿、木褐 — the region's own light, its grey blue-green under cloud, and its
## own flora, told apart from 绮云镇's greys and 青石村's moss.
func _check_own_colours() -> void:
	var light: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/village/voxel/light.json"))
	var frames: int = 0
	for key: String in ["sky", "ambient", "sun"]:
		frames += (light["outdoor"][key] as Dictionary).size()
	var overcast := Color(String(light["outdoor"]["overcast"]["sky"]))
	_check(frames == 15 and Color(String(light["outdoor"]["sky"]["dusk"])).r > 0.8 and overcast.b >= overcast.r and overcast.g >= overcast.r,
		"the region's light: five frames of sky, ambient and sun, dusk red-gold, cloud a blue-grey and never yellow")
	var flora: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/village/voxel/flora.json"))
	var cloud: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cloud/voxel/flora.json"))
	var green: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/green/voxel/flora.json"))
	var kinds: int = 0
	for key: String in ["crown_colors", "bark_colors", "grass_colors", "flower_colors"]:
		var value: Variant = flora.get(key)
		kinds += 1 if (value is Array and (value as Array).size() >= 4) or (value is Dictionary and (value as Dictionary).size() >= 4) else 0
	_check(kinds == 4 and flora["grass_colors"] != cloud["grass_colors"] and flora["grass_colors"] != green["grass_colors"] and "willow" in flora["crown_colors"] and "locust" in flora["crown_colors"],
		"the region's flora: four colours each of crown, bark, grass and flower, its own")


## The village's map: the widths the text asks for, the lake, the fields, the ways on walking.
func _check_main(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["notice_post", "skiff", "melon_vines", "scarecrow", "farm_tools", "snail_shells", "fishing_net", "great_tree", "far_peak", "cave_mouth", "thicket", "flower_bed", "compound_wall", "pigsty", "cart"]:
		_check(kind in kinds, "the village has its %s" % kind)
	_check(kinds.count("far_peak") >= 4, "lake.c: 西面远处是朦胧的群山")
	# 第八章 B (DECISIONS「舞台道具」): the burnt things wait for the night after the sword; before it the
	# whole ones stand and the burnt ones are built hidden, nodes of their own.
	var staged: Array[Dictionary] = view.geometry.staged_props
	_check(staged.size() == 11 and staged.filter(func(entry: Dictionary) -> bool: return (entry["node"] as Node3D).visible).size() == 4, "eleven stage props (two boats and two willows, each whole and burnt, the charred roof, the finale's two sheets of black ice): the four whole ones shown, the burnt and the ice hidden: %d shown" % staged.filter(func(entry: Dictionary) -> bool: return (entry["node"] as Node3D).visible).size())
	_check("burnt_roof" in kinds and staged.any(func(entry: Dictionary) -> bool: return entry["look"].get("burnt", false)) and staged.any(func(entry: Dictionary) -> bool: return entry["look"].get("charred", false)), "the farmhouse's charred roof, a burnt skiff and a charred willow among them")
	var bare: Array[String] = []
	for prop: Dictionary in view.layout["props"]:
		if prop["kind"] == "glow" and float(prop.get("day", 0.0)) == 0.0:
			bare.append(str(prop["at"]))
	_check(bare.is_empty(), "every lamp is a thing you can see, no light from nowhere: %s" % [bare])
	_check(kinds.count("firewood") >= 2 and kinds.count("water_vat") >= 1 and kinds.count("crocks") >= 2 and kinds.count("lantern_post") == 2, "things stand by the walls and at the gate")
	var willows: int = 0
	for look: Dictionary in _looks(map):
		willows += 1 if look["kind"] == "tree" and look.get("species", "") == "willow" else 0
	_check(willows >= 12, "road7.c: 小路的两边种了一排垂柳, and road8's, road9's: %d" % willows)
	var cells: Dictionary[Vector2i, String] = view.geometry.terrain_cells
	_check(_run(cells, Vector2i(2152, 600), Vector2i(16, 0), "path") >= 288, "road1.c: the 黄土大道 wide enough for eight carts: %d" % _run(cells, Vector2i(2152, 600), Vector2i(16, 0), "path"))
	for row: Array in [["road4", Vector2i(1336, 1048), Vector2i(0, 16)], ["road6", Vector2i(600, 1048), Vector2i(0, 16)], ["road7", Vector2i(936, 1208), Vector2i(16, 0)]]:
		var wide: int = _run(cells, row[1], row[2], "street")
		_check(wide >= 144 and wide <= 208, "the 青石小路 on %s is 160 wide: %d" % [row[0], wide])
	var valley: int = _run(cells, Vector2i(-88, 1400), Vector2i(16, 0), "path")
	_check(valley >= 144, "the path outside 忘情谷 is 160 wide: %d" % valley)
	_check(_run(cells, Vector2i(2152, 600), Vector2i(16, 0), "path") > _run(cells, Vector2i(1336, 1048), Vector2i(0, 16), "street") * 3 / 2, "the 黄土大道 plainly wider than the village's path")
	# The lake: wide, its shore no ruled line, walked on nowhere.
	var water: int = 0
	for cell: Vector2i in view.geometry.water.levels:
		water += 1 if view.geometry.water.looks[cell]["kind"] == "water" else 0
	_check(water > 1500, "玉螺湖 takes a great part of the map: %d cells" % water)
	_check(TerrainProbe.blocks_at(map, Vector2(384, 1500)) and TerrainProbe.blocks_at(map, Vector2(476, 1136)), "the lake blocks, in its bays too")
	# 稻田, 瓜地, 大沟.
	_check(String(view.geometry._ground_style(Vector2(600, 1880), "grass").get("style", "")) == "paddy", "field.c: the field's ground is rice")
	_check(cells.get(Vector2i(1192, 1304), "") == "shallow_water" and TerrainProbe.blocks_at(map, Vector2(1192, 1304)), "road7.c: 一条大沟, water in it, and no way over")
	var sand := Color(String((view.geometry._ground_style(Vector2(1360, 1320), "grass").get("colors", ["000000"]) as Array)[0]))
	_check(sand.r > sand.g and sand.g > sand.b + 0.1, "melonfarm.c: 沙质的土壤")
	# Fog over the lake (dawn thick, day thin), in `depth`: no height fog here.
	var fog: Dictionary = view.layout["light"]["areas"][0]["fog"]
	_check(not fog.has("height") and float(fog["depth_density"]["dawn"]) > float(fog["depth_density"]["day"]) * 2.0 and float(fog["depth_density"]["day"]) > 0.0, "lake.c: 丝丝雾气 thickest at dawn, thin by day, depth fog")
	_check(view.layout["ground"]["street"].get("style", "") == "slabs", "road4.c: the worn stones are old flags")
	var gold: ShaderMaterial = view.geometry.water.materials[view.geometry.water.sunsets.keys()[0]]
	view.geometry.water.set_dusk(1.0)
	_check(float(gold.get_shader_parameter("sunset_amount")) > 0.3, "the lake goes red-gold at dusk")
	view.geometry.water.set_dusk(0.0)
	var birds: Array[float] = []
	for flock: Dictionary in view.layout["ambience"]["birds"]:
		birds.append(float(flock.get("size", 1.0)))
	_check(birds.min() < 0.6 and birds.max() > 1.5, "road9.c's swallows and valley2.c's great birds")
	for row: Array in [[&"village.road1.north", Vector2.UP], [&"village.road2.south", Vector2.DOWN], [&"village.road1.west", Vector2.LEFT]]:
		var arrow: Node3D = view.arrows.get(row[0])
		_check(arrow != null and arrow.get_meta("direction") == row[1], "the exit arrow of %s points out of its map" % row[0])
	# No exit south of the path yet (valley1.c has none); the land beyond it stays free.
	var south: bool = false
	for node: Node in map.find_children("*", "Area2D", true, false):
		var passage := node as WorldPassageArea2D
		if passage != null and (passage as Node2D).global_position.y > 1696.0 and (passage as Node2D).global_position.x < 0.0:
			south = true
	_check(not south and TerrainProbe.blocks_at(map, Vector2(-96, 1712)), "valley1.c: the path runs on south but brush closes it, no exit")
	_check_facades(view)
	_check_passing(map, [&"village.road2", &"village.road3", &"village.road4", &"village.road5", &"village.road6"])
	_check_passing(map, [&"village.road5", &"village.road7", &"village.road8", &"village.road9"])
	_check(await MapPlaces.drive_through(tree, map, [&"village.road2", &"village.road3", &"village.road4", &"village.melonfarm"]), "walk from the 三叉路口 into the melon field")
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"village.melonfarm.pick")), "up to the melons")
	_check(await MapPlaces.drive_through(tree, map, [&"village.road4", &"village.road5", &"village.road7", &"village.lakeside"]), "and on to the lakeside")
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"village.lakeside.paddle")), "to the boats")
	_check(await MapPlaces.drive_through(tree, map, [&"village.road7", &"village.road8", &"village.road9", &"village.field"]), "south to the rice")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"village.lordhouse1.door", &"village.road9")), "and to 田老财's black gate")
	_check(map.place_player(&"village.valley2", MapPlaces.zone_spot(map, &"village.valley2")), "TEST-ONLY: over the grass, by the path outside 忘情谷")
	await _frames(tree, 2)
	_check(await MapPlaces.drive_through(tree, map, [&"village.valley1"]), "down the path along the far shore")
	# Short of the passage itself (stepping on it would take the way down).
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"village.valley1", Vector2(-110, 1424), 48.0)), "to the rock with the way down in it")
	var button := session.shared_ui().find_child("ViewSide", true, false) as VoxelViewSideButton
	_check(map.place_player(&"village.road4", MapPlaces.zone_spot(map, &"village.road4")), "TEST-ONLY: back on the path")
	await _frames(tree, 2)
	for left: bool in [true, false]:
		_click(tree, button)
		await tree.create_timer(WorldVoxelView.VIEW_ROTATION_SECONDS + 0.05).timeout
		var start: Vector2 = map.player_body.global_position
		Input.action_press("move_right")
		await _frames(tree, 8)
		MapPlaces.release()
		var moved: Vector2 = map.view_ground.basis_xform(map.player_body.global_position - start)
		_check(view.left_view == left and moved.x > 4 and absf(moved.y) < 2, "D walks screen-right on the path from the %s side" % ("left" if left else "right"))
		_check(map.place_player(&"village.road4", start), "back on the path")
		await _frames(tree, 2)


## 玉螺湖村立面 (voxel_facade.gd keys on `buildings`): each house old its own way, after its text.
func _check_facades(view: WorldVoxelView) -> void:
	var layout: Dictionary = view.layout
	var farmhouse: Dictionary = _building(layout, [1184, 608, 1472, 928])
	_check(int(farmhouse.get("steps", {}).get("count", 0)) == 1 and float(farmhouse.get("couplets", {}).get("faded", 0.0)) >= 0.4 and farmhouse.get("windows", {}).get("style", "") == "propped"
		and not farmhouse.has("patches") and not farmhouse.has("cracks") and _hung(farmhouse, "winnow", "south") == 1 and _hung(farmhouse, "hat", "south") == 1,
		"farmhouse1.c: 朴素，但十分井井有条 — one step, couplets gone pale, sashes propped, nothing mended or cracked, a winnow and a hat on the wall")
	var liu: Dictionary = _building(layout, [800, 336, 1088, 608])
	_check(float(liu.get("patches", 0.0)) > 0.3 and float(liu.get("cracks", 0.0)) > 0.0 and float(liu.get("damp", {}).get("height", 0.0)) >= 0.5 and _hung(liu, "broom", "south") == 1 and _hung(liu, "straw_cape", "south") == 1,
		"home.c: 很破旧的木屋 — boards mended, cracked, deep damp, a broom and a straw cape by the door")
	var kitchen: Dictionary = _building(layout, [640, 416, 800, 608])
	_check(float(kitchen.get("soot", {}).get("eaves", 0.0)) >= 0.5 and _hung(kitchen, "kindling", "south") == 1, "smallstorage.c: 四壁已被油烟薰 — the eaves sooted, kindling against the wall")
	var east_room: Dictionary = _building(layout, [1504, 1792, 1744, 2048])
	var south_room: Dictionary = _building(layout, [1184, 2048, 1504, 2288])
	_check(east_room.get("eave_tiles", false) and east_room.get("ridge_tips", false) and south_room.get("eave_tiles", false) and south_room.get("ridge_tips", false)
		and float(south_room.get("windows", {}).get("share", 0.0)) > float(east_room.get("windows", {}).get("share", 0.0)) and east_room.get("windows", {}).get("style", "") == "propped",
		"lordhouse2/3.c: old tiles with their 瓦当 and curled ends, the 东房's window open, the 南房's two great windows all open")
	for id: String in ["village.lordhouse1.door", "village.home.door"]:
		var look: Dictionary = layout.get("door_looks", {}).get(id, {})
		_check(look.get("kind", "") == "old_gate" and look.get("open", false) and view.shutters.has(StringName(id)) and view.opened.has(StringName(id))
			and view.opened[StringName(id)].visible != view.shutters[StringName(id)].visible,
			"%s: an old gate with its shut look and its open one, one of them shown" % id)
	var bare: Array[String] = []
	for building: Dictionary in layout["buildings"]:
		if building.get("construction", "") == "posts":
			continue
		var marks: int = 0
		for key: String in AGE:
			marks += 1 if building.has(key) else 0
		if marks < 2:
			bare.append(String(building.get("note", building["rect"])).left(20))
	_check(bare.is_empty(), "every house but the open 瓜棚 carries two marks of age or more: %s" % [bare])


func _building(layout: Dictionary, rect: Array) -> Dictionary:
	for building: Dictionary in layout["buildings"]:
		var same: bool = true
		for i: int in 4:
			same = same and int(building["rect"][i]) == int(rect[i])
		if same:
			return building
	return {}


## How many things of `kind` hang on `wall` of a building.
func _hung(building: Dictionary, kind: String, wall: String) -> int:
	var count: int = 0
	for item: Dictionary in building.get("wall_hangings", []):
		if String(item.get("kind", "")) == kind and String(item.get("wall", "south")) == wall:
			count += 1
	return count


## The boat alone on the water: no land about it, the far hills and shore, the flash below.
func _check_midlake(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	_check("skiff" in kinds and "far_peak" in kinds and "distant_figures" in kinds and kinds.count("lake_gleam") >= 2, "the boat, the mountains west, the fishermen east, the 白光 under it")
	_check(view.geometry.ambience._blinks.size() >= 2, "lake.c: 忽的见白光一闪: it comes and goes")
	_check(view.geometry.water.levels.size() > 10000, "the lake all round: %d cells" % view.geometry.water.levels.size())
	_check(float(view.layout["water"]["kinds"]["water"].get("swell", 1.0)) < 0.04, "周围静得出奇: the water lies still")


## The ice cave: ice walls and floor, the weed's light, the way in frozen over, the vault and its
## fish, the stair; the hall wider than the way in, six dragons.
func _check_icecave(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["ice_pillar", "thin_ice", "ice_stair", "ice_dome", "glow_algae"]:
		_check(kind in kinds, "the cave has its %s" % kind)
	_check(view.layout["ground"]["cave_floor"]["style"] == "ice" and float(view.layout["cliffs"]["roughness"]) < 0.5, "lakebottom1.c: 全都是冰, floor and walls")
	_check(view.geometry.ambience._fish.size() >= 8, "lakebottom2.c: 顶外的小鱼游来游去")
	_check(view.geometry.find_children("*", "OmniLight3D", true, false).size() >= 4, "lakebottom1.c: 发光的藻类植物 are the cave's light")
	_check(float(view.layout.get("flora", {}).get("cliff_foot_tufts", 1.0)) == 0.0, "no grass on the ice")
	var hall: Rect2 = MapPlaces.zone_rect(map, &"village.lakebottom2")
	_check(hall.size.x >= 640 and hall.size.y >= 480, "lakebottom2.c: 突然变得非常宽阔: %s" % hall.size)
	_check(map.npc_runtimes().filter(func(npc: NpcRuntimeState) -> bool: return npc.exists_in_map).size() == 6, "six white dragons (the finale's 商玦 and his four off the stage)")
	_check(await MapPlaces.drive_to_zone(tree, map, &"village.lakebottom2"), "walk from the frozen way in into the hall")
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"village.lakebottom2", Vector2(176, 288), 48.0)), "across it to the ice stair")


## 冰下封坛 (第八章 A): the same ice as the cave, the black 封坛 with the head and the hilt in the
## middle, 璃虹's lit pillar beside it (the room's one warm lamp), the vault with the dragons'
## shadows, the pool's mouth in the north; 璃虹 a figure that never stirs; the room round, wide
## enough for the 终章's dozen.
func _check_seal_chamber(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["seal_altar", "ice_pillar", "ice_dome", "glow_algae"]:
		_check(kind in kinds, "the chamber has its %s" % kind)
	_check(kinds.count("seal_altar") == 1, "one 封坛, the layout's blocked box")
	_check(view.layout["ground"]["cave_floor"]["style"] == "ice" and view.layout["cliffs"]["strata"][0] == "d8eaf4", "the cave's ice, floor and walls")
	var lit_pillar: bool = view.layout["props"].any(func(prop: Dictionary) -> bool: return prop["kind"] == "ice_pillar" and prop.get("light", false) and String(prop.get("glow", "")).begins_with("fff"))
	_check(lit_pillar, "璃虹's pillar carries the warm light")
	_check(view.geometry.ambience._fish.size() >= 3 and view.geometry.find_children("*", "OmniLight3D", true, false).size() >= 2, "the shadows over the vault, the pillar's light and the weed's")
	_check(view.layout["actors"]["native.npc.lihong"]["body"] == "statue", "璃虹 in the ice never stirs")
	var room: Rect2 = MapPlaces.zone_rect(map, &"village.seal_altar")
	_check(room.size.x >= 560 and room.size.y >= 500, "a round room wide enough for the 终章: %s" % room.size)
	var standing: int = map.npc_runtimes().filter(func(npc: NpcRuntimeState) -> bool: return npc.exists_in_map).size()
	_check(standing == 1, "璃虹 alone (商玦 waits for 看过封坛, the fallen 璃虹 for the sword): %d" % standing)
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"village.seal_altar.keep")), "from the pool's mouth round to the 封坛's south side")
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"village.seal_altar.recite")), "and to 璃虹's pillar")


func _check_farmhouse(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	_check("spinning_wheel" in kinds and kinds.count("bed") == 2 and "pigsty" in kinds and "chicken_coop" in kinds and "laundry_line" in kinds, "farmhouse1.c's wheel and two beds, fmhousback.c's sty and coops")
	var toys: bool = false
	var eggs: int = 0
	for look: Dictionary in _looks(map):
		toys = toys or look.get("set", "") == "toys"
		eggs = maxi(eggs, int(look.get("eggs", 0)))
	_check(toys and eggs == 2, "the clay toys and wooden sword on the table, two red eggs in the trough")
	var pigs: int = 0
	var hens: int = 0
	for critter: Node3D in view.geometry.critters:
		pigs += 1 if critter.get("kind") == "pig" else 0
		hens += 1 if critter.get("kind") == "chicken" else 0
	_check(pigs >= 3 and hens >= 3, "几只小白猪 and the hens: %d, %d" % [pigs, hens])
	var sty := Rect2()
	for node: Node in map.get_node("Furnishings").get_children():
		if (node.get_meta("look") as Dictionary)["kind"] == "pigsty":
			var box: Vector2 = node.get_meta("footprint")
			sty = Rect2((node as Node2D).position - box / 2.0, box)
	var kept: bool = sty.has_area()
	for critter: Node3D in view.geometry.critters:
		if critter.get("kind") == "pig":
			for cell: Vector2 in critter.get("cells"):
				kept = kept and sty.has_point(cell)
	_check(kept, "the pigs walk only in their sty: %s" % sty)
	_check(view.geometry.life.worn_cells.get(&"village.fmhousback", 0) > 0, "the yard lived in")
	_check(await MapPlaces.drive_to_zone(tree, map, &"village.fmhousback"), "walk through the doorway into the back yard")
	var narrow: Array[String] = []
	for x: int in range(-72, 40, 16):
		if TerrainProbe.blocks_at(map, Vector2(x, 72)):
			narrow.append(str(x))
	_check(narrow.is_empty(), "the doorway to the yard is 128 wide: closed at %s" % [narrow])


func _check_liu(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var life: VoxelLife = view.geometry.life
	_check(life.rooms[&"village.smallstorage"]["life"]["wealth"] == "poor" and float(life.rooms[&"village.smallstorage"]["life"]["grime"]) >= 0.9, "smallstorage.c: 四壁已被油烟薰的分不出原来的颜色")
	_check(life.hung.get(&"village.smallstorage", 0) >= 4, "墙上挂满了风干了的卤肉: %d" % life.hung.get(&"village.smallstorage", 0))
	_check((view.layout["life"]["village.smallstorage"]["hangings"] as Array).has("meat_hooks:cured"), "cured meat, not a butcher's fresh")
	_check("hearth" in _kinds(view), "the stove")
	var rats: int = 0
	for npc: NpcRuntimeState in map.npc_runtimes():
		rats += 1 if npc.definition().definition_id == &"village.npc.rat" else 0
	_check(rats == 6, "six big rats")
	_check(await MapPlaces.drive_to_zone(tree, map, &"village.smallstorage"), "walk through to the kitchen")


func _check_lord(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["great_tree", "guan_gong", "iron_stick", "square_table", "bookcase", "writing_desk", "far_ground"]:
		_check(kind in kinds, "田老财家 has its %s" % kind)
	var shelf: int = 0
	for look: Dictionary in _looks(map):
		shelf = maxi(shelf, int(look.get("books", 0)))
	var drawn: int = 0
	for slot: int in 42:
		drawn += 1 if TradeProps.book_at(slot, 42, shelf) else 0
	_check(shelf == 8 and drawn == 8, "lordhouse3.c: eight books, eight drawn: %d" % drawn)
	var views: int = 0
	for prop: Dictionary in view.layout["props"]:
		views += 1 if prop.has("open_view") else 0
	_check(views == 2, "the east and west windows look out on what the text names")
	_check(view.layout["door_looks"]["village.lordhouse1.door"]["kind"] == "old_gate" and Color(String(view.layout["door_looks"]["village.lordhouse1.door"]["leaf"])).v < 0.2, "lordhouse1.c: 一扇漆黑的大门")
	_check(view.geometry.ambience._puffs.size() >= 4, "lordhouse2.c: 三根拇指粗细的香慢慢燃着")
	_check(await MapPlaces.drive_to_zone(tree, map, &"village.lordhouse2") and await MapPlaces.drive_to_zone(tree, map, &"village.lordhouse1") and await MapPlaces.drive_to_zone(tree, map, &"village.lordhouse3"), "walk round the great tree to the east room and the south room")


func _check_shed(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	_check(view.geometry.wall_looks[0].get("style", "") == "posts", "melonguard.c: 竹竿作架, no walls")
	_check("melon_vines" in _kinds(view) and "pole_eaves" in _kinds(view), "the field through the poles, the thatch's eaves")
	var meloners: int = 0
	for npc: NpcRuntimeState in map.npc_runtimes():
		meloners += 1 if npc.definition().definition_id == &"village.npc.meloner" else 0
	_check(meloners == 3, "three 瓜农")
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"village.melonguard", Vector2(120, 60), 48.0)), "walk across the shed")


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
	_check_covered(map, view, place)
	for door_id: StringName in map.doors_by_id: # TEST-ONLY: the gate and the 木门 open for the walk
		map.set_door_open(door_id, true)
	await _check_access_and_saves(tree, session, map, view)


## A house's floor is furnished to its edges, and every light in it has something to shine from.
func _check_covered(map: WorldMapController, view: WorldVoxelView, place: String) -> void:
	if map.map_id() in NO_ROOMS:
		return
	var floor: float = 0.0
	for zone: ZoneDefinition in GameContent.catalog().zones_for_map(map.map_id()):
		var room: Rect2 = MapPlaces.zone_rect(map, zone.zone_id).grow(-32.0)
		floor += room.get_area()
	var taken: float = 0.0
	for node: Node in map.get_node("Furnishings").get_children():
		var box: Vector2 = node.get_meta("footprint")
		taken += box.x * box.y
	_check(taken / floor >= COVERED, "%s: its furniture covers %.0f%% of its floor" % [place, taken / floor * 100.0])


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
	_check(GameSaveJsonCodec.encode(Work.capture(session)).text == saved, "%s: light, view side, wind, dust and flames leave the save and RNG unchanged" % map.map_id())
	session.set_process(true)


## Pixels across a run of `kind` cells through `from`, along `step` (both ways).
func _run(cells: Dictionary[Vector2i, String], from: Vector2i, step: Vector2i, kind: String) -> int:
	var count: int = 0
	for way: int in [1, -1]:
		var at: Vector2i = from if way == 1 else from - step
		while cells.get(at, "") == kind:
			count += 1
			at += step * way
	return count * 16


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


## Every prop kind on a map: its voxel config's and the layout's blocked furniture.
func _kinds(view: WorldVoxelView) -> Array[String]:
	var result: Array[String] = []
	for prop: Dictionary in view.layout.get("props", []):
		result.append(String(prop["kind"]))
	for look: Dictionary in _looks(view.map):
		result.append(String(look["kind"]))
	return result


func _click(tree: SceneTree, button: Button) -> void:
	var click := InputEventMouseButton.new()
	click.position = button.get_global_rect().get_center()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	tree.root.push_input(click, true)
	click.pressed = false
	tree.root.push_input(click, true)


func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.physics_frame
		await tree.process_frame


func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
