class_name OldPineGameRuntimeHost
extends Node

const SESSION_SCENE: PackedScene = preload(
	"res://scenes/world/oldpine/oldpine_world_session.tscn"
)

signal save_completed(result: OldPineRuntimeSaveLoadResult)
signal load_completed(result: OldPineRuntimeSaveLoadResult)
signal startup_completed(result: OldPineRuntimeSaveLoadResult)
signal slot_inspection_completed(result: GameSaveResult)
signal new_game_completed(result: OldPineRuntimeSaveLoadResult)
signal continue_completed(result: OldPineRuntimeSaveLoadResult)
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
var _current_session: OldPineWorldSessionController
var _request_pending: bool = false
var _last_save: OldPineRuntimeSaveLoadResult
var _last_load: OldPineRuntimeSaveLoadResult
var _last_new_game: OldPineRuntimeSaveLoadResult
var _last_end_session: OldPineRuntimeSaveLoadResult
var _configured: bool = false


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
			GameSaveRepository.new(_profile, _files)
		)
	if _startup_mode == StartupMode.MANUAL:
		startup_completed.emit(OldPineRuntimeSaveLoadResult.success(null))
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
	var result: OldPineRuntimeSaveLoadResult = _create_new_game()
	startup_completed.emit(result)


func current_session() -> OldPineWorldSessionController:
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
	if _current_session != null or not _begin_request():
		return false
	call_deferred("_execute_slot_inspection")
	return true


func request_new_game() -> bool:
	if _current_session != null or not _begin_request():
		return false
	call_deferred("_execute_new_game")
	return true


func request_continue() -> bool:
	if _current_session != null or not _begin_request():
		return false
	call_deferred("_execute_continue")
	return true


func request_end_session() -> bool:
	if not _begin_request():
		return false
	call_deferred("_execute_end_session")
	return true


func request_save() -> bool:
	if not _begin_request():
		return false
	call_deferred("_execute_save")
	return true


func request_load() -> bool:
	if not _begin_request():
		return false
	call_deferred("_execute_load")
	return true


func _execute_slot_inspection() -> void:
	var result: GameSaveResult = _coordinator.inspect_slot()
	_request_pending = false
	slot_inspection_completed.emit(result)


func _execute_new_game() -> void:
	_last_new_game = _create_new_game()
	_request_pending = false
	new_game_completed.emit(_last_new_game)


func _execute_continue() -> void:
	_last_load = _coordinator.load_replacing(null, session_slot, staging_slot)
	if _last_load.succeeded():
		_current_session = _last_load.session
		if not session_invariant_holds():
			_discard_current_session()
			_last_load = OldPineRuntimeSaveLoadResult.failure(
				OldPineRuntimeSaveLoadResult.Outcome.SESSION_INVARIANT_FAILED
			)
	_request_pending = false
	continue_completed.emit(_last_load)


func _execute_end_session() -> void:
	_discard_current_session()
	_last_end_session = (
		OldPineRuntimeSaveLoadResult.success(null)
		if session_invariant_holds()
		else OldPineRuntimeSaveLoadResult.failure(
			OldPineRuntimeSaveLoadResult.Outcome.SESSION_INVARIANT_FAILED
		)
	)
	_request_pending = false
	end_session_completed.emit(_last_end_session)


func _execute_save() -> void:
	_last_save = _coordinator.save_current(_current_session)
	_request_pending = false
	save_completed.emit(_last_save)


func _execute_load() -> void:
	_last_load = _coordinator.load_replacing(
		_current_session,
		session_slot,
		staging_slot,
	)
	if _last_load.succeeded():
		_current_session = _last_load.session
	_request_pending = false
	load_completed.emit(_last_load)


func _create_new_game() -> OldPineRuntimeSaveLoadResult:
	if _current_session != null or session_slot.get_child_count() != 0 or staging_slot.get_child_count() != 0:
		return OldPineRuntimeSaveLoadResult.failure(
			OldPineRuntimeSaveLoadResult.Outcome.SESSION_INVARIANT_FAILED
		)
	var session: OldPineWorldSessionController = _instantiate_new_game_session()
	if session == null:
		return OldPineRuntimeSaveLoadResult.failure(
			OldPineRuntimeSaveLoadResult.Outcome.NEW_GAME_FAILED
		)
	# New Game initializes synchronously beneath the committed slot after explicit
	# user intent. Host authority remains null until the graph validates; a
	# failed graph is detached before the deferred request completes.
	session_slot.add_child(session)
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
	return OldPineRuntimeSaveLoadResult.success(session)


func _instantiate_new_game_session() -> OldPineWorldSessionController:
	return SESSION_SCENE.instantiate() as OldPineWorldSessionController


func _discard_current_session() -> void:
	var session: OldPineWorldSessionController = _current_session
	_current_session = null
	_discard_session(session)


func _discard_session(session: OldPineWorldSessionController) -> void:
	if session == null:
		return
	if session.get_parent() != null:
		session.get_parent().remove_child(session)
	session.queue_free()


func _begin_request() -> bool:
	if _request_pending or _coordinator == null:
		return false
	_request_pending = true
	return true
