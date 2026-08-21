class_name SkillLearnPolicyResult
extends RefCounted

enum Status {
	ALLOWED,
	REJECTED,
	DEPENDENCY_UNAVAILABLE,
}

enum Reason {
	NONE,
	MAXIMUM_INNER_FORCE_TOO_LOW,
	BELLICOSITY_TOO_HIGH,
	BELLICOSITY_TOO_LOW,
	STRENGTH_AND_INNER_FORCE_TOO_LOW,
	MAXIMUM_MANA_TOO_LOW,
	RAW_SKILL_TOO_LOW,
	EFFECTIVE_SKILL_TOO_LOW,
	MAPPED_SKILL_MISMATCH,
	GENDER_STATE_UNAVAILABLE,
	EQUIPMENT_STATE_UNAVAILABLE,
	LEGACY_REQUIRED_SKILL_MISSING,
}

var status: int
var reason: int
var subject_id: StringName
var actual_value: int
var required_value: int
var actual_id: StringName
var required_id: StringName


func _init(
	p_status: int = Status.DEPENDENCY_UNAVAILABLE,
	p_reason: int = Reason.NONE,
	p_subject_id: StringName = &"",
	p_actual_value: int = 0,
	p_required_value: int = 0,
	p_actual_id: StringName = &"",
	p_required_id: StringName = &"",
) -> void:
	status = p_status
	reason = p_reason
	subject_id = p_subject_id
	actual_value = p_actual_value
	required_value = p_required_value
	actual_id = p_actual_id
	required_id = p_required_id
