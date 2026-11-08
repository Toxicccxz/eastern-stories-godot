class_name EpilogueDefinition
extends RefCounted

## Native (终章 C; DECISIONS「结局讲述」): an ending told one place at a time — the cards shown over
## the 沙盘 in order, the camera flying to each card's `place` (a map; the place it belongs to on the
## 地图 page), its `title` over its lines. A line is shown when its `when` holds for the player then
## (none: always); a card with no line shown is passed over. `final` (a `when`): the journey ends with
## it (the player stayed in the ice) and the game goes back to the main menu afterwards; else the
## world goes on. Read from data/story/*.json's `epilogues`, played by an act's or an answer's
## `epilogue` step (ScriptedAct, NpcInquiryRule).


class Line:
	extends RefCounted
	var text: String = ""
	var condition: JournalEntryDefinition


class Card:
	extends RefCounted
	var card_id: StringName
	## The map whose place the camera flies to; "" keeps it where it is.
	var place: StringName = &""
	var title: String = ""
	var lines: Array[Line] = []

	## The lines shown now, by `test` (a condition -> whether it holds).
	func shown(test: Callable) -> Array[String]:
		var result: Array[String] = []
		for line: Line in lines:
			if line.condition == null or (test.is_valid() and bool(test.call(line.condition))):
				result.append(line.text)
		return result


var epilogue_id: StringName
## Traceability (剧情总纲 sections, the plan); never shown.
var sources: Array[String] = []
var cards: Array[Card] = []
var final: JournalEntryDefinition


## The cards shown now and their lines, in order: [[card, lines], ...].
func shown(test: Callable) -> Array[Array]:
	var result: Array[Array] = []
	for card: Card in cards:
		var lines: Array[String] = card.shown(test)
		if not lines.is_empty():
			result.append([card, lines])
	return result


## Whether the journey ends with it now (`final` holding).
func ends_journey(test: Callable) -> bool:
	return final != null and test.is_valid() and bool(test.call(final))


## {id, sources?, final?: when, cards: [{id, place?, title, lines: [{text, when?}]}]}.
static func from_record(reader: ContentRecordReader) -> EpilogueDefinition:
	var definition := EpilogueDefinition.new()
	definition.epilogue_id = StringName(reader.required_text("id"))
	definition.sources = reader.text_list("sources")
	if reader.has("final"):
		definition.final = JournalEntryDefinition.new()
		JournalEntryDefinition.read_when(reader, definition.final, "final")
	var seen: Dictionary[StringName, bool] = {}
	for record: ContentRecordReader in reader.children("cards"):
		var card := Card.new()
		card.card_id = StringName(record.required_text("id"))
		if seen.has(card.card_id):
			record.fail("id", "duplicate card '%s'" % card.card_id)
		seen[card.card_id] = true
		card.place = StringName(record.text("place"))
		card.title = record.required_text("title")
		for line_record: ContentRecordReader in record.children("lines"):
			var line := Line.new()
			line.text = line_record.required_text("text")
			if line_record.has("when"):
				line.condition = JournalEntryDefinition.new()
				JournalEntryDefinition.read_when(line_record, line.condition, "when")
				if line.condition.when in [JournalEntryDefinition.When.HEARD, JournalEntryDefinition.When.CHAT]:
					line_record.fail("when", "heard and chat are recorded as they happen: a line cannot ask them")
			line_record.finish()
			card.lines.append(line)
		if card.lines.is_empty():
			record.fail("lines", "a card says something")
		record.finish()
		definition.cards.append(card)
	if definition.cards.is_empty():
		reader.fail("cards", "an ending has at least one card")
	reader.finish()
	return definition
