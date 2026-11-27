class_name BountyBoard
extends RefCounted

## Native (owner, A2 经验节奏; DECISIONS「经验节奏」): the 雪亭驿 board's rules on the
## player's BountyState. The board shows BountyRules.postings bounties, each for the tier the
## player's combat_exp reaches, at one of the places in turn (no random draw); the player
## takes one at a time. A bounty done or given up leaves its slot empty for `refresh_ms` of
## play time, so the board cannot be worked faster than that. One whose outlaw the player
## has outgrown (远不如你) is put up anew for their tier; with none worth their while the
## board stays empty for them.
## 成长曲线 D (DECISIONS「成长曲线 D」): a tier may wait on the story (BountyRules.Tier.after) and
## have places of its own; with the pacing knob bounty_ceiling_percent an outlaw is outgrown once
## the player has that percent of its combat_exp (200: twice), and a player who has outgrown the
## highest tier they reached is offered the next one the story has opened, so the ladder has no
## gaps; `opens` (tier -> bool) says which the story has opened, all of them when not given.

## Places are taken in this stride where it is coprime with the count of a tier's places (the
## board's seven: 0, 3, 6, 2 …), so postings in turn differ; one place at a time otherwise (a
## tier's own three). place_stride().
const PLACE_STRIDE: int = 3


## Play time passes (`elapsed_ms`): empty slots count down and are filled once due; postings
## not taken that are of another tier than the player's now are put up anew.
## `outlaw_exp` (npc_id) -> combat_exp of that outlaw.
static func tick(state: BountyState, rules: BountyRules, combat_exp: int, elapsed_ms: int, outlaw_exp: Callable, opens: Callable = Callable(), ceiling_percent: int = 0) -> bool:
	if state == null or rules == null:
		return false
	state.fit(rules.postings)
	_drop_unknown(state, rules)
	var tier: int = worthy_tier(rules, combat_exp, outlaw_exp, opens, ceiling_percent)
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


## The tier offered to a player of `combat_exp`: the highest the story has opened that they
## reached, unless they have outgrown its outlaw (outgrown()); then, with a ceiling, the next
## tier up the story has opened that they have not outgrown; else none (-1).
static func worthy_tier(rules: BountyRules, combat_exp: int, outlaw_exp: Callable, opens: Callable = Callable(), ceiling_percent: int = 0) -> int:
	var reached: int = -1
	for index: int in rules.tiers.size():
		if rules.tiers[index].min_exp <= combat_exp and _opened(opens, index):
			reached = index
	if reached >= 0 and not outgrown(rules, reached, combat_exp, outlaw_exp, ceiling_percent):
		return reached
	if ceiling_percent <= 0:
		return -1
	for index: int in range(reached + 1, rules.tiers.size()):
		if _opened(opens, index) and not outgrown(rules, index, combat_exp, outlaw_exp, ceiling_percent):
			return index
	return -1


## Whether a player of `combat_exp` has outgrown `tier`'s outlaw: `ceiling_percent` of its
## combat_exp and more; with no ceiling, once it looks far weaker (RelativeStrength 远不如你).
static func outgrown(rules: BountyRules, tier: int, combat_exp: int, outlaw_exp: Callable, ceiling_percent: int = 0) -> bool:
	var outlaw: int = int(outlaw_exp.call(rules.tiers[tier].npc_id))
	if ceiling_percent > 0:
		return combat_exp * 100 >= outlaw * ceiling_percent
	return RelativeStrength.band(combat_exp, outlaw) == RelativeStrength.Band.MUCH_WEAKER


## Why a player of `combat_exp` is offered no tier, for the empty board: the first tier above
## the ones they have outgrown that waits on the story (its index), -2 when every tier the story
## has opened is outgrown and none is left to wait for, -1 when one is offered (an empty board
## then only waits for its slots to fill).
static func waiting_tier(rules: BountyRules, combat_exp: int, outlaw_exp: Callable, opens: Callable = Callable(), ceiling_percent: int = 0) -> int:
	if worthy_tier(rules, combat_exp, outlaw_exp, opens, ceiling_percent) >= 0:
		return -1
	for index: int in rules.tiers.size():
		if not _opened(opens, index) and not outgrown(rules, index, combat_exp, outlaw_exp, ceiling_percent):
			return index
	return -2


static func _opened(opens: Callable, tier: int) -> bool:
	return not opens.is_valid() or bool(opens.call(tier))


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
	var places: Array[int] = rules.tiers[tier].place_indices
	state.places[slot] = places[(state.serial * place_stride(places.size())) % places.size()]
	state.serial += 1
	return true


## The stride postings in turn take through `count` places: PLACE_STRIDE when coprime with it, else 1.
static func place_stride(count: int) -> int:
	var a: int = PLACE_STRIDE
	var b: int = maxi(count, 1)
	while b != 0:
		var rest: int = a % b
		a = b
		b = rest
	return PLACE_STRIDE if a == 1 else 1
