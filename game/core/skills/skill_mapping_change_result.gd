class_name SkillMappingChangeResult
extends RefCounted

enum InternalResourceReset {
	NONE,
	ATMAN,
	INNER_FORCE,
	MANA,
}

var applied: bool
var internal_resource_reset: int


func _init(
	p_applied: bool = false,
	p_internal_resource_reset: int = InternalResourceReset.NONE,
) -> void:
	applied = p_applied
	internal_resource_reset = p_internal_resource_reset

