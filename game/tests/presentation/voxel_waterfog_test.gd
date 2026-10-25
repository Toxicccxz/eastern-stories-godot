extends RefCounted

## 水烟阁 in the fixed-angle voxel view: the 青石官道 from 雪亭镇 under the maples, the white stone
## stairs and their railings, the white pavilion on the cliff, the platform before 水烟阁 on its
## peak, the hall's three sandalwood gateways, the main hall, the side halls, the kitchen and the
## servants' rooms, 聆啸厅 and its terrace upstairs, the west path along the gorge to 葬剑亭. The 2D
## maps still decide every way through: the walk comes west from 雪亭镇, climbs the five flights to
## the platform, goes in and up the white stone stairs to 聆啸厅 and across to the east side hall,
## comes down and out again and takes the west path to 葬剑亭. Every stretch of the way can be
## walked round a body standing in it without touching it (the ways are sized for the voxel view).
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
## Decor tall enough to walk into: in a voxel config it must stand on blocking ground (rock, the
## forest, a wall, a blocked box) or be raised clear of the floor (`elevation`).
const TALL: Array[String] = ["lantern", "stone_lantern", "standing_rock", "boulder", "banner", "tree", "great_tree", "pavilion",
	"rockery", "stele", "censer", "flagpole", "water_vat", "strange_stone", "stuck_swords", "boundary_stone", "torch", "bush"]
const SCENES: Array[String] = ["waterfog_mountain", "waterfog_pavilion", "waterfog_upstairs"]
const MAPS: Array[StringName] = [&"waterfog.mountain", &"waterfog.pavilion", &"waterfog.upstairs"]
## The climb from the road to the platform, and the west path to 葬剑亭.
const CLIMB: Array[StringName] = [&"waterfog.sroad1", &"waterfog.sroad2", &"waterfog.sroad3", &"waterfog.stair1", &"waterfog.stair2",
	&"waterfog.stair3", &"waterfog.stair4", &"waterfog.clifftop", &"waterfog.stair5", &"waterfog.frontyard"]
const WEST: Array[StringName] = [&"waterfog.frontyard", &"waterfog.wpath1", &"waterfog.wpath2", &"waterfog.wpath3", &"waterfog.wpath4",
	&"waterfog.wpath5", &"waterfog.swordtomb"]
var assertions: int = 0
var failures: Array[String] = []
var _seen: Dictionary[StringName, bool] = {}


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	for scene: String in SCENES:
		furnishings._check_furnishings(load("res://scenes/world/waterfog/%s.tscn" % scene) as PackedScene, scene)
	assertions += furnishings.assertions
	failures.append_array(furnishings.failures)
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	_check_snow_seam()
	var snow := MapPlaces.enter(session, &"snow.sroad5", &"snow.sroad5.waterfog_return")
	_check(snow != null, "on 雪亭镇's sroad5")
	if snow != null:
		await _frames(tree, 4)
		_check(await MapPlaces.take_passage(tree, snow, &"snow.sroad5.west"), "west out of 雪亭镇 onto the 青石官道")
		await _frames(tree, 6)
		var mountain := session.active_map() as WorldMapController
		_check(mountain != null and mountain.map_id() == &"waterfog.mountain", "on 水烟阁's mountain")
		if mountain != null and mountain.map_id() == &"waterfog.mountain":
			await _check_mountain(tree, session, mountain)
			await _walk(tree, session, mountain)
	var missing: Array[StringName] = []
	for map_id: StringName in MAPS:
		if not _seen.has(map_id):
			missing.append(map_id)
	_check(missing.is_empty(), "every map of 水烟阁 was seen in the voxel view: missing %s" % [missing])
	session.free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


## 雪亭镇's side of the seam: its 官道 runs on west past the way out, maples begin by it.
func _check_snow_seam() -> void:
	var snow: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/snow/voxel/outdoor.json"))
	_check(snow.get("exit_trails", {}).has("snow.sroad5.west"), "雪亭镇's sroad5 runs on west toward 水烟阁 past its way out")
	var maples: bool = false
	for area: Dictionary in snow.get("flora", {}).get("areas", []):
		var r: Array = area["rect"]
		maples = maples or Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]).has_point(Vector2(-1712, 416)) and "maple" in area.get("tree_types", [])
	_check(maples, "雪亭镇's west end has the first maples of 水烟阁's slopes")


