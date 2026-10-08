class_name InvocationSpell
extends CastFunction

## daemon/class/taoist/necromancy/invocation.c (茅山道术's 召护法), in a fight only:
## 100 mana and 60 sen, the incantation, and when random(max_mana) < 200 nothing comes
## (但是什麽也没有发生); else, one time in three (!random(3)), obj/npc/heaven_soldier.c,
## the other two obj/npc/hell_guard.c (`context.summons`): its invocation() kills the
## caster's enemies, who fight it back (the fight admits it on the caster's side).
const MANA_COST: int = 100
const SEN_COST: int = 60
const FAIL_BELOW: int = 200
const SOLDIER: StringName = &"common.npc.heaven_soldier"
const GUARD: StringName = &"common.npc.hell_guard"


func _init() -> void:
	id = &"invocation"
	label = "召护法"


func cast(context: SpecialContext) -> bool:
	var me: SpecialSide = context.me
	if not context.is_fighting():
		return context.refuse("只有战斗中才能召唤天将！")
	var mana: CharacterInternalResourceState = me.state.recovery.mana
	if mana.current < MANA_COST:
		return context.refuse("你的法力不够了！")
	if me.state.spirit.current < SEN_COST:
		return context.refuse("你的精神无法集中！")
	context.say("$N喃喃地念了几句咒语。")
	mana.current -= MANA_COST
	me.state.spirit.apply_damage(SEN_COST)
	if context.random.call(mana.maximum) < FAIL_BELOW:
		# message("vision", ..., environment(me)): everyone in the room reads it.
		context.say("但是什麽也没有发生。")
		return true
	context.summons.append(SOLDIER if context.random.call(3) == 0 else GUARD)
	return true
