class_name MinimumBaseSpiritualitySkillLearnPolicy
extends "res://core/learning/skill_learn_policy.gd"

var minimum_base_spirituality: int


func _init(p_skill_id: StringName = &"", p_minimum: int = 0) -> void:
	super(p_skill_id)
	minimum_base_spirituality = p_minimum


## daemon/skill/stormdance.c reads persistent base "spi", not an effective
## attribute helper or temporary modifier.
func evaluate(student: CharacterStateType) -> PolicyResultType:
	var actual: int = student.attributes.spirituality
	if actual < minimum_base_spirituality:
		return PolicyResultType.new(
			PolicyResultType.Status.REJECTED,
			PolicyResultType.Reason.BASE_SPIRITUALITY_TOO_LOW,
			&"spi",
			actual,
			minimum_base_spirituality,
		)
	return PolicyResultType.new(PolicyResultType.Status.ALLOWED)
