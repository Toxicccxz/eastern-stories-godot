class_name ApplicationSettingsSnapshot
extends RefCounted

## Version 2 adds the language; a version 1 file reads as following the system language.
## Version 3 adds the 战斗速度 and 受击闪红 (DECISIONS「手感」); older files read as 标准, on.
## Version 4 adds 无边框全屏 and the 界面缩放; an older "fullscreen" reads as 无边框全屏
## (what it showed), and the scale as 100%.
## Version 5 adds 击倒后 (DECISIONS「了结 / 放过」); an older file reads as 询问.
## Version 6 adds 目标提示 (DECISIONS「新手链与当前目标」); an older file reads as on.
## Version 7 adds 昼夜 (DECISIONS「昼夜」); an older file reads as 跟随游戏时间.
const SCHEMA_VERSION: int = 7

var _version: int
var _window_mode: int
var _language: String
var _battle_speed: int
var _hit_flash: bool
var _ui_scale: int
var _after_knockout: int
var _objective_hints: bool
var _day_night: int


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


func with_window_mode(mode: int) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, mode, _language, _battle_speed, _hit_flash, _ui_scale, _after_knockout, _objective_hints, _day_night)


func with_language(language: String) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, language, _battle_speed, _hit_flash, _ui_scale, _after_knockout, _objective_hints, _day_night)


func with_battle(speed: int, flash: bool, after_knockout: int) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, _language, speed, flash, _ui_scale, after_knockout, _objective_hints, _day_night)


func with_ui_scale(percent: int) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, _language, _battle_speed, _hit_flash, percent, _after_knockout, _objective_hints, _day_night)


func with_objective_hints(shown: bool) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, _language, _battle_speed, _hit_flash, _ui_scale, _after_knockout, shown, _day_night)


func with_day_night(mode: int) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, _language, _battle_speed, _hit_flash, _ui_scale, _after_knockout, _objective_hints, mode)


func is_valid() -> bool:
	return (
		_version == SCHEMA_VERSION
		and ApplicationWindowMode.is_valid(_window_mode)
		and BattlePace.is_valid(_battle_speed)
		and BattlePace.is_valid_knockout(_after_knockout)
		and ApplicationUiScale.is_valid(_ui_scale)
		and DayNightPreference.is_valid(_day_night)
	)


static func defaults() -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new()
