class_name DriftSenseConjure
extends ConjureFunction

## daemon/class/bonze/essencemagic/drift_sense.c (游识神通), at oneself only, not in a
## fight, with 75 atman: conjure() asks 你要移动到哪一个人身边？ and select_target() takes
## the answer. The one it finds (`context.target`, owner: an NPC the player has seen,
## DECISIONS 山烟寺 A Q3): not in a fight and 75 atman again, then 75 atman and 30 gin of
## damage and its line; random(their max_atman) above the caster's atman / 2 fails (不够
## 强烈), random(magic) below their atman / 50 fails (不够熟练), else the caster is moved to
## their room (`context.drifted`). The lights others see there are not the player's to read.
# TRANSLATORS: doc/skill/essencemagic: 游识 (drift sense), as a button and a panel's title.
const LABEL: String = "游识神通"
const ATMAN_COST: int = 75
const GIN_COST: int = 30
const PROMPT: String = "你要移动到哪一个人身边？"
const NOT_FOUND: String = "你无法感受到这个人的灵力 ...."
const CANCELLED: String = "中止施法。"
const LINE: String = "$N低头闭目，开始施展游识神通 ...."


func _init() -> void:
	id = &"drift_sense"
	label = LABEL


## conjure(): the checks before the question; true when it asks.
func conjure(context: SpecialContext) -> bool:
	if context.is_fighting():
		return context.refuse("战斗中无法使用游识神通！")
	if context.me.state.recovery.atman.current < ATMAN_COST:
		return context.refuse("你的灵力不够！")
	if context.target != null:
		return context.refuse("游识神通只能对自己使用！")
	return true


## select_target() with the one the name found (`context.target`, null for nobody): false
## when nobody was found, and the question is asked again; true when the conjuring is
## over, its lines in `context`.
func select_target(context: SpecialContext) -> bool:
	var me: SpecialSide = context.me
	var target: SpecialSide = context.target
	if target == null:
		context.write(NOT_FOUND)
		return false
	var atman: CharacterInternalResourceState = me.state.recovery.atman
	if context.is_fighting():
		context.write("战斗中无法使用游识神通！")
		return true
	if atman.current < ATMAN_COST:
		context.write("你的灵力不够！")
		return true
	atman.current -= ATMAN_COST
	me.state.essence.apply_damage(GIN_COST)
	context.say(LINE, &"", ColoredLine.HIY)
	# is_ghost(): nobody conjures as a ghost here (death takes the player to the temple).
	@warning_ignore("integer_division")
	if context.random.call(target.state.recovery.atman.maximum) > atman.current / 2:
		context.write("你感受到对方的灵力，但是不够强烈。")
		return true
	@warning_ignore("integer_division")
	if context.random.call(me.query_skill(ConjureService.MAGIC)) < target.state.recovery.atman.current / 50:
		context.write("你因为不够熟练而失败了。")
		return true
	context.drifted = true
	return true
