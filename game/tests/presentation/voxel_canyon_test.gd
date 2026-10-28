extends RefCounted

## 天驼关 in the fixed-angle voxel view (d/canyon, six maps): the clifftop where the 青石官道 ends
## at the mound and the chain drops over the edge; the 黄石隘口 below it — the chain wall, the
## yellow-earth path between ochre cliffs, the garrison's tents of cloth behind their iron
## palisade, the smooth west wall, the raised iron gate and its winch, the valley and the far
## camel humps, the 黄石穿林路 through giant grass in fog to the sunlit clearing and the mirror;
## the camp's yards and eight tents (the general's tiger head, dragon pillars, gold chair and
## silver table); the 兵器库 cut in the rock with its 「武」; the 梦幻迷境 with its two sealed ways
## and the 竹林道 in the gale to the great yellow stone; the 洞内石室 and its blue-lit bookcase.
## The 2D maps decide every way through: each is walked end to end past the blocked furniture.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
## Decor tall enough to walk into: in a voxel config it must stand on blocking ground (rock, a
## wall, a blocked box, the map's boundary or the camp's closed yard) or be raised clear of the
## floor (`elevation`).
const TALL: Array[String] = ["standing_rock", "boulder", "banner", "torch", "cairn", "bush", "tree", "iron_palisade", "campfire", "well",
	"wine_jars", "firewood", "crocks", "mirror", "reeds", "cave_mouth", "barricade", "rubble", "stone_door", "whetstone", "tiger_head",
	"rock_pile", "mound", "winch", "tent_pole", "dragon_pillar", "grand_chair", "instruments", "weapon_rack"]
const SCENES: Array[String] = ["canyon_clifftop", "canyon_pass", "canyon_armory", "canyon_bamboo", "canyon_stoneroom", "camp"]
const MAPS: Array[StringName] = [&"canyon.clifftop", &"canyon.pass", &"canyon.camp", &"canyon.armory", &"canyon.bamboo", &"canyon.stoneroom"]
## Maps that are no rooms (the clifftop, the pass, the mirror's wood): no lived-in life expected.
const NO_ROOMS: Array[StringName] = [&"canyon.clifftop", &"canyon.pass", &"canyon.bamboo"]
## Where a test may put the player on each map (TEST-ONLY).
const ENTRIES: Dictionary[StringName, Array] = {
	&"canyon.clifftop": [&"canyon.road", &"canyon.road.snow_arrival"],
	&"canyon.pass": [&"canyon.canyon1", &"canyon.canyon1.chain_arrival"],
	&"canyon.camp": [&"canyon.camp1", &"canyon.camp1.canyon4_entry"],
	&"canyon.armory": [&"canyon.blackmarket", &"canyon.blackmarket.swear_arrival"],
	&"canyon.bamboo": [&"canyon.fantasy1", &"canyon.fantasy1.mirror_arrival"],
	&"canyon.stoneroom": [&"canyon.train", &"canyon.train.gap_arrival"]}
var assertions: int = 0
var failures: Array[String] = []
var _seen: Dictionary[StringName, bool] = {}


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	for scene: String in SCENES:
		furnishings._check_furnishings(load("res://scenes/world/canyon/%s.tscn" % scene) as PackedScene, scene)
	assertions += furnishings.assertions
	failures.append_array(furnishings.failures)
	_check_own_colours()
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	# TEST-ONLY: listed with the 大队长, so 李信 lets the walker into the 将军营帐 (canyon_test pays).
	session.player_runtime().state.marks["军营"] = 1
	for map_id: StringName in MAPS:
		var entry: Array = ENTRIES[map_id]
		var map := MapPlaces.enter(session, entry[0], entry[1]) # TEST-ONLY: each map as it is drawn
		await _frames(tree, 4)
		_check(map != null and map.projected_view, "%s in its voxel view" % map_id)
		if map == null:
			continue
		await _check_map(tree, session, map, String(map_id))
		match map_id:
			&"canyon.clifftop": await _check_clifftop(tree, map)
			&"canyon.pass": await _check_pass(tree, session, map)
			&"canyon.camp": await _check_camp(tree, map)
			&"canyon.armory": await _check_armory(tree, map)
			&"canyon.bamboo": await _check_bamboo(tree, map)
			&"canyon.stoneroom": await _check_stoneroom(tree, map)
	var missing: Array[StringName] = []
	for map_id: StringName in MAPS:
		if not _seen.has(map_id):
			missing.append(map_id)
	_check(missing.is_empty(), "every map of 天驼关 was seen in the voxel view: missing %s" % [missing])
	session.free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


