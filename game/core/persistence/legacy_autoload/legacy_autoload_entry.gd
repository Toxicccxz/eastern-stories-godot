class_name LegacyAutoloadEntry
extends RefCounted

var _legacy_program_path: String
var _has_parameter: bool
var _parameter: String

var legacy_program_path: String:
	get: return _legacy_program_path
var has_parameter: bool:
	get: return _has_parameter
var parameter: String:
	get: return _parameter


func _init(
	p_legacy_program_path: String = "",
	p_has_parameter: bool = false,
	p_parameter: String = "",
) -> void:
	_legacy_program_path = p_legacy_program_path
	_has_parameter = p_has_parameter
	_parameter = p_parameter


func duplicate_snapshot() -> LegacyAutoloadEntry:
	return LegacyAutoloadEntry.new(
		_legacy_program_path,
		_has_parameter,
		_parameter,
	)
