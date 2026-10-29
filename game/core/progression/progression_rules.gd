class_name ProgressionRules
extends RefCounted

## The native progression table (owner, A2 经验节奏; DECISIONS「经验节奏」): one record in
## game/data/common/progression.json. ES2 has none of it: there combat_exp comes only from
## do_attack() against someone stronger and from 朱鸿雪's tasks. Nothing here changes a
## ported formula; pacing.json's knobs say whether it is used (left out: ES2).
## - stages: from `min_exp` combat_exp on, a one-time reward is `unit` times its kind's
##   percent / 100, and (pacing `staged_potential_cap`) at most `potential_cap` potential
##   stays unspent instead of combatd.c's 100.
## - rewards: each kind's percent of the stage's unit; `potential_percent` of the exp
##   comes as potential too.
## - chain_percent: a chain whose reward is not the kind's own.
## - notable_npcs: NPC definitions whose defeat is the `defeat` kind, not `spar`.
## - places: zones whose first visit is the `place` kind (each region's first is `region`).
## - force_milestones: the max_force numbers whose first reaching is the `force` kind
##   (前两小时 A, owner Q5; DECISIONS「新手链与当前目标」).

## BOUNTY: a 雪亭驿 bounty done (repeatable: BountyBoard, no ledger key).
## FORCE: max_force first reached one of `force_milestones` (the id is the number).
## QUEST: a quest (StoryQuestDefinition) done whose reward says `milestone` (任务系统;
## `quest_percent` overrides the kind's percent for one quest, as chain_percent does).
enum Kind { SPAR, DEFEAT, CHAIN, BOOK, REGION, PLACE, BOUNTY, FORCE, QUEST }

const KIND_KEYS: Dictionary[String, Kind] = {
	"spar": Kind.SPAR, "defeat": Kind.DEFEAT, "chain": Kind.CHAIN, "book": Kind.BOOK,
	"region": Kind.REGION, "place": Kind.PLACE, "bounty": Kind.BOUNTY, "force": Kind.FORCE,
	"quest": Kind.QUEST,
}
## combatd.c: potential grows while less than 100 of it is unspent.
const ES2_POTENTIAL_CAP: int = 100


class Stage:
	extends RefCounted
	var min_exp: int
	var unit: int
	var potential_cap: int


var stages: Array[Stage] = []
var percents: Dictionary[Kind, int] = {}
var potential_percent: int = 0
var chain_percent: Dictionary[StringName, int] = {}
var quest_percent: Dictionary[StringName, int] = {}
var notable_npcs: Dictionary[StringName, bool] = {}
var places: Dictionary[StringName, bool] = {}
## Rising max_force numbers; empty when 打坐 earns no 历练.
var force_milestones: Array[int] = []


## The stage `combat_exp` stands in (the first when there is none).
func stage(combat_exp: int) -> Stage:
	var found: Stage = null if stages.is_empty() else stages[0]
	for candidate: Stage in stages:
		if candidate.min_exp <= combat_exp:
			found = candidate
	return found


## The exp a reward of `kind` (or of chain or quest `chain_id`) is worth at `combat_exp`.
@warning_ignore("integer_division")
func reward_exp(kind: Kind, combat_exp: int, chain_id: StringName = &"") -> int:
	var at: Stage = stage(combat_exp)
	if at == null:
		return 0
	var percent: int = int(percents.get(kind, 0))
	if kind == Kind.CHAIN and chain_percent.has(chain_id):
		percent = chain_percent[chain_id]
	if kind == Kind.QUEST and quest_percent.has(chain_id):
		percent = quest_percent[chain_id]
	return at.unit * percent / 100


static func from_record(reader: ContentRecordReader) -> ProgressionRules:
	var rules := ProgressionRules.new()
	reader.text("source")
	rules.potential_percent = reader.integer("potential_percent", 0)
	for record: ContentRecordReader in reader.children("stages"):
		var at := Stage.new()
		at.min_exp = record.required_integer("min_exp")
		at.unit = record.required_integer("unit")
		at.potential_cap = record.required_integer("potential_cap")
		record.finish()
		if at.unit < 0 or at.potential_cap < ES2_POTENTIAL_CAP:
			record.fail("", "unit must not be negative and potential_cap must be at least %d" % ES2_POTENTIAL_CAP)
		rules.stages.append(at)
	if rules.stages.is_empty() or rules.stages[0].min_exp != 0:
		reader.fail("stages", "expected stages starting at min_exp 0")
	for index: int in range(1, rules.stages.size()):
		if rules.stages[index].min_exp <= rules.stages[index - 1].min_exp:
			reader.fail("stages", "min_exp %d does not rise" % rules.stages[index].min_exp)
	var percents: Dictionary[String, int] = reader.integer_map("rewards")
	for key: String in percents:
		if not KIND_KEYS.has(key):
			reader.fail("rewards", "unknown kind '%s'" % key)
		elif percents[key] < 0:
			reader.fail("rewards", "'%s' must not be negative" % key)
		else:
			rules.percents[KIND_KEYS[key]] = percents[key]
	var chains: Dictionary[String, int] = reader.integer_map("chain_percent")
	for chain_id: String in chains:
		rules.chain_percent[StringName(chain_id)] = chains[chain_id]
	var quests: Dictionary[String, int] = reader.integer_map("quest_percent")
	for quest_id: String in quests:
		rules.quest_percent[StringName(quest_id)] = quests[quest_id]
	for npc_id: String in reader.text_list("notable_npcs"):
		rules.notable_npcs[StringName(npc_id)] = true
	for zone_id: String in reader.text_list("places"):
		rules.places[StringName(zone_id)] = true
	rules.force_milestones = reader.integer_list("force_milestones")
	for index: int in rules.force_milestones.size():
		if rules.force_milestones[index] <= 0 or (index > 0 and rules.force_milestones[index] <= rules.force_milestones[index - 1]):
			reader.fail("force_milestones", "expected rising positive numbers")
			break
	reader.finish()
	return rules
