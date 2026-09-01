class_name ApplicationShellController
extends Node

const HOST_SCENE: PackedScene = preload(
	"res://scenes/runtime/oldpine_game_runtime_host.tscn"
)

signal host_ready(host: OldPineGameRuntimeHost)
signal state_changed(state: ApplicationShellState)

@onready var runtime_host_slot: Node = %RuntimeHostSlot
@onready var shell_canvas: CanvasLayer = %ShellCanvas
@onready var main_menu_panel: Control = %MainMenuPanel
@onready var status_label: Label = %StatusLabel
@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var busy_overlay: Control = %BusyOverlay
@onready var busy_label: Label = %BusyLabel
@onready var result_overlay: Control = %ResultOverlay
@onready var result_label: Label = %ResultLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton
@onready var acknowledge_button: Button = %AcknowledgeButton

var _profile: GameSaveStorageProfile = GameSaveStorageProfile.release()
var _files: SaveFileOperations
var _coordinator: OldPineSessionLoadCoordinator
var _configured: bool = false
var _host: OldPineGameRuntimeHost
var _state: ApplicationShellState = ApplicationShellState.new()
var _slot_inspection: ApplicationSlotInspection
var _last_result: ApplicationOperationResult
var _confirmation_pending: bool = false


func configure_before_start(
	profile: GameSaveStorageProfile,
	files: SaveFileOperations = null,
	coordinator: OldPineSessionLoadCoordinator = null,
) -> bool:
	if _configured or is_node_ready() or profile == null or not profile.is_valid():
		return false
	_profile = profile
	_files = files
	_coordinator = coordinator
	_configured = true
	return true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _configured:
		_configured = true
	_set_state(ApplicationShellState.boot_inspecting())
	_host = HOST_SCENE.instantiate() as OldPineGameRuntimeHost
	_connect_host(_host)
	if not _host.configure_manual_before_start(_profile, _files, _coordinator):
		_show_request_failure(ApplicationOperationResult.Operation.INSPECT_SLOT)
		return
	runtime_host_slot.add_child(_host)
	host_ready.emit(_host)


func runtime_host() -> OldPineGameRuntimeHost:
	return _host


func shell_state() -> ApplicationShellState:
	return _state


func slot_inspection() -> ApplicationSlotInspection:
	return _slot_inspection


func last_result() -> ApplicationOperationResult:
	return _last_result


func storage_profile_id() -> StringName:
	return _profile.profile_id if _profile != null else &""


func is_configured() -> bool:
	return _configured


func menu_visible() -> bool:
	return main_menu_panel != null and main_menu_panel.visible


func busy_visible() -> bool:
	return busy_overlay != null and busy_overlay.visible


func result_visible() -> bool:
	return result_overlay != null and result_overlay.visible


func continue_enabled() -> bool:
	return continue_button != null and not continue_button.disabled


func status_text() -> String:
	return "" if status_label == null else status_label.text


func request_new_game_from_menu() -> bool:
	if _state.mode() != ApplicationShellState.Mode.MAIN_MENU:
		return false
	if _slot_inspection != null and _slot_inspection.has_save_material():
		_confirmation_pending = true
		_last_result = ApplicationOperationResult.new(
			ApplicationOperationResult.Operation.NEW_GAME,
			ApplicationOperationResult.Outcome.CONFIRMATION_REQUIRED,
			&"new_game.confirm",
		)
		_set_state(ApplicationShellState.result())
		return true
	return _start_new_game()


func request_continue_from_menu() -> bool:
	if (
		_state.mode() != ApplicationShellState.Mode.MAIN_MENU
		or _slot_inspection == null
		or not _slot_inspection.continue_available()
	):
		return false
	_confirmation_pending = false
	_set_state(ApplicationShellState.starting(ApplicationShellState.Operation.CONTINUE))
	if _host != null and _host.request_continue():
		return true
	_show_request_failure(ApplicationOperationResult.Operation.CONTINUE)
	return false


func confirm_current_result() -> bool:
	if _state.mode() != ApplicationShellState.Mode.RESULT or not _confirmation_pending:
		return false
	_confirmation_pending = false
	return _start_new_game()


func dismiss_current_result() -> bool:
	if _state.mode() != ApplicationShellState.Mode.RESULT:
		return false
	_confirmation_pending = false
	_last_result = null
	_set_state(ApplicationShellState.main_menu())
	return true


func request_end_session() -> bool:
	if _state.mode() != ApplicationShellState.Mode.PLAYING or _host == null:
		return false
	return _host.request_end_session()


func _start_new_game() -> bool:
	_set_state(ApplicationShellState.starting(ApplicationShellState.Operation.NEW_GAME))
	if _host != null and _host.request_new_game():
		return true
	_show_request_failure(ApplicationOperationResult.Operation.NEW_GAME)
	return false


func _connect_host(host: OldPineGameRuntimeHost) -> void:
	host.startup_completed.connect(_on_host_startup_completed)
	host.slot_inspection_completed.connect(_on_slot_inspection_completed)
	host.new_game_completed.connect(_on_new_game_completed)
	host.continue_completed.connect(_on_continue_completed)
	host.end_session_completed.connect(_on_end_session_completed)


func _on_host_startup_completed(result: OldPineRuntimeSaveLoadResult) -> void:
	if not result.succeeded():
		_show_runtime_result(
			ApplicationOperationResult.Operation.INSPECT_SLOT,
			result,
		)
		return
	if not _host.session_invariant_holds():
		_show_session_invariant_failure(ApplicationOperationResult.Operation.INSPECT_SLOT)
		return
	if not _host.request_slot_inspection():
		_show_request_failure(ApplicationOperationResult.Operation.INSPECT_SLOT)


