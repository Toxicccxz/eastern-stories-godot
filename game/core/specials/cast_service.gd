class_name CastService
extends RefCounted

## cmds/std/cast.c, `cast <spell> [on <target>]`: not while busy, not in a no_magic room,
## and only through the spells skill enabled (its cast_spell_file(); std/skill.c
## cast_spell() says 你所选用的咒文系中没有这种咒文 for a spell it has not). The file's
## own notify_fail() is the line a refusal shows. Casting improves nothing.
const SPELLS: StringName = &"spells"


## The spells the enabled spells skill reaches, in SpecialFunctions order.
static func offered(character: CharacterState, catalog: ContentCatalog) -> Array[StringName]:
	var out: Array[StringName] = []
	var mapped: StringName = character.skills.mapped_skill(SPELLS)
	var skill: SkillDefinition = null if mapped.is_empty() else catalog.skill(mapped)
	if skill == null:
		return out
	for function_id: StringName in SpecialFunctions.CASTS:
		if skill.cast_functions.has(function_id):
			out.append(function_id)
	return out


## cast <function_id> for `context.me` (`context.target` the one named, `me` for oneself)
## in a room that is `no_magic` or not. Returns whether the file ran; its lines,
## summons and departure are in `context`, a refusal in `context.fail_line`.
static func cast(context: SpecialContext, function_id: StringName, no_magic: bool) -> bool:
	var me: SpecialSide = context.me
	if me.busy.is_busy():
		return context.refuse("( 你上一个动作还没有完成，不能念咒文。)")
	if no_magic:
		return context.refuse("这里不准念咒文。")
	var mapped: StringName = me.state.skills.mapped_skill(SPELLS)
	if mapped.is_empty():
		return context.refuse("你请先用 enable 指令选择你要使用的咒文系。")
	context.refuse("你所选用的咒文系中没有这种咒文。")
	var skill: SkillDefinition = context.catalog.skill(mapped)
	var function: CastFunction = SpecialFunctions.cast(function_id)
	if function == null or skill == null or not skill.cast_functions.has(function_id):
		return false
	return function.cast(context)
