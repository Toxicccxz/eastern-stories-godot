class_name PracticePolicies
extends RefCounted

const SkillIdsType := preload("res://core/skills/skill_ids.gd")
const VitalityInnerForcePracticePolicyType := preload(
	"res://core/training/vitality_inner_force_practice_policy.gd"
)
const UnpracticeablePracticePolicyType := preload(
	"res://core/training/unpracticeable_practice_policy.gd"
)


## daemon/skill/fall-steps.c
static func create_fall_steps() -> VitalityInnerForcePracticePolicyType:
	return VitalityInnerForcePracticePolicyType.new(
		SkillIdsType.FALL_STEPS,
		30,
		30,
		3,
		3,
	)


## daemon/skill/fonxanforce.c
static func create_fonxan_force() -> UnpracticeablePracticePolicyType:
	return UnpracticeablePracticePolicyType.new(SkillIdsType.FONXAN_FORCE)
