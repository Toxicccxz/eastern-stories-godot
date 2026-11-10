class_name StoryQuestDefinition
extends RefCounted

## Native (任务系统, 剧情总纲 §7–8; DECISIONS「任务系统」): one quest of the 任务 page, from a
## `quests` array (data/story/*.json for the main story, a region's quests.json for its own
## lines). ES2 has no quests of this kind: 朱鸿雪's kill tasks (QuestDefinition) are its
## only ones, and they stay as they are under the 差事 column.
##
## A quest has a `line` (its column), a one-line `summary` (the 任务 page's sentence), the
## condition it `starts` on, the quests it `requires` done and `excludes` (either started
## keeps the other from ever starting), its `steps` in order and its `reward`. Every
## condition is one of JournalEntryDefinition's `when`s, read the same way.
##
## A step is done when its `done` condition holds, or, a branch, when one of its `options`
## holds: the first that does is taken and the rest are not. A later step with `only_after`
## names an option: it is skipped unless that option was taken. A step's `text` is what the
## 任务 page records when it is done; its `objective` what the status card's 目标 row says
## while it is the one to do; its `target` where that is (a map and a zone: the marker). The
## reward is a 历练 (MilestoneRewards, kind QUEST) when `milestone` is set, and a deed
## (DeedLog) when `deed` is; an option may carry its own, and so may a plain step (势力线: a
## deed done and a rank given half way down a line).
##
## Native (势力线第一批; DECISIONS「势力线的选择」): a branch step of a 势力 quest says how much it
## weighs: `weight` "big" (the line's one split) or "small" (owner 2026-11-09: 每条线 1 个大分裂 +
## 最多 2 个小选择, the rest is play). The main story's branches say nothing.

const LINE_MAIN: String = "main"
const LINE_FACTION: String = "faction"
const LINE_REGION: String = "region"
const LINE_ERRAND: String = "errand"
const LINES: Array[String] = [LINE_MAIN, LINE_FACTION, LINE_REGION, LINE_ERRAND]
## The columns' player names, in LINES order.
const LINE_TITLES: Dictionary[String, String] = {LINE_MAIN: "主线", LINE_FACTION: "势力", LINE_REGION: "地区", LINE_ERRAND: "差事"}
const WEIGHT_BIG: String = "big"
const WEIGHT_SMALL: String = "small"
const WEIGHTS: Array[String] = [WEIGHT_BIG, WEIGHT_SMALL]


## Where a step leads: a map and a zone of it.
class Target:
	extends RefCounted
	var map_id: StringName
	var zone_id: StringName
	## Whom the step is about there (NPC definition ids, `npcs`): the voxel view's marker turns
	## over the nearest of them standing on the map, else over the zone. Empty: the zone.
	var npc_ids: Array[StringName] = []

	static func from_record(reader: ContentRecordReader) -> Target:
		var target := Target.new()
		target.map_id = StringName(reader.required_text("map"))
		target.zone_id = StringName(reader.required_text("zone"))
		for npc: String in reader.text_list("npcs"):
			target.npc_ids.append(StringName(npc))
		reader.finish()
		return target


## What a quest, an option or a step gives once done.
class Reward:
	extends RefCounted
	## A 历练 reward of kind QUEST for the quest (once).
	var milestone: bool = false
	## The deed written down (DeedLog); "" for none.
	var deed: String = ""
	## Marks set on the player (CharacterState.marks), for what later quests or NPCs ask.
	var marks: Array[String] = []
	## Native (势力线第一批; DECISIONS「晋阶」): `rank` {family, title}: a member of that family is
	## from now on its `title` (弟子 → 大弟子: CharacterAffiliationState.family_title, what
	## apprentice.c's assign_apprentice() wrote once and nothing in ES2 ever raised). One who is
	## not of the family gets nothing.
	var rank_family: StringName = &""
	var rank_title: String = ""
	## Native (势力线第一批 封山 B; DECISIONS「分宗」): `branch` {from, to, title}: a member of the
	## family `from` is from now on of its branch `to`, in the generation they had, its `title`,
	## with no master (the branch's own teach their fellows: learn.c's same-family rule). It is no
	## betrayal: recruit.c's score 0 and betrayer + 1 are for one who kneels to another family's
	## master. One who is not of `from` gets nothing.
	var branch_from: StringName = &""
	var branch_to: StringName = &""
	var branch_title: String = ""

	func is_empty() -> bool:
		return not milestone and deed.is_empty() and marks.is_empty() and rank_title.is_empty() and branch_to.is_empty()

	static func from_record(reader: ContentRecordReader) -> Reward:
		var reward := Reward.new()
		reward.milestone = reader.boolean("milestone", false)
		reward.deed = reader.text("deed")
		reward.marks = reader.text_list("marks")
		var rank: ContentRecordReader = reader.child("rank") if reader.has("rank") else null
		if rank != null:
			reward.rank_family = StringName(rank.required_text("family"))
			reward.rank_title = rank.required_text("title")
			rank.finish()
		var branch: ContentRecordReader = reader.child("branch") if reader.has("branch") else null
		if branch != null:
			reward.branch_from = StringName(branch.required_text("from"))
			reward.branch_to = StringName(branch.required_text("to"))
			reward.branch_title = branch.required_text("title")
			if reward.branch_from == reward.branch_to:
				branch.fail("to", "a branch is another family than the one it leaves")
			if not reward.rank_title.is_empty():
				reader.fail("branch", "a reward raises in a family or moves to its branch, not both")
			branch.finish()
		reader.finish()
		return reward


