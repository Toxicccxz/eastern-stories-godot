extends RefCounted

## 画质 (DECISIONS「画质」): 高 is the game as it was drawn before the setting, 低 the cheaper
## shadows, no MSAA and four lamps casting (graphics_quality.json); a Steam Deck starts on 低,
## everything else on 高; the setting is kept with the others (schema 12, an older file reads as
## the machine's first level), applies the moment 应用 is pressed, the map's view following at
## once; a run of slow seconds says once, ever, that it can go lower.
const Display := preload("res://tests/application/display_settings_test.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var before: int = GraphicsQuality.level
	var told: bool = GraphicsQuality.hint_told
	var keep: Callable = GraphicsQuality.keep_hint_told
	_levels()
	_device_default()
	_storage()
	_slow_hint()
	await _settings_page(tree)
	await _view_follows(tree)
	GraphicsQuality.apply(before)
	GraphicsQuality.hint_told = told
	GraphicsQuality.keep_hint_told = keep
	return {"assertions": _count, "failures": _failures.duplicate()}


func _levels() -> void:
	var high: Dictionary = GraphicsQuality.settings(GraphicsQuality.Value.HIGH)
	_check(high.get("shadow_filter") == "soft_low" and int(high.get("sun_shadow_size")) == int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size")), "高 is the shadows as the project draws them")
	_check(GraphicsQuality.FILTERS[String(high.get("shadow_filter"))] == int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality")) and GraphicsQuality.FILTERS[String(high.get("shadow_filter"))] == int(ProjectSettings.get_setting("rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality")), "the project's own filter, sun and lamps")
	_check(GraphicsQuality.msaa(GraphicsQuality.Value.HIGH) == Viewport.MSAA_4X and GraphicsQuality.sun_shadow_mode(GraphicsQuality.Value.HIGH) == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS and GraphicsQuality.lamp_shadows(GraphicsQuality.Value.HIGH) == VoxelLighting.LAMP_SHADOWS, "高: 4x MSAA, four splits, every lamp the light casts")
	var low: Dictionary = GraphicsQuality.settings(GraphicsQuality.Value.LOW)
	_check(low.get("shadow_filter") == "hard" and int(low.get("sun_shadow_size")) == 2048, "低: hard shadows, a 2048 sun shadow")
	_check(GraphicsQuality.msaa(GraphicsQuality.Value.LOW) == Viewport.MSAA_DISABLED and GraphicsQuality.sun_shadow_mode(GraphicsQuality.Value.LOW) == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and GraphicsQuality.lamp_shadows(GraphicsQuality.Value.LOW) == 4, "低: no MSAA, two splits, four lamps")


func _device_default() -> void:
	_check(GraphicsQuality.default_for("Windows", "NVIDIA GeForce RTX 4070 SUPER", "") == GraphicsQuality.Value.HIGH, "a Windows desktop starts on 高")
	_check(GraphicsQuality.default_for("Windows", "AMD Custom GPU 0405", "") == GraphicsQuality.Value.HIGH, "the Deck's GPU name alone under Windows: 高 (it is the player's own install)")
	_check(GraphicsQuality.default_for("Linux", "AMD Radeon RX 7800 XT (RADV NAVI32)", "") == GraphicsQuality.Value.HIGH, "a Linux desktop: 高")
	_check(GraphicsQuality.default_for("Linux", "AMD Custom GPU 0405 (RADV VANGOGH)", "") == GraphicsQuality.Value.LOW, "a Steam Deck by its GPU: 低")
	_check(GraphicsQuality.default_for("Linux", "AMD Custom GPU 0932 (RADV SEPHIROTH)", "") == GraphicsQuality.Value.LOW, "a Steam Deck OLED: 低")
	_check(GraphicsQuality.default_for("Linux", "llvmpipe", "1") == GraphicsQuality.Value.LOW, "Steam's SteamDeck=1: 低")


func _storage() -> void:
	var files := Display.MemoryFiles.new()
	var repository := ApplicationSettingsRepository.new(files)
	var written: ApplicationSettingsResult = repository.write(ApplicationSettingsSnapshot.defaults().with_graphics_quality(GraphicsQuality.Value.LOW).with_quality_hint_told(true))
	var text: String = files.files[ApplicationSettingsRepository.SETTINGS_PATH].get_string_from_utf8()
	_check(written.succeeded() and text.contains("graphics_quality=\"low\"") and text.contains("quality_hint_told=true"), "低 and the hint told are kept: %s" % text)
	var back: ApplicationSettingsResult = repository.load()
	_check(back.succeeded() and back.snapshot().graphics_quality() == GraphicsQuality.Value.LOW and back.snapshot().quality_hint_told() and back.snapshot().version() == 12, "and read back")
	var lines := PackedStringArray()
	for line: String in text.replace("schema_version=12", "schema_version=11").split("\n"):
		if not line.begins_with("graphics_quality=") and not line.begins_with("quality_hint_told="):
			lines.append(line)
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "\n".join(lines).to_utf8_buffer()
	var old: ApplicationSettingsResult = repository.load()
	_check(old.succeeded() and old.snapshot().graphics_quality() == GraphicsQuality.device_default() and not old.snapshot().quality_hint_told(), "a version 11 file reads as this machine's first level, not told")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = text.replace("graphics_quality=\"low\"", "graphics_quality=\"ultra\"").to_utf8_buffer()
	_check(repository.load().outcome() == ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "an unknown level is refused")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = text.replace("quality_hint_told=true\n", "").to_utf8_buffer()
	_check(repository.load().outcome() == ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "a version 12 file without the hint's key is refused")
	_check(not ApplicationSettingsSnapshot.defaults().with_graphics_quality(5).is_valid(), "a snapshot with no such level is invalid")
	_check(ApplicationSettingsSnapshot.defaults().graphics_quality() == GraphicsQuality.device_default(), "the default is this machine's first level")


func _slow_hint() -> void:
	var hint := GraphicsQualityHint.new({"below_fps": 30, "seconds": 5, "settle_seconds": 10})
	var told: bool = false
	for frame: int in 10 * 20:
		told = told or hint.advance(1.0 / 20.0)
	_check(not told, "the first ten seconds of a map (its building) never count, however slow")
	for frame: int in 4 * 20:
		told = told or hint.advance(1.0 / 20.0)
	_check(not told, "four slow seconds: not yet")
	for frame: int in 60:
		told = told or hint.advance(1.0 / 60.0)
	for frame: int in 4 * 20:
		told = told or hint.advance(1.0 / 20.0)
	_check(not told, "a smooth second between starts the count again")
	for frame: int in 20:
		told = told or hint.advance(1.0 / 20.0)
	_check(told, "five slow seconds in a row: time to say it")
	var smooth := GraphicsQualityHint.new({"below_fps": 30, "seconds": 5, "settle_seconds": 10})
	var said: bool = false
	for frame: int in 30 * 40:
		said = said or smooth.advance(1.0 / 40.0)
	_check(not said, "at 40 frames a second never")
	_check(GraphicsQuality.slow_hint().get("below_fps") == 30 and GraphicsQuality.slow_hint().get("seconds") == 5, "the data's 30 fps, five seconds")


## 设置: 画质 beside the 界面缩放, kept by 应用, applied at once; the hint told is kept by the
## service and comes back with the next start.
func _settings_page(tree: SceneTree) -> void:
	var files := Display.MemoryFiles.new()
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	shell.configure_before_start(GameSaveStorageProfile.isolated_test("graphics-quality"), Display.MemoryFiles.new(), null, files, Display.FakeDisplay.new())
	tree.root.add_child(shell)
	await _frames(tree, 3)
	_check(shell.request_settings_from_main_menu(), "设置 opens")
	await tree.process_frame
	var option: OptionButton = shell.graphics_quality_option
	_check(option.is_visible_in_tree() and not option.disabled and option.get_parent().get_parent() == shell.ui_scale_row, "the 画质 row is there, beside the 界面缩放")
	_check(option.item_count == 2 and option.get_item_text(0) == "高" and option.get_item_text(1) == "低", "高 and 低")
	_check(option.get_selected_id() == GraphicsQuality.device_default(), "this machine's first level chosen")
	var revision: int = GraphicsQuality.revision
	option.select(option.get_item_index(GraphicsQuality.Value.LOW))
	_check(shell.apply_settings(), "应用")
	_check(GraphicsQuality.level == GraphicsQuality.Value.LOW and GraphicsQuality.revision > revision, "低 applies at once")
	var kept: ApplicationSettingsSnapshot = ApplicationSettingsRepository.new(files).load().snapshot()
	_check(kept.graphics_quality() == GraphicsQuality.Value.LOW and not kept.quality_hint_told(), "and is kept")
	GraphicsQuality.note_hint_told()
	kept = ApplicationSettingsRepository.new(files).load().snapshot()
	_check(kept.quality_hint_told() and kept.graphics_quality() == GraphicsQuality.Value.LOW, "the hint told is kept by the service, the level with it")
	shell.get_parent().remove_child(shell)
	shell.free()
	await tree.process_frame
	GraphicsQuality.apply(GraphicsQuality.Value.HIGH)
	GraphicsQuality.hint_told = false
	var next: ApplicationShellController = SHELL_SCENE.instantiate()
	next.configure_before_start(GameSaveStorageProfile.isolated_test("graphics-quality-next"), Display.MemoryFiles.new(), null, files, Display.FakeDisplay.new())
	tree.root.add_child(next)
	await _frames(tree, 3)
	_check(GraphicsQuality.level == GraphicsQuality.Value.LOW and GraphicsQuality.hint_told, "the next start comes back to 低, the hint not to be told again")
	next.get_parent().remove_child(next)
	next.free()
	await tree.process_frame


## The map's view follows a change at once: its MSAA, the sun's splits, how many lamps cast.
func _view_follows(tree: SceneTree) -> void:
	GraphicsQuality.apply(GraphicsQuality.Value.HIGH)
	var session: WorldSessionController = Work.create_session(tree)
	await _frames(tree, 4)
	var square := MapPlaces.enter(session, &"snow.square", &"snow.square.inn_entry") as WorldMapController
	await _frames(tree, 4)
	var view := square.get_node("MapView") as WorldVoxelView if square != null else null
	_check(view != null and view.lighting.sun != null, "the square's view is up")
	if view == null or view.lighting.sun == null:
		session.free()
		return
	view.set_frame("night", true)
	await _frames(tree, 6)
	_check(view.get_viewport().msaa_3d == Viewport.MSAA_4X and view.lighting.sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS and view.lighting.lamp_shadow_count() == VoxelLighting.LAMP_SHADOWS, "高 by night: 4x, four splits, eight lamps may cast")
	GraphicsQuality.apply(GraphicsQuality.Value.LOW)
	await _frames(tree, 3)
	_check(view.get_viewport().msaa_3d == Viewport.MSAA_DISABLED and view.lighting.sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and view.lighting.lamp_shadow_count() == 4, "低 at once: no MSAA, two splits, four lamps")
	_check(view.lighting.casting.size() <= 4, "and no more than four cast: %d" % view.lighting.casting.size())
	# The world let go (only the last few maps keep theirs) and built again: still 低.
	view.release_world()
	for frame: int in 600:
		await _frames(tree, 1)
		if view._built and view.lighting.sun != null:
			break
	view.set_frame("night", true)
	await _frames(tree, 6)
	_check(view._built and view.lighting.sun != null and view.lighting.sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "低 after the world is built again: two splits")
	_check(view._built and view.get_viewport().msaa_3d == Viewport.MSAA_DISABLED and view.lighting.lamp_shadow_count() == 4 and view.lighting.casting.size() <= 4, "低 after the world is built again: no MSAA, four lamps (%d cast)" % view.lighting.casting.size())
	GraphicsQuality.apply(GraphicsQuality.Value.HIGH)
	await _frames(tree, 3)
	_check(view.get_viewport().msaa_3d == Viewport.MSAA_4X and view.lighting.sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS and view.lighting.lamp_shadow_count() == VoxelLighting.LAMP_SHADOWS, "and back to 高")
	view.set_frame("", true)
	session.free()
	await tree.process_frame


const SHELL_SCENE: PackedScene = preload("res://scenes/application/application_shell.tscn")


func _frames(tree: SceneTree, count: int) -> void:
	for frame: int in count:
		await tree.physics_frame
		await tree.process_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
