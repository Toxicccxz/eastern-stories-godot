class_name LearnLines
extends RefCounted

## What cmds/std/learn.c (with std/char/master.c prevent_learn() and
## feature/skill.c improve_skill()) prints to the student for one LearnResult.
## `context` is the request's (NpcTeacher.context()).

# TRANSLATORS: learn.c: {npc} is the teacher, {skill} the skill asked about.
const ASKED: String = "你向{npc}请教有关「{skill}」的疑问。"


## In the shown language; `teacher` and `respect` are as authored.
static func lines(result: LearnResult, teacher: String, skill: SkillDefinition, student: CharacterState, context: TeachingContext, respect: String) -> Array[String]:
	return ColoredLine.texts(colored(result, teacher, skill, student, context, respect))


## The lines with the colours ES2 prints them in (improve_skill()'s is HIC).
static func colored(result: LearnResult, teacher: String, skill: SkillDefinition, student: CharacterState, context: TeachingContext, respect: String) -> Array[ColoredLine]:
	var out: Array[ColoredLine] = []
	for line: String in _plain_lines(result, teacher, skill, student, context, respect):
		out.append(ColoredLine.new(line))
	if result.failure_reason == LearnResult.FailureReason.NONE:
		out.append_array(TrainingLines.improved(result.skill_improvement, result.authored_effect, skill))
	return out


static func _plain_lines(result: LearnResult, teacher: String, skill: SkillDefinition, student: CharacterState, context: TeachingContext, respect: String) -> Array[String]:
	var policy: NpcRecognitionPolicy = context.recognition_policy as NpcRecognitionPolicy
	var out: Array[String] = []
	var npc: String = _t(teacher)
	var asked: Dictionary = {"npc": npc, "skill": _t(skill.display_name)}
	match result.failure_reason:
		LearnResult.FailureReason.NONE:
			pass
		LearnResult.FailureReason.STUDENT_FIGHTING:
			return [_t("临阵磨枪？来不及啦。")]
		LearnResult.FailureReason.TEACHER_UNAVAILABLE, LearnResult.FailureReason.TEACHER_NOT_CHARACTER:
			return [_t("你要向谁求教？")]
		LearnResult.FailureReason.TEACHER_ASLEEP:
			return [_t("嗯....你得先把%s弄醒再说。") % npc]
		LearnResult.FailureReason.RECOGNITION_POLICY_ABSENT, LearnResult.FailureReason.RECOGNITION_REJECTED:
			var rule: NpcTeaching.RecognizeRule = null if policy == null else policy.matched_rule
			if rule != null:
				for line: NpcLine in rule.lines:
					out.append(line.sentence(teacher, respect))
			if rule != null and not rule.fail.is_empty():
				out.append(_t(rule.fail))
			elif policy != null and policy.reject_index >= 0 and policy.reject_index < NpcRecognitionPolicy.REJECT_LINES.size():
				out.append(_t(NpcRecognitionPolicy.REJECT_LINES[policy.reject_index]) % npc)
			return out
		LearnResult.FailureReason.TEACHER_SKILL_ZERO:
			return [_t("这项技能你恐怕必须找别人学了。")]
		LearnResult.FailureReason.TEACHER_PREVENTED:
			if student.apprenticeship.betrayer_count != 0 and result.student_raw_before >= context.teacher_raw_level - student.apprenticeship.betrayer_count * 20:
				out.append(_t("%s神色间似乎对你不是十分信任，也许是想起你从前背叛师门的事情 ...。") % npc)
				out.append(_t("%s说道：嗯 .... 师父能教你的都教了，其他的你自己练吧。") % npc)
			else:
				# command("hmm") and command("pat") print nothing (data/emoted.o is not in the mudlib).
				out.append(_t("%s说道：虽然你是我门下的弟子，可是并非我的嫡传弟子 ....") % npc)
				out.append(_t("%s说道：我只能教你这些粗浅的本门功夫，其他的还是去找你师父学吧。") % npc)
			out.append(_t("%s不愿意教你这项技能。") % npc)
			return out
		LearnResult.FailureReason.STUDENT_SKILL_NOT_BELOW_TEACHER:
			return [_t("这项技能你的程度已经不输你师父了。")]
		LearnResult.FailureReason.SKILL_LEARN_REJECTED:
			# valid_learn()'s own notify_fail() replaces learn.c's (the last call wins).
			var refusal: String = skill.valid_learn_line(result.skill_learn_policy_result)
			return [_t(refusal if not refusal.is_empty() else "依你目前的能力，没有办法学习这种技能。")]
		LearnResult.FailureReason.POTENTIAL_EXHAUSTED:
			return [_t("你的潜能已经发挥到极限了，没有办法再成长了。")]
		LearnResult.FailureReason.TEACHING_TEMPORARILY_DISABLED:
			return [_t(ASKED).format(asked), _t("但是%s现在并不准备回答你的问题。") % npc]
		LearnResult.FailureReason.TEACHER_TOO_TIRED:
			return [_t(ASKED).format(asked), _t("但是%s显然太累了，没有办法教你什麽。") % npc]
		_:
			# A rule the game cannot evaluate yet, or a broken state: no ES2 line.
			return [_t("你向%s请教，但这次请教无法进行。") % npc]
	out.append(_t(ASKED).format(asked))
	match result.completion:
		LearnResult.Completion.NO_PROGRESS_COMBAT_EXPERIENCE:
			out.append(_t("也许是缺乏实战经验，你对%s的回答总是无法领会。") % npc)
		LearnResult.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE:
			out.append(_t("你今天太累了，结果什麽也没有学到。"))
		LearnResult.Completion.PROGRESSED, LearnResult.Completion.LEVEL_INCREASED:
			out.append(_t("你听了%s的指导，似乎有些心得。") % npc)
	# improve_skill()'s and skill_improved()'s lines follow (colored()).
	return out


