class_name DunSpell
extends CastFunction

## daemon/class/juechen/magic-array/dun.c (奇门遁甲's 遁), in a fight only. At an enemy
## (an NPC's cast_spell() names none: offensive_target()): nothing while that one is
## busy already (正自顾不暇, to the caster alone); else 200 mana and 80 sen, and one time
## in random(spells) < 40 it fails (write(): the caster alone reads it). Otherwise one of
## five spells closes round the target and, when random(ap + dp) > dp (ap = spells³ / 10
## * sen / 100 after the cost, dp the target's combat_exp), the target is busy
## mana / 200 (after the cost; the misspelt mana_facter adds nothing) less its own
## max_mana / 100, at least 0, plus 2; else it leaps free and the caster is busy 1.
## At oneself (the player's own cast) it takes the caster away to Snow's temple: not
## here yet, as nobody casts it at themselves before the player's spells come.
const MANA_COST: int = 200
const SEN_COST: int = 80
const FAIL_BELOW: int = 40
const CHANT: String = "$N口中喃喃地念著咒文，忽然大喝一声“疾！”"
const SPELLS: Array[String] = [
	"只见一道黑气罩在$n身上！",
	"只见一道金光罩在$n身上！",
	"只见一团火焰罩在$n身上！",
	"只听在一声海啸，海水将$n团团围住！",
	"只见空中落下无数大木，正把$n困在中央！",
]
const ESCAPED: String = "但是$n纵身一跃，脱离了围困。"


func _init() -> void:
	id = &"dun"


func cast(context: SpecialContext) -> bool:
	var me: SpecialSide = context.me
	var target: SpecialSide = context.target_or_offensive()
	if target == null:
		return context.refuse("你要对谁施展这个法术？")
	if not context.is_fighting():
		return context.refuse("这个法术只能在战斗中使用！")
	if target.character_id == me.character_id:
		return context.refuse("你要对谁施展这个法术？")
	if target.busy != null and target.busy.is_busy():
		return context.refuse("$n正自顾不暇，放胆进攻吧。", target.character_id)
	var mana: CharacterInternalResourceState = me.state.recovery.mana
	if mana.current < MANA_COST:
		return context.refuse("你的法力不够！")
	if me.state.spirit.current < SEN_COST:
		return context.refuse("你的精神没有办法有效集中！")
	mana.current -= MANA_COST
	me.state.spirit.apply_damage(SEN_COST)
	var spells: int = me.query_skill(&"spells")
	if context.random.call(spells) < FAIL_BELOW:
		return true # write("你失败了。"): the caster alone reads it.
	var spell: String = SPELLS[clampi(context.random.call(SPELLS.size()), 0, SPELLS.size() - 1)]
	@warning_ignore("integer_division")
	var ap: int = (spells * spells * spells / 10) * me.state.spirit.current / 100
	var dp: int = target.state.progression.combat_experience
	context.say(CHANT, target.character_id, ColoredLine.HIW)
	context.say(spell, target.character_id, ColoredLine.HIW)
	if context.random.call(ap + dp) > dp:
		@warning_ignore("integer_division")
		var busy_time: int = maxi(mana.current / 200 - target.state.recovery.mana.maximum / 100, 0)
		target.busy.start_busy(busy_time + 2)
	else:
		context.say(ESCAPED, target.character_id)
		me.busy.start_busy(1)
	return true
