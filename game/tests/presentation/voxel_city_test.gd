extends RefCounted

## 京师 in the fixed-angle voxel view (d/city): the 青石 驿道 from 玉螺湖村 between its two woods to
## the old red 北门; the city of packed dark roofs inside its grey walls, the streets of worn stone;
## 护国道 past 护国寺's ochre walls, the 钱庄 and the 武器店; down the axis the altar square, the
## 紫禁城's vermilion wall and gold roofs between 神武门 in its chains and 午门 between its lions, the
## 校武场's yellow earth, the 天桥's stalls and lanterns; the 西街 and its 太白酒楼, the 东街 between
## the palace wall and the 尚书府's; the 南街, the 监狱 and 刑场 walled shut, the 南门. Five outer
## gates shut, each its own. Inside: the 钱庄 swept clean, the 武器店's red brick and blades, the new
## 绸缎庄 half empty, the old 鞋店's boots, the empty house, the gilt 太白酒楼 and its 雅座, the 镖局's
## yard, the 尚书府's rooms and garden, the wall top, the cell under the altar. The 2D maps decide
## every way through: each is walked past the furniture.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
## Decor tall enough to walk into: in a voxel config it must stand on blocking ground or be raised
## clear of the floor (`elevation`). Furniture counts: what blocks is the layout's (AGENTS「地图」).
const TALL: Array[String] = ["reeds", "tree", "great_tree", "compound_wall", "city_wall", "fence", "firewood", "haystack", "boulder", "pagoda",
	"temple_bell", "incense_burner", "pavilion", "rockery", "camellia_bed", "flagpole", "lantern_post", "notice_post", "old_gate", "rubble",
	"chair", "stool", "flower_stand", "baskets", "crocks", "water_vat", "well", "table", "bench", "bench_seat", "side_table", "bush", "stall", "cart"]
## How much of a house's floor its furniture covers at least (美术规划 §2: 地面边缘要满).
const COVERED: float = 0.11
const SCENES: Array[String] = ["city_main", "city_upstairs", "city_cellar", "bank_house", "biaoju_house", "boots_house", "cloth_house", "jiulou_house", "weapon_house", "shangshu"]
const MAPS: Array[StringName] = [&"city.main", &"city.upstairs", &"city.wall_top", &"city.cellar", &"city.bank_house", &"city.biaoju_house", &"city.boots_house",
	&"city.cloth_house", &"city.house1_house", &"city.jiulou_house", &"city.weapon_house", &"city.shangshu"]
## Maps that are no rooms of a house: no lived-in life expected (the wall top, the cell: 石室不上生活层).
const NO_ROOMS: Array[StringName] = [&"city.main", &"city.wall_top", &"city.cellar"]
## house1.c: 这是一间什麽也没有的空房间 — the one room left bare.
const BARE: Array[StringName] = [&"city.house1_house", &"city.wall_top", &"city.cellar"]
const ENTRIES: Dictionary[StringName, Array] = {
	&"city.main": [&"city.nroad2", &"city.nroad2.village_arrival"],
	&"city.upstairs": [&"city.jiulou_2", &"city.jiulou_2.stairs_arrival"],
	&"city.wall_top": [&"city.wall", &"city.wall.climb_arrival"],
	&"city.cellar": [&"city.midao1", &"city.midao1.stairs_arrival"],
	&"city.bank_house": [&"city.bank", &"city.bank.street8_entry"],
	&"city.biaoju_house": [&"city.biaoju", &"city.biaoju.street1_entry"],
	&"city.boots_house": [&"city.boots", &"city.boots.street11_entry"],
	&"city.cloth_house": [&"city.cloth", &"city.cloth.street6_entry"],
	&"city.house1_house": [&"city.house1", &"city.house1.street11_entry"],
	&"city.jiulou_house": [&"city.jiulou", &"city.jiulou.street5_entry"],
	&"city.weapon_house": [&"city.weapon", &"city.weapon.street9_entry"],
	&"city.shangshu": [&"city.shangshu.yuan", &"city.shangshu.yuan.gate_entry"]}
