class_name StoryQuestLog
extends RefCounted

## Native (任务系统; DECISIONS「任务系统」): the player's quests (StoryQuestDefinition) on
## CharacterState.quests, a {key: order} ledger like the journal's: "<quest>#started" when it
## began, "<quest>/<step>" when a step was done, "<quest>/<step>/<option>" when a branch step
## was done by that option, "<quest>#done" when the quest ended, "<quest>#lapsed" when it was
## cut short (StoryQuestDefinition.lapses). Nothing is ever taken back.
## Only the current step's condition is looked at, in order (JournalLog.holds, with the
## zone the player stands in); an asked answer (heard()) and a chat line (chat_heard()) are
## looked at as they happen, as the journal's are. The runtime tells what was recorded
## (told_lines), gives the rewards (Fresh.reward) and writes the deeds.

enum Kind { STARTED, STEP, DONE, LAPSED }


## One thing just recorded.
class Fresh:
	extends RefCounted
	var kind: Kind
	var quest: StoryQuestDefinition
	## STEP: the step done; null otherwise.
	var step: StoryQuestDefinition.Step
	## STEP of a branch: the option taken; null otherwise.
	var option: StoryQuestDefinition.Option

	func _init(p_kind: Kind, p_quest: StoryQuestDefinition, p_step: StoryQuestDefinition.Step = null, p_option: StoryQuestDefinition.Option = null) -> void:
		kind = p_kind
		quest = p_quest
		step = p_step
		option = p_option

	## What this gives: the option's reward or the plain step's, the quest's at its end; null otherwise.
	func reward() -> StoryQuestDefinition.Reward:
		if kind == Kind.DONE:
			return quest.reward
		if option != null:
			return option.reward
		if step != null and not step.reward.is_empty():
			return step.reward
		return null

	## What the 任务 page records for it ("" for a start).
	func text() -> String:
		if option != null:
			return option.text
		return "" if step == null else step.text


## One quest as the 任务 page shows it.
class Shown:
	extends RefCounted
	var quest: StoryQuestDefinition
	var done: bool = false
	## Cut short (StoryQuestDefinition.lapses): over, with nothing more to do, and not done.
	var lapsed: bool = false
	## The step and option texts recorded, in the order they happened.
	var entries: Array[String] = []
	## What to do now ("" once done).
	var objective: String = ""
	## The current step's checklist rows as they stand now (only when shown() is given a test).
	var checklist: Array[Checked] = []
	## The order of its newest record (quests with the newest news come first).
	var latest: int = 0


## One checklist row as it stands (StoryQuestDefinition.CheckRow): a note, or ticked or not.
class Checked:
	extends RefCounted
	enum Tick { NOTE, DONE, LACKING }
	var row: StoryQuestDefinition.CheckRow
	var tick: Tick = Tick.NOTE
	## A count row: how many of its parts hold, and how many are wanted.
	var have: int = 0
	var want: int = 0


## The rows of `step`'s checklist shown now, by `test` (a condition -> whether it holds for the
## player now: what JournalLog.holds says with their things, place and time).
static func checked(step: StoryQuestDefinition.Step, test: Callable) -> Array[Checked]:
	var rows: Array[Checked] = []
	if step == null or not test.is_valid():
		return rows
	for row: StoryQuestDefinition.CheckRow in step.checklist:
		if row.shown_if != null and not bool(test.call(row.shown_if)):
			continue
		var view := Checked.new()
		view.row = row
		if row.condition != null:
			view.tick = Checked.Tick.DONE if bool(test.call(row.condition)) else Checked.Tick.LACKING
			if row.counts:
				view.want = row.condition.amount
				for part: JournalEntryDefinition in row.condition.parts:
					if bool(test.call(part)):
						view.have += 1
		rows.append(view)
	return rows


static func key_started(quest: StoryQuestDefinition) -> String:
	return "%s#started" % quest.quest_id


static func key_done(quest: StoryQuestDefinition) -> String:
	return "%s#done" % quest.quest_id


static func key_lapsed(quest: StoryQuestDefinition) -> String:
	return "%s#lapsed" % quest.quest_id


