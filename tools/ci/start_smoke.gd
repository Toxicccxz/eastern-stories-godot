extends SceneTree

## The game started as a player starts it: the shell (the main scene) on real user files, its
## main menu, 新的旅程, the first moment played a few hundred frames, one save by hand
## through 系统 → 存档. Lives outside game/ so the release copy can run it too
## (tools/ci/start_smoke.py runs it; it fails on any ERROR, SHADER ERROR or SCRIPT ERROR line).
##
##   <godot> --headless --path <project> --script <abs>/tools/ci/start_smoke.gd -- start
##   <godot> --path game --script <abs>/tools/ci/start_smoke.gd -- walk <shots dir> <map,map,...>
##
## `walk` (windowed): after the save it hands the player over to each map in turn, walks a
## little with the move keys and saves a screenshot per map to <shots dir>.
## The last line is `START SMOKE PASS` or `START SMOKE FAIL: <why>`; the exit code is 0 or 1.

const SHELL_SCENE: String = "res://scenes/application/application_shell.tscn"
## Frames the played moment runs before the save ("a few hundred").
const PLAY_FRAMES: int = 300
## Upper bounds, in frames, for the shell's own steps (a slow runner builds slowly).
const BOOT_FRAMES: int = 1800
const START_FRAMES: int = 6000
const SAVE_FRAMES: int = 1800
## A step that never ends must not hang the run (start_smoke.py has its own limit too).
const WATCHDOG_SECONDS: float = 540.0
## Below this brightness spread a screenshot is one flat colour (a black or grey screen); a
## dressed voxel map with its HUD is far above it.
const FLAT_SPREAD: float = 0.02

var _shell: ApplicationShellController
var _failed: String = ""
## walk: where the screenshots go (empty: none are taken).
var _shots: String = ""


func _initialize() -> void:
	call_deferred("_run")
	create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(func() -> void:
		_finish("watchdog: no result after %d s" % int(WATCHDOG_SECONDS)))


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "start"
	if mode == "walk":
		_shots = args[1] if args.size() > 1 else "user://smoke_shots"
		DirAccess.make_dir_recursive_absolute(_shots)
	print("START SMOKE %s: %s" % [mode, BuildIdentity.log_line()])
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ApplicationShellController
	root.add_child(_shell)
	if not await _until(func() -> bool: return _shell.shell_state().mode() == ApplicationShellState.Mode.MAIN_MENU, BOOT_FRAMES):
		_finish("the main menu never showed (mode %d)" % _shell.shell_state().mode())
		return
	print("START SMOKE: main menu")
	await _shot("main_menu")
	# The cleaned release copy: none of the development project's helpers, the release slot.
	if not DirAccess.dir_exists_absolute("res://tests"):
		if root.has_node("_mcp_game_helper") or ProjectSettings.has_setting("autoload/_mcp_game_helper"):
			_finish("the release copy still starts the Godot AI helper")
			return
		if _shell.runtime_host().storage_profile_id() != &"release":
			_finish("the release copy saves in the %s slot, not release" % _shell.runtime_host().storage_profile_id())
			return
		print("START SMOKE: release copy (no tests, no Godot AI helper, release saves)")
	if _shell.request_new_game_from_menu() and _shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		_shell.confirm_current_result()
	_shell.player_name_edit.text = "凌雪"
	_shell.select_new_game_gender(CharacterState.GENDER_FEMALE)
	if not _shell.submit_new_game_setup():
		_finish("新的旅程 was refused")
		return
	if not await _until(_playing, START_FRAMES):
		_finish("the new game never started playing (mode %d)" % _shell.shell_state().mode())
		return
	var session: WorldSessionController = _shell.runtime_host().current_session()
	var overlay: PlayerLifeOverlay = session.shared_ui().life_overlay
	if overlay.card_shown():
		overlay.go_on()
	print("START SMOKE: playing on %s" % session.active_map_id())
	await _frames(PLAY_FRAMES)
	if not await _save():
		return
	print("START SMOKE: saved")
	if mode == "walk":
		var maps: PackedStringArray = (args[2] if args.size() > 2 else "snow.outdoor,snow.inn_upstairs,cloud.outdoor").split(",", false)
		for map_id: String in maps:
			if not await _walk(session, StringName(map_id), _shots):
				return
	_finish("")


func _playing() -> bool:
	var session: WorldSessionController = _shell.runtime_host().current_session()
	return _shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING and session != null and session.start_finished() and _shown(session)


