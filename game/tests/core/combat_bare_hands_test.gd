extends RefCounted

## 空手对兵器 (DECISIONS「空手对兵器」): combatd.c do_attack() (4) gives a bare-handed defender no
## parry against a weapon (pp = 0), doubles an armed defender's parry against bare hands (pp *= 2),
## and a bare-handed blow has no weapon share. CombatPowerRules' three knobs set those (ES2's values
## left out: 0, 200, 0); the resolver and the 战前预判 read the same knobs.

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_records()
	_test_parry_power()
	_test_resolver()
	_test_forecast()
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


## ES2's power curve with the bare-hand knobs at `parry`, `armed`, `damage`.
func _rules(parry: int = 0, armed: int = 200, damage: int = 0) -> CombatPowerRules:
	return CombatPowerRules.classic().with_bare_hands(parry, armed, damage)


## The player is the bare-handed side (the attacker when both or neither are): `trained` their
## hands have a fist art enabled; `player_fight` false: two NPCs.
func _input(rules: CombatPowerRules, weapon: bool, defender_weapon: bool, attack_level: int = 20, dodge_level: int = 0, parry_level: int = 10, unarmed_level: int = 10, apply_damage: int = 20, exp: int = 0, trained: bool = true, player_fight: bool = true) -> CombatAttackInput:
	var profile: WeaponCombatProfile = WeaponCombatProfile.new(&"sword-1", &"sword", CombatHitPolicyStatus.Value.PROVEN_NO_AUTHORED_EFFECT) if weapon else null
	var attacker := CombatAttackerSnapshot.new(
			&"attacker-1", true, exp, 0, 0, &"sword" if weapon else &"unarmed", attack_level, 0, apply_damage,
			CombatStrengthProjection.new(0, 0, 0), false, &"", CombatHitPolicyStatus.Value.NOT_APPLICABLE,
			&"", CombatHitPolicyStatus.Value.NOT_APPLICABLE,
			CombatHitPolicyStatus.Value.NOT_APPLICABLE if weapon else CombatHitPolicyStatus.Value.PROVEN_NO_AUTHORED_EFFECT, profile, &"force", 0,
	)
	var defender := CombatDefenderSnapshot.new(&"defender-1", true, false, exp, 0, 0, dodge_level, parry_level, unarmed_level, 0, 0, defender_weapon, [&"头"])
	var player_defends: bool = weapon and not defender_weapon
	attacker.player = player_fight and not player_defends
	defender.player = player_fight and player_defends
	attacker.trained_bare_hands = attacker.player and trained and not weapon
	defender.trained_bare_hands = defender.player and trained and not defender_weapon
	return CombatAttackInput.new(attacker, defender, CombatActionDefinition.new(&"ordinary-action", 0, 0, &"伤害"), null, rules)


## The resolver's draw bounds: [limb, dodge, parry, damage, ...]; every gate passed.
func _bounds(input: CombatAttackInput) -> Array[int]:
	var rng := ScriptedCombatRandomSource.new([0, 2000, 2600, 0, 0, 0, 0, 0, 0, 0])
	CombatAttackResolver.resolve(input, CharacterResourceState.new(100, 100, 100), CharacterResourceState.new(100, 100, 100), CharacterResourceState.new(100, 100, 100), rng)
	return rng.requested_bounds()


func _test_records() -> void:
	var classic: CombatPowerRules = CombatPowerRules.classic()
	_assert_eq([classic.bare_parry_percent, classic.armed_parry_percent, classic.bare_damage_percent], [0, 200, 0], "ES2's: no parry bare against a weapon, a weapon's doubled against bare hands, no bare share")
	_assert_true(classic.is_classic() and not _rules(100).is_classic() and not _rules(0, 100).is_classic() and not _rules(0, 200, 50).is_classic(), "any of the three off ES2's is not classic")
	var copied: CombatPowerRules = _rules(150, 100, 100).duplicate_snapshot()
	_assert_eq([copied.bare_parry_percent, copied.armed_parry_percent, copied.bare_damage_percent], [150, 100, 100], "copied with the record")
	_assert_true(not _rules(-1).is_valid() and not _rules(0, -1).is_valid() and not _rules(0, 200, -1).is_valid(), "negative knobs are not valid")
	var errors: Array[String] = []
	var bare: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000}, "p", errors))
	var read: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000, "bare_parry_percent": 150, "armed_parry_percent": 100, "bare_damage_percent": 100}, "p", errors))
	_assert_true(errors.is_empty() and bare.combat_rules().armed_parry_percent == 200 and bare.combat_rules().bare_parry_percent == 0 and bare.combat_rules().bare_damage_percent == 0, "left out of pacing.json: ES2's")
	_assert_eq([read.combat_rules().bare_parry_percent, read.combat_rules().armed_parry_percent, read.combat_rules().bare_damage_percent, read.copy().combat_rules().bare_damage_percent], [150, 100, 100, 100], "read from pacing.json and copied")
	var production: CombatPowerRules = GameContent.catalog().pacing().combat_rules()
	_assert_eq([production.bare_parry_percent, production.armed_parry_percent, production.bare_damage_percent], [MODERN_PARRY, MODERN_ARMED, MODERN_DAMAGE], "pacing.json: the modern values")
	var previous: PacingDefinition = Es2Pacing.use_combat()
	var es2: CombatPowerRules = GameContent.catalog().pacing().combat_rules()
	Es2Pacing.restore(previous)
	_assert_eq([es2.bare_parry_percent, es2.armed_parry_percent, es2.bare_damage_percent], [0, 200, 0], "Es2Pacing.use_combat(): ES2's for the suites that pin combatd.c")

