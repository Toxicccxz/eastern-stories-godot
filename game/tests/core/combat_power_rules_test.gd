extends RefCounted

## 战斗决策层 1A (DECISIONS「战斗数值」): the combat power knobs. At ES2's values every draw
## and number of combatd.c's do_attack() stays as it was; the MODERN curve is Elo's shape
## (every power_doubling_levels doubles the odds), the defender's power is discounted, and
## the experience defense is one bounded reduction with no draw.

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_classic_is_es2()
	_test_modern_curve()
	_test_defense_discount()
	_test_experience_defense_percent()
	_test_resolver_classic_unchanged()
	_test_resolver_modern()
	_test_records_and_presets()
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _power(level: int, exp: int = 0, sen: int = 0, max_sen: int = 0, rules: CombatPowerRules = null, defense: bool = false) -> int:
	return CombatMath.skill_power(CombatSkillPowerInput.new(true, level, 0, exp, max_sen, sen), rules, defense)


func _modern(doubling: int = 10, base: int = 100, divisor: int = 4, defense_percent: int = 50, max_percent: int = 40, softness: int = 200) -> CombatPowerRules:
	return CombatPowerRules.new(CombatPowerRules.PowerCurve.MODERN, base, doubling, divisor, defense_percent, CombatPowerRules.ExperienceDefense.MODERN, max_percent, softness)


func _test_classic_is_es2() -> void:
	var classic: CombatPowerRules = CombatPowerRules.classic()
	_assert_true(classic.is_classic() and classic.is_valid(), "the bare rules are ES2's")
	for level: int in [0, 1, 10, 30, 120]:
		for exp: int in [0, 150, 20000]:
			_assert_eq(_power(level, exp, 0, 0, classic), _power(level, exp), "classic rules change nothing: level %d exp %d" % [level, exp])
			_assert_eq(_power(level, exp, 50, 100, classic, true), _power(level, exp, 50, 100), "nor for a defender with sen: level %d" % level)
	_assert_eq([_power(0, 300), _power(10), _power(30, 7), _power(120)], [150, 333, 9007, 576000], "combatd.c: exp / 2 at level 0, level³ / 3 + exp")
	_assert_eq(_power(10, 0, 50, 100), 150, "scaled by sen / max_sen before the exp: 333 / 100 × 50")


func _test_modern_curve() -> void:
	var rules: CombatPowerRules = _modern()
	_assert_eq([_power(0, 0, 0, 0, rules), _power(10, 0, 0, 0, rules), _power(20, 0, 0, 0, rules), _power(30, 0, 0, 0, rules), _power(40, 0, 0, 0, rules)], [100, 200, 400, 800, 1600], "every 10 levels doubles")
	_assert_eq(_power(5, 0, 0, 0, rules), 141, "between: 100 × 2^0.5")
	_assert_eq(_power(0, 150, 0, 0, rules), 137, "exp / 4 added")
	_assert_eq(_power(10, 100, 50, 100, rules), 125, "sen / max_sen scales the curve, not the exp: 200 / 2 + 25")
	_assert_eq(_power(10, 0, 0, 0, _modern(20, 50)), 71, "doubling levels and base are the knobs: 50 × 2^0.5")
	_assert_eq([_power(150, 0, 0, 0, rules), _power(300, 0, 0, 0, rules), _power(225, 0, 0, 0, rules)], [3276800, 6553600, 4915200], "above power_cap_levels 150 the curve goes on linearly: 300 is twice 150")
	_assert_true(_power(300, 20000000, 1000000, 1000000, rules) < 2147483647, "a master's bound stays within random()'s reach")
	var odds: float = float(_power(10, 0, 0, 0, rules)) / float(_power(10, 0, 0, 0, rules) + _power(0, 0, 0, 0, rules))
	_assert_true(absf(odds - 2.0 / 3.0) < 0.001, "10 levels up: 67 / 33 (%f)" % odds)
	_assert_eq(_power(0, 0, 0, 0, rules, false), 100, "not living is 0, living level 0 is the base")
	_assert_eq(CombatMath.skill_power(CombatSkillPowerInput.new(false, 10, 0, 0, 0, 0), rules), 0, "not living: 0 under the modern curve too")


