class_name SkillMappingChangeResult
extends RefCounted

enum InternalResourceReset {
	NONE,
	ATMAN,
	INNER_FORCE,
	MANA,
}

## Why enable.c refused, in its order of checks.
enum Failure {
	NONE,
	## 没有这个技能种类
	NOT_A_USE,
	## 「X」是所有Y的基础，不需要 enable。 (enable.c writes it and returns 1)
	BASIC_OF_ITSELF,
	## 你不会这种技能。
	SKILL_NOT_KNOWN,
	## 你连「X」都没学会，更别提Y了。
	USE_NOT_KNOWN,
	## 这个技能不能当成这种用途。
	INVALID_USE,
	## feature/skill.c map_skill() refused (no raw entry); unreachable after the checks.
	MAPPING_REJECTED,
}

var applied: bool
var internal_resource_reset: int
var failure: int


func _init(
	p_applied: bool = false,
	p_internal_resource_reset: int = InternalResourceReset.NONE,
	p_failure: int = Failure.NONE,
) -> void:
	applied = p_applied
	internal_resource_reset = p_internal_resource_reset
	failure = p_failure
