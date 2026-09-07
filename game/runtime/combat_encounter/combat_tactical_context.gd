class_name CombatTacticalContext
extends RefCounted

## Exact Core authorities, not a character snapshot or world/controller access.
var _actor: CombatEncounterAuthorityBinding
var _target: CombatEncounterAuthorityBinding
var _mode: int
var mode: int:
	get: return _mode
var actor: CombatEncounterAuthorityBinding:
	get: return _actor
var target: CombatEncounterAuthorityBinding:
	get: return _target


func _init(
	p_actor: CombatEncounterAuthorityBinding = null,
	p_target: CombatEncounterAuthorityBinding = null,
	p_mode: int = -1,
) -> void:
	_actor = p_actor
	_target = p_target
	_mode = p_mode
