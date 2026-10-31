extends RefCounted

## 关北 A in the fixed-angle voxel view (four maps): the military road out of the valley's east
## gate — the gate's stone back with 严廷殷's flag, pale cliffs falling back to the steppe, the
## boundary stone, 槐阳城's earth wall across the north; the city — rammed-earth walls and gate
## tower, the caravan yard with its kneeling camels, the mud-brick shopfronts of the street, the
## 王府's faded red gate; the 马市 — the pen and its ponies, the tethered pair, the camel pen, the
## 酒肆's flag; the 酒肆 — the sunk hearth, the counter, the mud walls. Its own colours: grass
## where 天驼关 has none, earth where it has yellow stone. The 2D maps decide every way through.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
## Decor tall enough to walk into: in a voxel config it must stand on blocking ground or be raised.
const TALL: Array[String] = ["standing_rock", "boulder", "banner", "torch", "cairn", "bush", "tree", "campfire", "well", "wine_jars", "firewood", "crocks",
	"rock_pile", "dead_log", "stele", "cart", "haystack", "notice_post", "horse", "camel", "tethered_horse", "fence", "stone_lion", "drying_rack", "saw_horse",
	"hearth", "counter", "cauldron", "meat_rack", "lantern_post", "post", "chest_stack", "sacks"]
const SCENES: Array[String] = ["guanbei_gorge", "guanbei_town", "guanbei_market", "guanbei_inn", "guanbei_palace_court", "guanbei_palace"]
const MAPS: Array[StringName] = [&"guanbei.gorge", &"guanbei.town", &"guanbei.horse_market", &"guanbei.inn", &"guanbei.palace_court", &"guanbei.palace"]
## Maps that are no rooms: no lived-in life expected.
const NO_ROOMS: Array[StringName] = [&"guanbei.gorge", &"guanbei.town", &"guanbei.horse_market"]
## Where a test may put the player on each map (TEST-ONLY).
const ENTRIES: Dictionary[StringName, Array] = {
	&"guanbei.gorge": [&"guanbei.gate_road", &"guanbei.gate_road.pass_arrival"],
	&"guanbei.town": [&"guanbei.gate", &"guanbei.gate.gorge_arrival"],
	&"guanbei.horse_market": [&"guanbei.market", &"guanbei.market.street_arrival"],
	&"guanbei.inn": [&"guanbei.inn_hall", &"guanbei.inn_hall.market_entry"],
	&"guanbei.palace_court": [&"guanbei.palace_yard", &"guanbei.palace_yard.gate_arrival"],
	&"guanbei.palace": [&"guanbei.palace_hall", &"guanbei.palace_hall.yard_entry"]}
var assertions: int = 0
var failures: Array[String] = []
var _seen: Dictionary[StringName, bool] = {}


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	for scene: String in SCENES:
		furnishings._check_furnishings(load("res://scenes/world/guanbei/%s.tscn" % scene) as PackedScene, scene)
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
		await _check_map(tree, session, map, String(map_id))
		match map_id:
			&"guanbei.gorge": await _check_gorge(tree, map)
			&"guanbei.town": await _check_town(tree, session, map)
			&"guanbei.horse_market": await _check_market(tree, map)
			&"guanbei.inn": await _check_inn(tree, map)
			&"guanbei.palace_court": await _check_court(tree, map)
			&"guanbei.palace": await _check_palace(tree, map)
	var missing: Array[StringName] = []
	for map_id: StringName in MAPS:
		if not _seen.has(map_id):
			missing.append(map_id)
	_check(missing.is_empty(), "every map of 关北 A and B was seen in the voxel view: missing %s" % [missing])
	session.free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


