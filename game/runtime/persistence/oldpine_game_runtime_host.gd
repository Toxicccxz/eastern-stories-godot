class_name OldPineGameRuntimeHost
extends Node

const NamePolicy = preload("res://application/new_game/new_player_name_policy.gd")

const SESSION_SCENE: PackedScene = preload(
	"res://scenes/world/oldpine/oldpine_world_session.tscn"
)

signal save_completed(result: OldPineRuntimeSaveLoadResult)
signal load_completed(result: OldPineRuntimeSaveLoadResult)
signal startup_completed(result: OldPineRuntimeSaveLoadResult)
signal slot_inspection_completed(result: GameSaveSlotInspectionResult)
signal new_game_completed(result: OldPineRuntimeSaveLoadResult)
signal continue_completed(result: OldPineRuntimeSaveLoadResult)
signal recovery_completed(result: OldPineRuntimeSaveLoadResult)
signal end_session_completed(result: OldPineRuntimeSaveLoadResult)

enum StartupMode {
	NEW_GAME,
	LOAD,
	MANUAL,
}

@onready var session_slot: Node = get_node("SessionSlot")
@onready var staging_slot: Node = get_node("StagingSlot")

var _profile: GameSaveStorageProfile = GameSaveStorageProfile.release()
var _files: SaveFileOperations
var _startup_mode: int = StartupMode.NEW_GAME
var _coordinator: OldPineSessionLoadCoordinator
var _current_session: WorldSessionController
var _request_pending: bool = false
var _last_save: OldPineRuntimeSaveLoadResult
var _last_load: OldPineRuntimeSaveLoadResult
var _last_new_game: OldPineRuntimeSaveLoadResult
var _last_end_session: OldPineRuntimeSaveLoadResult
var _configured: bool = false
## 现代基线 A (DECISIONS「自动存档」): the autosave of whichever Session stands here.
var _autosave: GameAutosave
var _slots: Array[GameSaveSlotSummary] = []
## While no journey runs and starts go in slices (DECISIONS「加载画面」), every map's scene is
## read on worker threads and held here, so a start does not read them; let go once a journey
## stands. Paths asked for and not yet taken, and the scenes taken.
var _scenes_asked: Array[String] = []
var _scenes_held: Dictionary[String, PackedScene] = {}
## Once a frame (_process): a start waits on it to let the frame that asked for it draw.
signal _frame


func configure_before_start(
	profile: GameSaveStorageProfile,
	files: SaveFileOperations = null,
	startup_load: bool = false,
	coordinator: OldPineSessionLoadCoordinator = null,
) -> bool:
	if _configured or is_node_ready() or profile == null or not profile.is_valid():
		return false
	_profile = profile
	_files = files
	_startup_mode = StartupMode.LOAD if startup_load else StartupMode.NEW_GAME
	_coordinator = coordinator
	_configured = true
	return true


func configure_manual_before_start(
	profile: GameSaveStorageProfile,
	files: SaveFileOperations = null,
	coordinator: OldPineSessionLoadCoordinator = null,
) -> bool:
	if not configure_before_start(profile, files, false, coordinator):
		return false
	_startup_mode = StartupMode.MANUAL
	return true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _coordinator == null:
		_coordinator = OldPineSessionLoadCoordinator.new(
			SourceEntrySaveRepository.new(_profile, _files)
			if _startup_mode == StartupMode.MANUAL
			else GameSaveRepository.new(_profile, _files)
		)
	_autosave = GameAutosave.new(_coordinator.repository_for(GameSaveSnapshot.AUTO_SLOT_ID))
	if _startup_mode == StartupMode.MANUAL:
		var manual_result: OldPineRuntimeSaveLoadResult = (
			OldPineRuntimeSaveLoadResult.success(null)
			if session_invariant_holds()
			else OldPineRuntimeSaveLoadResult.failure(
				OldPineRuntimeSaveLoadResult.Outcome.SESSION_INVARIANT_FAILED
			)
		)
		startup_completed.emit(manual_result)
		_read_scenes_ahead()
		return
	if _startup_mode == StartupMode.LOAD:
		_last_load = _coordinator.load_replacing(
			null,
			session_slot,
			staging_slot,
		)
		if _last_load.succeeded():
			_current_session = _last_load.session
		startup_completed.emit(_last_load)
		return
	# Explicit auto-start fixture mode. Public Shell always configures MANUAL.
	var result: OldPineRuntimeSaveLoadResult = _attach_new_game_session(_instantiate_new_game_session())
	startup_completed.emit(result)


## A finished autosave is told once (已自动存档, unless turned off; a failure always).
func _process(_delta: float) -> void:
	_frame.emit()
	_take_read_scenes()
	var saved: GameSaveResult = null if _autosave == null else _autosave.take_finished()
	if saved == null or _current_session == null or not is_instance_valid(_current_session):
		return
	if not saved.succeeded():
		_current_session.shared_ui().toasts().push(tr("自动存档失败"))
	elif AutosaveNotice.shown:
		_current_session.shared_ui().toasts().push(tr("已自动存档"))


