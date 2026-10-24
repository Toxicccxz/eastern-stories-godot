extends RefCounted

## 老松林 in the fixed-angle voxel view: the forest with its clearing, gorge and keep, the
## great pine's boughs, the gorge below the bridge, the passage behind the falls, the cave
## maze, the big stone, the two hollows in the cliffs and the keep's hall. The 2D maps still
## decide every way through: the forest is walked from Snow's road to the keep, the pine
## climbed, the curtain passed, the hall entered past the blocked furniture the layout added.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
const Snake := preload("res://presentation/voxel/actors/voxel_snake.gd")
const Flyer := preload("res://presentation/voxel/actors/voxel_flyer.gd")
const NPCS: Array[StringName] = [&"oldpine.npc.bandit", &"oldpine.npc.tall_bandit", &"oldpine.npc.fat_bandit", &"oldpine.npc.serpent",
	&"oldpine.npc.maniac", &"oldpine.npc.wolf_dog", &"oldpine.npc.bandit_guard", &"oldpine.npc.bandit_leader", &"oldpine.npc.bandit_commander",
	&"oldpine.npc.spy", &"oldpine.npc.venomsnake"]
## Decor tall enough to walk into: in a voxel config it must stand on ground the 2D map blocks
## (rock, the forest, a blocked box) or be raised clear of the floor (`elevation`).
const TALL: Array[String] = ["torch", "cairn", "banner", "standing_rock", "boulder", "crag", "barricade", "wine_jars", "stalagmites",
	"dead_log", "lean_to", "loot_crates", "campfire", "mossy_rock", "mossy_log", "stump", "tree", "great_pine", "bush", "candlestick", "brazier"]
const MAPS: Array[StringName] = [&"oldpine.outdoor", &"oldpine.tree", &"oldpine.gorge", &"oldpine.cave", &"oldpine.stone", &"oldpine.caves",
	&"oldpine.cliff", &"oldpine.cliff2", &"oldpine.keep_hall"]
var assertions: int = 0
var failures: Array[String] = []
var _seen: Dictionary[StringName, bool] = {}


func run_all(tree: SceneTree) -> Dictionary:
	var furnishings := Existing.new()
	for scene: String in ["oldpine_outdoor", "oldpine_cave", "keep_hall"]:
		furnishings._check_furnishings(load("res://scenes/world/oldpine/%s.tscn" % scene) as PackedScene, scene)
	assertions += furnishings.assertions
	failures.append_array(furnishings.failures)
	# TEST-ONLY: the forest's people and beasts leave the walker alone (their own suites fight them).
	var kept: Dictionary = {}
	for id: StringName in NPCS:
		var npc: NpcDefinition = GameContent.catalog().npc(id)
		kept[id] = [npc.attitude, npc._capability_ids.duplicate()]
		npc.attitude = NpcDefinition.Attitude.PEACEFUL
		npc._capability_ids.clear()
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	var outdoor := MapPlaces.enter(session, &"oldpine.outdoor.north_approach", &"oldpine.outdoor.north_approach.snow_entry")
	_check(outdoor != null, "into 老松林 from Snow's road")
	if outdoor != null:
		await _frames(tree, 4)
		_calm_maniac(outdoor)
		await _check_forest(tree, session, outdoor)
		await _check_pine(tree, session, outdoor)
		await _check_keep(tree, session, outdoor)
		await _check_behind_falls(tree, session)
		await _check_caves(tree, session)
		for zone: StringName in [&"oldpine.stone.top", &"oldpine.cliff.hole", &"oldpine.cliff2.niche"]:
			await _check_small(tree, session, zone)
	var missing: Array[StringName] = []
	for map_id: StringName in MAPS:
		if not _seen.has(map_id):
			missing.append(map_id)
	_check(missing.is_empty(), "every map of 老松林 was seen in the voxel view: missing %s" % [missing])
	for id: StringName in NPCS:
		var npc: NpcDefinition = GameContent.catalog().npc(id)
		npc.attitude = kept[id][0]
		npc._capability_ids.assign(kept[id][1])
	session.free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


