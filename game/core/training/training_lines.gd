class_name TrainingLines
extends RefCounted

## What cmds/std/enable.c, practice.c, exercise.c, selflearn.c and study.c print to
## the player for one result, with feature/skill.c improve_skill()'s line and the
## skill's skill_improved() line when the skill gains a level. In the shown language;
## names come from skills.json and items.json as authored.

# TRANSLATORS: feature/skill.c improve_skill(): %s is the skill's name.
const LEVEL_UP: String = "你的「%s」进步了！"


## enable <use> <skill>; `use` is the basic skill of that use.
static func enable(result: SkillMappingChangeResult, use: SkillDefinition, skill: SkillDefinition) -> Array[ColoredLine]:
	var use_name: String = _t(use.display_name) if use != null else ""
	var skill_name: String = _t(skill.display_name) if skill != null else ""
	match result.failure:
		SkillMappingChangeResult.Failure.NOT_A_USE:
			return _plain(["没有这个技能种类，用 enable ? 可以查看有哪些种类。"])
		SkillMappingChangeResult.Failure.BASIC_OF_ITSELF:
			var kind: String = _t(SkillUseIds.KINDS.get(use.skill_id, "")) if use != null else ""
			return [ColoredLine.new(_t("「{skill}」是所有{kind}的基础，不需要 enable。").format({"skill": use_name, "kind": kind}))]
		SkillMappingChangeResult.Failure.SKILL_NOT_KNOWN, SkillMappingChangeResult.Failure.MAPPING_REJECTED:
			return _plain(["你不会这种技能。"])
		SkillMappingChangeResult.Failure.USE_NOT_KNOWN:
			return [ColoredLine.new(_t("你连「{basic}」都没学会，更别提{skill}了。").format({"basic": use_name, "skill": skill_name}))]
		SkillMappingChangeResult.Failure.INVALID_USE:
			return _plain(["这个技能不能当成这种用途。"])
	var out: Array[ColoredLine] = [_ok()]
	match result.internal_resource_reset:
		SkillMappingChangeResult.InternalResourceReset.ATMAN:
			out.append(ColoredLine.new(_t("你改用另一种法术系，灵力必须重新锻炼。")))
		SkillMappingChangeResult.InternalResourceReset.INNER_FORCE:
			out.append(ColoredLine.new(_t("你改用另一种内功，内力必须重新锻炼。")))
		SkillMappingChangeResult.InternalResourceReset.MANA:
			out.append(ColoredLine.new(_t("你改用另一种咒文系，法力必须重新修炼。")))
	return out


## enable <use> none.
static func disable() -> Array[ColoredLine]:
	return [_ok()]