func _exit_tree() -> void:
	if _autosave != null:
		_autosave.wait()
	# Nothing is left loading on a worker thread when the game closes.
	if _coordinator != null:
		_coordinator.wait_for_reads()
	for path: String in _scenes_asked:
		ResourceLoader.load_threaded_get(path)
	_scenes_asked.clear()
	_scenes_held.clear()


## How long a start builds the world per frame (the feel's session_start_slice_ms; 0 in the
## suites: the start is one frame and its result comes within the deferred call).
func _start_slice_usec() -> int:
	return roundi(GameContent.catalog().pacing().feel.session_start_slice_seconds * 1000000.0)


## A start in slices lets the frame that asked for it draw first (the title's first burn).
func _let_frame_draw() -> void:
	if _start_slice_usec() > 0:
		await _frame


## Every map's scene asked of the worker threads (the starts go in slices only).
func _read_scenes_ahead() -> void:
	if _start_slice_usec() <= 0 or _current_session != null or not _scenes_asked.is_empty() or not _scenes_held.is_empty():
		return
	for map: MapDefinition in GameContent.catalog().maps():
		if ResourceLoader.load_threaded_request(map.scene_path, "PackedScene") == OK:
			_scenes_asked.append(map.scene_path)


## The scenes read so far are taken; once a journey stands none is held.
func _take_read_scenes() -> void:
	for i: int in range(_scenes_asked.size() - 1, -1, -1):
		var path: String = _scenes_asked[i]
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		var scene: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene if status == ResourceLoader.THREAD_LOAD_LOADED else null
		if scene != null and _current_session == null:
			_scenes_held[path] = scene
		_scenes_asked.remove_at(i)
	if _current_session != null and not _scenes_held.is_empty():
		_scenes_held.clear()


## How many map scenes are read ahead and held now.
func scenes_read_ahead() -> int:
	return _scenes_held.size()


func autosave() -> GameAutosave:
	return _autosave


## The Session in the slot from now on: the autosave follows it. A New Game's first moment
## saves; a loaded one's interval starts with the load, its slots have nothing to add yet.
func _session_began(session: WorldSessionController, loaded: bool) -> void:
	session.autosave_moment.connect(_on_autosave_moment.bind(session), CONNECT_DEFERRED)
	if loaded:
		_autosave.restart_interval()
	else:
		_autosave.restart_interval(-1)


func _on_autosave_moment(session: WorldSessionController) -> void:
	if session == _current_session and not _request_pending:
		_autosave.begin(session)


func current_session() -> WorldSessionController:
	return _current_session


func last_save_result() -> OldPineRuntimeSaveLoadResult:
	return _last_save


func last_load_result() -> OldPineRuntimeSaveLoadResult:
	return _last_load


func last_new_game_result() -> OldPineRuntimeSaveLoadResult:
	return _last_new_game


func last_end_session_result() -> OldPineRuntimeSaveLoadResult:
	return _last_end_session


func is_configured() -> bool:
	return _configured


func storage_profile_id() -> StringName:
	return _profile.profile_id if _profile != null else &""


func request_pending() -> bool:
	return _request_pending


func session_invariant_holds() -> bool:
	if session_slot == null or staging_slot == null or staging_slot.get_child_count() != 0:
		return false
	if _current_session == null:
		return session_slot.get_child_count() == 0
	return (
		session_slot.get_child_count() == 1
		and session_slot.get_child(0) == _current_session
		and _current_session.get_parent() == session_slot
		and _current_session.is_initialized()
		and _current_session.active_map_child_count() == 1
	)


func request_slot_inspection() -> bool:
	if not _empty_session_invariant_holds() or not _begin_request():
		return false
	call_deferred("_execute_slot_inspection")
	return true


## The slots' rows as the last inspection read them.
func slots() -> Array[GameSaveSlotSummary]:
	return _slots


## The slots' rows now (once the autosave under way is done).
func read_slots() -> Array[GameSaveSlotSummary]:
	_autosave.wait()
	_slots = _coordinator.slot_summaries()
	return _slots


## The autosave before the last one (its .bak), for the list's 上一份自动存档 row.
func previous_autosave() -> GameSaveSlotSummary:
	_autosave.wait()
	return _coordinator.repository_for(GameSaveSnapshot.AUTO_SLOT_ID).read_backup_summary()


## The autosave's row now.
func autosave_row() -> GameSaveSlotSummary:
	_autosave.wait()
	return _coordinator.repository_for(GameSaveSnapshot.AUTO_SLOT_ID).read_summary()


func selected_slot() -> StringName:
	return _coordinator.selected_slot()


