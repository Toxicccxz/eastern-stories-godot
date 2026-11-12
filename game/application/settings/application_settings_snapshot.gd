class_name ApplicationSettingsSnapshot
extends RefCounted

## Version 2 adds the language; a version 1 file reads as following the system language.
## Version 3 adds the 战斗速度 and 受击闪红 (DECISIONS「手感」); older files read as 标准, on.
## Version 4 adds 无边框窗口 and the 界面缩放; an older "fullscreen" reads as 无边框窗口
## (what it showed), and the scale as 100%.
## Version 5 adds 击倒后 (DECISIONS「了结 / 放过」); an older file reads as 询问.
## Version 6 adds 目标提示 (DECISIONS「新手链与当前目标」); an older file reads as on.
## Version 7 adds 昼夜 (DECISIONS「昼夜」); an older file reads as 跟随游戏时间.
## Version 8 adds 自动存档提示 (DECISIONS「自动存档」); an older file reads as on.
## Version 9 adds the 分辨率 and the monitor the game was last set up on (DECISIONS「显示设置」);
## an older file reads as 自动, wherever the system opens the window.
## Version 10 adds the 总音量 (DECISIONS「战斗拍数 C」); an older file reads as DEFAULT_MASTER_VOLUME.
## Version 11 adds the 战斗开场动画 (DECISIONS「战斗演出 B」); an older file reads as 全程 (FULL).
## Version 12 adds the 画质 and whether its slow-frame hint was told (DECISIONS「画质」); an older
## file reads as this machine's first level (GraphicsQuality.device_default()), not told.
## Version 13 adds 切出窗口时暂停 (DECISIONS「切出窗口」); an older file reads as on.
const SCHEMA_VERSION: int = 13
## The 画质 is this machine's first level (GraphicsQuality.device_default()).
const DEVICE_QUALITY: int = -1
## The 总音量 at first start, in percent of full.
const DEFAULT_MASTER_VOLUME: int = 80
## The monitor is not known: the window stays where the system opens it.
const NO_SCREEN: int = -1

var _version: int
var _window_mode: int
var _language: String
var _battle_speed: int
var _hit_flash: bool
var _ui_scale: int
var _after_knockout: int
var _objective_hints: bool
var _day_night: int
var _autosave_notice: bool
var _resolution: Vector2i
var _screen: int
var _master_volume: int
var _battle_opening: int
var _graphics_quality: int
var _quality_hint_told: bool
var _pause_on_focus_loss: bool


func _init(
	p_version: int = SCHEMA_VERSION,
	p_window_mode: int = ApplicationWindowMode.Value.WINDOWED,
	p_language: String = LocalizationService.FOLLOW_SYSTEM,
	p_battle_speed: int = BattlePace.Speed.NORMAL,
	p_hit_flash: bool = true,
	p_ui_scale: int = ApplicationUiScale.DEFAULT,
	p_after_knockout: int = BattlePace.AfterKnockout.ASK,
	p_objective_hints: bool = true,
	p_day_night: int = DayNightPreference.Value.FOLLOW,
	p_autosave_notice: bool = true,
	p_resolution: Vector2i = ApplicationWindowSize.AUTO,
	p_screen: int = NO_SCREEN,
	p_master_volume: int = DEFAULT_MASTER_VOLUME,
	p_battle_opening: int = BattlePace.Opening.FULL,
	p_graphics_quality: int = DEVICE_QUALITY,
	p_quality_hint_told: bool = false,
	p_pause_on_focus_loss: bool = true,
) -> void:
	_version = p_version
	_window_mode = p_window_mode
	_language = p_language
	_battle_speed = p_battle_speed
	_hit_flash = p_hit_flash
	_ui_scale = p_ui_scale
	_after_knockout = p_after_knockout
	_objective_hints = p_objective_hints
	_day_night = p_day_night
	_autosave_notice = p_autosave_notice
	_resolution = p_resolution
	_screen = p_screen
	_master_volume = p_master_volume
	_battle_opening = p_battle_opening
	_graphics_quality = GraphicsQuality.device_default() if p_graphics_quality == DEVICE_QUALITY else p_graphics_quality
	_quality_hint_told = p_quality_hint_told
	_pause_on_focus_loss = p_pause_on_focus_loss


func version() -> int:
	return _version


func window_mode() -> int:
	return _window_mode


## A language code from languages.json, or LocalizationService.FOLLOW_SYSTEM.
func language() -> String:
	return _language


## BattlePace.Speed.
func battle_speed() -> int:
	return _battle_speed


func hit_flash() -> bool:
	return _hit_flash


## Percent, one of ApplicationUiScale.PERCENTS.
func ui_scale() -> int:
	return _ui_scale


## BattlePace.AfterKnockout.
func after_knockout() -> int:
	return _after_knockout


## 目标提示 (ObjectiveHints): the status card's 目标 row and the toasts' 下一步.
func objective_hints() -> bool:
	return _objective_hints


## 昼夜 (DayNightPreference.Value): how the voxel view is lit.
func day_night() -> int:
	return _day_night


## 自动存档提示 (AutosaveNotice): the 已自动存档 line.
func autosave_notice() -> bool:
	return _autosave_notice


## ApplicationWindowSize.AUTO or one of its RESOLUTIONS.
func resolution() -> Vector2i:
	return _resolution


