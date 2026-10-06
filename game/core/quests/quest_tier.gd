class_name QuestTier
extends RefCounted

## One of god.c's `levels`: the quests QUEST_D(level) lists (quest/qlist<level>.c),
## for a combat_exp of at least `min_exp`. A name listed twice is drawn twice as often.
var min_exp: int
var legacy_source: String
var quests: Array[QuestDefinition] = []


func _init(p_min_exp: int = 0, p_legacy_source: String = "", p_quests: Array[QuestDefinition] = []) -> void:
	min_exp = p_min_exp
	legacy_source = p_legacy_source
	quests = p_quests.duplicate()


## {"min_exp", "legacy_source", "quests": [QuestDefinition]}.
static func from_record(reader: ContentRecordReader) -> QuestTier:
	var tier := QuestTier.new(reader.required_integer("min_exp"), reader.required_text("legacy_source"))
	for record: ContentRecordReader in reader.children("quests"):
		tier.quests.append(QuestDefinition.from_record(record))
	if tier.quests.is_empty():
		reader.fail("quests", "a tier lists at least one quest")
	reader.finish()
	return tier