## 美术规划 §1: 沙黄、赭石、铁灰 — the rock yellower and warmer than 野羊山's 土黄灰褐, the grass straw,
## no blossom; the region's own flora file.
func _check_own_colours() -> void:
	var pass_layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/canyon/voxel/pass.json"))
	var goathill: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/goathill/voxel/mountain.json"))
	var ours := Color(String(pass_layout["cliffs"]["strata"][0]))
	var theirs := Color(String(goathill["cliffs"]["strata"][0]))
	_check(ours.r > 0.6 and ours.r > ours.g + 0.1 and ours.g > ours.b + 0.15 and ours.r - theirs.r > 0.2,
		"the pass's rock is yellow stone (沙黄、赭石), not 野羊山's grey-brown: %s vs %s" % [ours.to_html(false), theirs.to_html(false)])
	var flora: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/canyon/voxel/flora.json"))
	var hill_flora: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/goathill/voxel/flora.json"))
	var kinds: int = 0
	for key: String in ["crown_colors", "bark_colors", "grass_colors", "flower_colors"]:
		var value: Variant = flora.get(key)
		kinds += 1 if (value is Array and (value as Array).size() >= 4) or (value is Dictionary and (value as Dictionary).size() >= 4) else 0
	_check(kinds == 4 and flora["grass_colors"] != hill_flora["grass_colors"] and flora["crown_colors"]["scrub"] != hill_flora["crown_colors"]["scrub"],
		"the region's flora: four colours each of crown, bark, grass and flower, its own and not 野羊山's")
	_check(float(pass_layout["flora"].get("blossom_trees", 0.35)) == 0.0 and "bamboo" in flora["crown_colors"], "no blossom on the pass; the 竹林道's bamboo has its colours")
	var light: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/canyon/voxel/light.json"))
	var frames: int = 0
	for key: String in ["sky", "ambient", "sun"]:
		frames += (light["outdoor"][key] as Dictionary).size()
	_check(frames == 15 and Color(String(light["outdoor"]["sky"]["dusk"])).r > 0.7 and Color(String(light["outdoor"]["sky"]["night"])).b > Color(String(light["outdoor"]["sky"]["night"])).r,
		"the region's light: five frames of sky, ambient and sun, dusk ruddy, night cold")


## The clifftop: the 青石官道's last slabs, the gravel path to the mound, the chain over the drop.
func _check_clifftop(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["mound", "iron_chain", "far_peak", "rock_pile", "boulder"]:
		_check(kind in kinds, "the clifftop has its %s" % kind)
	var cliffs: VoxelCliffs = view.geometry.cliffs
	_check(cliffs != null and cliffs.holes().size() > 40, "the cliff's edge drops away to the pass far below (a sunken rim): %d" % (0 if cliffs == null else cliffs.holes().size()))
	_check(view.geometry.terrain_cells.get(Vector2i(488, 56), "") == "street" and view.geometry.terrain_cells.get(Vector2i(264, 136), "") == "path",
		"the 青石官道's slabs give way to the gravel path (road.c)")
	var arrow: Node3D = view.arrows.get(&"canyon.road.northeast")
	_check(arrow != null and (arrow.get_meta("direction") as Vector2).is_equal_approx(Vector2(1, -1).normalized()), "the arrow by the 官道 points north-east")
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"canyon.road.chain")), "walk from the 官道 to the mound and the chain")


