class_name SkillEnableTransition
extends RefCounted

const CharacterSkillStateType := preload("res://core/skills/character_skill_state.gd")
const SkillDefinitionType := preload("res://core/skills/skill_definition.gd")
const SkillMappingChangeResultType := preload(
	"res://core/skills/skill_mapping_change_result.gd"
)
const SkillUseIdsType := preload("res://core/skills/skill_use_ids.gd")


## Pure domain part of cmds/std/enable.c. It omits command text and action
## rebuilding, and exposes resource-reset ownership as a typed result rather
## than coupling skill state to CharacterRecoveryState.
static func try_enable(
	skills: CharacterSkillStateType,
	definition: SkillDefinitionType,
	use_id: StringName,
) -> SkillMappingChangeResultType:
	if not SkillUseIdsType.is_enable_command_use(use_id):
		return SkillMappingChangeResultType.new()
	if definition.skill_id == use_id:
		return SkillMappingChangeResultType.new()
	if skills.raw_level(definition.skill_id) == 0:
		return SkillMappingChangeResultType.new()
	if skills.raw_level(use_id) == 0:
		return SkillMappingChangeResultType.new()
	if not definition.can_enable_for(use_id):
		return SkillMappingChangeResultType.new()
	if not skills.map_skill(use_id, definition.skill_id):
		return SkillMappingChangeResultType.new()

	return SkillMappingChangeResultType.new(true, _resource_reset_for(use_id))


static func _resource_reset_for(use_id: StringName) -> int:
	if use_id == SkillUseIdsType.MAGIC:
		return SkillMappingChangeResultType.InternalResourceReset.ATMAN
	if use_id == SkillUseIdsType.FORCE:
		return SkillMappingChangeResultType.InternalResourceReset.INNER_FORCE
	if use_id == SkillUseIdsType.SPELLS:
		return SkillMappingChangeResultType.InternalResourceReset.MANA
	return SkillMappingChangeResultType.InternalResourceReset.NONE
