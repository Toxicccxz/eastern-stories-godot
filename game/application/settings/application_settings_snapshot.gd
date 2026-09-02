class_name ApplicationSettingsSnapshot
extends RefCounted

const SCHEMA_VERSION: int = 1

var _version: int
var _window_mode: int


func _init(
	p_version: int = SCHEMA_VERSION,
	p_window_mode: int = ApplicationWindowMode.Value.WINDOWED,
) -> void:
	_version = p_version
	_window_mode = p_window_mode


func version() -> int:
	return _version


func window_mode() -> int:
	return _window_mode


func is_valid() -> bool:
	return _version == SCHEMA_VERSION and ApplicationWindowMode.is_valid(_window_mode)


static func defaults() -> ApplicationSettingsSnapshot:
	return ApplicationSettingsSnapshot.new()
