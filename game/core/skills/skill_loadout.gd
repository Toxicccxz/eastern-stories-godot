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


## Read-only persistence projection. Callers receive stable IDs rather than
## the mutable mapping itself.
func enabled_use_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_enabled_skills.keys())
	result.sort_custom(_string_name_less_than)
	return result


static func _string_name_less_than(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)
