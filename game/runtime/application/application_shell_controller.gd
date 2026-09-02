class_name ApplicationShellController
extends Node

const HOST_SCENE: PackedScene = preload(
	"res://scenes/runtime/oldpine_game_runtime_host.tscn"
)

signal host_ready(host: OldPineGameRuntimeHost)
signal state_changed(state: ApplicationShellState)
signal input_context_changing
signal interaction_changed

@onready var runtime_host_slot: Node = %RuntimeHostSlot
@onready var shell_canvas: CanvasLayer = %ShellCanvas
@onready var main_menu_panel: Control = %MainMenuPanel
@onready var status_label: Label = %StatusLabel
@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var recovery_button: Button = %RecoveryButton
@onready var menu_settings_button: Button = %MenuSettingsButton
@onready var pause_panel: Control = %PausePanel
@onready var lifecycle_info: Label = %LifecycleInfo
@onready var resume_button: Button = %ResumeButton
@onready var save_button: Button = %SaveButton
@onready var pause_settings_button: Button = %PauseSettingsButton
@onready var return_button: Button = %ReturnButton
@onready var settings_panel: Control = %SettingsPanel
@onready var window_mode_row: Control = %WindowModeRow
@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var settings_status_label: Label = %SettingsStatusLabel
@onready var settings_apply_button: Button = %SettingsApplyButton
@onready var settings_cancel_button: Button = %SettingsCancelButton
@onready var recovery_panel: Control = %RecoveryPanel
@onready var backup_recovery_button: Button = %BackupRecoveryButton
@onready var temp_recovery_button: Button = %TempRecoveryButton
@onready var recovery_new_game_button: Button = %RecoveryNewGameButton
@onready var recovery_cancel_button: Button = %RecoveryCancelButton
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
var _settings_files: SaveFileOperations
var _window_capability: ApplicationWindowModeCapability
var _settings_repository: ApplicationSettingsRepository
var _settings_service: ApplicationSettingsService
var _settings_bootstrap_result: ApplicationSettingsServiceResult
var _configured: bool = false
var _host: OldPineGameRuntimeHost
var _state: ApplicationShellState = ApplicationShellState.new()
var _slot_inspection: ApplicationSlotInspection
var _last_result: ApplicationOperationResult
var _transition_held_actions: Array[StringName] = []
var _exit_capability: ApplicationExitCapability = ApplicationExitCapability.new()
var _quit_requested: bool = false
var _activity: ApplicationActivity = ApplicationActivity.new()


func activity() -> ApplicationActivity:
	return _activity


func interaction_allowed() -> bool:
	return _activity.interaction_allowed()


func _on_mobile_activity_event(event: ApplicationActivity.Event) -> void:
	var change: ApplicationActivity.Change = _activity.receive(event)
	if change == ApplicationActivity.Change.NONE:
		return
	input_context_changing.emit() # PAD/POINTER cancellation precedes global action release.
	_release_transition_actions()
	if change == ApplicationActivity.Change.INTERACTION_LOST:
		if _state.mode() == ApplicationShellState.Mode.PLAYING or _starting_session_operation():
			_activity.require_explicit_resume()
		get_tree().paused = true # Not the guarded user Pause request; Host stays ALWAYS.
		if is_node_ready():
			var presenter: SafeAreaPresenter = get_node_or_null("SafeAreaPresentation")
			if presenter != null:
				presenter.set_observation_enabled(false)
			if _state.mode() == ApplicationShellState.Mode.PLAYING:
				_set_state(ApplicationShellState.paused())
			else:
				_render_state() # Keep modal origin/draft/result unchanged.
		interaction_changed.emit()
	else:
		_refresh_mobile_presentation(_activity.presentation_revision())


func _presentation_entered(node: Node) -> void:
	if node is SafeAreaPresenter and node.name == &"SafeAreaPresentation" and not interaction_allowed():
		_refresh_mobile_presentation.call_deferred(_activity.presentation_revision())


func _refresh_mobile_presentation(revision: int) -> void:
	if not is_node_ready() or revision != _activity.presentation_revision() or not _activity.foreground() or not _activity.focused():
		return
	var presenter: SafeAreaPresenter = get_node_or_null("SafeAreaPresentation")
	if presenter == null or not presenter.is_inside_tree():
		return # Keep the gate closed; child reentry retries measurement, not OS polling.
	presenter.set_observation_enabled(true)
	_finish_mobile_reactivation.call_deferred(revision)


func _finish_mobile_reactivation(revision: int) -> void:
	var presenter: SafeAreaPresenter = get_node_or_null("SafeAreaPresentation")
	if not is_inside_tree() or presenter == null or not presenter.is_inside_tree() or not _activity.finish_reactivation(revision):
		return
	input_context_changing.emit()
	_release_transition_actions()
	_sync_application_pause()
	_render_state(false)
	interaction_changed.emit()