## 美术规划 §1 关北: 夯土黄褐、毡白、草原灰绿到秋金 — grass where 天驼关 has none, a higher paler sky, its
## own flora file with four colours of each kind; the dusk red, the night cold.
func _check_own_colours() -> void:
	var gorge: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/guanbei/voxel/gorge.json"))
	var pass_layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/canyon/voxel/pass.json"))
	var grass := Color(String(gorge["ground"]["grass"]["colors"][0]))
	var pass_grass := Color(String(pass_layout["ground"]["grass"]["colors"][0])) if (pass_layout["ground"] as Dictionary).has("grass") else Color.WHITE
	_check(grass.g > grass.r and grass.g > grass.b + 0.15 and grass.g - grass.r > pass_grass.g - pass_grass.r, "the steppe's turf is grey-green, greener than the pass's straw (the 石林's meadow): %s vs %s" % [grass.to_html(false), pass_grass.to_html(false)])
	var ours := Color(String(gorge["cliffs"]["strata"][0]))
	var theirs := Color(String(pass_layout["cliffs"]["strata"][0]))
	_check(ours.r + ours.g + ours.b > theirs.r + theirs.g + theirs.b + 0.2, "the cliffs beyond the gate are paler than the pass's yellow stone: %s vs %s" % [ours.to_html(false), theirs.to_html(false)])
	var flora: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/guanbei/voxel/flora.json"))
	var canyon_flora: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/canyon/voxel/flora.json"))
	var kinds: int = 0
	for key: String in ["crown_colors", "bark_colors", "grass_colors", "flower_colors"]:
		var value: Variant = flora.get(key)
		kinds += 1 if (value is Array and (value as Array).size() >= 4) or (value is Dictionary and (value as Dictionary).size() >= 4) else 0
	_check(kinds == 4 and flora["grass_colors"] != canyon_flora["grass_colors"] and "poplar" in flora["crown_colors"] and not ("mountain_pine" in flora["crown_colors"]), "the region's flora: four colours each, its own — gold poplars, no mountain pines")
	var light: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/guanbei/voxel/light.json"))
	var canyon_light: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/canyon/voxel/light.json"))
	var frames: int = 0
	for key: String in ["sky", "ambient", "sun"]:
		frames += (light["outdoor"][key] as Dictionary).size()
	var day := Color(String(light["outdoor"]["sky"]["day"]))
	var canyon_day := Color(String(canyon_light["outdoor"]["sky"]["day"]))
	_check(frames == 15 and Color(String(light["outdoor"]["sky"]["dusk"])).r > 0.8 and Color(String(light["outdoor"]["sky"]["night"])).b > Color(String(light["outdoor"]["sky"]["night"])).r and day.r + day.g + day.b > canyon_day.r + canyon_day.g + canyon_day.b, "the region's light: five frames, the sky higher and paler than the pass's, dusk red, night cold")
	_check((light["outdoor"] as Dictionary).has("overcast") and Color(String(light["outdoor"]["overcast"]["sky"])).r > Color(String(canyon_light["outdoor"]["overcast"]["sky"])).r, "its own overcast, a brighter dust-grey than the pass's")


## The road out: the gate's back with its flag, ruts, the boundary stone, the city wall north.
func _check_gorge(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["stele", "trail", "cart_wheel", "bones", "far_peak", "far_ground", "cairn", "standing_rock", "torch"]:
		_check(kind in kinds, "the road has its %s" % kind)
	var flagged: bool = false
	var earth: int = 0
	for building: Dictionary in view.layout.get("buildings", []):
		flagged = flagged or (building.get("hanging_flag", {}) as Dictionary).get("text", "") == "严"
		earth += 1 if building.get("construction", "") == "earth" else 0
	_check(flagged and earth == 1, "严廷殷's flag on the gate's back; the city's earth wall across the north")
	var cliffs: VoxelCliffs = view.geometry.cliffs
	_check(cliffs != null and cliffs.heights.size() > 400, "the pale cliffs stand either side of the road")
	var areas: Array = (view.layout.get("cliffs", {}) as Dictionary).get("areas", [])
	_check(areas.size() == 3 and float(areas[0]["high"]) > 4.0 and float(areas[2]["high"]) < 1.5, "the cliffs fall back toward the steppe: high in the gorge, low banks at the stone")
	_check(view.geometry.terrain_cells.get(Vector2i(520, 408), "") == "path" and view.geometry.terrain_cells.get(Vector2i(392, 296), "") == "grass", "the road runs on through grass at the boundary: %s %s" % [view.geometry.terrain_cells.get(Vector2i(520, 408), ""), view.geometry.terrain_cells.get(Vector2i(392, 296), "")])
	_check(view.geometry.ambience._puffs.size() >= 2 or view.geometry.ambience._motes.size() >= 20, "风沙道: sand on the wind")
	for row: Array in [[&"guanbei.boundary.north", Vector2.UP], [&"guanbei.gate_road.south", Vector2.DOWN]]:
		var arrow: Node3D = view.arrows.get(row[0])
		_check(arrow != null and arrow.get_meta("direction") == row[1], "the exit arrow of %s points out of its room" % row[0])
	_check(await MapPlaces.drive_through(tree, map, [&"guanbei.dust_road", &"guanbei.boundary"]), "walk from the gate up to the stone")
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"guanbei.boundary", Vector2(600, 320), 48.0)), "and up to the stone itself")


