class_name ApplicationSettingsSnapshot
extends RefCounted

## Version 2 adds the language; a version 1 file reads as following the system language.
## Version 3 adds the 战斗速度 and 受击闪红 (DECISIONS「手感」); older files read as 标准, on.
const SCHEMA_VERSION: int = 3

var _version: int
var _window_mode: int
var _language: String
var _battle_speed: int
var _hit_flash: bool


func _init(
	p_version: int = SCHEMA_VERSION,
	p_window_mode: int = ApplicationWindowMode.Value.WINDOWED,
	p_language: String = LocalizationService.FOLLOW_SYSTEM,
	p_battle_speed: int = BattlePace.Speed.NORMAL,
	p_hit_flash: bool = true,
) -> void:
	_version = p_version
	_window_mode = p_window_mode
	_language = p_language
	_battle_speed = p_battle_speed
	_hit_flash = p_hit_flash


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


func with_window_mode(mode: int) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, mode, _language, _battle_speed, _hit_flash)


func with_language(language: String) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, language, _battle_speed, _hit_flash)


func with_battle(speed: int, flash: bool) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, _language, speed, flash)


func is_valid() -> bool:
	return _version == SCHEMA_VERSION and ApplicationWindowMode.is_valid(_window_mode) and BattlePace.is_valid(_battle_speed)


static func defaults() -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new()