func _check_forest(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var view: WorldVoxelView = _view_of(map)
	_check_map(session, map, "the forest")
	var cliffs: VoxelCliffs = view.geometry.cliffs
	_check(cliffs != null and cliffs.holes().size() > 300, "the gorge under the bridge is sunk into a deep pit: %d cells" % (cliffs.holes().size() if cliffs != null else 0))
	_check(view.geometry.water.levels.size() > 100, "a stream runs along the gorge's floor")
	_check(view.geometry._groves.size() > 20, "the pines stand in groves")
	var crowns: int = 0
	for chunk: Vector2i in view.geometry._groves:
		for node: Node in (view.geometry._groves[chunk]["node"] as Node3D).get_children():
			if node is MultiMeshInstance3D:
				crowns += (node as MultiMeshInstance3D).multimesh.instance_count
	_check(crowns > 300, "the groves' crowns are drawn: %d" % crowns)
	var banked_in_pit: int = 0
	for cell: Vector2i in view.geometry.water.banked:
		banked_in_pit += 1 if cliffs.heights.get(cell, 0.0) < 0.0 else 0
	_check(banked_in_pit == 0, "the stream at the gorge's bottom has the gorge's walls for banks, no second face on them: %d" % banked_in_pit)
	var kinds: Array[String] = _kinds(view)
	for kind: String in ["great_pine", "stone_bridge", "waterfall", "plank_road", "vines", "bone_gate", "notice_post", "sandbags", "stakes", "mossy_log", "mossy_rock", "tracks", "sun_flecks"]:
		_check(kind in kinds, "the forest has its %s" % kind)
	_check(view.layout.get("light", {}).has("fog") and view.lighting.environment.fog_enabled, "haze settles into the gorge")
	var arrow: Node3D = view.arrows.get(&"oldpine.npath1.north")
	_check(arrow != null and arrow.get_meta("direction") == Vector2.UP, "the arrow at Snow's road points north out of the forest")
	_check(view.arrows.has(&"oldpine.keep.gate") and view.arrows.has(&"oldpine.outdoor.keep_yard.east"), "the keep's gate and the hall's door have their arrows")
	var flies: Array = view.geometry.ambience._fireflies
	view.set_night(false, true)
	view._process(0.1)
	var hidden_by_day: bool = not flies.is_empty()
	for fly: Dictionary in flies:
		hidden_by_day = hidden_by_day and not (fly["node"] as Node3D).visible
	view.set_night(true, true)
	view._process(0.1)
	var shown_at_night: bool = false
	for fly: Dictionary in flies:
		shown_at_night = shown_at_night or (fly["node"] as Node3D).visible
	view.set_night(false, true)
	_check(hidden_by_day and shown_at_night, "fireflies come out only at night")
	_check(view.geometry.ambience._falling.size() > 40, "pine needles drift down")
	var road: Array[StringName] = [&"oldpine.outdoor.central_clearing", &"oldpine.outdoor.slope", &"oldpine.outdoor.central_clearing", &"oldpine.outdoor.east_bridge",
		&"oldpine.outdoor.central_clearing", &"oldpine.outdoor.pine_entrance", &"oldpine.outdoor.pine_deep", &"oldpine.outdoor.pine_cliff_edge",
		&"oldpine.outdoor.pine_deep", &"oldpine.outdoor.pine_entrance", &"oldpine.outdoor.cliffside", &"oldpine.outdoor.pine_entrance"]
	for zone: StringName in road:
		_check(await MapPlaces.drive_to_zone(tree, map, zone), "walk the forest into " + String(zone))
	# Over the bridge: the deck is the 2D bridge, the gorge to either side blocks.
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"oldpine.outdoor.east_bridge", Vector2(1430, 300), 32.0)), "across the old bridge to epath3")
	var button := session.shared_ui().find_child("ViewSide", true, false) as VoxelViewSideButton
	for left: bool in [true, false]:
		_click(tree, button)
		await tree.create_timer(WorldVoxelView.VIEW_ROTATION_SECONDS + 0.05).timeout
		_check(map.place_player(&"oldpine.outdoor.central_clearing", Vector2(450, 380)), "into the clearing's open grass")
		await _frames(tree, 2)
		var start: Vector2 = map.player_body.global_position
		Input.action_press("move_right")
		await _frames(tree, 8)
		MapPlaces.release()
		var moved: Vector2 = map.view_ground.basis_xform(map.player_body.global_position - start)
		_check(view.left_view == left and moved.x > 4 and absf(moved.y) < 2, "D walks screen-right in the clearing from the %s side" % ("left" if left else "right"))


