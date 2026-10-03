class_name StudyResult
extends RefCounted

## One study (cmds/std/study.c), in its order of checks.
enum Outcome {
	IN_COMBAT,
	NOTHING_TO_LEARN,
	ILLITERATE,
	COMBAT_EXPERIENCE_TOO_LOW,
	VALID_LEARN_REJECTED,
	## No valid_learn() rule for the skill, or one the game cannot evaluate.
	VALID_LEARN_UNAVAILABLE,
	TOO_TIRED,
	TOO_SHALLOW,
	## The cost came out negative: receive_damage() raises an error before any change.
	LEGACY_NEGATIVE_COST,
	STUDIED,
}

var outcome: int
var skill_id: StringName
var sen_cost: int
var skill_learn_policy_result: SkillLearnPolicyResult
var skill_improvement: SkillImprovementResult
var authored_effect: SkillImprovementEffectResult


func _init(p_outcome: int = Outcome.NOTHING_TO_LEARN, p_skill_id: StringName = &"") -> void:
	outcome = p_outcome
	skill_id = p_skill_id
