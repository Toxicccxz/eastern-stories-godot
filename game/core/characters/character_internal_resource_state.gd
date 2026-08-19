class_name CharacterInternalResourceState
extends RefCounted

## One ES2 internal resource pair. CharacterRecoveryState composes three
## instances for legacy force/max_force, mana/max_mana, and atman/max_atman.
##
## Unlike gin/kee/sen, these resources have no effective tier. Legacy training
## can put current above maximum, while generic dbase writes can assign any int
## to either field, so Phase 2A intentionally adds no range clamp.

var current: int = 0
var maximum: int = 0


func _init(p_current: int = 0, p_maximum: int = 0) -> void:
	current = p_current
	maximum = p_maximum