func _on_slot_inspection_completed(result: GameSaveResult) -> void:
	_slot_inspection = ApplicationProductResultMapper.inspect_slot(result)
	_last_result = null
	_set_state(ApplicationShellState.main_menu())


func _on_new_game_completed(result: OldPineRuntimeSaveLoadResult) -> void:
	if result.succeeded() and not _host.session_invariant_holds():
		_show_session_invariant_failure(ApplicationOperationResult.Operation.NEW_GAME)
		return
	if result.succeeded():
		_last_result = ApplicationProductResultMapper.runtime_result(
			ApplicationOperationResult.Operation.NEW_GAME,
			result,
		)
		_set_state(ApplicationShellState.playing())
		return
	_show_runtime_result(ApplicationOperationResult.Operation.NEW_GAME, result)


func _on_continue_completed(result: OldPineRuntimeSaveLoadResult) -> void:
	if result.succeeded() and not _host.session_invariant_holds():
		_show_session_invariant_failure(ApplicationOperationResult.Operation.CONTINUE)
		return
	if result.succeeded():
		_last_result = ApplicationProductResultMapper.runtime_result(
			ApplicationOperationResult.Operation.CONTINUE,
			result,
		)
		_set_state(ApplicationShellState.playing())
		return
	_show_runtime_result(ApplicationOperationResult.Operation.CONTINUE, result)


func _on_end_session_completed(result: OldPineRuntimeSaveLoadResult) -> void:
	if result.succeeded() and not _host.session_invariant_holds():
		_show_session_invariant_failure(ApplicationOperationResult.Operation.END_SESSION)
		return
	_last_result = ApplicationProductResultMapper.runtime_result(
		ApplicationOperationResult.Operation.END_SESSION,
		result,
	)
	if result.succeeded():
		_slot_inspection = null
		_set_state(ApplicationShellState.boot_inspecting())
		if not _host.request_slot_inspection():
			_show_request_failure(ApplicationOperationResult.Operation.INSPECT_SLOT)
		return
	_set_state(ApplicationShellState.result())


func _show_runtime_result(
	operation: int,
	result: OldPineRuntimeSaveLoadResult,
) -> void:
	_last_result = ApplicationProductResultMapper.runtime_result(operation, result)
	_confirmation_pending = false
	_set_state(ApplicationShellState.result())


func _show_request_failure(operation: int) -> void:
	_last_result = ApplicationOperationResult.new(
		operation,
		ApplicationOperationResult.Outcome.REQUEST_BUSY,
		&"operation.busy",
	)
	_confirmation_pending = false
	_set_state(ApplicationShellState.result())


func _show_session_invariant_failure(operation: int) -> void:
	_show_runtime_result(
		operation,
		OldPineRuntimeSaveLoadResult.failure(
			OldPineRuntimeSaveLoadResult.Outcome.SESSION_INVARIANT_FAILED
		),
	)


func _set_state(next: ApplicationShellState) -> bool:
	if next == null or not next.is_valid():
		return false
	_state = next
	if is_node_ready():
		_render_state()
	state_changed.emit(_state)
	return true


func _render_state() -> void:
	var mode: int = _state.mode()
	shell_canvas.visible = mode != ApplicationShellState.Mode.PLAYING
	main_menu_panel.visible = mode != ApplicationShellState.Mode.PLAYING
	busy_overlay.visible = (
		mode == ApplicationShellState.Mode.BOOT
		or mode == ApplicationShellState.Mode.STARTING_SESSION
	)
	result_overlay.visible = mode == ApplicationShellState.Mode.RESULT
	var menu_interactive: bool = mode == ApplicationShellState.Mode.MAIN_MENU
	new_game_button.disabled = not menu_interactive
	continue_button.disabled = (
		not menu_interactive
		or _slot_inspection == null
		or not _slot_inspection.continue_available()
	)
	status_label.text = (
		"Checking saved journey..."
		if _slot_inspection == null
		else ApplicationMessageCatalog.text_for(_slot_inspection.message_key())
	)
	busy_label.text = (
		"Checking saved journey..."
		if mode == ApplicationShellState.Mode.BOOT
		else "Starting journey..."
	)
	if result_overlay.visible:
		result_label.text = ApplicationMessageCatalog.text_for(_last_result.message_key())
		confirm_button.visible = _confirmation_pending
		cancel_button.visible = _confirmation_pending
		acknowledge_button.visible = not _confirmation_pending
		call_deferred("_focus_result_button")
	elif menu_interactive:
		call_deferred("_focus_first_menu_button")


func _focus_first_menu_button() -> void:
	if _state.mode() == ApplicationShellState.Mode.MAIN_MENU and not new_game_button.disabled:
		new_game_button.grab_focus()


func _focus_result_button() -> void:
	if _state.mode() != ApplicationShellState.Mode.RESULT:
		return
	if _confirmation_pending:
		confirm_button.grab_focus()
	else:
		acknowledge_button.grab_focus()


func _on_new_game_button_pressed() -> void:
	request_new_game_from_menu()


func _on_continue_button_pressed() -> void:
	request_continue_from_menu()


func _on_confirm_button_pressed() -> void:
	confirm_current_result()


func _on_cancel_button_pressed() -> void:
	dismiss_current_result()


func _on_acknowledge_button_pressed() -> void:
	dismiss_current_result()
