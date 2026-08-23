class_name RequiredGenderSkillLearnPolicy
extends "res://core/learning/skill_learn_policy.gd"

var required_gender: StringName


func _init(
	p_skill_id: StringName = &"",
	p_required_gender: StringName = &"",
) -> void:
	super(p_skill_id)
	required_gender = p_required_gender


## Legacy valid_learn() hooks compare the persistent value using
## exact LPC string equality. No human/animal or absent/custom normalization.
func evaluate(student: CharacterStateType) -> PolicyResultType:
	if student.gender != required_gender:
		return PolicyResultType.new(
			PolicyResultType.Status.REJECTED,
			PolicyResultType.Reason.GENDER_MISMATCH,
			&"gender",
			0,
			0,
			student.gender,
			required_gender,
		)
	return PolicyResultType.new(PolicyResultType.Status.ALLOWED)
