class_name CombatBeatRules
extends RefCounted

## 战斗拍数 A (DECISIONS「战斗拍数」): a round is a string of beats, not one move. Each knob
## keeps ES2's value as its 经典 value — a record without them is ES2's one heart beat, one
## move, one busy count per round:
## - round_beats: the beats each side has in a round (the player's; an NPC's own `beats`
##   stands in for it, DECISIONS「战斗拍数」). 1 (ES2): one move a round.
## - beat_costs: what a beat of each kind costs, by the move's tag (quick / heavy / feint /
##   guard / plain) or the action's key (perform/<id>, stance, exert, item, flee); a key left
##   out costs 1. All 1 (ES2): every action is one heart beat.
## - earned_beat_cap: how many beats a fighter may win in one round through its school's
##   skeleton (CombatSchoolSkeleton). 0 (ES2): none.
## - busy_in_beats: busy N confiscates the fighter's next N beats, from its nearest beat on
##   and across rounds; false (ES2): busy counts down once a heart beat, whatever the beats.
## - interleaved: the round resolves in exchange order — the player's first beat, each
##   NPC's first beat, then the remaining beats by turns; false (ES2): combatd.c's
##   participant order, each one's beats together.

const COST_STANCE: StringName = &"stance"
const COST_EXERT: StringName = &"exert"
const COST_ITEM: StringName = &"item"
const COST_FLEE: StringName = &"flee"
## 战斗拍数 B: a spell cast as an order (not in the data: it costs 1, as a key left out).
const COST_CAST: StringName = &"cast"
const COST_PLAIN: StringName = &"plain"
const PERFORM_PREFIX: String = "perform/"

var round_beats: int = 1
var beat_costs: Dictionary[StringName, int] = {}
var earned_beat_cap: int = 0
var busy_in_beats: bool = false
var interleaved: bool = false


func _init(p_round_beats: int = 1, p_beat_costs: Dictionary[StringName, int] = {}, p_earned_beat_cap: int = 0, p_busy_in_beats: bool = false, p_interleaved: bool = false) -> void:
	round_beats = p_round_beats
	beat_costs = p_beat_costs.duplicate()
	earned_beat_cap = p_earned_beat_cap
	busy_in_beats = p_busy_in_beats
	interleaved = p_interleaved


static func classic() -> CombatBeatRules:
	return CombatBeatRules.new()


func is_valid() -> bool:
	if round_beats < 1 or earned_beat_cap < 0:
		return false
	for key: StringName in beat_costs:
		if beat_costs[key] < 1:
			return false
	return true


## Whether the beats change anything from ES2's one beat a round.
func is_classic() -> bool:
	return round_beats <= 1 and earned_beat_cap == 0 and not busy_in_beats and not interleaved and beat_costs.values().all(func(cost: int) -> bool: return cost == 1)


## The cost of a move with `tag` (平 under &"").
func cost_of_tag(tag: StringName) -> int:
	return beat_costs.get(COST_PLAIN if tag.is_empty() else tag, 1)


## The cost of an action by its key (perform/<id>, stance, exert, item, flee).
func cost_of_action(key: StringName) -> int:
	return beat_costs.get(key, 1)


## The key of a perform's cost.
static func perform_key(function_id: StringName) -> StringName:
	return StringName(PERFORM_PREFIX + String(function_id))


## Whether `key` names a perform (perform/<id>), and which.
static func perform_of(key: StringName) -> StringName:
	var text: String = String(key)
	return StringName(text.trim_prefix(PERFORM_PREFIX)) if text.begins_with(PERFORM_PREFIX) else &""


func duplicate_snapshot() -> CombatBeatRules:
	return CombatBeatRules.new(round_beats, beat_costs, earned_beat_cap, busy_in_beats, interleaved)


static func from_record(reader: ContentRecordReader) -> CombatBeatRules:
	var costs: Dictionary[StringName, int] = {}
	if reader.has("beat_costs"):
		var map: Dictionary[String, int] = reader.integer_map("beat_costs")
		for key: String in map:
			costs[StringName(key)] = map[key]
	var rules := CombatBeatRules.new(
		reader.integer("round_beats", 1), costs, reader.integer("earned_beat_cap", 0),
		reader.boolean("busy_in_beats", false), reader.boolean("interleaved", false),
	)
	if not rules.is_valid():
		reader.fail("round_beats", "round_beats and every beat cost are at least 1, earned_beat_cap at least 0")
	return rules