## practice <use>; `special` is the skill the use is enabled for (null when none is);
## `conjured_name` names the NPC a PRACTICE_CONJURED result conjured.
static func practice(result: PracticeResult, special: SkillDefinition, conjured_name: String = "") -> Array[ColoredLine]:
	var name: String = _t(special.display_name) if special != null else ""
	var conjuring: PracticeConjuring = null if special == null else special.practice_policy().conjuring
	match result.failure_reason:
		PracticeResult.FailureReason.NONE:
			pass
		PracticeResult.FailureReason.IN_COMBAT:
			return _plain(["你已经在战斗中了，学一点实战经验吧。"])
		PracticeResult.FailureReason.SKILL_NOT_MAPPED:
			return _plain(["你只能练习用 enable 指定的特殊技能。"])
		PracticeResult.FailureReason.SPECIAL_SKILL_NOT_LEARNED:
			return _plain(["你好像还没「学会」这项技能吧？最好先去请教别人。"])
		PracticeResult.FailureReason.BASIC_SKILL_NOT_LEARNED:
			return _plain(["你对这方面的技能还是一窍不通，最好从先从基本学起。"])
		PracticeResult.FailureReason.VALID_LEARN_REJECTED:
			var refusal: String = "" if special == null else special.valid_learn_line(result.skill_learn_policy_result)
			return _plain([refusal if not refusal.is_empty() else "你现在不能练习这项技能。"])
		PracticeResult.FailureReason.PRACTICE_WEAPON_REJECTED:
			if special != null and not special.practice_weapon_fail.is_empty():
				return _plain([special.practice_weapon_fail])
			return [ColoredLine.new(_t("你试著练习%s，但是并没有任何进步。") % name)]
		PracticeResult.FailureReason.PRACTICE_FORCE_REJECTED:
			if special != null and not special.practice_force_fail.is_empty():
				return _plain([special.practice_force_fail])
			if special != null and not special.practice_fail.is_empty():
				return _plain([special.practice_fail])
			return [ColoredLine.new(_t("你试著练习%s，但是并没有任何进步。") % name)]
		PracticeResult.FailureReason.PRACTICE_HOOK_REJECTED:
			# necromancy.c says its own line for each check that refuses.
			if special != null and special.practice_refusal_lines.has(result.refusal):
				return _plain([special.practice_refusal_lines[result.refusal]])
			if special != null and not special.practice_fail.is_empty():
				return _plain([special.practice_fail])
			return [ColoredLine.new(_t("你试著练习%s，但是并没有任何进步。") % name)]
		PracticeResult.FailureReason.PRACTICE_CONJURED_STANDING:
			if conjuring != null:
				return [ColoredLine.new(_t(conjuring.standing).replace("$N", _t(result.standing_conjured)))]
			return _plain(["你现在不能练习这项技能。"])
		PracticeResult.FailureReason.PRACTICE_CONJURED:
			# write() before the draw, the conjuring's write(), then its notify_fail().
			var came: Array[ColoredLine] = []
			if not special.practice_done.is_empty():
				came.append(ColoredLine.new(_t(special.practice_done)))
			for line: String in [conjuring.came, conjuring.caught]:
				came.append(ColoredLine.new(_t(line).replace("$N", _t(conjured_name))))
			return came
		_:
			# A rule the game does not have for this skill: practice.c's first notify_fail().
			return _plain(["你现在不能练习这项技能。"])
	var out: Array[ColoredLine] = []
	if special != null and not special.practice_done.is_empty():
		out.append(ColoredLine.new(_t(special.practice_done)))
	out.append_array(improved(result.skill_improvement, result.authored_effect, special))
	out.append(ColoredLine.new(_t("你的%s进步了！") % name, ColoredLine.HIY))
	return out


## exercise <kee>.
static func exercise(result: CultivationResult) -> Array[ColoredLine]:
	match result.failure_reason:
		CultivationResult.FailureReason.NONE:
			pass
		CultivationResult.FailureReason.IN_COMBAT:
			return _plain(["战斗中不能练内功，会走火入魔。"])
		CultivationResult.FailureReason.FORCE_STYLE_NOT_ENABLED:
			return _plain(["你必须先用 enable 选择你要用的内功心法。"])
		CultivationResult.FailureReason.COST_BELOW_MINIMUM:
			return _plain(["你最少要花 10 点「气」才能练功。"])
		CultivationResult.FailureReason.INSUFFICIENT_VITALITY:
			return _plain(["你现在的气太少了，无法产生内息运行全身经脉。"])
		CultivationResult.FailureReason.SPIRIT_BELOW_HEALTH_THRESHOLD:
			return _plain(["你现在精神状况太差了，无法凝神专一！"])
		CultivationResult.FailureReason.ESSENCE_BELOW_HEALTH_THRESHOLD:
			return _plain(["你现在精力不够，无法控制内息的流动！"])
		_:
			# A zero maximum: exercise.c divides by it and the driver stops the command.
			return _plain(["你现在无法练功。"])
	var out: Array[ColoredLine] = _plain(["你坐下来运气用功，一股内息开始在体内流动。"])
	match result.completion:
		CultivationResult.Completion.NO_GAIN:
			# exercise.c's 全身□麻: the character was lost in the source's conversion (痠).
			out.append(ColoredLine.new(_t("但是当你行功完毕，只觉得全身酸麻。")))
		CultivationResult.Completion.SKILL_CAP_REACHED:
			# The source line's last characters were lost (瓶颈。).
			out.append(ColoredLine.new(_t("当你的内息遍布全身经脉时却没有功力提升的迹象，似乎内力修为已经遇到了瓶颈。")))
		CultivationResult.Completion.MAXIMUM_INCREASED:
			out.append(ColoredLine.new(_t("你的内力增强了！")))
	return out


