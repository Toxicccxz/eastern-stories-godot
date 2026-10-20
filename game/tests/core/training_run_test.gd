extends RefCounted

## Continuous training's core (DECISIONS「连续修炼」): LearnPreview reads what learn.c would
## do and agrees with LearnService.learn() over a seeded matrix of students and teachers,
## changing nothing; CultivationService's preview agrees with the real command and changes
## nothing; PracticeService.weak_progress_full(); TrainingRun's stops; the run's lines.

const TEACHER_ID: StringName = &"teacher.liu_chunfeng"
const FAMILY_ID: StringName = &"family.fonxan"
const TEACHER_NAME: String = "柳淳风"

var _count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_learn_preview_agrees_with_learn()
	_test_learn_preview_wastes()
	_test_cultivation_preview()
	_test_weak_progress_full()
	_test_stops()
	_test_run_lines()
	return {"assertions": _count, "failures": _failures}


## 400 seeded cases: the preview's failure and completion are learn()'s (PROGRESSED for
## both of learn()'s progress outcomes), and the preview leaves student and teacher as
## they were (no zero entry, no gin, no sen, no potential).
func _test_learn_preview_agrees_with_learn() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 20261019
	var mismatches: Array[String] = []
	var changed: Array[String] = []
	var seen: Dictionary[String, bool] = {}
	for case: int in 400:
		var facts: Dictionary = _draw_facts(random)
		var looked: CharacterState = _student(facts)
		var looked_context: TeachingContext = _context(facts)
		var preview: LearnResult = LearnPreview.next(looked, looked_context, _skill(facts), _policy(facts))
		var before: String = _state_text(looked, looked_context)
		if before != _state_text(_student(facts), _context(facts)):
			changed.append(str(facts))
		var learned: CharacterState = _student(facts)
		var context: TeachingContext = _context(facts)
		var result: LearnResult = LearnService.learn(learned, context, _skill(facts), _policy(facts))
		var completion: int = result.completion
		if completion == LearnResult.Completion.LEVEL_INCREASED:
			completion = LearnResult.Completion.PROGRESSED
		if preview.failure_reason != result.failure_reason or preview.completion != completion:
			mismatches.append("%s: preview %d/%d, learn %d/%d" % [facts, preview.failure_reason, preview.completion, result.failure_reason, result.completion])
		seen["%d/%d" % [result.failure_reason, completion]] = true
		if LearnPreview.wastes(preview) != (completion in [LearnResult.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE, LearnResult.Completion.NO_PROGRESS_COMBAT_EXPERIENCE] and result.failure_reason == LearnResult.FailureReason.NONE):
			mismatches.append("%s: wastes()" % facts)
	_check(mismatches.is_empty(), "LearnPreview agrees with learn(): %s" % [mismatches.slice(0, 3)])
	_check(changed.is_empty(), "LearnPreview changes nothing: %s" % [changed.slice(0, 3)])
	# The matrix reaches the outcomes that matter here.
	for outcome: String in [
		"%d/%d" % [LearnResult.FailureReason.NONE, LearnResult.Completion.PROGRESSED],
		"%d/%d" % [LearnResult.FailureReason.NONE, LearnResult.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE],
		"%d/%d" % [LearnResult.FailureReason.NONE, LearnResult.Completion.NO_PROGRESS_COMBAT_EXPERIENCE],
		"%d/%d" % [LearnResult.FailureReason.POTENTIAL_EXHAUSTED, LearnResult.Completion.NONE],
		"%d/%d" % [LearnResult.FailureReason.TEACHER_PREVENTED, LearnResult.Completion.NONE],
		"%d/%d" % [LearnResult.FailureReason.STUDENT_SKILL_NOT_BELOW_TEACHER, LearnResult.Completion.NONE],
		"%d/%d" % [LearnResult.FailureReason.TEACHER_TOO_TIRED, LearnResult.Completion.NO_PROGRESS_TEACHER_FATIGUE],
		"%d/%d" % [LearnResult.FailureReason.SKILL_LEARN_REJECTED, LearnResult.Completion.NONE],
		"%d/%d" % [LearnResult.FailureReason.RECOGNITION_REJECTED, LearnResult.Completion.NONE],
	]:
		_check(seen.has(outcome), "the matrix reaches %s (seen %s)" % [outcome, seen.keys()])


