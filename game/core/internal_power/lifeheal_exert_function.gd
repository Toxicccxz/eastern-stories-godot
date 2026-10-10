class_name LifehealExertFunction
extends ExertFunction

## daemon/class/bonze/lotusforce/lifeheal.c (exert lifeheal <someone>): neither side in a
## fight, 150 force above max_force, the target's eff_kee at least a fifth of its max_kee;
## then its two lines, the target's eff_kee cured by 10 + query_skill("force") / 3, 150
## force off and force_factor back to 0. Its 震□ is 震荡 (the character lost, DECISIONS
## 山烟寺 B). ES2's exert without a target worked on oneself; the game offers it only on
## the selected NPC (owner, 疗伤他人: doc/skill/lotusforce 医治他人所受的伤).
const COST: int = 150
const DIVISOR: int = 3
const LINES: Array[String] = [
	"$N坐了下来运起内功，将手掌贴在$n背心，缓缓地将真气输入$n体内....",
	"过了不久，$N额头上冒出豆大的汗珠，$n吐出一口瘀血，脸色看起来红润多了。",
]


func _init() -> void:
	id = &"lifeheal"
	targets_other = true


func exert(context: ExertContext) -> bool:
	var target: SpecialSide = context.target
	if target == null:
		context.fail_line = _t("你要用真气为谁疗伤？")
		return false
	if context.is_fighting or (target.relationship != null and target.relationship.is_fighting()):
		context.fail_line = _t("战斗中无法运功疗伤！")
		return false
	var force: CharacterInternalResourceState = context.character.recovery.inner_force
	if force.current - force.maximum < COST:
		context.fail_line = _t("你的真气不够。")
		return false
	var kee: CharacterResourceState = target.state.vitality
	@warning_ignore("integer_division")
	if kee.effective < kee.maximum / 5:
		# TRANSLATORS: lifeheal.c's refusal: {name} the one too badly hurt for it.
		context.fail_line = _t("{name}已经受伤过重，经受不起你的真气震荡！").format({"name": context.target_name})
		return false
	for line: String in LINES:
		context.vision_at(target, line, ColoredLine.HIY, context.target_name)
	@warning_ignore("integer_division")
	kee.cure(10 + context.force_level / DIVISOR)
	force.current -= COST
	context.character.attributes.force_factor = 0
	return true
