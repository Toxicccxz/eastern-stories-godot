extends RefCounted

## 空手对兵器 (DECISIONS「空手对兵器」): combatd.c do_attack() (4) gives a bare-handed defender no
## parry against a weapon (pp = 0), doubles an armed defender's parry against bare hands (pp *= 2),
## and a bare-handed blow has no weapon share. CombatPowerRules' knobs set those (ES2's values left
## out: 0, 200, 0): each parry by who parries, the player or the player's foe (owner 2026-11-20:
## only ever in the player's favour); the resolver and the 战前预判 read the same knobs.

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_records()
	_test_parry_power()
	_test_resolver()
	_test_forecast()
	_test_player_half()
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


## ES2's power curve with the bare-hand knobs at `parry`, `armed` (the same on both sides), `damage`.
func _rules(parry: int = 0, armed: int = 200, damage: int = 0) -> CombatPowerRules:
	return CombatPowerRules.classic().with_parries(parry, armed, parry, armed).with_bare_damage(damage)


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
	_assert_eq(_knobs(classic), [0, 200, 0, 200, 0], "ES2's: no parry bare against a weapon, a weapon's doubled against bare hands, no bare share, on either side")
	var one_off: Array[CombatPowerRules] = [
		CombatPowerRules.classic().with_parries(100, 200, 0, 200), CombatPowerRules.classic().with_parries(0, 100, 0, 200),
		CombatPowerRules.classic().with_parries(0, 200, 100, 200), CombatPowerRules.classic().with_parries(0, 200, 0, 100),
		CombatPowerRules.classic().with_bare_damage(50),
	]
	_assert_true(classic.is_classic() and one_off.all(func(rules: CombatPowerRules) -> bool: return not rules.is_classic()), "any of the five off ES2's is not classic")
	var copied: CombatPowerRules = CombatPowerRules.classic().with_parries(150, 120, 30, 100).with_bare_damage(100).duplicate_snapshot()
	_assert_eq(_knobs(copied), [150, 120, 30, 100, 100], "copied with the record")
	_assert_true(not _rules(-1).is_valid() and not _rules(0, -1).is_valid() and not _rules(0, 200, -1).is_valid() and not CombatPowerRules.classic().with_parries(0, 200, -1, 200).is_valid(), "negative knobs are not valid")
	var errors: Array[String] = []
	var bare: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000}, "p", errors))
	var read: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000, "player_bare_parry_percent": 150, "player_armed_parry_percent": 120, "foe_bare_parry_percent": 30, "foe_armed_parry_percent": 100, "bare_damage_percent": 100}, "p", errors))
	_assert_true(errors.is_empty() and _knobs(bare.combat_rules()) == [0, 200, 0, 200, 0], "left out of pacing.json: ES2's")
	_assert_eq([_knobs(read.combat_rules()), _knobs(read.copy().combat_rules())], [[150, 120, 30, 100, 100], [150, 120, 30, 100, 100]], "read from pacing.json and copied")
	var production: CombatPowerRules = GameContent.catalog().pacing().combat_rules()
	_assert_eq(_knobs(production), MODERN, "pacing.json: the modern values")
	var previous: PacingDefinition = Es2Pacing.use_combat()
	var es2: CombatPowerRules = GameContent.catalog().pacing().combat_rules()
	Es2Pacing.restore(previous)
	_assert_eq(_knobs(es2), [0, 200, 0, 200, 0], "Es2Pacing.use_combat(): ES2's for the suites that pin combatd.c")


## [player_bare, player_armed, foe_bare, foe_armed, bare_damage] percent.
func _knobs(rules: CombatPowerRules) -> Array[int]:
	return [rules.player_bare_parry_percent, rules.player_armed_parry_percent, rules.foe_bare_parry_percent, rules.foe_armed_parry_percent, rules.bare_damage_percent]

## pacing.json's values (DECISIONS「空手对兵器」): the player's bare hands parry a weapon, the
## player's weapon parries bare hands doubled (ES2's); a foe's bare hands do not parry the player's
## weapon (ES2's), a foe's weapon parries the player's bare hands undoubled.
const MODERN: Array[int] = [100, 200, 0, 100, 120]


