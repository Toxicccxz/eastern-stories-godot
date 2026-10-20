class_name LearnQuote
extends RefCounted

## How far a teacher can take the student in a skill, and why not further (owner,
## 2026-10-19; DECISIONS「上限预览和拜师条件」): learn.c's level-bound checks walked up from
## the student's level, in learn.c's order, nothing changed — prevent_learn() (master.c:
## betrayal, 20 levels each; not a direct apprentice, a third of the teacher's level), the
## teacher's own level, valid_learn() (each skill's learn policy, asked as if at that
## level) and the martial experience gate (level³/10). `now` is what one more learn would
## do (LearnPreview). The ceiling is the level the student can reach; -1 when this teacher
## does not teach them at all (recognition, asleep, out of reach …).

enum Bound { NONE, TEACHER, BETRAYAL, NOT_DIRECT, POLICY, EXPERIENCE }

## What one more learn would do now.
var now: LearnResult
var level: int = 0
var ceiling: int = -1
var bound: Bound = Bound.NONE
## The teacher's level, and the student's betrayals (BETRAYAL's numbers).
var teacher_level: int = 0
var betrayals: int = 0
## valid_learn()'s refusal at the ceiling (POLICY).
var policy_result: SkillLearnPolicyResult
## The combat_exp the ceiling's level needs (EXPERIENCE), and the student's.
var required_experience: int = 0
var experience: int = 0


## The failures that say the teacher does not teach this student this skill at all.
const NOT_TAUGHT: Array[LearnResult.FailureReason] = [
	LearnResult.FailureReason.STUDENT_FIGHTING, LearnResult.FailureReason.TEACHER_UNAVAILABLE,
	LearnResult.FailureReason.TEACHER_NOT_CHARACTER, LearnResult.FailureReason.TEACHER_ASLEEP,
	LearnResult.FailureReason.RECOGNITION_POLICY_ABSENT, LearnResult.FailureReason.RECOGNITION_REJECTED,
	LearnResult.FailureReason.RECOGNITION_DEPENDENCY_UNAVAILABLE, LearnResult.FailureReason.TEACHER_SKILL_ZERO,
	LearnResult.FailureReason.PREVENTION_DEPENDENCY_UNAVAILABLE, LearnResult.FailureReason.SKILL_DEFINITION_MISMATCH,
	LearnResult.FailureReason.SKILL_POLICY_MISMATCH, LearnResult.FailureReason.SKILL_LEARN_DEPENDENCY_UNAVAILABLE,
]


## `context`'s recognition policy may draw: build it apart from the world's random
## source, as for LearnPreview.
static func of(student: CharacterState, context: TeachingContext, skill: SkillDefinition, policy: SkillLearnPolicy) -> LearnQuote:
	var quote := LearnQuote.new()
	quote.now = LearnPreview.next(student, context, skill, policy)
	var skill_id: StringName = context.offer.skill_id
	quote.level = student.skills.raw_level(skill_id)
	quote.teacher_level = context.teacher_raw_level
	quote.betrayals = student.apprenticeship.betrayer_count
	quote.experience = student.progression.combat_experience
	if quote.now.failure_reason in NOT_TAUGHT or quote.now.completion == LearnResult.Completion.LEGACY_ERROR:
		return quote
	for at: int in range(quote.level, maxi(quote.level, quote.teacher_level)):
		var prevention: TeacherPolicyResult = context.prevention_policy.evaluate(student, context, at)
		if prevention.status == TeacherPolicyResult.Status.REJECTED:
			# master.c checks the betrayals first, then whether the student is its own.
			var betrayed: bool = quote.betrayals != 0 and at >= quote.teacher_level - quote.betrayals * 20
			return quote._stop(at, Bound.BETRAYAL if betrayed else Bound.NOT_DIRECT)
		var allowed: SkillLearnPolicyResult = student.skills.probe_raw_level(skill_id, at, policy.evaluate.bind(student))
		if allowed.status != SkillLearnPolicyResult.Status.ALLOWED:
			quote.policy_result = allowed
			return quote._stop(at, Bound.POLICY)
		if skill.skill_type == SkillDefinition.Type.MARTIAL:
			var required: int = LearnService.required_combat_experience(at)
			if required > quote.experience:
				quote.required_experience = required
				return quote._stop(at, Bound.EXPERIENCE)
	return quote._stop(maxi(quote.level, quote.teacher_level), Bound.TEACHER)


func _stop(at: int, why: Bound) -> LearnQuote:
	ceiling = at
	bound = why
	return self


## The teacher takes the student some way in this skill.
func taught() -> bool:
	return ceiling >= 0
