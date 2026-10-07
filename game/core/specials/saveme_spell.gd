class_name SavemeSpell
extends CastFunction

## daemon/class/juechen/magic-array/saveme.c (奇门遁甲's 召天将), in a fight only: 100
## mana and 60 sen, the incantation, and one time in random(spells) < 60 nothing comes
## (但是什麽也没有发生); else obj/npc/heaven_soldier.c comes (`context.summons`): its
## invocation() kills the caster's enemies, who fight it back (the fight admits it).
const MANA_COST: int = 100
const SEN_COST: int = 60
const FAIL_BELOW: int = 60
const SOLDIER: StringName = &"common.npc.heaven_soldier"


func _init() -> void:
	id = &"saveme"


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
	if context.random.call(me.query_skill(&"spells")) < FAIL_BELOW:
		# message("vision", ..., environment(me)): everyone in the room reads it.
		context.say("但是什麽也没有发生。")
		return true
	context.summons.append(SOLDIER)
	return true
