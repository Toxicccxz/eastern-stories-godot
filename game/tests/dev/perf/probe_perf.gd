extends SceneTree

## Measuring kit for the waits the player feels (DECISIONS「等待的量」, 审查修补 R and X): the
## end-of-fight autosave in the battle panel's closing, the save's capture and 继续, and a map
## change. It runs the real shell in a real window, on an isolated save profile (the player's own
## saves are not touched; the settings file is read, not written), with 切出窗口时暂停 off and a
## check that the shell is playing before each timing (BUILD.md, the windowed walkthrough).
## Self-contained (no test helpers): an exported build has no tests/ folder, so it runs from
## outside the pack.
##
##   <godot> --path game --script res://tests/dev/perf/probe_perf.gd -- <mode> <out.json> [args]
##   <godot> --main-pack <exported .pck> --script <abs>/game/tests/dev/perf/probe_perf.gd -- <mode> <out.json> [args]
## (the exported build's pack run by the Godot binary: the release .exe takes no --main-pack).
##
## Modes:
##   fight [n]        n fights (up to 6) ended in 雪亭镇's 武馆, one per trainee:
##                    from the last blow to the world back, every frame, when the autosave moment
##                    came and how long its frame took, and what showed then (lines still to
##                    tell, the stamp).
##   save [n]         the autosave's capture on the main thread n times, then 继续: back to the
##                    main menu (the slot check), 继续 to playing.
##   maps a,b,c       each map handed over to in turn: seconds until shown, video memory,
##                    a screenshot beside the json.
## Four small cores: start the process with its affinity on logical cores 16–19
## (PowerShell: `$p.ProcessorAffinity = 0xF0000`), as 「等待的量」 did.

const SHELL_SCENE: String = "res://scenes/application/application_shell.tscn"
const PROFILE: String = "perf-probe"
## Six trainees, one fight each (up to six fights a run).
const FIGHT_POINTS: Array[StringName] = [&"snow.school2.trainee.1", &"snow.school2.trainee.2", &"snow.school2.trainee.3", &"snow.school2.trainee.4", &"snow.school2.trainee.5", &"snow.school2.trainee.6"]
const FIGHT_ZONE: StringName = &"snow.school2"
const LIMIT_FRAMES: int = 20000

var _shell: ApplicationShellController
var _report: Dictionary = {}
var _out: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "fight"
	_out = args[1] if args.size() > 1 else "user://perf_probe.json"
	_report = {
		"mode": mode, "build": BuildIdentity.log_line(), "cpu": OS.get_processor_name(),
		"logical_cores": OS.get_processor_count(), "export": OS.has_feature("template"),
	}
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ApplicationShellController
	_shell.configure_before_start(GameSaveStorageProfile.isolated_test(PROFILE))
	root.add_child(_shell)
	# A click elsewhere must not pause the run (BUILD.md).
	_shell.lifecycle_adapter().pause_on_focus_loss = false
	if not await _until(func() -> bool: return _shell.shell_state().mode() == ApplicationShellState.Mode.MAIN_MENU):
		_finish("no main menu")
		return
	if not await _new_game():
		return
	match mode:
		"fight":
			await _fights(int(args[2]) if args.size() > 2 else 5)
		"save":
			await _saves(int(args[2]) if args.size() > 2 else 5)
		"maps":
			await _maps((args[2] if args.size() > 2 else "choyin.town,snow.outdoor").split(",", false))
		_:
			_finish("unknown mode %s" % mode)
			return
	_finish("")


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
	await _seconds(1.0)
	return true


func _session() -> WorldSessionController:
	return _shell.runtime_host().current_session()


## The shell plays and the world is up: no pause of any kind, no loading screen.
func _playing() -> bool:
	var session: WorldSessionController = _session()
	return (
		_shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING and not (_shell.has_method(&"focus_held") and bool(_shell.call(&"focus_held")))
		and not paused and session != null and session.start_finished() and not session.world_building()
		and not session.presentation_held(WorldSessionController.WORLD_BUILD_HOLD)
	)


# --- fight ---------------------------------------------------------------------------------

func _fights(count: int) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var pacing: PacingDefinition = catalog.pacing()
	# Every fight's end may write (the shipped 180 s interval would let only the first).
	catalog.set_pacing(pacing.copy().with_autosave(1))
	var runs: Array[Dictionary] = []
	for index: int in mini(count, FIGHT_POINTS.size()):
		var run: Dictionary = await _fight(FIGHT_POINTS[index])
		if run.has("failed"):
			_report["failed"] = run["failed"]
			break
		runs.append(run)
		print("PROBE fight %d: %s" % [index + 1, JSON.stringify(run)])
		await _seconds(1.5)
	catalog.set_pacing(pacing)
	_report["fights"] = runs
	_report["summary"] = _summary(runs, ["closing_ms", "moment_after_ms", "moment_frame_ms", "longest_other_frame_ms", "stamp_after_ms"])