## The player's map is up and no loading screen holds the world.
static func _shown(session: WorldSessionController) -> bool:
	var map: WorldMapController = session.active_map() as WorldMapController
	var view: WorldVoxelView = null if map == null else map.get_node_or_null("MapView") as WorldVoxelView
	return (view == null or view._built) and not session.world_building() and not session.presentation_held(WorldSessionController.WORLD_BUILD_HOLD)


## 系统 → 存档 → the first row, as a player saves.
func _save() -> bool:
	if not _shell.request_pause():
		_finish("系统 was refused (mode %d)" % _shell.shell_state().mode())
		return false
	await _shot("system")
	if not (_shell.request_save_slots() and _shell.choose_slot_row(0)):
		_finish("系统 → 存档 was refused (mode %d)" % _shell.shell_state().mode())
		return false
	if _shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		_shell.confirm_current_result()
	await _until(func() -> bool: return _shell.shell_state().mode() != ApplicationShellState.Mode.SAVING, SAVE_FRAMES)
	await _frames(2)
	var result: ApplicationOperationResult = _shell.last_result()
	if result == null or not result.succeeded():
		_finish("the save failed: %s" % ("no result" if result == null else "%s (%d)" % [result.message_key(), result.outcome()]))
		return false
	_shell.dismiss_current_result()
	_shell.request_resume()
	await _frames(2)
	return true


## Over to `map_id`'s entry, a few steps with the move keys, one screenshot.
func _walk(session: WorldSessionController, map_id: StringName, shots: String) -> bool:
	if session.active_map_id() != map_id:
		var definition: MapDefinition = GameContent.catalog().map(map_id)
		if definition == null:
			_finish("no map %s" % map_id)
			return false
		var spawn: StringName = definition.entry_spawn_id
		var zone: StringName = StringName(String(spawn).substr(0, String(spawn).rfind(".")))
		if not session.handoff_to(map_id, zone, zone, spawn).succeeded():
			_finish("the way to %s was refused" % map_id)
			return false
	if not await _until(func() -> bool: return _shown(session), START_FRAMES):
		_finish("%s never showed" % map_id)
		return false
	await _seconds(1.0)
	for action: StringName in [&"move_right", &"move_down", &"move_left", &"move_up"]:
		Input.action_press(action)
		await _seconds(0.5)
		Input.action_release(action)
	await _seconds(0.5)
	var shot: Image = root.get_texture().get_image()
	if shot == null:
		_finish("no picture of %s" % map_id)
		return false
	var path: String = shots.path_join("%s.png" % map_id)
	shot.save_png(path)
	var spread: float = _spread(shot)
	print("START SMOKE: %s shown, %s (brightness spread %.3f)" % [map_id, path, spread])
	# Twice a black or grey screen reached main: a map is never one flat colour.
	if spread < FLAT_SPREAD:
		_finish("the picture of %s is one flat colour (spread %.3f): a black or grey screen? %s" % [map_id, spread, path])
		return false
	return true


## How far the brightness of a grid of pixels strays from its mean (standard deviation, 0..1).
static func _spread(image: Image) -> float:
	var values: Array[float] = []
	for y: int in range(0, image.get_height(), maxi(1, image.get_height() / 48)):
		for x: int in range(0, image.get_width(), maxi(1, image.get_width() / 64)):
			values.append(image.get_pixel(x, y).get_luminance())
	var mean: float = 0.0
	for value: float in values:
		mean += value
	mean /= maxf(1.0, values.size())
	var variance: float = 0.0
	for value: float in values:
		variance += (value - mean) * (value - mean)
	return sqrt(variance / maxf(1.0, values.size()))


## walk: a picture of what shows now (the main menu, 系统), the version small in it.
func _shot(name: String) -> void:
	if _shots.is_empty():
		return
	await _seconds(0.6)
	var shot: Image = root.get_texture().get_image()
	if shot != null:
		shot.save_png(_shots.path_join("%s.png" % name))
		print("START SMOKE: %s shot" % name)


func _until(done: Callable, limit: int) -> bool:
	for _frame: int in limit:
		if done.call():
			return true
		await process_frame
	return done.call()


func _frames(count: int) -> void:
	for _frame: int in count:
		await process_frame


## Real seconds: a windowed run's frames are short.
func _seconds(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _finish(failure: String) -> void:
	if not _failed.is_empty():
		return
	_failed = failure if not failure.is_empty() else "-"
	print("START SMOKE PASS" if failure.is_empty() else "START SMOKE FAIL: %s" % failure)
	quit(0 if failure.is_empty() else 1)
