class_name FakefaultPerform
extends PerformFunction

## daemon/class/swordsman/fonxansword/fakefault.c, 封山剑法's 「缺」字诀: against a
## conscious enemy in the same place, when random(its combat_exp) beats half the
## target's, skill = (300 - query_skill("sword")) / 20 within 2..10 and for `skill`
## seconds apply/attack - skill * 3, apply/dodge + (12 - skill) * 5, no busy; else
## the performer is busy 1. remove_effect(): against the target still conscious and
## there, "奋力一击": apply/attack + (12 - skill) * 10 and apply/damage + (12 - skill) * 3
## for one attack each way (the dodge still on), then everything goes back.
## Owner: one at a time (the source checks query_temp("fonxansword") but sets the
## permanent flag, so nothing stopped a second); a strike only in the fight it began
## in, by a conscious performer (else remove_effect() only takes the applies back).
const EFFECT: StringName = &"fonxansword"
const OWN_BUSY: int = 1


func _init() -> void:
	id = &"fakefault"
	label = "「缺」字诀"
	effect_id = EFFECT


func perform(context: SpecialContext) -> bool:
	var me: SpecialSide = context.me
	var target: SpecialSide = context.target_or_offensive()
	if target == null or not me.is_fighting(target.character_id):
		return context.refuse("'缺'字诀只能在战斗中使用。")
	if not target.living or target.location_id != me.location_id:
		return context.refuse("你要对谁使用'缺'字诀？")
	if me.state.timed_applies.has(EFFECT):
		return context.refuse("你已经在运用中了。")
	@warning_ignore("integer_division")
	if context.random.call(me.state.progression.combat_experience) > target.state.progression.combat_experience / 2:
		@warning_ignore("integer_division")
		var skill: int = clampi((300 - me.query_skill(&"sword")) / 20, 2, 10)
		me.state.timed_applies.start(EFFECT, {&"attack": -skill * 3, &"dodge": (12 - skill) * 5}, skill * 1000, target.character_id)
		context.say("$N剑招陡变，空门大开，诱使$n进招，", target.character_id, ColoredLine.CYN)
		return true
	context.say("$N剑招陡变，空门大开，诱使$n进招，", target.character_id, ColoredLine.CYN)
	context.say("可是$n看破了$N的企图，并没有上当。", target.character_id, ColoredLine.CYN)
	me.busy.start_busy(OWN_BUSY)
	return true


func remove_effect(context: SpecialContext, entry: CharacterTimedApplies.Entry) -> void:
	var me: SpecialSide = context.me
	var target: SpecialSide = context.target
	if target == null or not target.living or target.location_id != me.location_id or not me.living:
		return
	@warning_ignore("integer_division")
	var skill: int = -entry.applies.get(&"attack", 0) / 3
	var strike: Dictionary[StringName, int] = {
		&"attack": (12 - skill) * 10, &"damage": (12 - skill) * 3, &"dodge": entry.applies.get(&"dodge", 0),
	}
	context.say("$N突然对$n发出奋力一击！", target.character_id, ColoredLine.CYN)
	me.state.timed_applies.hold(strike)
	context.do_attack(me, target)
	context.do_attack(target, me)
	me.state.timed_applies.release(strike)
