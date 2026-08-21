class_name StrengthForceSkillLearnPolicy
extends "res://core/learning/skill_learn_policy.gd"

var minimum_combined_value: int
var inner_force_divisor: int


func _init(
	p_skill_id: StringName = &"",
	p_minimum_combined_value: int = 0,
	p_inner_force_divisor: int = 10,
) -> void:
	super(p_skill_id)
	minimum_combined_value = p_minimum_combined_value
	inner_force_divisor = p_inner_force_divisor


func evaluate(student: CharacterStateType) -> PolicyResultType:
	@warning_ignore("integer_division")
	var actual: int = (
		student.attributes.strength
		+ student.recovery.inner_force.maximum / inner_force_divisor
	)
	if actual < minimum_combined_value:
		return PolicyResultType.new(
			PolicyResultType.Status.REJECTED,
			PolicyResultType.Reason.STRENGTH_AND_INNER_FORCE_TOO_LOW,
			&"str+max_force/10",
			actual,
			minimum_combined_value,
		)
	return PolicyResultType.new(PolicyResultType.Status.ALLOWED)
