extends RefCounted

## The loading screen over a map's voxel world (DECISIONS「加载画面」): a world not yet built
## goes up over several frames behind the cover, the world held, and one fade brings it back;
## a kept map shows none of it. The picture comes only past the delay. Frames change nothing:
## the same world, the same rules. Suites run with the feel off, so this one sets it.
const Work = preload("res://tests/runtime/snow_work_income_test.gd")
const HOLD: StringName = WorldSessionController.WORLD_BUILD_HOLD
const INN: Array[StringName] = [&"snow.inn.main_floor", &"snow.inn.main_floor.player_birth"]
const UPSTAIRS: Array[StringName] = [&"snow.inn_2f", &"snow.inn_2f.stairs_arrival"]
const SMITHY: Array[StringName] = [&"snow.smithy", &"snow.smithy.smithy_entry"]
const WILD: Array[StringName] = [&"oldpine.outdoor.north_approach", &"oldpine.outdoor.north_approach.snow_entry"]
## Fast fades, a build that gives way at every chance, and no picture: each test says if it wants one.
const QUICK: Dictionary = {"map_fade_out_ms": 20, "map_fade_in_ms": 20, "door_fade_out_ms": 20, "door_fade_in_ms": 30, "map_banner_ms": 200, "map_loading_slice_ms": 1, "map_loading_delay_ms": 60000, "map_loading_min_ms": 0, "map_loading_fade_ms": 20}
var assertions: int = 0
var failures: Array[String] = []
var overlay: WorldViewOverlay


func run_all(tree: SceneTree) -> Dictionary:
	_test_data()
	_use({})
	var session: WorldSessionController = Work.create_session(tree)
	await _test_new_game(tree, session)
	await _test_kept_map(tree, session)
	await _test_rules_stand_still(tree, session)
	await _test_same_world(tree, session)
	await _test_picture(tree, session)
	await _test_small_room_stays_dark(tree, session)
	await _test_one_fade(tree, session)
	await _test_under_the_cover(tree, session)
	await _test_left_mid_build(tree, session)
	await _test_off(tree, session)
	await _test_session_gone_mid_build(tree, session)
	TestFeel.restore()
	return {"assertions": assertions, "failures": failures}


## pacing.json's knobs, the art it names, and what the loader refuses.
func _test_data() -> void:
	var feel: FeelDefinition = TestFeel.production
	_check(feel.map_loading_slice_seconds == 0.04 and feel.map_loading_delay_seconds == 0.2 and feel.map_loading_min_seconds == 0.5 and feel.map_loading_fade_seconds == 0.2, "pacing.json: 40 ms a frame, shown past 0.2 s, stays 0.5 s, fades 0.2 s")
	var definition: LoadingScreenDefinition = GameContent.catalog().loading_screen()
	if not _check(definition != null, "loading_screen.json is in the catalog"):
		return
	_check(not definition.sheet.begins_with("res://assets/") or ResourceLoader.exists(definition.sheet), "the sheet it names exists: %s" % definition.sheet)
	var sheet: Texture2D = load(definition.sheet) as Texture2D
	_check(sheet != null and sheet.get_width() % definition.columns == 0 and sheet.get_height() % definition.rows == 0, "the sheet cuts into whole cells")
	_check(definition.frames <= definition.columns * definition.rows and definition.caption, "its frames fit, and it says what it is doing")
	var errors: Array[String] = []
	LoadingScreenDefinition.from_record(ContentRecordReader.new({"columns": 2, "rows": 2, "frames": 5}, "loading", errors))
	_check(not errors.is_empty(), "more frames than the sheet has cells is refused")
	errors.clear()
	LoadingScreenDefinition.from_record(ContentRecordReader.new({"background": "not a colour"}, "loading", errors))
	_check(not errors.is_empty(), "a colour that is none is refused")
	errors.clear()
	LoadingScreenDefinition.from_record(ContentRecordReader.new({"sprite": "x"}, "loading", errors))
	_check(not errors.is_empty(), "an unknown key is refused")
	errors.clear()
	var plain: LoadingScreenDefinition = LoadingScreenDefinition.from_record(ContentRecordReader.new({}, "loading", errors))
	_check(errors.is_empty() and plain.sheet.is_empty() and plain.frames == 1, "with nothing said it is a plain dark screen")


## New Game has no fade of its own: dark at once, the world held, then the world comes up.
func _test_new_game(tree: SceneTree, session: WorldSessionController) -> void:
	await _frames(tree, 3)
	overlay = session.shared_ui().view_overlay
	var view: WorldVoxelView = _view(session)
	_check(overlay.loading() and overlay.shade_alpha() == 1.0, "New Game's first world comes up behind the cover")
	_check(view._building and not view._built, "over several frames, not in the first one")
	_check(session.presentation_held(HOLD) and session.world_time_held() and session.presentation_frozen(), "the world is held meanwhile")
	await _until_lifted(tree, session)
	_check(view._built and view.camera.current and (session.active_map() as WorldMapController).projected_view, "the world is up")
	_check(overlay.shade_alpha() == 0.0 and not session.world_time_held() and not (session.active_map() as WorldMapController).player_body.walk_paused, "the view is back and the player walks")


