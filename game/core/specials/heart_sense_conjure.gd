class_name HeartSenseConjure
extends ConjureFunction

## daemon/class/bonze/essencemagic/heart_sense.c (心识神通) on a character (`context.target`):
## 50 atman and 30 sen of damage, its line; when random(max_atman) is above 100 the target
## revive()s (`context.revived`), otherwise the caster falls unconscious (`context.fainted`:
## unconcious()). A caster still fighting after it is busy 3. The game offers it on one
## lying unconscious, outside fights (DECISIONS 山烟寺 C).
const ATMAN_COST: int = 50
const SEN_COST: int = 30
## random(max_atman) above this wakes the target.
const WAKES_ABOVE: int = 100
const BUSY_IN_FIGHT: int = 3
# TRANSLATORS: doc/skill/essencemagic: 心识 (heart sense), as a button (施展心识神通).
const LABEL: String = "心识神通"
# 天灵盖\上 in the source: the backslash doubled the second byte of Big5 蓋 (0x5C).
const LINE: String = "$N一手放在$n的天灵盖上，一手贴在$n的後心，闭上眼睛缓缓低吟 ..."


func _init() -> void:
	id = &"heart_sense"
	label = LABEL
	targets_other = true


func conjure(context: SpecialContext) -> bool:
	var me: SpecialSide = context.me
	var target: SpecialSide = context.target
	if target == null or target == me:
		return context.refuse("你要对谁使用心识神通？")
	# is_corpse(): 来不及了，只有活人才能救醒。 A corpse is never offered.
	var atman: CharacterInternalResourceState = me.state.recovery.atman
	if atman.current < ATMAN_COST:
		return context.refuse("你的灵力不够！")
	atman.current -= ATMAN_COST
	me.state.spirit.apply_damage(SEN_COST)
	context.say(LINE, target.character_id, ColoredLine.HIY)
	if context.random.call(atman.maximum) > WAKES_ABOVE:
		context.revived = true
	else:
		context.fainted = true
	# unconcious() ends the caster's fights (remove_all_enemy()).
	if not context.fainted and context.is_fighting():
		me.busy.start_busy(BUSY_IN_FIGHT)
	return true


## The chance in a hundred that it knocks a caster with `maximum_atman` out:
## random(max_atman) <= 100, every time below 102.
static func faint_percent(maximum_atman: int) -> int:
	if maximum_atman <= WAKES_ABOVE + 1:
		return 100
	return roundi((WAKES_ABOVE + 1) * 100.0 / maximum_atman)
