extends RefCounted

## 战前预判 (战斗决策层 1A, DECISIONS「战斗数值」): CombatForecast reads the same attack
## inputs the resolver draws on, without a draw: rounds to fell each other, the verdict
## bands, the reason that weighs most, a gang counted together, a 切磋 by who lands first.

var _assertion_count: int = 0
var _failures: Array[String] = []
var _rules: CombatPowerRules = CombatPowerRules.new(CombatPowerRules.PowerCurve.MODERN, 100, 10, 4, 50, CombatPowerRules.ExperienceDefense.MODERN, 40, 200)


func run_all() -> Dictionary[String, Variant]:
	_test_gates_and_damage()
	_test_verdicts()
	_test_reasons_and_gang()
	_test_spar_and_lines()
	_test_classic_loop_expectation()
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _input(attack_level: int, dodge_level: int, attacker_exp: int = 0, defender_exp: int = 0, apply_damage: int = 20, strength: int = 20, weapon: bool = false, defender_weapon: bool = false, parry_level: int = 0, rules: CombatPowerRules = _rules) -> CombatAttackInput:
	var profile: WeaponCombatProfile = WeaponCombatProfile.new(&"sword-1", &"sword", CombatHitPolicyStatus.Value.PROVEN_NO_AUTHORED_EFFECT) if weapon else null
	return CombatAttackInput.new(
		CombatAttackerSnapshot.new(
			&"attacker-1", true, attacker_exp, 0, 0, &"sword" if weapon else &"unarmed", attack_level, 0, apply_damage,
			CombatStrengthProjection.new(strength, 0, 0), false, &"", CombatHitPolicyStatus.Value.NOT_APPLICABLE,
			&"", CombatHitPolicyStatus.Value.NOT_APPLICABLE,
			CombatHitPolicyStatus.Value.NOT_APPLICABLE if weapon else CombatHitPolicyStatus.Value.PROVEN_NO_AUTHORED_EFFECT, profile, &"force", 0,
		),
		CombatDefenderSnapshot.new(&"defender-1", true, false, defender_exp, 0, 0, dodge_level, parry_level, 0, 0, 0, defender_weapon, [&"头"]),
		CombatActionDefinition.new(&"ordinary-action", 0, 0, &"伤害"),
		null, rules,
	)


func _test_gates_and_damage() -> void:
	var even: CombatAttackInput = _input(10, 10)
	_assert_true(absf(CombatForecast.dodge_gate(even) - 200.0 / 300.0) < 0.001, "even skills: ap 200 against dp 200 × 50 %: 2 / 3 pass the dodge")
	_assert_true(absf(CombatForecast.parry_gate(even) - 200.0 / 250.0) < 0.001, "unarmed parry at level 0: 100 × 50 %")
	_assert_true(absf(CombatForecast.expected_damage(even) - (14.75 + 14.75)) < 0.001, "E[(20 + random(20)) / 2] twice: apply damage and strength")
	var armed: CombatAttackInput = _input(10, 10, 0, 0, 20, 20, true, false)
	_assert_true(absf(CombatForecast.parry_gate(armed) - 200.0 / 201.0) < 0.001, "a weapon against bare hands: pp 0 → 1")
	var against_weapon: CombatAttackInput = _input(10, 10, 0, 0, 20, 20, false, true, 10)
	_assert_true(absf(CombatForecast.parry_gate(against_weapon) - 200.0 / 400.0) < 0.001, "bare hands against a weapon: parry doubled (100 × 2)")
	var gapped: CombatAttackInput = _input(10, 10, 0, 600)
	_assert_true(absf(CombatForecast.experience_multiplier(gapped) - 0.6) < 0.001, "0 against 600 under MODERN: 40 % off")


