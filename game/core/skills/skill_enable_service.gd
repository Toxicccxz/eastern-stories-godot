class_name SkillEnableService
extends RefCounted

## cmds/std/enable.c on a character: SkillEnableTransition's checks and mapping,
## then the internal power the use resets. enable.c resets it on every enable
## for force, magic or spells, also when the same skill is enabled again;
## receive_damage(x, 0) after it changes nothing.


## enable <use> <skill>.
static func enable(character: CharacterState, definition: SkillDefinition, use_id: StringName) -> SkillMappingChangeResult:
	var result: SkillMappingChangeResult = SkillEnableTransition.try_enable(character.skills, definition, use_id)
	if not result.applied:
		return result
	match result.internal_resource_reset:
		SkillMappingChangeResult.InternalResourceReset.INNER_FORCE:
			character.recovery.inner_force.current = 0
		SkillMappingChangeResult.InternalResourceReset.ATMAN:
			character.recovery.atman.current = 0
		SkillMappingChangeResult.InternalResourceReset.MANA:
			character.recovery.mana.current = 0
	return result


## enable <use> none: map_skill(use) clears the use whether or not it was mapped,
## and leaves skills, progress and internal power as they are.
static func disable(character: CharacterState, use_id: StringName) -> bool:
	if not SkillUseIds.is_enable_command_use(use_id):
		return false
	character.skills.unmap_skill(use_id)
	return true
