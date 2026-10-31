class_name CombatStance
extends RefCounted

## 姿态 (DECISIONS「战斗决策」): the player's standing lean for the fight, three buttons in
## place of enforce.c's SpinBox under the modern pacing. 攻 ATTACK: damage +p, dodge and
## parry −p, and 加力 to stance_enforce_percent of its limit; 守 GUARD: parry +p, damage −p;
## 游走 EVADE: dodge +p, attack power −p. Set at once, kept until changed, never queued.

enum Value { ATTACK, GUARD, EVADE }

const STORAGE: Dictionary[int, String] = {Value.ATTACK: "attack", Value.GUARD: "guard", Value.EVADE: "evade"}
## TRANSLATORS: the three stance buttons on the battle panel.
const LABELS: Dictionary[int, String] = {Value.ATTACK: "攻", Value.GUARD: "守", Value.EVADE: "游走"}
## TRANSLATORS: what each stance does, for the button's hover.
const DESCRIPTIONS: Dictionary[int, String] = {
	Value.ATTACK: "攻：伤害高，闪躲、招架低；有内功时加力到上限的一半。",
	Value.GUARD: "守：招架高，伤害低。",
	Value.EVADE: "游走：闪躲高，命中低。",
}


static func is_valid(value: int) -> bool:
	return STORAGE.has(value)


static func label(value: int) -> String:
	return TranslationServer.translate(LABELS.get(value, LABELS[Value.ATTACK]))


static func description(value: int) -> String:
	return TranslationServer.translate(DESCRIPTIONS.get(value, DESCRIPTIONS[Value.ATTACK]))


## The stance's percents on `side`, in CombatRoundModifiers' order (attack, damage, dodge, parry).
static func apply(side: CombatRoundModifiers.Fighter, value: int, percent: int) -> void:
	match value:
		Value.ATTACK:
			side.add(0, percent, -percent, -percent)
		Value.GUARD:
			side.add(0, -percent, 0, percent)
		Value.EVADE:
			side.add(-percent, 0, percent, 0)
