class_name CodexTopicDefinition
extends RefCounted

## One 江湖常识 entry of the 百科 (data/common/codex.json): an ES2 help file for players,
## its commands put as the game's own buttons and its MUD-only lines left out (owner,
## 界面重构 Q2; DECISIONS「任务日志与百科」).

var topic_id: StringName
## Player text, as authored.
var title: String = ""
## Paragraphs, as authored.
var paragraphs: Array[String] = []
## The indexes in `paragraphs` that are subheadings.
var headings: Dictionary[int, bool] = {}
## The help file's author and date, as written in it ("" none).
var byline: String = ""
## The help file it comes from (doc/help/<name>; traceability, never shown).
var source: String = ""


static func from_record(reader: ContentRecordReader) -> CodexTopicDefinition:
	var definition := CodexTopicDefinition.new()
	definition.topic_id = StringName(reader.required_text("id"))
	definition.title = reader.required_text("title")
	# A paragraph is a string, or { "heading": ... } for a subheading (ES2's □ lines).
	for paragraph: Variant in reader.strings_or_children("paragraphs"):
		if paragraph is ContentRecordReader:
			definition.headings[definition.paragraphs.size()] = true
			definition.paragraphs.append((paragraph as ContentRecordReader).required_text("heading"))
			(paragraph as ContentRecordReader).finish()
		else:
			definition.paragraphs.append(paragraph)
	definition.byline = reader.text("byline")
	definition.source = reader.required_text("source")
	if definition.paragraphs.is_empty():
		reader.fail("paragraphs", "expected at least one paragraph")
	reader.finish()
	return definition
