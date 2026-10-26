extends RefCounted

## 泓水南岸、日照山 and 山烟寺 in the fixed-angle voxel view: the ford across the cold river and the
## jetty where the boat puts in, the rough yellow-earth path round the foot of the hill, the road
## of mossy stones under the cliff carved 「山烟寺」, the 山门 in the temple's wall over its golden
## roofs, the tunnel west smelling of sulphur; inside, the training ground ringed with white
## poplars and its pile of bricks, the gate hall under gilt tiles with its jade plaque and the great
## door shut, the flagstone road between peonies to the golden 大雄宝殿 with its gilt dragons and
## bells, the herb garden bed by bed, the garden of brook, bridge, rockery and pavilion, the laurel
## walk, the walls painted with 观世音's deeds, the two pagodas; the gilt Buddha on his lotus
## throne, 药师如来 among the eighteen painted arhats, the drawers up to the roof and the plaques of
## 流云轩, the two stoves of the 香积厨. The ways are wide enough to pass a body standing in them;
## the 2D maps decide every way through.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
## Decor tall enough to walk into: in a voxel config it must stand on blocking ground (rock, a
## wall, a blocked box) or be raised clear of the floor (`elevation`).
const TALL: Array[String] = ["lantern", "stone_lantern", "standing_rock", "boulder", "banner", "tree", "great_tree", "pavilion",
	"rockery", "stele", "censer", "flagpole", "water_vat", "strange_stone", "stuck_swords", "boundary_stone", "torch", "bush",
	"column", "pavilion_post", "compound_wall", "deity", "spirit_tablets", "training_post", "bookcase", "lamp_stand",
	"lantern_post", "beast_statue", "screen_wall", "flower_stand", "pagoda", "temple_bell", "buddha", "stone_lion", "weapon_rack",
	"drying_rack", "fishing_net", "incense_burner", "herb_bed"]
const SCENES: Array[String] = ["sunhill_mountain", "sanyen_temple", "hall_house", "back_temple_house", "heal_room_house",
	"kitchen_house", "tunnels"]
const MAPS: Array[StringName] = [&"sunhill.mountain", &"sanyen.grounds", &"sanyen.hall_house", &"sanyen.back_temple_house",
	&"sanyen.heal_room_house", &"sanyen.kitchen_house", &"sanyen.tunnels"]
## Where a test may put the player on each room's map (TEST-ONLY).
const ENTRIES: Dictionary[StringName, Array] = {
	&"sanyen.hall_house": [&"sanyen.temple", &"sanyen.temple.road1_entry"],
	&"sanyen.back_temple_house": [&"sanyen.back_temple", &"sanyen.back_temple.corridor_entry"],
	&"sanyen.heal_room_house": [&"sanyen.heal_room", &"sanyen.heal_room.inner_yard_entry"],
	&"sanyen.kitchen_house": [&"sanyen.kitchen", &"sanyen.kitchen.corridor1_entry"],
	&"sanyen.tunnels": [&"sanyen.tunnele", &"sanyen.tunnele.gate_entry"]}
## The ways a body may stand in: each stretch between neighbouring rooms can be walked round it.
const MOUNTAIN_WAYS: Array = [[&"sunhill.dukou", &"sunhill.road1", &"sunhill.road2", &"sunhill.road3", &"sunhill.road4",
	&"sanyen.sroad1", &"sanyen.sroad2", &"sanyen.gate"]]
const GROUNDS_WAYS: Array = [
	[&"sanyen.front_yard", &"sanyen.door", &"sanyen.road1", &"sanyen.road2", &"sanyen.drug_field"],
	[&"sanyen.corridor1", &"sanyen.corridor"]]
