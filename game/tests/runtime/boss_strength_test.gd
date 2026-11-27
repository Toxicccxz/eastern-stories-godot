extends RefCounted

## DECISIONS「主线必打的仗」(owner 2026-11-10「按这个调」, 2026-11-12「按推荐调」): the fights the main
## story cannot be got past without, fought as the game fights them (tests/sim/mainline_fight_sim.gd:
## the real coordinator and scheduler, the player's 2 beats a round and each NPC's own, the whole
## group, the helpers the story guarantees, a fixed plain policy) by a character grown to the main
## story's arrival exp the fights were tuned at (tests/support/story_arrival.gd's TUNED, which
## growth_curve_data_test holds the 历练-derived arrival to within 1%; the exploring tier: the
## 历练-derived arrival itself), in two
## builds: the sword (封山剑法, a sword in hand) and the fist (柳家拳, bare-handed: the first teacher's
## school, DECISIONS「空手对兵器」). The target is about six in ten without help and nine in ten with
## the story's own helpers; provisional until growth is set.
##
## Each fight is a sample in two stages: three seeds of DUELS duels pooled (42 counted: each
## session's first duel closes at once and is left out) against the band, the target ± SPREAD; a first
## sample outside it is measured again with as many new seeds (MORE_SEEDS) and the 84 judged pooled.
## As a binomial sample: a fight whose true rate is on target (six in ten) fails about once in 500 runs
## (nine in ten with help: about once in 1,000); one whose true rate is 15 points off lies on the
## band's edge and is caught about a third of the time (20 points off: about three times in four; 15
## points under the helped band: about a third). So the suites catch a fight gone far off, not one
## drifting to an edge: re-measure with more seeds when a number looks near one. The seeds are fixed,
## so a run repeats itself: what changes a result is a change to the game or to these suites (成长曲线 A:
## even 落后补偿 on the in-fight trickle reshuffles every duel). Each fight's numbers are printed as
## it ends, so a suite cut off by its time limit still leaves them.
##
## Split for the suites' shards: this one 第一章's cave and 第三章 to 第五章; boss_strength_guanbei_test 第六章 and
## 第九章's choice fight; boss_strength_finale_test the 终章's 湖畔 and 冰龙厅; boss_strength_demon_test
## 侮天鬼's four forms; each with a `_fist` twin for the fist build.

const Arrival := preload("res://tests/support/story_arrival.gd")

const SEEDS: Array[int] = [7, 11, 13]
## A first sample outside its band is measured again with these and judged pooled (the re-measure the
## failure message asks for): a seeded sample of some 45 duels swings ±7–15 points, so a change too
## small to move a win rate (成长曲线 A: 落后补偿 on the in-fight trickle) can push it across an
## edge either way.
const MORE_SEEDS: Array[int] = [17, 19, 23, 29, 31]
## Seeds no suite here pools: the failure message's re-measure (with MORE_SEEDS' they would only
## repeat the pooled sample).
const FRESH_SEEDS: String = "37,41,43,47,53,59"
const DUELS: int = 15
const ALONE: float = 0.60
const HELPED: float = 0.90
const SPREAD: float = 0.15
## The most a band reaches: a fight won every time is flagged too.
const CEILING: float = 0.98
## Label -> the target share won at the fight's main-story exp, or [low, high] for a fight that is
## not tuned to a target.
const TARGETS: Dictionary[String, Variant] = {
	# The first two hours' end (第一章's cave): tuned there, pinned here so it stays an easy one.
	"第一章 山洞 黑衣道士": [0.90, 1.00],
	"第三章 祭坛 鬼卒×2": ALONE,
	"第三章 救人 带钥匙的狱卒×2": ALONE,
	"第三章 追宫主 玄冥子": ALONE,
	"第五章 树洞 鬼卒×2": ALONE,
	"第五章 护送 庾家管事+打手×3": ALONE,
}

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_check_arrivals()
	await _run_targets(tree, _targets())
	return {"assertions": _count, "failures": _failures.duplicate()}


func _targets() -> Dictionary[String, Variant]:
	return TARGETS


func _build() -> StringName:
	return MainlineFightSim.SWORD


## The seeds each fight is sampled from (boss_strength_faction_test samples more).
func _seeds() -> Array[int]:
	return SEEDS


