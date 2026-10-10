class_name VoidSenseConjure
extends ConjureFunction

## daemon/class/bonze/essencemagic/void_sense.c (空识神通), at oneself only: 50 atman and
## 50 gin of damage, its line; then, when random(magic) beats query_int(), one time in
## random(max_atman) < atman / 2 (after the cost) learned_points rise by 1 (潜能降低),
## otherwise, while less than 500 potential is unspent, potential rises by random(spi / 5)
## + 1; else nothing comes of it (一无所获). The file has no fight check; the game offers
## it outside fights (DECISIONS 山烟寺 C).
# TRANSLATORS: doc/skill/essencemagic: 空识 (void sense), as a button.
const LABEL: String = "空识神通"
const ATMAN_COST: int = 50
const GIN_COST: int = 50
## potential - learned_points below this gains.
const UNSPENT_BELOW: int = 500
const LINE: String = "$N盘膝而座，开始运用空识神通静思入定 ..."


func _init() -> void:
	id = &"void_sense"
	label = LABEL


func conjure(context: SpecialContext) -> bool:
	var me: SpecialSide = context.me
	if context.target != null:
		return context.refuse("空识神通只能对自己使用。")
	var atman: CharacterInternalResourceState = me.state.recovery.atman
	if atman.current < ATMAN_COST:
		return context.refuse("你的灵力不够！")
	atman.current -= ATMAN_COST
	me.state.essence.apply_damage(GIN_COST)
	context.say(LINE, &"", ColoredLine.HIY)
	var progression: CharacterProgressionState = me.state.progression
	# query_int(): int + apply/intelligence.
	var intelligence: int = me.state.attributes.effective_intelligence() + me.apply(&"intelligence")
	if context.random.call(me.query_skill(ConjureService.MAGIC)) > intelligence:
		@warning_ignore("integer_division")
		if context.random.call(atman.maximum) < atman.current / 2:
			progression.potential_spent += 1
			context.write("你觉得脑中一片混乱，你的潜能降低了！", ColoredLine.HIR)
			return true
		if progression.potential - progression.potential_spent < UNSPENT_BELOW:
			# query_spi(): spi + apply/spirituality.
			var spirituality: int = me.state.attributes.effective_spirituality() + me.apply(&"spirituality")
			@warning_ignore("integer_division")
			progression.potential += context.random.call(spirituality / 5) + 1
			context.write("你的潜能提高了！", ColoredLine.HIG)
			return true
	context.write("可是你只觉得一无所获。")
	return true
