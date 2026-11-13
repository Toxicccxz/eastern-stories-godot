extends "res://tests/runtime/boss_strength_bearer_test.gd"

## The fist build (柳家拳, bare-handed: no weapon to choose) of boss_strength_bearer_test.gd's fights.

const FIST_TARGETS: Dictionary[String, Variant] = {
	"终章 湖畔 鬼卒×3（没拿旋芒·长剑，皇叔并肩）": HELPED,
	"终章 冰龙厅 商玦（没拿旋芒·长剑，皇叔并肩）": HELPED,
	"终章 冰龙厅 商玦+四道士（没拿旋芒·长剑，皇叔并肩）": DRAGONS_BEATEN,
}


func _build() -> StringName:
	return MainlineFightSim.FIST


func _bearer_targets() -> Dictionary[String, Variant]:
	return FIST_TARGETS
