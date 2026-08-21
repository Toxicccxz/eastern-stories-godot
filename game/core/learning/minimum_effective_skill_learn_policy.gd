class_name MinimumEffectiveSkillLearnPolicy
extends "res://core/learning/skill_learn_policy.gd"

var prerequisite_skill_id: StringName
var minimum_effective_level: int


func _init(
	p_skill_id: StringName = &"",
	p_prerequisite_skill_id: StringName = &"",
	p_minimum_effective_level: int = 0,
) -> void:
	super(p_skill_id)
	prerequisite_skill_id = p_prerequisite_skill_id
	minimum_effective_level = p_minimum_effective_level


func evaluate(student: CharacterStateType) -> PolicyResultType:
	var actual: int = student.skills.effective_level(prerequisite_skill_id)
	if actual < minimum_effective_level:
		return PolicyResultType.new(
			PolicyResultType.Status.REJECTED,
			PolicyResultType.Reason.EFFECTIVE_SKILL_TOO_LOW,
			prerequisite_skill_id,
			actual,
			minimum_effective_level,
		)
	return PolicyResultType.new(PolicyResultType.Status.ALLOWED)
