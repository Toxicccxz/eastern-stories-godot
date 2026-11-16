class_name QuestMercy
extends RefCounted

## Native (势力线第一批 东方神教 B; 计划 build/plans/势力线第一批_计划.md §11 Q7, owner 2026-11-09「按推荐开工」;
## DECISIONS「朱鸿雪的差事分两档」): god.c draws every qlist target alike, the 乞丐 and the 裁缝 as the 疯狗.
## While `when` holds (the player stood with 安妮儿), 朱鸿雪 gives only the targets that deserve it
## (`deserving`: bandits, beasts); the others cannot be drawn, and a running task on one is called off
## as one whose target is gone (QuestGiver). quests.json's `quest_mercy` {when, deserving, sources}.
var when: JournalEntryDefinition
var deserving: Dictionary[String, bool] = {}


## Whether `target` is spared for `state`: the mercy holds and it is not one of the deserving.
func spares(target: String, state: CharacterState) -> bool:
	return when != null and state != null and not deserving.has(target) and JournalLog.holds(when, state, {}, {})


static func from_record(reader: ContentRecordReader) -> QuestMercy:
	var mercy := QuestMercy.new()
	# Traceability, as a quest's `sources`; never shown.
	reader.text_list("sources")
	mercy.when = JournalEntryDefinition.new()
	JournalEntryDefinition.read_when(reader, mercy.when, "when")
	for target: String in reader.text_list("deserving"):
		if mercy.deserving.has(target):
			reader.fail("deserving", "'%s' is listed twice" % target)
		mercy.deserving[target] = true
	if mercy.deserving.is_empty():
		reader.fail("deserving", "names at least one target")
	reader.finish()
	return mercy