## Up the great pine from the clearing, along its boughs to the top, and down again.
func _check_pine(tree: SceneTree, session: WorldSessionController, outdoor: WorldMapController) -> void:
	_check(await MapPlaces.drive(tree, outdoor, MapPlaces.spot(outdoor, &"oldpine.outdoor.central_clearing", Vector2(600, 320), 48.0)), "to the foot of the great pine")
	_check(outdoor.select_landmark(&"oldpine.outdoor.landmark.ancient_pine"), "the great pine can be chosen")
	outdoor.traverse_selected_portal()
	await _frames(tree, 6)
	var map := session.active_map() as WorldMapController
	_check(map.map_id() == &"oldpine.tree" and map.projected_view, "climbed into the great pine's boughs, in the voxel view")
	var view: WorldVoxelView = _view_of(map)
	_check(view.geometry.landmass != null and view.geometry.get_node_or_null("LandmassCutaway") == null, "the boughs hang in the air: no ground slab under them")
	_check("far_ground" in _kinds(view) and "pine_trunk" in _kinds(view) and "needle_pad" in _kinds(view), "the trunk goes down to the clearing far below; needles mass along the boughs")
	var flyers: int = 0
	for actor: Node3D in view.actors.values():
		if actor.get_child(0) is Flyer:
			flyers += 1
	_check(flyers == 6, "tree2's six butterflies flutter as butterflies: %d" % flyers)
	_check_map(session, map, "the great pine")
	# TEST-ONLY: the butterflies and the man in black can stand on the trunk, as wide as two of
	# them; out of the way for the climb.
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.exists_in_map:
			map.npcs.vanish(npc)
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"oldpine.tree.canopy", Vector2(2000, -40), 32.0)), "along the trunk up to the windy top (tree3)")
	var down: Vector2 = MapPlaces.spot(map, &"oldpine.tree.canopy", Vector2(2000, 420), 48.0)
	_check(await MapPlaces.drive(tree, map, down), "and back down to the lowest boughs: at %s for %s" % [map.player_body.global_position, down])
	_check(map.select_landmark(&"oldpine.tree.landmark.tree1_descent"), "the way down can be chosen")
	map.traverse_selected_portal()
	await _frames(tree, 6)
	_check(session.active_map_id() == &"oldpine.outdoor" and outdoor.projected_view, "back down in the clearing, the forest's view again")


