class_name BattleResourceProjection
extends RefCounted

## Read-only value snapshot; retains no mutable gameplay authority.
var _current: int
var current: int:
	get: return _current
var _effective: int
var effective: int:
	get: return _effective
var _maximum: int
var maximum: int:
	get: return _maximum


func _init(
	p_current: int = 0,
	p_effective: int = 0,
	p_maximum: int = 0,
) -> void:
	_current = p_current
	_effective = p_effective
	_maximum = p_maximum
