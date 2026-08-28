class_name NpcSkillLevelDefinition
extends RefCounted

var _skill_id: StringName
var _raw_level: int

var skill_id: StringName:
	get:
		return _skill_id
var raw_level: int:
	get:
		return _raw_level


func _init(p_skill_id: StringName = &"", p_raw_level: int = 0) -> void:
	_skill_id = p_skill_id
	_raw_level = p_raw_level


func is_valid() -> bool:
	return not _skill_id.is_empty()


func duplicate_snapshot() -> NpcSkillLevelDefinition:
	return NpcSkillLevelDefinition.new(_skill_id, _raw_level)
