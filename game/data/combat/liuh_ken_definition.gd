class_name LiuhKenDefinition
extends RefCounted

## Exact daemon/skill/liuh-ken.c. Unused dodge/parry metadata stays in the
## source analysis; it is deliberately not part of combat arithmetic.
const SKILL_ID: StringName = &"liuh-ken"
const ACTION_IDS: Array[StringName] = [
	&"es2:daemon/skill/liuh-ken/gu-song-gua-yue",
	&"es2:daemon/skill/liuh-ken/ao-xue-dong-mei",
	&"es2:daemon/skill/liuh-ken/gu-ya-ting-tao",
	&"es2:daemon/skill/liuh-ken/huang-shan-hu-yin",
]
const ACTION_TEXTS: Array[String] = [
	"$N使一招「古松挂月」，对准$n的$l「呼」地一拳",
	"$N扬起拳头，一招「傲雪冬梅」便往$n的$l招呼过去",
	"$N左手虚晃，右拳「孤崖听涛」往$n的$l击出",
	"$N步履一沉，左拳拉开，右拳使出「荒山虎吟」击向$n$l",
]


## Its kind, type, enable use and name are data (common/skills.json).
static func skill() -> SkillDefinition:
	return GameContent.catalog().skill(SKILL_ID)


static func actions() -> CombatActionSet:
	var definitions: Array[CombatActionDefinition] = []
	for index: int in range(ACTION_IDS.size()):
		definitions.append(CombatActionDefinition.new(ACTION_IDS[index], 0, 0,
			&"瘀伤", ACTION_IDS[index], ACTION_TEXTS[index], "拳", &""))
	return CombatActionSet.new(definitions)


static func action_text(action_id: StringName) -> String:
	var index: int = ACTION_IDS.find(action_id)
	return ACTION_TEXTS[index] if index >= 0 else ""
