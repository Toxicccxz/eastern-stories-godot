class_name SkillDeathPenaltyChange
extends RefCounted

## One skill touched by feature/skill.c skill_death_penalty(): either its
## learning progress was wiped (level kept) or it lost a level.
var skill_id: StringName
var level_before: int
## -1 when the skill fell below level 0 and was deleted.
var level_after: int
var progress_cleared: bool


func _init(p_skill_id: StringName, p_level_before: int, p_level_after: int, p_progress_cleared: bool) -> void:
	skill_id = p_skill_id
	level_before = p_level_before
	level_after = p_level_after
	progress_cleared = p_progress_cleared
