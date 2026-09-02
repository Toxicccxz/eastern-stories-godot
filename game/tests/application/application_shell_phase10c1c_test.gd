extends RefCounted

const SHELL_SCENE: PackedScene = preload(
	"res://scenes/application/application_shell.tscn"
)

class MemoryFiles extends SaveFileOperations:
	var files: Dictionary[String, PackedByteArray] = {}
	var read_error: int = OK
	var write_error: int = OK
	var directory_error: int = OK

	func file_exists(path: String) -> bool:
		return files.has(path)

	func make_directory_recursive(_path: String) -> int:
		return directory_error

	func read_bytes(path: String, maximum_bytes: int) -> SaveFileReadResult:
		if read_error != OK:
			return SaveFileReadResult.new(read_error)
		if not files.has(path):
			return SaveFileReadResult.new(ERR_FILE_NOT_FOUND)
		var bytes: PackedByteArray = files[path]
		if bytes.size() > maximum_bytes:
			return SaveFileReadResult.new(SaveFileReadResult.ERROR_FILE_TOO_LARGE)
		return SaveFileReadResult.new(OK, bytes.duplicate(), bytes.size())

	func write_bytes(path: String, bytes: PackedByteArray) -> int:
		if write_error != OK:
			return write_error
		files[path] = bytes.duplicate()
		return OK


class FakeWindowCapability extends ApplicationWindowModeCapability:
	var editable: bool = true
	var mode: int = ApplicationWindowMode.Value.WINDOWED
	var fail_apply: bool = false
	var apply_calls: Array[int] = []

	func can_edit_window_mode() -> bool:
		return editable

	func current_window_mode() -> int:
		return mode

	func apply_window_mode(requested_mode: int) -> bool:
		apply_calls.append(requested_mode)
		if not editable or fail_apply or not ApplicationWindowMode.is_valid(requested_mode):
			return false
		mode = requested_mode
		return true