static func key_step(quest: StoryQuestDefinition, step: StoryQuestDefinition.Step, option: StoryQuestDefinition.Option = null) -> String:
	if option != null:
		return "%s/%s/%s" % [quest.quest_id, step.step_id, option.option_id]
	return "%s/%s" % [quest.quest_id, step.step_id]


static func is_started(state: CharacterState, quest: StoryQuestDefinition) -> bool:
	return state != null and state.quests.has(key_started(quest))


static func is_done(state: CharacterState, quest: StoryQuestDefinition) -> bool:
	return state != null and state.quests.has(key_done(quest))


## Cut short before its end (DECISIONS「线断了」).
static func is_lapsed(state: CharacterState, quest: StoryQuestDefinition) -> bool:
	return state != null and state.quests.has(key_lapsed(quest))


## Started and neither done nor cut short.
static func is_active(state: CharacterState, quest: StoryQuestDefinition) -> bool:
	return is_started(state, quest) and not is_done(state, quest) and not is_lapsed(state, quest)


static func step_done(state: CharacterState, quest: StoryQuestDefinition, step: StoryQuestDefinition.Step) -> bool:
	if state == null:
		return false
	if state.quests.has(key_step(quest, step)):
		return true
	for option: StoryQuestDefinition.Option in step.options:
		if state.quests.has(key_step(quest, step, option)):
			return true
	return false


## The option a branch step was done by, or null.
static func option_taken(state: CharacterState, quest: StoryQuestDefinition, step: StoryQuestDefinition.Step) -> StoryQuestDefinition.Option:
	if state == null:
		return null
	for option: StoryQuestDefinition.Option in step.options:
		if state.quests.has(key_step(quest, step, option)):
			return option
	return null


## Whether the option `option_id` of some step of `quest` was taken.
static func took(state: CharacterState, quest: StoryQuestDefinition, option_id: StringName) -> bool:
	var step: StoryQuestDefinition.Step = quest.step_of_option(option_id)
	if step == null:
		return false
	var taken: StoryQuestDefinition.Option = option_taken(state, quest, step)
	return taken != null and taken.option_id == option_id


## The step to do now: the first not done whose `only_after` was taken; null once every
## step is done or skipped.
static func current_step(state: CharacterState, quest: StoryQuestDefinition) -> StoryQuestDefinition.Step:
	for step: StoryQuestDefinition.Step in quest.steps:
		if step_done(state, quest, step):
			continue
		if not step.only_after.is_empty() and not took(state, quest, step.only_after):
			continue
		return step
	return null


## Whether `quest` may begin: not begun, what it requires done, nothing it excludes (or
## that excludes it) begun.
static func can_start(state: CharacterState, quest: StoryQuestDefinition, quests: Array[StoryQuestDefinition]) -> bool:
	if state == null or is_started(state, quest):
		return false
	var by_id: Dictionary[StringName, StoryQuestDefinition] = {}
	for candidate: StoryQuestDefinition in quests:
		by_id[candidate.quest_id] = candidate
	for required: StringName in quest.requires:
		if not by_id.has(required) or not is_done(state, by_id[required]):
			return false
	for excluded: StringName in quest.excludes:
		if by_id.has(excluded) and is_started(state, by_id[excluded]):
			return false
	for other: StoryQuestDefinition in quests:
		if other != quest and other.excludes.has(quest.quest_id) and is_started(state, other):
			return false
	return true


## Records what holds now: quests that begin, steps done, quests ended, in the order found.
## `temps` are the player's temp marks, `held` the item definitions carried, `zone_id` where
## the player stands, `worn` the item definitions worn (WEARING), `phase_id` the day's phase (PHASE).
static func record(state: CharacterState, temps: Dictionary[String, int], held: Dictionary[StringName, bool], zone_id: StringName, quests: Array[StoryQuestDefinition], worn: Dictionary[StringName, bool] = {}, phase_id: StringName = &"") -> Array[Fresh]:
	var test: Callable = func(condition: JournalEntryDefinition) -> bool:
		return JournalLog.holds(condition, state, temps, held, zone_id, worn, phase_id)
	return _look(state, quests, test)


