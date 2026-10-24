class_name BountyRules
extends RefCounted

## Native (owner, A2 经验节奏; DECISIONS「经验节奏」): the 雪亭驿 board's bounties, one
## record in game/data/native/bounties.json. ES2 has no bounty board.
## - postings: how many bounties the board shows at once.
## - tiers: rising min_exp; the outlaw (an NPC of native role bounty_target) a player of
##   that much combat_exp is offered, and the silver it is worth.
## - places: where an outlaw is found (a wild zone near Snow): it comes out when the
##   player walks into the zone.


class Tier:
	extends RefCounted
	var min_exp: int
	var npc_id: StringName
	var silver: int


class Place:
	extends RefCounted
	var map_id: StringName
	var zone_id: StringName


var postings: int = 3
var tiers: Array[Tier] = []
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
	for record: ContentRecordReader in reader.children("tiers"):
		var tier := Tier.new()
		tier.min_exp = record.required_integer("min_exp")
		tier.npc_id = StringName(record.required_text("npc"))
		tier.silver = record.required_integer("silver")
		record.finish()
		rules.tiers.append(tier)
	for record: ContentRecordReader in reader.children("places"):
		var place := Place.new()
		place.map_id = StringName(record.required_text("map"))
		place.zone_id = StringName(record.required_text("zone"))
		record.finish()
		rules.places.append(place)
	reader.finish()
	if rules.postings < 1:
		reader.fail("postings", "must be at least 1")
	if rules.tiers.is_empty() or rules.tiers[0].min_exp != 0:
		reader.fail("tiers", "expected tiers starting at min_exp 0")
	for index: int in range(1, rules.tiers.size()):
		if rules.tiers[index].min_exp <= rules.tiers[index - 1].min_exp:
			reader.fail("tiers", "min_exp %d does not rise" % rules.tiers[index].min_exp)
	if rules.places.is_empty():
		reader.fail("places", "expected at least one place")
	return rules
