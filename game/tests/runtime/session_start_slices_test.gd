extends RefCounted

## A journey's start in slices (DECISIONS「加载画面」): with the feel's session_start_slice_ms
## the world is built a little each frame while the title plays, standing still between them,
## and it is the same world as the one-frame start the suites use — New Game and Continue alike;
## through the host, every way a journey starts goes over frames and ends where it did.
const ShellTests = preload("res://tests/application/application_shell_test.gd")
const SESSION_SCENE: PackedScene = preload("res://scenes/world/oldpine/oldpine_world_session.tscn")
const HOST_SCENE: PackedScene = preload("res://scenes/runtime/oldpine_game_runtime_host.tscn")
const TIMESTAMP: String = "2026-11-04T12:00:00Z"

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	var feel: FeelDefinition = pacing.feel
	await _test_new_game(tree)
	await _test_continue(tree)
	await _test_failed_continue(tree)
	pacing.feel = feel.but({"map_loading_slice_ms": 40})
	await _test_first_world(tree)
	pacing.feel = feel.but({"session_start_slice_ms": 2})
	await _test_host(tree)
	pacing.feel = feel
	return {"assertions": assertions, "failures": failures}


func _check(condition: bool, message: String) -> bool:
	assertions += 1
	if not condition:
		failures.append(message)
	return condition


