class_name ApplicationSettingsSnapshot
extends RefCounted

## Version 2 adds the language; a version 1 file reads as following the system language.
const SCHEMA_VERSION: int = 2

var _version: int
var _window_mode: int
var _language: String


func _init(
	p_version: int = SCHEMA_VERSION,
	p_window_mode: int = ApplicationWindowMode.Value.WINDOWED,
	p_language: String = LocalizationService.FOLLOW_SYSTEM,
) -> void:
	_version = p_version
	_window_mode = p_window_mode
	_language = p_language


func version() -> int:
	return _version


func window_mode() -> int:
	return _window_mode


## A language code from languages.json, or LocalizationService.FOLLOW_SYSTEM.
func language() -> String:
	return _language


func with_window_mode(mode: int) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, mode, _language)


func with_language(language: String) -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new(_version, _window_mode, language)


func is_valid() -> bool:
	return _version == SCHEMA_VERSION and ApplicationWindowMode.is_valid(_window_mode)


static func defaults() -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new()
