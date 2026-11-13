extends RefCounted

## 界面重做 package 1 (DECISIONS「界面样式」「像素界面」): the interface's worn materials, its pixel face, and
## the shell's surfaces wearing it — 设置's pairs in columns, a chosen 性别 that shows, the
## safe answer and the losing choice told apart, the focus arrow beside the focused button.
const ShellTests = preload("res://tests/application/application_shell_test.gd")
const SHELL_SCENE: PackedScene = preload("res://scenes/application/application_shell.tscn")

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	_test_theme()
	_test_materials()
	_test_pixel_scale()
	_test_scene_sizes()
	_test_faces()
	_test_prompt()
	await _test_shell(tree)
	return {"assertions": assertions, "failures": failures}


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


## Roles are type variations of one theme, built once; every surface an old material on the
## pixel grid (DECISIONS「像素界面」).
func _test_theme() -> void:
	var theme: GameTheme = GameTheme.shared()
	_check(theme == GameTheme.shared(), "one theme for every user")
	for variation: StringName in [&"TitleLabel", &"HeadingLabel", &"MutedLabel", &"SmallLabel", &"WarningLabel", &"KeyCap", &"WellPanel", &"PlatePanel", &"ToastPanel", &"PrimaryButton", &"DangerButton", &"ChipButton", &"ToggleButton", &"RowButton", &"SlotButton", &"MenuWindow", &"TabButton", &"TitleMenuItem", &"TitleMenuLetters", &"TitleCaption", &"BarePanel"]:
		_check(theme.is_type_variation(variation, theme.get_type_variation_base(variation)), "%s is a variation" % variation)
	var normal: PixelBox = theme.get_stylebox("normal", &"Button") as PixelBox
	var pressed: PixelBox = theme.get_stylebox("pressed", &"Button") as PixelBox
	_check(normal != null and pressed != null and is_equal_approx(normal.scale, GameTheme.GRID), "a button is a box drawn on the pixel grid")
	_check(normal.variants.size() == 3 and pressed.variants.size() == 3, "three versions of each material, one a control")
	_check(normal.margins.y < pressed.margins.y and normal.margins.w > pressed.margins.w, "a pressed plate sinks: air above its face, less edge under it")
	_check(normal.mark_seed == pressed.mark_seed and normal.mark_rects.size() > 0, "a button's marks are the same pressed or not")
	_check(theme.get_stylebox("focus", &"Button") is PixelBox and theme.get_stylebox("focus", &"LineEdit") is PixelBox, "focus is the lantern rim")
	_check(_face_near(normal, UiPalette.IRON), "an ordinary button is iron")
	_check(_face_near(theme.get_stylebox("normal", &"PrimaryButton") as PixelBox, UiPalette.LACQUER), "the main choice is vermilion lacquer")
	_check(_face_near(theme.get_stylebox("normal", &"DangerButton") as PixelBox, UiPalette.DANGER), "a losing one dark lacquer")
	_check(_face_near(theme.get_stylebox("normal", &"ChipButton") as PixelBox, UiPalette.BRONZE), "a small one bronze")
	_check(_face_near(theme.get_stylebox("pressed", &"ToggleButton") as PixelBox, UiPalette.LACQUER), "a chosen toggle is lacquer")
	var window: PixelBox = theme.get_stylebox("panel", &"MenuWindow") as PixelBox
	var talk: PixelBox = theme.get_stylebox("panel", &"DialoguePanel") as PixelBox
	_check(window != null and talk != null and window.texture == talk.texture and window.mark_seed != talk.mark_seed, "windows share their images, not their marks")


## The middle of a box's face is (mostly) `colour`.
func _face_near(style: PixelBox, colour: Color) -> bool:
	if style == null or style.texture == null:
		return false
	var image: Image = style.texture.get_image()
	var sum := Color(0, 0, 0, 0)
	var count: int = 0
	for y: int in range(style.margins.y + 1, image.get_height() - style.margins.w):
		for x: int in range(image.get_width() / 3, image.get_width() * 2 / 3):
			sum += image.get_pixel(x, y)
			count += 1
	if count == 0:
		return false
	var mean: Color = sum / float(count)
	return absf(mean.r - colour.r) + absf(mean.g - colour.g) + absf(mean.b - colour.b) < 0.18


