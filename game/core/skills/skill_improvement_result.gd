class_name SkillImprovementResult
extends RefCounted

## Typed outcome of feature/skill.c::improve_skill(). Authored callbacks are
## deliberately processed outside CharacterSkillState.
var skill_id: StringName
var previous_level: int
var current_level: int
var leveled_up: bool
var learned_before: int
var learned_after: int


func _init(
	p_skill_id: StringName = &"",
	p_previous_level: int = 0,
	p_current_level: int = 0,
	p_leveled_up: bool = false,
	p_learned_before: int = 0,
	p_learned_after: int = 0,
) -> void:
	skill_id = p_skill_id
	previous_level = p_previous_level
	current_level = p_current_level
	leveled_up = p_leveled_up
	learned_before = p_learned_before
	learned_after = p_learned_after
