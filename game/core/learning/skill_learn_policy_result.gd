class_name SkillLearnPolicyResult
extends RefCounted

enum Status {
	ALLOWED,
	REJECTED,
	DEPENDENCY_UNAVAILABLE,
}

var status: int


func _init(p_status: int = Status.DEPENDENCY_UNAVAILABLE) -> void:
	status = p_status
