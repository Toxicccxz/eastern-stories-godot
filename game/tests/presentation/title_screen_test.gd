extends RefCounted

## The title (DECISIONS「标题画面」): title_screen.json in the catalog, the ink lettering from
## its baked masks (one language at a time), the title shown while no journey runs and only then,
## the menu's buttons dressed but still the shell's own, the camera flying to a choice's
## place, and a start going ahead at once while the ink lifts off over it.
const ShellTests = preload("res://tests/application/application_shell_test.gd")
const SHELL_SCENE: PackedScene = preload("res://scenes/application/application_shell.tscn")

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	_test_data()
	_test_logo_blocks()
	await _test_wide_screens(tree)
	await _test_shell(tree)
	return {"assertions": assertions, "failures": failures}


func _check(condition: bool, message: String) -> bool:
	assertions += 1
	if not condition:
		failures.append(message)
	return condition


func _test_data() -> void:
	var definition: TitleScreenDefinition = GameContent.catalog().title_screen()
	if not _check(definition != null, "title_screen.json is in the catalog"):
		return
	var atlas: AtlasTable = GameContent.catalog().atlas()
	for button: StringName in [&"NewGameButton", &"ContinueButton", &"LoadButton", &"RecoveryButton", &"MenuSettingsButton", &"QuitButton"]:
		var choice: TitleScreenDefinition.Choice = definition.choice(button)
		if not _check(choice != null, "%s has a place on the 沙盘" % button):
			continue
		_check(choice.place == &"" or atlas.cell(choice.place) != null, "%s flies to a place of the atlas: %s" % [button, choice.place])
		_check(choice.weather in TitleScreenDefinition.WEATHERS, "%s drifts a known weather" % button)
	_check(definition.choice(&"ContinueButton").place == &"", "继续 flies to the save's own place")
	_check(atlas.cell(definition.new_game_place) != null, "a new journey's place is on the 沙盘")
	for language: String in ["zh_CN", "en", "fr"]:
		_check(ResourceLoader.exists(definition.logo_for(language)), "a logo mask for %s" % language)
	_check(ResourceLoader.exists(definition.seal_for("zh_CN")) and definition.seal_for("en") == "", "侠 on the Chinese seal; no Chinese on another language's")
	var errors: Array[String] = []
	var reader := ContentRecordReader.new({"choices": {"NewGameButton": {"weather": "rain", "zoom_percent": 5}}, "logo_width_px": 10}, "test", errors)
	TitleScreenDefinition.from_record(reader)
	_check(errors.size() == 3, "an unknown weather, a zoom out of range and a tiny logo are refused: %s" % [errors])


## The lettering: a large antialiased mask (ink in red, the ink blurred wide in green) inked by
## its shader, the other language spaced out under it, the seal stamped only after the writing,
## black ink until the light has passed, all gone once it has lifted off.
func _test_logo_blocks() -> void:
	var definition: TitleScreenDefinition = GameContent.catalog().title_screen()
	var mask: Texture2D = load(definition.logo_for("zh_CN")) as Texture2D
	var image: Image = mask.get_image()
	var greys: Dictionary = {}
	var blurred: bool = false
	for x: int in range(0, image.get_width(), 3):
		var pixel: Color = image.get_pixel(x, image.get_height() / 2)
		greys[roundi(pixel.r * 255.0)] = true
		blurred = blurred or (pixel.g > 0.05 and pixel.r < 0.01)
	_check(image.get_width() >= 800 and greys.size() > 8, "a large mask that keeps its antialiased edge: %d wide, %d greys" % [image.get_width(), greys.size()])
	_check(blurred, "with the ink blurred wide beside it, past the ink's own edge")
	_check(definition.line_for("zh_CN") == "EASTERN STORIES" and definition.line_for("en") == "东方故事" and definition.line_for("ja") == "東方物語", "the other language spaced out under the title (日本語: 故事 is an anecdote there)")
	var logo := TitleLogo.new()
	logo.build(definition.logo_for("zh_CN"), definition.seal_for("zh_CN"), definition.line_for("zh_CN"), true)
	var letters: TextureRect = logo.get_node("LogoView/Letters") as TextureRect
	var seal: TextureRect = logo.get_node("LogoView/Seal") as TextureRect
	var line: Label = logo.get_node("LogoView/Line") as Label
	if _check(letters != null and seal != null and line != null, "the lettering, its seal and the line under it"):
		var ink: ShaderMaterial = letters.material as ShaderMaterial
		_check(ink != null and ink.shader == TitleLogo.INK and ink.get_shader_parameter("mask") == letters.texture, "inked by its shader from the mask")
		_check(is_equal_approx(float(ink.get_shader_parameter("dry")), TitleLogo.DRY), "brush lettering shows its dry streaks")
		_check(seal.visible and line.text == "EASTERN STORIES", "侠 on the Chinese title, EASTERN STORIES under it")
		logo.write = 0.5
		logo._process(0.0)
		var seal_mat: ShaderMaterial = seal.material as ShaderMaterial
		_check(float(seal_mat.get_shader_parameter("fade")) < 0.01 and line.modulate.a < 0.01, "half written: neither the line nor the seal yet")
		logo.write = 1.0
		logo._process(0.0)
		_check(float(seal_mat.get_shader_parameter("fade")) > 0.99 and line.modulate.a > 0.99 and seal.scale.is_equal_approx(Vector2.ONE), "written: the line up and the seal stamped")
		var dim: ShaderMaterial = (logo.get_node("Dim") as ColorRect).material as ShaderMaterial
		_check(line.modulate.r < 0.2 and float(dim.get_shader_parameter("strength")) < 0.01, "black ink on the clouds, no dusk yet")
		logo.lit = 1.0
		logo._process(0.0)
		_check(line.modulate.r > 0.9 and float(dim.get_shader_parameter("strength")) > 0.99, "the light has passed: white, on the dusk")
		logo.burn = 1.15
		logo._process(0.0)
		_check(float(seal_mat.get_shader_parameter("fade")) < 0.01 and line.modulate.a < 0.01 and float(dim.get_shader_parameter("strength")) < 0.01, "lifted off: nothing left")
	var english := TitleLogo.new()
	english.build(definition.logo_for("en"), definition.seal_for("en"), definition.line_for("en"), false)
	var plain: ShaderMaterial = (english.get_node("LogoView/Letters") as TextureRect).material as ShaderMaterial
	_check(not (english.get_node("LogoView/Seal") as TextureRect).visible and (english.get_node("LogoView/Letters") as TextureRect).texture != letters.texture and is_zero_approx(float(plain.get_shader_parameter("dry"))), "English is its own lettering: no Chinese seal, no brush streaks")
	for node: TitleLogo in [logo, english]:
		node.free()


