class_name LearnResult
extends RefCounted

const SkillImprovementResultType := preload(
	"res://core/skills/skill_improvement_result.gd"
)
const EffectResultType := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_result.gd"
)

enum FailureReason {
	NONE,
	STUDENT_FIGHTING,
	TEACHER_UNAVAILABLE,
	TEACHER_NOT_CHARACTER,
	TEACHER_ASLEEP,
	RECOGNITION_POLICY_ABSENT,
	RECOGNITION_REJECTED,
	RECOGNITION_DEPENDENCY_UNAVAILABLE,
	TEACHER_SKILL_ZERO,
	TEACHER_PREVENTED,
	PREVENTION_DEPENDENCY_UNAVAILABLE,
	STUDENT_SKILL_NOT_BELOW_TEACHER,
	SKILL_DEFINITION_MISMATCH,
	SKILL_POLICY_MISMATCH,
	SKILL_LEARN_REJECTED,
	SKILL_LEARN_DEPENDENCY_UNAVAILABLE,
	LEGACY_TEACHER_INTELLIGENCE_DIVISION_BY_ZERO,
	LEGACY_STUDENT_INTELLIGENCE_DIVISION_BY_ZERO,
	POTENTIAL_EXHAUSTED,
	TEACHING_TEMPORARILY_DISABLED,
	TEACHER_TOO_TIRED,
	LEGACY_NEGATIVE_TEACHER_SPIRIT_DAMAGE,
	LEGACY_RANDOM_DENOMINATOR_DIVISION_BY_ZERO,
	LEGACY_NON_POSITIVE_RANDOM_BOUND,
	INVALID_DETERMINISTIC_ROLL,
	LEGACY_NEGATIVE_STUDENT_ESSENCE_DAMAGE,
}

enum Completion {
	NONE,
	NO_PROGRESS_TEACHER_FATIGUE,
	NO_PROGRESS_INSUFFICIENT_ESSENCE,
	NO_PROGRESS_COMBAT_EXPERIENCE,
	PROGRESSED,
	LEVEL_INCREASED,
	LEGACY_ERROR,
}

enum RelationshipAdmission {
	NONE,
	LEARN_PRIVATE_DIRECT,
	SPOUSE_EXEMPTION,
	SAME_FAMILY_FULL_PRIVILEGE,
	AUTHORED_RECOGNITION,
}

var success: bool = false
var failure_reason: int = FailureReason.NONE
var completion: int = Completion.NONE
var relationship_admission: int = RelationshipAdmission.NONE
var skill_id: StringName

var student_raw_before: int = 0
var student_raw_after: int = 0
var learned_before: int = 0
var learned_after: int = 0
var potential_spent_before: int = 0
var potential_spent_after: int = 0
var essence_before: int = 0
var essence_after: int = 0
var teacher_spirit_before: int = 0
var teacher_spirit_after: int = 0

var calculated_essence_cost: int = 0
var actual_essence_cost: int = 0
var teacher_spirit_cost: int = 0
var required_combat_experience: int = 0
var random_upper_bound: int = 0
var deterministic_improvement_roll: int = 0
var student_had_raw_entry_before: bool = false
var wrote_explicit_zero_skill_entry: bool = false
var created_explicit_zero_skill_entry: bool = false

var skill_improvement: SkillImprovementResultType
var authored_effect: EffectResultType


func _init(p_skill_id: StringName = &"") -> void:
	skill_id = p_skill_id