## The pass: the chain wall and the tail, the path south ≥ 192 wide past the camp's palisade,
## the smooth wall, the gate and its winch, the valley; west the 黄石穿林路 to the mirror.
func _check_pass(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["iron_chain", "iron_gate", "winch", "iron_palisade", "far_peak", "mirror", "reeds", "light_shaft", "campfire", "tiger_head", "stone_door"]:
		_check(kind in kinds, "the pass has its %s" % kind)
	_check(kinds.count("far_peak") == 2 and kinds.count("iron_palisade") >= 4, "the camel's two humps (canyon7.c) and the palisade round the camp (canyon3.c)")
	var tents: int = 0
	var bars: int = 0
	for building: Dictionary in view.layout.get("buildings", []):
		tents += 1 if building.get("construction", "") == "cloth" and building.get("roof_tiles", "") == "cloth" else 0
		bars += 1 if building.get("construction", "") == "iron_bars" else 0
	_check(tents == 6 and bars == 2, "six tents of cloth and two yards in iron bars, by building data: %d, %d" % [tents, bars])
	var cliffs: VoxelCliffs = view.geometry.cliffs
	_check(cliffs != null and cliffs.heights.size() > 1500 and cliffs.face_count > 2000, "the barren mountains stand as raised rock")
	_check(cliffs != null and cliffs.heights.get(Vector2i(1208, 424), 0.0) >= 6.0, "the chain wall stands 十七、八丈: %s" % [cliffs.heights.get(Vector2i(1208, 424), 0.0) if cliffs != null else null])
	_check(view.geometry.terrain_cells.get(Vector2i(1416, 1096), "") == "rock" and not cliffs.heights.has(Vector2i(1416, 1096)), "the camp's ground between the tents lies flat inside the palisade")
	var walkable_rock: Array[Vector2i] = []
	for cell: Vector2i in cliffs.heights:
		if cliffs.distances.get(cell, INF) == 0.0:
			walkable_rock.append(cell)
	_check(walkable_rock.is_empty(), "no open cell is raised into rock: %s" % [walkable_rock.slice(0, 4)])
	_check(view.geometry.wall_looks.size() >= 1 and view.geometry.wall_looks[0].get("smooth", false), "the west wall of 隘口中道 is smooth (canyon4.c)")
	_check(view.geometry.ambience._birds.size() >= 4 and view.geometry.ambience._puffs.size() >= 3, "hawks and crows overhead, the camp fire smoking")
	for row: Array in [[&"canyon.canyon7.south", Vector2.DOWN], [&"canyon.canyon1.chain", Vector2.ZERO]]:
		if row[1] == Vector2.ZERO:
			continue
		var arrow: Node3D = view.arrows.get(row[0])
		_check(arrow != null and arrow.get_meta("direction") == row[1], "the exit arrow of %s points out of its room" % row[0])
	_check(view.arrows.has(&"canyon.stone_forest3.mirror"), "an arrow at the mirror")
	# The way 160–192 wide at its narrowest (美术规划 §2 路和空间): two bodies abreast where the
	# tail meets the path, through the gate, down the valley and along the 黄石穿林路.
	var narrow: Array[String] = []
	for row: Array in [["the tail's foot", 1136, 1296, 456], ["the tail into 隘口小路", 896, 1088, 712], ["the gate (门洞)", 816, 976, 1728], ["the valley", 800, 992, 1896], ["the valley's end", 800, 992, 2216], ["黄石穿林路", 448, 464, 760]]:
		var open: bool = true
		if String(row[0]) == "黄石穿林路":
			for y: int in range(760, 912, 16):
				open = open and not TerrainProbe.blocks_at(map, Vector2(456, y))
		else:
			for x: int in range(int(row[1]) + 8, int(row[2]), 16):
				open = open and not TerrainProbe.blocks_at(map, Vector2(x, int(row[3])))
		if not open:
			narrow.append(String(row[0]))
	_check(narrow.is_empty(), "the ways are wide enough to pass a body: narrow at %s" % [narrow])
	var walk: Array[StringName] = [&"canyon.canyon2", &"canyon.canyon3", &"canyon.canyon4", &"canyon.canyon5", &"canyon.canyon6", &"canyon.canyon7"]
	_check(await MapPlaces.drive_through(tree, map, walk), "walk the pass from the chain foot through the gate into the valley")
	_check(await MapPlaces.drive_through(tree, map, [&"canyon.canyon6", &"canyon.canyon5", &"canyon.canyon4"]), "and back north to the camp's gate")
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"canyon.canyon4.swear")), "up to the smooth wall")
	_check(await MapPlaces.drive_through(tree, map, [&"canyon.canyon3", &"canyon.canyon2", &"canyon.stone_forest1", &"canyon.stone_forest2", &"canyon.stone_forest3"]), "west along the 黄石穿林路 into the clearing")
	# Short of the passage itself (stepping on it would take the mirror).
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"canyon.stone_forest3", Vector2(16, 760), 48.0)), "up to the mirror")
	var button := session.shared_ui().find_child("ViewSide", true, false) as VoxelViewSideButton
	_check(map.place_player(&"canyon.canyon3", MapPlaces.zone_spot(map, &"canyon.canyon3")), "TEST-ONLY: back on 隘口小路")
	await _frames(tree, 2)
	for left: bool in [true, false]:
		_click(tree, button)
		await tree.create_timer(WorldVoxelView.VIEW_ROTATION_SECONDS + 0.05).timeout
		var start: Vector2 = map.player_body.global_position
		Input.action_press("move_right")
		await _frames(tree, 8)
		MapPlaces.release()
		var moved: Vector2 = map.view_ground.basis_xform(map.player_body.global_position - start)
		_check(view.left_view == left and moved.x > 4 and absf(moved.y) < 2, "D walks screen-right on the pass from the %s side" % ("left" if left else "right"))
		_check(map.place_player(&"canyon.canyon3", start), "back on the path")
		await _frames(tree, 2)


