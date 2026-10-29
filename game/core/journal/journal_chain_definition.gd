class_name JournalChainDefinition
extends RefCounted

## One story on the 任务 page (data/common/journal.json): its title, where it happens and
## its entries in story order. It shows once one of its entries is recorded.

var chain_id: StringName
## Player text, as authored: a title that does not tell how the story ends.
var title: String = ""
## The region's player-facing name, as authored.
var region: String = ""
## The LPC files the entries follow (traceability; never shown).
var sources: Array[String] = []
var entries: Array[JournalEntryDefinition] = []
## Native (前两小时 A; DECISIONS「新手链与当前目标」): a guide chain's entries may carry
## `next`, shown on the status card's 目标 row while the chain is not seen through. The
## 任务 page shows a guide chain as any other: only what happened.
var guide: bool = false
## Native (任务系统; DECISIONS「任务系统」): the 任务 page's column the chain is listed under
## (StoryQuestDefinition.LINES: main / faction / region / errand); "region" when unsaid.
var line: String = StoryQuestDefinition.LINE_REGION


## The entry's saved key in CharacterState.journal.
func key_of(entry: JournalEntryDefinition) -> String:
	return "%s/%s" % [chain_id, entry.entry_id]


static func from_record(reader: ContentRecordReader) -> JournalChainDefinition:
	var definition := JournalChainDefinition.new()
	definition.chain_id = StringName(reader.required_text("id"))
	definition.title = reader.required_text("title")
	definition.region = reader.required_text("region")
	definition.sources = reader.text_list("sources")
	definition.guide = reader.boolean("guide", false)
	definition.line = reader.text("line", StoryQuestDefinition.LINE_REGION)
	if not StoryQuestDefinition.LINES.has(definition.line):
		reader.fail("line", "expected one of %s" % [StoryQuestDefinition.LINES])
	var seen: Dictionary[StringName, bool] = {}
	for record: ContentRecordReader in reader.children("entries"):
		var entry: JournalEntryDefinition = JournalEntryDefinition.from_record(record)
		if seen.has(entry.entry_id):
			record.fail("id", "duplicate entry '%s'" % entry.entry_id)
		if not entry.next.is_empty() and not definition.guide:
			record.fail("next", "only a guide chain's entry says what comes next")
		seen[entry.entry_id] = true
		definition.entries.append(entry)
	if definition.entries.is_empty():
		reader.fail("entries", "expected at least one entry")
	reader.finish()
	return definition