func _starting_session_operation() -> bool:
	return _state.operation() in [ApplicationShellState.Operation.NEW_GAME, ApplicationShellState.Operation.CONTINUE, ApplicationShellState.Operation.RECOVER]


func _sync_application_pause() -> void:
	if not is_inside_tree():
		return
	if _host_is_exactly_empty() and not _starting_session_operation():
		_activity.clear_resume_gate()
	var pause_context: bool = _state.mode() in [ApplicationShellState.Mode.PAUSED, ApplicationShellState.Mode.SAVING] or _state.settings_origin() == ApplicationShellState.SettingsOrigin.PAUSED or _state.result_origin() == ApplicationShellState.ResultOrigin.PAUSED or _state.operation() == ApplicationShellState.Operation.END_SESSION
	get_tree().paused = not interaction_allowed() or pause_context or _activity.resume_gate() == ApplicationActivity.ResumeGate.EXPLICIT_AFTER_LIFECYCLE


func _present_committed_session() -> void:
	if not interaction_allowed() or _activity.resume_gate() == ApplicationActivity.ResumeGate.EXPLICIT_AFTER_LIFECYCLE:
		_activity.require_explicit_resume()
		_set_state(ApplicationShellState.paused())
	else:
		_set_state(ApplicationShellState.playing())


func configure_before_start(
	profile: GameSaveStorageProfile,
	files: SaveFileOperations = null,
	coordinator: OldPineSessionLoadCoordinator = null,
	settings_files: SaveFileOperations = null,
	window_capability: ApplicationWindowModeCapability = null,
) -> bool:
	if _configured or is_node_ready() or profile == null or not profile.is_valid():
		return false
	_profile = profile
	_files = files
	_coordinator = coordinator
	_settings_files = settings_files
	_window_capability = window_capability
	_configured = true
	return true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	child_entered_tree.connect(_presentation_entered)
	if not _configured:
		_configured = true
	if _window_capability == null:
		_window_capability = GodotWindowModeCapability.new()
	_settings_repository = ApplicationSettingsRepository.new(_settings_files)
	_settings_service = ApplicationSettingsService.new(_settings_repository, _window_capability)
	_settings_bootstrap_result = _settings_service.load_and_apply()
	_configure_window_mode_options()
	window_mode_option.get_popup().window_input.connect(_popup_system_input)
	_set_state(ApplicationShellState.boot_inspecting())
	_host = HOST_SCENE.instantiate() as OldPineGameRuntimeHost
	_connect_host(_host)
	if not _host.configure_manual_before_start(_profile, _files, _coordinator):
		_show_request_failure(
			ApplicationOperationResult.Operation.INSPECT_SLOT,
			ApplicationShellState.ResultOrigin.MAIN_MENU,
		)
		return
	runtime_host_slot.add_child(_host)
	host_ready.emit(_host)


func _exit_tree() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.paused:
		tree.paused = false


func _input(event: InputEvent) -> void:
	if not interaction_allowed():
		_release_transition_actions()
		get_viewport().set_input_as_handled()
		return
	if event.is_action(&"system_back"):
		get_viewport().set_input_as_handled()
		if event.is_action_pressed(&"system_back") and not event.is_echo():
			_handle_system_back()
		return
	# action_release clears polling, but an OS keyboard echo can set it again.
	# Quarantine only actions held across a transition until release/fresh press;
	# ordinary held gameplay movement and normal menu navigation stay untouched.
	var suppressed_repeat: bool = false
	for action: StringName in _transition_held_actions.duplicate():
		if not event.is_action(action):
			continue
		if event.is_echo():
			Input.action_release(action)
			suppressed_repeat = true
		else:
			_transition_held_actions.erase(action)
	if suppressed_repeat:
		get_viewport().set_input_as_handled()
		return
	if _state.mode() in [
		ApplicationShellState.Mode.BOOT,
		ApplicationShellState.Mode.STARTING_SESSION,
		ApplicationShellState.Mode.SAVING,
	]:
		_release_transition_actions()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not interaction_allowed():
		get_viewport().set_input_as_handled()
		return
	var pause_pressed: bool = event.is_action_pressed("pause_game")
	var cancel_pressed: bool = event.is_action_pressed("ui_cancel")
	if not pause_pressed and not cancel_pressed:
		return
	var handled: bool = false
	match _state.mode():
		ApplicationShellState.Mode.PLAYING:
			if pause_pressed:
				handled = request_pause()
		ApplicationShellState.Mode.PAUSED:
			if pause_pressed or cancel_pressed:
				handled = request_resume()
		ApplicationShellState.Mode.RESULT:
			if cancel_pressed:
				handled = dismiss_current_result()
		ApplicationShellState.Mode.SETTINGS:
			if cancel_pressed:
				handled = cancel_settings()
		ApplicationShellState.Mode.RECOVERY_CHOICE:
			if cancel_pressed:
				handled = cancel_recovery_choice()
	if handled:
		get_viewport().set_input_as_handled()