## The camp: the yards in iron bars, the tents of cloth, lived in; the general's things.
func _check_camp(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["campfire", "well", "tent_pole", "grand_chair", "dragon_pillar", "instruments", "tiger_head", "mural", "weapon_rack", "side_table", "iron_palisade", "torch", "banner"]:
		_check(kind in kinds, "the camp has its %s" % kind)
	_check(kinds.count("dragon_pillar") == 2 and kinds.count("grand_chair") == 2 and kinds.count("tent_pole") == 4, "two dragon pillars, the tiger-skin chair and the gold chair, a pole in each small tent")
	var cloth: int = 0
	var bars: int = 0
	for look: Dictionary in view.geometry.wall_looks:
		cloth += 1 if look.get("style", "") == "cloth" else 0
		bars += 1 if look.get("style", "") == "iron_bars" else 0
	_check(cloth >= 6 and bars >= 2, "six tents walled in cloth, two yards in iron bars: %d, %d" % [cloth, bars])
	var life: VoxelLife = view.geometry.life
	var worn: int = 0
	var hung: int = 0
	for zone: StringName in [&"canyon.camp3", &"canyon.camp4", &"canyon.camp5", &"canyon.camp6", &"canyon.camp7", &"canyon.camp8"]:
		worn += 1 if life.worn_cells.get(zone, 0) > 0 else 0
		hung += 1 if life.hung.get(zone, 0) > 0 else 0
	_check(worn == 6 and hung >= 5, "every tent lived in: floors worn (%d), things hung on their cloth (%d)" % [worn, hung])
	var pieces: int = 0
	for look: Dictionary in _looks(map):
		pieces += 1 if look["kind"] in ["wine_jars", "sacks", "bedding", "chest_stack", "crocks", "lumber", "clutter", "firewood", "bones"] else 0
	_check(pieces >= 12, "the painter's lived-in pieces in the yards and tents: %d" % pieces)
	# Two bodies abreast between the tents: each doorway 128 wide.
	var narrow: Array[String] = []
	for row: Array in [["camp1-camp3", -1168, -1040, -304], ["camp1-camp2", -688, -64, 64], ["camp2-camp7", 128, -64, 64], ["camp7-camp8", 816, -64, 64]]:
		var open: bool = true
		if String(row[0]) in ["camp1-camp3"]:
			for x: int in range(int(row[1]) + 8, int(row[2]), 16):
				open = open and not TerrainProbe.blocks_at(map, Vector2(x, int(row[3]) - 8)) and not TerrainProbe.blocks_at(map, Vector2(x, int(row[3]) + 8))
		else:
			for y: int in range(int(row[2]) + 8, int(row[3]), 16):
				open = open and not TerrainProbe.blocks_at(map, Vector2(int(row[1]) - 8, y)) and not TerrainProbe.blocks_at(map, Vector2(int(row[1]) + 8, y))
		if not open:
			narrow.append(String(row[0]))
	_check(narrow.is_empty(), "the ways between the tents are 128 wide: narrow at %s" % [narrow])
	_check(await MapPlaces.drive_through(tree, map, [&"canyon.camp3", &"canyon.camp1", &"canyon.camp4", &"canyon.camp1", &"canyon.camp2", &"canyon.camp5", &"canyon.camp2", &"canyon.camp6", &"canyon.camp2", &"canyon.camp7", &"canyon.camp8"]), "walk every tent from the gate to the general's")
	var general: WorldCharacterBody2D = map.runtime_body_for_spawn_point(&"canyon.camp8.general.1")
	_check(general != null, "严廷殷 is in his tent")
	if general != null:
		var near: Vector2 = MapPlaces.spot(map, &"canyon.camp8", general.global_position + Vector2(0, 60), 64.0)
		_check(await MapPlaces.drive(tree, map, near) and map.player_body.global_position.distance_to(general.global_position) < 96.0, "up to 严廷殷 between the pillars and the silver table")


## The 兵器库: the rock chamber, the racks on three walls, 「武」 on the north one.
func _check_armory(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	_check(kinds.count("weapon_rack") == 3 and "carved_wall" in kinds and "weapon_pegs" in kinds and "stone_door" in kinds, "racks on three walls, weapons hung above them, the 「武」, the door east")
	var carved: bool = false
	for prop: Dictionary in view.layout.get("props", []):
		carved = carved or (prop["kind"] == "carved_wall" and prop.get("text", "") == "武")
	_check(carved, "blackmarket.c: 墙上写了个诺大的「武」字")
	_check(view.geometry.life.hung.get(&"canyon.blackmarket", 0) >= 1 and view.geometry.life.worn_cells.get(&"canyon.blackmarket", 0) > 0, "the armory lived in: things on its walls, the floor worn")
	var seller: WorldCharacterBody2D = map.runtime_body_for_spawn_point(&"canyon.blackmarket.seller.1")
	_check(seller != null, "the 后备兵 is among the weapons")
	if seller != null:
		var near: Vector2 = MapPlaces.spot(map, &"canyon.blackmarket", seller.global_position + Vector2(0, 56), 64.0)
		_check(await MapPlaces.drive(tree, map, near) and map.player_body.global_position.distance_to(seller.global_position) < 96.0, "walk up to him between the racks")
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"canyon.blackmarket", Vector2(280, 160), 48.0)), "and over to the door east")


