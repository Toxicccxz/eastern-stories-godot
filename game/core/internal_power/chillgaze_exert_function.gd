class_name ChillgazeExertFunction
extends ExertFunction

## daemon/class/dancer/iceforce/chillgaze.c (意寒睨), only in a fight: the user is busy 4
## (before any check), then for 50 force and 20 sen stares at offensive_target(me). The
## target looks away when random(its combat_exp) > the user's combat_exp / 2; else
## force_factor * 2 - its max_force / 15, when at least 1, is gin damage, and a wound of
## half of it when random(query_skill("force")) > its cps * 2.
const COST: int = 50
const SEN_COST: int = 20
const BUSY: int = 4
const CPS_MULTIPLIER: int = 2


func _init() -> void:
	id = &"chillgaze"
	fight_only = true
	aims = true


func exert(context: ExertContext) -> bool:
	if not context.is_fighting:
		context.fail_line = _t("「意寒睨」之术只能在战斗中使用。")
		return false
	context.busy.start_busy(BUSY)
	var force: CharacterInternalResourceState = context.character.recovery.inner_force
	if force.current < COST:
		context.fail_line = _t("你的内力不够。")
		return false
	var target: SpecialSide = context.pick_offensive_target()
	if target == null:
		context.fail_line = _t("你要对谁施展「意寒睨」之术？")
		return false
	var skill: int = context.force_level
	force.current -= COST
	context.character.spirit.apply_damage(SEN_COST)
	context.vision_at(target, "$N眼神忽然发出异光，双瞳犹如两把利刃般盯著$n！", ColoredLine.HIB)
	@warning_ignore("integer_division")
	if context.legacy_random(target.state.progression.combat_experience) > context.character.progression.combat_experience / 2:
		context.vision_by(target, "$N很快地转过头去，避开了$n的目光。")
		return true
	@warning_ignore("integer_division")
	var damage: int = context.character.attributes.force_factor * 2 - target.state.recovery.inner_force.maximum / 15
	if damage < 1:
		context.vision_by(target, "但是$N对$n的注视视若无睹....。")
		return true
	target.state.essence.apply_damage(damage)
	if context.legacy_random(skill) > target.state.attributes.composure * CPS_MULTIPLIER:
		@warning_ignore("integer_division")
		target.state.essence.apply_wound(damage / 2)
	context.vision_by(target, "$N被$n的目光所摄，不自禁地打了个寒噤。")
	return true
