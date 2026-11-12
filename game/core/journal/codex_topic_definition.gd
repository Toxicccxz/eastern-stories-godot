class_name CodexTopicDefinition
extends RefCounted

## One 江湖常识 entry of the 百科 (data/common/codex.json): a 入门 entry written for the game
## as it plays now, or a 传说 entry kept from an ES2 help file (DECISIONS「百科重写」).

var topic_id: StringName
## The group it is listed under (入门, 传说; player text, as authored).
var group: String = ""
## Player text, as authored.
var title: String = ""
## Paragraphs, as authored.
var paragraphs: Array[String] = []
## The indexes in `paragraphs` that are subheadings.
var headings: Dictionary[int, bool] = {}
## Where its text comes from (an ES2 help file, or native; traceability, never shown).
var source: String = ""


static func from_record(reader: ContentRecordReader) -> CodexTopicDefinition:
	var definition := CodexTopicDefinition.new()
	definition.topic_id = StringName(reader.required_text("id"))
	definition.group = reader.required_text("group")
	definition.title = reader.required_text("title")
	# A paragraph is a string, or { "heading": ... } for a subheading (ES2's □ lines).
	for paragraph: Variant in reader.strings_or_children("paragraphs"):
		if paragraph is ContentRecordReader:
			definition.headings[definition.paragraphs.size()] = true
			definition.paragraphs.append((paragraph as ContentRecordReader).required_text("heading"))
			(paragraph as ContentRecordReader).finish()
		else:
			definition.paragraphs.append(paragraph)
	definition.source = reader.required_text("source")
	if definition.paragraphs.is_empty():
		reader.fail("paragraphs", "expected at least one paragraph")
	reader.finish()
	return definition