var assertions: int = 0
var failures: Array[String] = []
var _seen: Dictionary[StringName, bool] = {}


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	for scene: String in SCENES:
		furnishings._check_furnishings(load("res://scenes/world/city/%s.tscn" % scene) as PackedScene, scene)
	assertions += furnishings.assertions
	failures.append_array(furnishings.failures)
	_check_own_colours()
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
			&"city.main": await _check_main(tree, session, map)
			&"city.bank_house": _check_bank(map)
			&"city.weapon_house": _check_weapon(map)
			&"city.cloth_house": _check_cloth(map)
			&"city.boots_house": _check_boots(map)
			&"city.house1_house": _check_empty(map)
			&"city.jiulou_house", &"city.upstairs": _check_tavern(map)
			&"city.biaoju_house": _check_escort(map)
			&"city.shangshu": await _check_shangshu(tree, map)
			&"city.wall_top": _check_wall_top(map)
			&"city.cellar": _check_cellar(map)
	var missing: Array[StringName] = []
	for map_id: StringName in MAPS:
		if not _seen.has(map_id):
			missing.append(map_id)
	_check(missing.is_empty(), "every map of 京师 was seen in the voxel view: missing %s" % [missing])
	session.free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


## 美术规划 §1: 青石灰、深瓦、朱红、少量金 — the region's own light (its slate under cloud) and its
## own few trees, told apart from 乔阴's and 绮云镇's.
func _check_own_colours() -> void:
	var light: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/city/voxel/light.json"))
	var frames: int = 0
	for key: String in ["sky", "ambient", "sun"]:
		frames += (light["outdoor"][key] as Dictionary).size()
	var overcast := Color(String(light["outdoor"]["overcast"]["sky"]))
	_check(frames == 15 and Color(String(light["outdoor"]["sky"]["dusk"])).r > 0.8 and overcast.b >= overcast.r,
		"the region's light: five frames of sky, ambient and sun, dusk gold, cloud a slate grey and never yellow")
	var flora: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/city/voxel/flora.json"))
	var choyin: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/choyin/voxel/flora.json"))
	var kinds: int = 0
	for key: String in ["crown_colors", "bark_colors", "grass_colors", "flower_colors"]:
		var value: Variant = flora.get(key)
		kinds += 1 if (value is Array and (value as Array).size() >= 4) or (value is Dictionary and (value as Dictionary).size() >= 4) else 0
	_check(kinds == 4 and flora["grass_colors"] != choyin["grass_colors"] and "locust" in flora["crown_colors"] and "slender" in flora["crown_colors"],
		"the region's flora: four colours each of crown, bark, grass and flower, its own 槐 and 柏")