var assertions: int = 0
var failures: Array[String] = []
var _seen: Dictionary[StringName, bool] = {}


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	for scene: String in SCENES:
		furnishings._check_furnishings(load("res://scenes/world/sanyen/%s.tscn" % scene) as PackedScene, scene)
	assertions += furnishings.assertions
	failures.append_array(furnishings.failures)
	_check_own_colours()
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	_check(session.handoff_to(&"sunhill.mountain", &"sunhill.dukou", &"sunhill.dukou", &"sunhill.dukou.ferry_arrival").succeeded(), "off the boat at 江南渡口")
	await _frames(tree, 6)
	var mountain := session.active_map() as WorldMapController
	_check(mountain != null and mountain.map_id() == &"sunhill.mountain", "on the south bank of 泓水")
	if mountain != null and mountain.map_id() == &"sunhill.mountain":
		await _check_map(tree, session, mountain, "泓水南岸与日照山")
		_check_mountain(mountain)
		for way: Array in MOUNTAIN_WAYS:
			_check_passing(mountain, way)
		_check(await MapPlaces.drive_through(tree, mountain, [&"sunhill.road1", &"sunhill.road2", &"sunhill.road3", &"sunhill.road4",
			&"sanyen.sroad1", &"sanyen.sroad2", &"sanyen.gate"]), "on foot up the yellow-earth path and along the stone road to the 山门")
		_check(await MapPlaces.take_passage(tree, mountain, &"sanyen.gate.north"), "through the 山门")
		await _frames(tree, 6)
	var grounds := session.active_map() as WorldMapController
	_check(grounds != null and grounds.map_id() == &"sanyen.grounds", "inside 山烟寺's 山门")
	if grounds != null and grounds.map_id() == &"sanyen.grounds":
		await _check_map(tree, session, grounds, "山烟寺")
		_check_grounds(grounds)
		for way: Array in GROUNDS_WAYS:
			_check_passing(grounds, way)
		_check(await MapPlaces.drive_through(tree, grounds, [&"sanyen.door", &"sanyen.road1"]), "through a side door of the gate hall onto the road")
	for map_id: StringName in ENTRIES:
		var entry: Array = ENTRIES[map_id]
		var map := MapPlaces.enter(session, entry[0], entry[1]) # TEST-ONLY: each room's map as it is drawn
		await _frames(tree, 4)
		_check(map != null and map.projected_view, "%s in its voxel view" % map_id)
		if map == null:
			continue
		await _check_map(tree, session, map, String(map_id))
		match map_id:
			&"sanyen.hall_house": _check_hall(map)
			&"sanyen.back_temple_house": _check_back_temple(map)
			&"sanyen.heal_room_house": _check_heal_room(map)
			&"sanyen.kitchen_house": await _check_kitchen(tree, map)
			&"sanyen.tunnels": _check_tunnels(map)
	var missing: Array[StringName] = []
	for map_id: StringName in MAPS:
		if not _seen.has(map_id):
			missing.append(map_id)
	_check(missing.is_empty(), "every map of 山烟寺 and 日照山 was seen in the voxel view: missing %s" % [missing])
	session.free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


## 美术规划 §1: 暖灰、金、翡翠绿 — gilt roofs, white poplars, no maples or blossom trees.
func _check_own_colours() -> void:
	for view: String in ["mountain", "grounds"]:
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sanyen/voxel/%s.json" % view))
		var flora: Dictionary = layout.get("flora", {})
		var wrong: Array[String] = []
		for part: Dictionary in [flora] + flora.get("areas", []):
			for species: String in part.get("tree_types", []):
				if species in ["maple", "blossom", "plum", "apricot", "peach"]:
					wrong.append(species)
		_check(wrong.is_empty() and "poplar" in str(flora), "%s: 白杨 and jade greens, no maples or blossom (%s)" % [view, wrong])
		var gilt: int = 0
		for building: Dictionary in layout.get("buildings", []):
			var roof := Color(String(building.get("roof", "000000")).get_slice(":", 0))
			gilt += 1 if roof.r > roof.b * 1.6 and roof.r > 0.55 and String(building["roof"]).ends_with(":gloss") else 0
		_check(gilt >= 1, "%s: 上覆金瓦 — a golden glazed roof" % view)