## One way a branch step is done.
class Option:
	extends RefCounted
	var option_id: StringName
	## The condition (its when, key, topic and amount; the entry's text is unused).
	var condition: JournalEntryDefinition
	## What the 任务 page records when this option is taken.
	var text: String = ""
	var reward: Reward = Reward.new()

	static func from_record(reader: ContentRecordReader) -> Option:
		var option := Option.new()
		option.option_id = StringName(reader.required_text("id"))
		option.condition = JournalEntryDefinition.new()
		JournalEntryDefinition.read_when(reader, option.condition, "done")
		option.text = reader.required_text("text")
		if reader.has("reward"):
			option.reward = Reward.from_record(reader.child("reward"))
		reader.finish()
		return option


## Native (终章 A; DECISIONS「任务清单」): one row under a step's objective on the 任务 page, ticked
## while its `when` holds (三器 each in whose hands, the 帮手 who came). `count` rows are an
## `at_least` and show how many of its parts hold out of how many are wanted (「帮手：2／3」).
## `missing` is the half sentence said while it does not hold (「瑷伦在晚月庄等你去叫」). `if`
## shows the row only while it holds; a row without `when` is a note (no tick), shown by its `if`.
## Only shown: the rows never do a step.
class CheckRow:
	extends RefCounted
	var label: String = ""
	var condition: JournalEntryDefinition
	var shown_if: JournalEntryDefinition
	var missing: String = ""
	var counts: bool = false

	static func from_record(reader: ContentRecordReader) -> CheckRow:
		var row := CheckRow.new()
		row.label = reader.required_text("label")
		row.missing = reader.text("missing")
		row.counts = reader.boolean("count", false)
		if reader.has("when"):
			row.condition = JournalEntryDefinition.new()
			JournalEntryDefinition.read_when(reader, row.condition, "when")
		if reader.has("if"):
			row.shown_if = JournalEntryDefinition.new()
			JournalEntryDefinition.read_when(reader, row.shown_if, "if")
		if row.condition == null and row.shown_if == null:
			reader.fail("when", "a row is ticked by `when`, or a note shown by `if`")
		# A named condition (`cond`) is what it names only once linked: the catalog builder asks then.
		if row.counts and (row.condition == null or not row.condition.when in [JournalEntryDefinition.When.AT_LEAST, JournalEntryDefinition.When.COND]):
			reader.fail("count", "a count row's when is an at_least")
		if row.condition == null and not row.missing.is_empty():
			reader.fail("missing", "a note has nothing missing")
		for condition: JournalEntryDefinition in [row.condition, row.shown_if]:
			if condition != null and condition.when in [JournalEntryDefinition.When.HEARD, JournalEntryDefinition.When.CHAT]:
				reader.fail("when", "heard and chat are recorded as they happen: a row cannot ask them")
		reader.finish()
		return row


class Step:
	extends RefCounted
	var step_id: StringName
	## What to do, as the 目标 row says it.
	var objective: String = ""
	## The 任务 page's rows under the objective while this is the step to do (CheckRow).
	var checklist: Array[CheckRow] = []
	## The condition that does the step; null for a branch step (`options`).
	var condition: JournalEntryDefinition
	var options: Array[Option] = []
	## What the 任务 page records when the step is done ("" for a branch: the option's text).
	var text: String = ""
	var target: Target
	## The option (of an earlier step) this step waits for; "" for every way.
	var only_after: StringName = &""
	## What a plain step gives when done (a branch's options carry their own).
	var reward: Reward = Reward.new()
	## A branch's weight in its line: WEIGHT_BIG, WEIGHT_SMALL, or "" (unsaid: the main story's).
	var weight: String = ""

	func is_branch() -> bool:
		return not options.is_empty()

	func option(option_id: StringName) -> Option:
		for candidate: Option in options:
			if candidate.option_id == option_id:
				return candidate
		return null

	static func from_record(reader: ContentRecordReader) -> Step:
		var step := Step.new()
		step.step_id = StringName(reader.required_text("id"))
		step.objective = reader.required_text("objective")
		step.text = reader.text("text")
		step.only_after = StringName(reader.text("only_after"))
		if reader.has("target"):
			step.target = Target.from_record(reader.child("target"))
		for record: ContentRecordReader in reader.children("checklist"):
			step.checklist.append(CheckRow.from_record(record))
		var seen: Dictionary[StringName, bool] = {}
		for record: ContentRecordReader in reader.children("options"):
			var option: Option = Option.from_record(record)
			if seen.has(option.option_id):
				record.fail("id", "duplicate option '%s'" % option.option_id)
			seen[option.option_id] = true
			step.options.append(option)
		if reader.has("done"):
			step.condition = JournalEntryDefinition.new()
			JournalEntryDefinition.read_when(reader, step.condition, "done")
			if step.is_branch():
				reader.fail("done", "a branch step is done by one of its options")
		elif not step.is_branch():
			reader.fail("done", "a step says what does it: `done`, or `options`")
		if step.options.size() == 1:
			reader.fail("options", "a branch has at least two options")
		step.weight = reader.text("weight")
		if not step.weight.is_empty() and (not step.is_branch() or not WEIGHTS.has(step.weight)):
			reader.fail("weight", "a branch's weight is one of %s" % [WEIGHTS])
		if reader.has("reward"):
			step.reward = Reward.from_record(reader.child("reward"))
			if step.is_branch():
				reader.fail("reward", "a branch's options carry the rewards")
			if step.reward.milestone:
				reader.fail("reward", "the 历练 is the quest's")
		if not step.is_branch() and step.text.is_empty():
			reader.fail("text", "a step records what happened")
		reader.finish()
		return step