func _test_learn_preview_wastes() -> void:
	# gin 13 with a cost of 30 (150/10 + 150/10): learn.c would take all 13 for nothing.
	var facts: Dictionary = _plain_facts()
	facts.essence = 13
	var student: CharacterState = _student(facts)
	var preview: LearnResult = LearnPreview.next(student, _context(facts), _skill(facts), _policy(facts))
	_check(LearnPreview.wastes(preview) and preview.calculated_essence_cost == 30 and preview.essence_before == 13 and student.essence.current == 13, "gin not above the cost wastes: %d" % preview.calculated_essence_cost)
	var run := TrainingRun.new(TrainingRun.Kind.LEARN, &"sword", student)
	_check(run.look_at_learn(preview, 100) == TrainingRun.Stop.WASTE_ESSENCE and run.cost == 30 and run.have == 13, "WASTE_ESSENCE with its numbers")
	# Level 10 needs 10^3/10 = 100 combat_exp: 99 learns nothing and spends gin.
	facts = _plain_facts()
	facts.exp = 99
	preview = LearnPreview.next(_student(facts), _context(facts), _skill(facts), _policy(facts))
	run = TrainingRun.new(TrainingRun.Kind.LEARN, &"sword", _student(facts))
	_check(run.look_at_learn(preview, 99) == TrainingRun.Stop.WASTE_EXPERIENCE and run.required == 100 and run.have == 99, "WASTE_EXPERIENCE: level 10 needs 100")
	facts.exp = 100
	preview = LearnPreview.next(_student(facts), _context(facts), _skill(facts), _policy(facts))
	_check(run.look_at_learn(preview, 100) == TrainingRun.Stop.NONE and preview.completion == LearnResult.Completion.PROGRESSED, "100 learns")
	# A knowledge skill has no experience gate (learn.c checks martial skills only).
	facts.exp = 0
	facts.knowledge = true
	preview = LearnPreview.next(_student(facts), _context(facts), _skill(facts), _policy(facts))
	_check(not LearnPreview.wastes(preview), "knowledge skills skip the gate")
	_check(LearnService.required_combat_experience(31) == 2979, "31^3 / 10 = 2979")


func _test_cultivation_preview() -> void:
	for kind: TrainingRun.Kind in [TrainingRun.Kind.EXERCISE, TrainingRun.Kind.MEDITATE, TrainingRun.Kind.RESPIRATE]:
		# [current, maximum, raw skill, amount] -> what the step would do.
		for case: Array in [[50, 100, 20, 30], [199, 100, 20, 30], [199, 200, 20, 30], [200, 200, 20, 300], [10, 100, 0, 10], [10, 100, 20, 5000]]:
			var looked: CharacterState = _cultivator(kind, case)
			var preview: CultivationResult = _cultivate(kind, looked, case[3], true)
			var real: CharacterState = _cultivator(kind, case)
			var result: CultivationResult = _cultivate(kind, real, case[3], false)
			var same: bool = (
				preview.failure_reason == result.failure_reason and preview.completion == result.completion
				and preview.internal_after == result.internal_after and preview.maximum_after == result.maximum_after
				and preview.calculated_gain == result.calculated_gain
			)
			_check(same, "%s %s: the preview is the command (%d/%d %d, %d/%d %d)" % [kind, case, preview.failure_reason, preview.completion, preview.internal_after, result.failure_reason, result.completion, result.internal_after])
			_check(_cultivation_text(looked) == _cultivation_text(_cultivator(kind, case)), "%s %s: the preview changes nothing" % [kind, case])
	# The stops the look ahead gives.
	var run := TrainingRun.new(TrainingRun.Kind.EXERCISE, &"", CharacterState.new())
	var poor: CharacterState = _cultivator(TrainingRun.Kind.EXERCISE, [10, 100, 0, 10])
	_check(run.look_at_cultivation(_cultivate(TrainingRun.Kind.EXERCISE, poor, 10, true)) == TrainingRun.Stop.NO_GAIN, "10 kee with force 0 and con 20: 200/300 = 0, NO_GAIN")
	var capped: CharacterState = _cultivator(TrainingRun.Kind.EXERCISE, [400, 200, 10, 30])
	_check(run.look_at_cultivation(_cultivate(TrainingRun.Kind.EXERCISE, capped, 30, true)) == TrainingRun.Stop.BOTTLENECK and run.have == 200, "at the bottleneck with force at twice the maximum: BOTTLENECK")
	var low: CharacterState = _cultivator(TrainingRun.Kind.EXERCISE, [10, 200, 10, 300])
	_check(run.look_at_cultivation(_cultivate(TrainingRun.Kind.EXERCISE, low, 300, true)) == TrainingRun.Stop.NONE, "at the cap but below the maximum: the step still raises force")
	var tired: CharacterState = _cultivator(TrainingRun.Kind.EXERCISE, [10, 100, 20, 5000])
	_check(run.look_at_cultivation(_cultivate(TrainingRun.Kind.EXERCISE, tired, 5000, true)) == TrainingRun.Stop.NONE, "a refusal costs nothing: it is taken (its line says why)")