func _check_mountain(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	await _check_map(tree, session, map, "水烟阁's mountain")
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["stair_flight", "balustrade", "pavilion_post", "pavilion_roof", "stele", "censer", "stone_lantern", "gateway",
			"boundary_stone", "cloud_sea", "far_peak", "stuck_swords", "flagpole", "tree"]:
		_check(kind in kinds, "the mountain has its %s" % kind)
	var steles: int = 0
	var turtle: bool = false
	for node: Node in map.get_node("Furnishings").get_children():
		var look: Dictionary = node.get_meta("look")
		if look["kind"] == "stele":
			steles += 1
			turtle = turtle or look.get("turtle", false)
	_check(steles == 2 and turtle, "虹谷's tablet by the path and 葬剑亭's monolith on its tortoise (wpath2.c, swordtomb.c)")
	var hall: Dictionary = view.layout.get("buildings", [{}])[0]
	_check(String(hall.get("roof", "")).ends_with(":gloss") and String((hall.get("signboard", {}) as Dictionary).get("text", "")) == "水烟阁",
		"水烟阁 under its glazed roof, its name over the gate (frontyard.c: 琉璃色的屋瓦)")
	var terrace: bool = false
	for mass: Dictionary in hall.get("masses", []):
		terrace = terrace or mass.get("roof_form", "") == "terrace" and int(mass.get("rocks", 0)) == 5
	_check(terrace, "聆啸厅's terrace over the gate with its five grey-green stones (forehall.c)")
	var maples: int = 0
	for prop: Dictionary in view.layout.get("props", []):
		if prop["kind"] == "tree" and prop.get("species", "") == "maple":
			maples += 1
	_check(maples >= 5 and "maple" in view.layout.get("flora", {}).get("tree_types", []), "the maple woods (sroad1.c) and wpath1's row of maples")
	_check(view.geometry.cliffs != null and view.geometry.cliffs.holes().size() > 300, "水烟阁 stands on its peak, deep chasms round it (eaststair.c: 孤立于独峰之上)")
	_check(not view.geometry.cliffs.config.get("lifts", []).is_empty() and float(view.geometry.cliffs.config.get("south_rise", 1.0)) > 1.0,
		"rock south of the ways rises slowly: the ways stay in view")
	var ambience: VoxelAmbience = view.geometry.ambience
	_check(ambience._falling.size() > 60, "maple leaves drift down")
	_check(ambience._drifting.size() >= 4, "mist drifts in the gorge and round the peak")
	_check(ambience._birds.size() >= 8, "hawks over the gorge, swallows round the eaves")
	_check(ambience._swaying.size() >= 8, "wind bells stir under the eaves")
	_check(ambience._puffs.size() >= 6, "incense smoke from the censer, smoke from the kitchen")
	_check(view.lighting.flickering.size() >= 10, "stone lanterns light the climb at night")
	_check(view.lighting.carried != null, "a soft light goes with the player at night")
	var gate: Node3D = view.arrows.get(&"waterfog.frontyard.north")
	_check(gate != null and gate.get_meta("direction") == Vector2.UP, "the arrow at the gate points in, north")
	var button := session.shared_ui().find_child("ViewSide", true, false) as VoxelViewSideButton
	for left: bool in [true, false]:
		_click(tree, button)
		await tree.create_timer(WorldVoxelView.VIEW_ROTATION_SECONDS + 0.05).timeout
		_check(map.place_player(&"waterfog.frontyard", Vector2(944, 800)), "onto the platform's white stone")
		await _frames(tree, 2)
		var start: Vector2 = map.player_body.global_position
		Input.action_press("move_right")
		await _frames(tree, 8)
		MapPlaces.release()
		var moved: Vector2 = map.view_ground.basis_xform(map.player_body.global_position - start)
		_check(view.left_view == left and moved.x > 4 and absf(moved.y) < 2, "D walks screen-right on the platform from the %s side" % ("left" if left else "right"))
	_check(map.place_player(&"waterfog.sroad1", Vector2(1712, 2064)), "back at the road's east end")
	await _frames(tree, 2)


## Up the five flights to the platform; in, up the white stone stairs to 聆啸厅 and across to
## the east side hall; down and out; the west path to 葬剑亭. Every stretch can be walked round a
## body standing in it.
func _walk(tree: SceneTree, session: WorldSessionController, mountain: WorldMapController) -> void:
	_check_passing(mountain, CLIMB)
	_check_passing(mountain, WEST)
	for zone: StringName in CLIMB.slice(1):
		_check(await MapPlaces.drive_to_zone(tree, mountain, zone), "walk up into " + String(zone))
	for zone: StringName in [&"waterfog.entrance", &"waterfog.westhall", &"waterfog.weststair", &"waterfog.west_2f", &"waterfog.forehall", &"waterfog.east_2f"]:
		var there: WorldMapController = await MapPlaces.go_to(tree, session, zone)
		_check(there != null and there.projected_view, "on foot to %s, in its voxel view" % zone)
		if there == null:
			return
		if not _seen.has(there.map_id()):
			await _check_map(tree, session, there, String(zone))
			_check_interior(there)
		if zone == &"waterfog.weststair":
			_check_passing(there, [&"waterfog.entrance", &"waterfog.westhall", &"waterfog.weststair", &"waterfog.storage", &"waterfog.servroom"])
			_check_passing(there, [&"waterfog.entrance", &"waterfog.easthall", &"waterfog.eaststair", &"waterfog.kitchen"])
			_check_passing(there, [&"waterfog.entrance", &"waterfog.guildhall"])
		if zone == &"waterfog.east_2f":
			_check_passing(there, [&"waterfog.west_2f", &"waterfog.forehall", &"waterfog.east_2f"])
	var back: WorldMapController = await MapPlaces.go_to(tree, session, &"waterfog.frontyard")
	_check(back != null and back.map_id() == &"waterfog.mountain", "down the east stairs and out of the gate")
	if back == null:
		return
	for zone: StringName in WEST.slice(1):
		_check(await MapPlaces.drive_to_zone(tree, back, zone), "the west path into " + String(zone))


## What the hall shows inside: the three gateways and the board too wild to read, the black
## chair, the long bed and the kang, the camellias beyond the railings; upstairs the five stones,
## the drops into the tall side halls and the shut door to 春秋水色斋.
func _check_interior(map: WorldMapController) -> void:
	var kinds: Array[String] = _kinds(_view_of(map))
	if map.map_id() == &"waterfog.pavilion":
		var gates: int = 0
		var scrawl: bool = false
		for node: Node in map.get_node("Furnishings").get_children():
			var look: Dictionary = node.get_meta("look")
			if look["kind"] == "gate_frame":
				gates += 1
				scrawl = scrawl or (look.get("plaque", {}) as Dictionary).get("scrawl", false)
		_check(gates == 6 and scrawl, "正门共分三进, its innermost board 龙飞凤舞 (entrance.c)")
		for kind: String in ["grand_chair", "long_bed", "kang", "camellia_bed", "balustrade", "firewood", "cauldron", "sign", "stairs", "column"]:
			_check(kind in kinds, "the ground floor has its %s" % kind)
	else:
		_check(kinds.count("strange_stone") == 5, "聆啸厅's five grey-green stones (forehall.c)")
		for kind: String in ["drop", "balustrade", "closed_door", "column", "stairwell"]:
			_check(kind in kinds, "the upper floor has its %s" % kind)


## Each stretch of the way between neighbouring rooms, with a body standing anywhere on it, can
## still be walked round, never touching it (a 5-cell square about the body is solid).
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
			# Its posts stand at the ends of its width; the way runs on under its beam.
			var half: float = float(prop["size"][0]) / 2.0 - 6.4
			for x: float in [-half, half]:
				if not TerrainProbe.blocks_at(map, at + Vector2(x, 0)):
					loose.append("gateway post %s" % (at + Vector2(x, 0)))
			continue
		if not kind in TALL or float(prop.get("elevation", 0.0)) >= 0.9:
			continue
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
				solid = solid and (rock or TerrainProbe.blocks_at(map, cell))
		if not solid:
			loose.append("%s %s" % [kind, prop["at"]])
	_check(loose.is_empty(), "tall decor in %s stands on blocking ground: %s" % [place, loose])


## On the 2D map the voxel view never changes: every room has a way to it from where the
## player stands, every NPC a spot within interaction reach on that way, and day, night, the view
## side and the animations leave the save (and gameplay RNG) as they were.
func _check_access_and_saves(tree: SceneTree, session: WorldSessionController, map: WorldMapController, view: WorldVoxelView) -> void:
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
		if body == null or not npc.exists_in_map:
			continue
		var reach: float = WorldMapSelection.NEARBY_REACH
		var at: Vector2 = MapPlaces.spot(map, npc.world_location().zone_id, body.global_position, reach)
		if not at.is_finite() or at.distance_to(body.global_position) > reach or MapRoute.path(map, start, at).is_empty():
			out_of_reach.append(String(npc.spawn_point_id))
	_check(out_of_reach.is_empty(), "every NPC of %s can be walked up to within reach: %s" % [map.map_id(), out_of_reach])
	session.set_process(false)
	var saved: String = GameSaveJsonCodec.encode(Work.capture(session)).text
	for left: bool in [true, false]:
		view.set_view_side(left, true)
		for night: bool in [true, false]:
			view.set_night(night, true)
			view._process(0.1)
	_check(GameSaveJsonCodec.encode(Work.capture(session)).text == saved, "%s: light, view side, mist, leaves and bells leave the save and RNG unchanged" % map.map_id())
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
