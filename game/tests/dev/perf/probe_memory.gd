extends SceneTree

## Measuring kit for memory over many loads in one run (稳定性检查, 2026-11-20): the real shell on
## an isolated save profile (the player's own saves are not touched), played as a player plays it,
## the process's memory and Godot's object counts read after each round. Each world the round left
## behind is watched through a WeakRef: one still there after the next is up is a world kept alive.
## Self-contained (no test helpers), like probe_perf.gd.
##
##   <godot> [--headless] --path game --script res://tests/dev/perf/probe_memory.gd -- <mode> <out.json> [rounds] [seconds]
##
## Modes (each round ends with `seconds` of play, standing in the world):
##   menu    存档 by hand, 返回主菜单, 继续.
##   load    系统 → 读取存档 → the save made at the start.
##   death   a mortal wound, 回到上次自动存档 on the death card.
## Rounds default to 10; seconds to 60 (menu) or 15 (load, death).

const SHELL_SCENE: String = "res://scenes/application/application_shell.tscn"
const PROFILE: String = "memory-probe"
const LIMIT_FRAMES: int = 20000

var _shell: ApplicationShellController
var _report: Dictionary = {}
var _out: String = ""
var _worlds: Array[WeakRef] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "menu"
	_out = args[1] if args.size() > 1 else "user://memory_probe.json"
	var rounds: int = int(args[2]) if args.size() > 2 else 10
	var seconds: float = float(args[3]) if args.size() > 3 else (60.0 if mode == "menu" else 15.0)
	_report = {"mode": mode, "rounds": rounds, "seconds": seconds, "build": BuildIdentity.log_line(), "headless": DisplayServer.get_name() == "headless"}
	_report["before_shell"] = _measure()
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ApplicationShellController
	_shell.configure_before_start(GameSaveStorageProfile.isolated_test(PROFILE))
	root.add_child(_shell)
	_shell.lifecycle_adapter().pause_on_focus_loss = false
	if not await _until(func() -> bool: return _shell.shell_state().mode() == ApplicationShellState.Mode.MAIN_MENU):
		_finish("no main menu")
		return
	if not await _new_game():
		return
	await _seconds(seconds)
	var samples: Array[Dictionary] = [_sample(0)]
	print("PROBE round 0: %s" % JSON.stringify(samples[0]))
	if mode == "load" and not await _save_by_hand():
		_finish("存档 refused")
		return
	if mode == "death" and not await _autosave_now():
		_finish("no autosave")
		return
	for index: int in rounds:
		_worlds.append(weakref(_session()))
		var failure: String = ""
		match mode:
			"menu":
				failure = await _menu_round()
			"load":
				failure = await _load_round()
			"death":
				failure = await _death_round()
			_:
				failure = "unknown mode %s" % mode
		if not failure.is_empty():
			_report["samples"] = samples
			_finish("round %d: %s" % [index + 1, failure])
			return
		await _seconds(seconds)
		samples.append(_sample(index + 1))
		print("PROBE round %d: %s" % [index + 1, JSON.stringify(samples[-1])])
	_report["samples"] = samples
	_finish("")


# --- rounds --------------------------------------------------------------------------------

func _menu_round() -> String:
	if not await _save_by_hand():
		return "存档 refused"
	if not (_shell.request_pause() and _shell.request_return_to_main_menu()):
		return "返回主菜单 refused"
	if _shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		_shell.confirm_current_result()
	if not await _until(func() -> bool: return _shell.shell_state().mode() == ApplicationShellState.Mode.MAIN_MENU and _shell.continue_enabled()):
		return "never back on the main menu"
	await _seconds(1.0)
	if not _shell.request_continue_from_menu():
		return "继续 refused"
	return "" if await _until(_playing) else "never playing after 继续"


func _load_round() -> String:
	if not (_shell.request_pause() and _shell.request_load_slots()):
		return "读取存档 refused"
	if not _shell.choose_slot_row(0):
		return "slot 1 refused"
	if _shell.shell_state().mode() == ApplicationShellState.Mode.RESULT and not _shell.confirm_current_result():
		return "读取 refused"
	return "" if await _until(_playing) else "never playing after 读取"