## Old and used, the same every run: chipped silhouettes, iron at a window's corners, marks
## laid out by the control and its size.
func _test_materials() -> void:
	var made: UiBlocks.Spec = UiBlocks.spec(UiBlocks.Kind.WOOD, UiPalette.EBONY, UiPalette.EBONY_SIDE, 128, 96, 18, 4, 7)
	made.frame = 5
	made.fittings = true
	var once: Image = UiBlocks.sheet(made)
	var again: Image = UiBlocks.sheet(made)
	_check(once.get_data() == again.get_data(), "a material is seeded: the same each run")
	var other: UiBlocks.Spec = made.copy()
	other.seed = 8
	_check(UiBlocks.sheet(other).get_data() != once.get_data(), "another seed, another version")
	var gaps: int = 0
	for x: int in range(3, once.get_width() - 3):
		if once.get_pixel(x, 0).a == 0.0:
			gaps += 1
	for y: int in range(3, 96 - 3):
		if once.get_pixel(0, y).a == 0.0:
			gaps += 1
	_check(gaps > 0, "its silhouette is chipped and dented, not a ruled box")
	var iron: int = 0
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		for ly: int in range(1, 5):
			for lx: int in range(1, made.margin - 1):
				var x: int = lx if corner.x == 0 else once.get_width() - 1 - lx
				var y: int = ly if corner.y == 0 else 96 - 1 - ly
				var c: Color = once.get_pixel(x, y)
				if c.a > 0.0 and absf(c.r - c.b) < 0.08 and c.v > UiPalette.EBONY.v + 0.15:
					iron += 1
	_check(iron > 12, "a window's corners are bound in iron")
	var sunk: UiBlocks.Spec = UiBlocks.spec(UiBlocks.Kind.IRON, UiPalette.IRON, UiPalette.IRON_SIDE, 48, 20, 5, 1, 41)
	sunk.sunk = 2
	var low: Image = UiBlocks.sheet(sunk)
	var clear: bool = true
	for x: int in low.get_width():
		clear = clear and low.get_pixel(x, 0).a == 0.0 and low.get_pixel(x, 1).a == 0.0
	_check(clear and low.get_height() == 2 + 20 + 1 + 1, "a pressed plate's face sits two rows lower")
	var box: PixelBox = GameTheme.shared().get_stylebox("panel", &"MenuWindow") as PixelBox
	var first: Array = box._layout(101, Vector2i(600, 400))
	_check(first == box._layout(101, Vector2i(600, 400)) and first == box._layout(101, Vector2i(603, 402)), "a control keeps its marks, and when it grows a little")
	_check(first.size() >= box.mark_range.x and first.size() <= box.mark_range.y, "as many marks as its size asks, within the material's range")
	var differs: bool = false
	for id: int in range(102, 110):
		differs = differs or box._layout(id, Vector2i(600, 400)) != first
	_check(differs, "another control, other marks")
	var theme: GameTheme = GameTheme.shared()
	for kind: StringName in [&"Button", &"PrimaryButton", &"ChipButton", &"SlotButton"]:
		var states: Array[PixelBox] = []
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			states.append(theme.get_stylebox(state, kind) as PixelBox)
		var same: bool = true
		for style: PixelBox in states:
			same = same and style.mark_rects == states[0].mark_rects and style._layout(7, Vector2i(80, 26)) == states[0]._layout(7, Vector2i(80, 26))
		_check(same, "%s keeps its marks hovered, pressed and disabled" % kind)
	var hovered: PixelBox = theme.get_stylebox("hover", &"RowButton") as PixelBox
	var chosen: PixelBox = theme.get_stylebox("pressed", &"RowButton") as PixelBox
	_check(hovered.mark_seed == chosen.mark_seed and hovered.variants[0].get_size() == chosen.variants[0].get_size(), "a row keeps its shape hovered and chosen")


## The pixel face at its whole steps; the interface's scale snapped so a font pixel is whole
## screen pixels.
func _test_pixel_scale() -> void:
	_check(GameTheme.text_size(13) == 18 and GameTheme.text_size(16) == 18 and GameTheme.text_size(22) == 18 and GameTheme.text_size(28) == 36 and GameTheme.text_size(36) == 36, "old sizes go to the nearest whole step")
	var base := Vector2i(1280, 720)
	_check(is_equal_approx(ApplicationUiScale.pixel_factor(100, Vector2i(2560, 1440), base), 1.0), "2560×1440 at 100 percent stays (3 screen pixels a font pixel)")
	_check(is_equal_approx(ApplicationUiScale.pixel_factor(100, Vector2i(1920, 1080), base) * 1.5, 4.0 / 3.0), "1920×1080 at 100 percent draws at 4/3 (2 screen pixels)")
	_check(is_equal_approx(ApplicationUiScale.pixel_factor(100, Vector2i(1280, 800), base), 4.0 / 3.0), "a Steam Deck's 1280×800 at 4/3")
	# The window a 1280×800 screen opened as before a first start covered it (1088×612): the
	# smallest step, a font pixel one screen pixel (12-pixel text), the three settings alike.
	for percent: int in ApplicationUiScale.PERCENTS:
		_check(is_equal_approx(ApplicationUiScale.pixel_factor(percent, Vector2i(1088, 612), base) * 0.85, 2.0 / 3.0), "1088×612 at %d percent: the smallest step" % percent)
	_check(not ApplicationUiScale.levels_differ(Vector2i(1088, 612), base) and not ApplicationUiScale.levels_differ(Vector2i(1280, 800), base) and not ApplicationUiScale.levels_differ(Vector2i(1280, 720), base), "the three settings draw alike at 1088×612, 1280×800 and 1280×720: 设置 says so")
	_check(ApplicationUiScale.levels_differ(Vector2i(1920, 1080), base) and ApplicationUiScale.levels_differ(Vector2i(2560, 1440), base), "and differ at 1920×1080 and 2560×1440")
	for window: Vector2i in [Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1200), Vector2i(3840, 2160), Vector2i(800, 600)]:
		for percent: int in ApplicationUiScale.PERCENTS:
			var stretch: float = minf(window.x / 1280.0, window.y / 720.0)
			var whole: float = ApplicationUiScale.pixel_factor(percent, window, base) * stretch * GameTheme.GRID
			_check(absf(whole - roundf(whole)) < 0.001 and whole >= 1.0, "%s at %d percent: a font pixel is %.3f screen pixels" % [window, percent, whole])
	for window: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160), Vector2i(1706, 960)]:
		var stretch: float = minf(window.x / 1280.0, window.y / 720.0)
		var last: float = 0.0
		for percent: int in ApplicationUiScale.PERCENTS:
			var total: float = ApplicationUiScale.pixel_factor(percent, window, base) * stretch
			_check(total <= stretch * 1.5 + 0.001, "%s at %d percent: never smaller than the interface is laid out for (%.3f)" % [window, percent, total])
			_check(total >= last - 0.001, "%s: a larger setting is never drawn smaller" % [window])
			last = total