## The city: its walls and gates, the axis, the roofs, the widths the voxel view needs, walked.
func _check_main(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["city_wall", "gate_tower", "compound_wall", "altar_terrace", "stone_lion", "weapon_rack", "stall", "lantern_string", "lantern_post", "pagoda",
			"temple_bell", "incense_burner", "flagpole", "stone_lantern", "training_post", "tethered_horse", "notices", "far_peak", "camellia_bed", "rubble", "reeds"]:
		_check(kind in kinds, "京师 has its %s" % kind)
	# Six gates, each its own (五座城门, each its LPC file, and the 北门) and the palace's two.
	var gates: Array[Dictionary] = []
	for prop: Dictionary in view.layout["props"]:
		if prop["kind"] == "gate_tower":
			gates.append(prop)
	_check(gates.size() == 8, "the 北门, 南门, 东一门, 东二门, 西一门, 西二门 and the palace's 神武门 and 午门: %d" % gates.size())
	var looks: Dictionary = {}
	for gate: Dictionary in gates:
		looks[JSON.stringify([gate.get("height"), gate.get("colors"), gate.get("leaves", ""), gate.get("tower", {}), gate.get("flags", {}), gate.get("plaque", {})])] = true
	_check(looks.size() == gates.size(), "no two gates look alike")
	var north: Dictionary = _gate_at(gates, Vector2(1296, 1056))
	_check(not north.is_empty() and not north.has("leaves") and String(north["plaque"]["text"]) == "京师北门" and Color(String(north["colors"][0])).r > 0.55 and float(north["wear"]) > 0.4,
		"northdoor.c: the 北门 open, old, its gold words 京师北门; street7.c: 大红颜色")
	var south: Dictionary = _gate_at(gates, Vector2(1296, 4328))
	_check(not south.is_empty() and south.has("leaves") and String(south["plaque"]["text"]) == "京师南门" and float(south["height"]) >= float(north["height"]),
		"southdoor.c: 高大的城门正上“京师南门”几个大字, shut")
	var east2: Dictionary = _gate_at(gates, Vector2(2528, 3704))
	_check(not east2.is_empty() and int(east2["flags"]["count"]) >= 3 and east2["notices"].get("fresh", false), "eastdoor2.c: 城门上插着几面旗帜; 一张刚刚粘贴上去的布告")
	var west2: Dictionary = _gate_at(gates, Vector2(64, 3704))
	_check(not west2.is_empty(), "the 西二门 is there")
	for gate: Dictionary in gates:
		if not west2.is_empty() and gate != west2 and Vector2(float(gate["at"][0]), float(gate["at"][1])).y not in [2512.0, 2784.0]:
			_check(float(west2["height"]) < float(gate["height"]), "westdoor2.c: 西二门虽不如京师的其他几个城门高大 (%s)" % [gate["at"]])
	var palace: Dictionary = _gate_at(gates, Vector2(1296, 2512))
	_check(not palace.is_empty() and palace.get("chains", false), "shenwumen.c: 门上缠着大铁链")
	var gold: int = 0
	for building: Dictionary in view.layout["buildings"]:
		gold += 1 if String(building.get("roof", "")).begins_with("d8a830") else 0
	_check(gold >= 1 and not palace.is_empty() and String(palace["tower"]["roof"]).begins_with("d8a830"), "紫禁城's gold roofs over its vermilion wall")
	# Each gate's drawn gateway is the 2D way through: open under the arch, solid in the piers.
	for gate: Dictionary in gates:
		var at := Vector2(float(gate["at"][0]), float(gate["at"][1]))
		var along: Vector2 = Vector2(1, 0).rotated(-deg_to_rad(float(gate.get("rotation", 0))))
		var half: float = float(gate["opening"]) / 2.0
		var length: float = float(gate["size"][0]) / 2.0
		var wrong: Array[String] = []
		for step: int in range(-int(length) + 24, int(length) - 23, 16):
			var spot: Vector2 = at + along * step
			if absf(step) >= half + 24.0 and not TerrainProbe.blocks_at(map, spot):
				wrong.append("pier %d" % step)
			elif absf(step) <= half - 24.0 and not gate.has("leaves") and TerrainProbe.blocks_at(map, spot):
				wrong.append("arch %d" % step)
		_check(wrong.is_empty(), "the gate at %s: its piers are solid and its arch is the way through: off at %s" % [gate["at"], wrong])
	var lions: int = 0
	for look: Dictionary in _looks(map):
		lions += 1 if look["kind"] == "stone_lion" else 0
	_check(lions == 2, "wumen.c: 大门的两侧放着一对石狮")
	_check(String(view.layout["ground"]["street"].get("style", "")) == "slabs", "street12.c: 青石铺道 — old flags in rows")
	# Every lamp has something to shine from; the roofs deep in the blocks light no street.
	var bare: Array[String] = []
	for prop: Dictionary in view.layout["props"]:
		if prop["kind"] == "glow" and float(prop.get("day", 0.0)) == 0.0 and Vector2(float(prop["at"][0]), float(prop["at"][1])).distance_to(Vector2(1296, 3700)) > 1.0:
			bare.append(str(prop["at"]))
	_check(bare.is_empty(), "every lamp is a thing you can see, no light from nowhere: %s" % [bare])
	var lights: int = view.geometry.find_children("*", "OmniLight3D", true, false).size()
	_check(lights > 40 and lights < 300, "lamps at the gates, the shops and the night market, not one per back window: %d" % lights)
	# The roofs: the blocks behind the streets are built over, not bare paving; and what is solid
	# by a street looks it (a house, a wall, a raised stoop), not like more of the street.
	var cells: Dictionary[Vector2i, String] = view.geometry.terrain_cells
	var bare_blocks: int = 0
	var blocks: int = 0
	var bare_edges: Array[String] = []
	var edges: int = 0
	# Each cell probed once (the 2D walls), each prop's box worked out once.
	var solid: Dictionary[Vector2i, bool] = {}
	var layers: Array[TileMapLayer] = []
	for layer: TileMapLayer in TerrainProbe.layers(map):
		if layer.collision_enabled and layer.get_parent() == map.get_node("Terrain"):
			layers.append(layer)
	for y: int in range(1112, 4296, 16):
		for x: int in range(104, 2504, 16):
			var hit: bool = false
			for layer: TileMapLayer in layers:
				var data: TileData = layer.get_cell_tile_data(layer.local_to_map(Vector2(x, y) - layer.position))
				hit = hit or (data != null and data.get_collision_polygons_count(0) > 0)
			solid[Vector2i(x, y)] = hit
	_check(solid[Vector2i(1288, 1688)] == false and solid[Vector2i(600, 1400)] == TerrainProbe.blocks_at(map, Vector2(600, 1400)), "the quick probe reads the walls as TerrainProbe does")
	var boxes: Array[Rect2] = []
	for prop: Dictionary in view.layout["props"]:
		if prop.has("size"):
			var size: Array = prop["size"]
			var box := Vector2(float(size[0]), float(size[1]))
			if absi(roundi(float(prop.get("rotation", 0)))) % 180 == 90:
				box = Vector2(box.y, box.x)
			boxes.append(Rect2(Vector2(float(prop["at"][0]), float(prop["at"][1])) - box / 2.0, box))
	for y: int in range(1144, 4256, 16):
		for x: int in range(136, 2464, 16):
			var at := Vector2(x, y)
			if not solid[Vector2i(x, y)]:
				continue
			var edge: bool = false
			for step: Vector2i in [Vector2i(32, 0), Vector2i(-32, 0), Vector2i(0, 32), Vector2i(0, -32)]:
				edge = edge or not solid.get(Vector2i(x, y) + step, true)
			var under: bool = false
			for box: Rect2 in boxes:
				if box.has_point(at):
					under = true
					break
			var is_bare: bool = not view.geometry.ground.covered(Vector2i(x, y)) and not under
			if edge:
				edges += 1
				if is_bare:
					bare_edges.append(str(at))
			elif x % 64 == 8 and y % 64 == 24:
				blocks += 1
				bare_blocks += 1 if is_bare else 0
	_check(blocks > 400 and float(bare_blocks) / blocks < 0.35, "the blocks are roofs and walls, little bare yard: %d of %d bare" % [bare_blocks, blocks])
	_check(edges > 1000 and float(bare_edges.size()) / edges < 0.12, "solid ground by the streets looks solid: %d of %d edge cells bare, e.g. %s" % [bare_edges.size(), edges, bare_edges.slice(0, 8)])
	# The widths the voxel view needs (美术规划 §2).
	var road: int = _run(cells, Vector2i(1288, 600), Vector2i(16, 0), "street")
	_check(road >= 288 and road <= 336, "the 北驿道 as wide as the village's end of it: %d" % road)
	for row: Array in [["护国道", Vector2(600, 1688)], ["南街", Vector2(600, 3704)], ["西街", Vector2(888, 2648)], ["东街", Vector2(1704, 2648)]]:
		var wide: int = _open_run(map, row[1], Vector2(0, 16) if row[0] in ["护国道", "南街"] else Vector2(16, 0))
		_check(wide >= 320, "%s is at least 320 wide: %d" % [row[0], wide])
	for row: Array in [[&"city.nroad2.north", Vector2.UP]]:
		var arrow: Node3D = view.arrows.get(row[0])
		_check(arrow != null and arrow.get_meta("direction") == row[1], "the exit arrow of %s points out of its map" % row[0])
	var trails: Dictionary = view.layout["exit_trails"]
	_check(trails.has("city.nroad2.north"), "the 驿道 runs on north past the map's edge")
	_check_passing(map, [&"city.nroad2", &"city.nroad1", &"city.northdoor", &"city.street16", &"city.street7"])
	_check_passing(map, [&"city.westdoor1", &"city.street14", &"city.street15", &"city.street7", &"city.street8", &"city.street9", &"city.eastdoor1"])
	_check_passing(map, [&"city.westdoor2", &"city.street13", &"city.street12", &"city.bridge", &"city.street11", &"city.street10", &"city.eastdoor2"])
	_check_passing(map, [&"city.street6", &"city.street5", &"city.street4"])
	_check_passing(map, [&"city.street1", &"city.street2", &"city.street3"])
	_check(await MapPlaces.drive_through(tree, map, [&"city.nroad1", &"city.northdoor", &"city.street16", &"city.street7"]), "walk down the 驿道 through the 北门 to the 十字路口")
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"city.jitan", Vector2(1296, 2120), 40.0)), "round the altar")
	_check(await MapPlaces.drive_through(tree, map, [&"city.street8", &"city.street9"]), "east along 护国道")
	# Short of the passage itself (stepping on it would go in).
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"city.street9", MapPlaces.passage_spot(map, &"city.street9.north") + Vector2(0, 64), 40.0)), "to the 武器店's door")
	_check(map.place_player(&"city.shenwumen", MapPlaces.zone_spot(map, &"city.shenwumen")), "TEST-ONLY: before 神武门")
	await _frames(tree, 2)
	for leg: Array in [[&"city.street1", &"city.street2", &"city.street3"], [&"city.wumen"], [&"city.jiaowu"], [&"city.bridge"], [&"city.street17", &"city.southdoor"]]:
		var zones: Array[StringName] = []
		zones.assign(leg)
		_check(await MapPlaces.drive_through(tree, map, zones), "down the 东街 between the walls, past 午门, over the 校武场 and the 天桥 to the 南门: %s" % [leg])
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"city.southdoor.out")), "up to the 南门's 出城")
	var button := session.shared_ui().find_child("ViewSide", true, false) as VoxelViewSideButton
	_check(map.place_player(&"city.street7", MapPlaces.zone_spot(map, &"city.street7")), "TEST-ONLY: back at the 十字路口")
	await _frames(tree, 2)
	for left: bool in [true, false]:
		_click(tree, button)
		await tree.create_timer(WorldVoxelView.VIEW_ROTATION_SECONDS + 0.05).timeout
		var start: Vector2 = map.player_body.global_position
		Input.action_press("move_right")
		await _frames(tree, 8)
		MapPlaces.release()
		var moved: Vector2 = map.view_ground.basis_xform(map.player_body.global_position - start)
		_check(view.left_view == left and moved.x > 4 and absf(moved.y) < 2, "D walks screen-right on the crossing from the %s side" % ("left" if left else "right"))
		_check(map.place_player(&"city.street7", start), "back at the crossing")
		await _frames(tree, 2)


