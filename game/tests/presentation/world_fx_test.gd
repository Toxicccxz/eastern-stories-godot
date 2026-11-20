extends RefCounted

## 世界演出 (DECISIONS「世界演出」): rain falls outdoors under the darkest sky and nowhere else,
## coming and going slowly; a door's leaf swings on its hinge; a thing taken from beside the
## player flies to their hand; one who notices the player starts; a wader splashes. With the
## feel off none of it is shown, and none of it changes a door, a thing or anyone's place.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	_check_data()
	await _check_rain(tree)
	await _check_touches(tree)
	await _check_in_a_session(tree)
	return {"assertions": assertions, "failures": failures}


## world_fx.json says what the code reads, and where it rains.
func _check_data() -> void:
	var weather: Dictionary = VoxelWeather.part("weather")
	var kinds: Dictionary = weather.get("kinds", {})
	check(not kinds.is_empty() and kinds.has(String(weather.get("default", ""))), "the default weather is a kind the data describes")
	var kinds_fine: int = 0
	for name: String in kinds:
		var look: Dictionary = kinds[name]
		kinds_fine += 1 if int(look.get("count", 0)) > 0 and (look.get("size", []) as Array).size() == 3 and float(look.get("fall", 0.0)) > 0.0 and float(look.get("height", 0.0)) > 0.0 and float(look.get("radius", 0.0)) > 0.0 and Color.html_is_valid(String(look.get("colour", ""))) else 0
	check(kinds_fine == kinds.size(), "every kind has its drops, their fall and their box")
	var regions: Dictionary = weather.get("regions", {})
	var regions_fine: int = 0
	for region: String in regions:
		regions_fine += 1 if GameContent.catalog().region(StringName(region)) != null and (regions[region] == "none" or kinds.has(String(regions[region]))) else 0
	check(regions_fine == regions.size(), "every region named is a region, its weather a kind or none (%d of %d)" % [regions_fine, regions.size()])
	check(VoxelWeather.kind_for(&"snow") == "rain" and VoxelWeather.kind_for(&"canyon") == "" and not kinds.has("snow"), "it rains in 雪亭镇 (no place is snowed on for its name), not in the desert beyond the pass")
	var from: int = int(weather.get("from_level", -1))
	check(from == SkyState.LEVELS - 1, "rain only under the darkest sky (天空中乌云密布)")
	check(is_equal_approx(VoxelWeather.falls(from, false, true), 1.0) and is_zero_approx(VoxelWeather.falls(from - 1, false, true)) and is_zero_approx(VoxelWeather.falls(from, true, true)) and is_zero_approx(VoxelWeather.falls(from, false, false)), "outdoors at that level, and only there")
	for key: String in ["door", "pickup", "startle", "wade"]:
		check(float(VoxelWeather.part(key).get("seconds", 0.0)) > 0.0, "%s has its share of the time" % key)
	check(float(VoxelWeather.part("door").get("swing", 0.0)) > 1.0 and float(VoxelWeather.part("door").get("swing", 9.0)) < PI / 2.0 + 0.2, "a door swings about a quarter turn")
	check(TestFeel.production.world_fx_seconds > 0.0 and is_zero_approx(FeelDefinition.new().world_fx_seconds), "pacing.json turns it on; off where the feel is (the suites)")


## The rain by itself: it comes on over the fade, all of it, and goes again.
func _check_rain(tree: SceneTree) -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var rain := VoxelWeather.new()
	root.add_child(rain)
	rain.configure("rain", false)
	var all: int = int(VoxelWeather.part("weather")["kinds"]["rain"]["count"])
	var fade: float = float(VoxelWeather.part("weather").get("fade_seconds", 6.0))
	check(rain.kind == "rain" and rain.shown_drops() == 0 and not rain.visible, "configured: none yet")
	rain.advance(fade * 0.5, 1.0, Vector3(40.0, 0.0, -12.0), Vector2.ZERO)
	check(absf(rain.amount - 0.5) < 0.01 and rain.shown_drops() == int(round(all * 0.5)) and rain.visible, "half the fade: half the drops (%d)" % rain.shown_drops())
	rain.advance(fade, 1.0, Vector3(40.0, 0.0, -12.0), Vector2(1.0, 0.0))
	check(is_equal_approx(rain.amount, 1.0) and rain.shown_drops() == all, "all of it")
	# Each drop is about what the camera looks at, under where drops begin.
	var multi: MultiMesh = (rain.get_child(0) as MultiMeshInstance3D).multimesh
	var look: Dictionary = VoxelWeather.part("weather")["kinds"]["rain"]
	var inside: int = 0
	for index: int in all:
		var at: Vector3 = multi.get_instance_transform(index).origin
		inside += 1 if absf(at.x - 40.0) <= float(look["radius"]) + 0.01 and absf(at.z + 12.0) <= float(look["radius"]) + 0.01 and at.y >= 0.0 and at.y <= float(look["height"]) + 0.01 else 0
	# Headless builds give no instance transforms back: only count what a renderer returns.
	check(inside == all or multi.get_instance_transform(0).origin == Vector3.ZERO, "the drops fall about the centre (%d of %d)" % [inside, all])
	rain.advance(fade * 2.0, 0.0, Vector3.ZERO, Vector2.ZERO)
	check(is_zero_approx(rain.amount) and rain.shown_drops() == 0 and not rain.visible, "and gone again")
	var thin := VoxelWeather.new()
	root.add_child(thin)
	thin.configure("rain", true)
	thin.advance(fade * 2.0, 1.0, Vector3.ZERO, Vector2.ZERO)
	check(thin.shown_drops() == int(all * float(VoxelWeather.part("weather").get("low_quality", 0.5))), "画质 低: its share of the drops (%d)" % thin.shown_drops())
	var none := VoxelWeather.new()
	root.add_child(none)
	none.configure("", false)
	none.advance(1.0, 1.0, Vector3.ZERO, Vector2.ZERO)
	check(none.kind.is_empty() and none.get_child_count() == 0 and none.shown_drops() == 0, "nothing where nothing falls")
	root.free()
	await tree.process_frame


