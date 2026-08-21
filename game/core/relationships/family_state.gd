class_name FamilyState
extends RefCounted

## Stable native family IDs are StringName values. The empty ID is reserved
## for no family; display names remain authored presentation metadata.
var family_id: StringName
var generation: int


func _init(p_family_id: StringName = &"", p_generation: int = 0) -> void:
	family_id = p_family_id
	generation = p_generation


func has_family() -> bool:
	return family_id != &""
