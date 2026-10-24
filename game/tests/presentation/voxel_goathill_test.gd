extends RefCounted

## 野羊山 in the fixed-angle voxel view: the mountain road with its cliffs, the caverns and
## the little 土地庙. The 2D maps still decide every way through: the road is walked from the
## gully to the canyon, the caves end to end, and the temple up to 黄霸, past the blocked
## furniture the layout added (the look-out's fire and plunder, the shrine, altar and burner).
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
const Crawler := preload("res://presentation/voxel/actors/voxel_crawler.gd")
const BANDITS: Array[StringName] = [&"goathill.npc.bandit", &"goathill.npc.bandit_leader"]
var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	# The caverns' things are rock or flat on the floor: no blocked furniture there.
	for scene: String in ["goathill_mountain", "temple_house"]:
		furnishings._check_furnishings(load("res://scenes/world/goathill/%s.tscn" % scene) as PackedScene, scene)
	assertions += furnishings.assertions
	failures.append_array(furnishings.failures)
	# TEST-ONLY: the corner's bandits leave the walker alone (goathill_test fights them).
	var aggressive: Dictionary = {}
	for id: StringName in BANDITS:
		var npc: NpcDefinition = GameContent.catalog().npc(id)
		aggressive[id] = [npc.attitude, npc.has_capability(NpcDefinition.CAPABILITY_AGGRESSIVE_ON_PLAYER_PRESENCE)]
		npc.attitude = NpcDefinition.Attitude.PEACEFUL
		npc._capability_ids.erase(NpcDefinition.CAPABILITY_AGGRESSIVE_ON_PLAYER_PRESENCE)
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	var mountain := MapPlaces.enter(session, &"goathill.mroad1", &"goathill.mroad1.snow_entry")
	_check(mountain != null, "on 野羊山's mroad1")
	await _frames(tree, 4)
	await _check_mountain(tree, session, mountain)
	await _check_caverns(tree, session, mountain)
	await _check_temple(tree, session)
	for id: StringName in BANDITS:
		var npc: NpcDefinition = GameContent.catalog().npc(id)
		npc.attitude = aggressive[id][0]
		if aggressive[id][1]:
			npc._capability_ids.append(NpcDefinition.CAPABILITY_AGGRESSIVE_ON_PLAYER_PRESENCE)
	session.free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


func _check_mountain(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var view := map.get_node("MapView") as WorldVoxelView
	_check(map.projected_view and view.camera.current, "the mountain road uses its voxel view")
	_check(view.geometry.unknown_kinds.is_empty(), "every mountain prop kind is drawn: %s" % [view.geometry.unknown_kinds])
	var cliffs: VoxelCliffs = view.geometry.cliffs
	_check(cliffs != null and cliffs.heights.size() > 500 and cliffs.face_count > 1000, "the cliffs stand as raised rock")
	var occluding: bool = false
	for entry: Dictionary in view.geometry.occluders:
		occluding = occluding or entry["node"] == cliffs.root
	_check(occluding, "the raised rock fades locally around the people behind it")
	var walkable_rock: Array[Vector2i] = []
	for cell: Vector2i in cliffs.heights:
		if cliffs.distances.get(cell, INF) == 0.0:
			walkable_rock.append(cell)
	_check(walkable_rock.is_empty(), "no open cell is raised into rock: %s" % [walkable_rock.slice(0, 4)])
	var land: VoxelLandmass = view.geometry.landmass
	var supported: bool = true
	for node: Node in map.find_children("*", "WorldPhysicalZoneArea2D", true, false):
		var rect: Rect2 = (node as WorldPhysicalZoneArea2D).global_rect()
		for y: int in range(floori(rect.position.y), ceili(rect.end.y), 16):
			for x: int in range(floori(rect.position.x), ceili(rect.end.x), 16):
				supported = supported and land.contains(Vector2(x, y))
	_check(supported, "every room of the road stands on the finite landmass")
	_check(not land.contains(Vector2(1500, 2300)), "rock far from the road is trimmed away: the ridge floats")
	for row: Array in [[&"goathill.mroad1.south", Vector2.DOWN], [&"goathill.mroad3.east", Vector2.RIGHT], [&"goathill.canyon3.east", Vector2.RIGHT]]:
		var arrow: Node3D = view.arrows.get(row[0])
		_check(arrow != null and arrow.get_meta("direction") == row[1], "the exit arrow of %s points out of its room: %s" % [row[0], arrow.get_meta("direction") if arrow != null else null])
	_check(view.geometry.ambience._birds.size() >= 5 and view.geometry.ambience._puffs.size() >= 6, "birds wheel overhead and the look-out's fire smokes")
	var arrow: Node3D = view.arrows[&"goathill.mroad1.south"]
	var heights: Array[float] = []
	for _step: int in range(3):
		heights.append(arrow.position.y)
		await _frames(tree, 12)
	_check(arrow.visible and heights[0] != heights[1] and heights[1] != heights[2], "the arrow by the near exit shows and bobs: %s" % [heights])
	var road: Array[StringName] = [&"goathill.mroad2", &"goathill.mroad3", &"goathill.mroad4", &"goathill.mroad5", &"goathill.slope1", &"goathill.mroad6", &"goathill.canyon1", &"goathill.canyon2", &"goathill.canyon3"]
	for zone: StringName in road:
		_check(await MapPlaces.drive_to_zone(tree, map, zone), "walk the road into " + String(zone))
	# The look-out's things block where the layout says, and leave room to walk round the fire.
	var grid: WorldNpcWalker.Grid = MapRoute.grid(map, [])
	_check(grid._astar.is_point_solid(grid.cell_of(Vector2(1088, 1248))), "the look-out's fire is a blocked box")
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"goathill.slope1", Vector2(1160, 1256), 24.0)), "walk round to the far side of the fire")
	_check(await MapPlaces.drive_to_zone(tree, map, &"goathill.mroad5"), "back along the narrow road")
	var button := session.shared_ui().find_child("ViewSide", true, false) as VoxelViewSideButton
	for left: bool in [true, false]:
		_click(tree, button)
		await tree.create_timer(WorldVoxelView.VIEW_ROTATION_SECONDS + 0.05).timeout
		var start: Vector2 = map.player_body.global_position
		Input.action_press("move_right")
		await _frames(tree, 8)
		MapPlaces.release()
		var moved: Vector2 = map.view_ground.basis_xform(map.player_body.global_position - start)
		_check(view.left_view == left and moved.x > 4 and absf(moved.y) < 2, "D walks screen-right on the mountain from the %s side" % ("left" if left else "right"))
		_check(map.place_player(&"goathill.mroad5", start), "back to the road")
		await _frames(tree, 2)


