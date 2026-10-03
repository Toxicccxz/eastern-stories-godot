class_name LearnLines
extends RefCounted

## What cmds/std/learn.c (with std/char/master.c prevent_learn() and
## feature/skill.c improve_skill()) prints to the student for one LearnResult.
## `context` is the request's (NpcTeacher.context()).

# TRANSLATORS: learn.c: {npc} is the teacher, {skill} the skill asked about.
const ASKED: String = "你向{npc}请教有关「{skill}」的疑问。"
## SKILL_D(skill)->skill_improved() lines, printed when its effect applies.
const IMPROVED_LINES: Dictionary[StringName, String] = {
	&"literate": "由於你的勤学苦读，你的悟性提高了。",
}


## In the shown language; `teacher`, `skill_name` and `respect` are as authored.
static func lines(result: LearnResult, teacher: String, skill_name: String, student: CharacterState, context: TeachingContext, respect: String) -> Array[String]:
	var policy: NpcRecognitionPolicy = context.recognition_policy as NpcRecognitionPolicy
	var out: Array[String] = []
	var npc: String = _t(teacher)
	var asked: Dictionary = {"npc": npc, "skill": _t(skill_name)}
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
			return [_t("依你目前的能力，没有办法学习这种技能。")]
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
	if result.completion == LearnResult.Completion.LEVEL_INCREASED:
		out.append(_t("你的「%s」进步了！") % asked["skill"])
		if (
			result.authored_effect != null and result.authored_effect.status == SkillImprovementEffectResult.Status.APPLIED
			and IMPROVED_LINES.has(result.skill_id)
		):
			out.append(_t(IMPROVED_LINES[result.skill_id]))
	return out


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
