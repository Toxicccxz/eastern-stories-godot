extends RefCounted

## 番坊 A in the fixed-angle voxel view (four maps): the 海崖道 — a bare headland with the sea god's
## niche, the road cut into a dark sea cliff with the sea far below (a cliff `sink` with the sea at
## its foot) running out to the sky (`water.open_sea`), gulls and spray; the port — the stone
## quay, two jetties, three flat-bottomed boats, the derrick and the crates, the tax table, the
## boatmen's lean-to; the bazaar — the stalls of glass, carpets, spice and copper, flat-roofed
## 胡商 houses and tiled ones, the black 拜火祠 smoking at the street's end, 铁盾会's gate with its
## two great shields, the lane sloping south; the 市舶司 — the desk, the notices, the seized goods,
## the yard; 番坊 B's three: 铁盾会's sanded yard with the shield racks, the hacked posts and the
## 会首's hut with its carpet; the 拜火祠's black hall with the fire on its altar, the shaft of day
## down the smoke-hole; 日陀罗寺's banyan, bell and Buddha. Its own colours: sea blue-grey and dark
## basalt where 关北 has dust and grass. The 2D maps decide every way through.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
## Decor tall enough to walk into: in a voxel config it must stand on blocking ground or be raised.
const TALL: Array[String] = ["standing_rock", "boulder", "banner", "torch", "cairn", "bush", "tree", "campfire", "well", "wine_jars", "firewood", "crocks",
	"rock_pile", "dead_log", "stele", "cart", "haystack", "notice_post", "horse", "camel", "tethered_horse", "fence", "stone_lion", "drying_rack", "saw_horse",
	"hearth", "counter", "cauldron", "meat_rack", "lantern_post", "post", "chest_stack", "sacks", "derrick", "lumber", "baskets", "water_vat", "bench",
	"great_shield", "stall", "lean_to", "mooring_post", "loot_crates", "cargo", "shield_rack", "fire_altar", "temple_bell", "training_post", "stone_seat",
	"tea_table", "bed", "travel_chest", "lamp_stand", "sandbags", "prayer_cushion", "buddha", "altar_table", "weapon_rack", "bedding", "lantern_post"]
const SCENES: Array[String] = ["fanfang_cliff_road", "fanfang_port", "fanfang_bazaar", "fanfang_customs", "fanfang_shield_hall", "fanfang_fire_temple", "fanfang_lama_temple"]
const MAPS: Array[StringName] = [&"fanfang.cliff_road", &"fanfang.port", &"fanfang.bazaar", &"fanfang.customs", &"fanfang.shield_hall", &"fanfang.fire_temple", &"fanfang.lama_temple"]
## Maps that are no rooms: no lived-in life expected.
const NO_ROOMS: Array[StringName] = [&"fanfang.cliff_road", &"fanfang.port", &"fanfang.bazaar"]
## Where a test may put the player on each map (TEST-ONLY).
const ENTRIES: Dictionary[StringName, Array] = {
	&"fanfang.cliff_road": [&"fanfang.cliff_top", &"fanfang.cliff_top.valley_arrival"],
	&"fanfang.port": [&"fanfang.dock", &"fanfang.dock.cliff_arrival"],
	&"fanfang.bazaar": [&"fanfang.bazaar_west", &"fanfang.bazaar_west.dock_arrival"],
	&"fanfang.customs": [&"fanfang.office", &"fanfang.office.street_entry"],
	&"fanfang.shield_hall": [&"fanfang.shield_yard", &"fanfang.shield_yard.gate_arrival"],
	&"fanfang.fire_temple": [&"fanfang.fire_hall", &"fanfang.fire_hall.street_entry"],
	&"fanfang.lama_temple": [&"fanfang.temple_yard", &"fanfang.temple_yard.slope_arrival"]}
