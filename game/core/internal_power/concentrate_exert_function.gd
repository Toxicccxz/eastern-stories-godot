class_name ConcentrateExertFunction
extends ExertFunction

## daemon/class/taoist/gouyee/concentrate.c (谷衣心法's 灵神诀): for 30 force and 10 sen,
## mana rises by 10 + query_skill("force") / 5; a rise that would pass max_mana sets mana
## to max_mana (also when mana stood above it). In a fight the user is then busy 1.
## receive_damage("sen", 10) may take sen below 0: the user then falls (char.c).
const COST: int = 30
const SEN_COST: int = 10
const BASE_GAIN: int = 10
const FORCE_DIVISOR: int = 5


func _init() -> void:
	id = &"concentrate"


func exert(context: ExertContext) -> bool:
	var force: CharacterInternalResourceState = context.character.recovery.inner_force
	if force.current < COST:
		context.fail_line = _t("你的内力不够。")
		return false
	var mana: CharacterInternalResourceState = context.character.recovery.mana
	@warning_ignore("integer_division")
	var gain: int = BASE_GAIN + context.force_level / FORCE_DIVISOR
	if gain + mana.current > mana.maximum:
		mana.current = mana.maximum
	else:
		mana.current += gain
	force.current -= COST
	context.character.spirit.apply_damage(SEN_COST)
	context.vision("$N闭目凝神，用谷衣心法的内力运转了一次「灵神诀」...", ColoredLine.HIY)
	context.vision("一股青气从$N身上散出，汇聚在$P的顶心，然後缓缓淡去。", ColoredLine.HIY)
	if context.is_fighting:
		context.busy.start_busy(1)
	return true
