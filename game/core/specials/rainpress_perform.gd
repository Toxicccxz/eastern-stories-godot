class_name RainpressPerform
extends PerformFunction

## 封山剑法's 「听雨」 (perform rainpress): the game's own (师娘彩蛋 A; DECISIONS「师娘彩蛋 A」). ES2 names
## 柳淳风「风雨双侠」 (daemon/class/swordsman/master.c) and writes nothing of the other one; the
## game's 沈疏雨 is she, and this is her half of the sword: 封山 waits for the enemy to miss
## (隙), 「听雨」 makes the opening — a thrust the enemy has to answer.
## Its numbers are the skill's own (skills.json `perform_rules.rainpress.numbers`):
## - `force`: the internal power one thrust takes (short of it the file refuses, nothing spent);
## - `damage`, `damage_percent`: one attack at apply/damage + `damage` +
##   query_skill("fonxansword") * `damage_percent` / 100.
## - `open_percent`: the thrust dodged or parried leaves its target open (露空): the next blow at
##   them finds their dodge and parry this much lower.
## The thrust dodged or parried also wins its performer a hand this round, as a 隙 does (within
## earned_beat_cap); landed, it is only the blow; nothing of this once the answer to it ended the
## fight (the riposte that wins a spar). Only against an enemy in the fight.
const SKILL: StringName = &"fonxansword"
const FORCE: String = "force"
const DAMAGE: String = "damage"
const DAMAGE_PERCENT: String = "damage_percent"
const OPEN_PERCENT: String = "open_percent"
const FORCED: Array[CombatAttackResult.Outcome] = [CombatAttackResult.Outcome.DODGE, CombatAttackResult.Outcome.PARRY]


func _init() -> void:
	id = &"rainpress"
	label = "「听雨」"
	number_keys = [FORCE, DAMAGE, DAMAGE_PERCENT, OPEN_PERCENT]


func perform(context: SpecialContext) -> bool:
	var me: SpecialSide = context.me
	var target: SpecialSide = context.target_or_offensive()
	if target == null or not me.is_fighting(target.character_id):
		return context.refuse("「听雨」只能对战斗中的对手使用。")
	var skill: SkillDefinition = context.catalog.skill(SKILL)
	if skill == null:
		return context.refuse("你所使用的外功中没有这种功能。")
	var force: CharacterInternalResourceState = me.state.recovery.inner_force
	var cost: int = skill.perform_number(id, FORCE)
	if force.current < cost:
		return context.refuse("你的内力不够，使不出「听雨」。")
	force.current -= cost
	@warning_ignore("integer_division")
	var strike: Dictionary[StringName, int] = {
		&"damage": skill.perform_number(id, DAMAGE) + me.query_skill(SKILL) * skill.perform_number(id, DAMAGE_PERCENT) / 100,
	}
	context.say("$N剑势一变，使出「听雨」，剑尖密如雨点罩向$n，逼得$p非接不可！", target.character_id, ColoredLine.CYN)
	me.state.timed_applies.hold(strike)
	var attack: SpecialAttack = context.do_attack(me, target)
	me.state.timed_applies.release(strike)
	if _was_forced(attack) and me.is_fighting(target.character_id):
		context.wins_beat = true
		context.opened[target.character_id] = skill.perform_number(id, OPEN_PERCENT)
		context.say("$n这一下接得仓促，身前露出了空子。", target.character_id, ColoredLine.CYN)
	return true


## Whether the thrust was dodged or parried (not landed, not lost to anything else).
static func _was_forced(attack: SpecialAttack) -> bool:
	if attack == null or attack.forward == null:
		return false
	var ordinary: CombatOrdinaryAttackResult = attack.forward.ordinary_attack_result
	return ordinary != null and ordinary.has_base_result and FORCED.has(ordinary.base_result.outcome)


func hint(catalog: ContentCatalog) -> String:
	var skill: SkillDefinition = catalog.skill(SKILL)
	if skill == null:
		return ""
	# TRANSLATORS: hover of 使出「听雨」: {force} the internal power one thrust takes.
	return TranslationServer.translate("用 {force} 点内力出一剑逼对方接招：对方闪开或架住，就露出空子（下一招更难躲开、架住），你这回合多一手；打中了就只是这一剑").format({"force": skill.perform_number(id, FORCE)})
