extends RefCounted

## DECISIONS「主线必打的仗」(owner 2026-11-10「按这个调」): the fights the main story cannot be got past
## without, fought as the game fights them (tests/sim/mainline_fight_sim.gd: the real coordinator and
## scheduler, the player's 2 beats a round and each NPC's own, the whole group, the helpers the story
## guarantees, a fixed plain policy and seed) by a character grown to the story path's arrival exp on
## the main story alone (tests/support/grown_character.gd, the sword build). The target is about six in
## ten without help and nine in ten with the story's own helpers; the bands are wide: they flag a
## retune when the numbers or the growth move, not the exact rate. Provisional until growth is set.
## 第一章's 黑衣道士 is the first two hours' (pinned there); 第九章 揭发's 庾子建 with 冯策 is a
## choice's fight (DECISIONS「主线人物的武功」), kept here as before.

## Split three ways for the suites' shards: this one 第三章 to 第六章 (and 第九章's choice fight);
## boss_strength_finale_test the 终章's 湖畔 and 冰龙厅; boss_strength_demon_test 侮天鬼's four forms.

const DUELS: int = 16
## Label -> [low, high] of the share won at the fight's first (main story only) exp.
const BANDS: Dictionary[String, Array] = {
	"第三章 祭坛 鬼卒×2": [0.35, 0.90],
	"第三章 救人 带钥匙的狱卒×2": [0.35, 0.90],
	"第五章 树洞 鬼卒×2": [0.35, 0.90],
	"第六章 借兵 踏平工地": [0.70, 1.00],
	"第六章 潜入 守夜武官×2": [0.70, 1.00],
	"第九章 揭发 庾子建（冯策并肩，选择）": [0.10, 0.70], # a choice's fight, not tuned here: about a quarter on the main story alone
}

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _run_bands(tree, _bands())
	return {"assertions": _count, "failures": _failures.duplicate()}


func _bands() -> Dictionary[String, Array]:
	return BANDS


## Each fight's share won against its band; the rates by label.
func _run_bands(tree: SceneTree, bands: Dictionary[String, Array]) -> Dictionary[String, float]:
	var rates: Dictionary[String, float] = {}
	for label: String in bands:
		var entry: Dictionary = MainlineFightSim.fight(label)
		_check(not entry.is_empty(), "%s is one of the sim's fights" % label)
		if entry.is_empty():
			continue
		var sim := MainlineFightSim.new(tree)
		var results: Array[MainlineFightSim.Result] = await sim.run(entry, DUELS, 7, [entry["exps"][0]])
		var result: MainlineFightSim.Result = results[0]
		var band: Array = bands[label]
		rates[label] = result.rate()
		# The first duel of a session closes at once (MainlineFightSim leaves it out): one may be left out.
		_check(result.lineup_ok() and result.short_lineup <= 1 and result.stuck == 0, "%s: the story's lineup fought (foes %d/%d, helpers %d/%d, nobody else: %d), every duel to its end: %s" % [label, result.enemies_in, result.expected_enemies, result.allies_in, result.expected_allies, result.others_in, result.notes])
		_check(result.duels >= DUELS - 1 and result.rate() >= float(band[0]) and result.rate() <= float(band[1]), "%s at %d exp: won %.0f%% of %d (%.0f–%.0f%%), median %d rounds" % [label, result.experience, result.rate() * 100.0, result.duels, float(band[0]) * 100.0, float(band[1]) * 100.0, result.median_rounds()])
	return rates


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
