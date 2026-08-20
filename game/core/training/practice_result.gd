class_name PracticeResult
extends RefCounted

enum FailureReason {
	NONE,
	IN_COMBAT,
	SKILL_NOT_MAPPED,
	SPECIAL_SKILL_NOT_LEARNED,
	BASIC_SKILL_NOT_LEARNED,
	POLICY_NOT_AVAILABLE,
	POLICY_SKILL_MISMATCH,
	VALID_LEARN_REJECTED,
	PRACTICE_HOOK_REJECTED,
}

enum Completion {
	NONE,
	NO_PROGRESS,
	PROGRESSED,
	LEVEL_INCREASED,
}

var success: bool
var failure_reason: int
var completion: int
var basic_skill_id: StringName
var special_skill_id: StringName
var basic_level: int
var special_level_before: int
var special_level_after: int
var improvement_amount: int
var weak_mode: bool
var learned_before: int
var learned_after: int


func _init(
	p_success: bool = false,
	p_failure_reason: int = FailureReason.NONE,
	p_completion: int = Completion.NONE,
	p_basic_skill_id: StringName = &"",
	p_special_skill_id: StringName = &"",
	p_basic_level: int = 0,
	p_special_level_before: int = 0,
	p_special_level_after: int = 0,
	p_improvement_amount: int = 0,
	p_weak_mode: bool = false,
	p_learned_before: int = 0,
	p_learned_after: int = 0,
) -> void:
	success = p_success
	failure_reason = p_failure_reason
	completion = p_completion
	basic_skill_id = p_basic_skill_id
	special_skill_id = p_special_skill_id
	basic_level = p_basic_level
	special_level_before = p_special_level_before
	special_level_after = p_special_level_after
	improvement_amount = p_improvement_amount
	weak_mode = p_weak_mode
	learned_before = p_learned_before
	learned_after = p_learned_after
