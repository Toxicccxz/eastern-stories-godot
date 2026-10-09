class_name NpcSpecials
extends RefCounted

## std/char/npc.c's chat functions perform_action(), cast_spell() and
## exert_function(), and command("surrender"). The skill enabled for the use names
## the file (its perform_action_file(), cast_spell_file(), exert_function_file());
## npc.c calls the skill daemon straight, so neither perform.c, cast.c nor exert.c
## checks busy or practises the skill. Without that file nothing happens
## (file_size() <= 0), and a file's refusal (notify_fail()) goes to the NPC alone.
## Returns whether the file ran; its lines are in `context.lines`.
static func run(action: NpcSpecialAction, context: SpecialContext) -> bool:
	if action == null or not action.is_valid() or context == null or context.me == null:
		return false
	if action.kind == NpcSpecialAction.Kind.SURRENDER:
		return SurrenderCommand.run(context)
	var mapped: StringName = context.me.state.skills.mapped_skill(action.use)
	var skill: SkillDefinition = null if mapped.is_empty() or context.catalog == null else context.catalog.skill(mapped)
	if skill == null:
		return false
	match action.kind:
		NpcSpecialAction.Kind.PERFORM:
			var perform: PerformFunction = SpecialFunctions.perform(action.function_id)
			return skill.perform_functions.has(action.function_id) and perform != null and perform.perform(context)
		NpcSpecialAction.Kind.CAST:
			var spell: CastFunction = SpecialFunctions.cast(action.function_id)
			return skill.cast_functions.has(action.function_id) and spell != null and spell.cast(context)
	var function: ExertFunction = ExertFunctions.find(action.function_id)
	if not skill.exert_functions.has(action.function_id) or function == null:
		return false
	var me: SpecialSide = context.me
	# An NPC's room is the fight's others (no NPC exerts roar; its kill_ob()s would
	# need the room's bystanders).
	var exert := ExertContext.new(me.state, me.query_skill(SkillUseIds.FORCE), context.is_fighting(), me.busy, me.character_id, context.random, context.others)
	exert.offensive = context.offensive_target
	if not function.exert(exert):
		return false
	context.lines.append_array(exert.vision_lines)
	return true