## South through the pines to the hidden gate, into the stockade and on into the hall.
func _check_keep(tree: SceneTree, session: WorldSessionController, outdoor: WorldMapController) -> void:
	# TEST-ONLY: the keep's guards crowd its gate; out of the way (oldpine_keep_caves_test meets them).
	for npc: NpcRuntimeState in outdoor.npc_runtimes():
		if npc.exists_in_map and npc.world_location().zone_id in [&"oldpine.outdoor.keep_gate", &"oldpine.outdoor.keep_yard"]:
			outdoor.npcs.vanish(npc)
	for zone: StringName in [&"oldpine.outdoor.pine_entrance", &"oldpine.outdoor.keep_gate", &"oldpine.outdoor.keep_yard"]:
		_check(await MapPlaces.drive_to_zone(tree, outdoor, zone), "on through the pines into " + String(zone))
	var grid: WorldNpcWalker.Grid = MapRoute.grid(outdoor, [])
	_check(grid._astar.is_point_solid(grid.cell_of(Vector2(1336, 752))), "the yard's sandbags are blocked boxes")
	_check(await MapPlaces.take_passage(tree, outdoor, &"oldpine.outdoor.keep_yard.east"), "east past the stakes into the hall by its door")
	await _frames(tree, 6)
	var map := session.active_map() as WorldMapController
	_check(map.map_id() == &"oldpine.keep_hall" and map.projected_view, "老松寨's hall is a voxel interior")
	var kinds: Array[String] = []
	for node: Node in map.get_node("Furnishings").get_children():
		kinds.append(String((node.get_meta("look") as Dictionary)["kind"]))
	for kind: String in ["brazier", "skull_pit", "chair", "travel_chest", "weapon_rack"]:
		_check(kind in kinds, "the hall has its %s" % kind)
	_check("bear_skin" in _kinds(_view_of(map)), "the bear skin lies by the north wall")
	_check_map(session, map, "the keep's hall")
	var commander: WorldCharacterBody2D = map.runtime_body_for_spawn_point(&"oldpine.outdoor.keep_hall.keep3.bandit_commander.1")
	_check(commander != null, "常老大 is in his hall")
	if commander != null:
		var near: Vector2 = MapPlaces.spot(map, &"oldpine.outdoor.keep_hall", commander.global_position + Vector2(-56, 0), 64.0)
		_check(await MapPlaces.drive(tree, map, near), "walk from the door round the pit up to 常老大")
		_check(map.player_body.global_position.distance_to(commander.global_position) < 96.0, "within his interaction reach")
	_check(await MapPlaces.take_passage(tree, map, &"oldpine.outdoor.keep_hall.west"), "out by the hall's door")
	await _frames(tree, 6)
	_check(session.active_map_id() == &"oldpine.outdoor", "back in the yard")
	var view: WorldVoxelView = _view_of(outdoor)
	var shut: bool = not outdoor.door(&"oldpine.keep.gate").is_open()
	var shutter: Node3D = view.shutters.get(&"oldpine.keep.gate")
	_check(shut and shutter != null and shutter.visible and shutter.get_child_count() > 1, "keep2's trap shut the gate: a great stone fills it")


## The passage behind the falls (reached by the vine; TEST-ONLY placed at its landing): past the
## candlesticks and through the silk curtain into the pool under the falls, then down the gorge.
func _check_behind_falls(tree: SceneTree, session: WorldSessionController) -> void:
	var map := MapPlaces.enter(session, &"oldpine.cave.waterfall_passage", &"oldpine.cave.waterfall_passage.vine_landing")
	await _frames(tree, 4)
	_check(map != null and map.projected_view, "behind the falls, in the voxel view")
	if map == null:
		return
	var view: WorldVoxelView = _view_of(map)
	_check("silk_curtain" in _kinds(view) and "waterfall" in _kinds(view), "the silk curtain hangs before the falling water")
	_check(view.lighting.carried != null and not view.lighting.carried.shadow_enabled, "a light goes with the player in the rock")
	_check_map(session, map, "the passage behind the falls")
	for zone: StringName in [&"oldpine.cave.secret_path", &"oldpine.cave.inner_path", &"oldpine.cave.secret_path", &"oldpine.cave.waterfall_passage"]:
		_check(await MapPlaces.drive_to_zone(tree, map, zone), "walk the passage into " + String(zone))
	_check(await MapPlaces.take_passage(tree, map, &"oldpine.cave.passage_to_waterfall"), "south through the curtain")
	await _frames(tree, 6)
	var gorge := session.active_map() as WorldMapController
	_check(gorge.map_id() == &"oldpine.gorge" and gorge.projected_view, "out into the pool under the falls")
	var gorge_view: WorldVoxelView = _view_of(gorge)
	var water: VoxelWater = gorge_view.geometry.water
	var kinds_of_water: Dictionary = {}
	for look: Dictionary in water.looks.values():
		kinds_of_water[look["kind"]] = true
	_check(kinds_of_water.has("shallow_water") and kinds_of_water.has("water") and kinds_of_water.has("deep_water"), "the pool, the stream and the bottomless pool are water: %s" % [kinds_of_water.keys()])
	var buried: int = 0
	for cell: Vector2i in water.looks:
		var landmass: VoxelLandmass = gorge_view.geometry.landmass
		if water.looks[cell].get("clear", false) and landmass.contains(Vector2(cell)) and not _slab_open(gorge_view, cell):
			buried += 1
	_check(buried == 0, "the clear pool's stony bed is not hidden under the ground slab: %d cells" % buried)
	for kind: String in ["waterfall", "stone_bridge", "bubbles", "reeds", "vines"]:
		_check(kind in _kinds(gorge_view), "the gorge has its %s" % kind)
	var snakes: int = 0
	for actor: Node3D in gorge_view.actors.values():
		if actor.get_child(0) is Snake:
			snakes += 1
	_check(snakes == 5, "the five black serpents coil as snakes: %d" % snakes)
	_check_map(session, gorge, "the gorge")
	for zone: StringName in [&"oldpine.gorge.river", &"oldpine.gorge.lake", &"oldpine.gorge.river", &"oldpine.gorge.waterfall"]:
		_check(await MapPlaces.drive_to_zone(tree, gorge, zone), "walk the gorge into " + String(zone))


