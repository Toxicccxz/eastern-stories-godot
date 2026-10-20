extends RefCounted

## How far a teacher can take a skill (LearnQuote; DECISIONS「上限预览和拜师条件」): each of
## learn.c's level-bound checks as the ceiling (the teacher's level, a betrayal's 20
## levels, a third of the level for one not the teacher's own, valid_learn() asked at each
## level, the experience gate), the probe leaving the student as it was, and the lines.

const TEACHER_ID: StringName = &"teacher.liu_chunfeng"
const FAMILY_ID: StringName = &"family.fonxan"
const TEACHER_NAME: String = "柳淳风"

var _count: int = 0
var _failures: Array[String] = []
var _sword: SkillDefinition


func run_all() -> Dictionary[String, Variant]:
	_sword = SkillDefinition.new(&"sword", SkillDefinition.Kind.BASIC, SkillDefinition.Type.MARTIAL)
	_sword.display_name = "基本剑法"
	_test_ceilings()
	_test_probe_changes_nothing()
	_test_lines()
	_test_cultivation_caps()
	return {"assertions": _count, "failures": _failures}


func _test_ceilings() -> void:
	var quote: LearnQuote = _quote(_student(10, 100000), 60)
	_check(quote.ceiling == 60 and quote.bound == LearnQuote.Bound.TEACHER, "the teacher's own level: %d %d" % [quote.ceiling, quote.bound])
	var betrayer: CharacterState = _student(10, 100000)
	betrayer.apprenticeship = ApprenticeshipState.new(TEACHER_ID, TEACHER_NAME, 1)
	quote = _quote(betrayer, 60, true)
	_check(quote.ceiling == 40 and quote.bound == LearnQuote.Bound.BETRAYAL, "one betrayal: 60 - 20 = 40: %d %d" % [quote.ceiling, quote.bound])
	var stranger: CharacterState = _student(10, 100000)
	stranger.apprenticeship = ApprenticeshipState.new(&"teacher.other", "别人", 0)
	quote = _quote(stranger, 60, true)
	# master.c: refused once 60 <= 3 * level, so 19 is the last learnt at and 20 is reached.
	_check(quote.ceiling == 20 and quote.bound == LearnQuote.Bound.NOT_DIRECT, "not his own: a third of 60: %d %d" % [quote.ceiling, quote.bound])
	# 21^3/10 = 926 <= 1000 < 1064 = 22^3/10.
	quote = _quote(_student(10, 1000), 60)
	_check(quote.ceiling == 22 and quote.bound == LearnQuote.Bound.EXPERIENCE and quote.required_experience == 1064, "combat_exp 1000: 22, it needs 1064: %d %d" % [quote.ceiling, quote.required_experience])
	var knowledge := SkillDefinition.new(&"sword", SkillDefinition.Kind.BASIC, SkillDefinition.Type.KNOWLEDGE)
	quote = LearnQuote.of(_student(10, 0), _context(60), knowledge, DefaultSkillLearnPolicy.new(&"sword"))
	_check(quote.ceiling == 60 and quote.bound == LearnQuote.Bound.TEACHER, "a knowledge skill has no experience gate")
	# celestial.c-like: bellicosity 500 at 50 a level of effective sword (raw / 2): 21 learns, 22 does not.
	var fierce: CharacterState = _student(10, 100000)
	fierce.attributes.bellicosity = 500
	quote = LearnQuote.of(fierce, _context(60), _sword, ScaledBellicositySkillLearnPolicy.new(&"sword", &"sword", 50))
	_check(quote.ceiling == 22 and quote.bound == LearnQuote.Bound.POLICY and quote.policy_result != null, "valid_learn() asked at each level: %d %d" % [quote.ceiling, quote.bound])
	quote = _quote(_student(60, 100000), 60)
	_check(quote.ceiling == 60 and quote.level == 60 and quote.bound == LearnQuote.Bound.TEACHER, "at the teacher's level")
	var context: TeachingContext = _context(60)
	context.recognition_policy = ExplicitTeacherRecognitionPolicy.new(false)
	quote = LearnQuote.of(stranger, context, _sword, DefaultSkillLearnPolicy.new(&"sword"))
	_check(not quote.taught() and quote.now.failure_reason == LearnResult.FailureReason.RECOGNITION_REJECTED, "not recognized: not taught")


func _test_probe_changes_nothing() -> void:
	var fresh: CharacterState = _student(0, 100000)
	fresh.attributes.bellicosity = 500
	var quote: LearnQuote = LearnQuote.of(fresh, _context(60), _sword, ScaledBellicositySkillLearnPolicy.new(&"sword", &"sword", 50))
	_check(quote.ceiling == 22 and not fresh.skills.has_raw_level(&"sword") and not fresh.skills.has_skills_mapping(), "a skill not begun stays without an entry, the mapping flag as it was")
	var known: CharacterState = _student(10, 100000)
	LearnQuote.of(known, _context(60), _sword, ScaledBellicositySkillLearnPolicy.new(&"sword", &"sword", 50))
	_check(known.skills.raw_level(&"sword") == 10 and known.skills.raw_skill_ids() == [&"sword"], "a skill begun keeps its level")