var _assertions: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_snapshot_and_repository()
	_test_service_policy()
	_test_state_model()
	await _test_main_menu_settings_and_focus(tree)
	await _test_paused_settings_freeze_and_cancel(tree)
	await _test_input_focus_cancel_and_bleed(tree)
	await _test_native_gamepad_navigation(tree)
	await _test_unsupported_capability_ui(tree)
	await _test_settings_and_game_save_separation(tree)
	await _test_valid_save_independence_and_ui_failure(tree)
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_snapshot_and_repository() -> void:
	var defaults: ApplicationSettingsSnapshot = ApplicationSettingsSnapshot.defaults()
	_assert_true(defaults.is_valid(), "default settings snapshot is valid")
	_assert_eq(defaults.version(), 1, "settings schema is v1")
	_assert_eq(defaults.window_mode(), ApplicationWindowMode.Value.WINDOWED, "desktop-safe default is Windowed")
	_assert_false(ApplicationSettingsSnapshot.new(2).is_valid(), "unsupported snapshot version rejects")
	_assert_false(ApplicationSettingsSnapshot.new(1, 99).is_valid(), "unknown window mode rejects")

	var files := MemoryFiles.new()
	var repository := ApplicationSettingsRepository.new(files)
	_assert_eq(repository.storage_path(), "user://settings/application-v1.cfg", "settings path is fixed and separate")
	_assert_eq(repository.load().outcome(), ApplicationSettingsResult.Outcome.NO_SETTINGS, "missing settings defaults")
	var write: ApplicationSettingsResult = repository.write(
		ApplicationSettingsSnapshot.new(1, ApplicationWindowMode.Value.FULLSCREEN)
	)
	_assert_true(write.succeeded(), "valid settings write succeeds")
	var loaded: ApplicationSettingsResult = repository.load()
	_assert_true(loaded.succeeded(), "valid settings reload succeeds")
	_assert_eq(loaded.snapshot().window_mode(), ApplicationWindowMode.Value.FULLSCREEN, "window mode round-trips")

	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "not a cfg [".to_utf8_buffer()
	_assert_eq(repository.load().outcome(), ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "malformed ConfigFile rejects")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = _config_bytes(2, "windowed")
	_assert_eq(repository.load().outcome(), ApplicationSettingsResult.Outcome.UNSUPPORTED_VERSION, "unknown schema rejects distinctly")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = _config_bytes(1, "borderless")
	_assert_eq(repository.load().outcome(), ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "unknown enum rejects")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = (
		"[application]\nschema_version=1\nwindow_mode=1\n".to_utf8_buffer()
	)
	_assert_eq(repository.load().outcome(), ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "wrong value type rejects")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = (
		"[application]\nschema_version=1\nwindow_mode=\"windowed\"\nextra=true\n".to_utf8_buffer()
	)
	_assert_eq(repository.load().outcome(), ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "unexpected key rejects")
	for invalid: String in [
		"[wrong]\nschema_version=1\nwindow_mode=\"windowed\"\n",
		"[application]\nschema_version=1\n",
		"[application]\nschema_version=\"1\"\nwindow_mode=\"windowed\"\n",
		"[application]\nschema_version=1\nwindow_mode=\"windowed\"\n[extra]\nvalue=1\n",
	]:
		files.files[ApplicationSettingsRepository.SETTINGS_PATH] = invalid.to_utf8_buffer()
		_assert_eq(repository.load().outcome(), ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "strict section/key/version type rejects")
	files.read_error = ERR_CANT_OPEN
	_assert_eq(repository.load().outcome(), ApplicationSettingsResult.Outcome.READ_FAILURE, "read failure is typed")
	files.read_error = OK
	files.write_error = ERR_CANT_CREATE
	_assert_eq(repository.write(defaults).outcome(), ApplicationSettingsResult.Outcome.WRITE_FAILURE, "write failure is typed")
	files.write_error = OK
	files.directory_error = ERR_CANT_CREATE
	_assert_eq(repository.write(defaults).outcome(), ApplicationSettingsResult.Outcome.WRITE_FAILURE, "directory failure is typed")


func _test_service_policy() -> void:
	var files := MemoryFiles.new()
	var capability := FakeWindowCapability.new()
	var service := ApplicationSettingsService.new(ApplicationSettingsRepository.new(files), capability)
	var missing: ApplicationSettingsServiceResult = service.load_and_apply()
	_assert_eq(missing.outcome(), ApplicationSettingsServiceResult.Outcome.DEFAULTED, "missing settings uses safe default")
	_assert_eq(capability.apply_calls, [ApplicationWindowMode.Value.WINDOWED], "default is applied exactly once")

	var applied: ApplicationSettingsServiceResult = service.apply_and_persist(ApplicationWindowMode.Value.FULLSCREEN)
	_assert_true(applied.succeeded(), "runtime apply plus persistence succeeds")
	_assert_eq(capability.mode, ApplicationWindowMode.Value.FULLSCREEN, "capability receives selected mode")
	_assert_true(files.files.has(ApplicationSettingsRepository.SETTINGS_PATH), "settings persist only in application path")

	capability.fail_apply = true
	var persisted_before: PackedByteArray = files.files[ApplicationSettingsRepository.SETTINGS_PATH].duplicate()
	var calls_before: int = capability.apply_calls.size()
	var apply_failure: ApplicationSettingsServiceResult = service.apply_and_persist(ApplicationWindowMode.Value.WINDOWED)
	_assert_eq(apply_failure.outcome(), ApplicationSettingsServiceResult.Outcome.APPLY_FAILURE, "runtime failure is distinct")
	_assert_eq(service.committed_snapshot().window_mode(), ApplicationWindowMode.Value.FULLSCREEN, "failed apply preserves committed value")
	_assert_eq(capability.apply_calls.size(), calls_before + 1, "failed apply is attempted once")
	_assert_eq(files.files[ApplicationSettingsRepository.SETTINGS_PATH], persisted_before, "failed runtime apply cannot persist selection")

	capability.fail_apply = false
	files.write_error = ERR_CANT_CREATE
	var persistence_failure: ApplicationSettingsServiceResult = service.apply_and_persist(ApplicationWindowMode.Value.WINDOWED)
	_assert_eq(persistence_failure.outcome(), ApplicationSettingsServiceResult.Outcome.PERSISTENCE_FAILURE, "persistence failure is distinct")
	_assert_eq(capability.mode, ApplicationWindowMode.Value.WINDOWED, "write failure keeps runtime-applied value for this run")
	_assert_eq(service.committed_snapshot().window_mode(), ApplicationWindowMode.Value.WINDOWED, "runtime-applied value becomes committed for this run")

	var unsupported := FakeWindowCapability.new()
	unsupported.editable = false
	var unsupported_service := ApplicationSettingsService.new(
		ApplicationSettingsRepository.new(MemoryFiles.new()), unsupported
	)
	var unsupported_result: ApplicationSettingsServiceResult = unsupported_service.load_and_apply()
	_assert_eq(unsupported_result.outcome(), ApplicationSettingsServiceResult.Outcome.UNSUPPORTED_CAPABILITY, "platform-managed mode is typed")
	_assert_eq(unsupported.apply_calls.size(), 0, "unsupported platform attempts no DisplayServer mutation")


