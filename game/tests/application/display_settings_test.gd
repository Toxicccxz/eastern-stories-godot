extends RefCounted

## 分辨率 and the window mode on 设置 (DECISIONS「显示设置」): what fits the monitor the game is
## on, shown the moment it is picked, kept by 应用, undone by 取消.

const SHELL_SCENE: PackedScene = preload("res://scenes/application/application_shell.tscn")
const HD: Vector2i = Vector2i(1280, 720)
const HD_PLUS: Vector2i = Vector2i(1600, 900)
const FULL_HD: Vector2i = Vector2i(1920, 1080)
const QHD: Vector2i = Vector2i(2560, 1440)
const UHD: Vector2i = Vector2i(3840, 2160)


class MemoryFiles extends SaveFileOperations:
	var files: Dictionary[String, PackedByteArray] = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func make_directory_recursive(_path: String) -> int:
		return OK

	func read_bytes(path: String, _maximum_bytes: int) -> SaveFileReadResult:
		return SaveFileReadResult.new(OK, files[path]) if files.has(path) else SaveFileReadResult.new(ERR_FILE_NOT_FOUND)

	func write_bytes(path: String, bytes: PackedByteArray) -> int:
		files[path] = bytes
		return OK


## A 2560×1440 monitor whose window frame leaves 1392 of height; `calls` keeps the order.
class FakeDisplay extends ApplicationWindowModeCapability:
	var mode: int = ApplicationWindowMode.Value.WINDOWED
	var resolution: Vector2i = ApplicationWindowSize.AUTO
	var screen: int = 0
	var window_room: Vector2i = Vector2i(2544, 1353)
	var covered_room: Vector2i = QHD
	var fail_mode: int = -1
	var editable: bool = true
	var calls: Array[String] = []

	func can_edit_window_mode() -> bool:
		return editable

	func current_window_mode() -> int:
		return mode

	func apply_window_mode(requested: int) -> bool:
		calls.append("mode %d" % requested)
		if requested == fail_mode:
			return false
		mode = requested
		return true

	func apply_resolution(requested: Vector2i) -> void:
		calls.append("resolution %s" % requested)
		resolution = requested

	func resolution_room(of_mode: int) -> Vector2i:
		return window_room if of_mode == ApplicationWindowMode.Value.WINDOWED else covered_room

	func current_screen() -> int:
		return screen

	func show_on_screen(requested: int) -> void:
		calls.append("screen %d" % requested)
		screen = requested


var _assertions: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_sizes()
	_test_storage()
	_test_service()
	await _test_settings_page(tree)
	await _test_size_for_a_bigger_monitor(tree)
	await _test_keys_and_pad(tree)
	await _test_platform_managed(tree)
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_sizes() -> void:
	_check(ApplicationWindowSize.choices(Vector2i(2544, 1353)) == [HD, HD_PLUS, FULL_HD], "a QHD monitor's window: its own size does not fit with the frame")
	_check(ApplicationWindowSize.choices(QHD) == [HD, HD_PLUS, FULL_HD, QHD], "covering it: the monitor's own size does")
	_check(ApplicationWindowSize.choices(UHD).size() == 5, "a 4K monitor takes them all")
	_check(ApplicationWindowSize.choices(Vector2i(1366, 689)).is_empty(), "a small laptop's window takes none, 自动 is left")
	_check(ApplicationWindowSize.choices(Vector2i(1920, 800)) == [HD], "both sides have to fit: an ultrawide of 800 is not 900 high")
	_check(ApplicationWindowSize.fitted(UHD, FULL_HD) == FULL_HD, "a size for a bigger monitor falls to the largest that fits")
	_check(ApplicationWindowSize.fitted(HD_PLUS, UHD) == HD_PLUS, "one that fits stays")
	_check(ApplicationWindowSize.fitted(HD, Vector2i(1024, 768)) == ApplicationWindowSize.AUTO, "none fits: 自动")
	_check(ApplicationWindowSize.fitted(ApplicationWindowSize.AUTO, UHD) == ApplicationWindowSize.AUTO, "自动 stays 自动")
	_check(is_equal_approx(ApplicationWindowSize.picture_scale(FULL_HD, UHD), 0.5), "1080p on a 4K monitor draws the map at half")
	_check(ApplicationWindowSize.picture_scale(UHD, FULL_HD) == 1.0, "never above the monitor")
	_check(ApplicationWindowSize.picture_scale(ApplicationWindowSize.AUTO, UHD) == 1.0, "自动 draws at the monitor's")
	_check(is_equal_approx(ApplicationWindowSize.picture_scale(QHD, Vector2i(2560, 1600)), 0.9), "a 16:10 monitor keeps the picture's shape: the height decides")
	_check(ApplicationWindowSize.from_storage("") == ApplicationWindowSize.AUTO, "an empty value is 自动")
	_check(ApplicationWindowSize.from_storage(ApplicationWindowSize.storage_value(QHD)) == QHD, "a size round-trips")
	_check(not ApplicationWindowSize.is_valid(ApplicationWindowSize.from_storage("1234x567")), "a size off the list rejects")