func request_new_game(display_name: String, gender: StringName, pace: StringName = CharacterState.PACE_MODERN) -> bool:
	if not NamePolicy.is_valid(display_name) or gender not in [CharacterState.GENDER_MALE, CharacterState.GENDER_FEMALE]:
		return false
	if pace not in [CharacterState.PACE_MODERN, CharacterState.PACE_CLASSIC]:
		return false
	if not _empty_session_invariant_holds() or not _begin_request():
		return false
	call_deferred("_execute_new_game", display_name, gender, pace)
	return true


## Whether Save, Load or the recovery can go to `slot_id` (none: the slot selected).
func _select_for_request(slot_id: StringName) -> bool:
	if slot_id.is_empty() or _coordinator.select_slot(slot_id):
		return true
	_request_pending = false
	return false


func request_continue(slot_id: StringName = &"") -> bool:
	if not _empty_session_invariant_holds() or not _begin_request() or not _select_for_request(slot_id):
		return false
	call_deferred("_execute_continue")
	return true


func request_recovery(source: int, slot_id: StringName = &"") -> bool:
	if (
		not GameSaveRecoverySource.is_valid(source)
		or not _empty_session_invariant_holds()
		or not _begin_request()
		or not _select_for_request(slot_id)
	):
		return false
	call_deferred("_execute_recovery", source)
	return true


func request_end_session() -> bool:
	if _current_session == null or not _begin_request():
		return false
	call_deferred("_execute_end_session")
	return true


func request_save(slot_id: StringName = &"") -> bool:
	if not _begin_request() or not _select_for_request(slot_id):
		return false
	call_deferred("_execute_save")
	return true


## A Load in play (DECISIONS「存档位」): the save replaces the Session standing here, which goes
## on as it was if the save fails. `source` a recovery source, for the 上一份自动存档 row.
func request_load(slot_id: StringName = &"", source: int = -1) -> bool:
	if not _begin_request() or not _select_for_request(slot_id):
		return false
	call_deferred("_execute_load", source)
	return true


## What the main menu says of `slot_id` instead of the newest (a row that does not load).
func request_slot_inspection_of(slot_id: StringName) -> bool:
	if not _empty_session_invariant_holds() or not _begin_request() or not _select_for_request(slot_id):
		return false
	call_deferred("_execute_slot_inspection", false)
	return true


func _execute_slot_inspection(newest: bool = true) -> void:
	_slots = _coordinator.slot_summaries()
	if newest:
		_coordinator.select_slot(GameSaveSlotSummary.newest(_slots, _coordinator.selected_slot()))
	var result: GameSaveSlotInspectionResult = _coordinator.inspect_slot()
	_request_pending = false
	slot_inspection_completed.emit(result)


func _execute_new_game(display_name: String, gender: StringName, pace: StringName) -> void:
	await _let_frame_draw()
	_last_new_game = await _create_new_game(display_name, gender, pace)
	_request_pending = false
	new_game_completed.emit(_last_new_game)


func _execute_continue() -> void:
	await _let_frame_draw()
	_last_load = await _coordinator.load_replacing_in_slices(null, session_slot, staging_slot, _start_slice_usec(), _frame)
	if _last_load.succeeded():
		_current_session = _last_load.session
		if not session_invariant_holds():
			_discard_current_session()
			_last_load = OldPineRuntimeSaveLoadResult.failure(
				OldPineRuntimeSaveLoadResult.Outcome.SESSION_INVARIANT_FAILED
			)
		else:
			_session_began(_current_session, true)
	_request_pending = false
	continue_completed.emit(_last_load)


func _execute_recovery(source: int) -> void:
	await _let_frame_draw()
	_last_load = await _coordinator.load_recovery_replacing_in_slices(
		source,
		null,
		session_slot,
		staging_slot,
		_start_slice_usec(),
		_frame,
	)
	if _last_load.succeeded():
		_current_session = _last_load.session
		if not session_invariant_holds():
			_discard_current_session()
			_last_load = OldPineRuntimeSaveLoadResult.failure(
				OldPineRuntimeSaveLoadResult.Outcome.SESSION_INVARIANT_FAILED
			)
		else:
			_session_began(_current_session, true)
	_request_pending = false
	recovery_completed.emit(_last_load)


func _execute_end_session() -> void:
	var session: WorldSessionController = _current_session
	if session == null or not session_invariant_holds():
		_last_end_session = OldPineRuntimeSaveLoadResult.failure(
			OldPineRuntimeSaveLoadResult.Outcome.SESSION_INVARIANT_FAILED
		)
	else:
		session_slot.remove_child(session)
		_current_session = null
		session.queue_free()
		_last_end_session = OldPineRuntimeSaveLoadResult.success(null)
		_read_scenes_ahead()
	_request_pending = false
	end_session_completed.emit(_last_end_session)


