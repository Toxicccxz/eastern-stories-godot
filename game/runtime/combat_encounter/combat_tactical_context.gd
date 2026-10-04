class_name CombatTacticalContext
extends RefCounted

## Exact Core authorities, not a character snapshot or world/controller access.
var _actor: CombatEncounterAuthorityBinding
var _target: CombatEncounterAuthorityBinding
var _mode: int
var _effect_registry: SkillImprovementEffectRegistry
var mode: int:
	get: return _mode
## The encounter's skill_improved() effects (null outside the scheduler).
var effect_registry: SkillImprovementEffectRegistry:
	get: return _effect_registry
var actor: CombatEncounterAuthorityBinding:
	get: return _actor
var target: CombatEncounterAuthorityBinding:
	get: return _target


func _init(
	p_actor: CombatEncounterAuthorityBinding = null,
	p_target: CombatEncounterAuthorityBinding = null,
	p_mode: int = -1,
	p_effect_registry: SkillImprovementEffectRegistry = null,
) -> void:
	_actor = p_actor
	_target = p_target
	_mode = p_mode
	_effect_registry = p_effect_registry
