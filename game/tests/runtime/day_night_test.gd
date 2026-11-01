extends RefCounted

## 昼夜 (美术优化 B, owner 批准 2026-10-27; DECISIONS「昼夜」): the day goes round with the world
## clock and stops with it; an outdoor room's text ends with natured.c's line on the sky and
## none indoors; a phase's first moment says its line once, outdoors only; the time of day is
## saved and Continue goes on from it; the 昼夜 setting is kept with the other settings.
## 天气 (DECISIONS「天气」): the outdoor text ends with the cloud's line after the phase's,
## none indoors; a change shows in the text and in the view's light, says nothing; the
## cloud is saved and Continue goes on from it.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const ShellTests := preload("res://tests/application/application_shell_test.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_settings()
	# The suites run with the day standing still (TestDay); this one is about the day.
	TestDay.use()
	await _world(tree)
	TestDay.restore()
	return {"assertions": _count, "failures": _failures.duplicate()}


## Settings schema 7: 昼夜 is kept; a version 6 file reads as 跟随游戏时间; applying sets DayNightPreference.
func _settings() -> void:
	var files := ShellTests.MemoryFiles.new()
	var repository := ApplicationSettingsRepository.new(files)
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "[application]\nschema_version=6\nwindow_mode=\"windowed\"\nlanguage=\"\"\nbattle_speed=\"fast\"\nhit_flash=false\nui_scale=125\nafter_knockout=\"finish\"\nobjective_hints=false\n".to_utf8_buffer()
	var old: ApplicationSettingsResult = repository.load()
	_check(old.succeeded() and old.snapshot().day_night() == DayNightPreference.Value.FOLLOW and not old.snapshot().objective_hints(), "a version 6 file: 跟随游戏时间, the rest kept")
	var written: ApplicationSettingsResult = repository.write(old.snapshot().with_day_night(DayNightPreference.Value.NIGHT))
	var back: ApplicationSettingsResult = repository.load()
	_check(written.succeeded() and back.succeeded() and back.snapshot().version() == ApplicationSettingsSnapshot.SCHEMA_VERSION and back.snapshot().day_night() == DayNightPreference.Value.NIGHT, "written and read back: 一直夜晚")
	_check(files.files[ApplicationSettingsRepository.SETTINGS_PATH].get_string_from_utf8().contains("day_night=\"night\""), "stored")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "[application]\nschema_version=7\nwindow_mode=\"windowed\"\nlanguage=\"\"\nbattle_speed=\"fast\"\nhit_flash=false\nui_scale=125\nafter_knockout=\"finish\"\nobjective_hints=false\n".to_utf8_buffer()
	_check(repository.load().outcome() == ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "a version 7 file without it is refused")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "[application]\nschema_version=7\nwindow_mode=\"windowed\"\nlanguage=\"\"\nbattle_speed=\"fast\"\nhit_flash=false\nui_scale=125\nafter_knockout=\"finish\"\nobjective_hints=false\nday_night=\"dusk\"\n".to_utf8_buffer()
	_check(repository.load().outcome() == ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "an unknown value is refused")
	ApplicationSettingsService._apply_battle(back.snapshot())
	_check(DayNightPreference.mode == DayNightPreference.Value.NIGHT, "applied")
	ApplicationSettingsService._apply_battle(old.snapshot())
	_check(DayNightPreference.mode == DayNightPreference.Value.FOLLOW, "and back")
	_check(not ApplicationSettingsSnapshot.new(ApplicationSettingsSnapshot.SCHEMA_VERSION).with_day_night(7).is_valid(), "a snapshot with no such mode is invalid")


