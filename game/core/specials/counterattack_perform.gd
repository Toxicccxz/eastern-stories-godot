class_name CounterattackPerform
extends PerformFunction

## daemon/class/swordsman/fonxansword/counterattack.c, 封山剑法's 「封」字诀: against
## an enemy that is not busy, the performer is busy 1; when random(its combat_exp)
## beats half the target's, the target is busy query_skill("fonxansword") / 20 + 2
## (start_busy() with no interrupt: no blow breaks it).
const OWN_BUSY: int = 1


func _init() -> void:
	id = &"counterattack"


func perform(context: SpecialContext) -> bool:
	var target: SpecialSide = context.offensive_target()
	if target == null or not context.me.is_fighting(target.character_id):
		return context.refuse("牵制攻击只能对战斗中的对手使用。")
	if target.busy.is_busy():
		return context.refuse("$n目前正自顾不暇，放胆攻击吧！", target.character_id)
	context.me.busy.start_busy(OWN_BUSY)
	@warning_ignore("integer_division")
	if context.random.call(context.me.state.progression.combat_experience) > target.state.progression.combat_experience / 2:
		@warning_ignore("integer_division")
		target.busy.start_busy(context.me.query_skill(&"fonxansword") / 20 + 2)
		context.say("$N使出封山剑法「封」字诀，连递数个虚招企图扰乱$n的攻势，结果$p被$P攻了个措手不及！", target.character_id, ColoredLine.CYN)
	else:
		context.say("$N使出封山剑法「封」字诀，连递数个虚招企图扰乱$n的攻势，可是$p看破了$P的企图，并没有上当。", target.character_id, ColoredLine.CYN)
	return true