func _test_lines() -> void:
	var expected: Dictionary[String, Variant] = {
		"还能学到 60 级（柳淳风自己是 60 级）。": _quote(_student(10, 100000), 60),
		"还能学到 22 级（22 级要再学，须实战经验 ≥ 1064）。": _quote(_student(10, 1000), 60),
		"学不了：经验不足，要再学须实战经验 ≥ 100（你 99）。": _quote(_student(10, 99), 60),
		"学不了：你已学到柳淳风的 60 级。": _quote(_student(60, 100000), 60),
	}
	var betrayer: CharacterState = _student(10, 100000)
	betrayer.apprenticeship = ApprenticeshipState.new(TEACHER_ID, TEACHER_NAME, 2)
	expected["还能学到 20 级（背叛师门 2 次，柳淳风只教到 60 - 20×2 = 20 级）。"] = _quote(betrayer, 60, true)
	var stranger: CharacterState = _student(10, 100000)
	stranger.apprenticeship = ApprenticeshipState.new(&"teacher.other", "别人", 0)
	expected["还能学到 20 级（不是柳淳风的嫡传弟子，只学得到柳淳风等级（60）的三分之一左右）。"] = _quote(stranger, 60, true)
	var beyond: CharacterState = _student(25, 100000)
	beyond.apprenticeship = ApprenticeshipState.new(TEACHER_ID, TEACHER_NAME, 2)
	expected["学不了：背叛师门 2 次，柳淳风能教你的都教了。"] = _quote(beyond, 60, true)
	var spent: CharacterState = _student(10, 100000)
	spent.progression.potential_spent = spent.progression.potential
	expected["还能学到 60 级（柳淳风自己是 60 级）；潜能已经用完。"] = _quote(spent, 60)
	var tired: CharacterState = _student(10, 100000)
	tired.essence.current = 30
	expected["还能学到 60 级（柳淳风自己是 60 级）；精不够：每次耗精 30，精须多于此数。"] = _quote(tired, 60)
	var context: TeachingContext = _context(60)
	context.recognition_policy = ExplicitTeacherRecognitionPolicy.new(false)
	expected["学不了：柳淳风不肯指点你。"] = LearnQuote.of(stranger, context, _sword, DefaultSkillLearnPolicy.new(&"sword"))
	for line: String in expected:
		var got: String = LearnLines.quote_line(expected[line], TEACHER_NAME, _sword)
		_check(got == line, "%s, not %s" % [line, got])


func _test_cultivation_caps() -> void:
	var character := CharacterState.new()
	character.skills.set_raw_level(SkillIds.FORCE, 20)
	character.skills.set_raw_level(SkillIds.FONXAN_FORCE, 15)
	character.skills.map_skill(SkillIds.FORCE, SkillIds.FONXAN_FORCE)
	# (20 + (10 + 15 + 5) / 5) * 10 with apply/force 5.
	_check(CultivationService.exercise_cap(character, 5) == 260, "exercise.c's cap: %d" % CultivationService.exercise_cap(character, 5))
	character.skills.set_raw_level(SkillIds.SPELLS, 7)
	character.skills.set_raw_level(SkillIds.MAGIC, 3)
	_check(CultivationService.meditate_cap(character) == 70 and CultivationService.respirate_cap(character) == 30, "meditate.c's and respirate.c's caps")


func _quote(student: CharacterState, teacher_level: int, f_master: bool = false) -> LearnQuote:
	var context: TeachingContext = _context(teacher_level)
	if f_master:
		context.prevention_policy = FMasterTeacherPreventionPolicy.new()
	return LearnQuote.of(student, context, _sword, DefaultSkillLearnPolicy.new(&"sword"))


func _student(level: int, experience: int) -> CharacterState:
	var student := CharacterState.new()
	for resource: CharacterResourceState in [student.essence, student.vitality, student.spirit]:
		resource.maximum = 200
		resource.effective = 200
		resource.current = 200
	student.attributes.intelligence = 10
	student.progression.combat_experience = experience
	student.progression.potential = 100
	student.family = FamilyState.new(FAMILY_ID, 14)
	student.apprenticeship = ApprenticeshipState.new(TEACHER_ID, TEACHER_NAME, 0)
	if level > 0:
		student.skills.set_raw_level(&"sword", level)
	return student


func _context(teacher_level: int) -> TeachingContext:
	return TeachingContext.new(
		TEACHER_ID, TeachingOffer.new(&"sword"), teacher_level, 10, 100, FAMILY_ID, 13, 0,
		TEACHER_NAME, true, true, true, false, false, false, false, 1,
		ExplicitTeacherRecognitionPolicy.new(true), TeacherPreventionPolicy.new(),
	)


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("learn quote: " + label)
