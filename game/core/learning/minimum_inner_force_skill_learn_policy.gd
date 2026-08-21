class_name MinimumInnerForceSkillLearnPolicy
extends "res://core/learning/skill_learn_policy.gd"

var minimum_maximum_inner_force: int


func _init(p_skill_id: StringName = &"", p_minimum: int = 0) -> void:
	super(p_skill_id)
	minimum_maximum_inner_force = p_minimum


## Representative authored valid_learn() shape from daemon/skill/chaos-steps.c.
func evaluate(student: CharacterStateType) -> PolicyResultType:
	var actual: int = student.recovery.inner_force.maximum
	if actual < minimum_maximum_inner_force:
		return PolicyResultType.new(
			PolicyResultType.Status.REJECTED,
			PolicyResultType.Reason.MAXIMUM_INNER_FORCE_TOO_LOW,
			&"max_force",
			actual,
			minimum_maximum_inner_force,
		)
	return PolicyResultType.new(PolicyResultType.Status.ALLOWED)
