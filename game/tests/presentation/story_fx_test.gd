extends RefCounted

## 主线场面 (DECISIONS「主线场面」): story_fx.json names only what the game has and can draw; a
## scene's trigger is read off the player's marks, the things they hold and who stands on the
## map; it is played once, the moment its trigger comes true in front of the player — not for
## what was true as the map was shown, not with the feel off — and what it shows is gone when
## it is over. Nothing of it writes a mark or moves anyone.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	_check_data()
	await _check_play(tree)
	await _check_in_a_session(tree)
	return {"assertions": assertions, "failures": failures}


## Every scene: a real map, a trigger, things the game has, figures the libraries draw.
func _check_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var scenes: Dictionary = VoxelStoryFx.data().get("scenes", {})
	check(scenes.size() >= 5 and float(VoxelStoryFx.data().get("check_seconds", 0.0)) > 0.0, "the main story has its scenes (%d)" % scenes.size())
	for name: String in scenes:
		var scene: Dictionary = scenes[name]
		var triggered: bool = scene.has("present") or scene.has("npc") or scene.has("item")
		var real: bool = catalog.map(StringName(String(scene.get("map", "")))) != null
		real = real and (not scene.has("npc") or catalog.npc(StringName(String(scene["npc"]))) != null)
		real = real and (not scene.has("item") or catalog.item(StringName(String(scene["item"]))) != null)
		check(triggered and real and (scene.get("at", []) as Array).size() == 2, "%s: a trigger, on a map the game has, with the people and things it names" % name)
		var layers: Array = scene.get("layers", [])
		var drawn: int = 0
		for layer: Dictionary in layers:
			var known: bool = BattleArts.KINDS.has(String(layer.get("art", ""))) != BattleSchoolMotifs.KINDS.has(String(layer.get("motif", "")))
			drawn += 1 if known and Color.html_is_valid(String(layer.get("colour", ""))) and float(layer.get("seconds", 0.0)) > 0.0 and float(layer.get("scale", 1.0)) > 0.0 and float(layer.get("delay", 0.0)) >= 0.0 else 0
		check(layers.size() >= 2 and drawn == layers.size(), "%s: every layer is a figure the libraries draw, in a colour, for a time (%d of %d)" % [name, drawn, layers.size()])
		var light: Dictionary = scene.get("light", {})
		var sound: Array = scene.get("sound", [])
		var shake: Array = scene.get("shake", [])
		var zoom: Array = scene.get("zoom", [])
		check(
			(light.is_empty() or (Color.html_is_valid(String(light.get("colour", ""))) and float(light.get("energy", 0.0)) > 0.0))
			and (sound.is_empty() or (sound.size() == 3 and BattleSounds.FILES.has(StringName(String(sound[0])))))
			and (shake.is_empty() or (shake.size() == 2 and float(shake[0]) > 0.0 and float(shake[0]) <= 0.3))
			and (zoom.is_empty() or (zoom.size() == 3 and float(zoom[0]) > 0.3 and float(zoom[0]) < 1.0)),
			"%s: its light, sound, jolt and push-in are ones the game can give" % name,
		)
	check(VoxelStoryFx.scenes_for(&"village.seal_chamber").size() >= 3 and VoxelStoryFx.scenes_for(&"snow.outdoor").is_empty(), "scenes are found by their map; a map without any has none")


## A scene by itself: layers come up in turn, the picture jolts and settles, all of it goes.
func _check_play(tree: SceneTree) -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var camera := Camera3D.new()
	root.add_child(camera)
	var fx := VoxelStoryFx.new()
	root.add_child(fx)
	fx.camera = camera
	var scene: Dictionary = (VoxelStoryFx.data()["scenes"]["impaler_pulled"] as Dictionary).duplicate(true)
	scene.erase("zoom")
	check(not fx.play("empty", {"layers": []}) and fx.played.is_empty(), "nothing to show: not played")
	check(fx.play("impaler_pulled", scene) and fx.played == ["impaler_pulled"], "played")
	var most: int = 0
	var jolted: float = 0.0
	var figures: int = 0
	for step: int in 300:
		await tree.process_frame
		most = maxi(most, fx.showing())
		jolted = maxf(jolted, maxf(absf(camera.h_offset), absf(camera.v_offset)))
		for child: Node in fx.get_children():
			figures += 1 if child.has_meta(&"story") and (child as Node3D).scale.x > 1.5 and step == 90 else 0
		if step > 60 and fx.showing() == 0:
			break
	check(most >= 3 and figures >= 1, "its layers and its light come up, larger than a fight's (%d up at most)" % most)
	check(jolted > 0.01 and jolted <= float(scene["shake"][0]) + 0.001 and is_zero_approx(camera.h_offset) and is_zero_approx(camera.v_offset), "the picture jolts, within its reach, and is still again (%.3f)" % jolted)
	check(fx.showing() == 0, "all of it gone when it is over")
	root.free()
	await tree.process_frame


