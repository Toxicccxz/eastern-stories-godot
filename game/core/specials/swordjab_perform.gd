class_name SwordjabPerform
extends PerformFunction

## daemon/class/swordsman/fonxansword/swordjab.c, 封山剑法's 「逐」字诀: when
## random(its combat_exp) beats two thirds of the target's, the performer attacks
## while i < random(3) + 1 (the bound is drawn again before each attack: one attack,
## a second at 2/3, a third at 1/3); then, whatever happened, eff_kee - 10 (add(),
## nobody's damage). No busy.
## Owner (both obvious slips): the attacks use the wielded weapon (the source passes
## query("weapon"), never set, so a sword's move would land as a bare hand's), and
## the line comes before them (the source shows it after).
const EFF_KEE_COST: int = 10


func _init() -> void:
	id = &"swordjab"
	label = "「逐」字诀"


func perform(context: SpecialContext) -> bool:
	var me: SpecialSide = context.me
	var target: SpecialSide = context.target_or_offensive()
	if target == null or not me.is_fighting(target.character_id):
		return context.refuse("「逐」字诀只能对战斗中的对手使用。")
	@warning_ignore("integer_division")
	if context.random.call(me.state.progression.combat_experience) > target.state.progression.combat_experience * 2 / 3:
		context.say("$N使出封山剑法「逐」字诀，剑法一紧，剑光罩向$n，$p已显吃力。", target.character_id, ColoredLine.CYN)
		var attacks: int = 0
		while attacks < context.random.call(3) + 1:
			context.do_attack(me, target)
			attacks += 1
	else:
		context.say("$N使出封山剑法「逐」字诀，剑法一紧，剑光罩向$n，$p从容化解", target.character_id, ColoredLine.CYN)
	me.state.vitality.effective -= EFF_KEE_COST
	return true
