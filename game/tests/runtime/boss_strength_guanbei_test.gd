extends "res://tests/runtime/boss_strength_test.gd"

## DECISIONS「主线必打的仗」: 第六章's two fights (郭承 and the 王府骑兵 beside the player: the helped
## band) and 第九章 揭发's 庾子建 with 冯策 beside (a choice's fight, DECISIONS「主线人物的武功」: not
## tuned, a wide band only); boss_strength_test has the how.

const GUANBEI_TARGETS: Dictionary[String, Variant] = {
	"第六章 借兵 踏平工地": HELPED,
	"第六章 潜入 守夜武官×2": HELPED,
	"第九章 揭发 庾子建（冯策并肩，选择）": [0.10, 0.80],
}


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _run_targets(tree, GUANBEI_TARGETS)
	return {"assertions": _count, "failures": _failures.duplicate()}