func _test_verdicts() -> void:
	var even: CombatForecast = CombatForecast.estimate([_input(10, 10)], [_input(10, 10)], [100], 100)
	_assert_eq(even.verdict, CombatForecast.Verdict.EVEN, "mirror images: EVEN (%f / %f)" % [even.rounds_to_win, even.rounds_to_lose])
	_assert_true(absf(even.rounds_to_win - even.rounds_to_lose) < 0.001 and even.rounds_to_win > 5.0 and even.rounds_to_win < 7.0, "about six rounds each way: %f" % even.rounds_to_win)
	var weak: CombatForecast = CombatForecast.estimate([_input(20, 0)], [_input(0, 20)], [40], 100)
	_assert_eq(weak.verdict, CombatForecast.Verdict.SURE_WIN, "20 against 0 with 40 kee: SURE_WIN (%f / %f)" % [weak.rounds_to_win, weak.rounds_to_lose])
	var strong: CombatForecast = CombatForecast.estimate([_input(0, 30, 0, 2000)], [_input(30, 0, 2000, 0, 40, 30)], [200], 100)
	_assert_eq(strong.verdict, CombatForecast.Verdict.SURE_LOSS, "0 against 30 with 2000 exp: SURE_LOSS (%f / %f)" % [strong.rounds_to_win, strong.rounds_to_lose])
	var a_bit: CombatForecast = CombatForecast.estimate([_input(10, 10)], [_input(10, 10)], [70], 100)
	_assert_eq(a_bit.verdict, CombatForecast.Verdict.FAVOURED, "the same fighter with 70 kee against 100: FAVOURED")
	var harmless: CombatForecast = CombatForecast.estimate([_input(10, 10)], [_input(10, 10, 0, 0, 0, 0)], [100], 100)
	_assert_eq([harmless.verdict, harmless.rounds_to_lose], [CombatForecast.Verdict.SURE_WIN, INF], "one that cannot hurt: SURE_WIN, never felled")
	_assert_eq(CombatForecast.estimate([], [], [], 100).verdict, CombatForecast.Verdict.EVEN, "nothing to read: EVEN, 0 enemies")
	_assert_true(absf(CombatForecast.attack_chance(30, 0, 30) - 1.0 / 3.0) < 0.001 and CombatForecast.attack_chance(30, 100, 10) == 1.0 and CombatForecast.attack_chance(30, 0, 0) == 1.0 and CombatForecast.attack_chance(5, 0, 30, true) == 1.0, "fight(): cor + bellicosity / 50 against cps × 3; no composure or a busy victim: always")
	var timid: CombatForecast = CombatForecast.estimate([_input(10, 10)], [_input(10, 10)], [100], 100, [1.0], [1.0 / 3.0])
	# It attacks a third of the rounds and ripostes two thirds of my misses (land 8 / 15).
	var expected: float = even.rounds_to_lose / (1.0 / 3.0 + 2.0 / 3.0 * (1.0 - 8.0 / 15.0))
	_assert_true(timid.verdict == CombatForecast.Verdict.FAVOURED and absf(timid.rounds_to_lose - expected) < 0.001 and absf(timid.rounds_to_win - even.rounds_to_win) < 0.001, "one that attacks a third of the rounds, riposting my misses: FAVOURED (%f against %f)" % [timid.rounds_to_lose, expected])