## bank.c: 里里外外都打扫得乾乾净净, iron chests, the counter and its sign, the master's books.
func _check_bank(map: WorldMapController) -> void:
	var kinds: Array[String] = _kinds(_view_of(map))
	_check("shop_counter" in kinds and kinds.count("strongbox") == 2 and "bookcase" in kinds and "sign" in kinds, "the 钱庄: its counter, chests, books, the sign")
	_check(_life_of(map, &"city.bank").get("tidy", false), "bank.c: 打扫得乾乾净净")


## weapon.c: 红砖铺地, blades on every wall, the spears in their rack, the counter by the north wall.
func _check_weapon(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	var brick := Color(String(view.layout["ground"]["floor_shop"]["stones"][0]))
	_check(brick.r > brick.g + 0.15 and brick.r > brick.b + 0.15, "weapon.c: 红砖铺地")
	_check(kinds.count("weapon_rack") >= 3 and "shop_counter" in kinds and kinds.count("armor_stand") == 2, "racks on the walls, the counter, armour")


func _check_cloth(map: WorldMapController) -> void:
	var kinds: Array[String] = _kinds(_view_of(map))
	_check("cloth_shelf" in kinds and "empty_shelf" in kinds and "cutting_table" in kinds and "cloth_bolts" in kinds, "cloth.c: 刚刚开业, half-stocked, bolts lying about")
	_check(not _life_of(map, &"city.cloth").get("tidy", true), "cloth.c: 凌乱")


func _check_boots(map: WorldMapController) -> void:
	var boots: int = 0
	for look: Dictionary in _looks(map):
		boots += 1 if look["kind"] == "shelf" and look.get("boots", false) else 0
	_check(boots >= 2, "boots.c: 架子上放满了各式的皮靴: %d shelves of boots" % boots)


## house1.c: 这是一间什麽也没有的空房间.
func _check_empty(map: WorldMapController) -> void:
	_check(_looks(map).is_empty(), "house1.c: nothing in the empty room")
	var life: Dictionary = _view_of(map).layout["life"]["city.house1"]
	_check((life.get("hangings", ["x"]) as Array).is_empty() and int(life.get("count", 1)) == 0, "no corner clutter, nothing on the walls: only dust and light")


## jiulou.c: 金壁辉煌 — red and gilt, round tables and fine sets; the 雅座 upstairs as rich.
func _check_tavern(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var wall := Color(String(view.layout["wall_looks"][0]["wall"]))
	_check(wall.r > wall.g * 1.6, "%s: red walls, gilt (金壁辉煌), not 福林楼's" % map.map_id())
	var lamps: int = 0
	for prop: Dictionary in view.layout["props"]:
		lamps += 1 if prop["kind"] == "hanging_lantern" and String(prop.get("paper", "")).begins_with("d8452f") else 0
	_check(lamps >= 4, "red lanterns over the tables: %d" % lamps)


func _check_escort(map: WorldMapController) -> void:
	var kinds: Array[String] = _kinds(_view_of(map))
	_check("flagpole" in kinds and kinds.count("cart") == 2 and kinds.count("weapon_rack") == 2, "the 镖局's yard: its flagpole, two 镖车, racks")


func _check_shangshu(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var tiger: bool = false
	var peonies: int = 0
	for look: Dictionary in _looks(map):
		tiger = tiger or (look["kind"] == "grand_chair" and look.get("hide", "") == "tiger" and Color(String(look.get("fur", "000000"))).v > 0.8)
		peonies += 1 if look["kind"] == "camellia_bed" and look.get("peony", false) else 0
	_check(tiger, "keting.c: 当中的椅子尤其大，并铺以少见的白虎皮")
	_check(peonies >= 3, "huayuan.c: 洛阳的牡丹: %d beds" % peonies)
	_check("wall_sword" in (view.layout["life"]["city.shangshu.kefang"]["hangings"] as Array), "kefang.c: 墙上则挂了把宝剑")
	_check((view.layout["life"]["city.shangshu.xiaowu"]["ambience"] as Array).is_empty(), "xiaowu.c: 什么也看不见 — nothing stirs in the dark")
	var yard: Dictionary = view.layout["ground"]["floor_yard"]
	_check((yard["stones"] as Array).size() <= 3 and float(yard.get("broken", 1.0)) < 0.05, "yuan.c: 规规整整地用清一色的大青石铺就")
	for door_id: StringName in map.doors_by_id: # TEST-ONLY: the doors open for the walk
		map.set_door_open(door_id, true)
	_check(await MapPlaces.drive_through(tree, map, [&"city.shangshu.road3", &"city.shangshu.huayuan", &"city.shangshu.road4", &"city.shangshu.feiwu"]), "through the garden to the 废屋")


func _check_wall_top(map: WorldMapController) -> void:
	var kinds: Array[String] = _kinds(_view_of(map))
	_check(kinds.count("far_ground") == 2, "wall.c: the street below on the north, the busy yards on the south")


func _check_cellar(map: WorldMapController) -> void:
	var kinds: Array[String] = _kinds(_view_of(map))
	_check("straw_patch" in kinds and not map.has_node("RoomLife") or (map.get_node("RoomLife").get_meta("rooms", {}) as Dictionary).is_empty(), "midao1.c: the old bed, straw; a cell, no lived-in layer")


func _life_of(map: WorldMapController, zone: StringName) -> Dictionary:
	var rooms: Dictionary = map.get_node("RoomLife").get_meta("rooms", {}) if map.has_node("RoomLife") else {}
	return rooms.get(String(zone), rooms.get(zone, {}))


func _gate_at(gates: Array[Dictionary], at: Vector2) -> Dictionary:
	for gate: Dictionary in gates:
		if Vector2(float(gate["at"][0]), float(gate["at"][1])).distance_to(at) < 1.0:
			return gate
	return {}


func _near_walkable(map: WorldMapController, at: Vector2) -> bool:
	for offset: Vector2 in [Vector2(36, 0), Vector2(-36, 0), Vector2(0, 36), Vector2(0, -36)]:
		if not TerrainProbe.blocks_at(map, at + offset):
			return true
	return false


func _under_prop(view: WorldVoxelView, at: Vector2) -> bool:
	for prop: Dictionary in view.layout["props"]:
		if not prop.has("size"):
			continue
		var size: Array = prop["size"]
		var box := Vector2(float(size[0]), float(size[1]))
		if absi(roundi(float(prop.get("rotation", 0)))) % 180 == 90:
			box = Vector2(box.y, box.x)
		if Rect2(Vector2(float(prop["at"][0]), float(prop["at"][1])) - box / 2.0, box).has_point(at):
			return true
	return false


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
	_check_footing(map, view, place)
	_check_covered(map, place)
	for door_id: StringName in map.doors_by_id: # TEST-ONLY: the doors open for the walk
		map.set_door_open(door_id, true)
	await _check_access_and_saves(tree, session, map, view)


## A house's floor is furnished to its edges (美术规划 §2), the empty room alone left bare.
func _check_covered(map: WorldMapController, place: String) -> void:
	if map.map_id() in NO_ROOMS or map.map_id() in BARE:
		return
	var floor: float = 0.0
	for zone: ZoneDefinition in GameContent.catalog().zones_for_map(map.map_id()):
		floor += MapPlaces.zone_rect(map, zone.zone_id).grow(-32.0).get_area()
	var taken: float = 0.0
	for node: Node in map.get_node("Furnishings").get_children():
		var box: Vector2 = node.get_meta("footprint")
		taken += box.x * box.y
	_check(taken / floor >= COVERED, "%s: its furniture covers %.0f%% of its floor" % [place, taken / floor * 100.0])


func _check_footing(map: WorldMapController, view: WorldVoxelView, place: String) -> void:
	var loose: Array[String] = []
	for prop: Dictionary in view.layout.get("props", []):
		var kind: String = String(prop["kind"])
		if not kind in TALL or float(prop.get("elevation", 0.0)) >= 0.9 or prop.get("wall_mounted", false):
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
				if not TerrainProbe.blocks_at(map, cell) and solid:
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
	_check(GameSaveJsonCodec.encode(Work.capture(session)).text == saved, "%s: light, view side, wind and smoke leave the save and RNG unchanged" % map.map_id())
	session.set_process(true)


## Pixels across the open (walkable) ground through `from`, along `step` (both ways).
func _open_run(map: WorldMapController, from: Vector2, step: Vector2) -> int:
	var count: int = 0
	for way: int in [1, -1]:
		var at: Vector2 = from if way == 1 else from - step
		while not TerrainProbe.blocks_at(map, at) and count < 100:
			count += 1
			at += step * way
	return count * 16


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