## The mirror's inside and the 竹林道: the sealed ways, bamboo in the gale, the blue-lit stone.
func _check_bamboo(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	_check(kinds.count("cave_mouth") == 2 and kinds.count("barricade") == 2 and "mirror" in kinds and "boulder" in kinds and "tracks" in kinds, "the two sealed ways (整修中), the mirror's inner face, the great yellow stone, small animals' tracks")
	var trees: int = 0
	for chunk: Vector2i in view.geometry._groves:
		for crown: ArrayMesh in view.geometry._groves[chunk]["crowns"]:
			trees += (view.geometry._groves[chunk]["crowns"][crown] as Array).size()
	_check(trees >= 60, "bamboo stands thick either side of the 竹林道: %d" % trees)
	_check(view.geometry.foliage != null and view.geometry.foliage.gust >= 0.9, "bamboo3.c: 风势愈来愈强 — the wind strong over the grass")
	var blue: int = 0
	for prop: Dictionary in view.layout.get("props", []):
		blue += 1 if prop["kind"] == "glow" and Color(String(prop.get("color", "000000"))).b > 0.9 else 0
	_check(blue >= 3, "bamboo3.c: 洋洋洒洒的蓝光从大黄石的四周漫漫而出: %d" % blue)
	_check(view.geometry.cliffs == null and view.geometry.terrain_cells.get(Vector2i(56, 824), "") == "chasm", "the upper and lower ways are sealed mouths in the floor's dark, not pits")
	_check(await MapPlaces.drive_through(tree, map, [&"canyon.bamboo1", &"canyon.bamboo2", &"canyon.bamboo3"]), "walk from the mirror up the 竹林道 to the stone")
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"canyon.bamboo3.stone")), "and up to the great yellow stone")
	var narrow: Array[String] = []
	for y: int in [280, 400, 520, 640, 720]:
		var open: bool = true
		for x: int in range(120, 264, 16):
			open = open and not TerrainProbe.blocks_at(map, Vector2(x, y))
		if not open:
			narrow.append(str(y))
	_check(narrow.is_empty(), "the 竹林道 is at least 160 wide between the bamboo: narrow at %s" % [narrow])


## The stone room: yellow rock, four holes on the bamboo in the gale, the bookcase's blue light.
func _check_stoneroom(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	_check(kinds.count("tree") >= 8 and kinds.count("light_shaft") == 4 and "bookcase" in kinds and "glow" in kinds, "bamboo outside the four holes, the stone bookcase glowing blue")
	var stone_case: bool = false
	for look: Dictionary in _looks(map):
		stone_case = stone_case or (look["kind"] == "bookcase" and look.get("stone", false))
	_check(stone_case, "train.c: 石制书柜")
	_check(view.geometry.ambience._motes.size() >= 30, "train.c: 飕飕的风不停地向你身上袭卷而来 — dust and leaves on the wind")
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"canyon.train.bookcase")), "walk from the gap to the bookcase")
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"canyon.train", Vector2(160, 224), 48.0)), "and back toward the way out")


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
	for door_id: StringName in map.doors_by_id: # TEST-ONLY: the camp's gate open for the walk
		map.set_door_open(door_id, true)
	await _check_access_and_saves(tree, session, map, view)


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
	_check(GameSaveJsonCodec.encode(Work.capture(session)).text == saved, "%s: light, view side, wind, dust and flames leave the save and RNG unchanged" % map.map_id())
	session.set_process(true)


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
