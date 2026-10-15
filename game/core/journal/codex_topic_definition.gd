class_name CodexTopicDefinition
extends RefCounted

## One 江湖常识 entry of the 百科 (data/common/codex.json): an ES2 help file for players,
## its commands put as the game's own buttons and its MUD-only lines left out (owner,
## 界面重构 Q2; DECISIONS「任务日志与百科」).

var topic_id: StringName
## Player text, as authored.
var title: String = ""
## Paragraphs, as authored; one starting with □ is a subheading.
var paragraphs: Array[String] = []
## The help file's author and date, as written in it ("" none).
var byline: String = ""
## The help file it comes from (doc/help/<name>; traceability, never shown).
var source: String = ""


static func from_record(reader: ContentRecordReader) -> CodexTopicDefinition:
	var definition := CodexTopicDefinition.new()
	definition.topic_id = StringName(reader.required_text("id"))
	definition.title = reader.required_text("title")
	definition.paragraphs = reader.text_list("paragraphs")
	definition.byline = reader.text("byline")
	definition.source = reader.required_text("source")
	if definition.paragraphs.is_empty():
		reader.fail("paragraphs", "expected at least one paragraph")
	reader.finish()
	return definition
