class_name PowerupExertFunction
extends ExertFunction

## daemon/class/fighter/celestial/powerup.c (天邪神功): for 100 force, bellicosity
## rises by 100 + skill / 2 and apply/attack and apply/dodge by skill / 3 for `skill`
## seconds (skill = query_skill("force")), set_temp("powerup") meanwhile; in a fight
## the user is then busy 3. receive_damage("kee", 0) changes nothing. remove_effect()
## tells only its user 你的天邪神功运行完毕，将内力收回丹田。
const EFFECT: StringName = &"powerup"
const COST: int = 100
const FIGHT_BUSY: int = 3


func _init() -> void:
	id = &"powerup"


func exert(context: ExertContext) -> bool:
	var force: CharacterInternalResourceState = context.character.recovery.inner_force
	if force.current < COST:
		context.fail_line = _t("你的内力不够。")
		return false
	if context.character.timed_applies.has(EFFECT):
		context.fail_line = _t("你已经在运功中了。")
		return false
	var skill: int = context.force_level
	@warning_ignore("integer_division")
	context.character.attributes.bellicosity += 100 + skill / 2
	force.current -= COST
	context.vision("$N微一凝神，运起天邪神功，全身骨节发出一阵爆豆般的声响！", ColoredLine.HIR)
	@warning_ignore("integer_division")
	var bonus: int = skill / 3
	context.character.timed_applies.start(EFFECT, {&"attack": bonus, &"dodge": bonus}, skill * 1000)
	if context.is_fighting:
		context.busy.start_busy(FIGHT_BUSY)
	return true
