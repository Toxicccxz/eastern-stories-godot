class_name JournalEntryDefinition
extends RefCounted

## One line of a story chain on the 任务 page (data/common/journal.json): what happened, or
## what someone said, recorded the first time its condition holds and kept from then on
## (owner, 界面重构 Q3: only what has happened, no hints of what comes next). A guide
## chain's entry (JournalChainDefinition.guide; DECISIONS「新手链与当前目标」) may add `next`:
## the one line the status card's 目标 row and the entry's toast show, never the 任务 page.

enum When {
	## CharacterState.marks has `key`.
	MARK,
	## The player's temp marks have `key` (saved with them).
	TEMP,
	## The player carries an item of definition `key`.
	ITEM,
	## The player met NPC definition `key` in its room (seen_npcs).
	SEEN,
	## The player asked NPC `npc_id` about `topic` and was answered (recorded at the ask).
	HEARD,
	## Native (前两小时 A): a 历练 reward `key` ("<kind>/<id>", MilestoneRewards) was given.
	MILESTONE,
	## Native: the maximum inner force (max_force) reached `amount`.
	FORCE_AT_LEAST,
	## Native: combat_exp reached `amount`.
	EXP_AT_LEAST,
	## Native: skill `key` is at level `amount` or above.
	SKILL_AT_LEAST,
	## Native: the player is of family `key` (FamilyState.family_id).
	FAMILY,
	## Native (前两小时 D): the player heard NPC `key` chat a line containing `topic` (in the
	## world or in a fight; recorded as it is said).
	CHAT,
	## Native (任务系统; DECISIONS「任务系统」): the player stands in zone `key` (the runtime
	## passes where they are; a quest's arrival step).
	ZONE,
	## Native (主线 A; DECISIONS「剧情演出」): the quest ledger (CharacterState.quests) holds the
	## key `key` (`<quest>#started`, `<quest>/<step>`, `<quest>/<step>/<option>`, `<quest>#done`;
	## a branch step's key holds once any of its options was taken): what a spawn's presence
	## or a later quest asks of the story so far.
	QUEST,
	## Native (逆灵宫 A; DECISIONS「逆灵宫 A」): the player wears an item of definition `key`
	## (armor on them: the 黑冠 that makes them one of the 道士 to those who look).
	WEARING,
	## Native (逆灵宫 A): one of `parts` holds (`any`), or every one does (`all`). A part is a
	## `when` object of its own; HEARD and CHAT are recorded as they happen and cannot be parts.
	ANY,
	ALL,
	## Native (关北 C; DECISIONS「关北 C」「昼夜」): the day's phase (DayClock, day_phases.json's
	## phase_id) is one of `phases` — the night watch on the 工地, the 枷锁 opened after dark.
	## A spawn's stage reads it as the player comes onto the map (never in front of them).
	PHASE,
}

const WHEN_KEYS: Dictionary[String, int] = {
	"mark": When.MARK, "temp": When.TEMP, "item": When.ITEM, "seen": When.SEEN, "heard": When.HEARD,
	"milestone": When.MILESTONE, "force_at_least": When.FORCE_AT_LEAST, "exp_at_least": When.EXP_AT_LEAST,
	"skill_at_least": When.SKILL_AT_LEAST, "family": When.FAMILY, "chat": When.CHAT, "zone": When.ZONE,
	"quest": When.QUEST, "wearing": When.WEARING, "any": When.ANY, "all": When.ALL, "phase": When.PHASE,
}

