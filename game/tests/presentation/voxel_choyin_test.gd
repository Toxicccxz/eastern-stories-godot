extends RefCounted

## 乔阴县城 in the fixed-angle voxel view: the stone arch of the 北门 with its two lions, the
## 福林大街 between 老姚布庄 and the three-storey tavern to the ring round the 树王坟 (the great
## stump and its hole, the little brick shrine, the stele, steps on four sides), the standing
## lion before the shut 西门, the 东门's iron lion, the market, 福林楼 three storeys high, the
## square's great well and vendors, 翠柳湖 with its willows, lilies and red carp under the zigzag
## bridge to the 曼雩台's posted pillars, the 承安街's shops, the 县府衙门's lions and drum, the
## rebuilt 南门, the 火龙将军庙's terrace over the road, the lake road, the peach woods; the
## yamen's courts, the general's terrace, the tavern's floors, the stump's hollow, the beast's
## cave, the marsh and 桐柏山, the furnace, 姑射山, the crown, the cliff cave, the 云台, the 寒谷,
## the tavern's hall and the hermit's 草堂. The ways are wide enough to pass a body standing in
## them; the 2D maps decide every way through.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
const CALMED: Array[StringName] = [&"choyin.npc.shadow", &"choyin.npc.lion", &"choyin.npc.serpent", &"choyin.npc.ghost"]
## Decor tall enough to walk into: in a voxel config it must stand on blocking ground (rock, a
## wall, water, the town's boundary, a blocked box) or be raised clear of the floor (`elevation`).
const TALL: Array[String] = ["lantern", "stone_lantern", "standing_rock", "boulder", "banner", "tree", "great_tree", "pavilion",
	"rockery", "stele", "censer", "flagpole", "water_vat", "strange_stone", "boundary_stone", "torch", "bush", "column",
	"pavilion_post", "compound_wall", "deity", "training_post", "bookcase", "lamp_stand", "lantern_post", "beast_statue",
	"screen_wall", "flower_stand", "pagoda", "temple_bell", "buddha", "stone_lion", "weapon_rack", "drying_rack", "fishing_net",
	"incense_burner", "herb_bed", "cart", "firewood", "haystack", "well", "drum", "great_stump", "brick_shrine", "city_wall",
	"jade_dais", "vase_hollow", "pill_furnace", "stall", "bench", "stair_run", "pillar_root", "cave_mouth", "flames"]
const SCENES: Array[String] = ["choyin_town", "choyin_yamen", "choyin_altar", "choyin_hotel_2f", "choyin_hotel_3f", "choyin_tree_hollow",
	"choyin_lion_cave", "choyin_east", "choyin_furnace", "choyin_guye", "choyin_crown", "choyin_cliff_cave", "choyin_summit", "choyin_valley",
	"hotel_house", "club_house"]
const MAPS: Array[StringName] = [&"choyin.town", &"choyin.yamen_compound", &"choyin.temple_altar", &"choyin.hotel_2f", &"choyin.hotel_3f",
	&"choyin.tree_hollow", &"choyin.lion_cave", &"choyin.east", &"choyin.furnace", &"choyin.guye", &"choyin.crown", &"choyin.cliff_cave",
	&"choyin.summit", &"choyin.valley", &"choyin.hotel_house", &"choyin.club_house"]
## Maps that are no rooms (caves, hills, the crown, the valley): no lived-in life expected.
const NO_ROOMS: Array[StringName] = [&"choyin.town", &"choyin.tree_hollow", &"choyin.lion_cave", &"choyin.east", &"choyin.furnace",
	&"choyin.guye", &"choyin.crown", &"choyin.cliff_cave", &"choyin.summit", &"choyin.valley"]
