class_name CombatForecast
extends RefCounted

## 战前预判 (战斗决策层 1A, DECISIONS「战斗数值」): what a fight would come to, from the
## expected values of the same inputs the resolver draws on (CombatAttackInput both ways,
## under the same CombatPowerRules), with no draw: how many rounds the player needs to fell
## the other side and how many it needs to fell the player; the ratio is the verdict. A gang
## (DECISIONS「进门一起上」) is felled one after the other while every member strikes.
## Guarding, ripostes, specials, force hits and wounds are left out: a read, not a replay.

enum Verdict { SURE_WIN, FAVOURED, EVEN, UNFAVOURED, SURE_LOSS }
## The one thing that weighs most, for the line's second sentence.
enum Reason { NONE, NUMBERS, DODGE, WEAPON_PARRY, EXPERIENCE, DAMAGE, MY_WEAPON }

## rounds_to_win / rounds_to_lose at which each verdict ends (the last is open).
const SURE_WIN_RATIO: float = 0.5
const FAVOURED_RATIO: float = 0.8
const EVEN_RATIO: float = 1.25
const UNFAVOURED_RATIO: float = 2.0
const LOOP_FACTOR: float = 2.0 / 3.0

var verdict: Verdict = Verdict.EVEN
var reason: Reason = Reason.NONE
## The other side's count.
var enemies: int = 0
## Expected rounds for the player to fell them all, and for them to fell the player
## (INF when a side cannot land a blow).
var rounds_to_win: float = INF
var rounds_to_lose: float = INF
## The player's chance to land a blow on the first enemy, both gates passed, and the
## first enemy's on the player.
var land_chance: float = 0.0
var enemy_land_chance: float = 0.0
## The expected 气 a round takes from the first enemy and from the player (attacks, lands,
## damage and ripostes all in), for the probe and the tests.
var mine_per_round: float = 0.0
var theirs_per_round: float = 0.0
## A 切磋 ends on the first blow that draws 气 (fight.c): its verdict is who lands first.
var spar_verdict: Verdict = Verdict.EVEN


## `outgoing[i]`: the player's attack on enemy i; `incoming[i]`: enemy i's on the player;
## `enemy_kee[i]` their 气 now; `player_kee` the player's. `outgoing_chance[i]` /
## `incoming_chance[i]`: how often each side attacks at all in a round (attack_chance();
## left out: every round).
static func estimate(
	outgoing: Array[CombatAttackInput], incoming: Array[CombatAttackInput],
	enemy_kee: Array[int], player_kee: int,
	outgoing_chance: Array[float] = [], incoming_chance: Array[float] = [],
) -> CombatForecast:
	var result := CombatForecast.new()
	result.enemies = outgoing.size()
	if outgoing.is_empty() or outgoing.size() != incoming.size() or enemy_kee.size() != outgoing.size():
		return result
	var to_win: float = 0.0
	var to_player: float = 0.0
	for index: int in outgoing.size():
		# fight(): a side that fails its courage draw guards instead, and a guarding side
		# ripostes whenever the other attacks and misses; so each side's attacks a round are
		# its own plus the ripostes the other's misses give it.
		var a: float = outgoing_chance[index] if index < outgoing_chance.size() else 1.0
		var b: float = incoming_chance[index] if index < incoming_chance.size() else 1.0
		var mine_land: float = land_chance_of(outgoing[index])
		var theirs_land: float = 0.0 if incoming[index] == null else land_chance_of(incoming[index])
		var mine: float = damage_per_round(outgoing[index]) * (a + (1.0 - a) * b * (1.0 - theirs_land))
		to_win = INF if mine <= 0.0 or to_win == INF else to_win + float(enemy_kee[index] + 1) / mine
		var theirs: float = 0.0
		if incoming[index] != null:
			theirs = damage_per_round(incoming[index]) * (b + (1.0 - b) * a * (1.0 - mine_land))
			to_player += theirs
		if index == 0:
			result.mine_per_round = mine
			result.theirs_per_round = theirs
	result.rounds_to_win = to_win
	result.rounds_to_lose = INF if to_player <= 0.0 else float(player_kee + 1) / to_player
	result.land_chance = land_chance_of(outgoing[0])
	result.enemy_land_chance = 0.0 if incoming[0] == null else land_chance_of(incoming[0])
	result.verdict = _verdict(result.rounds_to_win, result.rounds_to_lose)
	# Rounds to the first blow each way: 1 / chance; the same bands over their ratio.
	result.spar_verdict = _verdict(
		INF if result.land_chance <= 0.0 else 1.0 / result.land_chance,
		INF if result.enemy_land_chance <= 0.0 else 1.0 / result.enemy_land_chance,
	)
	result.reason = _reason(result, outgoing, incoming, enemy_kee, player_kee, outgoing_chance, incoming_chance)
	return result


