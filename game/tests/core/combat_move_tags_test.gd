extends RefCounted

## 战斗决策层 1B (DECISIONS「战斗决策」): the move tags 快 / 重 / 虚 / 守 and their ring, the
## chosen move taken without a draw, the stance's and the tag's percents at combatd.c's
## percent sites (nothing changes at 0), the knobs read from the record.

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_tags_and_ring()
	_test_action_records()
	_test_chosen_move_draws_nothing()
	_test_resolver_percents()
	_test_records_and_presets()
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _test_tags_and_ring() -> void:
	_assert_true(CombatMoveTags.beats(CombatMoveTags.QUICK, CombatMoveTags.HEAVY) and CombatMoveTags.beats(CombatMoveTags.HEAVY, CombatMoveTags.GUARD) and CombatMoveTags.beats(CombatMoveTags.GUARD, CombatMoveTags.FEINT) and CombatMoveTags.beats(CombatMoveTags.FEINT, CombatMoveTags.QUICK), "快克重、重克守、守克虚、虚克快")
	_assert_true(not CombatMoveTags.beats(CombatMoveTags.HEAVY, CombatMoveTags.QUICK) and not CombatMoveTags.beats(CombatMoveTags.QUICK, CombatMoveTags.NONE) and not CombatMoveTags.beats(CombatMoveTags.NONE, CombatMoveTags.QUICK), "the ring goes one way; 平 beats and is beaten by nothing")
	_assert_eq([CombatMoveTags.attack_percent(CombatMoveTags.QUICK, &"", 15, 15), CombatMoveTags.attack_percent(CombatMoveTags.HEAVY, &"", 15, 15), CombatMoveTags.attack_percent(CombatMoveTags.QUICK, CombatMoveTags.HEAVY, 15, 15)], [15, -15, 30], "quick +p on the attack power, heavy −p, the counter on top")
	_assert_eq([CombatMoveTags.damage_percent(CombatMoveTags.HEAVY, &"", 15, 15), CombatMoveTags.damage_percent(CombatMoveTags.QUICK, &"", 15, 15), CombatMoveTags.damage_percent(CombatMoveTags.FEINT, &"", 15, 15), CombatMoveTags.damage_percent(CombatMoveTags.NONE, &"", 15, 15), CombatMoveTags.damage_percent(CombatMoveTags.HEAVY, CombatMoveTags.GUARD, 15, 15)], [15, -15, -15, 0, 30], "heavy +p on the damage, the other tags −p, 平 nothing, the counter on top")
	_assert_eq([CombatMoveTags.parry_percent(CombatMoveTags.FEINT, 15), CombatMoveTags.parry_percent(CombatMoveTags.GUARD, 15)], [-15, 0], "a feint takes p off the defender's parry")
	_assert_true(CombatMoveTags.is_valid(&"") and CombatMoveTags.is_valid(&"guard") and not CombatMoveTags.is_valid(&"wild"), "tags are the four or none")
	_assert_eq(CombatMoveTags.label(CombatMoveTags.FEINT), "虚", "the one-character label")


func _test_action_records() -> void:
	var errors: Array[String] = []
	var tagged: CombatActionDefinition = CombatActionDefinition.from_record(ContentRecordReader.new({"id": "gu-song", "action": "$N使一招「古松挂月」，对准$n的$l一拳", "damage_type": "瘀伤", "tag": "guard"}, "a", errors), "t/")
	_assert_true(errors.is_empty() and tagged.tag == CombatMoveTags.GUARD and tagged.display_name == "古松挂月", "the tag read, the name from the 「」: %s / %s" % [tagged.display_name, errors])
	var named: CombatActionDefinition = CombatActionDefinition.from_record(ContentRecordReader.new({"id": "punch", "name": "挥拳", "tag": "quick", "action": "$N挥拳攻击$n的$l", "damage_type": "瘀伤"}, "a", errors), "t/")
	_assert_true(errors.is_empty() and named.display_name == "挥拳" and named.tag == CombatMoveTags.QUICK, "a move without 「」 names itself in the data")
	var plain: CombatActionDefinition = CombatActionDefinition.from_record(ContentRecordReader.new({"id": "bite", "action": "$N咬$n的$l", "damage_type": "咬伤"}, "a", errors), "t/")
	_assert_true(errors.is_empty() and plain.tag == CombatMoveTags.NONE and plain.display_name == "", "no tag, no name: 平, unnamed")
	var bad: Array[String] = []
	CombatActionDefinition.from_record(ContentRecordReader.new({"id": "x", "action": "$N打$n", "damage_type": "瘀伤", "tag": "wild"}, "a", bad), "t/")
	_assert_eq(bad.size(), 1, "an unknown tag is refused: %s" % [bad])
	_assert_true(tagged.duplicate_snapshot().tag == CombatMoveTags.GUARD and CombatActionSet.same_action(tagged, tagged.duplicate_snapshot()) and not CombatActionSet.same_action(tagged, plain), "the tag and name survive a copy and count in same_action()")
	_assert_eq(BeastCombatActionDefinitions.bite().tag, CombatMoveTags.QUICK, "beast.c's bite is 快")
	var catalog: ContentCatalog = GameContent.catalog()
	var liuh: SkillDefinition = catalog.skill(&"liuh-ken")
	_assert_true(liuh != null and liuh.action_set().actions().size() == 4 and liuh.action_set().actions().all(func(action: CombatActionDefinition) -> bool: return action.tag != CombatMoveTags.NONE and not action.display_name.is_empty()), "柳家拳's four moves are tagged and named")


