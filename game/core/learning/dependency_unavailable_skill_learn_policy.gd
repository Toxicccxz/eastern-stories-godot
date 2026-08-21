class_name DependencyUnavailableSkillLearnPolicy
extends "res://core/learning/skill_learn_policy.gd"

var dependency_reason: int


func _init(
	p_skill_id: StringName = &"",
	p_dependency_reason: int = PolicyResultType.Reason.NONE,
) -> void:
	super(p_skill_id)
	dependency_reason = p_dependency_reason


func evaluate(_student: CharacterStateType) -> PolicyResultType:
	return PolicyResultType.new(
		PolicyResultType.Status.DEPENDENCY_UNAVAILABLE,
		dependency_reason,
	)