func _test_state_model() -> void:
	_assert_true(
		ApplicationShellState.settings(ApplicationShellState.SettingsOrigin.MAIN_MENU).is_valid(),
		"Settings accepts Main Menu origin",
	)
	_assert_true(
		ApplicationShellState.settings(ApplicationShellState.SettingsOrigin.PAUSED).is_valid(),
		"Settings accepts Paused origin",
	)
	_assert_false(ApplicationShellState.new(ApplicationShellState.Mode.SETTINGS).is_valid(), "Settings without origin rejects")
	_assert_false(
		ApplicationShellState.new(
			ApplicationShellState.Mode.SETTINGS,
			ApplicationShellState.Operation.SAVE,
			ApplicationShellState.ResultOrigin.NONE,
			ApplicationShellState.SettingsOrigin.PAUSED,
		).is_valid(),
		"Settings cannot carry gameplay operation",
	)
	_assert_false(
		ApplicationShellState.new(
			ApplicationShellState.Mode.PAUSED,
			ApplicationShellState.Operation.NONE,
			ApplicationShellState.ResultOrigin.NONE,
			ApplicationShellState.SettingsOrigin.PAUSED,
		).is_valid(),
		"non-Settings state cannot retain Settings origin",
	)


func _test_main_menu_settings_and_focus(tree: SceneTree) -> void:
	var game_files := MemoryFiles.new()
	var settings_files := MemoryFiles.new()
	var capability := FakeWindowCapability.new()
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	_assert_true(
		shell.configure_before_start(
			GameSaveStorageProfile.isolated_test("phase10c1c-menu"),
			game_files,
			null,
			settings_files,
			capability,
		),
		"Shell accepts separate settings dependencies",
	)
	tree.root.add_child(shell)
	await _wait_frames(tree, 3)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.MAIN_MENU, "cold settings bootstrap reaches menu")
	_assert_true(shell.runtime_host().current_session() == null, "settings bootstrap creates no Session")
	_assert_true(shell.get_viewport().gui_get_focus_owner() == shell.new_game_button, "menu first focus is deterministic")
	_assert_true(shell.request_settings_from_main_menu(), "Main Menu opens Settings")
	await tree.process_frame
	_assert_eq(shell.shell_state().settings_origin(), ApplicationShellState.SettingsOrigin.MAIN_MENU, "Settings records menu origin")
	_assert_true(shell.settings_visible(), "Settings panel is visible")
	_assert_true(shell.get_viewport().gui_get_focus_owner() == shell.window_mode_option, "editable setting receives focus")
	_assert_true(shell.runtime_host().current_session() == null, "opening Settings creates no Session")
	shell.window_mode_option.select(
		shell.window_mode_option.get_item_index(ApplicationWindowMode.Value.FULLSCREEN)
	)
	_assert_true(shell.apply_settings(), "successful Apply returns to typed origin")
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.MAIN_MENU, "Apply returns to Main Menu")
	_assert_eq(capability.mode, ApplicationWindowMode.Value.FULLSCREEN, "Apply changes runtime capability")
	_assert_true(settings_files.files.has(ApplicationSettingsRepository.SETTINGS_PATH), "Apply persists settings")
	_assert_true(shell.runtime_host().current_session() == null, "Apply creates no Session")
	_assert_true(shell.request_settings_from_main_menu(), "Settings reopens")
	shell.window_mode_option.select(
		shell.window_mode_option.get_item_index(ApplicationWindowMode.Value.WINDOWED)
	)
	_assert_true(shell.cancel_settings(), "Cancel returns to origin")
	_assert_eq(capability.mode, ApplicationWindowMode.Value.FULLSCREEN, "Cancel performs no runtime mutation")
	_free_node(shell)
	await tree.process_frame


