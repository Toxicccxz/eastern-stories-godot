class_name FactionDefinition
extends RefCounted

## Native (势力线第一批; DECISIONS「势力名册」): one of the 势力 of the 声望 page, from a `factions`
## array (data/story/factions.json). ES2 has no such page: a family is a line in `score`.
##
## A faction has a `layer` — 门派 (a family one is taken into: 拜师), 交情 (dealings, no rank) or
## 秘密 (a token or a crown, nothing sworn) — and its `lines`: what that house thinks of the
## player, each a sentence shown while its `when` holds (EpilogueDefinition's cards read the same
## way). A faction none of whose lines holds is not on the page: one the player never dealt with.
## The page writes sentences, never numbers (owner 2026-11-09).

const LAYER_SECT: String = "sect"
const LAYER_TIE: String = "tie"
const LAYER_SECRET: String = "secret"
const LAYERS: Array[String] = [LAYER_SECT, LAYER_TIE, LAYER_SECRET]
## The layers' player names.
const LAYER_TITLES: Dictionary[String, String] = {LAYER_SECT: "门派", LAYER_TIE: "交情", LAYER_SECRET: "秘密"}


class Line:
	extends RefCounted
	var text: String = ""
	var condition: JournalEntryDefinition


var faction_id: StringName
## Player text, as authored.
var name: String = ""
var layer: String = LAYER_SECT
## Where the house is, as the player knows the place (a region's name), as authored.
var place: String = ""
## Traceability (LPC files, 剧情总纲 sections); never shown.
var sources: Array[String] = []
var lines: Array[Line] = []


## The sentences shown now, by `test` (a condition -> whether it holds), in order.
func shown(test: Callable) -> Array[String]:
	var result: Array[String] = []
	if not test.is_valid():
		return result
	for line: Line in lines:
		if bool(test.call(line.condition)):
			result.append(line.text)
	return result


## {id, name, layer, place, sources?, lines: [{text, when}]}.
static func from_record(reader: ContentRecordReader) -> FactionDefinition:
	var definition := FactionDefinition.new()
	definition.faction_id = StringName(reader.required_text("id"))
	definition.name = reader.required_text("name")
	definition.layer = reader.required_text("layer")
	if not LAYERS.has(definition.layer):
		reader.fail("layer", "expected one of %s" % [LAYERS])
	definition.place = reader.required_text("place")
	definition.sources = reader.text_list("sources")
	for record: ContentRecordReader in reader.children("lines"):
		var line := Line.new()
		line.text = record.required_text("text")
		line.condition = JournalEntryDefinition.new()
		# A sentence is about something that happened: every one says when.
		JournalEntryDefinition.read_when(record, line.condition, "when")
		if line.condition.when in [JournalEntryDefinition.When.HEARD, JournalEntryDefinition.When.CHAT]:
			record.fail("when", "heard and chat are recorded as they happen: a line cannot ask them")
		record.finish()
		definition.lines.append(line)
	if definition.lines.is_empty():
		reader.fail("lines", "a faction says something")
	reader.finish()
	return definition
