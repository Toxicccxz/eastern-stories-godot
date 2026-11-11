extends RefCounted

## 章与章之间的衔接: the main story played on one session from New Game, 寻剑令 through 逆灵宫's
## rescue, each chapter going on from what the one before it left — no StoryFixtures write. Between
## the chapters the player walks (MapPlaces.go_to: the portals and the streets) to where the next
## one begins; inside a chapter its own suite's play runs as it does there (each chapter's suite
## is the one that tells what it does). A chapter that only works on its fixture's ledger, not on
## the played one, fails here. Later chapters join as they are chained (this first reach: 第三章).
const Decree := preload("res://tests/runtime/sword_decree_test.gd")
const Chapter1 := preload("res://tests/runtime/story_chapter1_test.gd")
const Chapter2 := preload("res://tests/runtime/story_chapter2_test.gd")
const Chapter3Entry := preload("res://tests/runtime/story_chapter3_entry_test.gd")
const Chapter3 := preload("res://tests/runtime/story_chapter3_test.gd")
const Chapter3B := preload("res://tests/runtime/story_chapter3b_test.gd")
const Chapter3C := preload("res://tests/runtime/story_chapter3c_test.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	# 放过 is a choice only under 询问 (伪墓's 黑衣道士; the suites run 直接了结).
	var knockout_before: int = BattlePace.after_knockout
	BattlePace.after_knockout = BattlePace.AfterKnockout.ASK
	var session: WorldSessionController = await Decree.new()._session(tree)
	await _through(tree, session)
	session.free()
	await tree.process_frame
	BattlePace.after_knockout = knockout_before
	return {"assertions": _count, "failures": _failures.duplicate()}


func _through(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	if not await _chapter(tree, "寻剑令", Decree.new(), func(suite: RefCounted) -> void: await suite._test_decree(tree, session, true)):
		return
	# 伪墓 begins in 老松林: up the road north out of 雪亭镇.
	if not await _walk(tree, session, &"oldpine.outdoor.central_clearing", "寻剑令 → 伪墓"):
		return
	if not await _chapter(tree, "伪墓", Chapter1.new(), func(suite: RefCounted) -> void: await suite._test_chapter(tree, session, true)):
		return
	# 旧案 begins at 淳风武馆: back down the mountain.
	if not await _walk(tree, session, &"snow.school2", "伪墓 → 旧案"):
		return
	if not await _chapter(tree, "旧案", Chapter2.new(), func(suite: RefCounted) -> void: await suite._test_chapter(tree, session, true)):
		return
	if not await _walk(tree, session, &"snow.square", "旧案 → 逆灵宫"):
		return
	if not await _chapter(tree, "逆灵宫 (the entrance)", Chapter3Entry.new(), func(suite: RefCounted) -> void: await suite._test_entrance(tree, session, true)):
		return
	if not await _walk(tree, session, &"goathill.mroad4", "the entrance → the turn"):
		return
	if not await _chapter(tree, "逆灵宫 A", Chapter3.new(), func(suite: RefCounted) -> void: await suite._test_ways(tree, session, true)):
		return
	# B begins on the goods road before the 山门 (the 黑冠 put on there): back out of the yard.
	if not await _walk(tree, session, &"niling.goods_path", "逆灵宫 A → B"):
		return
	if not await _chapter(tree, "逆灵宫 B", Chapter3B.new(), func(suite: RefCounted) -> void: await suite._test_hall_and_dungeon(tree, session, true)):
		return
	if not await _walk(tree, session, &"niling.goods_path", "逆灵宫 B → C"):
		return
	var rescue: RefCounted = Chapter3C.new()
	if not await _chapter(tree, "逆灵宫 C (the altar)", rescue, func(suite: RefCounted) -> void: await suite._test_scene_and_ghosts(tree, session, true, true)):
		return
	if not await _chapter(tree, "逆灵宫 C (the rescue)", rescue, func(suite: RefCounted) -> void: await suite._test_rescue(tree, session, true)):
		return
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter3")
	_check(StoryQuestLog.is_done(state, quest) and state.marks.get("逆灵宫一章", 0) == 1, "played through: 逆灵宫 done (%s)" % [StoryQuestLog.objective(state, GameContent.catalog().story_quests())])
	# Save at the end of the run (each chapter's own suite reads its save back; a whole-world round trip
	# here would compare the TEST-ONLY maxima 伪墓 gives, which Continue derives again).
	var walker: RefCounted = (load("res://tests/runtime/snow_work_income_test.gd") as GDScript).new()
	_check(OldPineSaveEligibility.inspect(session).allowed() and walker.capture(session) != null, "the played-through world may be saved, and is")


## One chapter's play from its own suite on this session; its checks count here, named by the
## chapter. False when one failed (the next chapter would go on from a wrong state).
func _chapter(tree: SceneTree, title: String, suite: RefCounted, play: Callable) -> bool:
	# TEST-ONLY: the message log as a chapter's own suite starts it (empty): it keeps the last
	# sixty lines, and a suite reading what was said after a line counts from where it stood.
	_session_ui(tree).message_log._log_lines.clear()
	var failed_before: int = suite._failures.size()
	var counted_before: int = suite._count
	await play.call(suite)
	_count += suite._count - counted_before
	var failed: Array = suite._failures.slice(failed_before)
	for failure: Variant in failed:
		_failures.append("%s: %s" % [title, failure])
	await tree.process_frame
	return failed.is_empty()


func _session_ui(tree: SceneTree) -> SharedGameplayUI:
	for node: Node in tree.root.get_children():
		if node is WorldSessionController:
			return (node as WorldSessionController).shared_ui()
	return null


## Walks to `zone_id` the way the game's guide leads (WorldRoute.guided(): as few hidden hops as can
## be, a climb or a landmark's way only where nothing plain goes), through each step's passage on
## foot, then into the zone; a failed walk says where it stopped.
func _walk(tree: SceneTree, session: WorldSessionController, zone_id: StringName, label: String) -> bool:
	var from: StringName = session.player_runtime().world_location().zone_id
	# A chapter's suite may leave the menu or a panel open (its last look at the 任务 page): shut, as
	# the player does before walking on.
	session.shared_ui().close_menu()
	session.shared_ui().dismiss_current_panel()
	await tree.process_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var target: StringName = MapPlaces.map_of(zone_id)
	var chain: Array[WorldRoute.Step] = WorldRoute.guided(GameContent.catalog(), map.map_id(), target)
	if not _check(not chain.is_empty() or map.map_id() == target, "%s: a way from %s to %s" % [label, map.map_id(), target]):
		return false
	for step: WorldRoute.Step in chain:
		var portal: PortalDefinition = step.portal
		if not _check(portal != null, "%s: the way from %s goes by a room command (%s), not walked here" % [label, step.from_map, step.service.service_id if step.service != null else &""]):
			return false
		var at: StringName = session.player_runtime().world_location().zone_id
		if at != portal.source_zone_id and not await _drive_opening(tree, map, portal.source_zone_id):
			return _check(false, "%s: from %s, walked %s → %s (to %s) and stopped at %s" % [label, from, at, portal.source_zone_id, portal.portal_id, session.player_runtime().world_location().zone_id])
		var taken: bool = await _use_landmark(tree, map, portal) if MapPlaces.passage(map, portal.portal_id) == null else await MapPlaces.take_passage(tree, map, portal.portal_id)
		if not taken:
			return _check(false, "%s: from %s, %s not taken at %s" % [label, from, portal.portal_id, session.player_runtime().world_location().zone_id])
		map = session.active_map() as WorldMapController
		await tree.physics_frame
	var arrived: bool = await _drive_opening(tree, map, zone_id)
	return _check(arrived and session.player_runtime().world_location().zone_id == zone_id, "%s: walked from %s to %s (at %s)" % [label, from, zone_id, session.player_runtime().world_location().zone_id])


## Into `zone_id` on this map; where a shut door stands in the way, the player opens one off the
## room they stopped in (the 山门 from the yard) and walks on.
func _drive_opening(tree: SceneTree, map: WorldMapController, zone_id: StringName) -> bool:
	for attempt: int in 4:
		if await MapPlaces.drive_to_zone(tree, map, zone_id):
			return true
		var here: StringName = map.player_runtime().world_location().zone_id
		var opened: bool = false
		for door: WorldDoor in map.doors():
			var definition: DoorDefinition = GameContent.catalog().door(door.door_id)
			if door.is_open() or definition == null or not definition.zone_ids().has(here):
				continue
			if await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, door.door_id, here)) and map.open_door(door.door_id):
				opened = true
				break
		if not opened:
			return false
	return false


## A way used at a landmark rather than walked onto (a cliff climbed: 攀爬石壁, 往上爬): to it, and
## its action; true once the player is off this map.
func _use_landmark(tree: SceneTree, map: WorldMapController, portal: PortalDefinition) -> bool:
	for area: Node in map.find_children("*", "WorldLandmarkArea2D", true, false):
		var landmark: WorldLandmarkDefinition = GameContent.catalog().landmark((area as WorldLandmarkArea2D).landmark_id)
		if landmark == null or not landmark.portal_ids().has(portal.portal_id):
			continue
		var spot: Vector2 = MapPlaces.spot(map, landmark.zone_id, (area as Node2D).global_position, 48.0)
		if spot.is_finite():
			await MapPlaces.drive(tree, map, spot)
		if not map.select_landmark(landmark.landmark_id):
			return false
		map.traverse_selected_portal()
		for _frame: int in 30:
			if not map.is_inside_tree():
				return true
			await tree.physics_frame
		return not map.is_inside_tree()
	return false


func _check(ok: bool, label: String) -> bool:
	_count += 1
	if not ok:
		_failures.append(label)
	return ok
