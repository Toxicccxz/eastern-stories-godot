class_name BountyRules
extends RefCounted

## Native (owner, A2 经验节奏; DECISIONS「经验节奏」): the 雪亭驿 board's bounties, one
## record in game/data/native/bounties.json. ES2 has no bounty board.
## - postings: how many bounties the board shows at once.
## - tiers: rising min_exp; the outlaw (an NPC of native role bounty_target) a player of
##   that much combat_exp is offered, and the silver it is worth. A tier may wait on the story
##   (`after`: a condition on the player's marks and quests, e.g. a chapter done; `after_hint`:
##   when that is, as the empty board says it) and have places of its own (`places`: that
##   chapter's region) instead of the board's (成长曲线 D).
## - places: where an outlaw is found (a wild zone near Snow): it comes out when the
##   player walks into the zone.


class Tier:
	extends RefCounted
	var min_exp: int
	var npc_id: StringName
	var silver: int
	## The story it waits on (null: none).
	var after: JournalEntryDefinition = null
	## When `after` holds, as the empty board says it ("" with no `after`).
	var after_hint: String = ""
	## Indices into BountyRules.places this tier's outlaw is found at.
	var place_indices: Array[int] = []

	## Whether its story has come for `state` (always without an `after`).
	func open_for(state: CharacterState) -> bool:
		return after == null or (state != null and JournalLog.holds(after, state, {}, {}))


class Place:
	extends RefCounted
	var map_id: StringName
	var zone_id: StringName


var postings: int = 3
var tiers: Array[Tier] = []
## Every place: the board's own (`places`) first, then each tier's own in turn.
var places: Array[Place] = []


## The tier a player of `combat_exp` is offered: the highest one reached; -1 with none.
func tier_for(combat_exp: int) -> int:
	var found: int = -1
	for index: int in tiers.size():
		if tiers[index].min_exp <= combat_exp:
			found = index
	return found


static func from_record(reader: ContentRecordReader) -> BountyRules:
	var rules := BountyRules.new()
	reader.text("source")
	rules.postings = reader.integer("postings", 3)
	var own: Array[Array] = []
	for record: ContentRecordReader in reader.children("tiers"):
		var tier := Tier.new()
		tier.min_exp = record.required_integer("min_exp")
		tier.npc_id = StringName(record.required_text("npc"))
		tier.silver = record.required_integer("silver")
		if record.has("after"):
			tier.after = JournalEntryDefinition.new()
			JournalEntryDefinition.read_when(record, tier.after, "after")
			tier.after_hint = record.required_text("after_hint")
		var tier_places: Array[Place] = []
		for place_record: ContentRecordReader in record.children("places"):
			tier_places.append(_place(place_record))
		own.append(tier_places)
		record.finish()
		rules.tiers.append(tier)
	for record: ContentRecordReader in reader.children("places"):
		rules.places.append(_place(record))
	var board: Array[int] = []
	for index: int in rules.places.size():
		board.append(index)
	for index: int in rules.tiers.size():
		if own[index].is_empty():
			rules.tiers[index].place_indices = board.duplicate()
			continue
		for place: Place in own[index]:
			rules.tiers[index].place_indices.append(rules.places.size())
			rules.places.append(place)
	reader.finish()
	if rules.postings < 1:
		reader.fail("postings", "must be at least 1")
	if rules.tiers.is_empty() or rules.tiers[0].min_exp != 0:
		reader.fail("tiers", "expected tiers starting at min_exp 0")
	for index: int in range(1, rules.tiers.size()):
		if rules.tiers[index].min_exp <= rules.tiers[index - 1].min_exp:
			reader.fail("tiers", "min_exp %d does not rise" % rules.tiers[index].min_exp)
	if rules.places.is_empty() or rules.tiers.any(func(tier: Tier) -> bool: return tier.place_indices.is_empty()):
		reader.fail("places", "expected at least one place for every tier")
	return rules


static func _place(record: ContentRecordReader) -> Place:
	var place := Place.new()
	place.map_id = StringName(record.required_text("map"))
	place.zone_id = StringName(record.required_text("zone"))
	record.finish()
	return place