func _session(slice_usec: int) -> WorldSessionController:
	var session: WorldSessionController = SESSION_SCENE.instantiate()
	session.configure_source_entry("分帧", CharacterState.GENDER_FEMALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	session.start_slice_usec = slice_usec
	return session


func _save_text(session: WorldSessionController) -> String:
	var captured: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", TIMESTAMP)
	if captured.outcome != OldPineWorldCaptureResult.Outcome.SUCCESS:
		return ""
	return GameSaveJsonCodec.encode(captured.snapshot).text


## A New Game's save with its item-id scope (new for every session) masked: two worlds made
## alike save alike.
func _world_text(session: WorldSessionController) -> String:
	var text: String = _save_text(session)
	if text.is_empty():
		return ""
	var scope: String = str((JSON.parse_string(text) as Dictionary).get("item_id_allocator", {}).get("scope", ""))
	return text if scope.is_empty() else text.replace(scope, "SCOPE")


## Frames until `session`'s start is over; whether it stood still (no processing, no time
## played) at every frame boundary before that; the boundaries a map was in the tree at (`held`:
## its people are made a spawn at a time), and whether each such map was unseen, standing
## still and with its tile layers off (`unseen`).
func _follow(tree: SceneTree, session: WorldSessionController) -> Dictionary:
	var frames: int = 0
	var inert: bool = true
	var held: int = 0
	var unseen: bool = true
	while is_instance_valid(session) and not session.start_finished() and frames < 6000:
		await tree.process_frame
		frames += 1
		inert = inert and (session.start_finished() or (session.process_mode == Node.PROCESS_MODE_DISABLED and session.played_seconds() == 0))
		if session.start_finished():
			break
		for child: Node in session.active_map_slot.get_children():
			var map: WorldResidentMapController = child as WorldResidentMapController
			held += 1
			unseen = unseen and map != null and not map.visible and map.process_mode == Node.PROCESS_MODE_DISABLED and not map.is_map_initialized() and _layers(map, false) and _areas_quiet(map)
	return {"frames": frames, "inert": inert, "held": held, "unseen": unseen}


## Whether every tile layer of `map` is on (`enabled`) or every one off.
func _layers(map: Node, enabled: bool) -> bool:
	for node: Node in map.find_children("*", "TileMapLayer", true, false):
		if (node as TileMapLayer).enabled != enabled:
			return false
	return true


## No area of `map` watches or is watched (a staged map's).
func _areas_quiet(map: Node) -> bool:
	for node: Node in map.find_children("*", "Area2D", true, false):
		if (node as Area2D).monitoring or (node as Area2D).monitorable:
			return false
	return true


func _test_new_game(tree: SceneTree) -> void:
	var whole: WorldSessionController = _session(0)
	tree.root.add_child(whole)
	_check(whole.start_finished() and whole.is_initialized(), "with no slice a New Game's start is over within add_child")
	whole.set_process(false)
	var text: String = _world_text(whole)
	_check(not text.is_empty(), "the one-frame world saves")
	whole.free()
	await tree.process_frame
	var sliced: WorldSessionController = _session(1)
	tree.root.add_child(sliced)
	_check(not sliced.start_finished() and not sliced.is_initialized(), "with a slice it goes on after add_child")
	var seen: Dictionary = await _follow(tree, sliced)
	_check(sliced.start_finished() and sliced.is_initialized() and sliced.active_map_id() == &"snow.inn", "and is over some frames later, in the inn")
	_check(seen["frames"] > 100, "a frame for every map or so: %d frames" % seen["frames"])
	_check(seen["inert"], "the world stood still between the frames")
	# A town's people are several frames' share: frames go by inside a map too, the map there.
	_check(seen["held"] > 400, "a map's people are made a spawn at a time, frames going by between: %d" % seen["held"])
	_check(seen["unseen"], "a map in the tree at a frame's end is unseen, standing still, its areas quiet and its tile layers off")
	var as_it_was: bool = true
	for map: WorldMapController in sliced.world_maps():
		as_it_was = as_it_was and map.visible and not map.starts_in_steps and _layers(map, true) and map.is_map_initialized()
	_check(as_it_was and sliced.active_map_child_count() == 1, "afterwards every map is shown and its layers on, as a one-frame start leaves them")
	_check(sliced.process_mode == Node.PROCESS_MODE_INHERIT and sliced.get_node_or_null("StartPump") == null, "then it runs as any session, the pump gone")
	sliced.set_process(false)
	_check(_world_text(sliced) == text, "the same world as the one-frame start")
	sliced.free()
	await tree.process_frame


func _test_continue(tree: SceneTree) -> void:
	var world: WorldSessionController = _session(0)
	tree.root.add_child(world)
	world.set_process(false)
	var text: String = _save_text(world)
	world.free()
	await tree.process_frame
	var whole: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(GameSaveJsonCodec.decode(text).snapshot, tree.root)
	if whole.succeeded():
		whole.candidate.set_process(false)
	_check(whole.succeeded() and whole.candidate.start_finished() and whole.candidate.activate_restore_candidate(), "with no slice Continue's candidate is built within add_child")
	if whole.succeeded():
		_check(_save_text(whole.candidate) == text, "and saves the same")
		whole.candidate.free()
		await tree.process_frame
	var begun: OldPineWorldRestoreResult = OldPineWorldRestoreService.begin_candidate(GameSaveJsonCodec.decode(text).snapshot, tree.root, 1)
	if not _check(begun.candidate != null and not begun.candidate.start_finished(), "with a slice Continue's candidate goes on after it is added"):
		return
	var seen: Dictionary = await _follow(tree, begun.candidate)
	_check(seen["frames"] > 100 and seen["inert"], "over many frames, standing still: %d" % seen["frames"])
	_check(seen["unseen"], "a saved map in the tree at a frame's end is unseen and still as well (%d)" % seen["held"])
	var finished: OldPineWorldRestoreResult = OldPineWorldRestoreService.finish_candidate(begun)
	if finished.succeeded():
		finished.candidate.set_process(false)
	_check(finished.succeeded() and finished.candidate.activate_restore_candidate(), "then it is checked and activated as before")
	if finished.succeeded():
		_check(_save_text(finished.candidate) == text, "the same world as the save")
		finished.candidate.free()
		await tree.process_frame


## The first map's world is built under the title, still playing: at the start's share of a
## frame, not the loading screen's long one; every world after it at the loading screen's.
func _test_first_world(tree: SceneTree) -> void:
	var whole: WorldSessionController = _session(0)
	tree.root.add_child(whole)
	whole.set_process(false)
	_check(whole.world_building_slice_usec() == 40000, "a one-frame start's first world is built at the loading screen's share")
	whole.free()
	await tree.process_frame
	var sliced: WorldSessionController = _session(3000)
	tree.root.add_child(sliced)
	await _follow(tree, sliced)
	sliced.set_process(false)
	_check(sliced.start_finished() and sliced.world_building_slice_usec() == 3000, "a start in slices builds its first world at the start's share")
	sliced.set_world_building(true)
	_check(sliced.world_building_slice_usec() == 3000, "while it is being built")
	sliced.set_world_building(false)
	_check(sliced.world_building_slice_usec() == 40000, "and the worlds after it at the loading screen's")
	sliced.start_slice_usec = 90000
	sliced._worlds_built = 0
	_check(sliced.world_building_slice_usec() == 40000, "never a longer share than the loading screen's")
	sliced.free()
	await tree.process_frame


## A save that no longer fits (the player off the map, as an old save after a layout change)
## fails over frames as it fails in one: the same refusal, nothing left standing or locked.
## (The failed candidate is freed once its own start_done is over, never inside it.)
func _test_failed_continue(tree: SceneTree) -> void:
	var world: WorldSessionController = _session(0)
	tree.root.add_child(world)
	world.set_process(false)
	var text: String = _save_text(world)
	world.free()
	await tree.process_frame
	var record: Dictionary = JSON.parse_string(text)
	record["player"]["map_position"] = {"x": -99999.0, "y": -99999.0}
	var files := ShellTests.MemoryFiles.new()
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("start-slices-bad")
	files.write_bytes(profile.canonical_path(), JSON.stringify(record, "", false, true).to_utf8_buffer())
	var coordinator := OldPineSessionLoadCoordinator.new(GameSaveRepository.new(profile, files))
	var session_slot := Node.new()
	var staging_slot := Node.new()
	tree.root.add_child(session_slot)
	tree.root.add_child(staging_slot)
	var whole: OldPineRuntimeSaveLoadResult = coordinator.load_replacing(null, session_slot, staging_slot)
	_check(not whole.succeeded() and whole.restore != null and whole.restore.outcome == OldPineWorldRestoreResult.Outcome.INVALID_PHYSICAL_POSITION, "the one-frame Continue refuses a player off the map: %s" % whole.outcome)
	await tree.process_frame
	var sliced: OldPineRuntimeSaveLoadResult = await coordinator.load_replacing_in_slices(null, session_slot, staging_slot, 1, tree.process_frame)
	_check(sliced != null and not sliced.succeeded() and sliced.outcome == whole.outcome and sliced.restore != null and sliced.restore.outcome == whole.restore.outcome, "the sliced one refuses it the same way")
	await tree.process_frame
	_check(staging_slot.get_child_count() == 0 and session_slot.get_child_count() == 0 and not coordinator.operation_in_progress(), "nothing is left standing, the coordinator free again")
	session_slot.free()
	staging_slot.free()


## Through the host: New Game, Save, a Load in play, back to the main menu and Continue —
## each start goes over frames and ends with the world it always had.
func _test_host(tree: SceneTree) -> void:
	var host: OldPineGameRuntimeHost = HOST_SCENE.instantiate()
	host.configure_manual_before_start(GameSaveStorageProfile.isolated_test("start-slices"), ShellTests.MemoryFiles.new())
	tree.root.add_child(host)
	host.opening_card = false
	_check(host.request_new_game("分帧", CharacterState.GENDER_FEMALE), "New Game is asked for")
	var frames: int = await _while_pending(tree, host)
	_check(host.last_new_game_result() != null and host.last_new_game_result().succeeded() and host.current_session() != null and host.current_session().is_initialized(), "New Game reaches the world")
	_check(frames > 3, "New Game over several frames: %d" % frames)
	_check(host.request_save(), "a save is asked for")
	await _while_pending(tree, host)
	_check(host.last_save_result() != null and host.last_save_result().succeeded(), "the world saves")
	var first: WorldSessionController = host.current_session()
	_check(host.request_load(), "a Load in play is asked for")
	frames = await _while_pending(tree, host)
	_check(host.last_load_result() != null and host.last_load_result().succeeded() and host.current_session() != first and host.session_invariant_holds(), "the Load replaces the world")
	_check(frames > 3, "the Load over several frames: %d" % frames)
	var loaded_text: String = _save_text(host.current_session())
	_check(host.request_end_session(), "back to the main menu")
	await _while_pending(tree, host)
	await tree.process_frame
	_check(host.request_continue(), "Continue is asked for")
	frames = await _while_pending(tree, host)
	_check(host.last_load_result() != null and host.last_load_result().succeeded() and host.session_invariant_holds(), "Continue reaches the world")
	_check(frames > 3, "Continue over several frames: %d" % frames)
	_check(not loaded_text.is_empty() and _save_text(host.current_session()) == loaded_text, "Continue's world is the Load's")
	host.free()
	await tree.process_frame


## The frames a request takes. Its limit is the clock's, not a frame count: a save is read on a
## worker thread while the frames run on, as fast as they come.
func _while_pending(tree: SceneTree, host: OldPineGameRuntimeHost) -> int:
	var frames: int = 0
	var limit: int = Time.get_ticks_msec() + 60_000
	await tree.process_frame
	while host.request_pending() and Time.get_ticks_msec() < limit:
		await tree.process_frame
		frames += 1
	return frames + 1