## The motions by themselves, on things made here.
func _check_touches(tree: SceneTree) -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var touches := VoxelTouches.new()
	root.add_child(touches)
	var leaf := Node3D.new()
	leaf.position = Vector3(4.0, 0.0, 2.0)
	root.add_child(leaf)
	leaf.set_meta(VoxelTouches.DOOR_AT, leaf.position)
	leaf.set_meta(VoxelTouches.DOOR_TURN, 0.0)
	leaf.set_meta(VoxelTouches.DOOR_SPAN, Vector3(0.5, 0.0, 0.0))
	check(not touches.swing_door(&"d", leaf, true, Vector3(4.0, 0.0, 4.0)) and not touches.fly_to_hand(leaf, Vector3.ZERO) and not touches.startle(leaf, null) and not touches.splash(Vector3.ZERO) and touches.begun.is_empty(), "feel off: nothing is shown")
	TestFeel.use()
	# A door opened by one standing at +z: its free end swings away, to -z, then it is gone.
	check(touches.swing_door(&"d", leaf, true, Vector3(4.0, 0.0, 4.0)) and touches.swinging(&"d") and leaf.visible, "opening: the leaf swings")
	var turned: float = 0.0
	var went: float = 0.0
	for step: int in 120:
		await tree.process_frame
		turned = maxf(turned, absf(leaf.rotation.y))
		went = minf(went, leaf.position.z - 2.0)
		if not touches.swinging(&"d"):
			break
	check(turned > 1.2 and went < -0.2, "it turned about its hinge, away from the one who opened it (%.2f rad, %.2f)" % [turned, went])
	check(not leaf.visible and leaf.position.is_equal_approx(Vector3(4.0, 0.0, 2.0)) and is_zero_approx(leaf.rotation.y), "open: gone, hung where it was")
	check(touches.swing_door(&"d", leaf, false, Vector3(4.0, 0.0, 4.0)) and leaf.visible and absf(leaf.rotation.y) > 1.2, "shutting: it is there, swung, and comes to")
	for step: int in 120:
		await tree.process_frame
		if not touches.swinging(&"d"):
			break
	check(leaf.visible and leaf.position.is_equal_approx(Vector3(4.0, 0.0, 2.0)) and is_zero_approx(leaf.rotation.y), "shut: there, hung where it was")
	var bare := Node3D.new()
	root.add_child(bare)
	check(not touches.swing_door(&"b", bare, true, Vector3.ZERO), "a leaf not hung for it does not swing")
	# A thing flies to the hand and is gone.
	var thing := Node3D.new()
	thing.position = Vector3(1.0, 0.0, 1.0)
	root.add_child(thing)
	var hand := Vector3(2.0, 1.0, 1.0)
	check(touches.fly_to_hand(thing, hand), "a thing taken flies")
	var nearest: float = INF
	var highest: float = 0.0
	for step: int in 120:
		await tree.process_frame
		if not is_instance_valid(thing):
			break
		nearest = minf(nearest, thing.position.distance_to(hand))
		highest = maxf(highest, thing.position.y)
	check(not is_instance_valid(thing) and nearest < 0.3 and highest > 1.0, "to the hand in an arc, then gone (%.2f from it, %.2f high)" % [nearest, highest])
	# A start: a hop, the mark popping in.
	var model := Node3D.new()
	root.add_child(model)
	var mark := Node3D.new()
	root.add_child(mark)
	check(touches.startle(model, mark) and mark.scale.x > 1.5, "one who notices starts, its mark large at first")
	var hopped: float = 0.0
	for step: int in 60:
		await tree.process_frame
		hopped = maxf(hopped, model.position.y)
	check(hopped > 0.15 and is_zero_approx(model.position.y) and mark.scale.is_equal_approx(Vector3.ONE), "a hop and down again, the mark its own size (%.2f)" % hopped)
	# A splash: made, and gone.
	check(touches.splash(Vector3(3.0, 0.0, 3.0)) and touches.get_node_or_null(^"Splash") != null, "a splash where one wades")
	for step: int in 90:
		await tree.process_frame
	check(touches.get_node_or_null(^"Splash") == null, "gone when it has fallen")
	check(touches.begun == {"door": 2, "pickup": 1, "startle": 1, "splash": 1}, "each counted: %s" % [touches.begun])
	TestFeel.restore()
	root.free()
	await tree.process_frame


