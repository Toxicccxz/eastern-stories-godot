class_name SkillLoadout
extends RefCounted

## Typed equivalent of the legacy skill_map mapping. The collection is kept
## private and does not provide LPC-style arbitrary property access.
var _enabled_skills: Dictionary[StringName, StringName] = {}


func set_enabled_skill(use_id: StringName, skill_id: StringName) -> void:
	_enabled_skills[use_id] = skill_id


func remove_enabled_skill(use_id: StringName) -> bool:
	return _enabled_skills.erase(use_id)


func has_enabled_skill(use_id: StringName) -> bool:
	return _enabled_skills.has(use_id)


func enabled_skill(use_id: StringName) -> StringName:
	if not _enabled_skills.has(use_id):
		return &""
	return _enabled_skills[use_id]


func clear() -> void:
	_enabled_skills.clear()


func size() -> int:
	return _enabled_skills.size()

