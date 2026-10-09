class_name ScribeService
extends RefCounted

## cmds/std/scribe.c `scribe <符> on <物品> for <对象>`: not in a fight, at least 30 sen,
## and only through the spells skill enabled (its scribe_spell_file()); that 符's
## scribe() runs, and when it returns 1 the blood it is drawn in costs 1 kee (a wound)
## and 30 sen. The 符 a skill reaches are its skills.json `scribe` list (HauntScribe).
const SPELLS: StringName = &"spells"
const MIN_SEN: int = 30
const KEE_WOUND: int = 1
const SEN_COST: int = 30


## The 符 the enabled spells skill can draw, in SpecialFunctions order.
static func offered(character: CharacterState, catalog: ContentCatalog) -> Array[StringName]:
	var out: Array[StringName] = []
	var mapped: StringName = character.skills.mapped_skill(SPELLS)
	var skill: SkillDefinition = null if mapped.is_empty() else catalog.skill(mapped)
	if skill == null:
		return out
	for function_id: StringName in SpecialFunctions.SCRIBES:
		if skill.scribe_functions.has(function_id):
			out.append(function_id)
	return out


## scribe <function_id> on a carried paper for `name` (the one written on it) by `me`:
## the refusal only `me` reads, or "" once it is drawn and paid for.
static func scribe(me: SpecialSide, function_id: StringName, name: String, fighting: bool, catalog: ContentCatalog) -> String:
	if fighting:
		return "战斗时不能画符！"
	if me.state.spirit.current < MIN_SEN:
		return "你的精神太差了，无法画符。"
	var mapped: StringName = me.state.skills.mapped_skill(SPELLS)
	if mapped.is_empty():
		return "你请先用 enable 指令选择你要使用的咒文系。"
	var skill: SkillDefinition = catalog.skill(mapped)
	# scribe.c's own notify_fail() for a system without the 符, commented out there (ES2
	# then fails on the missing file); a native player is never offered one.
	if skill == null or not skill.scribe_functions.has(function_id) or function_id != HauntScribe.ID:
		return "你所学的法术没有这种符。"
	var refused: String = HauntScribe.scribe(me, fighting, name)
	if not refused.is_empty():
		return refused
	me.state.vitality.apply_wound(KEE_WOUND)
	me.state.spirit.apply_damage(SEN_COST)
	return ""
