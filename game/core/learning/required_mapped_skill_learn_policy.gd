class_name RequiredMappedSkillLearnPolicy
extends "res://core/learning/skill_learn_policy.gd"

var use_id: StringName
var required_mapped_skill_id: StringName


func _init(
	p_skill_id: StringName = &"",
	p_use_id: StringName = &"",
	p_required_mapped_skill_id: StringName = &"",
) -> void:
	super(p_skill_id)
	use_id = p_use_id
	required_mapped_skill_id = p_required_mapped_skill_id


func evaluate(student: CharacterStateType) -> PolicyResultType:
	var actual: StringName = student.skills.mapped_skill(use_id)
	if actual != required_mapped_skill_id:
		return PolicyResultType.new(
			PolicyResultType.Status.REJECTED,
			PolicyResultType.Reason.MAPPED_SKILL_MISMATCH,
			use_id,
			0,
			0,
			actual,
			required_mapped_skill_id,
		)
	return PolicyResultType.new(PolicyResultType.Status.ALLOWED)
