class_name BountyBoard
extends RefCounted

## Native (owner, A2 经验节奏; DECISIONS「经验节奏」): the 雪亭驿 board's rules on the
## player's BountyState. The board shows BountyRules.postings bounties, each for the tier the
## player's combat_exp reaches, at one of the places in turn (no random draw); the player
## takes one at a time. A bounty done or given up leaves its slot empty for `refresh_ms` of
## play time, so the board cannot be worked faster than that. One whose outlaw the player
## has outgrown (远不如你) is put up anew for their tier; with none worth their while the
## board stays empty for them.

## Places are taken in this stride (coprime with any small count), so the postings differ.
const PLACE_STRIDE: int = 3


## Play time passes (`elapsed_ms`): empty slots count down and are filled once due; postings
## not taken that are of another tier than the player's now are put up anew.
## `outlaw_exp` (npc_id) -> combat_exp of that outlaw.
static func tick(state: BountyState, rules: BountyRules, combat_exp: int, elapsed_ms: int, outlaw_exp: Callable) -> bool:
	if state == null or rules == null:
		return false
	state.fit(rules.postings)
	_drop_unknown(state, rules)
	var tier: int = worthy_tier(rules, combat_exp, outlaw_exp)
	var changed: bool = false
	for slot: int in rules.postings:
		if state.tiers[slot] >= 0:
			if slot != state.active and state.tiers[slot] != tier:
				changed = _post(state, rules, slot, tier) or changed
			continue
		state.refill_ms[slot] = maxi(state.refill_ms[slot] - elapsed_ms, 0)
		if state.refill_ms[slot] == 0:
			changed = _post(state, rules, slot, tier) or changed
	return changed


## The tier offered to a player of `combat_exp`: the highest reached, unless its outlaw is
## far weaker than them (RelativeStrength 远不如你): then none (-1).
static func worthy_tier(rules: BountyRules, combat_exp: int, outlaw_exp: Callable) -> int:
	var tier: int = rules.tier_for(combat_exp)
	if tier < 0:
		return -1
	if RelativeStrength.band(combat_exp, int(outlaw_exp.call(rules.tiers[tier].npc_id))) == RelativeStrength.Band.MUCH_WEAKER:
		return -1
	return tier


## Takes the bounty in `slot`: one at a time.
static func take(state: BountyState, slot: int) -> bool:
	if state == null or state.active >= 0 or slot < 0 or slot >= state.tiers.size() or state.tiers[slot] < 0:
		return false
	state.active = slot
	return true


## The bounty taken is given up or done: its slot is empty for `refresh_ms`.
static func close(state: BountyState, refresh_ms: int) -> void:
	if state == null or state.active < 0:
		return
	state.tiers[state.active] = -1
	state.places[state.active] = -1
	state.refill_ms[state.active] = maxi(refresh_ms, 0)
	state.active = -1


## Every posting names a tier and a place the rules have.
static func fits(state: BountyState, rules: BountyRules) -> bool:
	if state == null or rules == null:
		return false
	for slot: int in state.tiers.size():
		if state.tiers[slot] >= rules.tiers.size() or state.places[slot] >= rules.places.size():
			return false
	return true


## A save's posting of a tier or place the data no longer has (native/bounties.json changed)
## is taken down, the bounty taken too: its slot fills anew.
static func _drop_unknown(state: BountyState, rules: BountyRules) -> void:
	for slot: int in state.tiers.size():
		if state.tiers[slot] >= rules.tiers.size() or state.places[slot] >= rules.places.size():
			state.tiers[slot] = -1
			state.places[slot] = -1
			state.refill_ms[slot] = 0
			if state.active == slot:
				state.active = -1


static func _post(state: BountyState, rules: BountyRules, slot: int, tier: int) -> bool:
	if tier < 0:
		var had: bool = state.tiers[slot] >= 0
		state.tiers[slot] = -1
		state.places[slot] = -1
		return had
	state.tiers[slot] = tier
	state.places[slot] = (state.serial * PLACE_STRIDE) % rules.places.size()
	state.serial += 1
	return true