func _test_weak_progress_full() -> void:
	var character := CharacterState.new()
	character.skills.set_raw_level(&"unarmed", 10)
	character.skills.set_raw_level(&"liuh-ken", 10)
	character.skills.map_skill(&"unarmed", &"liuh-ken")
	character.skills.set_learned_progress(&"liuh-ken", 121)
	_check(not PracticeService.weak_progress_full(character, &"unarmed"), "121 = (10 + 1)^2: one more counts")
	character.skills.set_learned_progress(&"liuh-ken", 122)
	_check(PracticeService.weak_progress_full(character, &"unarmed"), "122 > 121 in weak mode: full")
	character.skills.set_raw_level(&"unarmed", 11)
	_check(not PracticeService.weak_progress_full(character, &"unarmed"), "basic above special: not weak mode")
	_check(not PracticeService.weak_progress_full(character, &"sword"), "nothing enabled for the use")


func _test_stops() -> void:
	var learned := LearnResult.new(&"sword")
	learned.completion = LearnResult.Completion.PROGRESSED
	_check(TrainingRun.after_learn(learned) == TrainingRun.Stop.NONE, "progress goes on")
	learned.completion = LearnResult.Completion.LEVEL_INCREASED
	_check(TrainingRun.after_learn(learned) == TrainingRun.Stop.LEVEL_UP, "a level stops")
	learned.failure_reason = LearnResult.FailureReason.POTENTIAL_EXHAUSTED
	_check(TrainingRun.after_learn(learned) == TrainingRun.Stop.REFUSED, "potential spent stops with learn.c's line")
	var practised := PracticeResult.new(true, PracticeResult.FailureReason.NONE, PracticeResult.Completion.PROGRESSED)
	_check(TrainingRun.after_practice(practised) == TrainingRun.Stop.NONE, "practice goes on")
	practised = PracticeResult.new(true, PracticeResult.FailureReason.NONE, PracticeResult.Completion.LEVEL_INCREASED)
	_check(TrainingRun.after_practice(practised) == TrainingRun.Stop.LEVEL_UP, "practice's level stops")
	practised = PracticeResult.new(false, PracticeResult.FailureReason.PRACTICE_FORCE_REJECTED, PracticeResult.Completion.NO_PROGRESS)
	_check(TrainingRun.after_practice(practised) == TrainingRun.Stop.REFUSED, "too little force stops")
	var sat := CultivationResult.new(CultivationResult.Action.EXERCISE, true, CultivationResult.FailureReason.NONE, CultivationResult.Completion.MAXIMUM_INCREASED)
	_check(TrainingRun.after_cultivation(sat) == TrainingRun.Stop.MAXIMUM_UP, "a maximum up stops")
	sat = CultivationResult.new(CultivationResult.Action.EXERCISE, true, CultivationResult.FailureReason.NONE, CultivationResult.Completion.GAINED)
	_check(TrainingRun.after_cultivation(sat) == TrainingRun.Stop.NONE, "a gain goes on")
	sat = CultivationResult.new(CultivationResult.Action.EXERCISE, false, CultivationResult.FailureReason.INSUFFICIENT_VITALITY)
	_check(TrainingRun.after_cultivation(sat) == TrainingRun.Stop.REFUSED, "too little kee stops")
	var run := TrainingRun.new(TrainingRun.Kind.EXERCISE, &"", CharacterState.new())
	for step: int in TrainingRun.MAX_STEPS:
		run.took_step(CharacterState.new())
	_check(run.stop == TrainingRun.Stop.LIMIT and run.steps == TrainingRun.MAX_STEPS, "a guard of %d steps" % TrainingRun.MAX_STEPS)
	run.end(TrainingRun.Stop.CANCELLED)
	_check(run.stop == TrainingRun.Stop.LIMIT, "the first stop stays")


