class_name ProgressionGain
extends RefCounted

## Native (owner, A2 经验节奏): how the player's exp and potential grow on top of a ported
## rule's own numbers, which stay as they are. With every knob at ES2's value (no catch-up,
## combatd.c's cap of 100) each function gives ES2's result.


## 落后补偿: how much more (percent) a gain is while `combat_exp` is below the region's
## `recommended` (RegionDefinition.recommended_exp): the shortfall's share of it, at most
## `max_percent` (pacing catch_up_max_percent; 0 is ES2). 0 once the player is there.
@warning_ignore("integer_division")
static func catch_up_percent(combat_exp: int, recommended: int, max_percent: int) -> int:
	if max_percent <= 0 or recommended <= 0 or combat_exp >= recommended:
		return 0
	return mini(max_percent, (recommended - maxi(combat_exp, 0)) * 100 / recommended)


## `base` with `percent` more; what does not make a whole point is kept in the player's
## progression.gain_carry (hundredths) for the next gain, so nothing is lost to rounding
## and no random number is drawn. A percent of 0 is `base` as it is.
@warning_ignore("integer_division")
static func scaled(progression: CharacterProgressionState, base: int, percent: int) -> int:
	if percent <= 0 or base <= 0:
		return base
	var hundredths: int = base * (100 + percent) + progression.gain_carry
	progression.gain_carry = hundredths % 100
	return hundredths / 100


## Adds up to `amount` potential while less than `cap` is unspent and returns what was
## added (combatd.c do_attack() with cap 100; killer_reward()'s cap only stops the gain,
## DECISIONS 3C).
static func add_potential(progression: CharacterProgressionState, amount: int, cap: int) -> int:
	var unspent: int = progression.potential - progression.potential_spent
	if amount <= 0 or unspent >= cap:
		return 0
	var added: int = mini(amount, cap - unspent)
	progression.potential += added
	return added


## The most potential that stays unspent at `combat_exp`: the stage's (pacing
## staged_potential_cap) or combatd.c's 100.
static func potential_cap(rules: ProgressionRules, combat_exp: int, staged: bool) -> int:
	if not staged or rules == null:
		return ProgressionRules.ES2_POTENTIAL_CAP
	var at: ProgressionRules.Stage = rules.stage(combat_exp)
	return ProgressionRules.ES2_POTENTIAL_CAP if at == null else at.potential_cap