func _fight(point: StringName) -> Dictionary:
	var session: WorldSessionController = _session()
	if not await _until(_playing):
		return {"failed": "not playing before the fight"}
	var map: WorldMapController = _enter(session, FIGHT_ZONE, point)
	if map == null:
		return {"failed": "no way to %s" % FIGHT_ZONE}
	await _frames(5)
	await _until(_playing)
	await _seconds(1.0)
	var npc: NpcRuntimeState = _npc_at(map, point)
	if npc == null or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		return {"failed": "no trainee standing at %s" % point}
	var body: Node2D = map.runtime_body_for_character(npc.character_id)
	var player_body: Node2D = map.runtime_player_body()
	for offset: Vector2 in [Vector2(0, 48), Vector2(48, 0), Vector2(-48, 0), Vector2(0, -48)]:
		if MapPlacementValidator.is_valid_character_position(map, FIGHT_ZONE, body.global_position + offset):
			player_body.global_position = body.global_position + offset
			break
	await _frames(3)
	if not await _until(_playing, 600):
		var held: WorldSessionController = _session()
		return {"failed": "not playing at the fight (mode %d, paused %s, building %s)" % [_shell.shell_state().mode(), paused, held.world_building()]}
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	map.select_npc(npc.character_id)
	var attack: CombatSliceInitiationResult = map.attack_selected()
	if attack.outcome != CombatSliceInitiationResult.Outcome.COMPLETED:
		return {"failed": "the attack on %s did not start (%d)" % [point, attack.outcome]}
	await _seconds(1.0)
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	npc.character_state.vitality = CharacterResourceState.new(1, 1, 100000) # PROBE-ONLY: the next blow ends it
	player.state.progression.combat_experience = maxi(player.state.progression.combat_experience, 100000)
	var moments: Array[int] = []
	var on_moment := func() -> void: moments.append(Time.get_ticks_usec())
	session.autosave_moment.connect(on_moment)
	for step: int in 600:
		if not coordinator.has_active_encounter():
			break
		# 了结 / 放过 waits for the player: the probe spares the trainee.
		for victim: StringName in coordinator.held_victims():
			coordinator.spare_downed(victim)
		# The fight's clock waits for the player's order: the first move.
		if coordinator.waiting_for_player():
			var moves: Array[CombatActionDefinition] = coordinator.player_moves()
			if not moves.is_empty():
				coordinator.choose_attack(moves[0].action_id)
		coordinator.advance_scheduler(1.0)
	if coordinator.has_active_encounter():
		session.autosave_moment.disconnect(on_moment)
		return {"failed": "the fight did not end (waiting %s, held %s)" % [coordinator.waiting_for_player(), coordinator.held_victims()]}
	var over: int = Time.get_ticks_usec()
	var frames: Array[int] = [over]
	var stamp_at: int = -1
	var lines_at_moment: int = -1
	var stamp_at_moment: bool = false
	while (ui.visible or session.battle_panel_shown()) and frames.size() < LIMIT_FRAMES and Time.get_ticks_usec() - over < 20000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(now)
		if stamp_at < 0 and ui.end_stamp.visible:
			stamp_at = now
		if lines_at_moment < 0 and not moments.is_empty():
			lines_at_moment = ui._line_queue.size()
			stamp_at_moment = ui.end_stamp.visible
	session.autosave_moment.disconnect(on_moment)
	var back: int = Time.get_ticks_usec()
	var run: Dictionary = {
		"closing_ms": (back - over) / 1000.0,
		"frames": frames.size(),
		"stamp_after_ms": -1.0 if stamp_at < 0 else (stamp_at - over) / 1000.0,
		"moment_after_ms": -1.0 if moments.is_empty() else (moments[0] - over) / 1000.0,
		"moments_in_closing": moments.size(),
		"lines_left_at_moment": lines_at_moment,
		"stamp_shown_at_moment": stamp_at_moment,
	}
	# The frame the moment fell in: from the frame boundary before it to the one after.
	var longest_other: float = 0.0
	var moment_frame: float = -1.0
	for index: int in range(1, frames.size()):
		var length: float = (frames[index] - frames[index - 1]) / 1000.0
		if not moments.is_empty() and frames[index - 1] <= moments[0] and moments[0] < frames[index]:
			moment_frame = length
		else:
			longest_other = maxf(longest_other, length)
	run["moment_frame_ms"] = moment_frame
	run["longest_other_frame_ms"] = longest_other
	await _until(func() -> bool: return not _shell.runtime_host().autosave().running(), 600)
	return run