func _test_run_lines() -> void:
	var sword := SkillDefinition.new(&"sword", SkillDefinition.Kind.BASIC, SkillDefinition.Type.MARTIAL)
	sword.display_name = "基本剑法"
	var student: CharacterState = _student(_plain_facts())
	var run := TrainingRun.new(TrainingRun.Kind.LEARN, &"sword", student)
	student.essence.current -= 96
	student.progression.potential_spent += 12
	student.skills.set_raw_level(&"sword", 12)
	var level_up: Array[ColoredLine] = [ColoredLine.new("你的「基本剑法」进步了！", ColoredLine.HIC)]
	run.took_step(student, level_up)
	run.end(TrainingRun.Stop.LEVEL_UP)
	var lines: Array[ColoredLine] = TrainingLines.run(run, sword, TEACHER_NAME)
	_check(ColoredLine.texts(lines) == ["你向柳淳风请教「基本剑法」1 次：基本剑法 10→12 级，精 -96，潜能 -12。", "你的「基本剑法」进步了！"], "the summary, then the level: %s" % [ColoredLine.texts(lines)])
	_check(lines[1].color == ColoredLine.HIC, "the level's line keeps its colour")
	run = TrainingRun.new(TrainingRun.Kind.LEARN, &"sword", student)
	run.cost = 30
	run.have = 13
	run.end(TrainingRun.Stop.WASTE_ESSENCE)
	_check(ColoredLine.texts(TrainingLines.run(run, sword, TEACHER_NAME)) == ["停下：精不够了。请教一次耗精 30，精须多于此数（你还有 13）；再请教只会白白累垮，先休息吧。"], "no step: only why")
	run = TrainingRun.new(TrainingRun.Kind.LEARN, &"sword", student)
	run.required = 2979
	run.have = 1000
	run.after = TrainingRun.Snapshot.of(student, &"sword")
	run.end(TrainingRun.Stop.WASTE_EXPERIENCE)
	_check(ColoredLine.texts(TrainingLines.run(run, sword, TEACHER_NAME)) == ["停下：实战经验不足。「基本剑法」12 级要再学，须实战经验 ≥ 2979（你 1000）。"], "the experience it needs")
	run = TrainingRun.new(TrainingRun.Kind.EXERCISE, &"", student)
	student.vitality.current -= 60
	student.recovery.inner_force.current += 4
	run.took_step(student)
	run.took_step(student)
	run.refused([ColoredLine.new("你现在的气太少了，无法产生内息运行全身经脉。")])
	var force := SkillDefinition.new(&"force", SkillDefinition.Kind.BASIC, SkillDefinition.Type.MARTIAL)
	force.display_name = "基本内功"
	_check(ColoredLine.texts(TrainingLines.run(run, null, "", force, 30)) == ["你打坐 2 次：气 -60，内力 +4。", "你现在的气太少了，无法产生内息运行全身经脉。"], "a refusal ends with its own line: %s" % [ColoredLine.texts(TrainingLines.run(run, null, "", force, 30))])
	run = TrainingRun.new(TrainingRun.Kind.EXERCISE, &"", student)
	run.have = 200
	run.end(TrainingRun.Stop.BOTTLENECK)
	_check(ColoredLine.texts(TrainingLines.run(run, null, "", force, 30)) == ["停下：内力的修为已到瓶颈（上限 200），再打坐，内力只会回落到 200。先提高基本内功吧。"], "the bottleneck")
	run.stop = TrainingRun.Stop.NO_GAIN
	_check(ColoredLine.texts(TrainingLines.run(run, null, "", force, 10)) == ["停下：每次只花 10 点气，打坐不会有任何长进；多花一些再试。"], "no gain")
	run.stop = TrainingRun.Stop.CANCELLED
	_check(ColoredLine.texts(TrainingLines.run(run, null, "", force, 10)) == ["你停了下来。"], "cancelled")


func _draw_facts(random: RandomNumberGenerator) -> Dictionary:
	return {
		"raw": [0, 1, 5, 10, 20, 40][random.randi_range(0, 5)],
		"teacher": [0, 10, 21, 40, 100][random.randi_range(0, 4)],
		"essence": [5, 13, 30, 31, 200][random.randi_range(0, 4)],
		"exp": [0, 99, 100, 800, 7000][random.randi_range(0, 4)],
		"potential_left": [0, 1, 50][random.randi_range(0, 2)],
		"teacher_sen": [1, 7, 100][random.randi_range(0, 2)],
		"betrayer": [0, 0, 1, 2][random.randi_range(0, 3)],
		"direct": random.randi_range(0, 2) > 0,
		"f_master": random.randi_range(0, 1) == 1,
		"recognized": random.randi_range(0, 3) > 0,
		"knowledge": random.randi_range(0, 4) == 0,
		"needs_force": random.randi_range(0, 4) == 0,
		"max_force": [0, 100][random.randi_range(0, 1)],
	}


func _plain_facts() -> Dictionary:
	return {
		"raw": 10, "teacher": 100, "essence": 200, "exp": 1000, "potential_left": 50, "teacher_sen": 100,
		"betrayer": 0, "direct": true, "f_master": true, "recognized": true, "knowledge": false,
		"needs_force": false, "max_force": 0,
	}