## Wider than 16:9 the title keeps its 16:9 size and place for the screen's height, and the menu's
## column stays under its line, on a phone too (owner, 2026-11-20: on a 20:9 phone the menu sat in
## the middle of the screen, over the lettering, which had also grown with the width).
func _test_wide_screens(tree: SceneTree) -> void:
	var definition: TitleScreenDefinition = GameContent.catalog().title_screen()
	var logo := TitleLogo.new()
	logo.at = Vector2(definition.logo_percent[0], definition.logo_percent[1]) / 100.0
	logo.width_px = definition.logo_width_px
	logo.build(definition.logo_for("zh_CN"), definition.seal_for("zh_CN"), definition.line_for("zh_CN"), true)
	var letters: TextureRect = logo.get_node("LogoView/Letters") as TextureRect
	var line: Label = logo.get_node("LogoView/Line") as Label
	logo.place_for(Vector2(1280, 800))
	_check(is_equal_approx(letters.size.x, logo.width_px), "the Steam Deck's 16:10 keeps its title: %.1f wide" % letters.size.x)
	logo.place_for(Vector2(1920, 1080))
	_check(is_equal_approx(letters.size.x, logo.width_px * 1.5), "so does 16:9: %.1f wide" % letters.size.x)
	var sixteen_nine: Array[Rect2] = [letters.get_rect(), line.get_rect()]
	# The line's letters end a font's height under its top (its box is taller).
	var line_bottoms: Dictionary[Vector2, float] = {Vector2(1920, 1080): _letters_bottom(line)}
	for screen: Vector2 in [Vector2(2400, 1080), Vector2(2560, 1080), Vector2(3840, 1080)]:
		logo.place_for(screen)
		_check(letters.get_rect().is_equal_approx(sixteen_nine[0]) and line.get_rect().is_equal_approx(sixteen_nine[1]), "%s keeps the 16:9 title at the left, the rest for the 沙盘: %s" % [screen, letters.get_rect()])
		line_bottoms[screen] = _letters_bottom(line)
	logo.free()
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	shell.configure_before_start(GameSaveStorageProfile.isolated_test("title-wide"), ShellTests.MemoryFiles.new(), null, ShellTests.MemoryFiles.new())
	tree.root.add_child(shell)
	for i: int in 6:
		await tree.process_frame
	var presenter: SafeAreaPresenter = shell.get_node("SafeAreaPresentation") as SafeAreaPresenter
	var panel: Control = shell.get_node("ShellCanvas/MainMenuPanel/Center/Panel") as Control
	var scroll: ScrollContainer = panel.get_node("ResponsiveScroll") as ScrollContainer
	# Screens 1080 pixels high draw 720 UI pixels: 1.5 to one. The phone (20:9) is touch-sized.
	for screen_case: Array in [[Vector2(1920, 1080), false, "16:9"], [Vector2(2560, 1080), false, "a 21:9 monitor"], [Vector2(2400, 1080), true, "a 20:9 phone"]]:
		var screen: Vector2 = screen_case[0]
		var view := Rect2(Vector2.ZERO, (screen / 1.5).floor())
		presenter.set_capability(FixedSafeArea.new(SafeAreaMetrics.new(view, view, false, screen_case[1])))
		for i: int in 4:
			await tree.process_frame
		var first: Rect2 = shell.new_game_button.get_global_rect()
		var menu: Rect2 = panel.get_global_rect()
		_check(first.position.y * 1.5 >= line_bottoms[screen], "%s: the menu starts under the title's line (%.0f ≥ %.0f px)" % [screen_case[2], first.position.y * 1.5, line_bottoms[screen]])
		_check(menu.position.x < view.size.x * 0.15 and menu.end.y <= view.end.y, "%s: a column at the lower left: %s" % [screen_case[2], menu])
		_check(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s: all of it shows, without scrolling" % screen_case[2])
	presenter.set_capability(GodotSafeAreaCapability.new())
	shell.queue_free()
	await tree.process_frame


static func _letters_bottom(line: Label) -> float:
	return line.position.y + line.get_theme_font("font").get_height(line.get_theme_font_size("font_size"))


func _test_shell(tree: SceneTree) -> void:
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	shell.configure_before_start(GameSaveStorageProfile.isolated_test("title-screen"), ShellTests.MemoryFiles.new(), null, ShellTests.MemoryFiles.new())
	tree.root.add_child(shell)
	for i: int in 6:
		await tree.process_frame
	var title: TitleScreen = shell.get_node_or_null("TitleScreen") as TitleScreen
	if not _check(title != null, "the shell has its title"):
		shell.queue_free()
		return
	_check(shell.shell_state().mode() == ApplicationShellState.Mode.MAIN_MENU and title.visible, "the title shows behind the main menu")
	_check(title.layer < shell.shell_canvas.layer, "under the shell's dialogs")
	_check(title.menu_fx.buttons().has(shell.new_game_button) and shell.new_game_button.theme_type_variation == &"TitleMenuItem", "the menu's own buttons, dressed")
	_check(shell.new_game_button.get_node_or_null("Letters") != null and shell.new_game_button.get_node_or_null("Swash") != null, "with voxel letters and a stroke")
	var quit_button: Button = shell.get_node("%QuitButton") as Button
	_check(quit_button != null, "退出游戏 is on the menu")
	# The first choice's place name waits for the clouds to part (it once rose over them alone),
	# and the menu for the seal to be stamped.
	await tree.create_timer(1.6).timeout
	_check(title.menu_fx.menu_alpha < 0.01 and title.caption.modulate.a < 0.01, "the place's name waits while the clouds part: name %.2f, menu %.2f" % [title.caption.modulate.a, title.menu_fx.menu_alpha])
	await tree.create_timer(TitleScreen.MENU_UP_SECONDS - 1.6 + 0.9).timeout
	_check(title.caption.modulate.a > 0.9 and not title.caption.text.is_empty(), "and rises with the menu: %.2f" % title.caption.modulate.a)
	# A quick pass over one choice onto the next leaves one stroke (two once stayed out).
	shell.menu_settings_button.grab_focus()
	await tree.process_frame
	quit_button.grab_focus()
	await tree.create_timer(0.6).timeout
	_check(title.menu_fx.stroke_reveal(shell.menu_settings_button) < 0.01 and title.menu_fx.stroke_reveal(quit_button) > 0.99, "a quick pass over 设置 onto 退出游戏 leaves one stroke: %.2f, %.2f" % [title.menu_fx.stroke_reveal(shell.menu_settings_button), title.menu_fx.stroke_reveal(quit_button)])
	shell.menu_settings_button.grab_focus()
	await tree.process_frame
	var settings: TitleScreenDefinition.Choice = title.definition.choice(&"MenuSettingsButton")
	await tree.create_timer(2.0).timeout
	_check(title.sand.centre.distance_to(title.sand.place_of(settings.place)) < 1.0, "choosing 设置 flies the camera to its place")
	_check(title.caption.text == TitleSand.place_name(settings.place) and not title.caption.text.is_empty(), "and names it: %s" % title.caption.text)
	_check(shell.request_settings_from_main_menu() and title.visible, "设置 opens over the title")
	shell.cancel_settings()
	await tree.process_frame
	_check(shell.request_new_game_from_menu() and title.visible, "新游戏's setup too")
	shell.player_name_edit.text = "凌雪"
	shell.select_new_game_gender(CharacterState.GENDER_FEMALE)
	_check(shell.submit_new_game_setup(), "a journey starts at once")
	await tree.process_frame
	_check(title.entering() and title.layer > shell.shell_canvas.layer, "the ink lifts off over the busy note")
	var started: bool = false
	for i: int in 2000:
		await tree.process_frame
		if shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING:
			started = true
			break
	_check(started, "the world comes up under the title")
	for i: int in 600:
		await tree.process_frame
		if not title.visible:
			break
	_check(not title.visible and not title.entering(), "then the title is gone")
	shell.queue_free()
	await tree.process_frame


## Measures the screen it is given: one this test cannot open.
class FixedSafeArea extends SafeAreaCapability:
	var _metrics: SafeAreaMetrics

	func _init(metrics: SafeAreaMetrics) -> void:
		_metrics = metrics

	func measure(_viewport: Viewport) -> SafeAreaMetrics:
		return _metrics