func _check_caverns(tree: SceneTree, session: WorldSessionController, mountain: WorldMapController) -> void:
	_check(await MapPlaces.drive_to_zone(tree, mountain, &"goathill.canyon3"), "to the cave mouth")
	_check(await MapPlaces.take_passage(tree, mountain, &"goathill.canyon3.east"), "into the caverns by the original portal")
	await _frames(tree, 4)
	var map := session.active_map() as WorldMapController
	var view := map.get_node("MapView") as WorldVoxelView
	_check(map.map_id() == &"goathill.caverns" and map.projected_view and view.camera.current, "the caverns take over the voxel camera")
	_check(view.geometry.unknown_kinds.is_empty(), "every cave prop kind is drawn: %s" % [view.geometry.unknown_kinds])
	_check(view.lighting.carried != null and view.geometry.cliffs != null, "a light goes with the player among the cave walls")
	var leeches: int = 0
	for npc: NpcRuntimeState in map.npc_runtimes():
		var actor: Node3D = view.actors.get(npc.character_id)
		if actor != null and actor.get_child(0) is Crawler:
			leeches += 1
	_check(leeches == 13, "the thirteen rock leeches crawl as leeches: %d" % leeches)
	for zone: StringName in [&"goathill.cavern2", &"goathill.cavern3", &"goathill.cavern2", &"goathill.cavern1", &"goathill.cavern4", &"goathill.cavern1"]:
		_check(await MapPlaces.drive_to_zone(tree, map, zone), "walk the caves into " + String(zone))
	_check(await MapPlaces.take_passage(tree, map, &"goathill.cavern1.west"), "out to the canyon again")
	await _frames(tree, 4)
	_check(session.active_map() == mountain and mountain.projected_view, "the mountain view comes back")


func _check_temple(tree: SceneTree, session: WorldSessionController) -> void:
	var mountain := session.active_map() as WorldMapController
	_check(await MapPlaces.drive_to_zone(tree, mountain, &"goathill.mroad3"), "down the road to the temple's crack")
	_check(await MapPlaces.take_passage(tree, mountain, &"goathill.mroad3.east"), "into the 土地庙 by its door")
	await _frames(tree, 4)
	var map := session.active_map() as WorldMapController
	var view := map.get_node("MapView") as WorldVoxelView
	_check(map.map_id() == &"goathill.temple_house" and map.projected_view, "the temple is a voxel interior")
	_check(view.geometry.unknown_kinds.is_empty(), "every temple prop kind is drawn: %s" % [view.geometry.unknown_kinds])
	var kinds: Array[String] = []
	for node: Node in map.get_node("Furnishings").get_children():
		kinds.append(String((node.get_meta("look") as Dictionary)["kind"]))
	for kind: String in ["shrine_niche", "altar_table", "incense_burner"]:
		_check(kind in kinds, "the temple has its %s" % kind)
	var hwang: WorldCharacterBody2D = map.runtime_body_for_spawn_point(&"goathill.temple1.bandit_hwang.1")
	_check(hwang != null, "黄霸 is in his temple")
	if hwang != null:
		var near: Vector2 = MapPlaces.spot(map, &"goathill.temple1", hwang.global_position + Vector2(-60, 0), 64.0)
		_check(await MapPlaces.drive(tree, map, near), "walk from the door up to 黄霸 between the furniture")
		_check(map.player_body.global_position.distance_to(hwang.global_position) < 96.0, "within his interaction reach")
	_check(await MapPlaces.take_passage(tree, map, &"goathill.temple1.west"), "out by the temple door")
	await _frames(tree, 4)
	_check(session.active_map_id() == &"goathill.mountain", "back on the mountain road")


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
