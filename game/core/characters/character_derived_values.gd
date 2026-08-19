class_name CharacterDerivedValues
extends RefCounted

## Deterministic race and character formulas extracted from the LPC sources.
## Random default age/attribute generation is intentionally not represented.

const HUMAN_BASE_WEIGHT: int = 40_000
const MONSTER_BASE_WEIGHT: int = 10_000
const WEIGHT_PER_STRENGTH_POINT: int = 2_000
const ENCUMBRANCE_PER_STRENGTH_POINT: int = 5_000


## reference/es2/mudlib/adm/daemons/race/human.c: setup_human()
static func human_maximum_essence(age: int, maximum_atman: int = 0) -> int:
	var result: int
	if age <= 14:
		result = 100
	elif age <= 20:
		result = 100 + (age - 14) * 20
	elif age <= 30:
		result = 220
	elif age <= 60:
		result = 220 - (age - 30) * 5
	else:
		result = 70
	if maximum_atman > 0:
		result += _legacy_int_divide(maximum_atman, 4)
	return result


## reference/es2/mudlib/adm/daemons/race/human.c: setup_human()
static func human_maximum_vitality(age: int, maximum_force: int = 0) -> int:
	var result: int
	if age <= 14:
		result = 100
	elif age <= 20:
		result = 100 + (age - 14) * 20
	else:
		result = 220
	if maximum_force > 0:
		result += _legacy_int_divide(maximum_force, 4)
	return result


## reference/es2/mudlib/adm/daemons/race/human.c: setup_human()
static func human_maximum_spirit(age: int, maximum_mana: int = 0) -> int:
	var result: int
	if age <= 30:
		result = 100
	else:
		result = 100 + (age - 30) * 5
	if maximum_mana > 0:
		result += _legacy_int_divide(maximum_mana, 4)
	return result


## reference/es2/mudlib/adm/daemons/race/monster.c: setup_monster()
static func monster_maximum_essence(age: int) -> int:
	if age <= 3:
		return 50
	if age <= 10:
		return 50 + (age - 3) * 30
	if age <= 60:
		return 260 + (age - 10) * 5
	return 510 + (age - 60)


## reference/es2/mudlib/adm/daemons/race/monster.c: setup_monster()
static func monster_maximum_vitality(age: int) -> int:
	if age <= 10:
		return 100
	if age <= 30:
		return 100 + (age - 10) * 30
	return 700 + (age - 30) * 10


## reference/es2/mudlib/adm/daemons/race/monster.c: setup_monster()
static func monster_maximum_spirit(age: int) -> int:
	if age <= 30:
		return 50
	return 50 + (age - 30) * 10


## race/human.c and race/monster.c use the same strength slope with different
## BASE_WEIGHT constants.
static func human_weight(base_strength: int) -> int:
	return HUMAN_BASE_WEIGHT + (base_strength - 10) * WEIGHT_PER_STRENGTH_POINT


static func monster_weight(base_strength: int) -> int:
	return MONSTER_BASE_WEIGHT + (base_strength - 10) * WEIGHT_PER_STRENGTH_POINT


## reference/es2/mudlib/adm/daemons/chard.c: setup_char()
static func maximum_encumbrance(base_strength: int) -> int:
	return base_strength * ENCUMBRANCE_PER_STRENGTH_POINT


static func _legacy_int_divide(dividend: int, divisor: int) -> int:
	@warning_ignore("integer_division")
	return dividend / divisor