# --- save ----------------------------------------------------------------------------------

func _saves(count: int) -> void:
	var session: WorldSessionController = _session()
	var captures: Array[float] = []
	for index: int in count:
		await _frames(2)
		var began: int = Time.get_ticks_usec()
		var captured: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"probe", Time.get_datetime_string_from_system(true) + "Z", null, GameSaveSnapshot.AUTO_SLOT_ID, false)
		captures.append((Time.get_ticks_usec() - began) / 1000.0)
		if not captured.succeeded():
			_report["capture_failed"] = captured.path
			break
	_report["capture_ms"] = captures
	# 继续: a save by hand, the main menu's check, then 继续 to playing.
	if not (_shell.request_pause() and _shell.request_save_slots() and _shell.choose_slot_row(0)):
		_report["failed"] = "系统 → 存档 refused"
		return
	if _shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		_shell.confirm_current_result()
	await _until(func() -> bool: return _shell.shell_state().mode() != ApplicationShellState.Mode.SAVING)
	_shell.dismiss_current_result()
	var began_menu: int = Time.get_ticks_usec()
	if not _shell.request_return_to_main_menu():
		_report["failed"] = "返回主菜单 refused"
		return
	if _shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		_shell.confirm_current_result()
	await _until(func() -> bool: return _shell.shell_state().mode() == ApplicationShellState.Mode.MAIN_MENU and _shell.continue_enabled())
	_report["to_main_menu_and_check_ms"] = (Time.get_ticks_usec() - began_menu) / 1000.0
	var began_continue: int = Time.get_ticks_usec()
	if not _shell.request_continue_from_menu():
		_report["failed"] = "继续 refused"
		return
	await _until(_playing)
	_report["continue_to_playing_ms"] = (Time.get_ticks_usec() - began_continue) / 1000.0


# --- maps ----------------------------------------------------------------------------------

func _maps(map_ids: PackedStringArray) -> void:
	var session: WorldSessionController = _session()
	var rows: Array[Dictionary] = []
	for map_id: String in map_ids:
		var definition: MapDefinition = GameContent.catalog().map(StringName(map_id))
		if definition == null:
			rows.append({"map": map_id, "failed": "no such map"})
			continue
		var spawn: StringName = definition.entry_spawn_id
		var zone: StringName = StringName(String(spawn).substr(0, String(spawn).rfind(".")))
		var began: int = Time.get_ticks_usec()
		if not session.handoff_to(StringName(map_id), zone, zone, spawn).succeeded():
			rows.append({"map": map_id, "failed": "handoff refused"})
			continue
		await _frames(5)
		await _until(_playing)
		var row: Dictionary = {"map": map_id, "shown_ms": (Time.get_ticks_usec() - began) / 1000.0}
		await _seconds(1.0)
		row["video_memory_mb"] = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		var shot: Image = root.get_texture().get_image()
		if shot != null and _playing():
			var path: String = _out.get_basename() + "_" + map_id + ".png"
			shot.save_png(path)
			row["shot"] = path
		rows.append(row)
		print("PROBE map: %s" % JSON.stringify(row))
	_report["maps"] = rows


# --- helpers -------------------------------------------------------------------------------

func _enter(session: WorldSessionController, zone_id: StringName, point_id: StringName) -> WorldMapController:
	var zone: ZoneDefinition = GameContent.catalog().zone(zone_id)
	if zone == null:
		return null
	var map: WorldMapController = session.active_map() as WorldMapController
	if map != null and map.map_id() == zone.map_id:
		return map if map.relocate_player(zone_id, point_id) else null
	if not session.handoff_to(zone.map_id, zone_id, zone_id, point_id).succeeded():
		return null
	return session.active_map() as WorldMapController


func _npc_at(map: WorldMapController, point_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == point_id:
			return npc
	return null


static func _summary(runs: Array[Dictionary], keys: Array[String]) -> Dictionary:
	var summary: Dictionary = {}
	for key: String in keys:
		var values: Array[float] = []
		for run: Dictionary in runs:
			if float(run.get(key, -1.0)) >= 0.0:
				values.append(float(run[key]))
		if values.is_empty():
			continue
		values.sort()
		summary[key] = {"min": values[0], "median": values[values.size() / 2], "max": values[-1]}
	return summary


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