## Where a test may put the player on each map (TEST-ONLY).
const ENTRIES: Dictionary[StringName, Array] = {
	&"choyin.yamen_compound": [&"choyin.yamen", &"choyin.yamen.hall_entry"],
	&"choyin.temple_altar": [&"choyin.altar", &"choyin.altar.stairs_arrival"],
	&"choyin.hotel_2f": [&"choyin.hotel2", &"choyin.hotel2.stairs_arrival"],
	&"choyin.hotel_3f": [&"choyin.hotel3", &"choyin.hotel3.stairs_arrival"],
	&"choyin.tree_hollow": [&"choyin.tomb1", &"choyin.tomb1.hole_arrival"],
	&"choyin.lion_cave": [&"choyin.lionroom", &"choyin.lionroom.fall_arrival"],
	&"choyin.east": [&"choyin.solidpath1", &"choyin.solidpath1.gate_arrival"],
	&"choyin.furnace": [&"choyin.stove", &"choyin.stove.platform_arrival"],
	&"choyin.guye": [&"choyin.spath", &"choyin.spath.gate_arrival"],
	&"choyin.crown": [&"choyin.craneroom", &"choyin.craneroom.climb_arrival"],
	&"choyin.cliff_cave": [&"choyin.halfhole", &"choyin.halfhole.vine_arrival"],
	&"choyin.summit": [&"choyin.platform", &"choyin.platform.crane_arrival"],
	&"choyin.valley": [&"choyin.hollow", &"choyin.hollow.fall_arrival"],
	&"choyin.hotel_house": [&"choyin.hotel1", &"choyin.hotel1.stairs_return"],
	&"choyin.club_house": [&"choyin.club", &"choyin.club.fence_entry"]}
## The ways a body may stand in: each stretch between neighbouring rooms can be walked round it.
const TOWN_WAYS: Array = [
	[&"choyin.n_gate", &"choyin.n_street1", &"choyin.n_street2", &"choyin.n_street3", &"choyin.tree_tomb", &"choyin.s_street3",
		&"choyin.s_street2", &"choyin.s_street1"],
	[&"choyin.tree_tomb", &"choyin.w_street3", &"choyin.w_street2", &"choyin.w_street1"],
	[&"choyin.n_street3", &"choyin.nw_street", &"choyin.w_street4"],
	[&"choyin.tree_tomb", &"choyin.e_street1", &"choyin.e_gate"],
	[&"choyin.s_street1", &"choyin.s_street4", &"choyin.s_street5", &"choyin.crossroad", &"choyin.court1"],
	[&"choyin.crossroad", &"choyin.s_gate", &"choyin.dragon_temple", &"choyin.sw_road1"],
	[&"choyin.s_street1", &"choyin.bridge1", &"choyin.bridge2", &"choyin.bridge3", &"choyin.bridge4", &"choyin.bridge5", &"choyin.entrance"]]
const EAST_WAYS: Array = [
	[&"choyin.solidpath1", &"choyin.solidpath2", &"choyin.cloudpool"],
	[&"choyin.solidpath1", &"choyin.rockpath2", &"choyin.rockpath1", &"choyin.rockyu", &"choyin.tongbhill"],
	[&"choyin.rockyu", &"choyin.fence"]]
