class_name QuestStatus
extends RefCounted

## cmds/usr/quest.c: the player's task and the time left, in the shown language.


## quest.c main(): 你现在没有任何任务！ (its notify_fail) without a task.
static func lines(quest: CharacterQuestState) -> Array[String]:
	if quest == null or not quest.has_task():
		return [_t("你现在没有任何任务！")]
	# TRANSLATORS: quest.c: the player's task, {type} 杀 (kill) or 寻 (find) and {target} whom or what.
	var out: Array[String] = [_t("你现在的任务是{type}『{target}』。").format({"type": _t(quest.current.type), "target": _t(quest.current.target)})]
	var seconds: int = seconds_left(quest)
	if seconds > 0:
		# TRANSLATORS: quest.c: the time left for the task, as time_period() writes it (五分零秒).
		out.append(_t("你还有{time}去完成它。").format({"time": period(seconds)}))
	else:
		out.append(_t("但是你已经没有足够的时间来完成它了。"))
	return out


## task_time - time() in whole seconds; a part second left still counts.
@warning_ignore("integer_division")
static func seconds_left(quest: CharacterQuestState) -> int:
	return 0 if quest == null or quest.remaining_ms <= 0 else (quest.remaining_ms + 999) / 1000


## time_period() of god.c and quest.c: days, hours and minutes when not 0, then the
## seconds always (五分零秒).
@warning_ignore("integer_division")
static func period(seconds: int) -> String:
	var s: int = seconds % 60
	var t: int = seconds / 60
	var m: int = t % 60
	t /= 60
	var h: int = t % 24
	var d: int = t / 24
	var text: String = ""
	if d != 0:
		# TRANSLATORS: time_period(): a number of days, {n} in Chinese numerals (三).
		text += _t("{n}天").format({"n": ChineseNumber.of(d)})
	if h != 0:
		# TRANSLATORS: time_period(): a number of hours, {n} in Chinese numerals.
		text += _t("{n}小时").format({"n": ChineseNumber.of(h)})
	if m != 0:
		# TRANSLATORS: time_period(): a number of minutes, {n} in Chinese numerals.
		text += _t("{n}分").format({"n": ChineseNumber.of(m)})
	# TRANSLATORS: time_period(): a number of seconds, {n} in Chinese numerals (零 too).
	text += _t("{n}秒").format({"n": ChineseNumber.of(s)})
	return text


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