func _test_chosen_move_draws_nothing() -> void:
	var moves := CombatActionSet.new([
		CombatActionDefinition.new(&"a", 0, 0, &"瘀伤", &"a", "$N打$n", "", &"", CombatMoveTags.QUICK, "甲"),
		CombatActionDefinition.new(&"b", 0, 0, &"瘀伤", &"b", "$N踢$n", "", &"", CombatMoveTags.HEAVY, "乙"),
	])
	var random := ScriptedCombatRandomSource.new([1, 1])
	var chosen: CombatActionSelectionResult = CombatActionSelector.select_action(CombatActionSelectionInput.new(false, null, false, null, moves, &"b"), random)
	_assert_true(chosen.succeeded and chosen.selected_action.action_id == &"b" and not chosen.random_attempted and random.call_count() == 0, "the chosen move is taken, no random(n)")
	var drawn: CombatActionSelectionResult = CombatActionSelector.select_action(CombatActionSelectionInput.new(false, null, false, null, moves), random)
	_assert_true(drawn.succeeded and drawn.random_attempted and random.call_count() == 1 and drawn.selected_action.action_id == &"b", "without a choice: random(n) as combatd.c")
	var missing: CombatActionSelectionResult = CombatActionSelector.select_action(CombatActionSelectionInput.new(false, null, false, null, moves, &"c"), random)
	_assert_true(missing.succeeded and missing.random_attempted and random.call_count() == 2, "a chosen move not in the set (the weapon changed): drawn as before")


func _input(tag: StringName, rules: CombatPowerRules, defender_tag: StringName = &"", attack_percent: int = 0, damage_percent: int = 0, dodge_percent: int = 0, parry_percent: int = 0) -> CombatAttackInput:
	var attacker := CombatAttackerSnapshot.new(
		&"attacker-1", true, 0, 0, 0, &"unarmed", 10, 0, 40,
		CombatStrengthProjection.new(0, 0, 0), false, &"", CombatHitPolicyStatus.Value.NOT_APPLICABLE,
		&"", CombatHitPolicyStatus.Value.NOT_APPLICABLE, CombatHitPolicyStatus.Value.PROVEN_NO_AUTHORED_EFFECT, null, &"force", 0,
	)
	attacker.attack_power_percent = attack_percent
	attacker.damage_percent_bonus = damage_percent
	var defender := CombatDefenderSnapshot.new(&"defender-1", true, false, 0, 0, 0, 10, 0, 10, 0, 0, false, [&"头"])
	defender.dodge_power_percent = dodge_percent
	defender.parry_power_percent = parry_percent
	defender.move_tag = defender_tag
	return CombatAttackInput.new(attacker, defender, CombatActionDefinition.new(&"move", 0, 0, &"瘀伤", &"move", "$N打$n", "", &"", tag), null, rules)


## The bounds of one HIT: limb, dodge, parry, damage, then the kee it took.
func _resolve(input: CombatAttackInput) -> Array:
	var vitality := CharacterResourceState.new(100, 100, 100)
	# 500 passes both gates in every case here (dp, pp ≤ 400; bounds ≥ 600).
	var rng := ScriptedCombatRandomSource.new([0, 500, 500, 30, 0, 0])
	var result: CombatAttackResult = CombatAttackResolver.resolve(input, CharacterResourceState.new(100, 100, 100), vitality, CharacterResourceState.new(100, 100, 100), rng)
	return [rng.requested_bounds(), 100 - vitality.current, result]


