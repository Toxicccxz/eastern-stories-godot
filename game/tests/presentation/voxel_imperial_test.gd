extends RefCounted

## 第九章 A in the fixed-angle voxel view: inside the 午门 — the walled courts behind the 铁门, red walls
## under gold coping, the giant paving with dry grass in its joints, the 金水河 under its five bridges and
## the bronze lions, the 太和门 with its guards; the 太和殿 square — the vats, the sundial, the tortoise;
## the 太和殿 — the dragon pillars, the dais, the dark 金砖; and 相国府 in 京师, plain and swept, its
## cabbages and its hen. Red, gold and white for the 皇城, set against the city's grey. The 2D maps decide
## every way through.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
## Decor tall enough to walk into: in a voxel config it must stand on blocking ground or be raised.
const TALL: Array[String] = ["standing_rock", "boulder", "banner", "torch", "bush", "tree", "well", "stone_lion", "water_vat", "stele", "censer", "dragon_pillar", "jade_dais", "screen_wall", "lantern_post", "rockery", "training_post"]
const SCENES: Array[String] = ["imperial/imperial_meridian", "imperial/imperial_square", "imperial/imperial_throne_hall", "city/city_xiangguo", "imperial/imperial_guard_camp", "imperial/imperial_lanes", "imperial/imperial_garden", "imperial/imperial_cold_palace", "imperial/imperial_well_tunnel", "imperial/imperial_yangxin_hall"]
const MAPS: Array[StringName] = [&"imperial.meridian", &"imperial.court_square", &"imperial.taihe_hall", &"city.xiangguo", &"imperial.guard_camp", &"imperial.lanes", &"imperial.yuhua_garden", &"imperial.cold_palace", &"imperial.well_tunnel", &"imperial.yangxin_hall"]
## Maps that are no rooms: no lived-in life expected.
const NO_ROOMS: Array[StringName] = [&"imperial.meridian", &"imperial.court_square", &"imperial.lanes", &"imperial.yuhua_garden", &"imperial.well_tunnel"]
## Where a test may put the player on each map (TEST-ONLY).
const ENTRIES: Dictionary[StringName, Array] = {
	&"imperial.meridian": [&"imperial.gate_court", &"imperial.gate_court.wumen_arrival"],
	&"imperial.court_square": [&"imperial.square", &"imperial.square.gate_arrival"],
	&"imperial.taihe_hall": [&"imperial.throne_hall", &"imperial.throne_hall.square_entry"],
	&"city.xiangguo": [&"city.xiangguo_yard", &"city.xiangguo_yard.gate_arrival"],
	&"imperial.guard_camp": [&"imperial.guard_yard", &"imperial.guard_yard.gate_arrival"],
	&"imperial.lanes": [&"imperial.lanes_south", &"imperial.lanes_south.square_arrival"],
	&"imperial.yuhua_garden": [&"imperial.garden", &"imperial.garden.lanes_arrival"],
	&"imperial.cold_palace": [&"imperial.cold_yard", &"imperial.cold_yard.garden_arrival"],
	&"imperial.well_tunnel": [&"imperial.well_bottom", &"imperial.well_bottom.well_arrival"],
	&"imperial.yangxin_hall": [&"imperial.yangxin_yard", &"imperial.yangxin_yard.gate_arrival"]}
var assertions: int = 0
var failures: Array[String] = []
var _seen: Dictionary[StringName, bool] = {}


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	for scene: String in SCENES:
		furnishings._check_furnishings(load("res://scenes/world/%s.tscn" % scene) as PackedScene, scene)
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
		var kinds: Array[String] = _kinds(_view_of(map))
		match map_id:
			&"imperial.meridian":
				_check(kinds.count("stone_lion") == 2 and kinds.count("water_vat") == 2 and kinds.count("pool") == 6 and kinds.count("stone_bridge") == 5, "inside the 午门: the bronze lions, the vats, the 金水河 in six stretches, five marble bridges: %s" % [kinds])
			&"imperial.court_square":
				_check(kinds.count("water_vat") == 4 and "stele" in kinds and "censer" in kinds, "the square: four vats, the sundial, the tortoise")
			&"imperial.taihe_hall":
				_check(kinds.count("dragon_pillar") == 4 and "jade_dais" in kinds, "the 太和殿: four dragon pillars and the dais")
			&"city.xiangguo":
				_check("herb_bed" in kinds and "writing_desk" in kinds and "bedding" in kinds, "相国府: cabbages, the desk, the couch")
			&"imperial.lanes":
				_check(kinds.count("lantern_post") == 4 and kinds.count("water_vat") == 4, "the 西长街: four lantern posts, the vats")
			&"imperial.yuhua_garden":
				_check(kinds.count("rockery") == 3 and kinds.count("tree") >= 2 and kinds.count("lantern_post") == 2, "the 御花园: three rockeries, cypresses, two lanterns")
			&"imperial.yangxin_hall":
				_check("grand_chair" in kinds and "chest_stack" in kinds and kinds.count("writing_desk") == 2, "the 养心殿: the throne, the memorials, the 御案 and the camphor chest")
			&"imperial.guard_camp":
				_check(kinds.count("training_post") == 2 and "weapon_rack" in kinds, "the 侍卫营: the posts and the racks")
	var missing: Array[StringName] = []
	for map_id: StringName in MAPS:
		if not _seen.has(map_id):
			missing.append(map_id)
	_check(missing.is_empty(), "every map of 第九章 A was seen in the voxel view: missing %s" % [missing])
	session.free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


## 剧情总纲 §6 皇城卡 红墙金瓦: the 皇城's walls are the city's vermilion, not its grey; its light has its own
## five frames, a deep blue night for the lanterns.
func _check_own_colours() -> void:
	var court: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/imperial/voxel/meridian.json"))
	var red := Color(String(court["wall_looks"][0]["colors"][0]))
	_check(red.r > 0.55 and red.r > red.g * 2.0, "the 皇城's walls are red: %s" % red.to_html(false))
	var light: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/imperial/voxel/light.json"))
	var frames: int = 0
	for key: String in ["sky", "ambient", "sun"]:
		frames += (light["outdoor"][key] as Dictionary).size()
	_check(frames == 15 and Color(String(light["outdoor"]["sky"]["night"])).b > Color(String(light["outdoor"]["sky"]["night"])).r and (light["outdoor"] as Dictionary).has("overcast"), "the region's light: five frames, a cold night, its own overcast")


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