func _check_caves(tree: SceneTree, session: WorldSessionController) -> void:
	var map := MapPlaces.enter(session, &"oldpine.caves.maze", &"oldpine.caves.maze.cave1_landing")
	await _frames(tree, 4)
	_check(map != null and map.projected_view, "in the cave maze, in the voxel view")
	if map == null:
		return
	var view: WorldVoxelView = _view_of(map)
	_check("carved_wall" in _kinds(view), "cave5's wall has its sword-cut words")
	var bones: bool = false
	for id: StringName in view.objects:
		bones = bones or view.objects[id].get_child_count() > 2
	_check(bones, "南危水's skeleton lies as bones, not a bundle")
	_check_map(session, map, "the cave maze")
	_check(await MapPlaces.drive_to_zone(tree, map, &"oldpine.caves.mouth"), "through the maze to cave5")
	_check(await MapPlaces.take_passage(tree, map, &"oldpine.caves.eastdown"), "east down out of the cave to the falls")
	await _frames(tree, 4)
	_check(session.active_map_id() == &"oldpine.gorge", "by the pool under the falls")


func _check_small(tree: SceneTree, session: WorldSessionController, zone: StringName) -> void:
	var spawn: StringName = GameContent.catalog().map(MapPlaces.map_of(zone)).entry_spawn_id
	var map := MapPlaces.enter(session, zone, spawn)
	await _frames(tree, 4)
	_check(map != null and map.projected_view, "%s is in the voxel view" % zone)
	if map == null:
		return
	_check_map(session, map, String(zone))
	if map.map_id() == &"oldpine.stone":
		var snake: bool = false
		for actor: Node3D in _view_of(map).actors.values():
			snake = snake or actor.get_child(0) is Snake and (actor.get_child(0) as Snake).rear
		_check(snake, "the gold-and-silver snake rears on the stone")
	if map.map_id() in [&"oldpine.cliff", &"oldpine.cliff2"]:
		_check(_view_of(map).geometry.cliffs.holes().size() > 50, "%s: the drop below the hollow's lip goes far down" % map.map_id())


## What every map must show: its view, every prop kind drawn, tall decor standing clear of the
## walkable ground, every room and NPC still reachable, and the save and RNG untouched.
func _check_map(session: WorldSessionController, map: WorldMapController, place: String) -> void:
	_seen[map.map_id()] = true
	var view: WorldVoxelView = _view_of(map)
	_check(map.projected_view and view.camera.current, "%s uses its voxel view" % place)
	_check(view.geometry.unknown_kinds.is_empty(), "every prop kind in %s is drawn: %s" % [place, view.geometry.unknown_kinds])
	var night_light: bool = view.geometry.find_children("*", "OmniLight3D", true, false).size() > 0 or view.lighting.carried != null
	_check(night_light, "%s has a light for the night" % place)
	var passages: int = 0
	for node: Node in map.find_children("*", "Area2D", true, false):
		if node is WorldPassageArea2D:
			passages += 1
	_check(view.arrows.size() == view.entrances.size() + map.doors_by_id.size() and view.entrances.size() == passages, "every way out of %s has its bobbing arrow" % place)
	_check_footing(map, view, place)
	_check_access_and_saves(session, map, view)