const GUYE_WAYS: Array = [[&"choyin.spath", &"choyin.rockroad", &"choyin.guyehill"]]
const VALLEY_WAYS: Array = [[&"choyin.hollow", &"choyin.hollow1", &"choyin.hollow2", &"choyin.hollow3"]]
var assertions: int = 0
var failures: Array[String] = []
var _seen: Dictionary[StringName, bool] = {}


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	for scene: String in SCENES:
		furnishings._check_furnishings(load("res://scenes/world/choyin/%s.tscn" % scene) as PackedScene, scene)
	assertions += furnishings.assertions
	failures.append_array(furnishings.failures)
	_check_own_colours()
	# TEST-ONLY: the 鬼影, the 护草神兽, the 巨蟒 and the 孤魂野鬼 leave the walker alone (choyin_test meets them).
	var kept: Dictionary = {}
	for id: StringName in CALMED:
		var npc: NpcDefinition = GameContent.catalog().npc(id)
		if npc == null:
			continue
		kept[id] = [npc.attitude, npc._capability_ids.duplicate()]
		npc.attitude = NpcDefinition.Attitude.PEACEFUL
		npc._capability_ids.clear()
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	_check(session.handoff_to(&"choyin.town", &"choyin.n_gate", &"choyin.n_gate", &"choyin.n_gate.road_arrival").succeeded(), "in at the 北门")
	await _frames(tree, 6)
	var town := session.active_map() as WorldMapController
	_check(town != null and town.map_id() == &"choyin.town", "inside 乔阴县城")
	if town != null and town.map_id() == &"choyin.town":
		await _check_map(tree, session, town, "乔阴县城")
		_check_town(town)
		for way: Array in TOWN_WAYS:
			_check_passing(town, way)
		_check(await MapPlaces.drive_through(tree, town, [&"choyin.n_street1", &"choyin.n_street2", &"choyin.n_street3", &"choyin.tree_tomb",
			&"choyin.s_street3", &"choyin.s_street2", &"choyin.s_street1", &"choyin.bridge1", &"choyin.bridge2", &"choyin.bridge3",
			&"choyin.bridge4", &"choyin.bridge5", &"choyin.entrance"]), "on foot down the 福林大街, over the square and the zigzag bridge to the 曼雩台")
		_check(town.place_player(&"choyin.s_street1", MapPlaces.zone_spot(town, &"choyin.s_street1")), "TEST-ONLY: back on the square")
		_check(await MapPlaces.drive_through(tree, town, [&"choyin.s_street4", &"choyin.s_street5", &"choyin.crossroad", &"choyin.s_gate",
			&"choyin.dragon_temple", &"choyin.sw_road1"]), "along the 承安街 to the 南门 and under the 火龙将军庙 to the lake road")
	for map_id: StringName in ENTRIES:
		var entry: Array = ENTRIES[map_id]
		var map := MapPlaces.enter(session, entry[0], entry[1]) # TEST-ONLY: each map as it is drawn
		await _frames(tree, 4)
		_check(map != null and map.projected_view, "%s in its voxel view" % map_id)
		if map == null:
			continue
		await _check_map(tree, session, map, String(map_id))
		match map_id:
			&"choyin.yamen_compound": _check_yamen(map)
			&"choyin.temple_altar": _check_altar(map)
			&"choyin.hotel_2f": _check_hotel_2f(map)
			&"choyin.hotel_3f": _check_hotel_3f(map)
			&"choyin.tree_hollow": _check_tree_hollow(map)
			&"choyin.lion_cave": _check_lion_cave(map)
			&"choyin.east":
				_check_east(map)
				for way: Array in EAST_WAYS:
					_check_passing(map, way)
			&"choyin.furnace": _check_furnace(map)
			&"choyin.guye":
				_check_guye(map)
				for way: Array in GUYE_WAYS:
					_check_passing(map, way)
			&"choyin.crown": _check_crown(map)
			&"choyin.cliff_cave": _check_cliff_cave(map)
			&"choyin.summit": _check_summit(map)
			&"choyin.valley":
				_check_valley(map)
				for way: Array in VALLEY_WAYS:
					_check_passing(map, way)
			&"choyin.hotel_house": _check_hotel_house(map)
			&"choyin.club_house": _check_club(map)
	var missing: Array[StringName] = []
	for map_id: StringName in MAPS:
		if not _seen.has(map_id):
			missing.append(map_id)
	_check(missing.is_empty(), "every map of 乔阴县城 was seen in the voxel view: missing %s" % [missing])
	session.free()
	await _frames(tree, 2)
	for id: StringName in kept:
		var npc: NpcDefinition = GameContent.catalog().npc(id)
		npc.attitude = kept[id][0]
		npc._capability_ids = kept[id][1]
	return {"assertions": assertions, "failures": failures}