var assertions: int = 0
var failures: Array[String] = []
var _seen: Dictionary[StringName, bool] = {}


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	for scene: String in SCENES:
		furnishings._check_furnishings(load("res://scenes/world/fanfang/%s.tscn" % scene) as PackedScene, scene)
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
			&"fanfang.cliff_road": await _check_cliff_road(tree, map)
			&"fanfang.port": await _check_port(tree, map)
			&"fanfang.bazaar": await _check_bazaar(tree, map)
			&"fanfang.customs": await _check_customs(tree, map)
			&"fanfang.hall": await _check_shield_hall(tree, map)
			&"fanfang.fire_temple": await _check_fire_temple(tree, map)
			&"fanfang.lama_temple": await _check_lama_temple(tree, map)
	var missing: Array[StringName] = []
	for map_id: StringName in MAPS:
		if not _seen.has(map_id):
			missing.append(map_id)
	_check(missing.is_empty(), "every map of 番坊 was seen in the voxel view: missing %s" % [missing])
	session.free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


## 美术规划 §1 番坊: 海蓝灰、盐白、胡商的红黄 — the sea grey-blue, the cliffs dark basalt where 关北's
## are pale dust, a wet bright sky, its own flora (stunted pines leaning inland, no poplars).
func _check_own_colours() -> void:
	var road: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/fanfang/voxel/cliff_road.json"))
	var gorge: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/guanbei/voxel/gorge.json"))
	var sea := Color(String(road["water"]["kinds"]["deep_water"]["colors"][1]))
	_check(sea.b > sea.r + 0.1 and sea.g > sea.r, "the sea is grey-blue: %s" % sea.to_html(false))
	var ours := Color(String(road["cliffs"]["strata"][0]))
	var theirs := Color(String(gorge["cliffs"]["strata"][0]))
	_check(ours.r + ours.g + ours.b < theirs.r + theirs.g + theirs.b - 0.6, "the sea cliffs are dark basalt beside 关北's pale dust: %s vs %s" % [ours.to_html(false), theirs.to_html(false)])
	var flora: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/fanfang/voxel/flora.json"))
	var guanbei_flora: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/guanbei/voxel/flora.json"))
	var kinds: int = 0
	for key: String in ["crown_colors", "bark_colors", "grass_colors", "flower_colors"]:
		var value: Variant = flora.get(key)
		kinds += 1 if (value is Array and (value as Array).size() >= 4) or (value is Dictionary and (value as Dictionary).size() >= 4) else 0
	_check(kinds == 4 and flora["grass_colors"] != guanbei_flora["grass_colors"] and "stunted_pine" in flora["crown_colors"] and not ("poplar" in flora["crown_colors"]), "the region's flora: four colours each, its own — stunted pines, no poplars")
	var light: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/fanfang/voxel/light.json"))
	var frames: int = 0
	for key: String in ["sky", "ambient", "sun"]:
		frames += (light["outdoor"][key] as Dictionary).size()
	var day := Color(String(light["outdoor"]["sky"]["day"]))
	var night := Color(String(light["outdoor"]["sky"]["night"]))
	_check(frames == 15 and day.b > day.r and Color(String(light["outdoor"]["sky"]["dusk"])).r > 0.8 and night.b > night.r and (light["outdoor"] as Dictionary).has("overcast"), "the region's light: five frames, a sea-blue day, dusk orange, night blue, its own overcast")


