class_name ApprenticeshipState
extends RefCounted

## Native master identity uses a stable TeacherId StringName. The legacy
## master name is retained only because feature/apprentice.c checks it in a
## second, non-generation-based direct-apprentice predicate.
var master_teacher_id: StringName
var legacy_master_name: String
var betrayer_count: int


func _init(
	p_master_teacher_id: StringName = &"",
	p_legacy_master_name: String = "",
	p_betrayer_count: int = 0,
) -> void:
	master_teacher_id = p_master_teacher_id
	legacy_master_name = p_legacy_master_name
	betrayer_count = p_betrayer_count


func has_master() -> bool:
	return master_teacher_id != &""
