class_name QuestGiver
extends RefCounted

## u/cloud/npc/god.c give_quest(), the `quest` command 朱鸿雪 adds (init()). Its
## lines are in the shown language, with 你 for $N (message_vision as the player
## sees it). When it returns 0 (too weak, or a task still running) the command goes
## on to cmds/usr/quest.c, so the caller shows QuestStatus next.
##
## Deviation (owner, 3C): the draw is made among the tier's quests whose target can
## be killed in the game now (`available`), and a tier without one gives way to the
## next lower tier. With every qlist target in the game this is god.c's own draw.
enum Outcome {
	## combat_exp <= 1000: she sends the player away (returns 0).
	TOO_WEAK,
	## A task whose time has not run out (returns 0).
	HAS_TASK,
	## No quest of any tier can be done in the game now (returns 0; nothing changed).
	NONE_AVAILABLE,
	GIVEN,
}

## god.c: query("combat_exp") <= 1000 is too weak.
const MIN_EXP: int = 1000
## god.c: factor = 10 for the tier combat_exp reaches (the factor-15 branch is commented out).
const FACTOR: int = 10


class Result:
	extends RefCounted
	var outcome: Outcome = Outcome.NONE_AVAILABLE
	var lines: Array[ColoredLine] = []
	## The quest given (a copy held by the player), or null.
	var quest: QuestDefinition


## `tiers` in god.c's order (min_exp rising); `available` (target name) -> bool;
## `random` (n) -> MudOS random(n).
static func give(state: CharacterState, tiers: Array[QuestTier], available: Callable, random: Callable) -> Result:
	var result := Result.new()
	if state.progression.combat_experience <= MIN_EXP:
		result.outcome = Outcome.TOO_WEAK
		# TRANSLATORS: god.c: 朱鸿雪 sends away a player with 1000 combat_exp or less.
		result.lines.append(ColoredLine.new(_t("朱鸿雪奇怪的眼神盯着你,说:\n就凭你这种小角色也想? 还不快滚!")))
		return result
	var quest: CharacterQuestState = state.quest
	if quest.has_task() and not quest.is_expired():
		result.outcome = Outcome.HAS_TASK
		return result
	var num: int = 0
	var factor: int = 0
	for j: int in range(tiers.size() - 1, -1, -1):
		if tiers[j].min_exp <= state.progression.combat_experience:
			num = j
			factor = FACTOR
			break
	# The task ran out: tfinished starts again from 0, or sinks further from -10 down.
	var tfinished: int = quest.finished
	if quest.has_task():
		tfinished = quest.finished - 1 if quest.finished <= -10 else 0
	num = _adjusted_tier(num, tfinished, tiers.size())
	var picked: Array[QuestDefinition] = _candidates(tiers, num, available)
	if picked.is_empty():
		result.outcome = Outcome.NONE_AVAILABLE
		return result
	if quest.has_task():
		# TRANSLATORS: god.c: the player comes back after the time ran out; 朱鸿雪 then gives another task.
		result.lines.append(ColoredLine.new(_t("朱鸿雪向你一甩袍袖，说道：\n真没用！不过看在你还回来见我的份上，就在给你一次机会．")))
		@warning_ignore("integer_division")
		var kee: int = state.vitality.current / 2 + 1
		state.vitality.current = kee
		quest.finished = tfinished
	var chosen: QuestDefinition = picked[random.call(picked.size())]
	result.lines.append(ColoredLine.new(assign_line(chosen), ColoredLine.HIW))
	quest.assign(chosen, factor)
	result.quest = quest.current
	result.outcome = Outcome.GIVEN
	return result


## time_period()'s 请在…内 and the task, one HIW line as the two tell_object()s print it.
static func assign_line(quest: QuestDefinition) -> String:
	var time: String = QuestStatus.period(quest.time_seconds)
	if quest.type == QuestDefinition.FIND:
		# TRANSLATORS: god.c: 朱鸿雪 gives a task to bring {target} back within {time} (三分二十秒).
		return _t("朱鸿雪沉思了一会儿，说道：\n请在{time}内找回『{target}』给我。").format({"time": time, "target": _t(quest.target)})
	# TRANSLATORS: god.c: 朱鸿雪 gives a task to kill {target} within {time} (三分二十秒).
	return _t("朱鸿雪沉思了一会儿，说道：\n请在{time}内替我杀了『{target}』。").format({"time": time, "target": _t(quest.target)})


## god.c: tfinished / 3 tiers up (to the last), or -tfinished / 3 down (to the first).
@warning_ignore("integer_division")
static func _adjusted_tier(num: int, tfinished: int, size: int) -> int:
	if tfinished >= 0:
		return mini(num + tfinished / 3, size - 1)
	return maxi(num - (-tfinished) / 3, 0)


## The tier's quests that can be done now, else the next lower tier's (deviation).
static func _candidates(tiers: Array[QuestTier], num: int, available: Callable) -> Array[QuestDefinition]:
	for index: int in range(mini(num, tiers.size() - 1), -1, -1):
		var picked: Array[QuestDefinition] = []
		for quest: QuestDefinition in tiers[index].quests:
			if available.call(quest.target):
				picked.append(quest)
		if not picked.is_empty():
			return picked
	return []


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
