class_name Es2CombatMessages
extends RefCounted

## ES2's combat narration, verbatim. Templates keep the LPC tokens ($N $n $P $p
## $l $w) for BattleNarrator; the trailing "\n" and colour macros are dropped.

## adm/daemons/combatd.c guard_msg. Core draws the index (fight()).
const GUARD: Array[String] = [
	"$N注视著$n的行动，企图寻找机会出手。",
	"$N正盯著$n的一举一动，随时准备发动攻势。",
	"$N缓缓地移动脚步，想要找出$n的破绽。",
	"$N目不转睛地盯著$n的动作，寻找进攻的最佳时机。",
	"$N慢慢地移动著脚步，伺机出手。",
]

## adm/daemons/combatd.c winner_msg. Core draws the index (do_attack()).
const WINNER: Array[String] = [
	"$N哈哈大笑，说道：承让了！",
	"$N双手一拱，笑著说道：承让！",
	"$N胜了这招，向後跃开三尺，笑道：承让！",
	"$n脸色微变，说道：佩服，佩服！",
	"$n向後退了几步，说道：这场比试算我输了，佩服，佩服！",
	"$n向後一纵，躬身做揖说道：阁下武艺不凡，果然高明！",
]

## adm/daemons/combatd.c do_attack(), the two riposte lines.
const QUICK_COUNTER: String = "$N一击不中，露出了破绽！"
const RIPOSTE_COUNTER: String = "$N见$n攻击失误，趁机发动攻击！"

## SKILL_D(dodge_skill)->query_dodge_msg(): the mapped dodge skill's lines
## (skills.json), combatd.c falling back to "dodge" when none is mapped. A mapped
## skill without lines of its own reads dodge.c's.
static func dodge_messages(dodge_skill_id: StringName) -> Array[String]:
	var catalog: ContentCatalog = GameContent.catalog()
	var skill: SkillDefinition = catalog.skill(dodge_skill_id) if not dodge_skill_id.is_empty() else null
	if skill != null and not skill.dodge_messages.is_empty():
		return skill.dodge_messages.duplicate()
	return catalog.skill(&"dodge").dodge_messages.duplicate()


## SKILL_D("parry")->query_parry_msg(weapon), weapon being the attacker's: combatd.c
## always asks parry.c, whatever parry is mapped to.
static func parry_messages(attacker_armed: bool) -> Array[String]:
	var parry: SkillDefinition = GameContent.catalog().skill(&"parry")
	return (parry.parry_messages_armed if attacker_armed else parry.parry_messages_unarmed).duplicate()