func _test_paused_settings_freeze_and_cancel(tree: SceneTree) -> void:
	var capability := FakeWindowCapability.new()
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	_assert_true(
		shell.configure_before_start(
			GameSaveStorageProfile.isolated_test("phase10c1c-paused"),
			MemoryFiles.new(), null, MemoryFiles.new(), capability
		),
		"paused Settings fixture configures",
	)
	tree.root.add_child(shell)
	await _wait_frames(tree, 3)
	_assert_true(shell.request_new_game_from_menu(), "fixture starts New Game")
	await _wait_frames(tree, 3)
	_assert_true(shell.request_pause(), "fixture pauses gameplay")
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	var player: WorldCharacterBody2D = session.active_map().runtime_player_body()
	var before: Vector2 = player.position
	_assert_true(shell.request_settings_from_pause(), "Pause opens Settings")
	await _wait_frames(tree, 4)
	_assert_true(tree.paused, "paused-origin Settings keeps SceneTree paused")
	_assert_eq(player.position, before, "paused-origin Settings keeps gameplay frozen")
	_assert_eq(shell.shell_state().settings_origin(), ApplicationShellState.SettingsOrigin.PAUSED, "paused origin is typed")
	_assert_true(shell.cancel_settings(), "Settings Cancel returns to Pause")
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PAUSED, "Cancel returns to PAUSED")
	_assert_true(tree.paused, "Cancel does not resume gameplay")
	_assert_true(shell.request_settings_from_pause(), "paused Settings reopens for Apply")
	shell.window_mode_option.select(1)
	_assert_true(shell.apply_settings(), "paused Settings Apply succeeds")
	_assert_true(tree.paused, "Apply does not resume gameplay")
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PAUSED, "Apply returns to PAUSED")
	_assert_true(shell.runtime_host().current_session() == session, "Settings preserves exact Session")
	_assert_true(shell.request_resume(), "Resume still works after Settings")
	_assert_false(tree.paused, "Resume unpauses tree")
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PLAYING, "Resume returns to PLAYING")
	_free_node(shell)
	await tree.process_frame