func _test_storage() -> void:
	var files := MemoryFiles.new()
	var repository := ApplicationSettingsRepository.new(files)
	var defaults: ApplicationSettingsSnapshot = ApplicationSettingsSnapshot.defaults()
	_check(defaults.resolution() == ApplicationWindowSize.AUTO and defaults.screen() == ApplicationSettingsSnapshot.NO_SCREEN, "the default is 自动, wherever the system opens the window")
	_check(not defaults.with_display(0, Vector2i(1234, 567), 0).is_valid(), "a snapshot with a size off the list rejects")
	var chosen: ApplicationSettingsSnapshot = defaults.with_display(ApplicationWindowMode.Value.BORDERLESS, HD_PLUS, 1).with_ui_scale(125)
	_check(repository.write(chosen).succeeded(), "the display settings write")
	var back: ApplicationSettingsResult = repository.load()
	_check(back.succeeded() and back.snapshot().resolution() == HD_PLUS and back.snapshot().screen() == 1 and back.snapshot().window_mode() == ApplicationWindowMode.Value.BORDERLESS, "and read back")
	_check(back.snapshot().ui_scale() == 125, "the other settings beside them stay")
	var path: String = ApplicationSettingsRepository.SETTINGS_PATH
	var previous: String = "[application]\nschema_version=8\nwindow_mode=\"fullscreen\"\nlanguage=\"\"\nbattle_speed=\"fast\"\nhit_flash=false\nui_scale=125\nafter_knockout=\"finish\"\nobjective_hints=false\nday_night=\"day\"\nautosave_notice=false\n"
	files.files[path] = previous.to_utf8_buffer()
	var old: ApplicationSettingsResult = repository.load()
	_check(old.succeeded() and old.snapshot().resolution() == ApplicationWindowSize.AUTO and old.snapshot().screen() == ApplicationSettingsSnapshot.NO_SCREEN, "a version 8 file reads as 自动")
	_check(old.snapshot().window_mode() == ApplicationWindowMode.Value.FULLSCREEN and old.snapshot().ui_scale() == 125 and not old.snapshot().autosave_notice(), "and keeps the rest")
	var current: String = previous.replace("schema_version=8", "schema_version=9")
	files.files[path] = current.to_utf8_buffer()
	_check(not repository.load().succeeded(), "a version 9 file without them rejects")
	for tail: String in ["resolution=\"1234x567\"\nscreen=0\n", "resolution=1920\nscreen=0\n", "resolution=\"\"\nscreen=-2\n", "resolution=\"\"\nscreen=\"0\"\n"]:
		files.files[path] = (current + tail).to_utf8_buffer()
		_check(not repository.load().succeeded(), "rejects: %s" % tail.strip_edges())
	files.files[path] = (current + "resolution=\"\"\nscreen=-1\n").to_utf8_buffer()
	_check(repository.load().succeeded(), "自动, no monitor known reads")


