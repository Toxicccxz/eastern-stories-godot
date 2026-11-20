extends "res://tests/runtime/boss_strength_test.gd"

## DECISIONS「势力线的仗」: the faction lines' other fights, the ones a line meets on its way (inside the
## 道观 on the spy line, 绝尘's and 山烟寺's 鬼卒, 东方神教's 量水的道士 and 兵部画吏, 振远's robbers), at
## the earliest arrival from which each is reached (MainlineFightSim.FACTION_FIGHTS), sword build;
## boss_strength_faction_easy_fist_test the fist build. Not tuned: each is won most times by a
## character who follows only the main story, and this keeps it so — a change elsewhere (growth,
## a rule, the foe's numbers) that turns one into a wall shows here. One seed of 15 duels: a fight
## won nine times in ten falls below FLOOR by chance about once in a thousand runs (振远's robbers,
## three in four for the fist build at 第二章's arrival, have a lower floor of their own).

const EASY_SEEDS: Array[int] = [7]
const FLOOR: Array[float] = [0.60, 1.0]
const EASY_TARGETS: Dictionary[String, Variant] = {
	"卧底 前殿 巡殿道士": FLOOR,
	"卧底 账房 管事道士": FLOOR,
	"卧底 前殿 领诵道士": FLOOR,
	"卧底 甬道 看牢的狱卒": FLOOR,
	"绝尘 山洞 洞口的鬼卒": FLOOR,
	"绝尘 山洞 洞底的鬼卒": FLOOR,
	"山烟寺 树王坟 鬼卒": FLOOR,
	"东方神教 湖边 量水的道士": FLOOR,
	"东方神教 隘口 兵部画吏": FLOOR,
	"振远 碎石小路 劫镖的": [0.40, 1.0],
}


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _run_targets(tree, EASY_TARGETS)
	return {"assertions": _count, "failures": _failures.duplicate()}


func _seeds() -> Array[int]:
	return EASY_SEEDS
