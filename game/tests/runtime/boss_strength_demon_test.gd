extends "res://tests/runtime/boss_strength_test.gd"

## DECISIONS「主线必打的仗」: 侮天鬼's four forms (boss_strength_test has the how); 宝衣 and not
## having pulled the sword in 第八章 each make it easier (DECISIONS「终章 B」).

const DEMON_TARGETS: Dictionary[String, Variant] = {
	"终章 侮天鬼（穿宝衣·没拔过）": ALONE,
	"终章 侮天鬼（没宝衣·没拔过）": ALONE,
	"终章 侮天鬼（穿宝衣·拔过）": ALONE,
	"终章 侮天鬼（没宝衣·拔过）": ALONE,
}
## How far the easiest form's sample may fall below the hardest's before it reads as harder: two
## samples of about 45 duels each differ by up to this much by chance.
const ORDER_SLACK: float = 0.15


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var rates: Dictionary[String, float] = await _run_targets(tree, DEMON_TARGETS)
	# The ends only: the two middle forms are too close to order on a sample.
	var easy: float = rates.get("终章 侮天鬼（穿宝衣·没拔过）", -1.0)
	var hard: float = rates.get("终章 侮天鬼（没宝衣·拔过）", -1.0)
	_check(hard >= 0.0 and easy + ORDER_SLACK >= hard, "%s: 侮天鬼 in 宝衣, unpulled, no harder than without, pulled (a sample; %.0f points of slack): %.0f%% against %.0f%%" % [_build(), ORDER_SLACK * 100.0, easy * 100.0, hard * 100.0])
	return {"assertions": _count, "failures": _failures.duplicate()}
