class_name CultivationResult
extends RefCounted

enum Action {
	EXERCISE,
	MEDITATE,
	RESPIRATE,
}

enum FailureReason {
	NONE,
	IN_COMBAT,
	FORCE_STYLE_NOT_ENABLED,
	COST_BELOW_MINIMUM,
	INSUFFICIENT_ESSENCE,
	INSUFFICIENT_VITALITY,
	INSUFFICIENT_SPIRIT,
	ESSENCE_BELOW_HEALTH_THRESHOLD,
	VITALITY_BELOW_HEALTH_THRESHOLD,
	SPIRIT_BELOW_HEALTH_THRESHOLD,
	LEGACY_ZERO_MAXIMUM_ESSENCE_DIVISOR,
	LEGACY_ZERO_MAXIMUM_VITALITY_DIVISOR,
	LEGACY_ZERO_MAXIMUM_SPIRIT_DIVISOR,
}

enum Completion {
	NONE,
	NO_GAIN,
	GAINED,
	MAXIMUM_INCREASED,
	SKILL_CAP_REACHED,
}

var action: int
var success: bool
var failure_reason: int
var completion: int
var requested_cost: int
var source_spent: int
var calculated_gain: int
var internal_before: int
var internal_after: int
var maximum_before: int
var maximum_after: int


func _init(
	p_action: int = Action.EXERCISE,
	p_success: bool = false,
	p_failure_reason: int = FailureReason.NONE,
	p_completion: int = Completion.NONE,
	p_requested_cost: int = 0,
	p_source_spent: int = 0,
	p_calculated_gain: int = 0,
	p_internal_before: int = 0,
	p_internal_after: int = 0,
	p_maximum_before: int = 0,
	p_maximum_after: int = 0,
) -> void:
	action = p_action
	success = p_success
	failure_reason = p_failure_reason
	completion = p_completion
	requested_cost = p_requested_cost
	source_spent = p_source_spent
	calculated_gain = p_calculated_gain
	internal_before = p_internal_before
	internal_after = p_internal_after
	maximum_before = p_maximum_before
	maximum_after = p_maximum_after
