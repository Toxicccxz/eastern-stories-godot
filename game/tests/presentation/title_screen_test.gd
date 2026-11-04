extends RefCounted

## The title (DECISIONS「标题画面」): title_screen.json in the catalog, the logo's blocks from its
## baked masks (one language at a time), the title shown while no journey runs and only then,
## the menu's buttons dressed but still the shell's own, the camera flying to a choice's
## place, and a start going ahead at once while the title burns over it.
const ShellTests = preload("res://tests/application/application_shell_test.gd")
const SHELL_SCENE: PackedScene = preload("res://scenes/application/application_shell.tscn")

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	_test_data()
	_test_logo_blocks()
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


## The blocks: ink thicker mid-stroke, the stroke behind it, embers one per stroke column.
func _test_logo_blocks() -> void:
	var definition: TitleScreenDefinition = GameContent.catalog().title_screen()
	var logo := TitleLogo.new()
	logo.build(definition.logo_for("zh_CN"), definition.seal_for("zh_CN"))
	var board: Node3D = logo.get_node("LogoView/World/Board") as Node3D
	var ink: MultiMeshInstance3D = board.get_node_or_null("Ink") as MultiMeshInstance3D
	var embers: MultiMeshInstance3D = board.get_node_or_null("Embers") as MultiMeshInstance3D
	if _check(ink != null and embers != null, "the logo has its ink and its embers"):
		_check(ink.multimesh.instance_count > 5000 and embers.multimesh.instance_count > 1000, "built from the mask: %d blocks, %d embers" % [ink.multimesh.instance_count, embers.multimesh.instance_count])
	# The block list (a headless run keeps no instance data in the MultiMesh itself).
	var cubes: Array = TitleLogo.parts_for(definition.logo_for("zh_CN"), definition.seal_for("zh_CN"))["cubes"]
	var deepest: float = 0.0
	var stroke: int = 0
	for cube: Array in cubes:
		deepest = maxf(deepest, (cube[0] as Vector3).z)
		if cube[2]:
			stroke += 1
	_check(cubes.size() == ink.multimesh.instance_count, "one block per instance")
	_check(deepest >= 2.0, "strokes rise toward their middle: %s" % deepest)
	_check(stroke > 2000 and stroke < cubes.size(), "a vermilion stroke behind the letters")
	var again := TitleLogo.new()
	again.build(definition.logo_for("zh_CN"), definition.seal_for("zh_CN"))
	_check((again.get_node("LogoView/World/Board/Ink") as MultiMeshInstance3D).multimesh == ink.multimesh, "built once per mask in a run")
	var english := TitleLogo.new()
	english.build(definition.logo_for("en"), definition.seal_for("en"))
	_check((english.get_node("LogoView/World/Board/Ink") as MultiMeshInstance3D).multimesh != ink.multimesh, "English is its own logo, not both at once")
	for node: TitleLogo in [logo, again, english]:
		node.free()


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
	# The first choice's place name waits for the clouds to part (it once rose over them alone).
	await tree.create_timer(1.6).timeout
	_check(title.menu_fx.menu_alpha < 0.01 and title.caption.modulate.a < 0.01, "the place's name waits while the clouds part: name %.2f, menu %.2f" % [title.caption.modulate.a, title.menu_fx.menu_alpha])
	await tree.create_timer(1.6).timeout
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
	_check(title.entering() and title.layer > shell.shell_canvas.layer, "the logo burns over the busy note")
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
