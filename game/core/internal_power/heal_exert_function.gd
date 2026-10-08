class_name HealExertFunction
extends ExertFunction

## daemon/class/swordsman/fonxanforce/heal.c: outside a fight, with 50 force above
## max_force and eff_kee at least half of max_kee, 50 force cure eff_kee by
## 10 + query_skill("force") / 5, and force_factor goes back to 0.
const COST: int = 50


func _init() -> void:
	id = &"heal"
	fight_refusal = "战斗中运功疗伤？找死吗？"


func exert(context: ExertContext) -> bool:
	if context.is_fighting:
		context.fail_line = _t(fight_refusal)
		return false
	var force: CharacterInternalResourceState = context.character.recovery.inner_force
	if force.current - force.maximum < COST:
		context.fail_line = _t("你的真气不够。")
		return false
	var kee: CharacterResourceState = context.character.vitality
	@warning_ignore("integer_division")
	if kee.effective < kee.maximum / 2:
		context.fail_line = _t("你已经受伤过重，只怕一运真气便有生命危险！")
		return false
	context.lines.append(ColoredLine.new(_t("你全身放松，坐下来开始运功疗伤。"), ColoredLine.HIW))
	@warning_ignore("integer_division")
	kee.cure(10 + context.force_level / 5)
	force.current -= COST
	context.character.attributes.force_factor = 0
	return true