func _student(facts: Dictionary) -> CharacterState:
	var student := CharacterState.new()
	for resource: CharacterResourceState in [student.essence, student.vitality, student.spirit]:
		resource.maximum = 200
		resource.effective = 200
		resource.current = 200
	student.essence.current = facts.essence
	student.attributes.intelligence = 10
	student.attributes.spirituality = 30
	student.progression.combat_experience = facts.exp
	student.progression.potential = 100
	student.progression.potential_spent = 100 - int(facts.potential_left)
	student.recovery.inner_force.maximum = facts.max_force
	if facts.direct:
		student.family = FamilyState.new(FAMILY_ID, 14)
		student.apprenticeship = ApprenticeshipState.new(TEACHER_ID, TEACHER_NAME, facts.betrayer)
	else:
		student.family = FamilyState.new(&"family.other", 3)
		student.apprenticeship = ApprenticeshipState.new(&"teacher.other", "别人", facts.betrayer)
	if int(facts.raw) > 0:
		student.skills.set_raw_level(&"sword", facts.raw)
	return student


func _context(facts: Dictionary) -> TeachingContext:
	var context := TeachingContext.new(
		TEACHER_ID, TeachingOffer.new(&"sword"), facts.teacher, 10, facts.teacher_sen, FAMILY_ID, 13, 0,
		TEACHER_NAME, true, true, true, false, false, false, false, 1,
		ExplicitTeacherRecognitionPolicy.new(facts.recognized),
		FMasterTeacherPreventionPolicy.new() if facts.f_master else TeacherPreventionPolicy.new(),
	)
	return context


func _skill(facts: Dictionary) -> SkillDefinition:
	return SkillDefinition.new(&"sword", SkillDefinition.Kind.BASIC, SkillDefinition.Type.KNOWLEDGE if facts.knowledge else SkillDefinition.Type.MARTIAL)


func _policy(facts: Dictionary) -> SkillLearnPolicy:
	if facts.needs_force:
		return MinimumInnerForceSkillLearnPolicy.new(&"sword", 100)
	return DefaultSkillLearnPolicy.new(&"sword")


func _state_text(student: CharacterState, context: TeachingContext) -> String:
	return str([
		student.skills.has_raw_level(&"sword"), student.skills.raw_level(&"sword"), student.skills.learned_progress(&"sword"),
		student.essence.current, student.progression.potential_spent, context.current_spirit,
	])


## [current, maximum, raw skill, amount]: a character whose internal power for `kind` and
## its skill are as given; con, spi 20; every resource full.
func _cultivator(kind: TrainingRun.Kind, case: Array) -> CharacterState:
	var character := CharacterState.new()
	for resource: CharacterResourceState in [character.essence, character.vitality, character.spirit]:
		resource.maximum = 1000
		resource.effective = 1000
		resource.current = 1000
	character.attributes.constitution = 20
	character.attributes.spirituality = 20
	var skill: StringName = {TrainingRun.Kind.EXERCISE: SkillIds.FORCE, TrainingRun.Kind.MEDITATE: SkillIds.SPELLS, TrainingRun.Kind.RESPIRATE: SkillIds.MAGIC}[kind]
	if kind == TrainingRun.Kind.EXERCISE:
		character.skills.set_raw_level(SkillIds.FONXAN_FORCE, 1)
		character.skills.map_skill(SkillIds.FORCE, SkillIds.FONXAN_FORCE)
	if int(case[2]) > 0:
		character.skills.set_raw_level(skill, case[2])
	var power: CharacterInternalResourceState = TrainingProgress._internal_power(character, kind)
	power.current = case[0]
	power.maximum = case[1]
	return character


func _cultivate(kind: TrainingRun.Kind, character: CharacterState, amount: int, preview: bool) -> CultivationResult:
	match kind:
		TrainingRun.Kind.MEDITATE:
			return CultivationService.meditate(character, amount, false, 0, preview)
		TrainingRun.Kind.RESPIRATE:
			return CultivationService.respirate(character, amount, false, 0, preview)
	return CultivationService.exercise(character, amount, false, 0, preview)


func _cultivation_text(character: CharacterState) -> String:
	return str([
		character.essence.current, character.vitality.current, character.spirit.current,
		character.recovery.inner_force.current, character.recovery.inner_force.maximum,
		character.recovery.mana.current, character.recovery.mana.maximum,
		character.recovery.atman.current, character.recovery.atman.maximum,
	])


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("training run: " + label)