## combatd.c damage_msg(damage, type). "□伤" is the source's own case label
## (a character lost in the Big5 conversion) and is kept as written.
static func damage_message(damage: int, type: String) -> String:
	if damage == 0:
		return "结果没有造成任何伤害。"
	match type:
		"□伤", "割伤":
			if damage < 10: return "结果只是轻轻地划破$p的皮肉。"
			if damage < 20: return "结果在$p$l划出一道细长的血痕。"
			if damage < 40: return "结果「嗤」地一声划出一道伤口！"
			if damage < 80: return "结果「嗤」地一声划出一道血淋淋的伤口！"
			if damage < 160: return "结果「嗤」地一声划出一道又长又深的伤口，溅得$N满脸鲜血！"
			return "结果只听见$n一声惨嚎，$w已在$p$l划出一道深及见骨的可怕伤口！！"
		"刺伤":
			if damage < 10: return "结果只是轻轻地刺破$p的皮肉。"
			if damage < 20: return "结果在$p$l刺出一个创口。"
			if damage < 40: return "结果「噗」地一声刺入了$n$l寸许！"
			if damage < 80: return "结果「噗」地一声刺进$n的$l，使$p不由自主地退了几步！"
			if damage < 160: return "结果「噗嗤」地一声，$w已在$p$l刺出一个血肉□糊的血窟窿！"
			return "结果只听见$n一声惨嚎，$w已在$p的$l对穿而出，鲜血溅得满地！！"
		"瘀伤":
			if damage < 10: return "结果只是轻轻地碰到，比拍苍蝇稍微重了点。"
			if damage < 20: return "结果在$p的$l造成一处瘀青。"
			if damage < 40: return "结果一击命中，$n的$l登时肿了一块老高！"
			if damage < 80: return "结果一击命中，$n闷哼了一声显然吃了不小的亏！"
			if damage < 120: return "结果「砰」地一声，$n退了两步！"
			if damage < 160: return "结果这一下「砰」地一声打得$n连退了好几步，差一点摔倒！"
			if damage < 240: return "结果重重地击中，$n「哇」地一声吐出一口鲜血！"
			return "结果只听见「砰」地一声巨响，$n像一捆稻草般飞了出去！！"
	# Any other type: the degree, then the type ({type}, damage_type_word()) and "！".
	if damage < 10: return "结果只是勉强造成一处轻微{type}！"
	if damage < 20: return "结果造成轻微的{type}！"
	if damage < 30: return "结果造成一处{type}！"
	if damage < 50: return "结果造成一处严重{type}！"
	if damage < 80: return "结果造成颇为严重的{type}！"
	if damage < 120: return "结果造成相当严重的{type}！"
	if damage < 170: return "结果造成十分严重的{type}！"
	if damage < 230: return "结果造成极其严重的{type}！"
	return "结果造成非常可怕的严重{type}！"


## The {type} of a damage_message() line: the action's damage type, or 伤害.
static func damage_type_word(type: String) -> String:
	return "伤害" if type.is_empty() else type


## combatd.c eff_status_msg(eff_kee * 100 / max_kee): after a wound.
static func effective_status_message(ratio: int) -> String:
	if ratio == 100: return "看起来气血充盈，并没有受伤。"
	if ratio > 95: return "似乎受了点轻伤，不过光从外表看不大出来。"
	if ratio > 90: return "看起来可能受了点轻伤。"
	if ratio > 80: return "受了几处伤，不过似乎并不碍事。"
	if ratio > 60: return "受伤不轻，看起来状况并不太好。"
	if ratio > 40: return "气息粗重，动作开始散乱，看来所受的伤著实不轻。"
	if ratio > 30: return "已经伤痕累累，正在勉力支撑著不倒下去。"
	if ratio > 20: return "受了相当重的伤，只怕会有生命危险。"
	if ratio > 10: return "伤重之下已经难以支撑，眼看就要倒在地上。"
	if ratio > 5: return "受伤过重，已经奄奄一息，命在旦夕了。"
	return "受伤过重，已经有如风中残烛，随时都可能断气。"


## combatd.c status_msg(kee * 100 / max_kee): after a blow that did not wound.
static func status_message(ratio: int) -> String:
	if ratio == 100: return "看起来充满活力，一点也不累。"
	if ratio > 95: return "似乎有些疲惫，但是仍然十分有活力。"
	if ratio > 90: return "看起来可能有些累了。"
	if ratio > 80: return "动作似乎开始有点不太灵光，但是仍然有条不紊。"
	if ratio > 60: return "气喘嘘嘘，看起来状况并不太好。"
	if ratio > 40: return "似乎十分疲惫，看来需要好好休息了。"
	if ratio > 30: return "已经一副头重脚轻的模样，正在勉力支撑著不倒下去。"
	if ratio > 20: return "看起来已经力不从心了。"
	if ratio > 10: return "摇头晃脑、歪歪斜斜地站都站不稳，眼看就要倒在地上。"
	return "已经陷入半昏迷状态，随时都可能摔倒晕去。"


## adm/simul_efun/gender.c gender_pronoun(): how others are named in third person.
static func pronoun(gender: StringName) -> String:
	if gender == CharacterState.GENDER_MALE or gender == &"中性神":
		return "他"
	if gender == CharacterState.GENDER_FEMALE:
		return "她"
	return "它"