func _execute_save() -> void:
	_last_save = _coordinator.save_current(_current_session)
	_request_pending = false
	save_completed.emit(_last_save)


func _execute_load(source: int = -1) -> void:
	await _let_frame_draw()
	if source < 0:
		_last_load = await _coordinator.load_replacing_in_slices(_current_session, session_slot, staging_slot, _start_slice_usec(), _frame)
	else:
		_last_load = await _coordinator.load_recovery_replacing_in_slices(source, _current_session, session_slot, staging_slot, _start_slice_usec(), _frame)
	if _last_load.succeeded():
		_current_session = _last_load.session
		_session_began(_current_session, true)
	elif _last_load.outcome == OldPineRuntimeSaveLoadResult.Outcome.ROLLBACK_FAILED:
		# Neither world stands: the main menu, not a frozen one.
		_discard_current_session()
	_request_pending = false
	load_completed.emit(_last_load)


## New Game opens on the theme story's card over the world (DECISIONS「开场卡片」); a suite that
## drives the world from its first moment through the shell turns it off (PublicNewGameTestFixture).
var opening_card: bool = true


func _create_new_game(display_name: String, gender: StringName, pace: StringName = CharacterState.PACE_MODERN) -> OldPineRuntimeSaveLoadResult:
	var session: WorldSessionController = _instantiate_new_game_session()
	if session == null:
		return OldPineRuntimeSaveLoadResult.failure(OldPineRuntimeSaveLoadResult.Outcome.NEW_GAME_FAILED)
	if not session.configure_source_entry(display_name, gender, pace):
		_discard_session(session)
		return OldPineRuntimeSaveLoadResult.failure(OldPineRuntimeSaveLoadResult.Outcome.NEW_GAME_FAILED)
	if opening_card:
		session.request_opening_card()
	# Its start goes over frames while the title plays (DECISIONS「加载画面」).
	session.start_slice_usec = _start_slice_usec()
	var refused: OldPineRuntimeSaveLoadResult = _place_new_game_session(session)
	if refused != null:
		return refused
	if not session.start_finished():
		await session.start_done
	return _adopt_new_game_session(session)


func _attach_new_game_session(session: WorldSessionController) -> OldPineRuntimeSaveLoadResult:
	var refused: OldPineRuntimeSaveLoadResult = _place_new_game_session(session)
	return refused if refused != null else _adopt_new_game_session(session)


## The new session goes beneath the committed slot, where it starts (null), or why not.
func _place_new_game_session(session: WorldSessionController) -> OldPineRuntimeSaveLoadResult:
	if _current_session != null or session_slot.get_child_count() != 0 or staging_slot.get_child_count() != 0:
		_discard_session(session)
		return OldPineRuntimeSaveLoadResult.failure(
			OldPineRuntimeSaveLoadResult.Outcome.SESSION_INVARIANT_FAILED
		)
	if session == null:
		return OldPineRuntimeSaveLoadResult.failure(
			OldPineRuntimeSaveLoadResult.Outcome.NEW_GAME_FAILED
		)
	# New Game initializes beneath the committed slot after explicit user intent (within
	# add_child, or over frames with a start_slice_usec). Host authority remains null until
	# the graph validates; a failed graph is detached before the deferred request completes.
	session_slot.add_child(session)
	return null


## Once its start is over, the new session becomes the Host's, or is discarded.
func _adopt_new_game_session(session: WorldSessionController) -> OldPineRuntimeSaveLoadResult:
	if not session.is_initialized() or session.active_map_child_count() != 1:
		_discard_session(session)
		return OldPineRuntimeSaveLoadResult.failure(
			OldPineRuntimeSaveLoadResult.Outcome.NEW_GAME_FAILED
		)
	_current_session = session
	if not session_invariant_holds():
		_discard_current_session()
		return OldPineRuntimeSaveLoadResult.failure(
			OldPineRuntimeSaveLoadResult.Outcome.SESSION_INVARIANT_FAILED
		)
	_session_began(session, false)
	return OldPineRuntimeSaveLoadResult.success(session)


func _instantiate_new_game_session() -> WorldSessionController:
	return SESSION_SCENE.instantiate() as WorldSessionController


func _discard_current_session() -> void:
	var session: WorldSessionController = _current_session
	_current_session = null
	_discard_session(session)


func _discard_session(session: WorldSessionController) -> void:
	if session == null:
		return
	if session.get_parent() != null:
		session.get_parent().remove_child(session)
	session.queue_free()


func _begin_request() -> bool:
	if _request_pending or _coordinator == null:
		return false
	_request_pending = true
	# Whatever this asks comes after the autosave under way.
	if _autosave != null:
		_autosave.wait()
	return true


func _empty_session_invariant_holds() -> bool:
	return _current_session == null and session_invariant_holds()
