class_name RequirePrimaryWeaponSkillTypeSkillLearnPolicy
extends "res://core/learning/skill_learn_policy.gd"

var required_skill_type: StringName


func _init(
	p_skill_id: StringName = &"",
	p_required_skill_type: StringName = &"",
) -> void:
	super(p_skill_id)
	required_skill_type = p_required_skill_type


## The LPC hooks read only query_temp("weapon")->query("skill_type"). A
## secondary-only weapon is neither promoted nor considered for this check.
func evaluate(student: CharacterStateType) -> PolicyResultType:
	if student.equipment.is_primary_hand_empty():
		return PolicyResultType.new(
			PolicyResultType.Status.REJECTED,
			PolicyResultType.Reason.PRIMARY_WEAPON_MISSING,
			&"primary_weapon",
			0,
			0,
			&"",
			required_skill_type,
		)
	var actual_skill_type: StringName = student.equipment.primary_weapon_skill_type()
	if actual_skill_type != required_skill_type:
		return PolicyResultType.new(
			PolicyResultType.Status.REJECTED,
			PolicyResultType.Reason.PRIMARY_WEAPON_SKILL_TYPE_MISMATCH,
			&"primary_weapon_skill_type",
			0,
			0,
			actual_skill_type,
			required_skill_type,
		)
	return PolicyResultType.new(PolicyResultType.Status.ALLOWED)
