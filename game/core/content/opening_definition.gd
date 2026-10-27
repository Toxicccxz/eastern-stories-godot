class_name OpeningDefinition
extends RefCounted

## The card New Game opens on (data/common/opening.json; owner Q2, DECISIONS「开场卡片」):
## ES2's theme story (doc/help/theme) as authored, in paragraphs, with the one native
## closing line. Shown once over the world before the player acts; never saved.

## The LPC file it follows (traceability; never shown).
var source: String = ""
## Player text, as authored.
var title: String = ""
var paragraphs: Array[String] = []
## The native line that ends the card; "" for none.
var closing: String = ""


static func from_record(reader: ContentRecordReader) -> OpeningDefinition:
	var definition := OpeningDefinition.new()
	definition.source = reader.text("source")
	definition.title = reader.required_text("title")
	definition.paragraphs = reader.text_list("paragraphs")
	definition.closing = reader.text("closing")
	if definition.paragraphs.is_empty():
		reader.fail("paragraphs", "expected at least one paragraph")
	reader.finish()
	return definition


## The card as shown, in the shown language: the title, the paragraphs set as the help
## file sets them (indented, no blank line between), then the closing line apart.
static func card_text(definition: OpeningDefinition) -> String:
	if definition == null:
		return ""
	var story: Array[String] = []
	for paragraph: String in definition.paragraphs:
		story.append(INDENT + TranslationServer.translate(paragraph))
	var parts: Array[String] = [TranslationServer.translate(definition.title), "\n".join(story)]
	if not definition.closing.is_empty():
		parts.append(TranslationServer.translate(definition.closing))
	return "\n\n".join(parts)


## Two full-width spaces, as doc/help/theme indents its paragraphs.
const INDENT: String = "　　"
