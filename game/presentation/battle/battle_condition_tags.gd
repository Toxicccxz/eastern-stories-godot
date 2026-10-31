class_name BattleConditionTags
extends RefCounted

## 战斗决策层 2 (DECISIONS「战斗界面」): the one-word tags a battle card shows for the
## conditions of daemon/condition/ (ConditionIds), and what each means for the hover.
## ES2 shows a condition only through the line its daemon prints on each heart beat;
## the tag and its words are presentation. No icon art yet: a word stands where an icon
## will (owner, 包 2 Q2).

## TRANSLATORS: the one-word tag of a condition on a battle card: poison (snake, rose, generic), drunk, 蒙汗药, 意寒掌's cold, bandaged.
const LABELS: Dictionary[StringName, String] = {
	ConditionIds.POISON: "毒",
	ConditionIds.SNAKE_POISON: "毒",
	ConditionIds.ROSE_POISON: "毒",
	ConditionIds.DRUNK: "醉",
	ConditionIds.SLUMBER_DRUG: "迷药",
	ConditionIds.ICE_SHOCK: "冰",
	ConditionIds.BANDAGED: "包扎",
}

## TRANSLATORS: what each condition does, for the card's hover; the numbers are the daemons' own (snake_poison.c, rose_poison.c, iceshock.c, drunk.c, slumber_drug.c, bandaged.c).
const DESCRIPTIONS: Dictionary[StringName, String] = {
	ConditionIds.POISON: "中毒：每次心跳掉气，一半成伤。",
	ConditionIds.SNAKE_POISON: "蛇毒：每次心跳伤气 10、掉神 10。",
	ConditionIds.ROSE_POISON: "火玫瑰毒：每次心跳伤神 20、掉气 10。",
	ConditionIds.DRUNK: "醉了：越醉越站不稳，醉过头会昏倒。",
	ConditionIds.SLUMBER_DRUG: "蒙汗药：药力发作，撑不住就会昏倒。",
	ConditionIds.ICE_SHOCK: "意寒掌毒：每次心跳伤精、气、神各 25。",
	ConditionIds.BANDAGED: "包扎着：每次心跳回气 3。",
}


## The tag for `condition_id`, "" for one the card does not show.
static func label(condition_id: StringName) -> String:
	return "" if not LABELS.has(condition_id) else TranslationServer.translate(LABELS[condition_id])


static func description(condition_id: StringName) -> String:
	return "" if not DESCRIPTIONS.has(condition_id) else TranslationServer.translate(DESCRIPTIONS[condition_id])


## The tags of `condition_ids`, each once (two poisons read one 毒).
static func labels(condition_ids: Array[StringName]) -> PackedStringArray:
	var tags := PackedStringArray()
	for id: StringName in condition_ids:
		var tag: String = label(id)
		if not tag.is_empty() and not tags.has(tag):
			tags.append(tag)
	return tags


## One line per condition for the hover.
static func descriptions(condition_ids: Array[StringName]) -> PackedStringArray:
	var lines := PackedStringArray()
	for id: StringName in condition_ids:
		var text: String = description(id)
		if not text.is_empty():
			lines.append(text)
	return lines