## combatd.c fight(): an attack comes when random(victim cps × 3) < cor + bellicosity / 50,
## else the attacker guards that round. The chance of it, 1 when the victim has no composure
## (random(0) is 0) or is busy.
static func attack_chance(courage: int, bellicosity: int, victim_composure: int, victim_busy: bool = false) -> float:
	var bound: int = victim_composure * 3
	@warning_ignore("integer_division")
	var threshold: int = courage + bellicosity / 50
	if victim_busy or bound <= 0:
		return 1.0
	return clampf(float(threshold) / float(bound), 0.0, 1.0)


## The verdict of `to_win` rounds against `to_lose`.
static func _verdict(to_win: float, to_lose: float) -> Verdict:
	if to_win == INF:
		return Verdict.SURE_LOSS
	if to_lose == INF:
		return Verdict.SURE_WIN
	var ratio: float = to_win / to_lose
	if ratio <= SURE_WIN_RATIO:
		return Verdict.SURE_WIN
	if ratio <= FAVOURED_RATIO:
		return Verdict.FAVOURED
	if ratio <= EVEN_RATIO:
		return Verdict.EVEN
	if ratio <= UNFAVOURED_RATIO:
		return Verdict.UNFAVOURED
	return Verdict.SURE_LOSS


static func _reason(
	result: CombatForecast, outgoing: Array[CombatAttackInput], incoming: Array[CombatAttackInput],
	enemy_kee: Array[int], player_kee: int, outgoing_chance: Array[float] = [], incoming_chance: Array[float] = [],
) -> Reason:
	var first: CombatAttackInput = outgoing[0]
	if outgoing.size() > 1:
		# Would the first alone have gone better? Then it is the numbers.
		var alone: CombatForecast = estimate([first], [incoming[0]], [enemy_kee[0]], player_kee, outgoing_chance.slice(0, 1), incoming_chance.slice(0, 1))
		if alone.verdict < result.verdict:
			return Reason.NUMBERS
	var attacker: CombatAttackerSnapshot = first.attacker
	var defender: CombatDefenderSnapshot = first.defender
	if result.verdict >= Verdict.UNFAVOURED or result.land_chance < 0.3:
		# A wide experience gap lifts everything of theirs (power and defense): it comes first.
		if experience_multiplier(first) < 0.7:
			return Reason.EXPERIENCE
		if result.land_chance < 0.3:
			if defender.has_primary_weapon and not attacker.has_weapon and parry_gate(first) < dodge_gate(first):
				return Reason.WEAPON_PARRY
			return Reason.DODGE
		if result.rounds_to_lose < 4.0:
			return Reason.DAMAGE
		return Reason.NONE
	if attacker.has_weapon and not defender.has_primary_weapon and result.verdict <= Verdict.FAVOURED:
		return Reason.MY_WEAPON
	return Reason.NONE


## The expected 气 one round of `input`'s attacks takes: the chance to land times the
## expected damage of do_attack() (5) and the experience defense.
static func damage_per_round(input: CombatAttackInput) -> float:
	if input == null or not input.is_valid():
		return 0.0
	return land_chance_of(input) * expected_damage(input)


## P(random(ap + dp) >= dp) × P(random(ap + pp) >= pp), the resolver's two gates.
static func land_chance_of(input: CombatAttackInput) -> float:
	return dodge_gate(input) * parry_gate(input)


static func attack_power(input: CombatAttackInput) -> int:
	var attacker: CombatAttackerSnapshot = input.attacker
	return maxi(1, CombatMath.skill_power(CombatSkillPowerInput.new(
		attacker.living, attacker.effective_attack_skill_level, attacker.attack_usage_bonus,
		attacker.combat_experience, attacker.maximum_spirit, attacker.current_spirit,
	), input.rules))


static func dodge_gate(input: CombatAttackInput) -> float:
	var defender: CombatDefenderSnapshot = input.defender
	var ap: int = attack_power(input)
	var dp: int = maxi(1, CombatMath.skill_power(CombatSkillPowerInput.new(
		defender.living, defender.effective_dodge_skill_level, defender.defense_usage_bonus,
		defender.combat_experience, defender.maximum_spirit, defender.current_spirit,
	), input.rules, true))
	return float(ap) / float(ap + dp)


static func parry_gate(input: CombatAttackInput) -> float:
	var attacker: CombatAttackerSnapshot = input.attacker
	var defender: CombatDefenderSnapshot = input.defender
	var ap: int = attack_power(input)
	var pp: int
	if defender.has_primary_weapon:
		pp = _power(defender, defender.effective_parry_skill_level, input.rules)
		if not attacker.has_weapon:
			pp *= 2
	elif attacker.has_weapon:
		pp = 0
	else:
		pp = _power(defender, defender.effective_unarmed_skill_level, input.rules)
	pp = maxi(1, pp)
	return float(ap) / float(ap + pp)


