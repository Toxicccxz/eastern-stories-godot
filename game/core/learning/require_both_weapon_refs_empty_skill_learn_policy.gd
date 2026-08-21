class_name RequireBothWeaponRefsEmptySkillLearnPolicy
extends "res://core/learning/skill_learn_policy.gd"


## LPC valid_learn() checks both query_temp("weapon") and
## query_temp("secondary_weapon"). Armor and inventory do not participate.
func evaluate(student: CharacterStateType) -> PolicyResultType:
	if not student.equipment.are_both_hands_empty():
		return PolicyResultType.new(
			PolicyResultType.Status.REJECTED,
			PolicyResultType.Reason.WEAPON_REFERENCES_NOT_EMPTY,
			&"weapon_references",
		)
	return PolicyResultType.new(PolicyResultType.Status.ALLOWED)