func _death_round() -> String:
	var session: WorldSessionController = _session()
	session.player_runtime().state.vitality.effective = -1 # PROBE-ONLY: a mortal wound
	(session.active_map() as WorldMapController).player_fall_below_zero()
	await physics_frame
	await _frames(3)
	var overlay: PlayerLifeOverlay = session.shared_ui().life_overlay
	if not await _until(func() -> bool: return _shell.autosave_to_return_to() != null, 600):
		return "no autosave of this journey to go back to"
	overlay.return_to_autosave()
	if _shell.shell_state().mode() != ApplicationShellState.Mode.RESULT or not _shell.confirm_current_result():
		return "回到上次自动存档 refused"
	var old_id: int = session.get_instance_id()
	if not await _until(func() -> bool: return _session() != null and _session().get_instance_id() != old_id and _playing()):
		return "never playing after 回到上次自动存档"
	return ""


func _new_game() -> bool:
	_shell.runtime_host().opening_card = false
	if _shell.request_new_game_from_menu() and _shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		_shell.confirm_current_result()
	_shell.player_name_edit.text = "量"
	_shell.select_new_game_gender(CharacterState.GENDER_FEMALE)
	if not _shell.submit_new_game_setup():
		_finish("新的旅程 refused")
		return false
	if not await _until(_playing):
		_finish("never playing")
		return false
	return true


## 系统 → 存档 → slot 1 (overwritten after the first time), back to playing.
func _save_by_hand() -> bool:
	if not (_shell.request_pause() and _shell.request_save_slots() and _shell.choose_slot_row(0)):
		return false
	if _shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		_shell.confirm_current_result()
	await _until(func() -> bool: return _shell.shell_state().mode() != ApplicationShellState.Mode.SAVING)
	_shell.dismiss_current_result()
	if _shell.shell_state().mode() == ApplicationShellState.Mode.PAUSED:
		_shell.request_resume()
	return await _until(_playing)


func _autosave_now() -> bool:
	var host: OldPineGameRuntimeHost = _shell.runtime_host()
	if not host.autosave().begin(_session()):
		return false
	await _until(func() -> bool: return not host.autosave().running())
	await _frames(2)
	return _shell.autosave_to_return_to() != null


# --- measuring -----------------------------------------------------------------------------

func _sample(index: int) -> Dictionary:
	var sample: Dictionary = _measure()
	sample["round"] = index
	var alive: int = 0
	for world: WeakRef in _worlds:
		alive += 1 if world.get_ref() != null else 0
	sample["old_worlds_alive"] = alive
	return sample


func _measure() -> Dictionary:
	var sample: Dictionary = {
		"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
	}
	var process: Dictionary = _process_memory()
	sample.merge(process)
	return sample


## The process's resident and private memory as the system counts them (Windows and Linux).
func _process_memory() -> Dictionary:
	var pid: int = OS.get_process_id()
	if OS.get_name() == "Windows":
		var output: Array = []
		OS.execute("powershell", ["-NoProfile", "-Command", "$p = Get-Process -Id %d; '{0} {1}' -f $p.WorkingSet64, $p.PrivateMemorySize64" % pid], output)
		var parts: PackedStringArray = String(output[0] if not output.is_empty() else "").strip_edges().split(" ")
		if parts.size() == 2:
			return {"rss_mb": roundi(int(parts[0]) / 1048576.0), "private_mb": roundi(int(parts[1]) / 1048576.0)}
	elif FileAccess.file_exists("/proc/self/status"):
		for line: String in FileAccess.get_file_as_string("/proc/self/status").split("\n"):
			if line.begins_with("VmRSS:"):
				return {"rss_mb": roundi(int(line.split(":")[1].strip_edges().split(" ")[0]) / 1024.0)}
	return {}


# --- helpers -------------------------------------------------------------------------------

func _session() -> WorldSessionController:
	return _shell.runtime_host().current_session()


func _playing() -> bool:
	var session: WorldSessionController = _session()
	return (
		_shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING and not _shell.focus_held()
		and not paused and session != null and session.start_finished() and not session.world_building()
		and not session.presentation_held(WorldSessionController.WORLD_BUILD_HOLD)
	)


func _until(done: Callable, limit: int = LIMIT_FRAMES) -> bool:
	for _frame: int in limit:
		if done.call():
			return true
		await process_frame
	return done.call()


func _frames(count: int) -> void:
	for _frame: int in count:
		await process_frame


func _seconds(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _finish(failure: String) -> void:
	if not failure.is_empty():
		_report["failed"] = failure
	var file := FileAccess.open(_out, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t"))
		file.close()
	print("PROBE %s: %s" % ["FAIL " + failure if not failure.is_empty() else "DONE", _out])
	quit(0 if failure.is_empty() else 1)