## A map whose world is kept shows nothing of this: no cover, not one frame of the screen.
func _test_kept_map(tree: SceneTree, session: WorldSessionController) -> void:
	await _go(tree, session, UPSTAIRS)
	var kept: WorldVoxelView = _view(session)
	_check(kept._built, "upstairs is built")
	await _go(tree, session, INN)
	var seen: bool = false
	MapPlaces.enter(session, UPSTAIRS[0], UPSTAIRS[1])
	for frame: int in 30:
		await tree.process_frame
		seen = seen or overlay.loading() or overlay.loading_screen().visible or kept._building or session.world_building()
	_check(not seen, "back on a kept map no cover shows, not for a frame")
	await _go(tree, session, INN)


## Frames take nobody's time: the clock, the random streams and the player stay where the
## handoff left them for as long as the cover is up, here past a heart beat (2 s), with NPCs
## on the map that would draw on it.
func _test_rules_stand_still(tree: SceneTree, session: WorldSessionController) -> void:
	_use({"map_loading_delay_ms": 0, "map_loading_min_ms": 2500})
	var map: WorldMapController = MapPlaces.enter(session, SMITHY[0], SMITHY[1])
	await _frames(tree, 2)
	_check(_view(session)._building, "the smithy builds")
	var before: Array = _rules(session, map)
	var steady: bool = true
	var frozen: bool = true
	var paused: bool = true
	while overlay.loading():
		await tree.process_frame
		if overlay.loading():
			steady = steady and _rules(session, map) == before
			frozen = frozen and session.presentation_frozen()
			paused = paused and map.player_body.walk_paused
	_check(steady, "clock, random streams, place and body do not move under the cover: %s vs %s" % [before, _rules(session, map)])
	_check(frozen, "nothing at all advances meanwhile")
	_check(paused, "the player stands")
	await _until_lifted(tree, session)
	_use({})
	await _go(tree, session, INN)


## Over frames or in one, the same shapes from the same seed.
func _test_same_world(tree: SceneTree, session: WorldSessionController) -> void:
	await _same_world(tree, session, UPSTAIRS, &"snow.inn_upstairs")
	# Outdoors: landmass, cliffs, water and plants, every breath of _terrain().
	await _same_world(tree, session, WILD, &"oldpine.outdoor")


func _same_world(tree: SceneTree, session: WorldSessionController, where: Array[StringName], map_id: StringName) -> void:
	var view: WorldVoxelView = _view_of(session, map_id)
	view.release_world()
	_check(not view._built, "%s's world is let go" % map_id)
	TestFeel.restore()
	MapPlaces.enter(session, where[0], where[1])
	_check(view._built or not view._building, "%s: no build under way before the frame" % map_id)
	await _frames(tree, 3)
	_check(view._built and not view._building and not overlay.loading(), "%s is built in one frame with the knob at 0" % map_id)
	var whole: Dictionary = _portrait(view)
	await _go(tree, session, INN)
	view.release_world()
	_use({})
	var frames: int = 0
	MapPlaces.enter(session, where[0], where[1])
	await _frames(tree, 2)
	while view._building:
		await tree.process_frame
		frames += 1
	await _until_lifted(tree, session)
	_check(frames > 3, "%s over frames this time: %d" % [map_id, frames])
	_check(session.active_map_id() == map_id and _portrait(view) == whole, "%s: the same world: %s vs %s" % [map_id, whole, _portrait(view)])
	await _go(tree, session, INN)
	view.release_world()


## Past the delay the picture comes, its frames follow the clock, it stays its minimum, and it
## leaves with the view.
func _test_picture(tree: SceneTree, session: WorldSessionController) -> void:
	_use({"map_loading_delay_ms": 0, "map_loading_min_ms": 150})
	var screen: WorldLoadingScreen = overlay.loading_screen()
	var map: WorldMapController = MapPlaces.enter(session, SMITHY[0], SMITHY[1])
	var view: WorldVoxelView = map.get_node("MapView") as WorldVoxelView
	view.release_world()
	await _frames(tree, 3)
	_check(screen.visible and screen.shown(), "with no delay the picture comes at once")
	var cells: Dictionary[int, bool] = {}
	while overlay.loading():
		cells[screen.frame_shown()] = true
		await tree.process_frame
	var stayed: int = Time.get_ticks_msec() - screen._shown_ms
	_check(stayed >= 145, "it stayed its minimum: %d ms" % stayed)
	_check(cells.size() >= 2, "its frames moved: %s" % [cells.keys()])
	await _until_lifted(tree, session)
	await _frames(tree, 3)
	_check(not screen.visible and screen.modulate.a == 0.0, "it left with the view")
	_check(overlay.shade_alpha() == 0.0, "nothing dark is left")
	await _go(tree, session, INN)
	view.release_world()