func _test_defense_discount() -> void:
	var rules: CombatPowerRules = _modern()
	_assert_eq(_power(10, 0, 0, 0, rules, true), 100, "a defender's 200 at 50 %")
	_assert_eq(_power(10, 0, 0, 0, _modern(10, 100, 4, 100), true), 200, "100 %: untouched")
	var classic_discounted := CombatPowerRules.new(CombatPowerRules.PowerCurve.CLASSIC, 100, 10, 1, 50)
	_assert_eq(_power(10, 0, 0, 0, classic_discounted, true), 166, "the discount works on the classic curve too (333 / 2)")
	_assert_eq(_power(10, 0, 0, 0, classic_discounted, false), 333, "and never on the attacker")


func _test_experience_defense_percent() -> void:
	var rules: CombatPowerRules = _modern()
	_assert_eq([rules.experience_defense_percent(0, 0), rules.experience_defense_percent(600, 100), rules.experience_defense_percent(100, 100)], [0, 0, 0], "no gap, or the attacker ahead: nothing")
	_assert_eq(rules.experience_defense_percent(0, 600), 40, "0 against 600: 600 / 800 = 75 %, capped at 40")
	_assert_eq(rules.experience_defense_percent(100, 400), 40, "100 against 400: 300 / 700 = 42 %, capped")
	_assert_eq(rules.experience_defense_percent(1000, 1200), 8, "1000 against 1200: 200 / 2400")
	_assert_eq(_modern(10, 100, 4, 50, 0).experience_defense_percent(0, 600), 0, "max 0: none")


func _input(attacker_exp: int, defender_exp: int, attack_level: int, dodge_level: int, rules: CombatPowerRules = null, apply_damage: int = 40) -> CombatAttackInput:
	return CombatAttackInput.new(
		CombatAttackerSnapshot.new(
			&"attacker-1", true, attacker_exp, 0, 0, &"unarmed", attack_level, 0, apply_damage,
			CombatStrengthProjection.new(0, 0, 0), false, &"", CombatHitPolicyStatus.Value.NOT_APPLICABLE,
			&"", CombatHitPolicyStatus.Value.NOT_APPLICABLE, CombatHitPolicyStatus.Value.PROVEN_NO_AUTHORED_EFFECT, null, &"force", 0,
		),
		CombatDefenderSnapshot.new(&"defender-1", true, false, defender_exp, 0, 0, dodge_level, 0, 0, 0, 0, false, [&"头"]),
		CombatActionDefinition.new(&"ordinary-action", 0, 0, &"伤害"),
		null, rules,
	)


func _resolve(input: CombatAttackInput, draws: Array[int]) -> Array:
	var vitality := CharacterResourceState.new(100, 100, 100)
	var rng := ScriptedCombatRandomSource.new(draws)
	var result: CombatAttackResult = CombatAttackResolver.resolve(input, CharacterResourceState.new(100, 100, 100), vitality, CharacterResourceState.new(100, 100, 100), rng)
	return [result, rng.requested_bounds(), vitality.current]


## The same draws, bounds and damage with the classic rules as with none.
func _test_resolver_classic_unchanged() -> void:
	# ap 333 against dp 602 (2 + exp 600) and pp 300 (exp / 2): both passed, then the loop once.
	var draws: Array[int] = [0, 900, 600, 30, 5, 0, 0]
	var bare: Array = _resolve(_input(0, 600, 10, 2), draws)
	var classic: Array = _resolve(_input(0, 600, 10, 2, CombatPowerRules.classic()), draws)
	_assert_eq(classic[1], bare[1], "classic rules: the same bounds %s" % [bare[1]])
	_assert_eq(classic[2], bare[2], "and the same kee left")
	var result: CombatAttackResult = bare[0]
	_assert_true(result.outcome == CombatAttackResult.Outcome.HIT and result.calculation.defense_iterations == 1, "the fixture lands and loops once: %s" % [bare[1]])


