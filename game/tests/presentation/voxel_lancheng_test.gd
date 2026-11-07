extends RefCounted

## 第十章 A in the fixed-angle voxel view: the 寻风地带 — the 幻影道's polished yellow walls and the
## incense mist on its floor; the high field of wind-worn white pillars, waist-high grass and mist in
## streaks; three sheltered hollows; the 逆灵宫's black altar and banners; the 兵部's dead camp. Warm white
## stone, never a flat grey; the grass and the mist lean with the map's guiding wind (WorldMapWinds), and
## still in the calm. The 2D map decides every way through; the view changes nothing in the save.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Existing := preload("res://tests/presentation/voxel_gameplay_test.gd")
const Imperial := preload("res://tests/presentation/voxel_imperial_test.gd")
const SCENES: Array[String] = ["lancheng/lancheng_wilds", "canyon/canyon_bamboo"]
var assertions: int = 0
var failures: Array[String] = []


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
	var state: CharacterState = session.player_runtime().state
	state.marks["皇城一章"] = 1 # TEST-ONLY: the diviners on their altar
	state.marks["风眼在北"] = 1 # TEST-ONLY: the north route blowing
	var map: WorldMapController = MapPlaces.enter(session, &"lancheng.stone_field", &"lancheng.wind.fork") # TEST-ONLY
	await _frames(tree, 4)
	_check(map != null and map.projected_view, "the 寻风地带 in its voxel view")
	if map != null:
		var shared := Imperial.new()
		var view: WorldVoxelView = map.get_node("MapView") as WorldVoxelView
		# The 皇城 suite's checks, but for a wild map (no rooms to be lived in: 野外, as its NO_ROOMS).
		_check(map.projected_view and view.camera.current, "the 寻风地带 uses its voxel view")
		_check(view.geometry.unknown_kinds.is_empty(), "every prop kind is drawn: %s" % [view.geometry.unknown_kinds])
		_check(view.geometry.find_children("*", "OmniLight3D", true, false).size() > 0, "a light for the night (the 迷香, the altar's ember, the moon in the hollow)")
		var passages: int = 0
		for node: Node in map.find_children("*", "Area2D", true, false):
			if node is WorldPassageArea2D:
				passages += 1
		_check(view.arrows.size() == view.entrances.size() + map.doors_by_id.size() and view.entrances.size() == passages, "every way out has its bobbing arrow")
		shared._check_footing(map, view, "lancheng.wilds")
		await shared._check_access_and_saves(tree, session, map, view)
		assertions += shared.assertions
		failures.append_array(shared.failures)
		var kinds: Array[String] = shared._kinds(view)
		_check(kinds.count("standing_rock") >= 12 and kinds.count("lean_to") == 3 and kinds.count("banner") == 3 and kinds.count("trail") == 4, "the pillars, the dead camp's three tents, the altar's banners and the fallen flag, four trails: %s" % [kinds])
		# The grass and the mist lean with the wind; still in the calm.
		map.winds.wind().veer_percent = 0 # TEST-ONLY: steady gusts (restored below)
		map.winds.tick(0.1)
		for frame: int in 40:
			view._process(0.05)
		var shown: Vector2 = view.geometry.ambience.guiding_wind
		_check(shown.length() > 0.5 and shown.dot(map.winds.vector()) > 0.8, "the mist follows the wind: %s (rule %s)" % [shown, map.winds.vector()])
		var gust_dir: Vector2 = view.geometry.foliage.material.get_shader_parameter("gust_dir")
		_check(gust_dir.dot(map.winds.vector()) > 0.8, "the grass leans along it: %s" % gust_dir)
		map.runtime_player_body().global_position = map.resolve_spawn_marker(&"lancheng.wind.north_calm").global_position # TEST-ONLY: in the calm
		map.winds.tick(map.winds.wind().gust_ms / 1000.0)
		for frame: int in 80:
			view._process(0.05)
		_check(view.geometry.ambience.guiding_wind.length() < 0.1 and float(view.geometry.foliage.material.get_shader_parameter("gust")) < 0.2, "still in the calm: the grass stands up")
		map.winds.wind().veer_percent = 15
	session.free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


## 美术规划 §1 岚城: the pillars are warm white stone (never a flat grey); the region's light has its five
## frames, a blue-violet night, its own overcast.
func _check_own_colours() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/lancheng/voxel/wilds.json"))
	var stone := Color(String(layout["cliffs"]["strata"][0]))
	_check(stone.r > 0.8 and stone.r > stone.b + 0.06, "the 寻风地带's stone is warm white: %s" % stone.to_html(false))
	var light: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/lancheng/voxel/light.json"))
	var frames: int = 0
	for key: String in ["sky", "ambient", "sun"]:
		frames += (light["outdoor"][key] as Dictionary).size()
	var night := Color(String(light["outdoor"]["sky"]["night"]))
	_check(frames == 15 and night.b > night.r and (light["outdoor"] as Dictionary).has("overcast"), "the region's light: five frames, a blue-violet night, its own overcast")


func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.physics_frame
		await tree.process_frame


func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
