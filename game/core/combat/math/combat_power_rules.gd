class_name CombatPowerRules
extends RefCounted

## The knobs 战斗决策层 1A puts on combatd.c's three ratios (DECISIONS「战斗数值」, owner
## 2026-10-31: the fight must follow the player's growth, no cliff, no 老鼠), each with ES2's
## value as its 经典 value; the resolver's draws and formulas stay, these only change what is
## fed to them. A rules record left out (tests built on PacingDefinition.new(), Es2Pacing) is
## ES2 bit for bit.
##
## - curve: skill_power(). CLASSIC is level³ / 3 (+ combat_exp; level 0 is combat_exp / 2),
##   a cliff at the bottom (0 against 10 is 1 against 333). MODERN is Elo's shape:
##   power_base × 2^(level / power_doubling_levels), every `power_doubling_levels` levels
##   doubling the odds, so 10 levels is 67/33 wherever on the ladder, plus combat_exp
##   / exp_power_divisor; both still scaled by sen / max_sen as combatd.c does. Above
##   power_cap_levels the doubling stops and the curve goes on linearly (a master's 300 is
##   twice 150, not 2^15 times), keeping every bound within the driver's random().
## - defense_power_percent: the defender's dodge and parry power are this much of what
##   skill_power() gives before they go into random(ap + dp) and random(ap + pp), so an even
##   match lands about half its blows instead of a quarter (two gates at 50 %). 100: ES2.
## - experience_defense: do_attack()'s `while random(victim exp) > my exp: damage -= damage / 3`.
##   CLASSIC loops (0 against 600 keeps 3 % of a blow). MODERN is one bounded reduction:
##   gap × 100 / (victim exp + my exp + exp_defense_softness) percent, at most
##   exp_defense_max_percent, and no draw.

enum PowerCurve { CLASSIC, MODERN }
enum ExperienceDefense { CLASSIC, MODERN }

const CURVES: Dictionary[String, PowerCurve] = {"classic": PowerCurve.CLASSIC, "modern": PowerCurve.MODERN}
const DEFENSES: Dictionary[String, ExperienceDefense] = {"classic": ExperienceDefense.CLASSIC, "modern": ExperienceDefense.MODERN}

var curve: PowerCurve = PowerCurve.CLASSIC
var power_base: int = 100
var power_doubling_levels: int = 10
var power_cap_levels: int = 150
var exp_power_divisor: int = 1
var defense_power_percent: int = 100
var experience_defense: ExperienceDefense = ExperienceDefense.CLASSIC
var exp_defense_max_percent: int = 0
var exp_defense_softness: int = 200
## 战斗决策层 1B (CombatMoveTags): a move tag's lean and the counter ring's extra, in
## percent at combatd.c's percent sites; 0 (ES2): tags are words only.
var action_tag_bonus_percent: int = 0
var tag_counter_percent: int = 0


func _init(
	p_curve: PowerCurve = PowerCurve.CLASSIC, p_power_base: int = 100, p_power_doubling_levels: int = 10,
	p_exp_power_divisor: int = 1, p_defense_power_percent: int = 100,
	p_experience_defense: ExperienceDefense = ExperienceDefense.CLASSIC,
	p_exp_defense_max_percent: int = 0, p_exp_defense_softness: int = 200, p_power_cap_levels: int = 150,
	p_action_tag_bonus_percent: int = 0, p_tag_counter_percent: int = 0,
) -> void:
	action_tag_bonus_percent = p_action_tag_bonus_percent
	tag_counter_percent = p_tag_counter_percent
	curve = p_curve
	power_base = p_power_base
	power_doubling_levels = p_power_doubling_levels
	power_cap_levels = p_power_cap_levels
	exp_power_divisor = p_exp_power_divisor
	defense_power_percent = p_defense_power_percent
	experience_defense = p_experience_defense
	exp_defense_max_percent = p_exp_defense_max_percent
	exp_defense_softness = p_exp_defense_softness


## ES2's own numbers: what a record without the knobs gets.
static func classic() -> CombatPowerRules:
	return CombatPowerRules.new()


func is_valid() -> bool:
	return (
		power_base > 0 and power_doubling_levels > 0 and power_cap_levels > 0 and exp_power_divisor > 0
		and defense_power_percent > 0 and exp_defense_max_percent >= 0 and exp_defense_max_percent < 100
		and exp_defense_softness >= 0 and action_tag_bonus_percent >= 0 and tag_counter_percent >= 0
	)


## Whether every knob is at ES2's value (the resolver then runs the ported code alone).
func is_classic() -> bool:
	return (
		curve == PowerCurve.CLASSIC and exp_power_divisor == 1 and defense_power_percent == 100
		and experience_defense == ExperienceDefense.CLASSIC
		and action_tag_bonus_percent == 0 and tag_counter_percent == 0
	)


func duplicate_snapshot() -> CombatPowerRules:
	return CombatPowerRules.new(
		curve, power_base, power_doubling_levels, exp_power_divisor, defense_power_percent,
		experience_defense, exp_defense_max_percent, exp_defense_softness, power_cap_levels,
		action_tag_bonus_percent, tag_counter_percent,
	)


## The percent of a blow the MODERN experience defense takes from an attacker with
## `attacker_exp` hitting one with `victim_exp`; 0 when the victim has no more.
func experience_defense_percent(attacker_exp: int, victim_exp: int) -> int:
	var gap: int = victim_exp - attacker_exp
	if gap <= 0:
		return 0
	var total: int = victim_exp + attacker_exp + exp_defense_softness
	if total <= 0:
		return exp_defense_max_percent
	@warning_ignore("integer_division")
	return mini(exp_defense_max_percent, gap * 100 / total)


## From pacing.json's keys on `reader` (each left out is ES2's).
static func from_record(reader: ContentRecordReader) -> CombatPowerRules:
	var curve_text: String = reader.text("power_curve", "classic")
	var defense_text: String = reader.text("experience_defense", "classic")
	if not CURVES.has(curve_text):
		reader.fail("power_curve", "classic or modern")
		curve_text = "classic"
	if not DEFENSES.has(defense_text):
		reader.fail("experience_defense", "classic or modern")
		defense_text = "classic"
	var rules := CombatPowerRules.new(
		CURVES[curve_text], reader.integer("power_base", 100), reader.integer("power_doubling_levels", 10),
		reader.integer("exp_power_divisor", 1), reader.integer("defense_power_percent", 100),
		DEFENSES[defense_text], reader.integer("exp_defense_max_percent", 0), reader.integer("exp_defense_softness", 200),
		reader.integer("power_cap_levels", 150),
		reader.integer("action_tag_bonus_percent", 0), reader.integer("tag_counter_percent", 0),
	)
	if not rules.is_valid():
		reader.fail("power_curve", "the combat power knobs must be positive (exp_defense_max_percent below 100)")
	return rules
