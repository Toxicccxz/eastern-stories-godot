class_name PowerfadeExertFunction
extends ExertFunction

## daemon/class/fighter/celestial/powerfade.c (天邪神功): not while powerup runs, and
## only with some bellicosity: 100 force and 100 sen lower bellicosity by
## 100 + skill / 3 (skill = query_skill("force")). In a fight, random(skill) < cps * 3
## knocks the user out (unconcious()). The file's line is broken in two in the
## source (杀气 / ....); it is one line here.
const COST: int = 100
const FAINT_CPS_MULTIPLIER: int = 3


func _init() -> void:
	id = &"powerfade"


func exert(context: ExertContext) -> bool:
	var force: CharacterInternalResourceState = context.character.recovery.inner_force
	if force.current < COST:
		context.fail_line = _t("你的内力不够。")
		return false
	if context.character.timed_applies.has(PowerupExertFunction.EFFECT):
		context.fail_line = _t("你已经在运功中了。")
		return false
	if context.character.attributes.bellicosity <= 0:
		context.fail_line = _t("你现在毫无杀气。")
		return false
	var skill: int = context.force_level
	@warning_ignore("integer_division")
	context.character.attributes.bellicosity -= 100 + skill / 3
	force.current -= COST
	context.character.spirit.apply_damage(100)
	context.vision("$N微一凝神，运起天邪神功，放慢呼吸，开始收敛自己的杀气 ....", ColoredLine.HIC)
	if context.is_fighting and context.legacy_random(skill) < context.character.attributes.composure * FAINT_CPS_MULTIPLIER:
		context.character.fall_unconscious()
		context.fainted = true
	return true


## Whether powerfade would run for `character` now (its refusals), as the question
## before it in a fight needs to know.
static func would_run(character: CharacterState) -> bool:
	return (
		character.recovery.inner_force.current >= COST
		and not character.timed_applies.has(PowerupExertFunction.EFFECT)
		and character.attributes.bellicosity > 0
	)


## The chance that powerfade knocks its user out in a fight: random(skill) < cps * 3,
## where random(n <= 0) is 0.
static func faint_chance(skill: int, composure: int) -> float:
	var below: int = composure * FAINT_CPS_MULTIPLIER
	if skill <= 0:
		return 1.0 if below > 0 else 0.0
	return clampf(float(below) / float(skill), 0.0, 1.0)
