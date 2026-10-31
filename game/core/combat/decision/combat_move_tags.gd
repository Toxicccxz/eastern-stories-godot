class_name CombatMoveTags
extends RefCounted

## 战斗决策层 1B (DECISIONS「战斗决策」): every attack action may carry one of four tags,
## authored in the data (`tag` on combat_actions.json's and skills.json's actions, the beast
## verbs in code): 快 quick, 重 heavy, 虚 feint, 守 guard; none is 平. The tag's own lean
## (`action_tag_bonus_percent`) and the ring 快克重、重克守、守克虚、虚克快
## (`tag_counter_percent`) feed combatd.c's existing percent sites (CombatAttackResolver),
## nothing else; at 0 they change no number.

const NONE: StringName = &""
const QUICK: StringName = &"quick"
const HEAVY: StringName = &"heavy"
const FEINT: StringName = &"feint"
const GUARD: StringName = &"guard"
const ALL: Array[StringName] = [QUICK, HEAVY, FEINT, GUARD]

## Which tag each beats.
const BEATS: Dictionary[StringName, StringName] = {QUICK: HEAVY, HEAVY: GUARD, GUARD: FEINT, FEINT: QUICK}

## TRANSLATORS: the one-character tag of an attack move on the battle panel and the enemy's card: 快 quick, 重 heavy, 虚 feint, 守 guard, 平 plain.
const LABELS: Dictionary[StringName, String] = {QUICK: "快", HEAVY: "重", FEINT: "虚", GUARD: "守", NONE: "平"}
## TRANSLATORS: what each move tag does, for the move button's hover.
const DESCRIPTIONS: Dictionary[StringName, String] = {
	QUICK: "快：命中高、伤害低；克重招。",
	HEAVY: "重：伤害高、命中低；克守招。",
	FEINT: "虚：对方难以招架、伤害低，打中就打断对方的蓄势；克快招。",
	GUARD: "守：这一回合自己更难被打中，伤害低；克虚招。",
	NONE: "平：没有偏向。",
}


static func is_valid(tag: StringName) -> bool:
	return tag == NONE or ALL.has(tag)


## Whether `tag` beats `other` on the ring.
static func beats(tag: StringName, other: StringName) -> bool:
	return tag != NONE and other != NONE and BEATS.get(tag, NONE) == other


static func label(tag: StringName) -> String:
	return TranslationServer.translate(LABELS.get(tag, LABELS[NONE]))


static func description(tag: StringName) -> String:
	return TranslationServer.translate(DESCRIPTIONS.get(tag, DESCRIPTIONS[NONE]))


## The attacker's attack power percent for `tag` against a defender whose move is
## `other`: quick +p, heavy −p, plus the counter when the ring says so.
static func attack_percent(tag: StringName, other: StringName, bonus: int, counter: int) -> int:
	var percent: int = 0
	if tag == QUICK:
		percent += bonus
	elif tag == HEAVY:
		percent -= bonus
	if beats(tag, other):
		percent += counter
	return percent


## The damage percent for `tag`: heavy +p, the rest −p, plus the counter.
static func damage_percent(tag: StringName, other: StringName, bonus: int, counter: int) -> int:
	var percent: int = 0
	if tag == HEAVY:
		percent += bonus
	elif tag != NONE:
		percent -= bonus
	if beats(tag, other):
		percent += counter
	return percent


## What a feint takes off the defender's parry power.
static func parry_percent(tag: StringName, bonus: int) -> int:
	return -bonus if tag == FEINT else 0