func _test_service() -> void:
	var files := MemoryFiles.new()
	var repository := ApplicationSettingsRepository.new(files)
	repository.write(ApplicationSettingsSnapshot.defaults().with_display(ApplicationWindowMode.Value.FULLSCREEN, HD_PLUS, 1))
	var display := FakeDisplay.new()
	var service := ApplicationSettingsService.new(repository, display)
	_check(service.load_and_apply().succeeded(), "the kept settings load")
	_check(display.calls == ["screen 1", "mode %d" % ApplicationWindowMode.Value.FULLSCREEN, "resolution %s" % HD_PLUS], "on its monitor first, full screen there, then the 分辨率: %s" % [display.calls])

	var written: PackedByteArray = files.files[ApplicationSettingsRepository.SETTINGS_PATH].duplicate()
	_check(service.preview_display(ApplicationWindowMode.Value.WINDOWED, HD), "a pick shows")
	_check(display.mode == ApplicationWindowMode.Value.WINDOWED and display.resolution == HD, "at once")
	_check(service.committed_snapshot().resolution() == HD_PLUS and files.files[ApplicationSettingsRepository.SETTINGS_PATH] == written, "nothing kept yet")
	service.restore_display()
	_check(display.mode == ApplicationWindowMode.Value.FULLSCREEN and display.resolution == HD_PLUS, "取消 goes back")
	display.calls.clear()
	service.restore_display()
	_check(display.calls.is_empty(), "with nothing on show, nothing is touched (a window the player resized stays)")

	display.screen = 2
	service.preview_display(ApplicationWindowMode.Value.BORDERLESS, FULL_HD)
	_check(service.apply_and_persist_display(ApplicationWindowMode.Value.BORDERLESS, FULL_HD).succeeded(), "应用 keeps it")
	var kept: ApplicationSettingsSnapshot = repository.load().snapshot()
	_check(kept.resolution() == FULL_HD and kept.window_mode() == ApplicationWindowMode.Value.BORDERLESS and kept.screen() == 2, "mode, 分辨率 and the monitor the game is on")
	display.calls.clear()
	service.restore_display()
	_check(display.calls.is_empty(), "what is kept is not restored over")
	_check(service.apply_and_persist(ApplicationWindowMode.Value.WINDOWED).succeeded() and repository.load().snapshot().resolution() == FULL_HD, "a mode alone keeps the 分辨率")

	display.fail_mode = ApplicationWindowMode.Value.FULLSCREEN
	var before: PackedByteArray = files.files[ApplicationSettingsRepository.SETTINGS_PATH].duplicate()
	_check(not service.preview_display(ApplicationWindowMode.Value.FULLSCREEN, HD), "a mode the display refuses is told")
	service.restore_display()
	_check(display.mode == ApplicationWindowMode.Value.WINDOWED and display.resolution == FULL_HD, "and the display goes back")
	_check(not service.apply_and_persist_display(ApplicationWindowMode.Value.FULLSCREEN, HD).succeeded() and files.files[ApplicationSettingsRepository.SETTINGS_PATH] == before, "refused, it is not kept")
	display.fail_mode = -1
	_check(not service.preview_display(ApplicationWindowMode.Value.WINDOWED, Vector2i(1234, 567)), "a size off the list is refused")
	service.restore_display()
	_check(service.resolution_choices(ApplicationWindowMode.Value.WINDOWED) == [HD, HD_PLUS, FULL_HD] and service.resolution_choices(ApplicationWindowMode.Value.BORDERLESS).back() == QHD, "the choices follow the mode")

	var unplugged := FakeDisplay.new()
	var old_files := MemoryFiles.new()
	var old_repository := ApplicationSettingsRepository.new(old_files)
	old_repository.write(ApplicationSettingsSnapshot.defaults().with_display(ApplicationWindowMode.Value.WINDOWED, UHD, 0))
	var moved := ApplicationSettingsService.new(old_repository, unplugged)
	moved.load_and_apply()
	_check(moved.committed_snapshot().resolution() == UHD and old_repository.load().snapshot().resolution() == UHD, "a smaller monitor does not rewrite the choice: the big one may come back")


