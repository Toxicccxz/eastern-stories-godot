class_name CharacterInternalResourceState
extends RefCounted

## One ES2 internal resource pair. CharacterRecoveryState composes three
## instances for legacy force/max_force, mana/max_mana, and atman/max_atman.
##
## Unlike gin/kee/sen, these resources have no effective tier. Legacy training
## can also put current above maximum, so current is intentionally not clamped.

var current: int = 0
var _maximum: int = 0

var maximum: int:
	get:
		return _maximum
	set(value):
		if value < 0:
			assert(false, "Maximum internal resource value cannot be negative.")
			return
		_maximum = value


func _init(p_current: int = 0, p_maximum: int = 0) -> void:
	if p_maximum < 0:
		assert(false, "Maximum internal resource value cannot be negative.")
		return
	current = p_current
	_maximum = p_maximum


func has_valid_invariants() -> bool:
	return _maximum >= 0