## The cliff road: the headland and its niche, the cut road, the sea far below and running on.
func _check_cliff_road(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["shrine_niche", "snail_shells", "candles", "rough_steps", "trail", "cairn", "sacks", "bench", "far_peak", "far_ground", "glow"]:
		_check(kind in kinds, "the cliff road has its %s" % kind)
	var cliffs: VoxelCliffs = view.geometry.cliffs
	var sunk: int = 0
	var beyond: int = 0
	for cell: Vector2i in cliffs.heights:
		if cliffs.heights[cell] <= -5.0:
			sunk += 1
			beyond += 1 if cell.x < 0 else 0
	_check(sunk > 2000 and beyond > sunk / 2, "the sea lies far below the road and runs on past the map's edge: %d sunk, %d beyond" % [sunk, beyond])
	var seas: int = 0
	for cell: Vector2i in view.geometry.water.levels:
		seas += 1 if view.geometry.water.levels[cell] < -4.0 else 0
	_check(seas == sunk, "the sea fills the drop at its foot: %d of %d" % [seas, sunk])
	_check(view.geometry.landmass.sea.size() > 100, "no slab under the open sea, and no cut-away edge toward it: %d patches" % view.geometry.landmass.sea.size())
	_check(view.geometry.terrain_cells.get(Vector2i(648, 360), "") == "path", "the road over the headland: %s" % view.geometry.terrain_cells.get(Vector2i(648, 360), ""))
	for row: Array in [[&"fanfang.cliff_top.north", Vector2.UP], [&"fanfang.cliff_foot.south", Vector2.DOWN]]:
		var arrow: Node3D = view.arrows.get(row[0])
		_check(arrow != null and arrow.get_meta("direction") == row[1], "the exit arrow of %s points out of its room" % row[0])
	_check(await MapPlaces.drive_through(tree, map, [&"fanfang.cliff_path", &"fanfang.cliff_foot"]), "walk down the cliff road to its foot")


## The port: the quay, the jetties and the boats, the derrick and the tax table, the lean-to.
func _check_port(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["jetty", "ferry", "skiff", "mooring_post", "lean_to", "fishing_net", "derrick", "cargo", "steelyard", "cauldron", "hanging_lantern", "torch", "far_peak"]:
		_check(kind in kinds, "the port has its %s" % kind)
	_check(kinds.count("jetty") == 2 and kinds.count("ferry") == 3, "two jetties, three flat-bottomed boats (theme:4: the boats are others')")
	var open: int = 0
	for cell: Vector2i in view.geometry.water.levels:
		open += 1 if cell.y > 1152 else 0
	_check(open > 1000 and view.geometry.landmass.sea.size() > 100, "the sea runs on south under the sky: %d cells past the map" % open)
	_check(view.geometry.terrain_cells.get(Vector2i(616, 904), "") == "bridge", "the west jetty is a way over the water")
	_check(await MapPlaces.drive_through(tree, map, [&"fanfang.shed", &"fanfang.dock"]), "walk to the shed and back")
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"fanfang.dock", Vector2(616, 1000), 40.0)), "and out to the west jetty's head")


## The bazaar: the four stalls, flat roofs and tiled ones, the 拜火祠's smoke, the shields.
func _check_bazaar(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["stall", "cloth_bolts", "whetstone", "great_shield", "rug", "laundry_line", "hanging_lantern", "torch", "notices", "cart"]:
		_check(kind in kinds, "the bazaar has its %s" % kind)
	_check(not "closed_door" in kinds, "番坊 B: 铁盾会's gate and the 拜火祠's door are no longer shut pictures but ways in")
	var doors: int = 0
	for building: Dictionary in view.layout.get("buildings", []):
		doors += (building.get("portals", []) as Array).size()
	_check(doors == 3, "three buildings open onto the street: the 市舶司, 铁盾会 and the 拜火祠: %d" % doors)
	var goods: Array[String] = []
	for look: Dictionary in _looks(map):
		if look["kind"] == "stall":
			goods.append(String(look.get("goods", "")))
	goods.sort()
	_check(goods == ["cloth", "copper", "glass", "spice"], "four stalls: carpets, copper, glass, spice: %s" % [goods])
	_check(kinds.count("great_shield") == 2, "a great shield either side of 铁盾会's gate")
	var flat: int = 0
	var tiled: int = 0
	var smoking: int = 0
	var black: bool = false
	for building: Dictionary in view.layout.get("buildings", []):
		flat += 1 if building.get("roof_form", "") == "terrace" else 0
		tiled += 1 if building.get("roof_tiles", "") == "tile" else 0
		smoking += 1 if building.get("smoke", false) else 0
		black = black or (String(building.get("note", "")).begins_with("拜火祠") and Color(String(building.get("wall", "ffffff"))).v < 0.25)
	_check(flat >= 4 and tiled >= 3 and smoking >= 2 and black, "flat-roofed 胡商 houses and tiled ones, the black 拜火祠 and the forge smoking")
	_check(view.geometry.ambience._puffs.size() >= 2 or view.geometry.ambience._motes.size() >= 10, "spice dust and smoke on the air")
	_check(await MapPlaces.drive_through(tree, map, [&"fanfang.bazaar_east", &"fanfang.bazaar_north"]), "walk along the street and up the lane to the gate")
	_check(await MapPlaces.drive_through(tree, map, [&"fanfang.bazaar_east", &"fanfang.bazaar_slope"]), "and down the slope towards 日陀罗寺")


## The 市舶司: the desk, the notices, the seized goods, the yard's crates and cart.
func _check_customs(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["table", "chest_stack", "sacks", "side_table", "bench_seat", "notices", "candlestick", "wall_lamp", "cloth_bolts", "cargo", "cart", "iron_chain", "loot_crates", "window"]:
		_check(kind in kinds, "the 市舶司 has its %s" % kind)
	var styles: Array[String] = []
	for look: Dictionary in view.layout.get("wall_looks", []):
		styles.append(String(look.get("style", "")))
	_check(styles.slice(0, 2) == ["plaster", "brick"], "the office plastered, the yard grey brick: %s" % [styles])
	_check(await MapPlaces.drive_through(tree, map, [&"fanfang.yard", &"fanfang.office"]), "walk into the yard and back")
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"fanfang.office.papers")), "and up to the desk")