func _test_reasons_and_gang() -> void:
	var one: CombatForecast = CombatForecast.estimate([_input(10, 10)], [_input(10, 10)], [100], 100)
	var three: CombatForecast = CombatForecast.estimate([_input(10, 10), _input(10, 10), _input(10, 10)], [_input(10, 10), _input(10, 10), _input(10, 10)], [100, 100, 100], 100)
	_assert_true(three.enemies == 3 and three.verdict == CombatForecast.Verdict.SURE_LOSS and three.reason == CombatForecast.Reason.NUMBERS, "three of an even match: SURE_LOSS by numbers (%f / %f)" % [three.rounds_to_win, three.rounds_to_lose])
	_assert_eq(one.reason, CombatForecast.Reason.NONE, "an even single: no reason")
	var dodgy: CombatForecast = CombatForecast.estimate([_input(0, 40)], [_input(0, 0)], [100], 100)
	_assert_eq(dodgy.reason, CombatForecast.Reason.DODGE, "40 dodge against 0: the dodge (land %f)" % dodgy.land_chance)
	var armed_foe: CombatForecast = CombatForecast.estimate([_input(0, 0, 0, 0, 20, 20, false, true, 40)], [_input(0, 0, 0, 0, 20, 20, true)], [100], 100)
	_assert_eq(armed_foe.reason, CombatForecast.Reason.WEAPON_PARRY, "a weapon in their hand, bare hands here: WEAPON_PARRY")
	var veteran: CombatForecast = CombatForecast.estimate([_input(10, 10, 0, 5000)], [_input(10, 10, 5000, 0, 60, 30)], [100], 100)
	_assert_eq(veteran.reason, CombatForecast.Reason.EXPERIENCE, "5000 exp against 0: EXPERIENCE (mult %f)" % CombatForecast.experience_multiplier(_input(10, 10, 0, 5000)))
	var heavy: CombatForecast = CombatForecast.estimate([_input(10, 10)], [_input(10, 10, 0, 0, 200, 200)], [100], 100)
	_assert_eq(heavy.reason, CombatForecast.Reason.DAMAGE, "a blow that fells in a round or two: DAMAGE (%f)" % heavy.rounds_to_lose)
	var my_sword: CombatForecast = CombatForecast.estimate([_input(10, 10, 0, 0, 20, 20, true)], [_input(10, 10)], [80], 100)
	_assert_eq(my_sword.reason, CombatForecast.Reason.MY_WEAPON, "my weapon against bare hands, favoured: MY_WEAPON")


func _test_spar_and_lines() -> void:
	var sharper: CombatForecast = CombatForecast.estimate([_input(20, 10)], [_input(10, 20)], [100], 100)
	_assert_eq(sharper.spar_verdict, CombatForecast.Verdict.FAVOURED, "20 against 10 lands first more often: spar FAVOURED (%f against %f)" % [sharper.land_chance, sharper.enemy_land_chance])
	var even: CombatForecast = CombatForecast.estimate([_input(10, 10)], [_input(10, 10)], [100], 100)
	_assert_eq(even.spar_verdict, CombatForecast.Verdict.EVEN, "mirror images spar EVEN")
	_assert_true(even.line().contains("{pronoun}") and even.line(true).contains("五五开"), "the lines keep {pronoun} for the caller: %s / %s" % [even.line(), even.line(true)])
	var three: CombatForecast = CombatForecast.estimate([_input(10, 10), _input(10, 10), _input(10, 10)], [_input(10, 10), _input(10, 10), _input(10, 10)], [100, 100, 100], 100)
	_assert_true(three.line().contains("{count}") and three.line().begins_with("必败"), "the gang's line names the count: %s" % three.line())
	var outlook := CombatOutlook.new(three.line(), three.enemies, three)
	_assert_eq(outlook.shown("他"), "必败：他远比你强，别打。他这边有 3 个人一起上。", "CombatOutlook fills pronoun and count")
	_assert_eq(CombatOutlook.new().shown("他"), "", "an empty outlook shows nothing")


## combatd.c's loop as an expectation: 0 against 600 keeps a few percent, 600 against 600 all.
func _test_classic_loop_expectation() -> void:
	var classic: CombatPowerRules = CombatPowerRules.classic()
	var gapped: float = CombatForecast.experience_multiplier(_input(10, 10, 0, 600, 20, 20, false, false, 0, classic))
	_assert_true(gapped > 0.01 and gapped < 0.08, "0 against 600: about 3 %% (%f)" % gapped)
	var even: float = CombatForecast.experience_multiplier(_input(10, 10, 600, 600, 20, 20, false, false, 0, classic))
	_assert_true(even > 0.99, "600 against 600: random(600) > 600 never (%f)" % even)
	var none: float = CombatForecast.experience_multiplier(_input(10, 10, 0, 0, 20, 20, false, false, 0, classic))
	_assert_true(none > 0.99, "0 against 0: random(0) is 0 (%f)" % none)


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
