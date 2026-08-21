class_name TeacherPolicyResult
extends RefCounted

enum Status {
	NO_ADDITIONAL_POLICY,
	ALLOWED,
	REJECTED,
	DEPENDENCY_UNAVAILABLE,
}

var status: int


func _init(p_status: int = Status.NO_ADDITIONAL_POLICY) -> void:
	status = p_status