## Shorter than the delay no picture shows at all: only the dark a door has anyway.
func _test_small_room_stays_dark(tree: SceneTree, session: WorldSessionController) -> void:
	_use({})
	var screen: WorldLoadingScreen = overlay.loading_screen()
	var seen: bool = false
	MapPlaces.enter(session, SMITHY[0], SMITHY[1])
	await _frames(tree, 2)
	_check(overlay.loading(), "the cover is up")
	while overlay.loading() or session.presentation_held(HOLD):
		seen = seen or screen.shown() or screen.modulate.a > 0.0
		await tree.process_frame
	_check(not seen, "no picture came")
	_check(overlay.shade_alpha() == 0.0, "the dark lifted all the same")
	await _go(tree, session, INN)
	_view_of(session, &"snow.smithy_house").release_world()


## The walked way: dark, the new map, and one fade to the world; the picture and the dark go
## together, so the view never dips back. The arrival's banner waits for the view.
func _test_one_fade(tree: SceneTree, session: WorldSessionController) -> void:
	_use({"map_loading_delay_ms": 0, "map_loading_min_ms": 60, "map_fade_in_ms": 200})
	var map: WorldMapController = session.active_map() as WorldMapController
	_view_of(session, &"snow.outdoor").release_world()
	var portal: PortalDefinition = GameContent.catalog().portal(&"snow.inn.east")
	var area: WorldPassageArea2D = MapPlaces.passage(map, portal.portal_id)
	session.player_runtime().set_world_location(map.location_for_zone(portal.source_zone_id))
	map.player_body.global_position = area.global_position # TEST-ONLY: standing in the doorway
	await tree.physics_frame
	map.passage_requested.emit(portal)
	var was_dark: bool = false
	var last: float = 0.0
	var dipped: bool = false
	var banner_early: bool = false
	var limit: int = Time.get_ticks_msec() + 30000
	while (session.active_map_id() != &"snow.outdoor" or overlay.loading() or session.world_time_held()) and Time.get_ticks_msec() < limit:
		await tree.process_frame
		var cover: float = maxf(overlay.shade_alpha(), overlay.loading_screen().modulate.a)
		if was_dark and last < 1.0 and cover > last + 0.001:
			dipped = true
		was_dark = was_dark or cover == 1.0
		if was_dark:
			last = cover
		banner_early = banner_early or (overlay.loading() and not overlay.banner_text().is_empty())
	_check(session.active_map_id() == &"snow.outdoor", "out on the square")
	_check(was_dark and not dipped, "dark once, one fade back")
	_check(not banner_early, "no banner under the cover")
	_check(not session.world_time_held(), "the hold is gone with the fade")
	await _go(tree, session, INN)


## Under the cover a key press does nothing, and a room's text waits for the view.
func _test_under_the_cover(tree: SceneTree, session: WorldSessionController) -> void:
	_use({})
	_view_of(session, &"snow.smithy_house").release_world()
	MapPlaces.enter(session, SMITHY[0], SMITHY[1])
	await _frames(tree, 2)
	_check(overlay.loading(), "the cover is up")
	var key := InputEventKey.new()
	key.keycode = KEY_E
	overlay._input(key)
	_check(not overlay.get_viewport().is_input_handled(), "a release gets through, or a held key would stick")
	key.pressed = true
	overlay._input(key)
	tree.paused = true
	_check(not overlay.blocks_input(), "with the tree paused (a phone sent away) the shell's pause panel gets the keys")
	await _frames(tree, 3)
	_check(overlay.loading() and _view(session)._building, "the build waits out the pause")
	tree.paused = false
	_check(overlay.blocks_input(), "and the cover takes them again after it")
	overlay.show_room("铁匠铺", "炉火正旺。", 1.0)
	_check(overlay.room_text().is_empty(), "a room's text waits while the cover is up")
	await _until_lifted(tree, session)
	await _frames(tree, 4)
	_check(overlay.room_text().begins_with("铁匠铺"), "and shows once the view is back: %s" % overlay.room_text())
	await _go(tree, session, INN)
	# Told in the handoff's own frame, before the cover: it waits as well, its time unspent.
	_view_of(session, &"snow.smithy_house").release_world()
	MapPlaces.enter(session, SMITHY[0], SMITHY[1])
	overlay.show_room("铁匠铺", "门口。", 1.0)
	await tree.process_frame
	await tree.process_frame
	await _frames(tree, 2)
	_check(overlay.loading() and overlay.room_text().is_empty(), "a room told just before the cover waits under it")
	await _until_lifted(tree, session)
	await _frames(tree, 4)
	_check(overlay.room_text().ends_with("门口。"), "and shows after: %s" % overlay.room_text())
	await _go(tree, session, INN)