func _test_unsupported_capability_ui(tree: SceneTree) -> void:
	var capability := FakeWindowCapability.new()
	capability.editable = false
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	shell.configure_before_start(
		GameSaveStorageProfile.isolated_test("phase10c1c-unsupported"),
		MemoryFiles.new(), null, MemoryFiles.new(), capability
	)
	tree.root.add_child(shell)
	await _wait_frames(tree, 3)
	_assert_true(shell.request_settings_from_main_menu(), "unsupported platform still opens Settings")
	await tree.process_frame
	_assert_false(shell.window_mode_row.visible, "unsupported platform exposes no fake editable control")
	_assert_false(shell.settings_apply_button.visible, "unsupported platform exposes no fake Apply")
	_assert_true(shell.get_viewport().gui_get_focus_owner() == shell.settings_cancel_button, "Back action owns focus")
	_assert_eq(capability.apply_calls.size(), 0, "unsupported UI attempts no mode mutation")
	_assert_true(shell.cancel_settings(), "unsupported Settings still navigates coherently")
	_free_node(shell)
	await tree.process_frame


func _test_input_focus_cancel_and_bleed(tree: SceneTree) -> void:
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	shell.configure_before_start(
		GameSaveStorageProfile.isolated_test("phase10c1c-input"),
		MemoryFiles.new(), null, MemoryFiles.new(), FakeWindowCapability.new()
	)
	tree.root.add_child(shell)
	await _wait_frames(tree, 3)
	_send_action(&"ui_down")
	await tree.process_frame
	_assert_true(
		shell.get_viewport().gui_get_focus_owner() == shell.menu_settings_button,
		"disabled Continue and Recovery are skipped by native focus navigation",
	)
	_send_action(&"ui_accept")
	await tree.process_frame
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.SETTINGS, "ui_accept activates only focused Settings")
	_assert_true(shell.runtime_host().current_session() == null, "Settings activation creates no hidden Session")
	_send_action(&"ui_cancel")
	await _wait_frames(tree, 2)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.MAIN_MENU, "Settings owns ui_cancel and returns to menu")
	_assert_true(shell.get_viewport().gui_get_focus_owner() == shell.new_game_button, "menu regains deterministic focus")
	_send_action(&"ui_accept")
	await _wait_frames(tree, 3)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PLAYING, "one ui_accept starts exactly one New Game")
	_assert_eq(shell.runtime_host().session_slot.get_child_count(), 1, "ui_accept creates exactly one Session")
	_send_action(&"pause_game")
	await tree.process_frame
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PAUSED, "pause action reaches Pause")
	_assert_true(tree.paused, "pause action freezes tree")
	_send_action(&"ui_down")
	_send_action(&"ui_down")
	await tree.process_frame
	_assert_true(
		shell.get_viewport().gui_get_focus_owner() == shell.pause_settings_button,
		"Pause focus reaches Settings through native navigation",
	)
	_send_action(&"ui_accept")
	await tree.process_frame
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.SETTINGS, "paused ui_accept opens Settings once")
	_assert_true(tree.paused, "opening paused Settings does not leak Resume")
	_send_action(&"ui_cancel")
	await tree.process_frame
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PAUSED, "Settings cancel precedence returns to Pause")
	_assert_true(tree.paused, "Settings dismissal input does not resume in same event")
	_assert_true(shell.request_return_to_main_menu(), "fixture opens highest result modal")
	_send_action(&"pause_game")
	await tree.process_frame
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.RESULT, "pause action cannot dismiss Result modal")
	_send_action(&"ui_cancel")
	await tree.process_frame
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PAUSED, "Result owns ui_cancel and returns to Pause")
	var player: WorldCharacterBody2D = shell.runtime_host().current_session().active_map().runtime_player_body()
	var before: Vector2 = player.position
	_send_action(&"move_right", true, false)
	await tree.process_frame
	_assert_true(Input.is_action_pressed(&"move_right"), "held movement is present before Resume")
	_send_action(&"ui_cancel")
	await _wait_frames(tree, 3)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PLAYING, "Pause ui_cancel resumes")
	_assert_false(Input.is_action_pressed(&"move_right"), "Resume releases held movement to prevent bleed")
	_assert_eq(player.position, before, "dismissal input does not move player in following frames")
	_send_action(&"move_right", false, true)
	_free_node(shell)
	await tree.process_frame


