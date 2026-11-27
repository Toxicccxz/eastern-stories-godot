extends "res://tests/runtime/boss_strength_test.gd"

## DECISIONS「势力线的仗」(owner 2026-11-19「都按推荐」): the faction lines' fights a player reaches and
## must get past, by the same rule as the main story's (about six in ten for a character who follows
## only the main story, at the earliest arrival from which the line's step can be reached:
## MainlineFightSim.FACTION_FIGHTS), sword build; boss_strength_faction_fist_test the fist build.
## Sampled from FACTION_SEEDS: four seeds of DUELS duels (about 60), steadier than the main suites'
## three (the review found 42 duels give ±15 points). The fights a line meets on its way that are not
## walls (inside the 道观, the 鬼卒, the 量水的道士, the 兵部画吏, the escort's robbers) are
## boss_strength_faction_easy_test's. 前院's 玄冥子 when found out is an escape, not a fight: none here
## (faction_niling_c_test plays it out).

const FACTION_SEEDS: Array[int] = [7, 11, 13, 17]
const FACTION_TARGETS: Dictionary[String, Variant] = {
	"晚月 前厅 神教杀手": ALONE,
	"官府 整肃 军师赫造基": ALONE,
	"花紫会 密信 小屋信使": ALONE,
	# The three on the 北麓 after one is found out: no wall (owner: beatable with a weapon), not tuned.
	"卧底 被识破 追杀的道士×3": [0.45, 1.0],
}

## 成长曲线 C (DECISIONS「成长曲线 C」): at 花紫会's 小屋 the fist build is ahead by about thirty points
## (its bare hands' share, 120% of its level, is about 83 by the ninth chapter; the sword build's
## 长剑 is 25, 卢卡's 大秦短剑 55), as wide as the band: the sword build keeps the band, the fist build
## only its floor.
const AHEAD_WITH_FIST: Array[String] = ["花紫会 密信 小屋信使"]


static func faction_targets(build: StringName) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = FACTION_TARGETS.duplicate()
	if build == MainlineFightSim.FIST:
		for label: String in AHEAD_WITH_FIST:
			out[label] = [float(FACTION_TARGETS[label]) - SPREAD, CEILING]
	return out


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _run_targets(tree, faction_targets(_build()))
	return {"assertions": _count, "failures": _failures.duplicate()}


func _seeds() -> Array[int]:
	return FACTION_SEEDS
