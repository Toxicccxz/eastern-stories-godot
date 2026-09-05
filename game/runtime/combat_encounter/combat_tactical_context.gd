class_name CombatTacticalContext
extends RefCounted

## Exact Core authorities, not a character snapshot or world/controller access.
var _actor: CombatEncounterAuthorityBinding
var _target: CombatEncounterAuthorityBinding
var actor: CombatEncounterAuthorityBinding:
	get: return _actor
var target: CombatEncounterAuthorityBinding:
	get: return _target


func _init(
	p_actor: CombatEncounterAuthorityBinding = null,
	p_target: CombatEncounterAuthorityBinding = null,
) -> void:
	_actor = p_actor
	_target = p_target
