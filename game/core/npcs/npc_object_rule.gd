class_name NpcObjectRule
extends RefCounted

## One branch of an NPC's own accept_object(who, ob) (d/snow/npc/keeper.c and the
## like), tested by cmds/std/give.c before anything changes hands. The first rule
## whose conditions all hold decides; an NPC without rules has no accept_object()
## and takes nothing. Conditions: the item's value() range, its liquid type and how
## much is left, a flag of the NPC (drunk.c has_alcohol), a mark of the giver
## (marks/魏无极), the giver's gender and raw per (u/cloud girl.c), the item's name and
## the giver's family (u/cloud b_header.c: 忘忧草 from 振远镖局). The outcome: lines,
## accept or refuse, what it changes, and `kill`: a refusal that attacks the giver
## (u/cloud gangster.c kill_passenger()). Effects: keeper.c's donation, and `wager`:
## the money is a bet on the NPC's NpcWager (judge.c).
const EFFECT_TEMPLE_DONATION: StringName = &"temple_donation"
const EFFECT_WAGER: StringName = &"wager"
const EFFECTS: Array[StringName] = [EFFECT_TEMPLE_DONATION, EFFECT_WAGER]
const NO_BOUND: int = -1

var value_at_least: int = NO_BOUND
var value_at_most: int = NO_BOUND
var liquid_type: StringName = &""
var liquid_remaining_at_most: int = NO_BOUND
var npc_flag: StringName = &""
var giver_mark: String = ""
var giver_gender: StringName = &""
var giver_per_below: int = NO_BOUND
## obj->query("name") as authored.
var item_name: String = ""
## families.json ID of query("family/family_name").
var giver_family: StringName = &""
var lines: Array[NpcLine] = []
var accept: bool = false
var mark_giver: String = ""
var set_npc_flag: StringName = &""
var effect: StringName = &""
var kill: bool = false


## What give.c knows about the gift and the two sides when it asks.
class Offer:
	extends RefCounted
	var value: int
	## "" when the item holds no liquid (feature/liquid.c liquid/type).
	var liquid_type: StringName
	var liquid_remaining: int
	var npc_flags: Dictionary[StringName, bool]
	var giver_marks: Dictionary[String, int]
	var giver_gender: StringName = &""
	## query("per"): the raw attribute.
	var giver_per: int = 0
	var item_name: String = ""
	var giver_family: StringName = &""

	func _init(p_value: int = 0, p_liquid_type: StringName = &"", p_liquid_remaining: int = 0, p_npc_flags: Dictionary[StringName, bool] = {}, p_giver_marks: Dictionary[String, int] = {}) -> void:
		value = p_value
		liquid_type = p_liquid_type
		liquid_remaining = p_liquid_remaining
		npc_flags = p_npc_flags
		giver_marks = p_giver_marks


func matches(offer: Offer) -> bool:
	return (
		(value_at_least == NO_BOUND or offer.value >= value_at_least)
		and (value_at_most == NO_BOUND or offer.value <= value_at_most)
		and (liquid_type.is_empty() or offer.liquid_type == liquid_type)
		and (liquid_remaining_at_most == NO_BOUND or (not offer.liquid_type.is_empty() and offer.liquid_remaining <= liquid_remaining_at_most))
		and (npc_flag.is_empty() or offer.npc_flags.get(npc_flag, false))
		and (giver_mark.is_empty() or offer.giver_marks.get(giver_mark, 0) != 0)
		and (giver_gender.is_empty() or offer.giver_gender == giver_gender)
		and (giver_per_below == NO_BOUND or offer.giver_per < giver_per_below)
		and (item_name.is_empty() or offer.item_name == item_name)
		and (giver_family.is_empty() or offer.giver_family == giver_family)
	)


## The first matching rule, or null: accept_object() returned 0.
static func decide(rules: Array[NpcObjectRule], offer: Offer) -> NpcObjectRule:
	for rule: NpcObjectRule in rules:
		if rule.matches(offer):
			return rule
	return null


static func from_record(reader: ContentRecordReader) -> NpcObjectRule:
	var rule := NpcObjectRule.new()
	rule.value_at_least = reader.integer("value_at_least", NO_BOUND)
	rule.value_at_most = reader.integer("value_at_most", NO_BOUND)
	rule.liquid_type = StringName(reader.text("liquid"))
	rule.liquid_remaining_at_most = reader.integer("liquid_remaining_at_most", NO_BOUND)
	rule.npc_flag = StringName(reader.text("npc_flag"))
	rule.giver_mark = reader.text("giver_mark")
	rule.giver_gender = StringName(reader.text("giver_gender"))
	rule.giver_per_below = reader.integer("giver_per_below", NO_BOUND)
	rule.item_name = reader.text("item_name")
	rule.giver_family = StringName(reader.text("giver_family"))
	rule.kill = reader.boolean("kill", false)
	rule.lines = NpcLine.optional_lines(reader)
	rule.accept = reader.boolean("accept", false)
	rule.mark_giver = reader.text("mark_giver")
	rule.set_npc_flag = StringName(reader.text("set_npc_flag"))
	rule.effect = StringName(reader.text("effect"))
	if not reader.has("accept"):
		reader.fail("accept", "is required")
	if not rule.effect.is_empty() and not EFFECTS.has(rule.effect):
		reader.fail("effect", "unsupported effect '%s'" % rule.effect)
	if not rule.liquid_type.is_empty() and not LiquidState.LEGACY_TYPES.has(rule.liquid_type):
		reader.fail("liquid", "unsupported liquid type '%s'" % rule.liquid_type)
	if not rule.accept and (not rule.mark_giver.is_empty() or not rule.set_npc_flag.is_empty() or not rule.effect.is_empty()):
		reader.fail("accept", "a refusal changes nothing")
	if rule.kill and rule.accept:
		reader.fail("kill", "only a refusal attacks the giver")
	if rule.effect == EFFECT_WAGER and rule.value_at_least < 1:
		reader.fail("value_at_least", "a bet is money: value_at_least must be at least 1")
	reader.finish()
	return rule
