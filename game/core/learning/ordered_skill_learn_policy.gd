class_name OrderedSkillLearnPolicy
extends "res://core/learning/skill_learn_policy.gd"

var _steps: Array[SkillLearnPolicy] = []


func _init(
	p_skill_id: StringName = &"",
	p_steps: Array[SkillLearnPolicy] = [],
) -> void:
	super(p_skill_id)
	_steps = p_steps.duplicate()


func evaluate(student: CharacterStateType) -> PolicyResultType:
	for step: SkillLearnPolicy in _steps:
		var result: PolicyResultType = step.evaluate(student)
		if result.status != PolicyResultType.Status.ALLOWED:
			return result
	return PolicyResultType.new(PolicyResultType.Status.ALLOWED)