## The player asked `npc_id` about `topic` and was answered.
static func heard(state: CharacterState, npc_id: StringName, topic: String, quests: Array[StoryQuestDefinition]) -> Array[Fresh]:
	var test: Callable = func(condition: JournalEntryDefinition) -> bool:
		return condition.when == JournalEntryDefinition.When.HEARD and StringName(condition.key) == npc_id and condition.topic == topic
	return _look(state, quests, test)


## The player heard `npc_id` say `text`.
static func chat_heard(state: CharacterState, npc_id: StringName, text: String, quests: Array[StoryQuestDefinition]) -> Array[Fresh]:
	if text.is_empty():
		return []
	var test: Callable = func(condition: JournalEntryDefinition) -> bool:
		return condition.when == JournalEntryDefinition.When.CHAT and StringName(condition.key) == npc_id and text.contains(condition.topic)
	return _look(state, quests, test)


static func _look(state: CharacterState, quests: Array[StoryQuestDefinition], test: Callable) -> Array[Fresh]:
	var recorded: Array[Fresh] = []
	if state == null:
		return recorded
	for quest: StoryQuestDefinition in quests:
		if not is_started(state, quest) and can_start(state, quest, quests) and (quest.starts == null or test.call(quest.starts)):
			_write(state, key_started(quest))
			recorded.append(Fresh.new(Kind.STARTED, quest))
		if not is_active(state, quest):
			continue
		if quest.lapses != null and test.call(quest.lapses):
			_write(state, key_lapsed(quest))
			recorded.append(Fresh.new(Kind.LAPSED, quest))
			continue
		while true:
			var step: StoryQuestDefinition.Step = current_step(state, quest)
			if step == null:
				_write(state, key_done(quest))
				_mark(state, quest.reward)
				recorded.append(Fresh.new(Kind.DONE, quest))
				break
			var fresh: Fresh = null
			if step.is_branch():
				for option: StoryQuestDefinition.Option in step.options:
					if test.call(option.condition):
						_write(state, key_step(quest, step, option))
						_mark(state, option.reward)
						fresh = Fresh.new(Kind.STEP, quest, step, option)
						break
			elif test.call(step.condition):
				_write(state, key_step(quest, step))
				_mark(state, step.reward)
				fresh = Fresh.new(Kind.STEP, quest, step)
			if fresh == null:
				break
			recorded.append(fresh)
	return recorded


static func _write(state: CharacterState, key: String) -> void:
	if not state.quests.has(key):
		state.quests[key] = state.quests.size() + 1


static func _mark(state: CharacterState, reward: StoryQuestDefinition.Reward) -> void:
	if reward == null:
		return
	for mark: String in reward.marks:
		state.marks[mark] = 1
	# 晋阶 (DECISIONS「晋阶」): only one of that family rises in it.
	if not reward.rank_title.is_empty() and state.family.family_id == reward.rank_family and state.affiliation.has_family_rank:
		state.affiliation.family_title = reward.rank_title
	# 分宗 (DECISIONS「分宗」): the same generation in the branch, no master, no betrayal.
	if not reward.branch_to.is_empty() and state.family.family_id == reward.branch_from and state.affiliation.has_family_rank:
		state.family = FamilyState.new(reward.branch_to, state.family.generation)
		state.apprenticeship.master_teacher_id = &""
		state.apprenticeship.legacy_master_name = ""
		state.affiliation.family_title = reward.branch_title


## The quest the 目标 row and the marker follow: an active main-line quest, else the active
## quest begun last; null when none is active.
static func tracked(state: CharacterState, quests: Array[StoryQuestDefinition]) -> StoryQuestDefinition:
	if state == null:
		return null
	var best: StoryQuestDefinition = null
	var best_order: int = -1
	for quest: StoryQuestDefinition in quests:
		if not is_active(state, quest):
			continue
		var main: bool = quest.line == StoryQuestDefinition.LINE_MAIN
		var order: int = int(state.quests[key_started(quest)])
		if best == null or (main and best.line != StoryQuestDefinition.LINE_MAIN) or (main == (best.line == StoryQuestDefinition.LINE_MAIN) and order > best_order):
			best = quest
			best_order = order
	return best


