class_name PowerfocusPerform
extends PerformFunction

## 封山剑法's 「点」字诀 (perform powerfocus). ES2 has only its help (doc/skill/fonxansword:
## 将劲力聚在剑尖，以意使剑，用来刺击的时候威力大增，但是若内力不够，无法收发自如，武器容易脱手飞出)
## and no file under daemon/class/swordsman/fonxansword/; this one is the game's (势力线第一批
## 封山 B; DECISIONS「点字诀」), its numbers the skill's own (skills.json
## `perform_rules.powerfocus.numbers`):
## - `force`: the internal power one thrust takes;
## - `damage`, `damage_percent`: with that much to spend, one attack at apply/damage + `damage` +
##   query_skill("fonxansword") * `damage_percent` / 100, and the force is spent;
## - `slip_busy`: short of it, what force is left goes, no thrust comes and the sword all but
##   leaves the hand: the performer is busy that long. The sword stays in the hand (a fight is
##   built on what its fighters wield): the slip costs moves, not the weapon.
## Only against an enemy in the fight, as 「逐」字诀.
const SKILL: StringName = &"fonxansword"
const FORCE: String = "force"
const DAMAGE: String = "damage"
const DAMAGE_PERCENT: String = "damage_percent"
const SLIP_BUSY: String = "slip_busy"


func _init() -> void:
	id = &"powerfocus"
	label = "「点」字诀"
	number_keys = [FORCE, DAMAGE, DAMAGE_PERCENT, SLIP_BUSY]


func perform(context: SpecialContext) -> bool:
	var me: SpecialSide = context.me
	var target: SpecialSide = context.target_or_offensive()
	if target == null or not me.is_fighting(target.character_id):
		return context.refuse("「点」字诀只能对战斗中的对手使用。")
	var skill: SkillDefinition = context.catalog.skill(SKILL)
	if skill == null:
		return context.refuse("你所使用的外功中没有这种功能。")
	var force: CharacterInternalResourceState = me.state.recovery.inner_force
	var cost: int = skill.perform_number(id, FORCE)
	if force.current < cost:
		force.current = 0
		me.busy.start_busy(skill.perform_number(id, SLIP_BUSY))
		context.say("$N使出封山剑法「点」字诀，可是内力不继，剑尖一颤，手中的剑险些脱手飞出！", target.character_id, ColoredLine.CYN)
		return true
	force.current -= cost
	@warning_ignore("integer_division")
	var strike: Dictionary[StringName, int] = {
		&"damage": skill.perform_number(id, DAMAGE) + me.query_skill(SKILL) * skill.perform_number(id, DAMAGE_PERCENT) / 100,
	}
	context.say("$N使出封山剑法「点」字诀，劲力尽数聚在剑尖，一剑直刺$n！", target.character_id, ColoredLine.CYN)
	me.state.timed_applies.hold(strike)
	context.do_attack(me, target)
	me.state.timed_applies.release(strike)
	return true


func hint(catalog: ContentCatalog) -> String:
	var skill: SkillDefinition = catalog.skill(SKILL)
	if skill == null:
		return ""
	# TRANSLATORS: hover of 使出「点」字诀: {force} the internal power one thrust takes.
	return TranslationServer.translate("用 {force} 点内力把劲力聚在剑尖，这一剑伤得更重；内力不够，剑会险些脱手，白白耽误几手").format({"force": skill.perform_number(id, FORCE)})
