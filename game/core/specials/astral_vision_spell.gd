class_name AstralVisionSpell
extends CastFunction

## daemon/class/taoist/necromancy/astral_vision.c (茅山道术's 阴阳眼), in a fight or out of
## one, on the caster whoever is named: refused while query_temp("apply/astral_vision")
## is set; else 30 mana off and 5 sen of damage, its line, apply/astral_vision for
## query_skill("spells") seconds (the call_out(): CharacterTimedApplies) and, in a fight,
## the caster busy 3. remove_effect() tells the caster alone. std/char.c visible() lets
## whoever has it see ghosts (CharacterState.sees_ghosts()).
const MANA_COST: int = 30
const SEN_COST: int = 5
const BUSY: int = 3
const LABEL: String = "阴阳眼"


func _init() -> void:
	id = &"astral_vision"
	self_label = LABEL
	self_anywhere = true
	effect_id = CharacterState.ASTRAL_VISION


func cast(context: SpecialContext) -> bool:
	var me: SpecialSide = context.me
	if me.state.timed_applies.value(CharacterState.ASTRAL_VISION) > 0:
		return context.refuse("你已经施展过阴阳眼的法术了。")
	var mana: CharacterInternalResourceState = me.state.recovery.mana
	if mana.current < MANA_COST:
		return context.refuse("你的法力不够。")
	var skill: int = me.query_skill(&"spells")
	mana.current -= MANA_COST
	me.state.spirit.apply_damage(SEN_COST)
	context.say("$N微一凝神，闭著眼睛念了几句咒语，施展「阴阳眼」法术。", &"", ColoredLine.HIB)
	# call_out(..., 0) still runs once the cast is over: at least a millisecond.
	me.state.timed_applies.start(effect_id, {CharacterState.ASTRAL_VISION: 1}, maxi(skill * 1000, 1))
	if context.is_fighting():
		me.busy.start_busy(BUSY)
	return true


func self_sen_cost(state: CharacterState) -> int:
	var refused: bool = state.timed_applies.value(CharacterState.ASTRAL_VISION) > 0 or state.recovery.mana.current < MANA_COST
	return 0 if refused else SEN_COST


func remove_effect(context: SpecialContext, _entry: CharacterTimedApplies.Entry) -> void:
	context.write("你的阴阳眼法术失效了。")
