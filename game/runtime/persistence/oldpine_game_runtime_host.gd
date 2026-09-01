class_name OldPineGameRuntimeHost
extends Node

const SESSION_SCENE: PackedScene = preload(
	"res://scenes/world/oldpine/oldpine_world_session.tscn"
)

signal save_completed(result: OldPineRuntimeSaveLoadResult)
signal load_completed(result: OldPineRuntimeSaveLoadResult)
signal startup_completed(result: OldPineRuntimeSaveLoadResult)

@onready var session_slot: Node = %SessionSlot
@onready var staging_slot: Node = %StagingSlot

var _profile: GameSaveStorageProfile = GameSaveStorageProfile.release()
var _files: SaveFileOperations
var _startup_load: bool = false
var _coordinator: OldPineSessionLoadCoordinator
var _current_session: OldPineWorldSessionController
var _request_pending: bool = false
var _last_save: OldPineRuntimeSaveLoadResult
var _last_load: OldPineRuntimeSaveLoadResult
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
	_startup_load = startup_load
	_coordinator = coordinator
	_configured = true
	return true


func _ready() -> void:
	if _coordinator == null:
		_coordinator = OldPineSessionLoadCoordinator.new(
			GameSaveRepository.new(_profile, _files)
		)
	if _startup_load:
		_last_load = _coordinator.load_replacing(
			null,
			session_slot,
			staging_slot,
		)
		if _last_load.succeeded():
			_current_session = _last_load.session
		startup_completed.emit(_last_load)
		return
	_current_session = _new_game_session()
	startup_completed.emit(OldPineRuntimeSaveLoadResult.success(_current_session))


func current_session() -> OldPineWorldSessionController:
	return _current_session


func last_save_result() -> OldPineRuntimeSaveLoadResult:
	return _last_save


func last_load_result() -> OldPineRuntimeSaveLoadResult:
	return _last_load


func request_save() -> bool:
	if _request_pending or _coordinator == null:
		return false
	_request_pending = true
	call_deferred("_execute_save")
	return true


func request_load() -> bool:
	if _request_pending or _coordinator == null:
		return false
	_request_pending = true
	call_deferred("_execute_load")
	return true


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


func _new_game_session() -> OldPineWorldSessionController:
	var session: OldPineWorldSessionController = SESSION_SCENE.instantiate()
	session_slot.add_child(session)
	return session