## A real session on the 岚城 terrace: 旋芒's scene plays when its mark comes, once.
func _check_in_a_session(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	var me: StringName = session.player_runtime().character_id
	var state: CharacterState = session.player_runtime().state
	var zone: ZoneDefinition = GameContent.catalog().zone(&"lancheng.deck")
	var terrace := session.resident_map(zone.map_id) as WorldMapController
	var arrived: bool = terrace != null and session.handoff_to_point(zone.map_id, &"lancheng.deck", &"lancheng.deck", MapPlaces.zone_spot(terrace, &"lancheng.deck")).succeeded()
	var map := session.active_map() as WorldMapController
	var view: WorldVoxelView = map.get_node_or_null("MapView") as WorldVoxelView
	for step: int in 900:
		await tree.process_frame
		if view != null and view.actors.has(me):
			break
	if not check(arrived and map.map_id() == &"lancheng.terrace" and view != null and view.actors.has(me), "on the terrace, its view built"):
		session.free()
		return
	var scenes: Dictionary = VoxelStoryFx.scenes_for(map.map_id())
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var nobody: Dictionary[StringName, bool] = {}
	check(scenes.has("xuanmang_out") and not VoxelStoryFx.holds(scenes["xuanmang_out"], player, nobody, nobody, &"", nobody), "旋芒 is in the wind: its scene's trigger does not hold")
	# The other triggers, read the same way: someone standing there, a thing held.
	var shade: Dictionary = VoxelStoryFx.data()["scenes"]["shade_called"]
	var feather: Dictionary = VoxelStoryFx.data()["scenes"]["feather_given"]
	var here: Dictionary[StringName, bool] = {&"native.npc.headless_shade": true}
	var has: Dictionary[StringName, bool] = {&"native:village/lihong_feather": true}
	check(VoxelStoryFx.holds(shade, player, nobody, nobody, &"", here) and not VoxelStoryFx.holds(shade, player, nobody, nobody, &"", nobody), "唤首: while the shade stands on the map")
	check(VoxelStoryFx.holds(feather, player, has, nobody, &"", nobody) and not VoxelStoryFx.holds(feather, player, nobody, nobody, &"", nobody), "璃虹's feather: while the player holds it")
	check(not VoxelStoryFx.holds({"layers": []}, player, has, nobody, &"", here), "a scene with no trigger never holds")
	# The feel off: nothing is read or made.
	state.marks["旋芒在皇叔手里"] = 1 # TEST-ONLY
	await tree.create_timer(0.6).timeout
	check(not is_instance_valid(view.story_fx), "feel off: no scene is looked for")
	# The feel on with the mark there already (a map come onto after it happened): not played.
	TestFeel.use()
	await tree.create_timer(0.6).timeout
	check(is_instance_valid(view.story_fx) and view.story_fx.played.is_empty(), "true as the map is shown: it happened before, nothing plays")
	state.marks.erase("旋芒在皇叔手里")
	await tree.create_timer(0.5).timeout
	var marks_before: Dictionary = state.marks.duplicate()
	var zoom_before: float = view.zoom()
	state.marks["旋芒在你手里"] = 1 # TEST-ONLY: the act's `mark`
	var nearest: float = zoom_before
	var up: int = 0
	for step: int in 60:
		await tree.process_frame
		nearest = minf(nearest, view.zoom())
		up = maxi(up, view.story_fx.showing())
	check(view.story_fx.played == ["xuanmang_out"] and up >= 2 and nearest < zoom_before - 0.1, "the mark comes: 旋芒's scene plays, its figures up, the camera nearer (%s, %d, %.2f)" % [view.story_fx.played, up, nearest])
	await tree.create_timer(4.0).timeout
	check(view.story_fx.played == ["xuanmang_out"] and view.story_fx.showing() == 0 and is_equal_approx(view.zoom(), zoom_before), "once; over, nothing left, the camera where it was")
	marks_before["旋芒在你手里"] = 1
	check(state.marks == marks_before, "it wrote no mark of its own")
	state.marks.erase("旋芒在你手里")
	TestFeel.restore()
	session.free()
	await tree.process_frame


func check(condition: bool, message: String) -> bool:
	assertions += 1
	if not condition:
		failures.append(message)
	return condition
