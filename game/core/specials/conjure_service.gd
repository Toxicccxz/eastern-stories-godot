class_name ConjureService
extends RefCounted

## cmds/std/conjure.c, `conjure <神通> [on <target>]`: not while busy, not in a no_magic
## room, and only through the magic skill enabled (its conjure_magic_file(); std/skill.c
## conjure_magic() says 你所选用的法术系中没有这种法术 for a file it has not). The file's own
## notify_fail() is the line a refusal shows. Conjuring improves nothing.
const MAGIC: StringName = &"magic"


## The 神通 the enabled magic skill reaches, in SpecialFunctions order.
static func offered(character: CharacterState, catalog: ContentCatalog) -> Array[StringName]:
	var out: Array[StringName] = []
	var mapped: StringName = character.skills.mapped_skill(MAGIC)
	var skill: SkillDefinition = null if mapped.is_empty() else catalog.skill(mapped)
	if skill == null:
		return out
	for function_id: StringName in SpecialFunctions.CONJURES:
		if skill.conjure_functions.has(function_id):
			out.append(function_id)
	return out


## conjure <function_id> for `context.me` (`context.target` the one named) in a room that is
## `no_magic` or not. Returns whether the file ran; its lines and what it did are in
## `context`, a refusal in `context.fail_line`.
static func conjure(context: SpecialContext, function_id: StringName, no_magic: bool) -> bool:
	var me: SpecialSide = context.me
	if me.busy.is_busy():
		return context.refuse("( 你上一个动作还没有完成，不能施展神通。)")
	if no_magic:
		return context.refuse("这里无法使用神通。")
	var mapped: StringName = me.state.skills.mapped_skill(MAGIC)
	if mapped.is_empty():
		return context.refuse("你请先用 enable 指令选择你要使用的神通系。")
	context.refuse("你所选用的法术系中没有这种法术。")
	var skill: SkillDefinition = context.catalog.skill(mapped)
	var function: ConjureFunction = SpecialFunctions.conjure(function_id)
	if function == null or skill == null or not skill.conjure_functions.has(function_id):
		return false
	return function.conjure(context)
