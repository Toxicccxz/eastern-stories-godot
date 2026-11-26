extends RefCounted

## 成长曲线 A (owner 2026-11-19「都照推荐」; DECISIONS「成长曲线 A」): the 历练 data the growth curve
## rests on. The main story alone still arrives at each chapter with the exp its must-win fights
## were tuned at (DECISIONS「主线必打的仗」), now from each chapter's own quest instead of 落后补偿;
## the regions' recommended_exp is the main story's arrival there (the 地图 page's 「适合经验」, and
## what 落后补偿 measures against); each faction line, and the 虹台 assembly, pays a share when done;
## a one-time 历练 is priced at most one stage above its content's own; the death price is 1%;
## 瑷伦 takes a student from 30000 exp and her lashes spare them.

const Arrival := preload("res://tests/support/story_arrival.gd")

## How far (percent) an arrival may drift from TUNED before the fights need measuring again.
const DRIFT_PERCENT: int = 1
## Regions the first two hours walk (their recommended_exp is tuned with them, DECISIONS「经验节奏」):
## kept, at or below the main story's arrival there.
const FIRST_HOURS: Array[StringName] = [&"oldpine", &"cloud", &"goathill"]
## The share a finished faction line pays (percent of the stage unit).
const LINE_PERCENT: int = 300

var _count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_arrival_kept()
	_test_recommended_is_arrival()
	_test_lines_pay()
	_test_stage_headroom()
	_test_knobs()
	return {"assertions": _count, "failures": _failures.duplicate()}


## Each chapter's arrival (main story alone) within DRIFT_PERCENT of what the fights were tuned at
## (StoryArrival.TUNED, where the strength suites measure them).
func _test_arrival_kept() -> void:
	for quest_id: StringName in Arrival.TUNED:
		var arrival: int = Arrival.main_story(quest_id)
		var tuned: int = Arrival.TUNED[quest_id]
		_check(absi(arrival - tuned) * 100 <= tuned * DRIFT_PERCENT, "%s: the main story arrives with %d exp, the must-win fights were tuned at %d (within %d%%; more, and run_mainline_fight_sim.gd must tune them again)" % [quest_id, arrival, tuned, DRIFT_PERCENT])


## A region the main story first leads into has the exp it arrives with there as its recommended_exp
## (within DRIFT_PERCENT): the 地图 page's 「适合经验」 is true, and 落后补偿 helps only one who is behind.
func _test_recommended_is_arrival() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var seen: Dictionary[StringName, bool] = {}
	for chapter: Array in Arrival.ROUTE:
		var arrival: int = Arrival.main_story(chapter[0])
		for reward: Array in chapter[1]:
			var region_id: StringName = reward[1]
			if reward[0] != &"region" or seen.has(region_id):
				continue
			seen[region_id] = true
			var region: RegionDefinition = catalog.region(region_id)
			if region == null:
				_check(false, "no region %s" % region_id)
				continue
			if FIRST_HOURS.has(region_id):
				_check(region.recommended_exp <= arrival, "%s (the first two hours'): recommended %d, at or below the main story's %d there" % [region_id, region.recommended_exp, arrival])
			else:
				_check(absi(region.recommended_exp - arrival) * 100 <= arrival * DRIFT_PERCENT, "%s: recommended %d is the main story's arrival there (%d, %s)" % [region_id, region.recommended_exp, arrival, chapter[0]])
	_check(seen.size() >= 14, "the route leads into the regions it should (%d)" % seen.size())


## Every faction line and the assembly: a quest-level 历练 of LINE_PERCENT when the whole quest is done.
func _test_lines_pay() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var rules: ProgressionRules = catalog.progression()
	var lines: int = 0
	for quest: StoryQuestDefinition in catalog.story_quests():
		if quest.line != StoryQuestDefinition.LINE_FACTION:
			continue
		lines += 1
		_check(quest.reward != null and quest.reward.milestone, "%s: done, it pays a 历练" % quest.quest_id)
		_check(rules.quest_percent.get(quest.quest_id, -1) == LINE_PERCENT, "%s: %d%% of the stage unit (%s)" % [quest.quest_id, LINE_PERCENT, rules.quest_percent.get(quest.quest_id, -1)])
	_check(lines == 13, "twelve lines and the assembly (%d)" % lines)