func _world(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	session.configure_sky_random_source(Still.Still.new())
	await _frames(tree, 4)
	var clock: DayClock = session.day_clock()
	var sky: SkyState = session.sky_state()
	var lines: Array[String] = GameContent.catalog().sky_levels()
	_check(sky.level() == 1 and session.sky_level() == 1 and sky.minutes_left() >= 170 and sky.minutes_left() <= 180, "a new game begins under a few light clouds, the first change three hours off: %d, %d" % [sky.level(), sky.minutes_left()])
	_check(clock.day_seconds() >= DayClock.NEW_GAME_SECONDS and clock.phase().phase_id == &"morning", "a new game begins in the morning: %d" % clock.day_seconds())
	var before: int = clock.day_seconds()
	await _frames(tree, 10)
	_check(clock.day_seconds() > before, "the day goes on with the world: %d → %d" % [before, clock.day_seconds()])
	session.hold_world_time(&"test_menu")
	await _frames(tree, 2)
	before = clock.day_seconds()
	sky.set_state(2, 0)
	await _frames(tree, 10)
	_check(clock.day_seconds() == before and sky.level() == 2, "under the menu's hold it stands still, and so does the cloud")
	session.release_world_time(&"test_menu")
	await _frames(tree, 4)
	_check(sky.level() == 3 and sky.minutes_left() > 230, "let go, the change that was due comes: one step up, the next wait drawn: %d, %d" % [sky.level(), sky.minutes_left()])
	var hud: SharedGameplayUI = session.shared_ui()
	# Indoors (the inn): no line on the sky, and a phase's line does not reach the player.
	var inn_zone: ZoneDefinition = hud.card.current_zone()
	_check(inn_zone != null and not WorldMapController.zone_outdoors(inn_zone.zone_id) and hud.message_log.sky_line(inn_zone).is_empty(), "the inn's text has no line on the sky")
	clock.set_day_seconds(540 * 60 - 30)
	await _frames(tree, 2)
	await tree.create_timer(1.2).timeout
	await _frames(tree, 2)
	_check(clock.phase().phase_id == &"noon", "正午 came while the player was in the inn: %d" % clock.day_seconds())
	_check(not hud.combat_log.text.contains("已经是正午了"), "and said nothing indoors")
	# Outdoors (the square): the room's text ends with the phase's line, in the log and on the look.
	var square := MapPlaces.enter(session, &"snow.square", &"snow.square.inn_entry") as WorldMapController
	_check(square != null and square.map_id() == &"snow.outdoor", "out onto the square")
	await _frames(tree, 4)
	hud.describe_again()
	await _frames(tree, 2)
	var noon: DayPhaseDefinition = clock.phase()
	_check(hud.combat_log.text.contains(noon.desc_msg + "。" + lines[3] + "。"), "the square's text ends with 现在是正午时分…厚厚的云层堆积在天边。: %s" % hud.combat_log.text.right(80))
	_check(hud.message_log.sky_line(hud.card.current_zone()) == noon.desc_msg + "。" + lines[3] + "。", "the look's two lines too")
	# The cloud turns: the text follows, nothing is said of it, the view greys toward it.
	var view := square.get_node("MapView") as WorldVoxelView
	_check(view != null and is_equal_approx(view.lighting.cloud, VoxelLighting.CLOUD_AMOUNTS[3]), "the view shows the cloud it came out under: %s" % view.lighting.cloud)
	var said: int = hud.combat_log.text.length()
	sky.set_state(4, 0)
	await _frames(tree, 4)
	_check(sky.level() == 3 and hud.message_log.sky_line(hud.card.current_zone()).ends_with(lines[3] + "。"), "the change due from 乌云密布 goes down, and the look says so: %d" % sky.level())
	sky.set_state(4, 200)
	hud.describe_again()
	await _frames(tree, 2)
	_check(hud.combat_log.text.ends_with(lines[4] + "。") and hud.combat_log.text.length() > said, "乌云密布 in the room's text")
	_check(not hud.combat_log.text.substr(said).contains("乌云密布。\n") and hud.toasts().latest_text() != lines[4] + "。", "the change itself said nothing (ES2 says nothing)")
	await tree.create_timer(0.5).timeout
	await _frames(tree, 2)
	_check(view.lighting.cloud > VoxelLighting.CLOUD_AMOUNTS[3] and view.lighting.cloud < 1.0, "the view greys toward it over twenty seconds: %s" % view.lighting.cloud)
	# 经典: the sky is clear and the text says nothing of it.
	var production: PacingDefinition = GameContent.catalog().pacing()
	GameContent.catalog().set_pacing(production.copy().with_sky_weather(false))
	_check(session.sky_level() == 0 and hud.message_log.sky_line(hud.card.current_zone()) == noon.desc_msg + "。", "with sky_weather off the look has the phase's line alone")
	GameContent.catalog().set_pacing(production)
	# The next phase's first moment: one line, as a toast and in the log, not again within it.
	clock.set_day_seconds(720 * 60 - 30)
	await _frames(tree, 2)
	await tree.create_timer(1.2).timeout
	await _frames(tree, 2)
	_check(clock.phase().phase_id == &"afternoon", "下午 came on the square: %d" % clock.day_seconds())
	_check(hud.combat_log.text.count("太阳开始从西方的天空中慢慢西沉。") == 1, "its line once: %d" % hud.combat_log.text.count("太阳开始从西方的天空中慢慢西沉。"))
	_check(hud.toasts().latest_text() == "太阳开始从西方的天空中慢慢西沉。", "and as a toast: %s" % hud.toasts().latest_text())
	await tree.create_timer(0.6).timeout
	await _frames(tree, 2)
	_check(hud.combat_log.text.count("太阳开始从西方的天空中慢慢西沉。") == 1, "still once")
	# The voxel view follows the clock: afternoon is day; held frames are the suites' alone.
	_check(view != null and view.held_frame.is_empty() and view.lighting.weights["day"] > 0.99, "the view lights the afternoon as day")
	clock.set_day_seconds(990 * 60)
	await _frames(tree, 3)
	var turning: float = view.lighting.weights["dusk"]
	await tree.create_timer(1.2).timeout
	await _frames(tree, 2)
	_check(turning > 0.0 and turning < 0.5 and view.lighting.weights["dusk"] > 0.95 and is_equal_approx(view.lighting.amount, 0.45), "at 傍晚 the view turns to dusk over a second: %s → %s" % [turning, view.lighting.weights])
	# Save and Continue: the time of day and the cloud are kept exactly; nothing else of the day is.
	clock.set_day_seconds(40000)
	sky.set_state(3, 55)
	session.set_process(false)
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null and snapshot.day_seconds == 40000, "saved: %d" % (snapshot.day_seconds if snapshot != null else -1))
	_check(snapshot != null and snapshot.sky_level == 3 and snapshot.sky_minutes_left == 55, "the cloud saved: %d, %d" % [snapshot.sky_level if snapshot != null else -1, snapshot.sky_minutes_left if snapshot != null else -1])
	var text: String = GameSaveJsonCodec.encode(snapshot).text
	session.free()
	await tree.process_frame
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(GameSaveJsonCodec.decode(text).snapshot, tree.root)
	_check(restored.succeeded(), "Continue prepared: " + restored.path)
	if restored.succeeded():
		var fresh: WorldSessionController = restored.candidate
		_check(fresh.activate_restore_candidate() and fresh.day_clock().day_seconds() == 40000 and fresh.day_clock().phase().phase_id == &"noon", "Continue goes on from 11:06, at 正午: %d" % fresh.day_clock().day_seconds())
		_check(fresh.sky_state().level() == 3 and fresh.sky_state().minutes_left() == 55, "and under the same cloud, the change as far off: %d, %d" % [fresh.sky_state().level(), fresh.sky_state().minutes_left()])
		fresh.free()
		await tree.process_frame
	_check(PacePresets.of(GameContent.catalog().pacing(), CharacterState.PACE_CLASSIC).day_length_minutes == 24, "经典's day is ES2's 24 minutes")


func _frames(tree: SceneTree, count: int) -> void:
	for frame: int in count:
		await tree.physics_frame
		await tree.process_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