func runtime_host() -> OldPineGameRuntimeHost:
	return _host


func set_exit_capability(capability: ApplicationExitCapability) -> void:
	if capability != null:
		_exit_capability = capability


func _popup_system_input(event: InputEvent) -> void:
	if not interaction_allowed():
		_release_transition_actions()
		window_mode_option.get_popup().set_input_as_handled()
		return
	# A native/embedded Popup is its own Viewport and receives focused input before
	# the root. Keep the same Shell policy rather than inventing a popup-state flag.
	if event.is_action(&"system_back"):
		window_mode_option.get_popup().set_input_as_handled()
		if event.is_action_pressed(&"system_back"):
			_handle_system_back()


func _handle_system_back() -> void:
	if not interaction_allowed():
		return
	if _state.mode() in [ApplicationShellState.Mode.BOOT, ApplicationShellState.Mode.STARTING_SESSION, ApplicationShellState.Mode.SAVING] or (_host != null and _host.request_pending()):
		return
	input_context_changing.emit()
	if window_mode_option.get_popup().visible:
		window_mode_option.get_popup().hide()
		return
	match _state.mode():
		ApplicationShellState.Mode.RESULT:
			dismiss_current_result()
		ApplicationShellState.Mode.SETTINGS:
			cancel_settings()
		ApplicationShellState.Mode.RECOVERY_CHOICE:
			cancel_recovery_choice()
		ApplicationShellState.Mode.PAUSED:
			request_resume()
		ApplicationShellState.Mode.PLAYING:
			var panel: ResponsivePanelLayout = ResponsivePanelLayout.top_interaction_panel(get_tree())
			if panel != null:
				panel.dismiss_requested.emit()
			else:
				request_pause()
		ApplicationShellState.Mode.MAIN_MENU:
			if _host_is_exactly_empty() and not _quit_requested:
				_quit_requested = true
				_exit_capability.request_quit(get_tree())


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


func pause_visible() -> bool:
	return pause_panel != null and pause_panel.visible


func recovery_visible() -> bool:
	return recovery_panel != null and recovery_panel.visible


func busy_visible() -> bool:
	return busy_overlay != null and busy_overlay.visible


func result_visible() -> bool:
	return result_overlay != null and result_overlay.visible


func continue_enabled() -> bool:
	return continue_button != null and not continue_button.disabled


func recovery_enabled() -> bool:
	return recovery_button != null and not recovery_button.disabled


func status_text() -> String:
	return "" if status_label == null else status_label.text


func settings_visible() -> bool:
	return settings_panel != null and settings_panel.visible


func settings_editable() -> bool:
	return _settings_service != null and _settings_service.can_edit_window_mode()


func committed_window_mode() -> int:
	return (
		_settings_service.committed_snapshot().window_mode()
		if _settings_service != null
		else ApplicationWindowMode.Value.WINDOWED
	)


func settings_storage_path() -> String:
	return ApplicationSettingsRepository.SETTINGS_PATH


func settings_bootstrap_result() -> ApplicationSettingsServiceResult:
	return _settings_bootstrap_result


func request_new_game_from_menu() -> bool:
	if not interaction_allowed():
		return false
	if _state.mode() != ApplicationShellState.Mode.MAIN_MENU:
		return false
	if _slot_inspection != null and _slot_inspection.has_save_material():
		return _show_new_game_confirmation()
	return _start_new_game()


func request_continue_from_menu() -> bool:
	if not interaction_allowed():
		return false
	if (
		_state.mode() != ApplicationShellState.Mode.MAIN_MENU
		or _slot_inspection == null
		or not _slot_inspection.continue_available()
	):
		return false
	_last_result = null
	_set_state(ApplicationShellState.starting(ApplicationShellState.Operation.CONTINUE))
	if _host != null and _host.request_continue():
		return true
	_show_request_failure(
		ApplicationOperationResult.Operation.CONTINUE,
		ApplicationShellState.ResultOrigin.MAIN_MENU,
	)
	return false


func request_recovery_choice_from_menu() -> bool:
	if not interaction_allowed():
		return false
	if (
		_state.mode() != ApplicationShellState.Mode.MAIN_MENU
		or _slot_inspection == null
		or not _slot_inspection.recovery_available()
	):
		return false
	_set_state(ApplicationShellState.recovery_choice())
	return true


func cancel_recovery_choice() -> bool:
	if not interaction_allowed():
		return false
	if _state.mode() != ApplicationShellState.Mode.RECOVERY_CHOICE:
		return false
	_set_state(ApplicationShellState.main_menu())
	return true