## As many of MORE_SEEDS as the suite's own seeds, none of them already used.
func _more_seeds() -> Array[int]:
	var out: Array[int] = []
	for seed: int in MORE_SEEDS:
		if not _seeds().has(seed) and out.size() < _seeds().size():
			out.append(seed)
	return out


## The band of `target` (a share, or [low, high]).
static func band(target: Variant) -> Array[float]:
	if target is Array:
		return [float(target[0]), float(target[1])]
	return [maxf(0.0, float(target) - SPREAD), minf(CEILING, float(target) + SPREAD)]


## Each fight's share won against its band; the rates by label.
func _run_targets(tree: SceneTree, targets: Dictionary[String, Variant]) -> Dictionary[String, float]:
	var rates: Dictionary[String, float] = {}
	for label: String in targets:
		var entry: Dictionary = MainlineFightSim.fight(label)
		_check(not entry.is_empty(), "%s is one of the sim's fights" % label)
		if entry.is_empty():
			continue
		var sim := MainlineFightSim.new(tree)
		sim.build = _build()
		var results: Array[MainlineFightSim.Result] = await sim.run_seeds(entry, DUELS, _seeds(), [MainlineFightSim.exps_of(entry)[0]])
		var result: MainlineFightSim.Result = results[0]
		var limits: Array[float] = band(targets[label])
		var seeds_used: int = _seeds().size()
		if result.rate() < limits[0] or result.rate() > limits[1]:
			var again := MainlineFightSim.new(tree)
			again.build = _build()
			var extra: Array[int] = _more_seeds()
			var more: Array[MainlineFightSim.Result] = await again.run_seeds(entry, DUELS, extra, [MainlineFightSim.exps_of(entry)[0]])
			result.pool(more[0])
			seeds_used += extra.size()
		rates[label] = result.rate()
		# As each fight ends: a suite stopped by its time limit still leaves the numbers in the log.
		print("boss_strength: %s (%s) at %d exp: %d of %d (%.0f%%; band %.0f–%.0f%%) over %d seeds" % [label, _build(), result.experience, result.wins, result.duels, result.rate() * 100.0, limits[0] * 100.0, limits[1] * 100.0, seeds_used])
		# The first duel of each session closes at once (MainlineFightSim leaves it out).
		_check(result.lineup_ok() and result.short_lineup <= seeds_used and result.stuck == 0, "%s (%s): the story's lineup fought (foes %d/%d, helpers %d/%d, nobody else: %d), every duel to its end: %s" % [label, _build(), result.enemies_in, result.expected_enemies, result.allies_in, result.expected_allies, result.others_in, result.notes])
		_check(result.duels >= (DUELS - 1) * seeds_used and result.rate() >= limits[0] and result.rate() <= limits[1], "%s (%s build) at %d exp: won %d of %d (%.0f%%; band %.0f–%.0f%%), median %d rounds, %.0f%% of 气 lost on average. A sample (pooled with as many more seeds when the first fell outside): before retuning, re-measure with seeds none of the suites used — <godot> --headless --fixed-fps 60 --path game --script res://tests/sim/run_mainline_fight_sim.gd -- only=%s build=%s %sseed=%s n=15 low" % [label, _build(), result.experience, result.wins, result.duels, result.rate() * 100.0, limits[0] * 100.0, limits[1] * 100.0, result.median_rounds(), result.mean_kee_lost() * 100.0, label, _build(), "faction " if MainlineFightSim.FACTION_FIGHTS.has(MainlineFightSim.fight(label)) else "", FRESH_SEEDS])
	return rates


## The arrival exps the suites grow to come from 历练 (story_arrival.gd), each chapter's above the last.
func _check_arrivals() -> void:
	var last: int = 0
	var missing: Array[StringName] = []
	for chapter: Array in Arrival.ROUTE:
		var main: int = Arrival.main_story(chapter[0])
		_check(main > last and Arrival.exploring(chapter[0]) > main and GameContent.catalog().story_quest(chapter[0]) != null, "%s: arrival %d (exploring %d) above the last chapter's, and a quest of the story" % [chapter[0], main, Arrival.exploring(chapter[0])])
		last = main
	for region: StringName in Arrival.regions():
		if GameContent.catalog().region(region) == null:
			missing.append(region)
	_check(missing.is_empty(), "story_arrival.gd's regions all exist: %s missing" % [missing])


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