func _test_resolver_percents() -> void:
	# Level 10 against level 10 (unarmed): ap 333, dp 333, pp 333 under the classic curve.
	var classic: CombatPowerRules = CombatPowerRules.classic()
	var plain: Array = _resolve(_input(CombatMoveTags.NONE, classic))
	_assert_eq(plain[0], [1, 666, 666, 40], "classic, 平: combatd.c's bounds")
	_assert_eq(plain[1], 35, "(40 + 30) / 2")
	var tagged_off: Array = _resolve(_input(CombatMoveTags.QUICK, classic, CombatMoveTags.HEAVY))
	_assert_eq(tagged_off, plain.slice(0, 2) + [tagged_off[2]], "at 0 a tag is words only, counter or not")
	var rules := CombatPowerRules.new(CombatPowerRules.PowerCurve.CLASSIC, 100, 10, 1, 100, CombatPowerRules.ExperienceDefense.CLASSIC, 0, 200, 150, 20, 10)
	var quick: Array = _resolve(_input(CombatMoveTags.QUICK, rules))
	_assert_eq([quick[0], quick[1]], [[1, 732, 732, 40], 28], "快 +20 %: ap 399 (bounds 732), damage −20 %: 35 → 28")
	var countered: Array = _resolve(_input(CombatMoveTags.QUICK, rules, CombatMoveTags.HEAVY))
	_assert_eq([countered[0], countered[1]], [[1, 765, 765, 40], 32], "快 against a 重 move: +30 % on the attack power, −10 % on the damage (35 − 3)")
	var heavy: Array = _resolve(_input(CombatMoveTags.HEAVY, rules))
	_assert_eq([heavy[0], heavy[1]], [[1, 600, 600, 40], 42], "重: ap 267 (−20 %), damage +20 %")
	var feint: Array = _resolve(_input(CombatMoveTags.FEINT, rules))
	_assert_eq([feint[0], feint[1]], [[1, 666, 600, 40], 28], "虚: the parry power −20 % (bound 600), damage −20 %")
	var stance: Array = _resolve(_input(CombatMoveTags.NONE, rules, &"", 0, 20, 20, -20))
	_assert_eq([stance[0], stance[1]], [[1, 732, 600, 40], 42], "the round's percents: dodge +20 (bound 732), parry −20 (600), damage +20")
	var no_rules: Array = _resolve(_input(CombatMoveTags.NONE, rules, &"", 0, 0, 0, 0))
	_assert_eq(no_rules.slice(0, 2), plain.slice(0, 2), "zero percents: untouched even with the knobs on")


func _test_records_and_presets() -> void:
	var errors: Array[String] = []
	var bare: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000}, "p", errors))
	var bare_rules: CombatDecisionRules = bare.decision_rules()
	_assert_true(errors.is_empty() and not bare_rules.player_turns and not bare_rules.npc_telegraph and not bare_rules.has_stances() and bare_rules.perform_cooldown_rounds == 0 and bare.combat_rules().action_tag_bonus_percent == 0, "a record without the knobs: ES2's auto-fight")
	var read: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({
		"combat_round_ms": 1000, "player_turns": true, "npc_telegraph": true, "stance_percent": 20, "stance_enforce_percent": 50,
		"perform_cooldown_rounds": 2, "action_tag_bonus_percent": 15, "tag_counter_percent": 15,
	}, "p", errors))
	var rules: CombatDecisionRules = read.decision_rules()
	_assert_true(errors.is_empty() and rules.player_turns and rules.npc_telegraph and rules.stance_percent == 20 and rules.stance_enforce_percent == 50 and rules.perform_cooldown_rounds == 2 and read.combat_rules().action_tag_bonus_percent == 15 and read.combat_rules().tag_counter_percent == 15, "the knobs are read: %s" % [errors])
	_assert_true(read.copy().decision_rules().player_turns and read.copy().combat_rules().tag_counter_percent == 15, "copy() keeps them")
	var classic: PacingDefinition = PacePresets.of(read, CharacterState.PACE_CLASSIC)
	_assert_true(not classic.decision_rules().player_turns and not classic.decision_rules().npc_telegraph and not classic.decision_rules().has_stances() and classic.combat_rules().action_tag_bonus_percent == 0, "经典 puts the decision layer away")
	var production: PacingDefinition = GameContent.catalog().pacing()
	_assert_true(production.decision_rules().player_turns and production.decision_rules().npc_telegraph and production.decision_rules().stance_percent == 20 and production.decision_rules().perform_cooldown_rounds == 2 and production.combat_rules().action_tag_bonus_percent == 15, "pacing.json: the decision layer is the default")
	var side := CombatRoundModifiers.new()
	CombatStance.apply(side.side(&"p"), CombatStance.Value.ATTACK, 20)
	_assert_eq([side.read(&"p").damage_percent, side.read(&"p").dodge_percent, side.read(&"p").parry_percent, side.read(&"p").attack_percent], [20, -20, -20, 0], "攻: damage +p, dodge and parry −p")
	CombatStance.apply(side.side(&"g"), CombatStance.Value.GUARD, 20)
	CombatStance.apply(side.side(&"e"), CombatStance.Value.EVADE, 20)
	_assert_true(side.read(&"g").parry_percent == 20 and side.read(&"g").damage_percent == -20 and side.read(&"e").dodge_percent == 20 and side.read(&"e").attack_percent == -20 and side.read(&"nobody").dodge_percent == 0, "守: parry +p, damage −p; 游走: dodge +p, attack −p; others nothing")


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