func _test_settings_page(tree: SceneTree) -> void:
	var files := MemoryFiles.new()
	var display := FakeDisplay.new()
	var shell: ApplicationShellController = await _shell(tree, "display-page", files, display)
	_check(shell.request_settings_from_main_menu(), "设置 opens")
	await tree.process_frame
	_check(shell.resolution_option.is_visible_in_tree() and not shell.resolution_option.disabled, "the 分辨率 row is there")
	_check(_items(shell.resolution_option) == ["自动", "1280×720", "1600×900", "1920×1080"], "自动, then what fits a window: %s" % [_items(shell.resolution_option)])
	_check(shell.resolution_option.selected == 0, "自动 chosen by default")
	_check(shell.window_mode_option.get_item_text(shell.window_mode_option.get_item_index(ApplicationWindowMode.Value.BORDERLESS)) == "无边框窗口", "the mode is called 无边框窗口")

	_pick(shell.resolution_option, 2)
	_check(display.resolution == HD_PLUS, "a 分辨率 shows the moment it is picked")
	_check(not files.files.has(ApplicationSettingsRepository.SETTINGS_PATH), "nothing kept before 应用")
	_pick(shell.window_mode_option, shell.window_mode_option.get_item_index(ApplicationWindowMode.Value.FULLSCREEN))
	_check(display.mode == ApplicationWindowMode.Value.FULLSCREEN and display.resolution == HD_PLUS, "so does a mode, the 分辨率 staying")
	_check(_items(shell.resolution_option).back() == "2560×1440", "covering the monitor, its own size joins the list")
	_check(shell.cancel_settings(), "取消")
	_check(display.mode == ApplicationWindowMode.Value.WINDOWED and display.resolution == ApplicationWindowSize.AUTO, "puts the window back as it was")
	_check(not files.files.has(ApplicationSettingsRepository.SETTINGS_PATH), "and writes nothing")

	_check(shell.request_settings_from_main_menu(), "设置 again")
	await tree.process_frame
	_check(shell.resolution_option.selected == 0 and shell.window_mode_option.get_selected_id() == ApplicationWindowMode.Value.WINDOWED, "it shows what is kept")
	_pick(shell.window_mode_option, shell.window_mode_option.get_item_index(ApplicationWindowMode.Value.BORDERLESS))
	_pick(shell.resolution_option, shell.resolution_option.item_count - 1)
	_check(display.resolution == QHD, "the monitor's own size, covering it")
	_pick(shell.window_mode_option, shell.window_mode_option.get_item_index(ApplicationWindowMode.Value.WINDOWED))
	_check(shell.resolution_option.get_item_text(shell.resolution_option.selected) == "1920×1080" and display.resolution == FULL_HD, "back in a window it falls to the largest that fits: %s" % display.resolution)
	_pick(shell.window_mode_option, shell.window_mode_option.get_item_index(ApplicationWindowMode.Value.BORDERLESS))
	display.screen = 1
	display.covered_room = FULL_HD
	await _wait_frames(tree, 2)
	_check(_items(shell.resolution_option).back() == "1920×1080", "the list follows the game to another monitor: %s" % [_items(shell.resolution_option)])
	_check(shell.apply_settings(), "应用")
	var kept: ApplicationSettingsSnapshot = ApplicationSettingsRepository.new(files).load().snapshot()
	_check(kept.resolution() == FULL_HD and kept.window_mode() == ApplicationWindowMode.Value.BORDERLESS and kept.screen() == 1, "keeps all three")
	_free(shell)
	await tree.process_frame

	# The next run: the same file comes back.
	var again := FakeDisplay.new()
	var next: ApplicationShellController = await _shell(tree, "display-page-next", files, again)
	_check(again.mode == ApplicationWindowMode.Value.BORDERLESS and again.resolution == FULL_HD and again.screen == 1, "a restart comes back to them")
	_check(next.request_settings_from_main_menu(), "设置 opens there")
	await tree.process_frame
	_check(next.resolution_option.get_item_text(next.resolution_option.selected) == "1920×1080", "and shows the kept 分辨率")
	next.window_mode_option.select(next.window_mode_option.get_item_index(ApplicationWindowMode.Value.WINDOWED))
	again.fail_mode = ApplicationWindowMode.Value.WINDOWED
	_pick(next.window_mode_option, next.window_mode_option.selected)
	_check(next.settings_status_label.text == "无法切换窗口模式。", "a mode that fails says so")
	_check(next.window_mode_option.get_selected_id() == ApplicationWindowMode.Value.BORDERLESS and again.mode == ApplicationWindowMode.Value.BORDERLESS, "and the page shows what is really on")
	_free(next)
	await tree.process_frame


## 4K kept, playing on the QHD monitor: the page shows what fits, and only a real choice
## replaces the kept size.
func _test_size_for_a_bigger_monitor(tree: SceneTree) -> void:
	var files := MemoryFiles.new()
	ApplicationSettingsRepository.new(files).write(ApplicationSettingsSnapshot.defaults().with_display(ApplicationWindowMode.Value.WINDOWED, UHD, 0))
	var shell: ApplicationShellController = await _shell(tree, "display-bigger", files, FakeDisplay.new())
	_check(shell.request_settings_from_main_menu(), "设置 opens")
	await tree.process_frame
	_check(shell.resolution_option.get_item_text(shell.resolution_option.selected) == "1920×1080", "the page shows the largest that fits")
	_check(shell.apply_settings(), "应用 with another setting's change")
	_check(ApplicationSettingsRepository.new(files).load().snapshot().resolution() == UHD, "the kept 4K stays")
	_check(shell.request_settings_from_main_menu(), "设置 again")
	await tree.process_frame
	_pick(shell.resolution_option, 1)
	_check(shell.apply_settings(), "应用 a smaller size")
	_check(ApplicationSettingsRepository.new(files).load().snapshot().resolution() == HD, "a real choice replaces it")
	_free(shell)
	await tree.process_frame


