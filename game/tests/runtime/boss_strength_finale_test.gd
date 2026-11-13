extends "res://tests/runtime/boss_strength_test.gd"

## DECISIONS「主线必打的仗」: the 终章's must-win fights before the 封坛 (boss_strength_test has the
## how): the 湖畔's 鬼卒 when nobody guards it (the 潜入 road) and 商玦 in the 冰龙厅, alone or with
## his four when the dragons were beaten; the sword build with 旋芒 in hand.

const FINALE_TARGETS: Dictionary[String, Variant] = {
	"终章 湖畔 鬼卒×3（潜入的路）": ALONE,
	"终章 冰龙厅 商玦": ALONE,
	"终章 冰龙厅 商玦+四道士（打过冰龙）": ALONE,
}


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _run_targets(tree, FINALE_TARGETS)
	return {"assertions": _count, "failures": _failures.duplicate()}
