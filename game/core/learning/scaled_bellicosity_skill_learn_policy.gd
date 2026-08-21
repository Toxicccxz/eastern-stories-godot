class_name ScaledBellicositySkillLearnPolicy
extends "res://core/learning/skill_learn_policy.gd"

var effective_skill_id: StringName
var bellicosity_per_level: int


func _init(
	p_skill_id: StringName = &"",
	p_effective_skill_id: StringName = &"",
	p_bellicosity_per_level: int = 0,
) -> void:
	super(p_skill_id)
	effective_skill_id = p_effective_skill_id
	bellicosity_per_level = p_bellicosity_per_level


func evaluate(student: CharacterStateType) -> PolicyResultType:
	var required: int = (
		student.skills.effective_level(effective_skill_id) * bellicosity_per_level
	)
	var actual: int = student.attributes.bellicosity
	if actual < required:
		return PolicyResultType.new(
			PolicyResultType.Status.REJECTED,
			PolicyResultType.Reason.BELLICOSITY_TOO_LOW,
			effective_skill_id,
			actual,
			required,
		)
	return PolicyResultType.new(PolicyResultType.Status.ALLOWED)