## Sizes written into the interface's scenes are on the pixel face's steps too. The painted
## maps' own labels (res://scenes/world) are left out: the 2D map is invisible under its voxel
## view, which draws the world's text itself.
func _test_scene_sizes() -> void:
	var off: Array[String] = []
	var pattern := RegEx.create_from_string("theme_override_font_sizes/[a-z_]+ = (\\d+)")
	for path: String in _scenes("res://scenes"):
		if path.begins_with("res://scenes/world/"):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in pattern.search_all(text):
			if int(found.get_string(1)) % GameTheme.BODY_SIZE != 0:
				off.append("%s: %s" % [path, found.get_string(0)])
	_check(off.is_empty(), "the interface's scenes size their text in whole steps: %s" % [off])


func _scenes(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".tscn"):
			found.append(folder.path_join(file))
	for sub: String in DirAccess.get_directories_at(folder):
		found.append_array(_scenes(folder.path_join(sub)))
	return found


## Every text in the pixel face (缝合像素 12 px), aliased and unhinted, 霞鹜文楷 under it for
## glyphs it lacks, titles at twice its size with one of their pixels of side under them.
func _test_faces() -> void:
	var project: Theme = ThemeDB.get_project_theme()
	var body: FontFile = project.default_font as FontFile
	_check(body != null and body.resource_path == GameTheme.BODY_FONT_PATH, "the text face is the bundled pixel face")
	_check(body.allow_system_fallback, "the system fills in glyphs it lacks")
	var pixel: FontFile = GameTheme.pixel_font()
	_check(pixel != null and pixel.antialiasing == TextServer.FONT_ANTIALIASING_NONE and pixel.hinting == TextServer.HINTING_NONE, "the pixel face is aliased and unhinted")
	_check(pixel.fallbacks.size() == 1 and pixel.fallbacks[0].resource_path == GameTheme.FALLBACK_FONT_PATH, "a glyph the pixel face lacks comes from 霞鹜文楷")
	var theme: GameTheme = GameTheme.shared()
	_check(theme.default_font == GameTheme.text_font() and GameTheme.text_font().base_font == pixel and theme.get_font("font", &"TitleLabel") == pixel, "text and titles are in the pixel face")
	_check(GameTheme.text_font().get_height(GameTheme.BODY_SIZE) <= 22.0, "a line of text no taller than 霞鹜文楷's was, so layouts keep their rhythm")
	_check(is_equal_approx(GameTheme.BODY_SIZE / 12.0, GameTheme.GRID) and GameTheme.PIXEL_SIZE == GameTheme.BODY_SIZE * 2, "18 px is its grid pixel, titles twice that")
	_check(theme.get_constant("shadow_offset_y", &"TitleLabel") == GameTheme.PIXEL_STEP and GameTheme.PIXEL_STEP * 12 == GameTheme.PIXEL_SIZE, "one font pixel of side under a title")


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
	_check(cursor.focused_button() == null, "the title's menu shows its choice by its stroke, not the arrow")
	# 设置: each label and its control a pair of one width, so the pairs stand in two columns.
	_check(shell.request_settings_from_main_menu(), "设置 opens")
	for i: int in 4:
		await tree.process_frame
	shell.ui_scale_option.grab_focus()
	await tree.process_frame
	await tree.process_frame
	_check(cursor.focused_button() == shell.ui_scale_option and cursor.visible, "it points at the focused button")
	_check(cursor.global_position.x < shell.ui_scale_option.global_position.x, "from its left")
	shell.settings_cancel_button.grab_focus()
	await tree.process_frame
	_check(cursor.focused_button() == null, "buttons side by side show only their rim")
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
	_check(seconds.size() == 4 and seconds.all(func(x: float) -> bool: return is_equal_approx(x, seconds[0]) and x > firsts[0]), "the second column lines up beside it: %s" % [seconds])
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
