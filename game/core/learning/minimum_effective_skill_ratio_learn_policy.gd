class_name MinimumEffectiveSkillRatioLearnPolicy
extends "res://core/learning/skill_learn_policy.gd"

var prerequisite_skill_id: StringName
var target_skill_id: StringName
var target_divisor: int


func _init(
	p_skill_id: StringName = &"",
	p_prerequisite_skill_id: StringName = &"",
	p_target_skill_id: StringName = &"",
	p_target_divisor: int = 1,
) -> void:
	super(p_skill_id)
	prerequisite_skill_id = p_prerequisite_skill_id
	target_skill_id = p_target_skill_id
	target_divisor = p_target_divisor


func evaluate(student: CharacterStateType) -> PolicyResultType:
	var actual: int = student.skills.effective_level(prerequisite_skill_id)
	@warning_ignore("integer_division")
	var required: int = student.skills.effective_level(target_skill_id) / target_divisor
	if actual < required:
		return PolicyResultType.new(
			PolicyResultType.Status.REJECTED,
			PolicyResultType.Reason.EFFECTIVE_SKILL_TOO_LOW,
			prerequisite_skill_id,
			actual,
			required,
		)
	return PolicyResultType.new(PolicyResultType.Status.ALLOWED)