## 美术规划 §1: 砖灰, 瓦灰, 柳绿, 朱红点缀 — grey tiles on every house, willows at the lake, peach
## blossom only in the 桃林, no maples, plums or cherry.
func _check_own_colours() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/choyin/voxel/town.json"))
	var flora: Dictionary = layout.get("flora", {})
	var wrong: Array[String] = []
	var peach_areas: int = 0
	for part: Dictionary in [flora] + flora.get("areas", []):
		for species: String in part.get("tree_types", []):
			if species in ["maple", "blossom", "plum", "apricot", "crabapple"]:
				wrong.append(species)
		peach_areas += 1 if "peach" in part.get("tree_types", []) else 0
	_check(wrong.is_empty() and "willow" in flora.get("tree_types", []) and peach_areas == 1 and not "peach" in flora.get("tree_types", []),
		"town: willows (柳绿) everywhere, peach blossom in the 桃林 only, no maples or plums (%s)" % [wrong])
	var grey: int = 0
	for building: Dictionary in layout.get("buildings", []):
		var roof := Color(String(building.get("roof", "000000")).get_slice(":", 0))
		grey += 1 if absf(roof.r - roof.g) < 0.08 and roof.b >= roof.r and roof.r < 0.45 else 0
	_check(grey >= 24, "town: 瓦灰 — grey tiles on the houses (%d of %d)" % [grey, layout.get("buildings", []).size()])
	var vermilion: int = 0
	for prop: Dictionary in layout.get("props", []):
		vermilion += 1 if String(prop.get("rail", "")) == "a8382a" or (prop["kind"] == "balustrade" and prop.get("wooden", false)) else 0
	_check(vermilion >= 10, "town: 朱红点缀 — the bridge's rails and the terrace's")


