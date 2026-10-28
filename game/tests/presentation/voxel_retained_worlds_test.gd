extends RefCounted

## The session keeps the built voxel world of only the last `voxel_worlds_kept` maps the
## player was on (feel knob, DECISIONS「固定俯视体素地图」): after A→B→C→D, A's world is
## freed; coming back to A builds it again as at first, and the 2D inn (bodies, NPCs, items)
## is as it was. With the knob at 0 every map keeps its world, as before the knob.
const Work = preload("res://tests/runtime/snow_work_income_test.gd")
const Still = preload("res://tests/runtime/snow_south_road_test.gd")
## B, C, D: upstairs, the square, the smithy (zone, spawn point).
const STOPS: Array = [[&"snow.inn_2f", &"snow.inn_2f.stairs_arrival"], [&"snow.square", &"snow.square.inn_entry"], [&"snow.smithy", &"snow.smithy.smithy_entry"]]
var assertions: int = 0
var failures: Array[String] = []

func run_all(tree: SceneTree) -> Dictionary:
	_check(TestFeel.production.voxel_worlds_kept == 3, "pacing.json keeps three maps' worlds: %d" % TestFeel.production.voxel_worlds_kept)
	# Suites run with the feel off (TestFeel): the knob is this suite's subject.
	GameContent.catalog().pacing().feel.with_values({"voxel_worlds_kept": 3})
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	var inn := session.active_map() as WorldMapController
	var view := inn.get_node("MapView") as WorldVoxelView
	_check(view._built and view.world != null and view.camera.current and inn.projected_view, "the inn's world is built on New Game")
	_check(session.recent_maps() == ([&"snow.inn"] as Array[StringName]), "the first map opens the recent list: %s" % [session.recent_maps()])
	view.set_frame("night", true)
	await _frames(tree, 2)
	var first: Dictionary = _portrait(view)
	var inn_before: Dictionary = _inn_state(inn)
	var views: Array[WorldVoxelView] = [view]
	for stop: Array in STOPS:
		var map: WorldMapController = MapPlaces.enter(session, stop[0], stop[1])
		_check(map != null, "in to %s" % stop[0])
		await _frames(tree, 4)
		var other := map.get_node("MapView") as WorldVoxelView
		_check(other._built and other.world != null and other.camera.current, "%s shows its own world" % stop[0])
		views.append(other)
		if stop[0] == &"snow.square":
			_check(view._built and view.world != null, "two maps on, the inn's world is still kept")
	_check(session.recent_maps() == ([&"snow.smithy_house", &"snow.outdoor", &"snow.inn_upstairs"] as Array[StringName]), "the last three maps are kept: %s" % [session.recent_maps()])
	_check(not view._built and view.world == null and view.camera == null and view.geometry == null, "the inn's world is freed after three other maps")
	_check(view.actors.is_empty() and view.labels.is_empty() and view.objects.is_empty() and view.entrances.is_empty() and view.shutters.is_empty() and view.arrows.is_empty(), "nothing of the inn's actors, things or exits is kept")
	_check(view.lighting.sun == null and view.lighting.lamps.is_empty() and view.lighting.windows.is_empty() and view.occlusion.materials.is_empty() and view.occlusion.roots.is_empty(), "the inn's lights and occlusion materials are let go")
	_check(view.get_child_count() == 0, "no 3D node is left under the inn's view: %d" % view.get_child_count())
	_check(view.held_frame == "night", "the held frame survives the freeing")
	for other: WorldVoxelView in views.slice(1):
		_check(other._built and other.world != null, "the kept maps' worlds stay built")
	_check(_inn_state(inn) == inn_before, "freeing the world changed nothing on the 2D inn: %s vs %s" % [inn_before, _inn_state(inn)])
	_check(is_instance_valid(inn) and session.resident_map(&"snow.inn") == inn, "the 2D inn stays resident")
	# Back to A: built again on the first frame there, the same world as at first.
	var back: WorldMapController = MapPlaces.enter(session, &"snow.inn.main_floor", &"snow.inn.main_floor.player_birth")
	_check(back == inn, "back onto the same inn map")
	await _frames(tree, 4)
	_check(view._built and view.world != null and view.camera != null and view.camera.current and inn.projected_view, "the inn's world is built again and live")
	var again: Dictionary = _portrait(view)
	_check(again == first, "the rebuilt inn matches the first build: %s vs %s" % [first, again])
	_check(view.actors.has(inn.player_body.character_id) and view.actors.size() == 1 + inn.npc_runtimes().size(), "the player and every NPC have their 3D body again: %d" % view.actors.size())
	_check(session.recent_maps() == ([&"snow.inn", &"snow.smithy_house", &"snow.outdoor"] as Array[StringName]), "the inn is the latest again: %s" % [session.recent_maps()])
	_check(not views[1]._built and views[1].world == null, "the upstairs' world went in its turn")
	_check(views[2]._built and views[3]._built, "the square's and the smithy's stay")
	# The knob at 0: every world stays (how the game was before the knob).
	GameContent.catalog().pacing().feel.with_values({"voxel_worlds_kept": 0})
	for stop: Array in STOPS:
		_check(MapPlaces.enter(session, stop[0], stop[1]) != null, "round again to %s" % stop[0])
		await _frames(tree, 3)
	_check(view._built and views[1]._built and views[2]._built and views[3]._built, "with the knob at 0 every map keeps its world")
	_check(session.recent_maps().size() == 4, "the recent list keeps every map when nothing is freed: %s" % [session.recent_maps()])
	TestFeel.restore()
	session.queue_free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}

## What the build made, in counts: the same layout and seed make the same world.
func _portrait(view: WorldVoxelView) -> Dictionary:
	return {
		"nodes": view.world.find_children("*", "", true, false).size(),
		"multimeshes": view.world.find_children("*", "MultiMeshInstance3D", true, false).size(),
		"lights": view.world.find_children("*", "Light3D", true, false).size(),
		"labels": view.world.find_children("*", "Label3D", true, false).size(),
		"occluders": view.geometry.occluders.size(),
		"footprints": view.geometry.footprints.size(),
		"materials": view.occlusion.materials.size(),
		"lamps": view.lighting.lamps.size(),
		"windows": view.lighting.windows.size(),
		"entrances": view.entrances.size(),
		"shutters": view.shutters.size(),
		"camera_size": view.camera.size,
		"frame": view.held_frame,
		"night": snappedf(view.lighting.amount, 0.01),
	}

## The 2D inn as the rules see it: who stands where, what lies on the floor, the doors.
func _inn_state(inn: WorldMapController) -> Dictionary:
	var npcs: Dictionary = {}
	for npc: NpcRuntimeState in inn.npc_runtimes():
		var body: Node2D = inn.runtime_body_for_character(npc.character_id)
		npcs[npc.character_id] = [npc.life_status, body.global_position if body != null else Vector2.INF, npc.world_location().zone_id]
	var doors: Dictionary = {}
	for id: StringName in inn.doors_by_id:
		doors[id] = inn.doors_by_id[id].is_open()
	return {"npcs": npcs, "items": inn.floor_item_ids(), "doors": doors}

func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.physics_frame
		await tree.process_frame

func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
