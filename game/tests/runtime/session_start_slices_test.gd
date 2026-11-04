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
## played) at every frame boundary before that.
func _follow(tree: SceneTree, session: WorldSessionController) -> Dictionary:
	var frames: int = 0
	var inert: bool = true
	while is_instance_valid(session) and not session.start_finished() and frames < 3000:
		await tree.process_frame
		frames += 1
		inert = inert and (session.start_finished() or (session.process_mode == Node.PROCESS_MODE_DISABLED and session.played_seconds() == 0))
	return {"frames": frames, "inert": inert}


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
	var finished: OldPineWorldRestoreResult = OldPineWorldRestoreService.finish_candidate(begun)
	if finished.succeeded():
		finished.candidate.set_process(false)
	_check(finished.succeeded() and finished.candidate.activate_restore_candidate(), "then it is checked and activated as before")
	if finished.succeeded():
		_check(_save_text(finished.candidate) == text, "the same world as the save")
		finished.candidate.free()
		await tree.process_frame


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


func _while_pending(tree: SceneTree, host: OldPineGameRuntimeHost) -> int:
	var frames: int = 0
	await tree.process_frame
	while host.request_pending() and frames < 3000:
		await tree.process_frame
		frames += 1
	return frames + 1