## The cycle runs through the row, an open list takes the arrows, and the pick shows.
func _test_keys_and_pad(tree: SceneTree) -> void:
	for pad: bool in [false, true]:
		var display := FakeDisplay.new()
		var shell: ApplicationShellController = await _shell(tree, "display-input-%s" % pad, MemoryFiles.new(), display)
		_check(shell.request_settings_from_main_menu(), "设置 opens")
		await _wait_frames(tree, 2)
		var name: String = "pad" if pad else "keys"
		_check(tree.root.gui_get_focus_owner() == shell.window_mode_option, "%s: the mode has the focus" % name)
		await _send(tree, pad, &"ui_down")
		_check(tree.root.gui_get_focus_owner() == shell.resolution_option, "%s: down reaches 分辨率" % name)
		await _send(tree, pad, &"ui_accept")
		_check(shell.resolution_option.get_popup().visible, "%s: confirm opens the list" % name)
		await _send(tree, pad, &"ui_cancel")
		_check(not shell.resolution_option.get_popup().visible and shell.shell_state().mode() == ApplicationShellState.Mode.SETTINGS, "%s: back closes the list, not the page" % name)
		_check(display.calls.filter(func(call: String) -> bool: return call.begins_with("resolution")).size() == 1, "%s: and picks nothing" % name)
		await _send(tree, pad, &"ui_accept")
		await _send(tree, pad, &"ui_down")
		await _send(tree, pad, &"ui_accept")
		await _wait_frames(tree, 2)
		_check(display.resolution == HD, "%s: down and confirm picks the next size, shown at once: %s" % [name, display.resolution])
		await _send(tree, pad, &"ui_down")
		_check(tree.root.gui_get_focus_owner() == shell.ui_scale_option, "%s: on to 界面缩放" % name)
		await _send(tree, pad, &"ui_up")
		await _send(tree, pad, &"ui_up")
		_check(tree.root.gui_get_focus_owner() == shell.window_mode_option, "%s: and back up to the mode" % name)
		_free(shell)
		await tree.process_frame


func _test_platform_managed(tree: SceneTree) -> void:
	var display := FakeDisplay.new()
	display.editable = false
	var shell: ApplicationShellController = await _shell(tree, "display-managed", MemoryFiles.new(), display)
	_check(shell.request_settings_from_main_menu(), "设置 opens where the platform keeps the window")
	await tree.process_frame
	_check(not shell.resolution_option.is_visible_in_tree() and shell.resolution_option.focus_mode == Control.FOCUS_NONE, "no 分辨率 row there")
	_check(shell.cancel_settings() and display.calls.is_empty(), "and nothing touches the window")
	_free(shell)
	await tree.process_frame
	var real := GodotWindowModeCapability.new()
	if not real.can_edit_window_mode():
		_check(real.resolution_room(ApplicationWindowMode.Value.WINDOWED) == Vector2i.ZERO, "headless: no room, no list")
		real.apply_resolution(HD)
		real.show_on_screen(0)


func _shell(tree: SceneTree, profile: String, files: MemoryFiles, display: FakeDisplay) -> ApplicationShellController:
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	shell.configure_before_start(GameSaveStorageProfile.isolated_test(profile), MemoryFiles.new(), null, files, display)
	tree.root.add_child(shell)
	await _wait_frames(tree, 3)
	return shell


## What the list does when the player picks a row.
func _pick(option: OptionButton, index: int) -> void:
	option.select(index)
	option.item_selected.emit(index)


func _items(option: OptionButton) -> Array[String]:
	var items: Array[String] = []
	for index: int in option.item_count:
		items.append(option.get_item_text(index))
	return items


func _send(tree: SceneTree, pad: bool, action: StringName) -> void:
	if pad:
		var button: JoyButton = {&"ui_down": JOY_BUTTON_DPAD_DOWN, &"ui_up": JOY_BUTTON_DPAD_UP, &"ui_accept": JOY_BUTTON_A, &"ui_cancel": JOY_BUTTON_B}[action]
		for pressed: bool in [true, false]:
			var event := InputEventJoypadButton.new()
			event.button_index = button
			event.pressed = pressed
			Input.parse_input_event(event)
			await tree.process_frame
	else:
		var key: Key = {&"ui_down": KEY_DOWN, &"ui_up": KEY_UP, &"ui_accept": KEY_ENTER, &"ui_cancel": KEY_ESCAPE}[action]
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = key
			event.physical_keycode = key
			event.pressed = pressed
			Input.parse_input_event(event)
			await tree.process_frame
	await tree.process_frame


func _wait_frames(tree: SceneTree, count: int) -> void:
	for _index: int in range(count):
		await tree.process_frame


func _free(node: Node) -> void:
	node.get_parent().remove_child(node)
	node.free()


func _check(value: bool, message: String) -> void:
	_assertions += 1
	if not value:
		_failures.append(message)
