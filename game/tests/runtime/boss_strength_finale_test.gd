extends "res://tests/runtime/boss_strength_test.gd"

## DECISIONS「主线必打的仗」: the 终章's must-win fights before the 封坛 (boss_strength_test has the
## how): the 湖畔's 鬼卒 when nobody guards it (the 潜入 road) and 商玦 in the 冰龙厅, alone or with
## his four when the dragons were beaten.

const FINALE_BANDS: Dictionary[String, Array] = {
	"终章 湖畔 鬼卒×3（潜入的路）": [0.35, 0.90],
	"终章 冰龙厅 商玦": [0.35, 0.90],
	"终章 冰龙厅 商玦+四道士（打过冰龙）": [0.35, 0.90],
}


func _bands() -> Dictionary[String, Array]:
	return FINALE_BANDS