## The monitor's index, or NO_SCREEN.
func master_volume() -> int:
	return _master_volume


func screen() -> int:
	return _screen


## 战斗开场动画 (BattlePace.Opening).
func battle_opening() -> int:
	return _battle_opening


## 画质 (GraphicsQuality.Value).
func graphics_quality() -> int:
	return _graphics_quality


## The slow-frame hint (DECISIONS「画质」) has been told.
func quality_hint_told() -> bool:
	return _quality_hint_told


## 切出窗口时暂停 (DECISIONS「切出窗口」): the window losing its focus pauses the game.
func pause_on_focus_loss() -> bool:
	return _pause_on_focus_loss


func with_pause_on_focus_loss(paused: bool) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, _language, _battle_speed, _hit_flash, _ui_scale, _after_knockout, _objective_hints, _day_night, _autosave_notice, _resolution, _screen, _master_volume, _battle_opening, _graphics_quality, _quality_hint_told, paused)


func with_graphics_quality(quality: int) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, _language, _battle_speed, _hit_flash, _ui_scale, _after_knockout, _objective_hints, _day_night, _autosave_notice, _resolution, _screen, _master_volume, _battle_opening, quality, _quality_hint_told, _pause_on_focus_loss)


func with_quality_hint_told(told: bool) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, _language, _battle_speed, _hit_flash, _ui_scale, _after_knockout, _objective_hints, _day_night, _autosave_notice, _resolution, _screen, _master_volume, _battle_opening, _graphics_quality, told, _pause_on_focus_loss)


func with_battle_opening(choice: int) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, _language, _battle_speed, _hit_flash, _ui_scale, _after_knockout, _objective_hints, _day_night, _autosave_notice, _resolution, _screen, _master_volume, choice, _graphics_quality, _quality_hint_told, _pause_on_focus_loss)


func with_display(mode: int, resolution: Vector2i, screen: int) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, mode, _language, _battle_speed, _hit_flash, _ui_scale, _after_knockout, _objective_hints, _day_night, _autosave_notice, resolution, screen, _master_volume, _battle_opening, _graphics_quality, _quality_hint_told, _pause_on_focus_loss)


func with_window_mode(mode: int) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, mode, _language, _battle_speed, _hit_flash, _ui_scale, _after_knockout, _objective_hints, _day_night, _autosave_notice, _resolution, _screen, _master_volume, _battle_opening, _graphics_quality, _quality_hint_told, _pause_on_focus_loss)


func with_language(language: String) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, language, _battle_speed, _hit_flash, _ui_scale, _after_knockout, _objective_hints, _day_night, _autosave_notice, _resolution, _screen, _master_volume, _battle_opening, _graphics_quality, _quality_hint_told, _pause_on_focus_loss)


func with_battle(speed: int, flash: bool, after_knockout: int) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, _language, speed, flash, _ui_scale, after_knockout, _objective_hints, _day_night, _autosave_notice, _resolution, _screen, _master_volume, _battle_opening, _graphics_quality, _quality_hint_told, _pause_on_focus_loss)


func with_ui_scale(percent: int) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, _language, _battle_speed, _hit_flash, percent, _after_knockout, _objective_hints, _day_night, _autosave_notice, _resolution, _screen, _master_volume, _battle_opening, _graphics_quality, _quality_hint_told, _pause_on_focus_loss)


func with_objective_hints(shown: bool) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, _language, _battle_speed, _hit_flash, _ui_scale, _after_knockout, shown, _day_night, _autosave_notice, _resolution, _screen, _master_volume, _battle_opening, _graphics_quality, _quality_hint_told, _pause_on_focus_loss)


func with_day_night(mode: int) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, _language, _battle_speed, _hit_flash, _ui_scale, _after_knockout, _objective_hints, mode, _autosave_notice, _resolution, _screen, _master_volume, _battle_opening, _graphics_quality, _quality_hint_told, _pause_on_focus_loss)


## 总音量 (DECISIONS「战斗拍数 C」): 0–100, the Master bus.
func with_master_volume(percent: int) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, _language, _battle_speed, _hit_flash, _ui_scale, _after_knockout, _objective_hints, _day_night, _autosave_notice, _resolution, _screen, percent, _battle_opening, _graphics_quality, _quality_hint_told, _pause_on_focus_loss)


func with_autosave_notice(shown: bool) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, _language, _battle_speed, _hit_flash, _ui_scale, _after_knockout, _objective_hints, _day_night, shown, _resolution, _screen, _master_volume, _battle_opening, _graphics_quality, _quality_hint_told, _pause_on_focus_loss)


func is_valid() -> bool:
	return (
		_version == SCHEMA_VERSION
		and ApplicationWindowMode.is_valid(_window_mode)
		and BattlePace.is_valid(_battle_speed)
		and BattlePace.is_valid_knockout(_after_knockout)
		and ApplicationUiScale.is_valid(_ui_scale)
		and DayNightPreference.is_valid(_day_night)
		and ApplicationWindowSize.is_valid(_resolution)
		and _screen >= NO_SCREEN
		and _master_volume >= 0 and _master_volume <= 100
		and BattlePace.is_valid_opening(_battle_opening)
		and GraphicsQuality.is_valid(_graphics_quality)
	)


static func defaults() -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new()
