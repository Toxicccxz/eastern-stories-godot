class_name AnimateSpell
extends CastFunction

## daemon/class/taoist/necromancy/animate.c (茅山道术's 驱尸), out of a fight only, on a
## corpse (`context.corpse`, one that is still a corpse: is_corpse() until it is a
## skeleton): 50 mana, its line, the corpse rises (corpse.c animate(): `context.raised`,
## the world makes the zombie), then 50 mana off and 30 sen of damage. animate()'s time
## (spells × 3 + 30) is never read by zombie.c.
const MANA_COST: int = 50
const SEN_COST: int = 30
## Its name on the HUD when a corpse is selected (no battle panel button: it refuses in
## a fight).
const WORLD_LABEL: String = "驱尸"


func _init() -> void:
	id = &"animate"
	world_label = WORLD_LABEL


func cast(context: SpecialContext) -> bool:
	var me: SpecialSide = context.me
	if context.is_fighting():
		return context.refuse("你正在战斗中！")
	if context.corpse == null or not context.corpse.is_legacy_corpse():
		return context.refuse("你要驱动哪一具尸体？")
	var mana: CharacterInternalResourceState = me.state.recovery.mana
	if mana.current < MANA_COST:
		return context.refuse("你的法力不够了！")
	# $n is the corpse (chard.c make_corpse(): 某某的尸体).
	context.say("$N对著地上的$n喃喃地念了几句咒语，$n抽搐了几下竟站了起来！")
	context.raised = true
	mana.current -= MANA_COST
	me.state.spirit.apply_damage(SEN_COST)
	return true
