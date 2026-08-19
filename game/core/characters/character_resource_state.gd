class_name CharacterResourceState
extends RefCounted

## One ES2 current/effective/maximum resource track. CharacterState composes
## three instances for legacy gin, kee, and sen.
##
## Mutation semantics are translated from:
## reference/es2/mudlib/feature/damage.c

const INCAPACITATED_FLOOR: int = -1

var _current: int = 0
var _effective: int = 0
var _maximum: int = 0

var current: int:
	get:
		return _current
	set(value):
		_current = clampi(value, INCAPACITATED_FLOOR, _effective)

var effective: int:
	get:
		return _effective
	set(value):
		_effective = clampi(value, INCAPACITATED_FLOOR, _maximum)
		_current = clampi(_current, INCAPACITATED_FLOOR, _effective)

var maximum: int:
	get:
		return _maximum
	set(value):
		if value < 0:
			assert(false, "Maximum resource value cannot be negative.")
			return
		_maximum = value
		_effective = clampi(_effective, INCAPACITATED_FLOOR, _maximum)
		_current = clampi(_current, INCAPACITATED_FLOOR, _effective)


func _init(p_current: int = 0, p_effective: int = 0, p_maximum: int = 0) -> void:
	if p_maximum < 0:
		assert(false, "Maximum resource value cannot be negative.")
		return
	_maximum = p_maximum
	_effective = clampi(p_effective, INCAPACITATED_FLOOR, _maximum)
	_current = clampi(p_current, INCAPACITATED_FLOOR, _effective)


## Equivalent to receive_damage(). The legacy function returns the requested
## amount even when the current value saturates at -1, so this method does too.
func apply_damage(amount: int) -> int:
	if not _require_non_negative(amount, "Damage"):
		return 0
	var next_value: int = _current - amount
	_current = next_value if next_value >= 0 else INCAPACITATED_FLOOR
	return amount


## Equivalent to receive_wound(). A wound reduces effective state and clamps
## current state down to the new effective value.
func apply_wound(amount: int) -> int:
	if not _require_non_negative(amount, "Wound damage"):
		return 0
	var next_value: int = _effective - amount
	_effective = next_value if next_value >= 0 else INCAPACITATED_FLOOR
	if _current > _effective:
		_current = _effective
	return amount


## Equivalent to receive_heal(). Healing restores current state only as far as
## effective state and returns the requested amount, matching the LPC API.
func heal(amount: int) -> int:
	if not _require_non_negative(amount, "Healing"):
		return 0
	_current = mini(_current + amount, _effective)
	return amount


## Equivalent to receive_curing(). Curing restores effective state only as far
## as maximum and returns the amount actually applied when capped.
func cure(amount: int) -> int:
	if not _require_non_negative(amount, "Curing"):
		return 0
	if _effective + amount > _maximum:
		var applied: int = _maximum - _effective
		_effective = _maximum
		return applied
	_effective += amount
	return amount


func is_unconscious_threshold_reached() -> bool:
	return _current < 0


func is_death_threshold_reached() -> bool:
	return _effective < 0


func has_valid_invariants() -> bool:
	return (
		_maximum >= 0
		and _effective >= INCAPACITATED_FLOOR
		and _current >= INCAPACITATED_FLOOR
		and _current <= _effective
		and _effective <= _maximum
	)


## LPC error() aborts negative mutations. The explicit false result is also
## required because Godot assertions may be disabled in release builds.
static func _require_non_negative(amount: int, operation: String) -> bool:
	if amount >= 0:
		return true
	assert(false, "%s cannot be negative." % operation)
	return false