## pacing.json's values (DECISIONS「空手对兵器」).
const MODERN_PARRY: int = 100
const MODERN_ARMED: int = 100
const MODERN_DAMAGE: int = 120


func _test_parry_power() -> void:
	var es2: CombatPowerRules = CombatPowerRules.classic()
	_assert_eq([es2.parry_power(true, true, 300, 50), es2.parry_power(true, false, 300, 50), es2.parry_power(false, true, 300, 50), es2.parry_power(false, false, 300, 50)], [300, 600, 0, 50], "ES2: armed against a weapon its parry, against bare hands doubled; bare against a weapon none, against bare hands its unarmed")
	var modern: CombatPowerRules = _rules(150, 100, 0)
	_assert_eq([modern.parry_power(true, true, 300, 50), modern.parry_power(true, false, 300, 50), modern.parry_power(false, true, 300, 50), modern.parry_power(false, false, 300, 50)], [300, 300, 75, 50], "150 / 100: bare against a weapon half again its unarmed, a weapon against bare hands not doubled")
	_assert_eq([_rules(0, 200, 100).bare_damage(false, 37), _rules(0, 200, 100).bare_damage(true, 37), _rules(0, 200, 60).bare_damage(false, 40), CombatPowerRules.classic().bare_damage(false, 40)], [37, 0, 24, 0], "the bare share: the percent of the unarmed level, none with a weapon or at ES2's")


func _test_resolver() -> void:
	# Classic curve: level 20 is 2666, level 10 is 333, level 0 with no exp is 0.
	var es2: CombatPowerRules = CombatPowerRules.classic()
	var modern: CombatPowerRules = _rules(150, 100, 100)
	_assert_eq(_bounds(_input(es2, false, true)).slice(0, 4), [1, 2667, 2666 + 666, 20], "ES2, bare hands on a sword: its parry doubled (333 × 2), the blow apply/damage alone")
	_assert_eq(_bounds(_input(modern, false, true)).slice(0, 4), [1, 2667, 2666 + 333, 40], "modern: the parry as against a weapon, the blow apply/damage + the unarmed level (20)")
	_assert_eq(_bounds(_input(es2, true, false)).slice(0, 3), [1, 2667, 2666 + 1], "ES2, a sword on bare hands: no parry (0, at least 1)")
	_assert_eq(_bounds(_input(modern, true, false)).slice(0, 4), [1, 2667, 2666 + 499, 20], "modern: bare hands parry a sword at 150 % of their unarmed (333 → 499); the sword's blow untouched")
	_assert_eq(_bounds(_input(modern, true, true)), _bounds(_input(es2, true, true)), "sword on sword: nothing changes")
	_assert_eq(_bounds(_input(modern, false, false)), _bounds(_input(_rules(150, 100, 0), false, false)).slice(0, 3) + [40] + _bounds(_input(modern, false, false)).slice(4), "bare on bare: the unarmed parry as ES2's; only the bare share added")
	# The other way round in the player's fights: an NPC's bare hands on the player's sword, the
	# player's sword on an NPC's bare hands.
	var npc_fist: CombatAttackInput = _input(modern, false, true, 20, 0, 10, 10, 20, 0, false)
	var attacker: CombatAttackerSnapshot = npc_fist.attacker
	var defender: CombatDefenderSnapshot = npc_fist.defender
	attacker.player = false
	defender.player = true
	_assert_eq(_bounds(CombatAttackInput.new(attacker, defender, npc_fist.selected_action, null, modern)).slice(0, 4), [1, 2667, 2666 + 333, 20], "an NPC's bare hands on the player's sword: parried as a weapon (333), not doubled; no bare share for an NPC")
	_assert_eq(_bounds(CombatAttackInput.new(attacker, defender, npc_fist.selected_action, null, es2)).slice(0, 3), [1, 2667, 2666 + 666], "ES2: doubled")
	var npc_bare: CombatAttackInput = _input(modern, true, false)
	var sword: CombatAttackerSnapshot = npc_bare.attacker
	var npc: CombatDefenderSnapshot = npc_bare.defender
	sword.player = true
	npc.player = false
	npc.trained_bare_hands = false
	_assert_eq(_bounds(CombatAttackInput.new(sword, npc, npc_bare.selected_action, null, modern)).slice(0, 3), [1, 2667, 2666 + 499], "the player's sword on an NPC's bare hands: parried at the bare percent too")
	# The player's untrained hands: parried and parrying evenly, but no bare share.
	_assert_eq(_bounds(_input(modern, false, true, 20, 0, 10, 10, 20, 0, false)).slice(0, 4), [1, 2667, 2666 + 333, 20], "untrained bare hands on a sword: parried as a weapon, no bare share")
	_assert_eq(_bounds(_input(modern, true, false, 20, 0, 10, 10, 20, 0, false)).slice(0, 3), [1, 2667, 2666 + 499], "a sword on untrained bare hands: parried at the bare percent")
	# Two NPCs: combatd.c's whatever the knobs say.
	_assert_eq(_bounds(_input(modern, false, true, 20, 0, 10, 10, 20, 0, true, false)).slice(0, 4), [1, 2667, 2666 + 666, 20], "NPC bare hands on an NPC's sword: doubled, no bare share, as ES2")
	_assert_eq(_bounds(_input(modern, true, false, 20, 0, 10, 10, 20, 0, true, false)).slice(0, 3), [1, 2667, 2666 + 1], "an NPC's sword on an NPC's bare hands: no parry, as ES2")