## A one-time 历练 is priced at most milestone_stage_headroom stages above its content's own; a
## quest (no content level) at the player's stage.
func _test_stage_headroom() -> void:
	var rules: ProgressionRules = GameContent.catalog().progression()
	var headroom: int = GameContent.catalog().pacing().milestone_stage_headroom
	_check(headroom == 1, "pacing.json: one stage of headroom (%d)" % headroom)
	# 雪亭镇 (recommended 300: the 150 stage) at 30000 exp: priced at the 400 stage (unit 80), not 1200.
	_check(rules.reward_exp(ProgressionRules.Kind.CHAIN, 30000, &"snow.newcomer", 300, headroom) == 80 and rules.reward_exp(ProgressionRules.Kind.CHAIN, 30000, &"snow.newcomer") == 1200, "a 雪亭镇 chain claimed at 30000: one unit of the 400 stage (80), not 30000's (1200)")
	_check(rules.reward_exp(ProgressionRules.Kind.REGION, 4690, &"", 4696, headroom) == rules.reward_exp(ProgressionRules.Kind.REGION, 4690), "the main story arriving where it is recommended: no cap")
	_check(rules.reward_exp(ProgressionRules.Kind.QUEST, 30000, &"main.chapter9", -1, headroom) == rules.reward_exp(ProgressionRules.Kind.QUEST, 30000, &"main.chapter9"), "a quest has no content level: the player's stage")
	_check(rules.priced_stage(30000, 300, -1).unit == 1200, "headroom -1 (A2): the player's stage")
	var state := CharacterState.new()
	state.progression.combat_experience = 30000
	var grant: MilestoneRewards.Grant = MilestoneRewards.grant(state, rules, ProgressionRules.Kind.CHAIN, &"snow.newcomer", 0, true, WorldProgressionRewards.chain_level(&"snow.newcomer"), headroom)
	_check(grant != null and grant.exp_gain == 80, "granted: the chain's region (雪亭镇, by the id's first part) prices it (%s)" % (-1 if grant == null else grant.exp_gain))
	_check(WorldProgressionRewards.chain_level(&"native.anything") == -1, "a chain whose first part is no region: no cap")


func _test_knobs() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var pacing: PacingDefinition = catalog.pacing()
	# Suites run with ES2's death price (TestDeath): pacing.json's own, from the file.
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/common/pacing.json"))["pacing"]
	_check(int(record.get("death_exp_percent", -1)) == 1, "pacing.json: a death takes 1%% of combat_exp (%s)" % record.get("death_exp_percent"))
	_check(pacing.exp_gate(&"elon", 100000) == 30000, "瑷伦's gate: 30000")
	var rule: NpcTeaching.ApprenticeRule = catalog.npc(&"latemoon.npc.room.elon").teaching().apprentice
	var gate: int = -1
	for check: NpcTeaching.RequirementCheck in rule.checks:
		if check.exp_gate == &"elon":
			gate = check.requires.get(&"combat_exp", -1)
	_check(gate == 30000, "her check of combat_exp follows the gate (%d; ES2 100000 kept in the data)" % gate)
	_check(rule.inner_force_percent == 35 and not rule.lethal, "her lashes: 35% of her inner force, never lethal")
	var modifiers: CombatRoundModifiers = rule.blow_modifiers()
	_check(modifiers != null and modifiers.inner_force_percent == 35 and modifiers.spare_life, "the blows' modifiers carry it")
	var ranks := NpcTeaching.ApprenticeRule.new()
	_check(ranks.blow_modifiers() == null, "left out: champion.c's own blows")


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