## Called away mid-build (what a fight's end or a kit can do): the half world goes, nothing
## stays held, and coming back builds it whole.
func _test_left_mid_build(tree: SceneTree, session: WorldSessionController) -> void:
	_use({})
	var view: WorldVoxelView = _view_of(session, &"snow.smithy_house")
	view.release_world()
	MapPlaces.enter(session, SMITHY[0], SMITHY[1])
	await _frames(tree, 3)
	_check(view._building, "the smithy is under way")
	MapPlaces.enter(session, INN[0], INN[1])
	_check(not view._building and not view._built and view.world == null and view.geometry == null, "its half world is gone")
	await _until_lifted(tree, session)
	await _frames(tree, 3)
	_check(not session.world_building() and not session.world_time_held() and overlay.shade_alpha() == 0.0, "nothing stays held or dark")
	await _go(tree, session, SMITHY)
	_check(view._built and view.world != null and view.camera.current, "coming back builds it whole")
	await _go(tree, session, INN)


## The switch: at 0 the build is the one long frame it was, with no cover.
func _test_off(tree: SceneTree, session: WorldSessionController) -> void:
	_use({"map_loading_slice_ms": 0})
	var view: WorldVoxelView = _view_of(session, &"snow.smithy_house")
	view.release_world()
	MapPlaces.enter(session, SMITHY[0], SMITHY[1])
	await _frames(tree, 3)
	_check(view._built and not view._building and not overlay.loading() and not session.presentation_held(HOLD), "built at once, no cover")
	_use({})
	await _go(tree, session, INN)
	view.release_world()


## The session going away mid-build leaves nothing running: a stray resume would be a script
## error here, and the gate fails on those.
func _test_session_gone_mid_build(tree: SceneTree, session: WorldSessionController) -> void:
	MapPlaces.enter(session, SMITHY[0], SMITHY[1])
	await _frames(tree, 3)
	_check(_view(session)._building, "the smithy is under way when the session goes")
	session.queue_free()
	await _frames(tree, 4)
	_check(not is_instance_valid(session), "the session is gone")


func _go(tree: SceneTree, session: WorldSessionController, where: Array[StringName]) -> void:
	MapPlaces.enter(session, where[0], where[1])
	await _frames(tree, 2)
	await _until_lifted(tree, session)


func _until_lifted(tree: SceneTree, session: WorldSessionController) -> void:
	var limit: int = Time.get_ticks_msec() + 30000
	while (overlay.loading() or session.presentation_held(HOLD)) and Time.get_ticks_msec() < limit:
		await tree.process_frame
	_check(not overlay.loading() and not session.presentation_held(HOLD), "the cover lifted in time")


func _use(values: Dictionary) -> void:
	var settings: Dictionary = QUICK.duplicate()
	settings.merge(values, true)
	GameContent.catalog().pacing().feel = FeelDefinition.new().with_values(settings)


func _view(session: WorldSessionController) -> WorldVoxelView:
	return (session.active_map() as Node).get_node("MapView") as WorldVoxelView


func _view_of(session: WorldSessionController, map_id: StringName) -> WorldVoxelView:
	return (session.resident_map(map_id) as Node).get_node("MapView") as WorldVoxelView


func _rules(session: WorldSessionController, map: WorldMapController) -> Array:
	return [session.day_clock().day_minutes(), Work.rng_state(session), map.player_body.global_position, session.player_runtime().world_location().zone_id]


## What the build made, shape by shape: every batch's size and colour, and where it begins.
func _portrait(view: WorldVoxelView) -> Dictionary:
	var batches: Array[String] = []
	for node: Node in view.world.find_children("*", "MultiMeshInstance3D", true, false):
		var instance := node as MultiMeshInstance3D
		var material := instance.material_override as StandardMaterial3D
		var colour: String = "" if material == null else material.albedo_color.to_html()
		var count: int = instance.multimesh.instance_count
		var first: Vector3 = Vector3.ZERO if count == 0 else instance.multimesh.get_instance_transform(0).origin
		batches.append("%d %s %s" % [count, colour, first])
	batches.sort()
	return {
		"batches": batches.size(),
		"shapes": "\n".join(batches).hash(),
		"lights": view.world.find_children("*", "Light3D", true, false).size(),
		"entrances": view.entrances.size(),
		"occluders": view.geometry.occluders.size(),
	}


func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.process_frame


func _check(ok: bool, label: String) -> bool:
	assertions += 1
	if not ok:
		failures.append(label)
	return ok
