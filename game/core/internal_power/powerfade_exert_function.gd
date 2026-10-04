class_name PowerfadeExertFunction
extends ExertFunction

## daemon/class/fighter/celestial/powerfade.c (天邪神功): not while powerup runs, and
## only with some bellicosity: 100 force and 100 sen lower bellicosity by
## 100 + skill / 3 (skill = query_skill("force")). In a fight, random(skill) < cps * 3
## knocks the user out; nobody exerts it in one yet (安惜迩 only outside a fight, the
## player cannot learn 天邪神功), so that is not ported. The file's line is broken in
## two in the source (杀气 / ....); it is one line here.
const COST: int = 100


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
	@warning_ignore("integer_division")
	context.character.attributes.bellicosity -= 100 + context.force_level / 3
	force.current -= COST
	context.character.spirit.apply_damage(100)
	context.vision("$N微一凝神，运起天邪神功，放慢呼吸，开始收敛自己的杀气 ....", ColoredLine.HIC)
	return true
