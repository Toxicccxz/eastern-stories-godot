class_name PerformService
extends RefCounted

## cmds/std/perform.c, `perform <action> [<target>]`: the martial use is the wielded
## weapon's skill_type, else unarmed; the skill enabled for it names the file (its
## perform_action_file()), and when that has none or refuses, the basic skill of the
## use is tried. The last notify_fail() is the line a refusal shows. Use is practice:
## random(120) < query_skill(<enabled skill>) improves it, random(120) < the basic
## skill's raw level after the basic skill's file, both in weak mode (a player gains
## progress, never a level).
const UNARMED: StringName = &"unarmed"
const ROLL: int = 120


## The use perform.c reads with no <martial>. prefix: the wielded weapon's skill_type.
static func martial_of(character: CharacterState) -> StringName:
	var skill_type: StringName = character.equipment.primary_weapon_skill_type()
	return UNARMED if skill_type.is_empty() else skill_type


## The actions `perform` reaches with what is in hand, in SpecialFunctions order.
static func offered(character: CharacterState, catalog: ContentCatalog) -> Array[StringName]:
	var out: Array[StringName] = []
	var martial: StringName = martial_of(character)
	var mapped: StringName = character.skills.mapped_skill(martial)
	if mapped.is_empty():
		return out
	for function_id: StringName in SpecialFunctions.PERFORMS:
		if _has(catalog.skill(mapped), function_id) or _has(catalog.skill(martial), function_id):
			out.append(function_id)
	return out


## perform <function_id> for `context.me` (`context.target` the named target).
## Returns whether a file ran; its lines and attacks are in `context`, a refusal in
## `context.fail_line`.
static func perform(context: SpecialContext, function_id: StringName) -> bool:
	var me: SpecialSide = context.me
	if me.busy.is_busy():
		return context.refuse("( 你上一个动作还没有完成，不能施用外功。)")
	var martial: StringName = martial_of(me.state)
	var mapped: StringName = me.state.skills.mapped_skill(martial)
	if mapped.is_empty():
		return context.refuse("你请先用 enable 指令选择你要使用的外功。")
	context.refuse("你所使用的外功中没有这种功能。")
	var function: PerformFunction = SpecialFunctions.perform(function_id)
	if function == null:
		return false
	if _has(context.catalog.skill(mapped), function_id) and function.perform(context):
		if context.random.call(ROLL) < me.query_skill(mapped):
			context.improve(mapped, 1, true)
		return true
	if _has(context.catalog.skill(martial), function_id) and function.perform(context):
		if context.random.call(ROLL) < me.state.skills.raw_level(martial):
			context.improve(martial, 1, true)
		return true
	return false


static func _has(skill: SkillDefinition, function_id: StringName) -> bool:
	return skill != null and skill.perform_functions.has(function_id)
