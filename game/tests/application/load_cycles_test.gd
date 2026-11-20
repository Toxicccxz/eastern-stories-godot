extends RefCounted

## 稳定性检查 (2026-11-20): many loads in one run do not pile worlds up. Through the shell, twice
## each: 返回主菜单 and 继续, 系统 → 读取存档, a death and 回到上次自动存档. After each the world it
## replaced is gone (freed, not merely out of the tree), and from the first of a pair to the second
## Godot's object, node and orphan counts and its static memory stay within a bound: a world kept
## alive is some 100 000 objects and 130 MB. The measured run is tests/dev/perf/probe_memory.gd.
const MemoryFiles = preload("res://tests/application/application_shell_test.gd").MemoryFiles
const SHELL = preload("res://scenes/application/application_shell.tscn")
## What one more load may leave behind: caches warmed, a few ids. A kept world is far over these.
const OBJECTS_BOUND: int = 2000
const NODES_BOUND: int = 60
const STATIC_MB_BOUND: float = 12.0

var _count: int = 0
var _failures: Array[String] = []
var _shell: ApplicationShellController
var _tree: SceneTree


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_tree = tree
	TestDeath.use()
	var files: MemoryFiles = MemoryFiles.new()
	_shell = SHELL.instantiate()
	_shell.configure_before_start(GameSaveStorageProfile.isolated_test("load-cycles"), files, null, MemoryFiles.new())
	tree.root.add_child(_shell)
	await _frames(8)
	await _new_game()
	_check(await _save_by_hand(), "a save in slot 1")
	_check(await _autosave(), "an autosave of this journey")
	for kind: String in ["menu", "load", "death"]:
		var first: Dictionary = await _cycle(kind)
		var second: Dictionary = await _cycle(kind)
		if first.is_empty() or second.is_empty():
			continue
		_check(second["objects"] - first["objects"] < OBJECTS_BOUND, "%s twice: objects %d → %d" % [kind, first["objects"], second["objects"]])
		_check(second["nodes"] - first["nodes"] < NODES_BOUND, "%s twice: nodes %d → %d" % [kind, first["nodes"], second["nodes"]])
		_check(second["orphans"] - first["orphans"] < NODES_BOUND, "%s twice: orphan nodes %d → %d" % [kind, first["orphans"], second["orphans"]])
		_check(second["static_mb"] - first["static_mb"] < STATIC_MB_BOUND, "%s twice: static memory %.1f → %.1f MB" % [kind, first["static_mb"], second["static_mb"]])
	_shell.free()
	await _frames(4)
	TestDeath.restore()
	return {"assertions": _count, "failures": _failures}


## One reload of `kind`; the counts once the new world plays, or empty if it never did.
func _cycle(kind: String) -> Dictionary:
	var before: WeakRef = weakref(_session())
	var old_id: int = _session().get_instance_id()
	match kind:
		"menu":
			_check(_shell.request_pause() and _shell.request_return_to_main_menu() and _shell.confirm_current_result(), "返回主菜单")
			_check(await _until(func() -> bool: return _shell.shell_state().mode() == ApplicationShellState.Mode.MAIN_MENU and _shell.continue_enabled()), "on the main menu, 继续 offered")
			_check(_shell.request_continue_from_menu(), "继续")
		"load":
			_check(_shell.request_pause() and _shell.request_load_slots() and _shell.choose_slot_row(0) and _shell.confirm_current_result(), "系统 → 读取存档 → slot 1")
		"death":
			var session: WorldSessionController = _session()
			session.player_runtime().state.vitality.effective = -1 # TEST-ONLY: a mortal wound
			(session.active_map() as WorldMapController).player_fall_below_zero()
			await _tree.physics_frame
			await _frames(3)
			_check(_shell.autosave_to_return_to() != null, "the death card can go back to the autosave")
			session.shared_ui().life_overlay.return_to_autosave()
			_check(_shell.confirm_current_result(), "回到上次自动存档")
	var playing: bool = await _until(func() -> bool: return _session() != null and _session().get_instance_id() != old_id and _playing())
	_check(playing, "%s: a new world, playing" % kind)
	if not playing:
		return {}
	await _frames(10)
	_check(before.get_ref() == null, "%s: the world it replaced is freed" % kind)
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	}


func _new_game() -> void:
	if _shell.request_new_game_from_menu() and _shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		_shell.confirm_current_result()
	_shell.runtime_host().opening_card = false
	_shell.player_name_edit.text = "凌雪"
	_shell.select_new_game_gender(CharacterState.GENDER_FEMALE)
	_check(_shell.submit_new_game_setup(), "New Game")
	_check(await _until(_playing), "playing")


func _save_by_hand() -> bool:
	if not (_shell.request_pause() and _shell.request_save_slots() and _shell.choose_slot_row(0)):
		return false
	await _until(func() -> bool: return _shell.shell_state().mode() != ApplicationShellState.Mode.SAVING)
	_shell.dismiss_current_result()
	if _shell.shell_state().mode() == ApplicationShellState.Mode.PAUSED:
		_shell.request_resume()
	return await _until(_playing)


func _autosave() -> bool:
	var host: OldPineGameRuntimeHost = _shell.runtime_host()
	if not host.autosave().begin(_session()):
		return false
	await _until(func() -> bool: return not host.autosave().running())
	await _frames(2)
	return _shell.autosave_to_return_to() != null


func _session() -> WorldSessionController:
	return _shell.runtime_host().current_session()


func _playing() -> bool:
	var session: WorldSessionController = _session()
	return (
		_shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING and not _tree.paused
		and session != null and session.start_finished() and not session.world_building()
	)


func _until(done: Callable, limit: int = 6000) -> bool:
	for _frame: int in limit:
		if done.call():
			return true
		await _tree.process_frame
	return done.call()


func _frames(count: int) -> void:
	for _frame: int in count:
		await _tree.process_frame


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures.append(label)
