extends RefCounted

## 卧龙岗 and 绮云镇 in the fixed-angle voxel view: the road over the ridge, the town gate, the
## markets and the crossroad's 古槐, the shops and houses, 香茗坊 and its upper floor, the tea
## field, 张家花园 and the ferry landing on 泓水. The 2D maps still decide every way through: the
## walk comes down from 雪亭镇 over the ridge, through the markets to the crossroad, up into the tea
## house and down again, into the escort agency and the gaming house, and on to the landing and
## the garden, past the furniture the layout added.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
const Flyer := preload("res://presentation/voxel/actors/voxel_flyer.gd")
const CALMED: Array[StringName] = [&"cloud.npc.gangster", &"cloud.npc.thief", &"snow.npc.crazy_dog"]
## Decor tall enough to walk into: in a voxel config it must stand on blocking ground (the town's
## boundary, a wall, rock, water, a blocked box) or be raised clear of the floor (`elevation`).
const TALL: Array[String] = ["lantern", "standing_rock", "boulder", "boundary_stone", "water_vat", "firewood", "drying_rack",
	"cart", "flagpole", "fishing_net", "tea_stall", "banner", "tree", "great_tree", "pavilion", "rockery", "stall", "bench",
	"cargo", "training_post", "wine_jars", "notice_post", "well", "screen_wall", "torch"]
const SCENES: Array[String] = ["cloud_outdoor", "cloud_tearoom_upstairs", "cloud_jiyuan_upstairs", "cloud_duchang_upstairs", "biaoju_house",
	"bookstore_house", "butchery_house", "drugstore_house", "duchang_house", "yard_house", "jiyuan_house", "rich_house", "marry_house",
	"monky_house", "tailory_house", "tearoom_house", "weapony_house", "zaihuoy_house"]
const MAPS: Array[StringName] = [&"cloud.outdoor", &"cloud.tearoom_upstairs", &"cloud.jiyuan_upstairs", &"cloud.duchang_upstairs",
	&"cloud.biaoju_house", &"cloud.bookstore_house", &"cloud.butchery_house", &"cloud.drugstore_house", &"cloud.duchang_house",
	&"cloud.yard_house", &"cloud.jiyuan_house", &"cloud.rich_house", &"cloud.marry_house", &"cloud.monky_house", &"cloud.tailory_house",
	&"cloud.tearoom_house", &"cloud.weapony_house", &"cloud.zaihuoy_house"]
## The rooms the walk does not pass through, each entered at its own way in.
const OTHERS: Array[StringName] = [&"cloud.bookstore", &"cloud.butchery", &"cloud.drugstore", &"cloud.woodboxy", &"cloud.jiyuan", &"cloud.jiyuan2",
	&"cloud.duchang2", &"cloud.rich", &"cloud.marry_room", &"cloud.monky", &"cloud.tailory", &"cloud.weapony", &"cloud.zaihuoy"]
var assertions: int = 0
var failures: Array[String] = []
var _seen: Dictionary[StringName, bool] = {}


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	for scene: String in SCENES:
		furnishings._check_furnishings(load("res://scenes/world/cloud/%s.tscn" % scene) as PackedScene, scene)
	assertions += furnishings.assertions
	failures.append_array(furnishings.failures)
	# TEST-ONLY: the ridge's robbers and the garden's thief leave the walker alone (cloud_test meets them).
	var kept: Dictionary = {}
	for id: StringName in CALMED:
		var npc: NpcDefinition = GameContent.catalog().npc(id)
		kept[id] = [npc.attitude, npc._capability_ids.duplicate()]
		npc.attitude = NpcDefinition.Attitude.PEACEFUL
		npc._capability_ids.clear()
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	_check_snow_seam()
	var snow := MapPlaces.enter(session, &"snow.sroad1", &"snow.sroad1.cloud_return")
	_check(snow != null, "on 雪亭镇's south road")
	if snow != null:
		await _frames(tree, 4)
		_check(await MapPlaces.take_passage(tree, snow, &"snow.sroad1.south"), "south out of 雪亭镇 toward 卧龙岗")
		await _frames(tree, 6)
		var outdoor := session.active_map() as WorldMapController
		_check(outdoor != null and outdoor.map_id() == &"cloud.outdoor", "on the 黄土路 below 卧龙岗")
		if outdoor != null and outdoor.map_id() == &"cloud.outdoor":
			await _check_town(tree, session, outdoor)
			await _walk_the_town(tree, session)
	for zone: StringName in OTHERS:
		await _check_room(tree, session, zone)
	var missing: Array[StringName] = []
	for map_id: StringName in MAPS:
		if not _seen.has(map_id):
			missing.append(map_id)
	_check(missing.is_empty(), "every map of 卧龙岗 and 绮云镇 was seen in the voxel view: missing %s" % [missing])
	for id: StringName in CALMED:
		var npc: NpcDefinition = GameContent.catalog().npc(id)
		npc.attitude = kept[id][0]
		npc._capability_ids.assign(kept[id][1])
	session.free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


