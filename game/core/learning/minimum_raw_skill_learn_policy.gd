class_name MinimumRawSkillLearnPolicy
extends "res://core/learning/skill_learn_policy.gd"

var prerequisite_skill_id: StringName
var minimum_raw_level: int


func _init(
	p_skill_id: StringName = &"",
	p_prerequisite_skill_id: StringName = &"",
	p_minimum_raw_level: int = 0,
) -> void:
	super(p_skill_id)
	prerequisite_skill_id = p_prerequisite_skill_id
	minimum_raw_level = p_minimum_raw_level


func evaluate(student: CharacterStateType) -> PolicyResultType:
	var actual: int = student.skills.raw_level(prerequisite_skill_id)
	if actual < minimum_raw_level:
		return PolicyResultType.new(
			PolicyResultType.Status.REJECTED,
			PolicyResultType.Reason.RAW_SKILL_TOO_LOW,
			prerequisite_skill_id,
			actual,
			minimum_raw_level,
		)
	return PolicyResultType.new(PolicyResultType.Status.ALLOWED)
