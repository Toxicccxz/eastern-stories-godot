class_name HastenPerform
extends PerformFunction

## daemon/class/scholar/mysterrier/hasten.c, 步玄七诀's first form 「玄羽乱舞」: only in a
## fight, with at least 70 kee and force at least 70 over max_force. Then query_skill(
## "mysterrier") / 20 + 2 rounds, at most seven: each picks an enemy afresh
## (clean_up_enemy(), select_opponent()); with none here the performer stops, else it
## circles that enemy and fight()s it (combatd.c's courage draw: an attack, a guard line or
## nothing), and pays 10 kee (receive_damage(), nobody's) and 10 force. Busy 3 after.
## Deviation (DECISIONS 乔阴 A, an obvious slip): `if( !COMBAT_D->fight(me, ob) )` tests a
## void function, so ES2 printed 但是$N找不到机会出手！ after every round, also after a
## blow; here it follows a round in which no blow was struck.
const KEE_NEEDED: int = 70
const SURPLUS_NEEDED: int = 70
const MOST_ROUNDS: int = 7
const ROUND_KEE: int = 10
const ROUND_FORCE: int = 10
const BUSY: int = 3


func _init() -> void:
	id = &"hasten"
	label = "「玄羽乱舞」"


func perform(context: SpecialContext) -> bool:
	var me: SpecialSide = context.me
	if not context.is_fighting():
		return context.refuse("「玄羽乱舞」只能在战斗中使用。")
	if me.state.vitality.current < KEE_NEEDED:
		return context.refuse("你的气不够！")
	var force: CharacterInternalResourceState = me.state.recovery.inner_force
	if force.current - force.maximum < SURPLUS_NEEDED:
		return context.refuse("你的真气不够！")
	context.say("$N使出步玄七诀第一式「玄羽乱舞」，身法陡然加快！", &"", ColoredLine.HIY)
	@warning_ignore("integer_division")
	var rounds: int = mini(me.query_skill(&"mysterrier") / 20 + 2, MOST_ROUNDS)
	while rounds > 0:
		rounds -= 1
		var target: SpecialSide = context.select_opponent()
		if target == null or target.location_id != me.location_id:
			context.say("$N的身形转了几转，倏地停住了脚步。", &"", ColoredLine.CYN)
			break
		context.say("$N迅捷无伦地在$n身旁绕了一圈 ...", target.character_id, ColoredLine.CYN)
		var attack: SpecialAttack = context.fight(me, target)
		if attack == null or not attack.attacked():
			context.say("但是$N找不到机会出手！", &"", ColoredLine.CYN)
		me.state.vitality.apply_damage(ROUND_KEE)
		force.current -= ROUND_FORCE
	me.busy.start_busy(BUSY)
	return true