## The teacher panel's line under a skill (LearnQuote; DECISIONS「上限预览和拜师条件」): how
## far `teacher` (as authored) can take the student and why not further, or why not at
## all, then what stops a learn now (gin, potential, the teacher tired). "" when the
## teacher does not teach the student at all and says why only when asked.
static func quote_line(quote: LearnQuote, teacher: String, skill: SkillDefinition) -> String:
	var npc: String = _t(teacher)
	if not quote.taught():
		if quote.now.failure_reason in [LearnResult.FailureReason.RECOGNITION_REJECTED, LearnResult.FailureReason.RECOGNITION_POLICY_ABSENT]:
			return _t(QUOTE_NOT_TAUGHT).format({"npc": npc})
		return ""
	var why: String = ""
	match quote.bound:
		LearnQuote.Bound.TEACHER:
			why = _t(QUOTE_TEACHER if quote.ceiling > quote.level else QUOTE_TEACHER_REACHED)
		LearnQuote.Bound.BETRAYAL:
			why = _t(QUOTE_BETRAYAL)
		LearnQuote.Bound.NOT_DIRECT:
			why = _t(QUOTE_NOT_DIRECT)
		LearnQuote.Bound.POLICY:
			var refusal: String = skill.valid_learn_line(quote.policy_result)
			# valid_learn()'s refusal is a sentence: inside the brackets, without its full stop.
			why = _t(refusal if not refusal.is_empty() else "依你目前的能力，没有办法学习这种技能。").trim_suffix("。") # NO_TRANSLATE
		LearnQuote.Bound.EXPERIENCE:
			why = _t(QUOTE_EXPERIENCE if quote.ceiling > quote.level else QUOTE_EXPERIENCE_NOW)
	var values: Dictionary = {
		"npc": npc, "teacher": quote.teacher_level, "count": quote.betrayals,
		"cap": quote.teacher_level - quote.betrayals * 20, "level": quote.ceiling,
		"required": quote.required_experience, "have": quote.experience,
	}
	why = why.format(values)
	var head: String = _t(QUOTE_UP_TO if quote.ceiling > quote.level else QUOTE_NOT_NOW).format({"level": quote.ceiling, "why": why})
	var problem: String = ""
	match quote.now.failure_reason:
		LearnResult.FailureReason.POTENTIAL_EXHAUSTED:
			problem = _t(QUOTE_NO_POTENTIAL)
		LearnResult.FailureReason.TEACHER_TOO_TIRED:
			problem = _t(QUOTE_TIRED).format({"npc": npc})
		LearnResult.FailureReason.TEACHING_TEMPORARILY_DISABLED:
			problem = _t(QUOTE_NO_TEACH).format({"npc": npc})
		LearnResult.FailureReason.NONE:
			if quote.now.completion == LearnResult.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE:
				problem = _t(QUOTE_TIRED_STUDENT).format({"cost": quote.now.calculated_essence_cost})
	if problem.is_empty() or quote.ceiling <= quote.level:
		return _t(QUOTE_LINE).format({"head": head})
	return _t(QUOTE_LINE_NOW).format({"head": head, "problem": problem})