func _check_mountain(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	_check(view.geometry.water.levels.size() > 2000, "泓水: wide and cold")
	var ford: int = 0
	for cell: Vector2i in view.geometry.water.looks:
		ford += 1 if is_equal_approx(view.geometry.water.levels[cell], 0.06) else 0
	_check(ford > 200, "northriver.c: 江水齐胸深 — the ford's shallows")
	_check("jetty" in kinds and "skiff" in kinds and "mooring_post" in kinds, "江南渡口: the jetty, the boatman's boat")
	var carved: bool = false
	var gate: bool = false
	for prop: Dictionary in view.layout.get("props", []):
		carved = carved or prop["kind"] == "carved_wall" and prop.get("text", "") == "山烟寺"
		gate = gate or prop["kind"] == "gateway" and prop.get("text", "") == "山烟寺"
	_check(carved and view.geometry.cliffs != null, "sroad1.c: 东面的山壁上刻著「山烟寺」几个大字")
	_check(gate and kinds.count("compound_wall") >= 4, "gate.c: the 山门 in the temple's wall")
	_check("cave_mouth" in kinds and "stains" in kinds, "sroad2.c: 往东穿过一个山壁上凿出来的隧道; tunnel.c: 硫磺的味道")
	_check(view.geometry._ground_style(Vector2(1120, 1728), "street").get("moss_chance", 0.0) >= 0.4, "sroad1.c: 一条铺著生满青苔大石的山路")
	_check(view.geometry._ground_style(Vector2(1760, 1300), "path").has("colors"), "road1-4.c: 崎岖的黄土小径")
	_check(view.lighting.lamps.size() >= 3, "moonlight and the boat's lamp for the night")


func _check_grounds(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	var looks: Array[Dictionary] = _looks(map)
	var species: Dictionary = {}
	var pagodas: Array[String] = []
	var herbs: Dictionary = {}
	var peonies: int = 0
	for look: Dictionary in looks:
		match String(look["kind"]):
			"tree": species[look.get("species", "")] = int(species.get(look.get("species", ""), 0)) + 1
			"pagoda": pagodas.append(String(look.get("text", "")))
			"herb_bed": herbs[look.get("herb", "")] = true
			"camellia_bed": peonies += 1 if look.get("peony", false) else 0
	_check(int(species.get("poplar", 0)) >= 8, "front_yard.c: 空地四周种了一排白杨树")
	_check("stone_blocks" in kinds, "front_yard.c: 靠北边的地方放了一堆用来锻链膂力的砖头")
	_check("明心塔" in pagodas and "见性塔" in pagodas, "tower.c: 『明心塔』, 『见性塔』")
	_check(herbs.has("umbel") and herbs.has("berry") and kinds.count("herb_bed") >= 4, "drug_field.c: 哪边种当归, 哪边种枸杞, 绝不会混在一起")
	_check(peonies >= 5, "road1.c, road2.c: 两旁种植一排芍药")
	_check(int(species.get("osmanthus", 0)) >= 6, "corridor.c: 两旁种植著一排月桂树")
	_check("pavilion" in kinds and kinds.count("rockery") >= 2 and view.geometry.water.levels.size() > 50, "inner_yard.c: 小桥流水, 假山凉亭")
	var plaque: bool = false
	var murals: int = 0
	for prop: Dictionary in view.layout.get("props", []):
		plaque = plaque or prop["kind"] == "sign" and prop.get("text", "") == "山烟寺" and String(prop.get("board", "")).begins_with("2f8a62")
		murals += 1 if prop["kind"] == "mural" else 0
	_check(plaque, "door.c: 一方翡翠匾额, 上面写著『山烟寺』三个烫金大字")
	_check(murals >= 1, "corridor1.c: 墙上画著大慈大悲观世音菩萨救苦救难的事迹")
	var shut: bool = false
	for look: Dictionary in looks:
		shut = shut or look["kind"] == "red_door"
	_check(shut and "pavilion_roof" in kinds, "door.c: 正中的大门正紧紧关闭著…只开著两旁的偏门, under gilt tiles")
	_check(TerrainProbe.blocks_at(map, Vector2(1088, 1904)) and not TerrainProbe.blocks_at(map, Vector2(1000, 1904))
		and not TerrainProbe.blocks_at(map, Vector2(1176, 1904)), "door.c: the great middle door shut, the side doors open")
	var hall: Dictionary = {}
	for building: Dictionary in view.layout.get("buildings", []):
		if "sanyen.road1.north" in building.get("portals", []):
			hall = building
	_check(hall.has("corner_beasts") and hall.get("bells", false), "road1.c: 屋檐的四个角落雕就著四只金龙, 屋檐下还各挂著一串金风铃")
	var golden: Dictionary = view.layout.get("door_looks", {}).get("sanyen.road1.door", {})
	_check(golden.get("leaf", "") == "c9a24a", "temple.c: 两扇敞开的金门")
	_check(view.lighting.lamps.size() >= 4, "lanterns for the night")


func _check_hall(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var buddha: Dictionary = {}
	for look: Dictionary in _looks(map):
		if look["kind"] == "buddha":
			buddha = look
	_check(buddha.get("gilt", false) and float(buddha.get("height", 0.0)) >= 6.0, "temple.c: 一丈八尺的如来佛祖金身, 坐在一座三尺高的莲台上")
	_check(view.geometry.wall_height > 3.2, "the great hall's walls stand higher than a room's")
	var kinds: Array[String] = _kinds(view)
	_check("censer" in kinds and "altar_table" in kinds, "temple.c: 前方的香炉里香烟缓缓飘上天")
	_check("silk_curtain" in kinds, "temple.c: 在佛像的右侧有道黄布幔")
	_check("notices" in kinds, "the monks' board (call_other bonze_b)")


func _check_back_temple(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var bowl: bool = false
	for look: Dictionary in _looks(map):
		bowl = bowl or look["kind"] == "buddha" and look.get("mudra", "") == "bowl"
	_check(bowl, "back_temple.c: 正中有一尊药师如来的金身塑像")
	var arhats: int = 0
	for prop: Dictionary in view.layout.get("props", []):
		arhats += int(prop.get("figures", 0)) if prop["kind"] == "mural" else 0
	_check(arhats == 18, "back_temple.c: 四周的墙上唯妙唯肖地彩绘著十八罗汉 (%d)" % arhats)


func _check_heal_room(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	_check("herb_cabinet" in kinds, "heal_room.c: 与屋顶齐高的木柜, 画分成许多抽屉")
	_check(kinds.count("plaques") >= 2, "heal_room.c: 两侧的墙璧上挂了许许多多的檀木扁额")


func _check_kitchen(tree: SceneTree, map: WorldMapController) -> void:
	var stoves: int = 0
	var steamer: bool = false
	for look: Dictionary in _looks(map):
		if look["kind"] == "cauldron":
			stoves += 1
			steamer = steamer or look.get("steamer", false)
	_check(stoves == 2 and steamer, "kitchen.c: 西北边的角落里砌了两个大灶…一个大锅及一个蒸笼")
	await _frames(tree, 2)
	var service := map.get_node_or_null("Steamer") as Node2D
	var starts: Array[Vector2] = [map.player_body.global_position]
	var near: Vector2 = Vector2.INF if service == null else MapPlaces.spot(map, &"sanyen.kitchen", service.global_position, 100.0)
	_check(service != null and _walkable_to(map, starts, near) and near.distance_to(service.global_position) <= 100.0,
		"the steamer can be walked up to and opened")


func _check_tunnels(map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	_check(kinds.count("vent") >= 2, "tunnel.c: 隧道中你可以闻到一股硫磺的味道")
	_check(kinds.count("light_shaft") == 2, "tunnele.c: 东边是隧道的出口, 往西不远处也可以从这里瞧见西边的出口")
	_check(String(view.layout.get("wall_looks", [{}])[0].get("style", "")) == "rock", "凿穿山壁开成的隧道: walls of rock")


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
	_check(map.map_id() in [&"sunhill.mountain", &"sanyen.grounds", &"sanyen.tunnels"] or not rooms.is_empty(), "%s says what its rooms are used for (lived-in)" % place)
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
	_check(GameSaveJsonCodec.encode(Work.capture(session)).text == saved, "%s: light, view side, leaves and fumes leave the save and RNG unchanged" % map.map_id())
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
