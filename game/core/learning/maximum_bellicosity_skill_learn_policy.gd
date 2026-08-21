class_name MaximumBellicositySkillLearnPolicy
extends "res://core/learning/skill_learn_policy.gd"

var maximum_bellicosity: int


func _init(p_skill_id: StringName = &"", p_maximum: int = 0) -> void:
	super(p_skill_id)
	maximum_bellicosity = p_maximum


func evaluate(student: CharacterStateType) -> PolicyResultType:
	var actual: int = student.attributes.bellicosity
	if actual > maximum_bellicosity:
		return PolicyResultType.new(
			PolicyResultType.Status.REJECTED,
			PolicyResultType.Reason.BELLICOSITY_TOO_HIGH,
			&"bellicosity",
			actual,
			maximum_bellicosity,
		)
	return PolicyResultType.new(PolicyResultType.Status.ALLOWED)