## meditate <sen>.
static func meditate(result: CultivationResult) -> Array[ColoredLine]:
	match result.failure_reason:
		CultivationResult.FailureReason.NONE:
			pass
		CultivationResult.FailureReason.IN_COMBAT:
			return _plain(["战斗中冥思——找死吗？"])
		CultivationResult.FailureReason.COST_BELOW_MINIMUM:
			return _plain(["你最少要花 10 点「神」才能冥思。"])
		CultivationResult.FailureReason.INSUFFICIENT_SPIRIT:
			return _plain(["你现在精神太差了，进行冥思将会迷失，永远醒不过来！"])
		CultivationResult.FailureReason.VITALITY_BELOW_HEALTH_THRESHOLD:
			return _plain(["你现在身体状况太差了，无法集中精神！"])
		CultivationResult.FailureReason.ESSENCE_BELOW_HEALTH_THRESHOLD:
			return _plain(["你现在身体状况太虚弱了，无法进入冥思的状态！"])
		_:
			# A zero maximum: meditate.c divides by it and the driver stops the command.
			return _plain(["你现在无法冥思。"])
	var out: Array[ColoredLine] = _plain(["你盘膝而坐，静坐冥思了一会儿。"])
	match result.completion:
		CultivationResult.Completion.NO_GAIN:
			out.append(ColoredLine.new(_t("但是当你睁开眼睛，只觉得脑中一片空白。")))
		CultivationResult.Completion.SKILL_CAP_REACHED:
			out.append(ColoredLine.new(_t("当你的法力增加的瞬间你忽然觉得脑中一片混乱，似乎魔力的提升已经到了瓶颈。")))
		CultivationResult.Completion.MAXIMUM_INCREASED:
			out.append(ColoredLine.new(_t("你的魔力提高了！")))
	return out


## respirate <gin>.
static func respirate(result: CultivationResult) -> Array[ColoredLine]:
	match result.failure_reason:
		CultivationResult.FailureReason.NONE:
			pass
		CultivationResult.FailureReason.IN_COMBAT:
			return _plain(["战斗也是一种修行，但不能和灵力的修行同时进行。"])
		CultivationResult.FailureReason.COST_BELOW_MINIMUM:
			return _plain(["你最少要花 10 点精力才能进行修行。"])
		CultivationResult.FailureReason.INSUFFICIENT_ESSENCE:
			return _plain(["你现在精力不足，无法修行灵力！"])
		CultivationResult.FailureReason.VITALITY_BELOW_HEALTH_THRESHOLD:
			return _plain(["你现在身体状况太差了，无法集中精神！"])
		CultivationResult.FailureReason.SPIRIT_BELOW_HEALTH_THRESHOLD:
			return _plain(["你现在精神状况太差了，无法控制自己的心灵！"])
		_:
			# A zero maximum: respirate.c divides by it and the driver stops the command.
			return _plain(["你现在无法修行。"])
	var out: Array[ColoredLine] = _plain(["你闭上眼睛开始打坐。"])
	match result.completion:
		CultivationResult.Completion.NO_GAIN:
			out.append(ColoredLine.new(_t("但是你一不小心却睡著了。")))
		CultivationResult.Completion.SKILL_CAP_REACHED:
			out.append(ColoredLine.new(_t("你忽然觉得一阵天旋地转，头涨得像要裂开一样，似乎灵力的修行已经遇到了瓶颈。")))
		CultivationResult.Completion.MAXIMUM_INCREASED:
			out.append(ColoredLine.new(_t("你的道行提高了！")))
	return out