func _test_parry_power() -> void:
	var es2: CombatPowerRules = CombatPowerRules.classic()
	_assert_eq([es2.parry_power(true, true, 300, 50), es2.parry_power(true, false, 300, 50), es2.parry_power(false, true, 300, 50), es2.parry_power(false, false, 300, 50)], [300, 600, 0, 50], "ES2: armed against a weapon its parry, against bare hands doubled; bare against a weapon none, against bare hands its unarmed")
	var modern: CombatPowerRules = _rules(150, 100, 0)
	_assert_eq([modern.parry_power(true, true, 300, 50), modern.parry_power(true, false, 300, 50), modern.parry_power(false, true, 300, 50), modern.parry_power(false, false, 300, 50)], [300, 300, 75, 50], "150 / 100: bare against a weapon half again its unarmed, a weapon against bare hands not doubled")
	var split: CombatPowerRules = CombatPowerRules.classic().with_parries(100, 200, 0, 100)
	var player: CombatPowerRules.ParrySide = CombatPowerRules.ParrySide.PLAYER
	var foe: CombatPowerRules.ParrySide = CombatPowerRules.ParrySide.FOE
	var nobody: CombatPowerRules.ParrySide = CombatPowerRules.ParrySide.NONE
	_assert_eq([split.parry_power(false, true, 300, 50, player), split.parry_power(true, false, 300, 50, player), split.parry_power(false, true, 300, 50, foe), split.parry_power(true, false, 300, 50, foe)], [50, 600, 0, 300], "by who parries: the player's bare hands 100 %, the player's weapon doubled; a foe's bare hands none, a foe's weapon undoubled")
	_assert_eq([split.parry_power(false, true, 300, 50, nobody), split.parry_power(true, false, 300, 50, nobody)], [0, 600], "two NPCs: combatd.c's")
	_assert_eq([CombatPowerRules.parry_side(true, false), CombatPowerRules.parry_side(false, true), CombatPowerRules.parry_side(false, false)], [foe, player, nobody], "the player strikes: the foe parries; the player is struck: the player parries")
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



## Owner 2026-11-20 (DECISIONS「空手对兵器」): pacing.json's knobs only ever help the player. A sword
## player against a bare-handed foe gets ES2's parries both ways; a fist player against an armed
## foe gets the evened ones both ways.
func _test_player_half() -> void:
	# pacing.json's parry knobs on ES2's power curve (level 20 is 2666, level 10 is 333).
	var game: CombatPowerRules = GameContent.catalog().pacing().combat_rules()
	var production: CombatPowerRules = CombatPowerRules.classic().with_parries(
		game.player_bare_parry_percent, game.player_armed_parry_percent, game.foe_bare_parry_percent, game.foe_armed_parry_percent,
	).with_bare_damage(game.bare_damage_percent)
	var es2: CombatPowerRules = CombatPowerRules.classic().with_bare_damage(game.bare_damage_percent)
	# The player's sword on a foe's bare hands: no parry (ES2's), not their unarmed's.
	var sword_on_bare: CombatAttackInput = _sided(_input(production, true, false), true)
	_assert_eq(_bounds(sword_on_bare).slice(0, 3), [1, 2667, 2666 + 1], "sword player: a foe's bare hands do not parry the sword (ES2)")
	# A foe's bare hands on the player's sword: the sword parries doubled (ES2's).
	var bare_on_sword: CombatAttackInput = _sided(_input(production, false, true, 20, 0, 10, 10, 20, 0, false), false)
	_assert_eq(_bounds(bare_on_sword).slice(0, 4), [1, 2667, 2666 + 666, 20], "sword player: the sword parries a foe's bare hands doubled (ES2), and the foe has no bare share")
	_assert_eq(_bounds(sword_on_bare), _bounds(_with(sword_on_bare, es2)), "sword player striking: exactly ES2's draws")
	_assert_eq(_bounds(bare_on_sword), _bounds(_with(bare_on_sword, es2)), "sword player struck: exactly ES2's draws")
	# The fist player's trained hands on a foe's sword: parried undoubled (today's 100 %).
	var fist_on_sword: CombatAttackInput = _input(production, false, true)
	_assert_eq(_bounds(fist_on_sword).slice(0, 3), [1, 2667, 2666 + 333], "fist player: a foe's sword parries the fist undoubled")
	# A foe's sword on the fist player's bare hands: parried by their unarmed (100 %).
	var sword_on_fist: CombatAttackInput = _input(production, true, false)
	_assert_eq([sword_on_fist.attacker.player, sword_on_fist.defender.player], [false, true], "the helper's player is the bare-handed defender")
	_assert_eq(_bounds(sword_on_fist).slice(0, 3), [1, 2667, 2666 + 333], "fist player: bare hands parry a foe's sword at 100 % of their unarmed")
	# The forecast reads the same.
	_assert_true(absf(CombatForecast.parry_gate(sword_on_bare) - 2666.0 / 2667.0) < 0.001 and absf(CombatForecast.parry_gate(bare_on_sword) - 2666.0 / (2666.0 + 666.0)) < 0.001, "the forecast: ES2's gates for the sword player")
	_assert_true(absf(CombatForecast.parry_gate(fist_on_sword) - 2666.0 / (2666.0 + 333.0)) < 0.001 and absf(CombatForecast.parry_gate(sword_on_fist) - 2666.0 / (2666.0 + 333.0)) < 0.001, "the forecast: the evened gates for the fist player")


## `input` with the player the attacker (`player_strikes`) or the defender, nobody's hands trained.
func _sided(input: CombatAttackInput, player_strikes: bool) -> CombatAttackInput:
	var attacker: CombatAttackerSnapshot = input.attacker
	var defender: CombatDefenderSnapshot = input.defender
	attacker.player = player_strikes
	defender.player = not player_strikes
	attacker.trained_bare_hands = false
	defender.trained_bare_hands = false
	return CombatAttackInput.new(attacker, defender, input.selected_action, null, input.rules)


func _with(input: CombatAttackInput, rules: CombatPowerRules) -> CombatAttackInput:
	return CombatAttackInput.new(input.attacker, input.defender, input.selected_action, null, rules)


func _assert_true(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
