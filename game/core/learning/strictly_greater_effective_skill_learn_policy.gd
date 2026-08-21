class_name StrictlyGreaterEffectiveSkillLearnPolicy
extends "res://core/learning/skill_learn_policy.gd"

var prerequisite_skill_id: StringName
var target_skill_id: StringName


func _init(
	p_skill_id: StringName = &"",
	p_prerequisite_skill_id: StringName = &"",
	p_target_skill_id: StringName = &"",
) -> void:
	super(p_skill_id)
	prerequisite_skill_id = p_prerequisite_skill_id
	target_skill_id = p_target_skill_id


func evaluate(student: CharacterStateType) -> PolicyResultType:
	var actual: int = student.skills.effective_level(prerequisite_skill_id)
	var required: int = student.skills.effective_level(target_skill_id)
	if actual <= required:
		return PolicyResultType.new(
			PolicyResultType.Status.REJECTED,
			PolicyResultType.Reason.EFFECTIVE_SKILL_TOO_LOW,
			prerequisite_skill_id,
			actual,
			required,
		)
	return PolicyResultType.new(PolicyResultType.Status.ALLOWED)