func request_settings_from_main_menu() -> bool:
	if not interaction_allowed():
		return false
	if _state.mode() != ApplicationShellState.Mode.MAIN_MENU:
		return false
	return _open_settings(ApplicationShellState.SettingsOrigin.MAIN_MENU)


func request_settings_from_pause() -> bool:
	if not interaction_allowed():
		return false
	if _state.mode() != ApplicationShellState.Mode.PAUSED or not get_tree().paused:
		return false
	return _open_settings(ApplicationShellState.SettingsOrigin.PAUSED)


func cancel_settings() -> bool:
	if not interaction_allowed():
		return false
	if _state.mode() != ApplicationShellState.Mode.SETTINGS:
		return false
	var origin: int = _state.settings_origin()
	settings_status_label.text = ""
	return _return_from_settings(origin)


func apply_settings() -> bool:
	if not interaction_allowed():
		return false
	if _state.mode() != ApplicationShellState.Mode.SETTINGS or _settings_service == null:
		return false
	if not _settings_service.can_edit_window_mode():
		settings_status_label.text = "Window mode is managed by this platform."
		return false
	var selected_mode: int = window_mode_option.get_selected_id()
	var result: ApplicationSettingsServiceResult = _settings_service.apply_and_persist(selected_mode)
	match result.outcome():
		ApplicationSettingsServiceResult.Outcome.SUCCESS:
			settings_status_label.text = ""
			return _return_from_settings(_state.settings_origin())
		ApplicationSettingsServiceResult.Outcome.PERSISTENCE_FAILURE:
			settings_status_label.text = (
				"Window mode was applied for this run, but the setting could not be saved."
			)
			return false
		ApplicationSettingsServiceResult.Outcome.APPLY_FAILURE:
			settings_status_label.text = "Window mode could not be applied."
			_select_committed_window_mode()
			return false
		_:
			settings_status_label.text = "Window mode is managed by this platform."
			return false


func _open_settings(origin: int) -> bool:
	if (
		origin not in [
			ApplicationShellState.SettingsOrigin.MAIN_MENU,
			ApplicationShellState.SettingsOrigin.PAUSED,
		]
		or (origin == ApplicationShellState.SettingsOrigin.PAUSED and not get_tree().paused)
	):
		return false
	settings_status_label.text = ""
	_select_committed_window_mode()
	return _set_state(ApplicationShellState.settings(origin))


func _return_from_settings(origin: int) -> bool:
	if origin == ApplicationShellState.SettingsOrigin.PAUSED:
		if not get_tree().paused:
			return false
		return _set_state(ApplicationShellState.paused())
	if origin == ApplicationShellState.SettingsOrigin.MAIN_MENU:
		return _set_state(ApplicationShellState.main_menu())
	return false


func request_recovery_source(source: int) -> bool:
	if not interaction_allowed():
		return false
	if (
		_state.mode() != ApplicationShellState.Mode.RECOVERY_CHOICE
		or _slot_inspection == null
		or not _slot_inspection.has_recovery_source(source)
	):
		return false
	_last_result = null
	_set_state(ApplicationShellState.starting(ApplicationShellState.Operation.RECOVER))
	if _host != null and _host.request_recovery(source):
		return true
	_show_request_failure(
		ApplicationOperationResult.Operation.RECOVER,
		ApplicationShellState.ResultOrigin.MAIN_MENU,
	)
	return false


func request_pause() -> bool:
	if not interaction_allowed():
		return false
	if (
		_state.mode() != ApplicationShellState.Mode.PLAYING
		or _host == null
		or _host.request_pending()
		or _host.current_session() == null
		or not _host.session_invariant_holds()
	):
		return false
	get_tree().paused = true
	_set_state(ApplicationShellState.paused())
	return true


func request_resume() -> bool:
	if not interaction_allowed():
		return false
	if (
		_state.mode() != ApplicationShellState.Mode.PAUSED
		or _host == null
		or _host.request_pending()
		or _host.current_session() == null
		or not _host.session_invariant_holds()
	):
		return false
	_activity.clear_resume_gate()
	_set_state(ApplicationShellState.playing())
	get_tree().paused = false
	return true


func request_save_from_pause() -> bool:
	if not interaction_allowed():
		return false
	if (
		_state.mode() != ApplicationShellState.Mode.PAUSED
		or not get_tree().paused
		or _host == null
	):
		return false
	_last_result = null
	_set_state(ApplicationShellState.saving())
	if _host.request_save():
		return true
	_show_request_failure(
		ApplicationOperationResult.Operation.SAVE,
		ApplicationShellState.ResultOrigin.PAUSED,
	)
	return false


func request_return_to_main_menu() -> bool:
	if not interaction_allowed():
		return false
	if _state.mode() != ApplicationShellState.Mode.PAUSED:
		return false
	_last_result = ApplicationOperationResult.new(
		ApplicationOperationResult.Operation.END_SESSION,
		ApplicationOperationResult.Outcome.CONFIRMATION_REQUIRED,
		&"return.confirm",
	)
	_set_state(ApplicationShellState.result(ApplicationShellState.ResultOrigin.PAUSED))
	return true