func _check_footing(map: WorldMapController, view: WorldVoxelView, place: String) -> void:
	var loose: Array[String] = []
	for prop: Dictionary in view.layout.get("props", []):
		if not String(prop["kind"]) in TALL or float(prop.get("elevation", 0.0)) >= 0.9:
			continue
		var size: Array = prop.get("size", [16, 16])
		var box := Vector2(float(size[0]), float(size[1]))
		if absi(roundi(float(prop.get("rotation", 0)))) % 180 == 90:
			box = Vector2(box.y, box.x)
		var at := Vector2(float(prop["at"][0]), float(prop["at"][1]))
		var area := Rect2(at - box / 2.0, box)
		var solid: bool = true
		for y: int in range(floori(area.position.y / 16.0), ceili(area.end.y / 16.0)):
			for x: int in range(floori(area.position.x / 16.0), ceili(area.end.x / 16.0)):
				var cell := Vector2(x * 16 + 8, y * 16 + 8)
				var rock: bool = prop.get("on_cliff", false) and view.geometry.cliffs != null and view.geometry.cliffs.heights.has(Vector2i(cell))
				solid = solid and (rock or TerrainProbe.blocks_at(map, cell))
		if not solid:
			loose.append("%s %s" % [prop["kind"], prop["at"]])
	_check(loose.is_empty(), "tall decor in %s stands on rock, forest or a blocked box: %s" % [place, loose])


## On the 2D map the voxel view never changes: every room has a way to it from where the
## player stands, every NPC a spot within interaction reach on that way, and day, night,
## the view side and the animations leave the save (and gameplay RNG) as they were.
func _check_access_and_saves(session: WorldSessionController, map: WorldMapController, view: WorldVoxelView) -> void:
	var start: Vector2 = map.player_body.global_position
	var cut_off: Array[String] = []
	for zone: ZoneDefinition in GameContent.catalog().zones_for_map(map.map_id()):
		var at: Vector2 = MapPlaces.zone_spot(map, zone.zone_id)
		if not at.is_finite() or MapRoute.path(map, start, at).is_empty():
			cut_off.append(String(zone.zone_id))
	_check(cut_off.is_empty(), "every room of %s can be walked to: cut off %s" % [map.map_id(), cut_off])
	var out_of_reach: Array[String] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
		# Butterflies flit over the gaps between the boughs: they come to the player, not the reverse.
		if body == null or not npc.exists_in_map or npc.definition().definition_id == &"oldpine.npc.butterfly":
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
	_check(GameSaveJsonCodec.encode(Work.capture(session)).text == saved, "%s: light, view side, water, mist and needles leave the save and RNG unchanged" % map.map_id())
	session.set_process(true)


## TEST-ONLY: 疯老头子's bellicosity (10000) has him fall on whoever comes by; the walk is not a fight.
func _calm_maniac(map: WorldMapController) -> void:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition().definition_id == &"oldpine.npc.maniac":
			npc.character_state.attributes.bellicosity = 0


## Whether the ground slab leaves a cell open: no top face of the slab lies on it.
func _slab_open(view: WorldVoxelView, cell: Vector2i) -> bool:
	var slab := view.geometry.get_node_or_null("LandmassCutaway") as MeshInstance3D
	if slab == null:
		return true
	var faces: PackedVector3Array = slab.mesh.get_faces()
	var centre := Vector3(cell.x / 32.0, -0.12, cell.y / 32.0)
	for i: int in range(0, faces.size(), 3):
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i + 1]
		var c: Vector3 = faces[i + 2]
		if not is_equal_approx(a.y, -0.12) or not is_equal_approx(b.y, -0.12) or not is_equal_approx(c.y, -0.12):
			continue
		if Geometry2D.point_is_inside_triangle(Vector2(centre.x, centre.z), Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)):
			return false
	return true


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
