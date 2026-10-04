class_name BoltSpell
extends CastFunction

## daemon/class/taoist/necromancy/drainerbolt.c and feeblebolt.c (茅山道术): at an
## enemy, for 25 mana and some sen. One time in max_mana / 50 it fails (write()
## tells only the caster). Else a bolt flies; when random(ap + dp) beats dp
## (ap = spells³ / 4 * sen / 100, dp the target's combat_exp) it hits for
## max_mana / 20 + random(eff_sen / 10) less the target's max_mana / 30 and
## random(eff_sen / 15) (the caster's eff_sen both times, as written). A hit that
## does damage drains gin into the caster (drainerbolt) or sen (feeblebolt), wounds
## a third of it, practises necromancy and is followed by report_status(target).
## The caster is busy 2. The files' kill_ob() when the target was not fighting the
## caster never runs: they are cast only in a fight, at an enemy.
enum Track { GIN, SEN }

const MANA_COST: int = 25
const FAIL_BELOW: int = 50
const BUSY: int = 2

var _track: Track
var _sen_cost: int
var _flash: String
var _flash_color: StringName
var _hit: String
var _miss: String


func _init(p_id: StringName, p_track: Track, p_sen_cost: int, p_flash: String, p_flash_color: StringName, p_hit: String, p_miss: String) -> void:
	id = p_id
	_track = p_track
	_sen_cost = p_sen_cost
	_flash = p_flash
	_flash_color = p_flash_color
	_hit = p_hit
	_miss = p_miss


func cast(context: SpecialContext) -> bool:
	var me: SpecialSide = context.me
	var target: SpecialSide = context.offensive_target()
	if target == null or target.character_id == me.character_id:
		return context.refuse("你要对谁施展这个法术？")
	var mana: CharacterInternalResourceState = me.state.recovery.mana
	if mana.current < MANA_COST:
		return context.refuse("你的法力不够！")
	if me.state.spirit.current < _sen_cost:
		return context.refuse("你的精神没有办法有效集中！")
	mana.current -= MANA_COST
	me.state.spirit.apply_damage(_sen_cost)
	if context.random.call(mana.maximum) < FAIL_BELOW:
		return true # write("你失败了。"): the caster alone reads it.
	context.say(_flash, target.character_id, _flash_color)
	var ap: int = me.query_skill(&"spells")
	@warning_ignore("integer_division")
	ap = (ap * ap * ap / 4) * me.state.spirit.current / 100
	var dp: int = target.state.progression.combat_experience
	var damage: int = 0
	if context.random.call(ap + dp) > dp:
		var eff_sen: int = me.state.spirit.effective
		@warning_ignore("integer_division")
		damage = mana.maximum / 20 + context.random.call(eff_sen / 10)
		@warning_ignore("integer_division")
		damage -= target.state.recovery.mana.maximum / 30 + context.random.call(eff_sen / 15)
		if damage > 0:
			context.say(_hit, target.character_id, ColoredLine.HIR).damage = damage
			_strike(me, target, damage)
			context.damaged.append(target.character_id)
			context.improve(&"necromancy", 1, true)
		else:
			context.say(_miss, target.character_id)
	else:
		context.say("但是被$n躲开了。", target.character_id)
	if damage > 0:
		context.lines.append(VisionLine.status(target.character_id, target.state.vitality.current, target.state.vitality.maximum))
	me.busy.start_busy(BUSY)
	return true


func _strike(me: SpecialSide, target: SpecialSide, damage: int) -> void:
	@warning_ignore("integer_division")
	var wound: int = damage / 3
	match _track:
		Track.GIN:
			me.state.essence.heal(target.state.essence.apply_damage(damage))
			target.state.essence.apply_wound(wound)
		Track.SEN:
			target.state.spirit.apply_damage(damage)
			target.state.spirit.apply_wound(wound)
