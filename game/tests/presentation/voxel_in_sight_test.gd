extends RefCounted

## What the player must see where they act (owner, 2026-11-11): the 官府悬赏's board was hidden
## under 雪亭驿's porch roof, a lantern over 丰登当铺's counter covered the head of whoever stood
## there to trade, and the quest's red arrow stood in the middle of the 山涧's stream.
const Work = preload("res://tests/runtime/snow_work_income_test.gd")
const Still = preload("res://tests/runtime/snow_south_road_test.gd")
## How far a building's porch roof reaches out from its front (VoxelArchitecture: 1.3 units),
## with a little to spare.
const PORCH_REACH: float = 45.0
## Things put up to be read or used at a service, which no roof may hide.
const SIGNS: Array[String] = ["board"]
var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	_test_boards_clear_of_roofs()
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	await _test_lantern_over_the_counter(tree, session)
	await _test_camera_on_pixels(tree, session)
	await _test_arrow_over_the_cliff(tree, session)
	session.queue_free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


## Every board on every map stands clear of every building's roof and porch.
func _test_boards_clear_of_roofs() -> void:
	var boards: int = 0
	var hidden: Array[String] = []
	for def: MapDefinition in GameContent.catalog().maps():
		var id: String = String(def.map_id)
		var config: String = "res://data/%s/voxel/%s.json" % [id.get_slice(".", 0), id.substr(id.find(".") + 1)]
		if not FileAccess.file_exists(config):
			continue
		var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string(config))
		var buildings: Array = (layout as Dictionary).get("buildings", []) if layout is Dictionary else []
		if buildings.is_empty():
			continue
		var scene: Node = (load(def.scene_path) as PackedScene).instantiate()
		var furnishings: Node = scene.get_node_or_null("Furnishings")
		for node: Node in ([] if furnishings == null else furnishings.get_children()):
			if not (node is Node2D and node.has_meta("look")):
				continue
			var look: Dictionary = VoxelMapGeometry.furnishing(node as Node2D)
			if not SIGNS.has(String(look.get("kind", ""))):
				continue
			boards += 1
			var at := Vector2(float(look["at"][0]), float(look["at"][1]))
			var footprint: Vector2 = node.get_meta("footprint")
			var box := Rect2(at - footprint / 2.0, footprint)
			for building: Dictionary in buildings:
				if not building.has("rect"):
					continue
				var r: Array = building["rect"]
				var roof := Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1])).grow(PORCH_REACH)
				if roof.intersects(box):
					hidden.append("%s: the %s at %s under %s" % [id, look["kind"], at, building.get("note", r)])
		scene.free()
	_check(boards > 1, "boards are found on the maps: %d" % boards)
	_check(hidden.is_empty(), "no board stands under a roof or porch: %s" % [hidden])


## 丰登当铺: the lantern over the counter opens over the player like any occluder.
func _test_lantern_over_the_counter(tree: SceneTree, session: WorldSessionController) -> void:
	var def: MapDefinition = GameContent.catalog().map(&"snow.hockshop_house")
	var map: WorldMapController = MapPlaces.enter(session, &"snow.hockshop", def.entry_spawn_id)
	_check(map != null, "enter 丰登当铺")
	if map == null:
		return
	var view := map.get_node("MapView") as WorldVoxelView
	await _built(tree, view)
	var lantern: Vector3 = VoxelMapGeometry.point(Vector2(-192, 16))
	var found: bool = false
	for occluder: Dictionary in view.geometry.occluders:
		var node: Node3D = occluder["node"]
		if Vector2(node.position.x, node.position.z).distance_to(Vector2(lantern.x, lantern.z)) < 0.05:
			found = true
	_check(found, "the lantern over the counter is one of the room's occluders")
	_check(VoxelMapGeometry.OVERHEAD_KINDS.has("hanging_lantern"), "as every hanging lantern is")


