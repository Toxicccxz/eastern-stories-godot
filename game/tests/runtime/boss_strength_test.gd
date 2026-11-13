extends RefCounted

## DECISIONS「主线必打的仗」(owner 2026-11-10「按这个调」, 2026-11-12「按推荐调」): the fights the main
## story cannot be got past without, fought as the game fights them (tests/sim/mainline_fight_sim.gd:
## the real coordinator and scheduler, the player's 2 beats a round and each NPC's own, the whole
## group, the helpers the story guarantees, a fixed plain policy) by a character grown to the main
## story's own arrival exp (tests/support/story_arrival.gd, from progression.json's 历练), in two
## builds: the sword (封山剑法, a sword in hand) and the fist (柳家拳, bare-handed: the first teacher's
## school, DECISIONS「空手对兵器」). The target is about six in ten without help and nine in ten with
## the story's own helpers; provisional until growth is set.
##
## Each fight is a sample: three seeds of DUELS duels pooled (about 45), the band the target ±
## SPREAD (a true rate 15 points off is flagged about nine times in ten, a rate on target about
## once in fifty). A miss by a few points can be chance: re-measure with more seeds before
## retuning (the failure message says how).
##
## Split for the suites' shards: this one 第一章's cave and 第三章 to 第五章; boss_strength_guanbei_test 第六章 and
## 第九章's choice fight; boss_strength_finale_test the 终章's 湖畔 and 冰龙厅; boss_strength_demon_test
## 侮天鬼's four forms; each with a `_fist` twin for the fist build.

const Arrival := preload("res://tests/support/story_arrival.gd")

const SEEDS: Array[int] = [7, 11, 13]
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
		var results: Array[MainlineFightSim.Result] = await sim.run_seeds(entry, DUELS, SEEDS, [MainlineFightSim.exps_of(entry)[0]])
		var result: MainlineFightSim.Result = results[0]
		var limits: Array[float] = band(targets[label])
		rates[label] = result.rate()
		# The first duel of each session closes at once (MainlineFightSim leaves it out).
		_check(result.lineup_ok() and result.short_lineup <= SEEDS.size() and result.stuck == 0, "%s (%s): the story's lineup fought (foes %d/%d, helpers %d/%d, nobody else: %d), every duel to its end: %s" % [label, _build(), result.enemies_in, result.expected_enemies, result.allies_in, result.expected_allies, result.others_in, result.notes])
		_check(result.duels >= (DUELS - 1) * SEEDS.size() and result.rate() >= limits[0] and result.rate() <= limits[1], "%s (%s build) at %d exp: won %d of %d (%.0f%%; band %.0f–%.0f%%), median %d rounds, %.0f%% of 气 lost on average. A sample: before retuning, re-measure with more seeds — <godot> --headless --fixed-fps 60 --path game --script res://tests/sim/run_mainline_fight_sim.gd -- only=%s build=%s seed=7,11,13,17,19,23 n=15 low" % [label, _build(), result.experience, result.wins, result.duels, result.rate() * 100.0, limits[0] * 100.0, limits[1] * 100.0, result.median_rounds(), result.mean_kee_lost() * 100.0, label, _build()])
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