func confirm_current_result() -> bool:
	if not interaction_allowed():
		return false
	if (
		_state.mode() != ApplicationShellState.Mode.RESULT
		or _last_result == null
		or _last_result.outcome() != ApplicationOperationResult.Outcome.CONFIRMATION_REQUIRED
	):
		return false
	match _last_result.operation():
		ApplicationOperationResult.Operation.NEW_GAME:
			return _start_new_game()
		ApplicationOperationResult.Operation.END_SESSION:
			return _start_end_session()
	return false


func dismiss_current_result() -> bool:
	if not interaction_allowed():
		return false
	if _state.mode() != ApplicationShellState.Mode.RESULT:
		return false
	var origin: int = _state.result_origin()
	_last_result = null
	if origin == ApplicationShellState.ResultOrigin.PAUSED:
		_set_state(ApplicationShellState.paused())
		return true
	_set_state(ApplicationShellState.main_menu())
	return true


func _show_new_game_confirmation() -> bool:
	_last_result = ApplicationOperationResult.new(
		ApplicationOperationResult.Operation.NEW_GAME,
		ApplicationOperationResult.Outcome.CONFIRMATION_REQUIRED,
		&"new_game.confirm",
	)
	_set_state(ApplicationShellState.result(ApplicationShellState.ResultOrigin.MAIN_MENU))
	return true


func _start_new_game() -> bool:
	_last_result = null
	_set_state(ApplicationShellState.starting(ApplicationShellState.Operation.NEW_GAME))
	if _host != null and _host.request_new_game():
		return true
	_show_request_failure(
		ApplicationOperationResult.Operation.NEW_GAME,
		ApplicationShellState.ResultOrigin.MAIN_MENU,
	)
	return false


func _start_end_session() -> bool:
	if not get_tree().paused or _host == null:
		return false
	_set_state(ApplicationShellState.starting(ApplicationShellState.Operation.END_SESSION))
	if _host.request_end_session():
		return true
	_show_request_failure(
		ApplicationOperationResult.Operation.END_SESSION,
		ApplicationShellState.ResultOrigin.PAUSED,
	)
	return false


func _connect_host(host: OldPineGameRuntimeHost) -> void:
	host.startup_completed.connect(_on_host_startup_completed)
	host.slot_inspection_completed.connect(_on_slot_inspection_completed)
	host.new_game_completed.connect(_on_new_game_completed)
	host.continue_completed.connect(_on_continue_completed)
	host.recovery_completed.connect(_on_recovery_completed)
	host.save_completed.connect(_on_save_completed)
	host.end_session_completed.connect(_on_end_session_completed)


func _on_host_startup_completed(result: OldPineRuntimeSaveLoadResult) -> void:
	if not result.succeeded():
		_show_runtime_result(
			ApplicationOperationResult.Operation.INSPECT_SLOT,
			result,
			ApplicationShellState.ResultOrigin.MAIN_MENU,
		)
		return
	if not _host.session_invariant_holds():
		_show_session_invariant_failure(
			ApplicationOperationResult.Operation.INSPECT_SLOT,
			ApplicationShellState.ResultOrigin.MAIN_MENU,
		)
		return
	if not _host.request_slot_inspection():
		_show_request_failure(
			ApplicationOperationResult.Operation.INSPECT_SLOT,
			ApplicationShellState.ResultOrigin.MAIN_MENU,
		)


func _on_slot_inspection_completed(result: GameSaveSlotInspectionResult) -> void:
	_slot_inspection = ApplicationProductResultMapper.inspect_slot(result)
	_last_result = null
	_set_state(ApplicationShellState.main_menu())


func _on_new_game_completed(result: OldPineRuntimeSaveLoadResult) -> void:
	if result.succeeded() and not _host.session_invariant_holds():
		_show_session_invariant_failure(
			ApplicationOperationResult.Operation.NEW_GAME,
			ApplicationShellState.ResultOrigin.MAIN_MENU,
		)
		return
	if result.succeeded():
		_last_result = ApplicationProductResultMapper.runtime_result(
			ApplicationOperationResult.Operation.NEW_GAME,
			result,
		)
		_present_committed_session()
		return
	_show_runtime_result(
		ApplicationOperationResult.Operation.NEW_GAME,
		result,
		ApplicationShellState.ResultOrigin.MAIN_MENU,
	)


func _on_continue_completed(result: OldPineRuntimeSaveLoadResult) -> void:
	_handle_load_completion(ApplicationOperationResult.Operation.CONTINUE, result)


func _on_recovery_completed(result: OldPineRuntimeSaveLoadResult) -> void:
	_handle_load_completion(ApplicationOperationResult.Operation.RECOVER, result)


