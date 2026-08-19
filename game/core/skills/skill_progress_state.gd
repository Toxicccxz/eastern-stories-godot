class_name SkillProgressState
extends RefCounted

## Snapshot of the two separate legacy mappings for one skill. Presence is
## explicit because a defined raw/learned entry may legitimately contain zero.
var has_raw_level: bool
var raw_level: int
var has_learned_progress: bool
var learned_progress: int


func _init(
	p_has_raw_level: bool = false,
	p_raw_level: int = 0,
	p_has_learned_progress: bool = false,
	p_learned_progress: int = 0,
) -> void:
	has_raw_level = p_has_raw_level
	raw_level = p_raw_level
	has_learned_progress = p_has_learned_progress
	learned_progress = p_learned_progress