# TRANSLATORS: the teacher panel under a skill: the student can reach {level}; {why} says what stops it there (one of the QUOTE_ reasons below).
const QUOTE_UP_TO: String = "还能学到 {level} 级（{why}）"
# TRANSLATORS: the teacher panel under a skill the student cannot learn now: {why} one of the QUOTE_ reasons below.
const QUOTE_NOT_NOW: String = "学不了：{why}"
# TRANSLATORS: ends the teacher panel's line under a skill: {head} QUOTE_UP_TO or QUOTE_NOT_NOW.
const QUOTE_LINE: String = "{head}。"
# TRANSLATORS: the same with what stops a learn right now: {problem} (潜能已经用完, 精不够 …).
const QUOTE_LINE_NOW: String = "{head}；{problem}。"
# TRANSLATORS: why the student can learn no higher: the teacher ({npc}) is at {teacher} (learn.c: only below the teacher's level).
const QUOTE_TEACHER: String = "{npc}自己是 {teacher} 级"
# TRANSLATORS: why the student cannot learn: they are at the teacher's ({npc}) level {teacher}.
const QUOTE_TEACHER_REACHED: String = "你已学到{npc}的 {teacher} 级"
# TRANSLATORS: why the student can learn no higher (master.c prevent_learn()): betrayed a family {count} times, so {npc} teaches only to {teacher} - 20 × {count} = {cap}.
const QUOTE_BETRAYAL: String = "背叛师门 {count} 次，{npc}只教到 {teacher} - 20×{count} = {cap} 级"
# TRANSLATORS: why the student can learn no higher (master.c prevent_learn()): not {npc}'s own apprentice, taught only while {npc}'s level ({teacher}) is above three times theirs.
const QUOTE_NOT_DIRECT: String = "不是{npc}的嫡传弟子，只学得到{npc}等级（{teacher}）的三分之一以内"
# TRANSLATORS: why the student can learn no higher than {level} for now: learning at {level} needs {required} combat_exp (learn.c: level³/10).
const QUOTE_EXPERIENCE: String = "{level} 级要再学，须实战经验 ≥ {required}"
# TRANSLATORS: why the student cannot learn now: their level needs {required} combat_exp, they have {have}.
const QUOTE_EXPERIENCE_NOW: String = "经验不足，要再学须实战经验 ≥ {required}（你 {have}）"
# TRANSLATORS: the teacher panel under a skill when the teacher ({npc}) does not teach the student (recognize_apprentice()).
const QUOTE_NOT_TAUGHT: String = "学不了：{npc}不肯指点你。"
# TRANSLATORS: what stops a learn now: no potential left.
const QUOTE_NO_POTENTIAL: String = "潜能已经用完"
# TRANSLATORS: what stops a learn now: the teacher ({npc}) is too tired.
const QUOTE_TIRED: String = "{npc}太累了"
# TRANSLATORS: what stops a learn now: the teacher ({npc}) answers no questions now (no_teach).
const QUOTE_NO_TEACH: String = "{npc}现在不答问题"
# TRANSLATORS: what stops a learn now: gin not above the learn's cost {cost} (learn.c).
const QUOTE_TIRED_STUDENT: String = "精不够：每次耗精 {cost}，精须多于此数"


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