func _check_town(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	var looks: Array[Dictionary] = _looks(map)
	var gates: Array[String] = []
	var stone_gates: int = 0
	var stair_runs: int = 0
	var lotus: int = 0
	var general_up: bool = false
	for prop: Dictionary in view.layout.get("props", []):
		match String(prop["kind"]):
			"gateway":
				gates.append(String(prop.get("text", "")))
				stone_gates += 1 if prop.get("stone", false) else 0
			"stair_run": stair_runs += 1
			"lotus": lotus += 1
			"deity": general_up = general_up or float(prop.get("elevation", 0.0)) > 3.0 and prop.get("armour", false)
	_check("北门" in gates and "东门" in gates and "西门" in gates and "南门" in gates and stone_gates >= 4,
		"n_gate.c, e_gate.c, w_street1.c, s_gate.c: 石牌楼 at the four gates (%s)" % [gates])
	var stele: bool = false
	var standing: bool = false
	var lions: int = 0
	var stalls: int = 0
	var peach_tree: bool = false
	var drum: bool = false
	var well: bool = false
	var posted: int = 0
	for look: Dictionary in looks:
		match String(look["kind"]):
			"stele": stele = stele or look.get("text", "") == "树王坟"
			"stone_lion":
				lions += 1
				standing = standing or look.get("standing", false) and look.has("mark")
			"stall": stalls += 1
			"tree": peach_tree = peach_tree or look.get("species", "") == "peach"
			"drum": drum = true
			"well": well = look.get("cups", false)
			"column": posted += 1 if look.get("posted", false) else 0
	_check("great_stump" in kinds and "brick_shrine" in kinds and stele, "tree_tomb.c: 一截巨大的树桩, 一间小庙; n_street3.c: 石碑上书「树王坟」")
	_check(kinds.count("stair_flight") == 4, "tree_tomb.c: 东西南北四个方向都有阶梯")
	_check(standing, "w_street1.c: 街道中央立著一尊石狮, 而且是站著的, 额头上刻著一个「□」字")
	_check(lions >= 6, "n_gate.c: 两只石狮; e_gate.c: 一只铁狮; court1.c: 两只巨大的石狮 (%d)" % lions)
	_check(drum, "court1.c: 门口有一面大皮鼓")
	_check(well, "s_street1.c: 广场中央有一口大井, 井旁用绳索绑著几只杯子")
	_check(stalls >= 8, "s_street1.c, s_street3.c, n_street3.c: 各色小贩穿梭来去 — stalls (%d)" % stalls)
	_check("overpass" in kinds and stair_runs == 2 and general_up, "dragon_temple.c: 神像立在横跨道路的一个高台上, 从南北两边的阶梯爬上高台")
	_check("koi" in kinds and lotus >= 6 and view.geometry.water.levels.size() > 1500, "bridge1.c: 翠柳湖 — 睡莲, 浮萍, 艳红锦鲤")
	_check(kinds.count("balustrade") >= 14, "bridge1-5.c: 一座弯弯曲曲的曲桥 — its rails along every turn")
	_check(posted >= 12 and peach_tree and "paper_slip" in kinds, "entrance.c: 数十根梁柱, 作品贴在这里; taolin.c: 桃树枝上挂了些字条")
	var tall: Dictionary = {}
	for building: Dictionary in view.layout.get("buildings", []):
		if building.get("skirts", []).size() >= 2 and float(building.get("height", 0.0)) >= 8.0:
			tall[String(building.get("signboard", {}).get("text", ""))] = true
	_check(tall.has("福林楼") and tall.has("酒"), "s_street2.c: 福林楼; n_street2.c: 一家三层楼的酒馆 — three storeys each (%s)" % [tall.keys()])
	_check("city_wall" in kinds and "far_ground" in kinds, "s_street5.c: 看到南边的城墙; s_gate.c: 往南则是许多房舍与农田")
	_check(view.geometry._ground_style(Vector2(1696, 500), "street").get("style", "") == "slabs", "s_street2.c: 青石官道 — old flags, laid in rows")
	_check(view.lighting.lamps.size() >= 20, "lanterns along the streets for the night")


func _check_yamen(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	var gavel: bool = false
	for look: Dictionary in _looks(map):
		gavel = gavel or look["kind"] == "writing_desk" and look.get("gavel", false)
	_check(gavel and kinds.count("folding_screen") == 2 and kinds.count("punishment_tools") == 2, "yamen.c: 书案上放着笔, 墨, 纸, 砚, 惊堂木; 两旁各置屏风; 堂下摆着各式刑具")
	var plaque: bool = false
	for prop: Dictionary in view.layout.get("props", []):
		plaque = plaque or prop["kind"] == "sign" and prop.get("text", "") == "明镜高悬"
	_check(plaque, "yamen.c: 正中高悬一匾")
	_check(kinds.count("pavilion") >= 2 and view.geometry.water.levels.size() > 10 and "zither_table" in kinds, "yamen_yard.c: 亭榭错落有致; yamen_iner.c: 品茶, 吟诗, 作画之所")


func _check_altar(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var beasts: Array[String] = []
	var general: bool = false
	for look: Dictionary in _looks(map):
		if look["kind"] == "beast_statue":
			beasts.append(String(look.get("beast", "")))
		general = general or look["kind"] == "deity" and look.get("armour", false)
	beasts.sort()
	_check(general and beasts == ["bear", "eagle", "leopard", "tiger"], "altar.c: 火龙将军高大威武的神像, 旁边还有虎豹熊鹰四位将军 (%s)" % [beasts])
	_check("balustrade" in _kinds(view) and view.layout.get("low_walls", []).size() == 4, "altar.c: 隔著栏杆可以看见下面的街道 — a parapet, not walls")


func _check_hotel_2f(map: WorldMapController) -> void:
	var kinds: Array[String] = _kinds(_view_of(map))
	_check(kinds.count("square_table") == 4 and kinds.count("window") >= 5 and "zither_table" in kinds, "hotel2.c: 二楼雅座, 从这里可以眺望乔阴县城的市景")


func _check_hotel_3f(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	_check(kinds.count("closed_door") == 4 and "weapon_rack" in kinds and kinds.count("travel_chest") == 2, "hotel3.c: 客房, 富商大贾, 武师担任守卫")
	_check(String(view.layout.get("actors", {}).get("choyin.npc.guard", {}).get("coat", "")) == "3a5a8a", "hotel3.c: 一个身穿蓝布衣的人")


func _check_tree_hollow(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	_check(kinds.count("pillar_root") >= 6 and "haystack" in kinds and "light_shaft" in kinds, "tomb1-2.c: 盘根错节的树根, 一堆乾草, the hole above")
	_check(String(view.layout.get("wall_looks", [{}])[0].get("style", "")) == "earth", "tomb1.c: 粗糙的洞壁")
	_check(view.layout.get("items", {}).get("es2:d/choyin/obj/chest", {}).get("kind", "") == "travel_chest", "tomb3.c: 桃木箱")


func _check_lion_cave(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var eyes: int = 0
	for prop: Dictionary in view.layout.get("props", []):
		eyes += 1 if prop["kind"] == "glow" and String(prop.get("color", "")).begins_with("ff2a") else 0
	_check(eyes == 2 and float(view.layout["light"]["ambient_energy"][0]) < 0.2, "lionroom.c: 洞内黑漆漆的, 在一个角落里有两点红光闪烁")
	_check("bones" in _kinds(view), "the beast's lair")


func _check_east(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	var marsh: int = 0
	for cell: Vector2i in view.geometry.water.looks:
		marsh += 1 if String(view.geometry.water.looks[cell].get("kind", "")) == "shallow_water" or view.geometry.water.levels[cell] > -0.1 else 0
	_check(marsh > 200 and view.layout["light"].get("areas", []).size() >= 1 and "cloud_sea" in kinds, "cloudpool.c: 云梦大泽八百里, 雾气沼沼")
	var bamboo: int = 0
	var pine_on_rock: bool = false
	for look: Dictionary in _looks(map):
		bamboo += 1 if look["kind"] == "tree" and look.get("species", "") == "bamboo" else 0
	for prop: Dictionary in view.layout.get("props", []):
		pine_on_rock = pine_on_rock or prop["kind"] == "tree" and prop.get("species", "") == "old_pine" and float(prop.get("elevation", 0.0)) > 1.0
	_check(bamboo >= 8 and kinds.count("fence") >= 4, "fence.c: 诺大的一片竹林, 竹篱; rockyu.c: 山坡尽是湘妃竹")
	_check("boulder" in kinds and pine_on_rock and "cave_mouth" in kinds and "flames" in kinds, "tongbhill.c: 一株老松立于巨石之上; 东边山壁天成一洞, 终日烈焰雄雄")
	_check(view.geometry._ground_style(Vector2(768, 1300), "street").get("moss_chance", 0.0) >= 0.4, "rockpath1.c: 铺路的青石, 已快被茅草遮没")
	var thatched: bool = false
	for building: Dictionary in view.layout.get("buildings", []):
		thatched = thatched or building.get("roof_tiles", "") == "thatch"
	_check(thatched, "club.c: 一间由白茅草搭成的草堂")


func _check_furnace(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	_check("pill_furnace" in _kinds(view) and view.layout.get("ambience", {}).get("lightning", []).size() >= 1, "stove.c: 雷霆不断击向一粒粒仙丹, 炉门好象开着")
	_check(view.layout.get("items", {}).get("es2:d/choyin/obj/tablet", {}).has("kind"), "stove.c: 仙丹 on the floor have a look")


func _check_guye(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	var ruined: int = 0
	for building: Dictionary in view.layout.get("buildings", []):
		ruined += 1 if building.get("ruined", false) else 0
	_check(ruined == 2, "spath.c: 路旁隐约可见房舍, 皆已破败")
	var broken: bool = false
	var old_tree: bool = false
	for look: Dictionary in _looks(map):
		broken = broken or look["kind"] == "stele" and look.get("broken", false) and look.get("text", "") == "姑射山"
		old_tree = old_tree or look["kind"] == "great_tree" and float(look.get("height", 0.0)) >= 10.0
	_check(broken, "rockroad.c: 山前断碑字迹依稀可辨——「姑射山』")
	_check(old_tree and "vines" in kinds, "guyehill.c: 一株万年古树; 藤蔓错杂")
	_check("far_peak" in kinds and kinds.count("cloud_sea") >= 2 and "cave_mouth" in kinds and view.geometry.cliffs != null, "rockroad.c: 云雾缭绕; guyehill.c: 半山腰处, 隐隐可见一洞, 流云出岫")


func _check_crown(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	_check("stump" in _kinds(view) and "cloud_sea" in _kinds(view), "craneroom.c: 树冠白雾升腾")
	_check(String(view.layout.get("actors", {}).get("choyin.npc.crane", {}).get("body", "")) == "flyer", "crane.c: 白羽如雪 — the cranes fly")


func _check_cliff_cave(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	_check("light_shaft" in _kinds(view) and view.layout.get("items", {}).get("es2:d/choyin/obj/goldenrope", {}).get("kind", "") == "rope_coil", "halfhole.c: 四壁空无一物; the 缚仙绳")


func _check_summit(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	_check("jade_dais" in kinds and "banner" in kinds, "platform.c: 一座精雕细琢的玉台; 台旁置一云幡")
	_check(kinds.count("cloud_sea") >= 2 and kinds.count("glow") >= 3, "platform.c: 祥云朵朵, 瑞彩千条")


func _check_valley(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	_check("vase_hollow" in _kinds(view) and view.layout.get("items", {}).get("es2:d/choyin/obj/orchid", {}).get("kind", "") == "orchid", "hollow3.c: 一株寒谷幽兰; 山壁天然行成一空穴")
	_check(view.geometry.cliffs != null and float(view.layout["cliffs"].get("rough", 1.0)) <= 0.1, "hollow.c: 两面皆为峭壁, 光滑无物")


func _check_hotel_house(map: WorldMapController) -> void:
	var kinds: Array[String] = _kinds(_view_of(map))
	_check("counter" in kinds and kinds.count("square_table") == 6 and kinds.count("stool") >= 12 and kinds.count("wine_jars") >= 2 and "stairs" in kinds,
		"hotel1.c: 酒楼一楼多半是县城里熟客人, 东北边有一道方梯通往楼上雅座")


func _check_club(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	var books: bool = false
	for look: Dictionary in _looks(map):
		books = books or look["kind"] == "tea_table" and look.get("books", false)
	_check(books and "couch" in kinds and kinds.count("chair") == 4, "club.c: 室内仅有一竹榻, 一矮几, 四把竹椅; 矮几上摊有书卷")
	var rubbing: bool = false
	for prop: Dictionary in view.layout.get("props", []):
		rubbing = rubbing or prop["kind"] == "sign" and String(prop.get("text", "")).begins_with("书有未曾经我读")
	_check(rubbing and String(view.layout.get("wall_looks", [{}])[0].get("style", "")) == "earth", "club.c: 白茅草搭成; 堂前一幅拓片, 上书: 书有未曾经我读 事无不可对人言")


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
	_check(map.map_id() in NO_ROOMS or not rooms.is_empty(), "%s says what its rooms are used for (lived-in)" % place)
	_check_footing(map, view, place)
	for door_id: StringName in map.doors_by_id: # TEST-ONLY: the 柴门 and the 铜钉大门 open for the walk
		map.set_door_open(door_id, true)
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
	_check(GameSaveJsonCodec.encode(Work.capture(session)).text == saved, "%s: light, view side, petals and fumes leave the save and RNG unchanged" % map.map_id())
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


func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.physics_frame
		await tree.process_frame


func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