static func _power(defender: CombatDefenderSnapshot, level: int, rules: CombatPowerRules) -> int:
	return CombatMath.skill_power(CombatSkillPowerInput.new(
		defender.living, level, defender.defense_usage_bonus,
		defender.combat_experience, defender.maximum_spirit, defender.current_spirit,
	), rules, true)


## E[(d + random(d)) / 2] with the action's damage percent, plus E[(str + random(str)) / 2],
## then the experience defense's expected share.
static func expected_damage(input: CombatAttackInput) -> float:
	var attacker: CombatAttackerSnapshot = input.attacker
	var damage: float = _half_with_draw(attacker.projected_apply_damage)
	var action: CombatActionDefinition = input.selected_action
	if action != null and action.damage_percent != 0:
		damage += float(action.damage_percent) * damage / 100.0
	var strength: int = CombatMath.effective_strength(attacker.strength_projection)
	if action != null and action.force_percent != 0:
		strength += action.force_percent * strength / 100
	if strength > 0:
		damage += _half_with_draw(strength)
	return maxf(0.0, damage * experience_multiplier(input))


## E[(n + random(n)) / 2] = (n + (n - 1) / 2) / 2 for n > 0.
static func _half_with_draw(n: int) -> float:
	if n <= 0:
		return 0.0
	return (float(n) + float(n - 1) / 2.0) / 2.0


## The share of a blow the experience defense leaves: MODERN's one bounded reduction, or
## the expected value of combatd.c's `while random(f) > exp: damage -= damage / 3; f /= 2`.
static func experience_multiplier(input: CombatAttackInput) -> float:
	var rules: CombatPowerRules = input.rules
	var mine: int = input.attacker.combat_experience
	var theirs: int = input.defender.combat_experience
	if rules.experience_defense == CombatPowerRules.ExperienceDefense.MODERN:
		return 1.0 - float(rules.experience_defense_percent(mine, theirs)) / 100.0
	var alive: float = 1.0
	var expected: float = 0.0
	var factor: int = theirs
	var kept: float = 1.0
	for _step: int in 64:
		var go_on: float = 0.0 if factor <= 0 else maxf(0.0, float(factor - mine - 1)) / float(factor)
		expected += alive * (1.0 - go_on) * kept
		alive *= go_on
		if alive < 0.0001:
			break
		kept *= LOOP_FACTOR
		@warning_ignore("integer_division")
		factor /= 2
	return expected + alive * kept


## TRANSLATORS: the fight forecast before a fight (native): {pronoun} is 他/她/它.
const VERDICT_LINES: Dictionary[Verdict, String] = {
	Verdict.SURE_WIN: "稳赢：{pronoun}远不是你的对手。",
	Verdict.FAVOURED: "占优：你比{pronoun}强一些。",
	Verdict.EVEN: "五五开：{pronoun}和你不相上下。",
	Verdict.UNFAVOURED: "吃亏：{pronoun}比你强，打起来要吃亏。",
	Verdict.SURE_LOSS: "必败：{pronoun}远比你强，别打。",
}
## TRANSLATORS: the fight forecast's second sentence, what weighs most: {pronoun} is 他/她/它, {count} how many stand on that side.
const REASON_LINES: Dictionary[Reason, String] = {
	Reason.NUMBERS: "{pronoun}这边有 {count} 个人一起上。",
	Reason.DODGE: "{pronoun}的闪躲比你高得多，你很难打中。",
	Reason.WEAPON_PARRY: "{pronoun}有兵刃在手，你空手难以近身。",
	Reason.EXPERIENCE: "{pronoun}的经验比你多得多，你的拳脚落不实。",
	Reason.DAMAGE: "{pronoun}下手太重，你撑不了几回合。",
	Reason.MY_WEAPON: "你有兵刃在手，{pronoun}空手挡不住。",
}


## TRANSLATORS: the 切磋 forecast (native): {pronoun} is 他/她/它; a spar ends on the first blow that lands.
const SPAR_LINES: Dictionary[Verdict, String] = {
	Verdict.SURE_WIN: "切磋稳赢：{pronoun}的招式你一眼看穿。",
	Verdict.FAVOURED: "切磋占优：你多半先打中{pronoun}。",
	Verdict.EVEN: "切磋五五开：谁先打中谁赢。",
	Verdict.UNFAVOURED: "切磋吃亏：{pronoun}多半先打中你。",
	Verdict.SURE_LOSS: "切磋必输：{pronoun}的招式你接不住。",
}


## The line, untranslated, with {pronoun} and {count} left to the caller; `spar` reads a
## 切磋 (who lands first, no reason).
func line(spar: bool = false) -> String:
	if spar:
		return SPAR_LINES[spar_verdict]
	var text: String = VERDICT_LINES[verdict]
	if reason != Reason.NONE:
		text += REASON_LINES[reason]
	return text
