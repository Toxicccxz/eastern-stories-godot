extends RefCounted

## 界面重做 package 1 (DECISIONS「界面样式」): the interface's block theme, its two faces, and
## the shell's surfaces wearing it — 设置's pairs in columns, a chosen 性别 that shows, the
## safe answer and the losing choice told apart, the focus arrow beside the focused button.
const ShellTests = preload("res://tests/application/application_shell_test.gd")
const SHELL_SCENE: PackedScene = preload("res://scenes/application/application_shell.tscn")

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	_test_theme()
	_test_faces()
	_test_prompt()
	await _test_shell(tree)
	return {"assertions": assertions, "failures": failures}


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


## Roles are type variations of one theme, built once.
func _test_theme() -> void:
	var theme: GameTheme = GameTheme.shared()
	_check(theme == GameTheme.shared(), "one theme for every user")
	for variation: StringName in [&"TitleLabel", &"HeadingLabel", &"MutedLabel", &"SmallLabel", &"WarningLabel", &"KeyCap", &"WellPanel", &"PlatePanel", &"ToastPanel", &"PrimaryButton", &"DangerButton", &"ChipButton", &"ToggleButton", &"RowButton", &"SlotButton", &"MenuWindow", &"TabButton"]:
		_check(theme.is_type_variation(variation, theme.get_type_variation_base(variation)), "%s is a variation" % variation)
	var normal: StyleBoxTexture = theme.get_stylebox("normal", &"Button") as StyleBoxTexture
	var pressed: StyleBoxTexture = theme.get_stylebox("pressed", &"Button") as StyleBoxTexture
	_check(normal != null and pressed != null and normal.texture.get_height() > pressed.texture.get_height(), "a pressed block has less front face: it sinks")
	_check(theme.get_stylebox("focus", &"Button") is StyleBoxTexture and theme.get_stylebox("focus", &"LineEdit") is StyleBoxTexture, "focus is the lantern rim")
	var primary: StyleBoxTexture = theme.get_stylebox("normal", &"PrimaryButton") as StyleBoxTexture
	var danger: StyleBoxTexture = theme.get_stylebox("normal", &"DangerButton") as StyleBoxTexture
	var top: Color = primary.texture.get_image().get_pixel(primary.texture.get_width() / 2, UiBlocks.PX * 4)
	var dark: Color = danger.texture.get_image().get_pixel(danger.texture.get_width() / 2, UiBlocks.PX * 4)
	_check(top.is_equal_approx(UiPalette.LACQUER) and dark.is_equal_approx(UiPalette.DANGER), "the main choice is vermilion lacquer, a losing one dark lacquer")
	var chosen: StyleBoxTexture = theme.get_stylebox("pressed", &"ToggleButton") as StyleBoxTexture
	_check(chosen.texture.get_image().get_pixel(chosen.texture.get_width() / 2, UiBlocks.PX * 4).is_equal_approx(UiPalette.LACQUER), "a chosen toggle is lacquer")


## 霞鹜文楷 for text (the language's system fonts under it), 方舟像素 16 px for titles, drawn
## aliased at a whole multiple of its grid.
func _test_faces() -> void:
	var project: Theme = ThemeDB.get_project_theme()
	var body: FontFile = project.default_font as FontFile
	_check(body != null and body.resource_path == GameTheme.BODY_FONT_PATH, "the text face is the bundled 霞鹜文楷")
	_check(body.allow_system_fallback, "the system fills in glyphs it lacks")
	var pixel: FontFile = GameTheme.pixel_font()
	_check(pixel != null and pixel.antialiasing == TextServer.FONT_ANTIALIASING_NONE and pixel.hinting == TextServer.HINTING_NONE, "the pixel face is aliased and unhinted")
	_check(pixel.fallbacks.size() == 1 and pixel.fallbacks[0] == body, "a glyph the pixel face lacks comes from 霞鹜文楷")
	var theme: GameTheme = GameTheme.shared()
	_check(theme.get_font("font", &"TitleLabel") == pixel, "titles are in the pixel face")
	_check(GameTheme.PIXEL_SIZE % 16 == 0 and GameTheme.PIXEL_STEP * 16 == GameTheme.PIXEL_SIZE, "at a whole multiple of its 16 px grid")
	_check(theme.get_constant("shadow_offset_y", &"TitleLabel") == GameTheme.PIXEL_STEP, "one grid pixel of side under the face")


