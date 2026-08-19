class_name RecoverySkillLevelsAdapter
extends RefCounted

const CharacterSkillStateType := preload("res://core/skills/character_skill_state.gd")
const RecoverySkillLevelsType := preload(
	"res://core/characters/recovery_skill_levels.gd"
)
const SkillIdsType := preload("res://core/skills/skill_ids.gd")


## Produces the narrow Phase 2A input from raw levels. CharacterRecovery keeps
## no dependency on CharacterSkillState, enabled mappings, or definitions.
static func create_snapshot(skills: CharacterSkillStateType) -> RecoverySkillLevelsType:
	return RecoverySkillLevelsType.new(
		skills.raw_level(SkillIdsType.MAGIC),
		skills.raw_level(SkillIdsType.FORCE),
		skills.raw_level(SkillIdsType.SPELLS),
	)