func _test_native_gamepad_navigation(tree: SceneTree) -> void:
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	shell.configure_before_start(
		GameSaveStorageProfile.isolated_test("phase10c1c-gamepad"),
		MemoryFiles.new(), null, MemoryFiles.new(), FakeWindowCapability.new()
	)
	tree.root.add_child(shell)
	await _wait_frames(tree, 3)
	await _send_joy(tree, JOY_BUTTON_DPAD_DOWN)
	_assert_true(tree.root.gui_get_focus_owner() == shell.menu_settings_button, "native D-pad skips disabled actions")
	await _send_joy(tree, JOY_BUTTON_A)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.SETTINGS, "native A activates Settings")
	await _send_joy(tree, JOY_BUTTON_B)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.MAIN_MENU, "native B cancels Settings")
	await _send_joy(tree, JOY_BUTTON_A)
	await _wait_frames(tree, 4)
	_assert_eq(shell.runtime_host().session_slot.get_child_count(), 1, "native A starts exactly one Session")
	await _send_joy(tree, JOY_BUTTON_B)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PLAYING, "B does not implicitly pause PLAYING")
	await _send_joy(tree, JOY_BUTTON_START)
	_assert_true(tree.paused, "native Start pauses")
	await _send_joy(tree, JOY_BUTTON_DPAD_DOWN)
	await _send_joy(tree, JOY_BUTTON_DPAD_DOWN)
	await _send_joy(tree, JOY_BUTTON_A)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.SETTINGS, "native controller opens paused Settings")
	await _send_joy(tree, JOY_BUTTON_B)
	_assert_true(tree.paused, "B from Settings cannot also Resume")
	await _send_joy(tree, JOY_BUTTON_B)
	_assert_false(tree.paused, "next B from Pause resumes")
	_free_node(shell)
	await tree.process_frame


func _send_joy(tree: SceneTree, button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await tree.process_frame
	await tree.process_frame


func _test_settings_and_game_save_separation(tree: SceneTree) -> void:
	var game_files := MemoryFiles.new()
	var settings_files := MemoryFiles.new()
	settings_files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "{".to_utf8_buffer()
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	shell.configure_before_start(
		GameSaveStorageProfile.isolated_test("phase10c1c-separate"),
		game_files, null, settings_files, FakeWindowCapability.new()
	)
	tree.root.add_child(shell)
	await _wait_frames(tree, 3)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.MAIN_MENU, "corrupt settings cannot block boot")
	_assert_false(shell.continue_enabled(), "game slot availability remains independently empty")
	_assert_true(shell.request_new_game_from_menu(), "corrupt settings cannot block New Game")
	await _wait_frames(tree, 3)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PLAYING, "gameplay starts after settings fallback")
	_assert_eq(settings_files.files.size(), 1, "gameplay start does not rewrite corrupt settings")
	_assert_eq(game_files.files.size(), 0, "settings fallback does not create gameplay save")
	_assert_true(
		ApplicationSettingsRepository.SETTINGS_PATH != GameSaveStorageProfile.release().canonical_path(),
		"settings and gameplay save use independent fixed paths",
	)
	_free_node(shell)
	await tree.process_frame