## The camera stands on the picture's pixel grid however far it has eased (owner, 2026-11-12: the
## forest path shimmered while the camera followed): moved by part of a pixel, everything small
## is drawn a little differently; by whole pixels the picture only shifts.
func _test_camera_on_pixels(tree: SceneTree, session: WorldSessionController) -> void:
	var map := session.active_map() as WorldMapController
	var view := map.get_node("MapView") as WorldVoxelView
	# A picture 720 pixels high (headless draws none: the camera is left as it is there).
	var lines: float = view.picture_lines() if view.picture_lines() > 0.0 else 720.0
	var pixel: float = view.camera.size / lines
	var right: Vector3 = view.camera.basis.x.normalized()
	var up: Vector3 = view.camera.basis.y.normalized()
	var on_grid := func(at: Vector3) -> bool:
		var across: float = at.dot(right) / pixel
		var rise: float = at.dot(up) / pixel
		return absf(across - roundf(across)) < 0.01 and absf(rise - roundf(rise)) < 0.01
	var start: Vector3 = view.camera.position
	var every: bool = true
	for share: float in [0.0, 0.37, 0.5, 1.73, 12.2]:
		var wanted: Vector3 = start + right * (pixel * share) + up * (pixel * share * 0.6)
		var at: Vector3 = view.on_pixels(wanted, lines)
		every = every and on_grid.call(at) and at.distance_to(wanted) <= pixel * 0.75 and view.on_pixels(at, lines).is_equal_approx(at)
	_check(every, "any place of the camera goes to the nearest pixel's (pixel %.4f)" % pixel)
	map.player_body.global_position += Vector2(5.3, 2.9)
	for i: int in 3:
		await tree.process_frame
	_check(view.picture_lines() == 0.0 or on_grid.call(view.camera.position), "and while it follows the player it stands on one: %s" % view.camera.position)


## The 山涧 (老松林's gorge): the way on toward 雪亭镇 is up the cliff, so the arrow stands over
## the cliff to climb, on ground, not over the stream in the room's middle.
func _test_arrow_over_the_cliff(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = MapPlaces.enter(session, &"oldpine.gorge.river", &"oldpine.gorge.river.riverbank1_cliff_landing")
	_check(map != null, "enter the 山涧")
	if map == null:
		return
	var view := map.get_node("MapView") as WorldVoxelView
	await _built(tree, view)
	var state: CharacterState = session.player_runtime().state
	MapAtlas.point_to(state, &"snow.inn", &"snow.inn.main_floor")
	# A 指路 keeps to roads walked: every map is known.
	for each: MapDefinition in GameContent.catalog().maps():
		state.visited_maps[String(each.map_id)] = 1
	view._quest_key = ""
	view._sync_quest_marker()
	await tree.process_frame
	_check(view.quest_marker != null, "the arrow is up")
	if view.quest_marker == null:
		return
	_check(view.quest_marker.get_meta("way", &"") == &"oldpine.gorge.riverbank1_climb_cliff", "toward the cliff: %s" % view.quest_marker.get_meta("way", &""))
	var cliff: Area2D = map.landmark_areas.get(&"oldpine.gorge.landmark.riverbank1_cliff")
	var over: Vector3 = view.quest_marker.position
	var middle: Vector2 = VoxelGlints._middle(cliff) if cliff != null else Vector2.INF
	_check(cliff != null and Vector2(over.x, over.z).distance_to(Vector2(middle.x, middle.y) / VoxelMapGeometry.UNIT) < 0.05, "over the cliff to climb: %s, %s" % [over, middle])
	var river: WorldPhysicalZoneArea2D = map.physical_zone(&"oldpine.gorge.river")
	var centre: Vector2 = river.global_rect().get_center()
	var ground: Vector2 = WorldVoxelView.quest_ground(map, river.global_rect())
	_check(not map.static_nodes().walkable_tile(centre) and map.static_nodes().walkable_tile(ground), "a room whose middle is the stream marks the ground nearest it: %s -> %s" % [centre, ground])
	MapAtlas.point_to(state, &"")


func _built(tree: SceneTree, view: WorldVoxelView) -> void:
	var waited: int = 0
	while not view._built and waited < 2000:
		await tree.process_frame
		waited += 1


func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.process_frame


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