## 铁盾会: the sanded yard open to the sky, the shield racks, the hacked posts, the carpet in the hut.
func _check_shield_hall(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["shield_rack", "training_post", "weapon_rack", "water_vat", "bench", "sandbags", "tea_table", "bedding", "great_shield", "chest_stack", "rug", "torch", "banner", "candlestick", "notices", "window", "trail"]:
		_check(kind in kinds, "铁盾会 has its %s" % kind)
	_check(kinds.count("shield_rack") == 2 and kinds.count("training_post") == 3, "two shield racks, three posts")
	_check(view.layout.get("courtyard", false) and (view.layout.get("light", {}) as Dictionary).has("areas"), "the yard lies open to the sky")
	_check(await MapPlaces.drive_through(tree, map, [&"fanfang.hall", &"fanfang.shield_yard"]), "walk into the 会首's hut and back")


## The 拜火祠: the altar and its fire, the shaft of day, the white kneeling-place; the priest's bare cell.
func _check_fire_temple(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["fire_altar", "light_shaft", "glow", "water_vat", "stone_seat", "wine_jars", "bed", "travel_chest", "lamp_stand", "wall_lamp", "plaques", "paper_charms"]:
		_check(kind in kinds, "the 拜火祠 has its %s" % kind)
	_check(kinds.count("fire_altar") == 1, "one fire, three hundred years")
	var black: bool = false
	for look: Dictionary in view.layout.get("wall_looks", []):
		black = black or Color(String((look.get("colors", ["ffffff"]) as Array)[0])).v < 0.25
	_check(black, "the hall's walls are black stone")
	_check(view.geometry.find_children("*", "OmniLight3D", true, false).size() >= 2, "the fire lights the hall, the lamp the cell")
	_check(await MapPlaces.drive_through(tree, map, [&"fanfang.priest_room", &"fanfang.fire_hall"]), "walk into the cell and back")
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"fanfang.fire_hall.questions")), "and up to the fire")


## 日陀罗寺: the banyan over the yard, the bell, the Buddha and his butter lamps.
func _check_lama_temple(tree: SceneTree, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["tree", "prayer_cushion", "temple_bell", "water_vat", "stone_seat", "buddha", "altar_table", "crocks", "candles", "hanging_lantern", "banner_cloth", "window", "trail"]:
		_check(kind in kinds, "日陀罗寺 has its %s" % kind)
	var banyan: bool = false
	for look: Dictionary in _looks(map):
		banyan = banyan or (look["kind"] == "tree" and look.get("species", "") == "banyan")
	_check(banyan, "the tree in the yard is a banyan")
	_check(view.layout.get("courtyard", false) and (view.layout.get("ambience", {}) as Dictionary).has("fall"), "the yard open to the sky, leaves coming down")
	_check(await MapPlaces.drive_through(tree, map, [&"fanfang.shrine", &"fanfang.temple_yard"]), "walk into the shrine and back")


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
	_check(GameSaveJsonCodec.encode(Work.capture(session)).text == saved, "%s: light, view side, wind, dust and smoke leave the save and RNG unchanged" % map.map_id())
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
