class_name JournalEntryDefinition
extends RefCounted

## One line of a story chain on the 任务 page (data/common/journal.json): what happened, or
## what someone said, recorded the first time its condition holds and kept from then on
## (owner, 界面重构 Q3: only what has happened, no hints of what comes next).

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
}

const WHEN_KEYS: Dictionary[String, int] = {"mark": When.MARK, "temp": When.TEMP, "item": When.ITEM, "seen": When.SEEN, "heard": When.HEARD}

var entry_id: StringName
var when: int = When.MARK
## The mark, temp mark, item or NPC definition the condition names; for HEARD the NPC.
var key: String = ""
## HEARD: the inquiry topic.
var topic: String = ""
## Player text, as authored.
var text: String = ""
## An NPC's inquiry answer shown under the text (quote_npc asked about quote_topic), or "".
var quote_npc: StringName
var quote_topic: String = ""


static func from_record(reader: ContentRecordReader) -> JournalEntryDefinition:
	var definition := JournalEntryDefinition.new()
	definition.entry_id = StringName(reader.required_text("id"))
	definition.text = reader.required_text("text")
	var when: ContentRecordReader = reader.child("when")
	if when == null:
		reader.fail("when", "expected an object")
	else:
		var names: Array[String] = when.keys()
		if names.size() != 1 or not WHEN_KEYS.has(names[0]):
			when.fail("", "expected one of %s" % [WHEN_KEYS.keys()])
		else:
			definition.when = WHEN_KEYS[names[0]]
			if definition.when == When.HEARD:
				var heard: ContentRecordReader = when.child("heard")
				if heard != null:
					definition.key = heard.required_text("npc")
					definition.topic = heard.required_text("topic")
					heard.finish()
			else:
				definition.key = when.required_text(names[0])
		when.finish()
	var quote: ContentRecordReader = reader.child("quote") if reader.has("quote") else null
	if quote != null:
		definition.quote_npc = StringName(quote.required_text("npc"))
		definition.quote_topic = quote.required_text("topic")
		quote.finish()
	reader.finish()
	return definition