## 雪亭镇's side of the seam: its road runs on south past the way out, the trees change.
func _check_snow_seam() -> void:
	var snow: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/snow/voxel/outdoor.json"))
	_check(snow.get("exit_trails", {}).has("snow.sroad1.south"), "雪亭镇's south road runs on toward 卧龙岗 past its way out")
	var toward_ridge: bool = false
	for area: Dictionary in snow.get("flora", {}).get("areas", []):
		var r: Array = area["rect"]
		toward_ridge = toward_ridge or Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]).has_point(Vector2(0, 864))
	_check(toward_ridge, "雪亭镇's trees turn toward 卧龙岗's woods at its south end")


func _check_town(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	await _check_map(tree, session, map, "卧龙岗 and 绮云镇")
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["great_tree", "notice_post", "gateway", "boundary_stone", "stall", "tea_stall", "tea_bushes", "tea_basket", "drying_rack",
			"water_vat", "firewood", "carry_pole", "lantern_string", "cart", "flagpole", "stone_lion", "pavilion", "rockery", "lotus",
			"moon_gate", "stone_table", "jetty", "ferry", "skiff", "bank_stones", "mooring_post", "fishing_net", "far_shore", "reeds", "bench", "cargo"]:
		_check(kind in kinds, "the town has its %s" % kind)
	var signs: Array[String] = []
	var two_storeys: int = 0
	for building: Dictionary in view.layout.get("buildings", []):
		if building.has("signboard"):
			signs.append(String((building["signboard"] as Dictionary).get("text", "")))
		two_storeys += 1 if building.has("skirt") else 0
	for text: String in ["香茗坊", "振远镖局", "赌", "怡红院", "张府", "红娘庄", "斋院", "药", "棺", "布庄", "兵器", "杂货", "书局"]:
		_check(text in signs, "a shop front shows its board: %s" % text)
	_check(two_storeys >= 2, "香茗坊 and 怡红院 stand two storeys over the street (nwroad1.c, nroad2.c)")
	var tea_house: Dictionary = {}
	for building: Dictionary in view.layout.get("buildings", []):
		if "cloud.nwroad1.east" in building.get("portals", []):
			tea_house = building
	_check(String((tea_house.get("signboard", {}) as Dictionary).get("letters", "")).ends_with(":glow"), "香茗坊's gilt board shines (金字招牌十分晃眼)")
	var water: VoxelWater = view.geometry.water
	_check(water.levels.size() > 2000, "泓水 runs wide past the landing: %d cells" % water.levels.size())
	var swell: bool = false
	for look: Dictionary in water.looks.values():
		swell = swell or float(look.get("swell", 0.0)) > 0.0
	_check(swell, "泓水 is never still (无风亦起浪)")
	var ambience: VoxelAmbience = view.geometry.ambience
	_check(ambience._floating.size() >= 3, "the ferry and the skiffs ride the swell")
	_check(ambience._puffs.size() > 10, "smoke rises from the kitchens and from the far hills")
	_check(ambience._flags.size() >= 3, "flags and banners stir")
	_check(ambience._birds.size() >= 6, "birds over the ridge, the river and the market")
	_check(view.lighting.flickering.size() > 5, "lamp flames waver at night")
	_check(view.geometry.cliffs != null and view.geometry.cliffs.heights.size() > 300, "卧龙岗's ridge rises in rock either side of the road")
	var arrow: Node3D = view.arrows.get(&"cloud.dragonhill.nroad.north")
	_check(arrow != null and arrow.get_meta("direction") == Vector2.UP, "the arrow at the ridge's north end points back to 雪亭镇")
	var button := session.shared_ui().find_child("ViewSide", true, false) as VoxelViewSideButton
	for left: bool in [true, false]:
		_click(tree, button)
		await tree.create_timer(WorldVoxelView.VIEW_ROTATION_SECONDS + 0.05).timeout
		_check(map.place_player(&"cloud.cross", Vector2(1760, 2400)), "onto the crossroad's open flags")
		await _frames(tree, 2)
		var start: Vector2 = map.player_body.global_position
		Input.action_press("move_right")
		await _frames(tree, 8)
		MapPlaces.release()
		var moved: Vector2 = map.view_ground.basis_xform(map.player_body.global_position - start)
		_check(view.left_view == left and moved.x > 4 and absf(moved.y) < 2, "D walks screen-right at the crossroad from the %s side" % ("left" if left else "right"))
	_check(map.place_player(&"cloud.dragonhill.nroad", Vector2(1040, 160)), "back up on the 黄土路")
	await _frames(tree, 2)


## Over 卧龙岗 into town, through the markets to the crossroad; up into 香茗坊's upper floor and
## down; into 振远镖局 and the gaming house; on to the ferry landing and 张家花园.
func _walk_the_town(tree: SceneTree, session: WorldSessionController) -> void:
	var map := session.active_map() as WorldMapController
	var road: Array[StringName] = [&"cloud.dragonhill.nhillfoot", &"cloud.dragonhill.hummock", &"cloud.dragonhill.shillfoot", &"cloud.entrance",
		&"cloud.nwroad1", &"cloud.nwroad2", &"cloud.nwroad3", &"cloud.nroad1", &"cloud.nroad2", &"cloud.cross"]
	for zone: StringName in road:
		_check(await MapPlaces.drive_to_zone(tree, map, zone), "walk into " + String(zone))
	for zone: StringName in [&"cloud.tearoom", &"cloud.tearoom2", &"cloud.biaoju", &"cloud.duchang", &"cloud.dukou", &"cloud.park"]:
		var there: WorldMapController = await MapPlaces.go_to(tree, session, zone)
		_check(there != null and there.projected_view, "on foot to %s, in its voxel view" % zone)
		if there == null:
			return
		if not _seen.has(there.map_id()):
			await _check_map(tree, session, there, String(zone))
		if zone == &"cloud.tearoom":
			var view: WorldVoxelView = _view_of(there)
			_check(view.shutters.has(&"cloud.tearoom.door") and view.arrows.has(&"cloud.tearoom.door"), "the 木雕门 to the tea store has its leaf and arrow")
			_check("tea_baskets" in _kinds(view) and "tea_stove" in _kinds(view), "tea in great baskets behind the door, water on the boil in front")
		if zone == &"cloud.duchang":
			_check("gaming_table" in _kinds(_view_of(there)), "the gaming house's tables")


func _check_room(tree: SceneTree, session: WorldSessionController, zone: StringName) -> void:
	var map_id: StringName = MapPlaces.map_of(zone)
	var spawn: StringName = GameContent.catalog().map(map_id).entry_spawn_id
	var map := MapPlaces.enter(session, zone, spawn)
	if map == null:
		# A room whose map is entered in another of its rooms (the coffin shop behind the yard).
		for other: ZoneDefinition in GameContent.catalog().zones_for_map(map_id):
			map = MapPlaces.enter(session, other.zone_id, spawn)
			if map != null:
				break
	await _frames(tree, 4)
	_check(map != null and map.projected_view, "%s is in the voxel view" % zone)
	if map == null:
		return
	if not _seen.has(map.map_id()):
		await _check_map(tree, session, map, String(zone))
	if map.map_id() == &"cloud.butchery_house":
		var flies: int = 0
		for actor: Node3D in _view_of(map).actors.values():
			flies += 1 if actor.get_child(0) is Flyer else 0
		_check(flies == 6, "the butcher's six flies buzz about as flies: %d" % flies)
		_check("meat_rack" in _kinds(_view_of(map)), "肉架上挂满了血淋淋的生肉")
	if map.map_id() == &"cloud.yard_house":
		var kinds: Array[String] = _kinds(_view_of(map))
		_check("pavilion" in kinds and "swing_frame" in kinds and "thorns" in kinds and "coffin" in kinds and "square_table" in kinds,
			"the overgrown yard's falling pavilion and swing, the coffins, the black-and-gold table")


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
		var at := Vector2(float(prop["at"][0]), float(prop["at"][1]))
		if kind == "gateway":
			# Its posts stand at the ends of its width; the road runs on under its beam.
			var half: float = float(prop["size"][0]) / 2.0 - 6.4
			for x: float in [-half, half]:
				if not TerrainProbe.blocks_at(map, at + Vector2(x, 0)):
					loose.append("gateway post %s" % (at + Vector2(x, 0)))
			continue
		if not kind in TALL or float(prop.get("elevation", 0.0)) >= 0.9:
			continue
		var size: Array = prop.get("size", [16, 16])
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
## player stands (through its doors, opened TEST-ONLY for the planning and shut again), every
## NPC a spot within interaction reach on that way, and day, night, the view side and the
## animations leave the save (and gameplay RNG) as they were.
func _check_access_and_saves(tree: SceneTree, session: WorldSessionController, map: WorldMapController, view: WorldVoxelView) -> void:
	var shut: Array[WorldDoor] = []
	for door: WorldDoor in map.doors_by_id.values():
		if not door.is_open():
			door.set_open(true)
			shut.append(door)
	await _frames(tree, 2)
	var start: Vector2 = map.player_body.global_position
	var cut_off: Array[String] = []
	for zone: ZoneDefinition in GameContent.catalog().zones_for_map(map.map_id()):
		var at: Vector2 = MapPlaces.zone_spot(map, zone.zone_id)
		if not at.is_finite() or MapRoute.path(map, start, at).is_empty():
			cut_off.append(String(zone.zone_id))
	_check(cut_off.is_empty(), "every room of %s can be walked to: cut off %s" % [map.map_id(), cut_off])
	var blocked_ways: Array[String] = []
	for node: Node in map.find_children("*", "Area2D", true, false):
		var passage := node as WorldPassageArea2D
		if passage != null and MapRoute.path(map, start, MapPlaces.passage_spot(map, passage.portal_id)).is_empty():
			blocked_ways.append(String(passage.portal_id))
	_check(blocked_ways.is_empty(), "every way out of %s can be walked to past the furniture: %s" % [map.map_id(), blocked_ways])
	var out_of_reach: Array[String] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
		# Flies buzz about the room: they come to the player, not the reverse.
		if body == null or not npc.exists_in_map or npc.definition().definition_id == &"cloud.npc.fly":
			continue
		var reach: float = WorldMapSelection.NEARBY_REACH
		var at: Vector2 = MapPlaces.spot(map, npc.world_location().zone_id, body.global_position, reach)
		if not at.is_finite() or at.distance_to(body.global_position) > reach or MapRoute.path(map, start, at).is_empty():
			out_of_reach.append(String(npc.spawn_point_id))
	_check(out_of_reach.is_empty(), "every NPC of %s can be walked up to within reach: %s" % [map.map_id(), out_of_reach])
	for door: WorldDoor in shut:
		door.set_open(false)
	await _frames(tree, 2)
	session.set_process(false)
	var saved: String = GameSaveJsonCodec.encode(Work.capture(session)).text
	for left: bool in [true, false]:
		view.set_view_side(left, true)
		for night: bool in [true, false]:
			view.set_night(night, true)
			view._process(0.1)
	_check(GameSaveJsonCodec.encode(Work.capture(session)).text == saved, "%s: light, view side, water, boats and smoke leave the save and RNG unchanged" % map.map_id())
	session.set_process(true)


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