func _test_forecast() -> void:
	var es2: CombatPowerRules = CombatPowerRules.classic()
	var modern: CombatPowerRules = _rules(150, 100, 100)
	_assert_true(absf(CombatForecast.parry_gate(_input(es2, false, true)) - 2666.0 / (2666.0 + 666.0)) < 0.001 and absf(CombatForecast.parry_gate(_input(modern, false, true)) - 2666.0 / (2666.0 + 333.0)) < 0.001, "the forecast's parry gate follows the knobs (bare on a sword)")
	_assert_true(absf(CombatForecast.parry_gate(_input(modern, true, false)) - 2666.0 / (2666.0 + 499.0)) < 0.001, "and a sword on bare hands")
	_assert_true(CombatForecast.expected_damage(_input(modern, false, true)) > CombatForecast.expected_damage(_input(es2, false, true)), "and the bare share in the expected damage")
	# A bare-handed player against an armed one a little stronger: under ES2's rules it reads as a
	# loss and the bare hands are why; with the hands evened (the modern knobs) the reason is not them.
	var me_es2: CombatAttackInput = _input(es2, false, true, 12, 12, 12, 12, 20)
	var them_es2: CombatAttackInput = _input(es2, true, false, 13, 12, 12, 12, 25)
	var lost: CombatForecast = CombatForecast.estimate([me_es2], [them_es2], [150], 150)
	_assert_true(lost.verdict >= CombatForecast.Verdict.UNFAVOURED and lost.reason == CombatForecast.Reason.WEAPON_PARRY, "ES2: bare hands against a blade read as the loss's reason: %s / %s" % [CombatForecast.Verdict.find_key(lost.verdict), CombatForecast.Reason.find_key(lost.reason)])
	_assert_true(lost.line().contains("空手难以近身"), "the line says so: %s" % lost.line())
	var evened: CombatForecast = CombatForecast.estimate([_input(modern, false, true, 12, 12, 12, 12, 20)], [_input(modern, true, false, 13, 12, 12, 12, 25)], [150], 150)
	_assert_true(evened.verdict < lost.verdict and evened.reason != CombatForecast.Reason.WEAPON_PARRY, "modern: better, and not for the bare hands: %s / %s" % [CombatForecast.Verdict.find_key(evened.verdict), CombatForecast.Reason.find_key(evened.reason)])
	var heavy_fists: CombatPowerRules = _rules(100, 100, 400)
	var untrained: CombatForecast = CombatForecast.estimate([_input(heavy_fists, false, true, 12, 12, 12, 12, 20, 0, false)], [_input(heavy_fists, true, false, 13, 12, 12, 12, 25, 0, false)], [150], 150)
	_assert_true(untrained.verdict >= CombatForecast.Verdict.UNFAVOURED and untrained.reason == CombatForecast.Reason.WEAPON_PARRY, "modern rules, untrained hands (no bare share): the reason is the bare hands, a fist art would help: %s / %s" % [CombatForecast.Verdict.find_key(untrained.verdict), CombatForecast.Reason.find_key(untrained.reason)])


func _assert_true(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