func _handle_load_completion(
	operation: int,
	result: OldPineRuntimeSaveLoadResult,
) -> void:
	if result.succeeded() and not _host.session_invariant_holds():
		_show_session_invariant_failure(
			operation,
			ApplicationShellState.ResultOrigin.MAIN_MENU,
		)
		return
	if result.succeeded():
		_last_result = ApplicationProductResultMapper.runtime_result(operation, result)
		_present_committed_session()
		return
	_show_runtime_result(
		operation,
		result,
		ApplicationShellState.ResultOrigin.MAIN_MENU,
	)


func _on_save_completed(result: OldPineRuntimeSaveLoadResult) -> void:
	_show_runtime_result(
		ApplicationOperationResult.Operation.SAVE,
		result,
		ApplicationShellState.ResultOrigin.PAUSED,
	)


func _on_end_session_completed(result: OldPineRuntimeSaveLoadResult) -> void:
	if result.succeeded() and _host_is_exactly_empty():
		_activity.clear_resume_gate()
		_slot_inspection = null
		_last_result = null
		_set_state(ApplicationShellState.boot_inspecting())
		if not _host.request_slot_inspection():
			_show_request_failure(
				ApplicationOperationResult.Operation.INSPECT_SLOT,
				ApplicationShellState.ResultOrigin.MAIN_MENU,
			)
		return
	var origin: int = (
		ApplicationShellState.ResultOrigin.PAUSED
		if (
			_host.current_session() != null
			and _host.current_session().get_parent() == _host.session_slot
		)
		else ApplicationShellState.ResultOrigin.MAIN_MENU
	)
	_show_runtime_result(ApplicationOperationResult.Operation.END_SESSION, result, origin)


func _show_runtime_result(
	operation: int,
	result: OldPineRuntimeSaveLoadResult,
	origin: int,
) -> void:
	_last_result = ApplicationProductResultMapper.runtime_result(operation, result)
	_set_state(ApplicationShellState.result(origin))


func _show_request_failure(operation: int, origin: int) -> void:
	_last_result = ApplicationOperationResult.new(
		operation,
		ApplicationOperationResult.Outcome.REQUEST_BUSY,
		&"operation.busy",
	)
	_set_state(ApplicationShellState.result(origin))


func _show_session_invariant_failure(operation: int, origin: int) -> void:
	_show_runtime_result(
		operation,
		OldPineRuntimeSaveLoadResult.failure(
			OldPineRuntimeSaveLoadResult.Outcome.SESSION_INVARIANT_FAILED
		),
		origin,
	)


func _host_is_exactly_empty() -> bool:
	return (
		_host != null
		and _host.current_session() == null
		and _host.session_slot.get_child_count() == 0
		and _host.staging_slot.get_child_count() == 0
		and _host.session_invariant_holds()
	)


func _set_state(next: ApplicationShellState) -> bool:
	if next == null or not next.is_valid():
		return false
	# Host completions and mouse/keyboard intents share the same boundary. Clear
	# polling state before exposing the next surface or a newly playable Session.
	input_context_changing.emit()
	_release_transition_actions()
	_state = next
	_sync_application_pause()
	if is_node_ready():
		_render_state()
	state_changed.emit(_state)
	return true


