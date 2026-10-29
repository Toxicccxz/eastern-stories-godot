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
## (DeedLog) when `deed` is; an option may carry its own.

const LINE_MAIN: String = "main"
const LINE_FACTION: String = "faction"
const LINE_REGION: String = "region"
const LINE_ERRAND: String = "errand"
const LINES: Array[String] = [LINE_MAIN, LINE_FACTION, LINE_REGION, LINE_ERRAND]
## The columns' player names, in LINES order.
const LINE_TITLES: Dictionary[String, String] = {LINE_MAIN: "主线", LINE_FACTION: "势力", LINE_REGION: "地区", LINE_ERRAND: "差事"}


## Where a step leads: a map and a zone of it.
class Target:
	extends RefCounted
	var map_id: StringName
	var zone_id: StringName

	static func from_record(reader: ContentRecordReader) -> Target:
		var target := Target.new()
		target.map_id = StringName(reader.required_text("map"))
		target.zone_id = StringName(reader.required_text("zone"))
		reader.finish()
		return target


## What a quest or an option gives once done.
class Reward:
	extends RefCounted
	## A 历练 reward of kind QUEST for the quest (once).
	var milestone: bool = false
	## The deed written down (DeedLog); "" for none.
	var deed: String = ""
	## Marks set on the player (CharacterState.marks), for what later quests or NPCs ask.
	var marks: Array[String] = []

	func is_empty() -> bool:
		return not milestone and deed.is_empty() and marks.is_empty()

	static func from_record(reader: ContentRecordReader) -> Reward:
		var reward := Reward.new()
		reward.milestone = reader.boolean("milestone", false)
		reward.deed = reader.text("deed")
		reward.marks = reader.text_list("marks")
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


class Step:
	extends RefCounted
	var step_id: StringName
	## What to do, as the 目标 row says it.
	var objective: String = ""
	## The condition that does the step; null for a branch step (`options`).
	var condition: JournalEntryDefinition
	var options: Array[Option] = []
	## What the 任务 page records when the step is done ("" for a branch: the option's text).
	var text: String = ""
	var target: Target
	## The option (of an earlier step) this step waits for; "" for every way.
	var only_after: StringName = &""

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
var steps: Array[Step] = []
var reward: Reward = Reward.new()


func step(step_id: StringName) -> Step:
	for candidate: Step in steps:
		if candidate.step_id == step_id:
			return candidate
	return null


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