## The city: earth walls and the gate tower, the yard, the shopfronts, the 王府's shut gate.
func _check_town(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["camel", "notice_post", "cart", "haystack", "stone_blocks", "banner", "animal_hide", "drying_rack", "whetstone", "firewood", "far_peak"]:
		_check(kind in kinds, "the city has its %s" % kind)
	_check(kinds.count("camel") == 2 and kinds.count("banner") >= 4, "two camels kneeling in the yard, banners on the gate and the 王府")
	var earth: int = 0
	var thatch: int = 0
	var palace_door: bool = false
	var signs: Array[String] = []
	for building: Dictionary in view.layout.get("buildings", []):
		earth += 1 if building.get("construction", "") == "earth" else 0
		thatch += 1 if building.get("roof_tiles", "") == "thatch" else 0
		palace_door = palace_door or "guanbei.palace_front.north" in building.get("portals", [])
		if building.has("signboard"):
			signs.append(String(building["signboard"]["text"]))
	_check(earth >= 7 and thatch == 3 and palace_door and signs == ["铁", "皮货", "马具"], "walls and tower of rammed earth, three thatched shopfronts with their signs, the 王府's gate with its way in (关北 B): %d %d %s" % [earth, thatch, signs])
	_check(view.geometry.cliffs == null, "no cliffs in the town")
	# The street 320 wide (two bodies abreast with room to spare) from the gate yard to the 王府.
	var narrow: Array[String] = []
	for row: Array in [["the gate yard", 464, 944, 1248], ["the street's south end", 560, 848, 1180], ["the street's middle", 560, 848, 832], ["the street's north end", 560, 848, 480], ["the 王府's forecourt", 496, 912, 300]]:
		var open: bool = true
		for x: int in range(int(row[1]) + 8, int(row[2]), 16):
			open = open and not TerrainProbe.blocks_at(map, Vector2(x, int(row[3])))
		if not open:
			narrow.append(String(row[0]))
	_check(narrow.is_empty(), "the ways are wide enough: narrow at %s" % [narrow])
	_check(await MapPlaces.drive_through(tree, map, [&"guanbei.street", &"guanbei.palace_front"]), "walk from the gate up the street to the 王府's front")
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"guanbei.gate.notice")), "and back down to the notice")
	var button := session.shared_ui().find_child("ViewSide", true, false) as VoxelViewSideButton
	_check(map.place_player(&"guanbei.street", MapPlaces.zone_spot(map, &"guanbei.street")), "TEST-ONLY: on the street")
	await _frames(tree, 2)
	for left: bool in [true, false]:
		_click(tree, button)
		await tree.create_timer(WorldVoxelView.VIEW_ROTATION_SECONDS + 0.05).timeout
		var start: Vector2 = map.player_body.global_position
		Input.action_press("move_right")
		await _frames(tree, 8)
		MapPlaces.release()
		var moved: Vector2 = map.view_ground.basis_xform(map.player_body.global_position - start)
		_check(view.left_view == left and moved.x > 4 and absf(moved.y) < 2, "D walks screen-right on the street from the %s side" % ("left" if left else "right"))
		_check(map.place_player(&"guanbei.street", start), "back on the street")
		await _frames(tree, 2)


## The 马市: the pen's rails and ponies, the tethered pair, the camel pen, the 酒肆's wine flag.
func _check_market(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["horse", "camel", "fence", "steelyard", "haystack", "cart", "sacks", "straw_patch", "bedroll"]:
		_check(kind in kinds, "the market has its %s" % kind)
	_check(kinds.count("horse") == 5 and kinds.count("camel") == 2 and kinds.count("fence") == 5, "five ponies (three in the pen, two tethered), two camels, five rails")
	var flagged: bool = false
	for building: Dictionary in view.layout.get("buildings", []):
		flagged = flagged or (building.get("hanging_flag", {}) as Dictionary).get("text", "") == "酒"
	_check(flagged, "the 酒肆's wine flag over its door (native:guanbei/market: 挑着一面酒旗)")
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"guanbei.market", Vector2(980, 790), 56.0)), "walk round the pen's south side to 卢卡's corner")
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"guanbei.market", Vector2(640, 440), 48.0)), "and up to the 酒肆's door")