var entry_id: StringName
var when: int = When.MARK
## The mark, temp mark, item, NPC definition, milestone, skill or family the condition
## names; for HEARD the NPC.
var key: String = ""
## HEARD: the inquiry topic; CHAT: the words the line contains.
var topic: String = ""
## FORCE_AT_LEAST, EXP_AT_LEAST: the number reached; SKILL_AT_LEAST: the level.
var amount: int = 0
## ANY, ALL: the conditions joined (each one a condition of its own, never HEARD or CHAT).
var parts: Array[JournalEntryDefinition] = []
## PHASE: the day phases (phase_id) the condition holds in.
var phases: Array[StringName] = []
## Player text, as authored.
var text: String = ""
## An NPC's inquiry answer shown under the text (quote_npc asked about quote_topic), or "".
var quote_npc: StringName
var quote_topic: String = ""
## Native (A2): the chain's story is seen through once this entry is recorded (one of its
## `final` entries, any of them): the 历练 reward for the chain (MilestoneRewards).
var final: bool = false
## Native (前两小时 A): what to do next, once this entry is the chain's latest (a guide
## chain only); "" says nothing.
var next: String = ""


static func from_record(reader: ContentRecordReader) -> JournalEntryDefinition:
	var definition := JournalEntryDefinition.new()
	definition.entry_id = StringName(reader.required_text("id"))
	definition.text = reader.required_text("text")
	definition.final = reader.boolean("final", false)
	definition.next = reader.text("next")
	read_when(reader, definition)
	var quote: ContentRecordReader = reader.child("quote") if reader.has("quote") else null
	if quote != null:
		definition.quote_npc = StringName(quote.required_text("npc"))
		definition.quote_topic = quote.required_text("topic")
		quote.finish()
	reader.finish()
	return definition


## Reads `reader`'s `when` object into `definition` (its when, key, topic and amount): one
## condition of the WHEN_KEYS. A quest's steps (StoryQuestDefinition) read theirs the same way.
static func read_when(reader: ContentRecordReader, definition: JournalEntryDefinition, field: String = "when") -> void:
	var when: ContentRecordReader = reader.child(field)
	if when == null:
		reader.fail(field, "expected an object")
		return
	_read_when_object(when, definition)


## Reads `when`, the condition object itself (one of the WHEN_KEYS), into `definition`.
static func _read_when_object(when: ContentRecordReader, definition: JournalEntryDefinition) -> void:
	var names: Array[String] = when.keys()
	if names.size() != 1 or not WHEN_KEYS.has(names[0]):
		when.fail("", "expected one of %s" % [WHEN_KEYS.keys()])
	else:
		definition.when = WHEN_KEYS[names[0]]
		match definition.when:
			When.HEARD:
				var heard: ContentRecordReader = when.child("heard")
				if heard != null:
					definition.key = heard.required_text("npc")
					definition.topic = heard.required_text("topic")
					heard.finish()
			When.CHAT:
				var chat: ContentRecordReader = when.child("chat")
				if chat != null:
					definition.key = chat.required_text("npc")
					definition.topic = chat.required_text("contains")
					chat.finish()
			When.FORCE_AT_LEAST, When.EXP_AT_LEAST:
				definition.amount = when.required_integer(names[0])
				if definition.amount <= 0:
					when.fail(names[0], "must be positive")
			When.SKILL_AT_LEAST:
				var skill: ContentRecordReader = when.child("skill_at_least")
				if skill != null:
					definition.key = skill.required_text("skill")
					definition.amount = skill.required_integer("level")
					if definition.amount <= 0:
						skill.fail("level", "must be positive")
					skill.finish()
			When.ANY, When.ALL:
				for part_reader: ContentRecordReader in when.children(names[0]):
					var part := JournalEntryDefinition.new()
					_read_when_object(part_reader, part)
					if part.when in [When.HEARD, When.CHAT]:
						part_reader.fail("", "heard and chat are recorded as they happen: they cannot be joined")
					definition.parts.append(part)
				if definition.parts.is_empty():
					when.fail(names[0], "joins at least one condition")
			When.PHASE:
				for phase_id: String in when.text_list("phase"):
					definition.phases.append(StringName(phase_id))
				if definition.phases.is_empty():
					when.fail("phase", "names at least one day phase")
			_:
				definition.key = when.required_text(names[0])
	when.finish()