func _render_state(defer_focus: bool = true) -> void:
	var mode: int = _state.mode()
	lifecycle_info.visible = _activity.resume_gate() == ApplicationActivity.ResumeGate.EXPLICIT_AFTER_LIFECYCLE
	_release_shell_focus()
	shell_canvas.visible = mode != ApplicationShellState.Mode.PLAYING
	main_menu_panel.visible = mode == ApplicationShellState.Mode.MAIN_MENU
	pause_panel.visible = mode == ApplicationShellState.Mode.PAUSED
	settings_panel.visible = mode == ApplicationShellState.Mode.SETTINGS
	recovery_panel.visible = mode == ApplicationShellState.Mode.RECOVERY_CHOICE
	busy_overlay.visible = mode in [
		ApplicationShellState.Mode.BOOT,
		ApplicationShellState.Mode.STARTING_SESSION,
		ApplicationShellState.Mode.SAVING,
	]
	result_overlay.visible = mode == ApplicationShellState.Mode.RESULT
	var menu_interactive: bool = mode == ApplicationShellState.Mode.MAIN_MENU
	new_game_button.disabled = not menu_interactive
	menu_settings_button.disabled = not menu_interactive
	continue_button.disabled = (
		not menu_interactive
		or _slot_inspection == null
		or not _slot_inspection.continue_available()
	)
	recovery_button.disabled = (
		not menu_interactive
		or _slot_inspection == null
		or not _slot_inspection.recovery_available()
	)
	var pause_interactive: bool = mode == ApplicationShellState.Mode.PAUSED
	resume_button.disabled = not pause_interactive
	save_button.disabled = not pause_interactive
	pause_settings_button.disabled = not pause_interactive
	return_button.disabled = not pause_interactive
	var recovery_interactive: bool = mode == ApplicationShellState.Mode.RECOVERY_CHOICE
	backup_recovery_button.disabled = not recovery_interactive
	temp_recovery_button.disabled = not recovery_interactive
	recovery_new_game_button.disabled = not recovery_interactive
	recovery_cancel_button.disabled = not recovery_interactive
	var settings_interactive: bool = mode == ApplicationShellState.Mode.SETTINGS
	window_mode_row.visible = _settings_service != null and _settings_service.can_edit_window_mode()
	window_mode_option.disabled = not settings_interactive or not window_mode_row.visible
	settings_apply_button.visible = window_mode_row.visible
	settings_apply_button.disabled = not settings_interactive
	settings_cancel_button.disabled = not settings_interactive
	status_label.text = (
		"Checking saved journey..."
		if _slot_inspection == null
		else ApplicationMessageCatalog.text_for(_slot_inspection.message_key())
	)
	backup_recovery_button.visible = (
		_slot_inspection != null
		and _slot_inspection.has_recovery_source(GameSaveRecoverySource.Value.BACKUP)
	)
	temp_recovery_button.visible = (
		_slot_inspection != null
		and _slot_inspection.has_recovery_source(GameSaveRecoverySource.Value.TEMP)
	)
	busy_label.text = _busy_text()
	if result_overlay.visible:
		_render_result()
	_configure_active_focus_cycle(mode)
	if not interaction_allowed():
		for control: Control in _all_shell_focus_controls():
			(control as BaseButton).disabled = true
		_release_shell_focus()
	elif defer_focus:
		_focus_current_surface.call_deferred()
	else:
		_focus_current_surface()


func _focus_current_surface() -> void:
	match _state.mode():
		ApplicationShellState.Mode.RESULT: _focus_result_button()
		ApplicationShellState.Mode.SETTINGS: _focus_settings_control()
		ApplicationShellState.Mode.RECOVERY_CHOICE: _focus_recovery_button()
		ApplicationShellState.Mode.PAUSED: _focus_pause_button()
		ApplicationShellState.Mode.MAIN_MENU: _focus_first_menu_button()


func _busy_text() -> String:
	if _state.mode() == ApplicationShellState.Mode.BOOT:
		return "Checking saved journey..."
	if _state.mode() == ApplicationShellState.Mode.SAVING:
		return "Saving journey..."
	if _state.operation() == ApplicationShellState.Operation.END_SESSION:
		return "Returning to Main Menu..."
	if _state.operation() == ApplicationShellState.Operation.RECOVER:
		return "Recovering journey..."
	return "Starting journey..."


func _render_result() -> void:
	result_label.text = (
		ApplicationMessageCatalog.text_for(_last_result.message_key())
		if _last_result != null
		else ApplicationMessageCatalog.text_for(&"operation.session_failure")
	)
	var confirmation: bool = (
		_last_result != null
		and _last_result.outcome() == ApplicationOperationResult.Outcome.CONFIRMATION_REQUIRED
	)
	confirm_button.visible = confirmation
	cancel_button.visible = confirmation
	acknowledge_button.visible = not confirmation
	confirm_button.disabled = not confirmation
	cancel_button.disabled = not confirmation
	acknowledge_button.disabled = confirmation
	if confirmation and _last_result.operation() == ApplicationOperationResult.Operation.END_SESSION:
		confirm_button.text = "Return to Main Menu"
	else:
		confirm_button.text = "Start New Game"


func _configure_window_mode_options() -> void:
	window_mode_option.clear()
	window_mode_option.add_item("Windowed", ApplicationWindowMode.Value.WINDOWED)
	window_mode_option.add_item("Fullscreen", ApplicationWindowMode.Value.FULLSCREEN)
	_select_committed_window_mode()


func _select_committed_window_mode() -> void:
	if window_mode_option == null or _settings_service == null:
		return
	var index: int = window_mode_option.get_item_index(
		_settings_service.committed_snapshot().window_mode()
	)
	if index >= 0:
		window_mode_option.select(index)


func _all_shell_focus_controls() -> Array[Control]:
	return [
		new_game_button,
		continue_button,
		recovery_button,
		menu_settings_button,
		resume_button,
		save_button,
		pause_settings_button,
		return_button,
		window_mode_option,
		settings_apply_button,
		settings_cancel_button,
		backup_recovery_button,
		temp_recovery_button,
		recovery_new_game_button,
		recovery_cancel_button,
		confirm_button,
		cancel_button,
		acknowledge_button,
	]


func _release_shell_focus() -> void:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner != null and shell_canvas.is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	for control: Control in _all_shell_focus_controls():
		control.focus_mode = Control.FOCUS_NONE