## A real session: no rain indoors; a door of the map swings when its state changes and the
## view changes nothing of it; what the player takes from beside them flies, what lies far does not.
func _check_in_a_session(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	var map := session.active_map() as WorldMapController
	var view: WorldVoxelView = map.get_node_or_null("MapView") as WorldVoxelView
	var me: StringName = session.player_runtime().character_id
	for step: int in 400:
		await tree.process_frame
		if view != null and view.actors.has(me):
			break
	if not check(view != null and view.actors.has(me), "the session's map has its view and the player's figure"):
		session.free()
		return
	check(not is_instance_valid(view.weather) and not is_instance_valid(view.touches), "feel off: no rain made, nothing to move things")
	check(not view._ground_kind(map.player_body.global_position).is_empty(), "the ground under the player has a kind (%s)" % view._ground_kind(map.player_body.global_position))
	TestFeel.use()
	view.set_cloud(SkyState.LEVELS - 1)
	await tree.create_timer(1.0).timeout
	check(view.geometry.indoor and is_instance_valid(view.weather) and is_zero_approx(view.weather.amount) and view.weather.shown_drops() == 0, "indoors under the darkest sky: no rain")
	# To the 武馆's yard, which has a gate: a door's state is the map's, the view shows it change.
	var zone: ZoneDefinition = GameContent.catalog().zone(&"snow.school2")
	var yard := session.resident_map(zone.map_id) as WorldMapController
	var arrived: bool = yard != null and session.handoff_to_point(zone.map_id, &"snow.school2", &"snow.school2", MapPlaces.zone_spot(yard, &"snow.school2")).succeeded()
	map = session.active_map() as WorldMapController
	view = map.get_node_or_null("MapView") as WorldVoxelView
	for step: int in 600:
		await tree.process_frame
		if view != null and view.actors.has(me) and not view.shutters.is_empty():
			break
	if not check(arrived and view != null and view.actors.has(me) and not map.doors_by_id.is_empty() and not view.shutters.is_empty(), "in the 武馆's yard, its gate drawn"):
		TestFeel.restore()
		session.free()
		return
	var id: StringName = map.doors_by_id.keys()[0]
	var door: WorldDoor = map.doors_by_id[id]
	var leaf: Node3D = view.shutters[id]
	var was_open: bool = door.is_open()
	await tree.process_frame
	door.set_open(not was_open) # TEST-ONLY: put back below
	var swung: bool = false
	for step: int in 60:
		await tree.process_frame
		swung = swung or (is_instance_valid(view.touches) and view.touches.swinging(id))
		if swung and not view.touches.swinging(id):
			break
	var has_open_form: bool = view.opened.has(id)
	check(swung != has_open_form, "the door's leaf swings (one with an open form of its own changes as before)")
	check(door.is_open() == not was_open and leaf.visible == was_open, "the door is as the map set it, the leaf there only while it is shut")
	door.set_open(was_open)
	await tree.create_timer(0.6).timeout
	check(door.is_open() == was_open and leaf.visible == not was_open and leaf.position.is_equal_approx(leaf.get_meta(VoxelTouches.DOOR_AT)), "put back: hung where it was")
	# Things gone from the ground: beside the player, to the hand; far off, or a corpse, just gone.
	var beside := Node3D.new()
	beside.position = view.actors[me].position + Vector3(0.6, 0.0, 0.0)
	view.world.add_child(beside)
	var far := Node3D.new()
	far.position = view.actors[me].position + Vector3(9.0, 0.0, 0.0)
	view.world.add_child(far)
	var body := Node3D.new()
	body.position = beside.position
	body.set_meta(&"corpse", true)
	view.world.add_child(body)
	check(view._taken_by_player(beside) and not view._taken_by_player(far) and not view._taken_by_player(body), "only a thing from beside the player flies")
	await tree.create_timer(0.6).timeout
	check(not is_instance_valid(beside) and is_instance_valid(far) and is_instance_valid(body), "and it is gone when it arrives; the others are the caller's to free")
	far.free()
	body.free()
	TestFeel.restore()
	await tree.process_frame
	check(not view.weather.visible, "feel off again: the rain is not drawn")
	session.free()
	await tree.process_frame


func check(condition: bool, message: String) -> bool:
	assertions += 1
	if not condition:
		failures.append(message)
	return condition