func _test_resolver_modern() -> void:
	var rules: CombatPowerRules = _modern()
	# 10 against dodge 2 with 600 exp under the modern curve: ap 200; dp (115 + 150) × 50 % =
	# 132; parry (unarmed 0: 100 + 150) × 50 % = 125; the damage draw, then no defense draw.
	var modern: Array = _resolve(_input(0, 600, 10, 2, rules), [0, 200, 200, 30])
	var result: CombatAttackResult = modern[0]
	_assert_eq(modern[1], [1, 332, 325, 40], "limb, dodge, parry, damage: no experience draw %s" % [modern[1]])
	_assert_true(result.outcome == CombatAttackResult.Outcome.HIT, "it lands")
	# (40 + 30) / 2 = 35, 40 % off (0 against 600) = 21.
	_assert_eq([result.calculation.defense_iterations, result.calculation.defense_factor_at_exit, result.calculation.requested_damage, modern[2]], [1, 40, 21, 79], "one bounded reduction: 35 → 21")
	var even: Array = _resolve(_input(600, 600, 10, 2, rules), [0, 200, 200, 30])
	var even_result: CombatAttackResult = even[0]
	_assert_eq([even_result.calculation.defense_iterations, even_result.calculation.requested_damage], [0, 35], "no gap: the blow whole, nothing counted")
	var classic_loop: Array = _resolve(_input(0, 600, 10, 2, CombatPowerRules.classic()), [0, 900, 600, 30, 599, 299, 149, 74, 36, 17, 8, 3, 1, 0, 0])
	var looped: CombatAttackResult = classic_loop[0]
	_assert_true(looped.calculation.defense_iterations >= 8 and looped.calculation.requested_damage <= 2, "combatd.c's loop against 600 leaves a few percent (%d after %d)" % [looped.calculation.requested_damage, looped.calculation.defense_iterations])


func _test_records_and_presets() -> void:
	var errors: Array[String] = []
	var bare: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000}, "p", errors))
	_assert_true(bare.combat_rules().is_classic() and not bare.combat_forecast and bare.es2_npc_values and errors.is_empty(), "a record without the knobs: ES2 throughout")
	var read: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({
		"combat_round_ms": 1000, "power_curve": "modern", "power_base": 100, "power_doubling_levels": 10, "power_cap_levels": 150, "exp_power_divisor": 4,
		"defense_power_percent": 50, "experience_defense": "modern", "exp_defense_max_percent": 40, "exp_defense_softness": 200,
		"combat_forecast": true, "es2_npc_values": false,
	}, "p", errors))
	var rules: CombatPowerRules = read.combat_rules()
	_assert_true(errors.is_empty() and rules.curve == CombatPowerRules.PowerCurve.MODERN and rules.power_cap_levels == 150 and rules.exp_power_divisor == 4 and rules.defense_power_percent == 50 and rules.experience_defense == CombatPowerRules.ExperienceDefense.MODERN and rules.exp_defense_max_percent == 40 and read.combat_forecast and not read.es2_npc_values, "the knobs are read: %s" % [errors])
	var copied: PacingDefinition = read.copy()
	_assert_true(copied.combat_rules().curve == CombatPowerRules.PowerCurve.MODERN and copied.combat_forecast and not copied.es2_npc_values, "copy() keeps them")
	var classic: PacingDefinition = PacePresets.of(read, CharacterState.PACE_CLASSIC)
	_assert_true(classic.combat_rules().is_classic() and not classic.combat_forecast and classic.es2_npc_values, "经典 puts the fight back at ES2's")
	_assert_true(PacePresets.of(read, CharacterState.PACE_MODERN) == read, "现代 leaves the record")
	var broken: Array[String] = []
	PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000, "power_curve": "steep", "exp_defense_max_percent": 100}, "p", broken))
	_assert_eq(broken.size(), 2, "an unknown curve and a whole-blow defense are refused: %s" % [broken])
	var production: PacingDefinition = GameContent.catalog().pacing()
	_assert_true(production.combat_rules().curve == CombatPowerRules.PowerCurve.MODERN and production.combat_forecast and not production.es2_npc_values, "pacing.json: the modern fight is the default")


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