func _test_valid_save_independence_and_ui_failure(tree: SceneTree) -> void:
	var source: OldPineWorldSessionController = preload(
		"res://scenes/world/oldpine/oldpine_world_session.tscn"
	).instantiate()
	tree.root.add_child(source)
	var snapshot: GameSaveSnapshot = OldPineWorldSaveFixture.from_new_game(source)
	var bytes: PackedByteArray = GameSaveJsonCodec.encode(snapshot).text.to_utf8_buffer()
	_free_node(source)
	await tree.process_frame
	var profile := GameSaveStorageProfile.isolated_test("phase10c1c-valid-separate")
	var game_files := MemoryFiles.new()
	game_files.files[profile.canonical_path()] = bytes.duplicate()
	game_files.files[profile.backup_path()] = bytes.duplicate()
	var settings_files := MemoryFiles.new()
	settings_files.files[ApplicationSettingsRepository.SETTINGS_PATH] = _config_bytes(99, "fullscreen")
	var capability := FakeWindowCapability.new()
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	shell.configure_before_start(profile, game_files, null, settings_files, capability)
	tree.root.add_child(shell)
	await _wait_frames(tree, 3)
	_assert_true(shell.continue_enabled(), "unsupported settings schema cannot invalidate valid Continue")
	_assert_eq(shell.settings_bootstrap_result().repository_outcome(), ApplicationSettingsResult.Outcome.UNSUPPORTED_VERSION, "settings failure stays typed and separate")
	_assert_eq(game_files.files[profile.canonical_path()], bytes, "settings boot preserves gameplay bytes")
	shell.request_settings_from_main_menu()
	settings_files.write_error = ERR_CANT_CREATE
	shell.window_mode_option.select(1)
	_assert_false(shell.apply_settings(), "UI exposes persistence failure instead of false success")
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.SETTINGS, "write failure stays in Settings")
	_assert_true(shell.settings_status_label.text.contains("applied for this run"), "write failure explains effective unsaved value")
	_assert_true(shell.runtime_host().current_session() == null, "settings write failure creates no Session")
	shell.cancel_settings()
	_assert_true(shell.continue_enabled(), "settings write failure cannot disable Continue")
	shell.request_continue_from_menu()
	await _wait_frames(tree, 5)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PLAYING, "valid Continue restores despite corrupt settings")
	_assert_eq(game_files.files[profile.backup_path()], bytes, "settings/Continue never promote or destroy backup")
	_free_node(shell)
	await tree.process_frame
	game_files.files[profile.canonical_path()] = "{".to_utf8_buffer()
	settings_files.files[ApplicationSettingsRepository.SETTINGS_PATH] = _config_bytes(1, "fullscreen")
	shell = SHELL_SCENE.instantiate()
	shell.configure_before_start(profile, game_files, null, settings_files, capability)
	tree.root.add_child(shell)
	await _wait_frames(tree, 3)
	_assert_eq(shell.committed_window_mode(), ApplicationWindowMode.Value.FULLSCREEN, "corrupt gameplay save cannot reset valid settings")
	_assert_false(shell.continue_enabled(), "invalid canonical independently disables Continue")
	_assert_true(shell.recovery_enabled(), "settings cannot alter available backup Recovery")
	_assert_true(shell.runtime_host().current_session() == null, "recovery remains explicit with no automatic Session")
	shell.request_settings_from_main_menu()
	capability.fail_apply = true
	shell.window_mode_option.select(0)
	_assert_false(shell.apply_settings(), "UI reports runtime apply failure")
	_assert_eq(shell.window_mode_option.get_selected_id(), ApplicationWindowMode.Value.FULLSCREEN, "failed apply restores effective selection")
	_assert_true(shell.settings_status_label.text.contains("could not be applied"), "runtime failure has distinct product message")
	_free_node(shell)
	await tree.process_frame


func _config_bytes(version: int, mode: String) -> PackedByteArray:
	return (
		"[application]\nschema_version=%d\nwindow_mode=\"%s\"\n" % [version, mode]
	).to_utf8_buffer()


func _send_action(action: StringName, press: bool = true, release: bool = true) -> void:
	if press:
		var pressed := InputEventAction.new()
		pressed.action = action
		pressed.pressed = true
		Input.parse_input_event(pressed)
	if release:
		var released := InputEventAction.new()
		released.action = action
		released.pressed = false
		Input.parse_input_event(released)


func _wait_frames(tree: SceneTree, count: int) -> void:
	for _index: int in range(count):
		await tree.process_frame


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _assert_true(value: bool, message: String) -> void:
	_assertions += 1
	if not value:
		_failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