## The 酒肆: the sunk hearth and its pot, the counter, benches, skins on the mud walls, lived in.
func _check_inn(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["cauldron", "counter", "chopping_block", "table", "bench_seat", "crocks", "meat_rack", "animal_hide", "meat_hooks", "window", "glow"]:
		_check(kind in kinds, "the 酒肆 has its %s" % kind)
	var earth: int = 0
	for look: Dictionary in view.geometry.wall_looks:
		earth += 1 if look.get("style", "") == "earth" else 0
	_check(earth >= 2, "both rooms walled in rammed earth: %d" % earth)
	var life: VoxelLife = view.geometry.life
	_check(life.worn_cells.get(&"guanbei.inn_hall", 0) > 0 and life.hung.get(&"guanbei.inn_hall", 0) >= 1, "the hall lived in: the floor worn, things hung on its walls")
	var pieces: int = 0
	for look: Dictionary in _looks(map):
		pieces += 1 if look["kind"] in ["wine_jars", "sacks", "crocks", "clutter", "baskets", "chest_stack"] else 0
	_check(pieces >= 4, "the painter's lived-in pieces in the hall and the back room: %d" % pieces)
	_check(await MapPlaces.drive_through(tree, map, [&"guanbei.inn_back", &"guanbei.inn_hall"]), "walk into the back room and out")
	var keeper: WorldCharacterBody2D = map.runtime_body_for_spawn_point(&"guanbei.inn_hall.hu_sanniang.1")
	_check(keeper != null, "胡三娘 is behind her counter")
	if keeper != null:
		var near: Vector2 = MapPlaces.spot(map, &"guanbei.inn_hall", keeper.global_position + Vector2(-60, 0), 64.0)
		_check(await MapPlaces.drive(tree, map, near) and map.player_body.global_position.distance_to(keeper.global_position) < 96.0, "up to her past the hearth")


## The 王府's court: the screen wall, the swept yard, the posts with their hacked shoulders.
func _check_court(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["screen_wall", "training_post", "weapon_rack", "stakes", "water_vat", "post", "fence", "stone_blocks"]:
		_check(kind in kinds, "the court has its %s" % kind)
	_check(kinds.count("training_post") == 3 and kinds.count("post") >= 2, "three posts to hack, two flag poles")
	var earth: int = 0
	for look: Dictionary in view.geometry.wall_looks:
		earth += 1 if look.get("style", "") == "earth" else 0
	_check(earth >= 1, "rammed-earth walls round the yards")
	_check(await MapPlaces.drive_through(tree, map, [&"guanbei.drill", &"guanbei.palace_yard"]), "walk from the gate round the screen wall to the drill yard and back")
	_check(await MapPlaces.drive(tree, map, MapPlaces.passage_spot(map, &"guanbei.palace_yard.north") + Vector2(0, 60)), "and up to the hall's steps")


## The 王府's hall: the chair and its skin, the rack, the benches; the side hall's desk and map.
func _check_palace(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["grand_chair", "weapon_rack", "bench_seat", "table", "brazier", "writing_desk", "chest_stack"]:
		_check(kind in kinds, "the 王府 has its %s" % kind)
	_check(kinds.count("bench_seat") == 3 and kinds.count("brazier") == 2, "three benches for the waiting, a brazier in each room")
	var life: VoxelLife = view.geometry.life
	_check(life.worn_cells.get(&"guanbei.palace_hall", 0) > 0, "the hall's brick worn from the door to the dais")
	_check(await MapPlaces.drive_through(tree, map, [&"guanbei.side_hall", &"guanbei.palace_hall"]), "walk into the side hall and back")
	var prince: WorldCharacterBody2D = map.runtime_body_for_spawn_point(&"guanbei.palace_hall.cheng_shuo.1")
	_check(prince != null, "程朔 sits on his chair")
	if prince != null:
		var near: Vector2 = MapPlaces.spot(map, &"guanbei.palace_hall", prince.global_position + Vector2(0, 60), 64.0)
		_check(await MapPlaces.drive(tree, map, near) and map.player_body.global_position.distance_to(prince.global_position) < 96.0, "up to him before the dais")


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
	for door_id: StringName in map.doors_by_id: # TEST-ONLY: the 王府大门 open for the walk
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
