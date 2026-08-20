class_name SelfLearningResult
extends RefCounted

const SkillImprovementResultType := preload(
	"res://core/skills/skill_improvement_result.gd"
)
const SkillImprovementEffectResultType := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_result.gd"
)

enum FailureReason {
	NONE,
	SKILL_NOT_SELF_LEARNABLE,
	IN_COMBAT,
	RAW_SKILL_BELOW_MINIMUM,
	LEGACY_NON_POSITIVE_INTELLIGENCE,
	POTENTIAL_EXHAUSTED,
	INVALID_IMPROVEMENT_ROLL,
}

enum Completion {
	NONE,
	NO_PROGRESS_INSUFFICIENT_ESSENCE,
	NO_PROGRESS_COMBAT_EXPERIENCE,
	PROGRESSED,
	LEVEL_INCREASED,
}

var success: bool
var failure_reason: int
var completion: int
var skill_id: StringName
var level_before: int
var level_after: int
var essence_cost: int
var essence_spent: int
var improvement_roll: int
var improvement_roll_upper_bound: int
var learned_before: int
var learned_after: int
var potential_spent_before: int
var potential_spent_after: int
var skill_improvement: SkillImprovementResultType
var authored_effect: SkillImprovementEffectResultType


func _init(
	p_success: bool = false,
	p_failure_reason: int = FailureReason.NONE,
	p_completion: int = Completion.NONE,
	p_skill_id: StringName = &"",
	p_level_before: int = 0,
	p_level_after: int = 0,
	p_essence_cost: int = 0,
	p_essence_spent: int = 0,
	p_improvement_roll: int = 0,
	p_improvement_roll_upper_bound: int = 0,
	p_learned_before: int = 0,
	p_learned_after: int = 0,
	p_potential_spent_before: int = 0,
	p_potential_spent_after: int = 0,
	p_skill_improvement: SkillImprovementResultType = null,
	p_authored_effect: SkillImprovementEffectResultType = null,
) -> void:
	success = p_success
	failure_reason = p_failure_reason
	completion = p_completion
	skill_id = p_skill_id
	level_before = p_level_before
	level_after = p_level_after
	essence_cost = p_essence_cost
	essence_spent = p_essence_spent
	improvement_roll = p_improvement_roll
	improvement_roll_upper_bound = p_improvement_roll_upper_bound
	learned_before = p_learned_before
	learned_after = p_learned_after
	potential_spent_before = p_potential_spent_before
	potential_spent_after = p_potential_spent_after
	skill_improvement = p_skill_improvement
	authored_effect = p_authored_effect
