extends "res://tests/runtime/boss_strength_test.gd"

## DECISIONS「主线必打的仗」: 侮天鬼's four forms (boss_strength_test has the how); 宝衣 and not
## having pulled the sword in 第八章 each make it easier (DECISIONS「终章 B」).

const DEMON_BANDS: Dictionary[String, Array] = {
	"终章 侮天鬼（穿宝衣·没拔过）": [0.45, 0.95],
	"终章 侮天鬼（没宝衣·没拔过）": [0.35, 0.90],
	"终章 侮天鬼（穿宝衣·拔过）": [0.35, 0.90],
	"终章 侮天鬼（没宝衣·拔过）": [0.30, 0.85],
}


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var rates: Dictionary[String, float] = await _run_bands(tree, DEMON_BANDS)
	# Sixteen duels a form are too few to order the two middle ones; the ends hold.
	var easy: float = rates.get("终章 侮天鬼（穿宝衣·没拔过）", -1.0)
	var hard: float = rates.get("终章 侮天鬼（没宝衣·拔过）", -1.0)
	_check(easy >= hard and hard >= 0.0, "侮天鬼 in 宝衣, unpulled, no harder than without, pulled: %.0f%% ≥ %.0f%%" % [easy * 100.0, hard * 100.0])
	return {"assertions": _count, "failures": _failures.duplicate()}