var quest_id: StringName
## Player text, as authored.
var title: String = ""
var line: String = LINE_MAIN
## The region's player-facing name, as authored.
var region: String = ""
## The 任务 page's sentence: where to go, whom to find, what to do.
var summary: String = ""
## Traceability (LPC files, 剧情总纲 sections); never shown.
var sources: Array[String] = []
## The condition the quest appears on; null: it is there from the start.
var starts: JournalEntryDefinition
var requires: Array[StringName] = []
var excludes: Array[StringName] = []
## Native (势力线第一批 封山 B; DECISIONS「线断了」): `lapses` {when, text}: a quest begun and not
## done is over the moment `when` holds (a 势力 line whose member left the family): its steps
## are asked no more, it gives nothing, and the 任务 page keeps what was recorded and adds
## `text`. It is not done: what `requires` it stays closed. `mark` (optional) is set on the player
## as it lapses, for the NPCs of the line to ask (`asker_lacks`, `unless_giver_mark`): what they
## would say and take of one walking the line, they do not of one who walked out of it — and
## not again of one who came back, for the line itself does not begin twice.
var lapses: JournalEntryDefinition
var lapsed_text: String = ""
var lapsed_mark: String = ""
var steps: Array[Step] = []
var reward: Reward = Reward.new()


func step(step_id: StringName) -> Step:
	for candidate: Step in steps:
		if candidate.step_id == step_id:
			return candidate
	return null


## How many of the quest's branch steps weigh `weight`.
func branches_of(weight: String) -> int:
	return steps.filter(func(candidate: Step) -> bool: return candidate.is_branch() and candidate.weight == weight).size()


## The step an option belongs to, or null.
func step_of_option(option_id: StringName) -> Step:
	for candidate: Step in steps:
		if candidate.option(option_id) != null:
			return candidate
	return null


static func from_record(reader: ContentRecordReader) -> StoryQuestDefinition:
	var definition := StoryQuestDefinition.new()
	definition.quest_id = StringName(reader.required_text("id"))
	definition.title = reader.required_text("title")
	definition.line = reader.text("line", LINE_MAIN)
	if not LINES.has(definition.line):
		reader.fail("line", "expected one of %s" % [LINES])
	definition.region = reader.required_text("region")
	definition.summary = reader.required_text("summary")
	definition.sources = reader.text_list("sources")
	if reader.has("starts"):
		definition.starts = JournalEntryDefinition.new()
		JournalEntryDefinition.read_when(reader, definition.starts, "starts")
	for quest_id: String in reader.text_list("requires"):
		definition.requires.append(StringName(quest_id))
	for quest_id: String in reader.text_list("excludes"):
		definition.excludes.append(StringName(quest_id))
	var lapses: ContentRecordReader = reader.child("lapses") if reader.has("lapses") else null
	if lapses != null:
		definition.lapses = JournalEntryDefinition.new()
		JournalEntryDefinition.read_when(lapses, definition.lapses)
		definition.lapsed_text = lapses.required_text("text")
		definition.lapsed_mark = lapses.text("mark")
		if definition.lapses.when in [JournalEntryDefinition.When.HEARD, JournalEntryDefinition.When.CHAT]:
			lapses.fail("when", "heard and chat are recorded as they happen: a quest lapses on what holds")
		lapses.finish()
	var seen: Dictionary[StringName, bool] = {}
	var options: Dictionary[StringName, bool] = {}
	for record: ContentRecordReader in reader.children("steps"):
		var step: Step = Step.from_record(record)
		if seen.has(step.step_id):
			record.fail("id", "duplicate step '%s'" % step.step_id)
		seen[step.step_id] = true
		if not step.only_after.is_empty() and not options.has(step.only_after):
			record.fail("only_after", "no option '%s' in an earlier step" % step.only_after)
		for option: Option in step.options:
			if options.has(option.option_id):
				record.fail("options", "option '%s' is already an earlier step's" % option.option_id)
			options[option.option_id] = true
		definition.steps.append(step)
	if definition.steps.is_empty():
		reader.fail("steps", "expected at least one step")
	if reader.has("reward"):
		definition.reward = Reward.from_record(reader.child("reward"))
	reader.finish()
	return definition
