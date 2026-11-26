extends RefCounted

## TEST-ONLY (DECISIONS「主线必打的仗」): the combat_exp a character has on arriving at each chapter
## of the main story, derived from the game's own 历练 (common/progression.json's stages and reward
## percents, each quest's `quest_percent`, the regions' recommended_exp, pacing's 落后补偿 and its
## milestone_stage_headroom) along
## ROUTE, the one thing written here: what the main story alone earns in each chapter — the
## chapter's quest (`milestone`), the first visit of each region it leads into, the places
## (名胜) on its way, 第一章's 黑衣道士 (a notable defeat). Two tiers: the main story alone from the
## first two hours' 1000 exp, and a player who explores on the side from 2500. The sim
## (tests/sim/mainline_fight_sim.gd) and the boss_strength suites grow their character to these, so
## a change to 历练 moves the character the suites measure instead of leaving them green against a
## character nobody plays.

## Where the first two hours leave a player who follows the story, and one who explores too.
const MAIN_START: int = 1000
const EXPLORING_START: int = 2500

## Each chapter's quest and, in order, what it pays on the main story's own road: [kind, region]
## (`quest`: the chapter's quest in that region; `region`: the region's first visit; `place`: a
## 名胜 there; `defeat`: a notable foe there).
const ROUTE: Array[Array] = [
	[&"main.prologue", [[&"region", &"canyon"], [&"region", &"oldpine"], [&"quest", &"oldpine"]]],
	[&"main.chapter1", [[&"defeat", &"oldpine"], [&"place", &"oldpine"], [&"quest", &"oldpine"]]],
	[&"main.chapter2", [[&"region", &"cloud"], [&"region", &"waterfog"], [&"place", &"waterfog"], [&"place", &"waterfog"], [&"quest", &"waterfog"]]],
	[&"main.chapter3", [[&"region", &"goathill"], [&"region", &"niling"], [&"quest", &"niling"]]],
	[&"main.chapter4", [[&"region", &"latemoon"], [&"quest", &"latemoon"]]],
	[&"main.chapter5", [[&"region", &"choyin"], [&"place", &"choyin"], [&"place", &"choyin"], [&"quest", &"choyin"]]],
	[&"main.chapter6", [[&"region", &"guanbei"], [&"quest", &"guanbei"]]],
	[&"main.chapter7", [[&"region", &"village"], [&"region", &"fanfang"], [&"quest", &"fanfang"]]],
	[&"main.chapter8", [[&"place", &"village"], [&"quest", &"village"]]],
	[&"main.chapter9", [[&"region", &"city"], [&"region", &"imperial"], [&"quest", &"imperial"]]],
	[&"main.chapter10", [[&"region", &"lancheng"], [&"quest", &"lancheng"]]],
	[&"main.finale", [[&"quest", &"snow"]]],
]

const KINDS: Dictionary[StringName, ProgressionRules.Kind] = {
	&"quest": ProgressionRules.Kind.QUEST,
	&"region": ProgressionRules.Kind.REGION,
	&"place": ProgressionRules.Kind.PLACE,
	&"defeat": ProgressionRules.Kind.DEFEAT,
}


## The exp on arriving at `quest_id`'s chapter (before any of its own rewards) from `start`; with no
## `quest_id` (&""), after the last chapter's (the dev start 终章之后).
static func arrival(quest_id: StringName, start: int) -> int:
	var catalog: ContentCatalog = GameContent.catalog()
	var rules: ProgressionRules = catalog.progression()
	var max_percent: int = catalog.pacing().catch_up_max_percent
	var headroom: int = catalog.pacing().milestone_stage_headroom
	var progression := CharacterProgressionState.new()
	var exp: int = start
	for chapter: Array in ROUTE:
		if chapter[0] == quest_id:
			return exp
		for reward: Array in chapter[1]:
			var region: RegionDefinition = catalog.region(reward[1])
			var base: int = rules.reward_exp(KINDS[reward[0]], exp, chapter[0], content_level(reward[0], region), headroom)
			var percent: int = ProgressionGain.catch_up_percent(exp, 0 if region == null else region.recommended_exp, max_percent)
			exp += ProgressionGain.scaled(progression, base, percent)
	return exp if quest_id.is_empty() else -1


## The level of a ROUTE reward's content (pacing milestone_stage_headroom, as WorldProgressionRewards
## prices it): a region's or 名胜's region's recommended_exp; the notable foe's too (ROUTE names its
## region, not the foe: 第一章's 黑衣道士 is of 老松岭's level); a quest has none (-1).
static func content_level(kind: StringName, region: RegionDefinition) -> int:
	if kind == &"quest" or region == null or region.recommended_exp <= 0:
		return -1
	return region.recommended_exp


## The main story's arrival exp at each chapter that its must-win fights were tuned at (DECISIONS
## 「主线必打的仗」 second round; 成长曲线 A moved the 历练 around and kept it, DECISIONS「成长曲线 A」).
## The strength suites (tests/sim/mainline_fight_sim.gd's main-story tier) measure here, so a drift
## too small to move a win rate (成长曲线 A: 0.1–0.3%) does not reshuffle their seeded duels;
## growth_curve_data_test fails as soon as main_story() leaves it by more than 1%, and the fights
## must then be measured, and tuned, at the new arrival.
const TUNED: Dictionary[StringName, int] = {
	&"main.prologue": MAIN_START, &"main.chapter1": 1820, &"main.chapter2": 2495, &"main.chapter3": 4696,
	&"main.chapter4": 6505, &"main.chapter5": 8443, &"main.chapter6": 11626, &"main.chapter7": 14500,
	&"main.chapter8": 21136, &"main.chapter9": 22936, &"main.chapter10": 31486, &"main.finale": 37276,
}


## The arrival the must-win fights of `quest_id`'s chapter were tuned at (TUNED; main_story() for a
## chapter it does not name).
static func tuned(quest_id: StringName) -> int:
	return TUNED.get(quest_id, main_story(quest_id))


## The main story alone (from the first two hours' MAIN_START).
static func main_story(quest_id: StringName) -> int:
	return arrival(quest_id, MAIN_START)


## A player who explores on the side (EXPLORING_START).
static func exploring(quest_id: StringName) -> int:
	return arrival(quest_id, EXPLORING_START)


## Every region ROUTE names, for the check that each exists.
static func regions() -> Array[StringName]:
	var out: Array[StringName] = []
	for chapter: Array in ROUTE:
		for reward: Array in chapter[1]:
			if not out.has(reward[1]):
				out.append(reward[1])
	return out
