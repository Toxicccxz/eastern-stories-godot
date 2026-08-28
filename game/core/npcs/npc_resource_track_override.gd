class_name NpcResourceTrackOverride
extends RefCounted

var _has_current: bool
var _current: int
var _has_effective: bool
var _effective: int
var _has_maximum: bool
var _maximum: int


func _init(
	p_has_current: bool = false,
	p_current: int = 0,
	p_has_effective: bool = false,
	p_effective: int = 0,
	p_has_maximum: bool = false,
	p_maximum: int = 0,
) -> void:
	_has_current = p_has_current
	_current = p_current
	_has_effective = p_has_effective
	_effective = p_effective
	_has_maximum = p_has_maximum
	_maximum = p_maximum


func has_current() -> bool:
	return _has_current


func current() -> int:
	return _current


func has_effective() -> bool:
	return _has_effective


func effective() -> int:
	return _effective


func has_maximum() -> bool:
	return _has_maximum


func maximum() -> int:
	return _maximum


func is_empty() -> bool:
	return not (_has_current or _has_effective or _has_maximum)


func duplicate_snapshot() -> NpcResourceTrackOverride:
	return NpcResourceTrackOverride.new(
		_has_current,
		_current,
		_has_effective,
		_effective,
		_has_maximum,
		_maximum,
	)