## What to do now: the tracked quest's current step; "" when no quest is active.
static func objective(state: CharacterState, quests: Array[StoryQuestDefinition]) -> String:
	var quest: StoryQuestDefinition = tracked(state, quests)
	var step: StoryQuestDefinition.Step = null if quest == null else current_step(state, quest)
	return "" if step == null else step.objective


## Where the tracked quest's current step leads; null when none or it names no place.
static func target(state: CharacterState, quests: Array[StoryQuestDefinition]) -> StoryQuestDefinition.Target:
	var quest: StoryQuestDefinition = tracked(state, quests)
	var step: StoryQuestDefinition.Step = null if quest == null else current_step(state, quest)
	return null if step == null else step.target


## The quests begun, of `line` ("" for every line), the one with the newest record first.
## `test` (a condition -> whether it holds now) fills the current step's checklist; without one
## it stays empty.
static func shown(state: CharacterState, quests: Array[StoryQuestDefinition], line: String = "", test: Callable = Callable()) -> Array[Shown]:
	var result: Array[Shown] = []
	if state == null:
		return result
	for quest: StoryQuestDefinition in quests:
		if not is_started(state, quest) or (not line.is_empty() and quest.line != line):
			continue
		var view := Shown.new()
		view.quest = quest
		view.done = is_done(state, quest)
		view.lapsed = is_lapsed(state, quest)
		view.latest = int(state.quests[key_done(quest) if view.done else key_lapsed(quest) if view.lapsed else key_started(quest)])
		var recorded: Array[Array] = []
		for step: StoryQuestDefinition.Step in quest.steps:
			var option: StoryQuestDefinition.Option = option_taken(state, quest, step)
			var key: String = key_step(quest, step, option)
			if state.quests.has(key):
				var text: String = option.text if option != null else step.text
				recorded.append([int(state.quests[key]), text])
				view.latest = maxi(view.latest, int(state.quests[key]))
		recorded.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
		for entry: Array in recorded:
			view.entries.append(entry[1])
		if view.lapsed:
			view.entries.append(quest.lapsed_text)
		elif not view.done:
			var step: StoryQuestDefinition.Step = current_step(state, quest)
			view.objective = "" if step == null else step.objective
			view.checklist = checked(step, test)
		result.append(view)
	result.sort_custom(func(a: Shown, b: Shown) -> bool: return a.latest > b.latest)
	return result


## The lines that tell what was recorded: a quest begun (its title and sentence), a step done
## (【见闻】 and, `with_next`, what to do next), a quest ended.
static func told_lines(fresh: Fresh, with_next: bool, state: CharacterState) -> Array[ColoredLine]:
	var lines: Array[ColoredLine] = []
	match fresh.kind:
		Kind.STARTED:
			# TRANSLATORS: native (任务系统): a quest began: {title} its name, {summary} its sentence on the 任务 page.
			lines.append(ColoredLine.new(_t("【任务】{title}：{summary}").format({"title": _t(fresh.quest.title), "summary": _t(fresh.quest.summary)}), ColoredLine.HIW))
		Kind.STEP:
			# TRANSLATORS: native (任务系统): a quest step was done: {text} what the 任务 page records.
			lines.append(ColoredLine.new(_t("【见闻】{text}").format({"text": _t(fresh.text())}), ColoredLine.HIG))
			var step: StoryQuestDefinition.Step = current_step(state, fresh.quest)
			if with_next and step != null:
				# TRANSLATORS: native (任务系统): under a quest's 【见闻】 line, {next} what to do next.
				lines.append(ColoredLine.new(_t("下一步：{next}").format({"next": _t(step.objective)}), ColoredLine.HIG))
		Kind.DONE:
			# TRANSLATORS: native (任务系统): a quest ended: {title} its name.
			lines.append(ColoredLine.new(_t("【任务完成】{title}").format({"title": _t(fresh.quest.title)}), ColoredLine.HIW))
		Kind.LAPSED:
			# TRANSLATORS: native (任务系统, 线断了): a quest was cut short: {title} its name, {text} why.
			lines.append(ColoredLine.new(_t("【任务中止】{title}：{text}").format({"title": _t(fresh.quest.title), "text": _t(fresh.quest.lapsed_text)}), ColoredLine.HIW))
	return lines


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
