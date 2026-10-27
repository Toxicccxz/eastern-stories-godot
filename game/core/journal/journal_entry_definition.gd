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
}

const WHEN_KEYS: Dictionary[String, int] = {
	"mark": When.MARK, "temp": When.TEMP, "item": When.ITEM, "seen": When.SEEN, "heard": When.HEARD,
	"milestone": When.MILESTONE, "force_at_least": When.FORCE_AT_LEAST, "exp_at_least": When.EXP_AT_LEAST,
	"skill_at_least": When.SKILL_AT_LEAST, "family": When.FAMILY,
}

var entry_id: StringName
var when: int = When.MARK
## The mark, temp mark, item, NPC definition, milestone, skill or family the condition
## names; for HEARD the NPC.
var key: String = ""
## HEARD: the inquiry topic.
var topic: String = ""
## FORCE_AT_LEAST, EXP_AT_LEAST: the number reached; SKILL_AT_LEAST: the level.
var amount: int = 0
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
	var when: ContentRecordReader = reader.child("when")
	if when == null:
		reader.fail("when", "expected an object")
	else:
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
				_:
					definition.key = when.required_text(names[0])
		when.finish()
	var quote: ContentRecordReader = reader.child("quote") if reader.has("quote") else null
	if quote != null:
		definition.quote_npc = StringName(quote.required_text("npc"))
		definition.quote_topic = quote.required_text("topic")
		quote.finish()
	reader.finish()
	return definition