func _configure_active_focus_cycle(mode: int) -> void:
	var controls: Array[Control] = []
	match mode:
		ApplicationShellState.Mode.MAIN_MENU:
			controls = [new_game_button]
			if not continue_button.disabled:
				controls.append(continue_button)
			if not recovery_button.disabled:
				controls.append(recovery_button)
			controls.append(menu_settings_button)
		ApplicationShellState.Mode.PAUSED:
			controls = [resume_button, save_button, pause_settings_button, return_button]
		ApplicationShellState.Mode.SETTINGS:
			if window_mode_row.visible:
				controls = [window_mode_option, settings_apply_button, settings_cancel_button]
			else:
				controls = [settings_cancel_button]
		ApplicationShellState.Mode.RECOVERY_CHOICE:
			if backup_recovery_button.visible:
				controls.append(backup_recovery_button)
			if temp_recovery_button.visible:
				controls.append(temp_recovery_button)
			controls.append(recovery_new_game_button)
			controls.append(recovery_cancel_button)
		ApplicationShellState.Mode.RESULT:
			if confirm_button.visible:
				controls = [confirm_button, cancel_button]
			else:
				controls = [acknowledge_button]
	if controls.is_empty():
		return
	for index: int in range(controls.size()):
		var control: Control = controls[index]
		var previous: Control = controls[(index - 1 + controls.size()) % controls.size()]
		var next: Control = controls[(index + 1) % controls.size()]
		control.focus_mode = Control.FOCUS_ALL
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_left = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)
		control.focus_neighbor_right = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)


func _release_transition_actions() -> void:
	for action: StringName in [
		&"move_left",
		&"move_right",
		&"move_up",
		&"move_down",
		&"ui_accept",
		&"ui_cancel",
		&"pause_game",
		&"system_back",
	]:
		if Input.is_action_pressed(action) and not _transition_held_actions.has(action):
			_transition_held_actions.append(action)
		Input.action_release(action)


func _focus_first_menu_button() -> void:
	if not interaction_allowed():
		return
	if _state.mode() == ApplicationShellState.Mode.MAIN_MENU and not new_game_button.disabled:
		new_game_button.grab_focus()


func _focus_settings_control() -> void:
	if not interaction_allowed():
		return
	if _state.mode() != ApplicationShellState.Mode.SETTINGS:
		return
	if window_mode_row.visible and not window_mode_option.disabled:
		window_mode_option.grab_focus()
	else:
		settings_cancel_button.grab_focus()


func _focus_pause_button() -> void:
	if not interaction_allowed():
		return
	if _state.mode() == ApplicationShellState.Mode.PAUSED:
		resume_button.grab_focus()


func _focus_recovery_button() -> void:
	if not interaction_allowed():
		return
	if _state.mode() != ApplicationShellState.Mode.RECOVERY_CHOICE:
		return
	if backup_recovery_button.visible:
		backup_recovery_button.grab_focus()
	elif temp_recovery_button.visible:
		temp_recovery_button.grab_focus()
	else:
		recovery_new_game_button.grab_focus()


func _focus_result_button() -> void:
	if not interaction_allowed():
		return
	if _state.mode() != ApplicationShellState.Mode.RESULT:
		return
	if confirm_button.visible:
		confirm_button.grab_focus()
	else:
		acknowledge_button.grab_focus()


func _on_new_game_button_pressed() -> void:
	request_new_game_from_menu()


func _on_continue_button_pressed() -> void:
	request_continue_from_menu()


func _on_recovery_button_pressed() -> void:
	request_recovery_choice_from_menu()


func _on_menu_settings_button_pressed() -> void:
	request_settings_from_main_menu()


func _on_resume_button_pressed() -> void:
	request_resume()


func _on_save_button_pressed() -> void:
	request_save_from_pause()


func _on_pause_settings_button_pressed() -> void:
	request_settings_from_pause()


func _on_return_button_pressed() -> void:
	request_return_to_main_menu()


func _on_settings_apply_button_pressed() -> void:
	apply_settings()


func _on_settings_cancel_button_pressed() -> void:
	cancel_settings()


func _on_backup_recovery_button_pressed() -> void:
	request_recovery_source(GameSaveRecoverySource.Value.BACKUP)


func _on_temp_recovery_button_pressed() -> void:
	request_recovery_source(GameSaveRecoverySource.Value.TEMP)


func _on_recovery_new_game_button_pressed() -> void:
	if not interaction_allowed():
		return
	if _state.mode() == ApplicationShellState.Mode.RECOVERY_CHOICE:
		_show_new_game_confirmation()


func _on_recovery_cancel_button_pressed() -> void:
	cancel_recovery_choice()


func _on_confirm_button_pressed() -> void:
	confirm_current_result()


func _on_cancel_button_pressed() -> void:
	dismiss_current_result()


func _on_acknowledge_button_pressed() -> void:
	dismiss_current_result()