func _test_prompt() -> void:
	var prompt := ConfirmPrompt.new()
	prompt.ask("覆盖这一位的存档？", "覆盖", "取消", "", true)
	_check(prompt.confirm_button.theme_type_variation == &"DangerButton", "a choice that loses something is dark lacquer")
	prompt.ask("读取这一份存档？", "读取")
	_check(prompt.confirm_button.theme_type_variation == &"PrimaryButton", "any other choice is vermilion")
	prompt.tell("已存档。")
	_check(prompt.confirm_button.theme_type_variation == &"PrimaryButton", "a notice's one button too")
	prompt.free()


func _test_shell(tree: SceneTree) -> void:
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	shell.configure_before_start(GameSaveStorageProfile.isolated_test("game-theme"), ShellTests.MemoryFiles.new(), null, ShellTests.MemoryFiles.new())
	tree.root.add_child(shell)
	for i: int in 6:
		await tree.process_frame
	var canvas: CanvasLayer = shell.shell_canvas
	var dressed: bool = true
	for child: Node in canvas.get_children():
		if child is Control and (child as Control).theme != GameTheme.shared():
			dressed = false
	_check(dressed and shell.slot_panel.theme == GameTheme.shared(), "every shell surface wears the theme, the slot list too")
	var cursor: FocusCursor = canvas.get_node_or_null("FocusCursor") as FocusCursor
	_check(cursor != null, "the focus arrow is on the shell")
	shell.new_game_button.grab_focus()
	await tree.process_frame
	await tree.process_frame
	_check(cursor.focused_button() == shell.new_game_button and cursor.visible, "it points at the focused button")
	_check(cursor.global_position.x < shell.new_game_button.global_position.x, "from its left")
	# 设置: each label and its control a pair of one width, so the pairs stand in two columns.
	_check(shell.request_settings_from_main_menu(), "设置 opens")
	for i: int in 4:
		await tree.process_frame
	var firsts: Array[float] = []
	var seconds: Array[float] = []
	for row: Control in [shell.ui_scale_row, shell.language_row, shell.battle_speed_row, (shell.get_node("%KnockoutRow") as Control), (shell.get_node("%DayNightRow") as Control)]:
		var items: Array[Control] = []
		for child: Node in row.get_children():
			if child is Control and (child as Control).visible:
				items.append(child as Control)
		firsts.append(items[0].global_position.x)
		var label: Label = items[0].get_child(0) as Label
		_check(label != null and label.autowrap_mode == TextServer.AUTOWRAP_OFF and label.get_line_count() == 1, "%s: its name on one line" % row.name)
		if items.size() > 1:
			seconds.append(items[1].global_position.x)
	_check(firsts.all(func(x: float) -> bool: return is_equal_approx(x, firsts[0])), "the first column lines up: %s" % [firsts])
	_check(seconds.size() == 3 and seconds.all(func(x: float) -> bool: return is_equal_approx(x, seconds[0]) and x > firsts[0]), "the second column lines up beside it: %s" % [seconds])
	_check(shell.cancel_settings(), "设置 closes")
	await tree.process_frame
	# 性别: the choice shows as it is made.
	_check(shell.request_new_game_from_menu(), "新游戏 opens its setup")
	await tree.process_frame
	shell.select_new_game_gender(CharacterState.GENDER_FEMALE)
	_check(shell.female_button.theme_type_variation == &"ToggleButton" and shell.female_button.button_pressed and not shell.male_button.button_pressed, "the chosen 性别 stays down, in lacquer")
	_check(shell.journey_start_button.theme_type_variation == &"PrimaryButton", "开始旅程 is the main choice")
	shell.cancel_new_game_setup()
	await tree.process_frame
	shell.queue_free()
	await tree.process_frame
