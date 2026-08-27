class_name CombatPerceptionSkillProjection
extends RefCounted

const PERCEPTION_SKILL_ID: StringName = &"perception"

var _skill_id: StringName
var _effective_level: int

var skill_id: StringName:
	get:
		return _skill_id
var effective_level: int:
	get:
		return _effective_level


func _init(
	p_skill_id: StringName = PERCEPTION_SKILL_ID,
	p_effective_level: int = 0,
) -> void:
	_skill_id = p_skill_id
	_effective_level = p_effective_level


func is_valid() -> bool:
	return _skill_id == PERCEPTION_SKILL_ID


func duplicate_snapshot() -> CombatPerceptionSkillProjection:
	return CombatPerceptionSkillProjection.new(_skill_id, _effective_level)