## selflearn <skill>.
static func self_learn(result: SelfLearningResult, skill: SkillDefinition) -> Array[ColoredLine]:
	var name: String = _t(skill.display_name) if skill != null else String(result.skill_id)
	match result.failure_reason:
		SelfLearningResult.FailureReason.NONE:
			pass
		SelfLearningResult.FailureReason.SKILL_NOT_SELF_LEARNABLE:
			return _plain(["这项技能不能通过自学取得进步！"])
		SelfLearningResult.FailureReason.IN_COMBAT:
			return _plain(["临阵磨枪？来不及啦。"])
		SelfLearningResult.FailureReason.RAW_SKILL_BELOW_MINIMUM:
			return [ColoredLine.new(_t("你得有「%s」的入门知识才行。") % name)]
		SelfLearningResult.FailureReason.POTENTIAL_EXHAUSTED:
			return _plain(["你的潜能已经发挥到极限了，没有办法再成长了。"])
		_:
			# selflearn.c divides by a non-positive int (driver error), or a bad draw.
			return _plain(["你现在无法自学。"])
	var out: Array[ColoredLine] = [ColoredLine.new(_t("你开始钻研有关「%s」的问题。") % name)]
	match result.completion:
		SelfLearningResult.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE:
			out.append(ColoredLine.new(_t("你今天太累了，结果什麽也没有学到。")))
		SelfLearningResult.Completion.NO_PROGRESS_COMBAT_EXPERIENCE:
			out.append(ColoredLine.new(_t("也许是缺乏实战经验，结果是一无所获。")))
		_:
			out.append(ColoredLine.new(_t("你苦思冥想，似乎有些心得。")))
			out.append_array(improved(result.skill_improvement, result.authored_effect, skill))
	return out


## study <item>; `skill` is the one the item teaches.
static func study(result: StudyResult, skill: SkillDefinition) -> Array[ColoredLine]:
	var name: String = _t(skill.display_name) if skill != null else String(result.skill_id)
	match result.outcome:
		StudyResult.Outcome.IN_COMBAT:
			return _plain(["你无法在战斗中专心下来研读新知！"])
		StudyResult.Outcome.NOTHING_TO_LEARN:
			return _plain(["你无法从这样东西学到任何东西。"])
		StudyResult.Outcome.ILLITERATE:
			return _plain(["你是个文盲，先学学读书识字(literate)吧。"])
		StudyResult.Outcome.COMBAT_EXPERIENCE_TOO_LOW:
			return _plain(["你的实战经验不足，再怎麽读也没用。"])
		StudyResult.Outcome.VALID_LEARN_REJECTED:
			var refusal: String = "" if skill == null else skill.valid_learn_line(result.skill_learn_policy_result)
			return _plain([refusal if not refusal.is_empty() else "以你目前的能力，还没有办法学这个技能。"])
		StudyResult.Outcome.TOO_TIRED:
			return _plain(["你现在过於疲倦，无法专心下来研读新知。"])
		StudyResult.Outcome.TOO_SHALLOW:
			return _plain(["你研读了一会儿，但是发现上面所说的对你而言都太浅了，没有学到任何东西。"])
		StudyResult.Outcome.STUDIED:
			var out: Array[ColoredLine] = improved(result.skill_improvement, result.authored_effect, skill)
			out.append(ColoredLine.new(_t("你研读有关%s的技巧，似乎有点心得。") % name))
			return out
	# A negative cost (receive_damage() errors) or a rule the game does not have.
	return _plain(["你现在无法研读。"])


## improve_skill()'s level line and the skill's skill_improved() line.
static func improved(improvement: SkillImprovementResult, effect: SkillImprovementEffectResult, skill: SkillDefinition) -> Array[ColoredLine]:
	var out: Array[ColoredLine] = []
	if improvement == null or not improvement.leveled_up:
		return out
	var name: String = _t(skill.display_name) if skill != null else String(improvement.skill_id)
	out.append(ColoredLine.new(_t(LEVEL_UP) % name, ColoredLine.HIC))
	if (
		skill != null and not skill.improved_line.is_empty()
		and effect != null and effect.status == SkillImprovementEffectResult.Status.APPLIED
		and (skill.improved_every == 0 or improvement.current_level % skill.improved_every == 0)
	):
		out.append(ColoredLine.new(_t(skill.improved_line), skill.improved_color))
	return out


static func _ok() -> ColoredLine:
	# TRANSLATORS: enable.c's answer when a skill is enabled or disabled; ES2 prints it in English.
	return ColoredLine.new(TranslationServer.translate("Ok."))


static func _plain(texts: Array[String]) -> Array[ColoredLine]:
	var out: Array[ColoredLine] = []
	for text: String in texts:
		out.append(ColoredLine.new(_t(text)))
	return out


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
