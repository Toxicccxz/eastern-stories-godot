extends "res://tests/runtime/boss_strength_test.gd"

## DECISIONS「主线必打的仗」(owner 2026-11-12「按推荐调」): the 终章 without a divine weapon — the
## player let 皇叔 or 萧辟尘 pull 旋芒 in 第十章 — fought with a 长剑 and with the 大秦短剑 one can buy,
## the one who pulled the sword beside the player at the 湖畔 (standing there, `fights_beside_here`)
## and in the 冰龙厅 (summoned by 商玦's scene): the helped band. The sim plays 皇叔; 萧辟尘's copies
## carry the same numbers (checked here). boss_strength_test has the how.

## 商玦 with his four (only when the dragons were beaten, a fight the player chose): the four go for the
## player, and the helper does what 旋芒 would — the band it has with 旋芒 in hand, a little wider.
const DRAGONS_BEATEN: Array = [0.45, 0.85]
const BEARER_TARGETS: Dictionary[String, Variant] = {
	"终章 湖畔 鬼卒×3（没拿旋芒·长剑，皇叔并肩）": HELPED,
	"终章 冰龙厅 商玦（没拿旋芒·长剑，皇叔并肩）": HELPED,
	"终章 冰龙厅 商玦+四道士（没拿旋芒·长剑，皇叔并肩）": DRAGONS_BEATEN,
	"终章 湖畔 鬼卒×3（没拿旋芒·大秦短剑，皇叔并肩）": HELPED,
	"终章 冰龙厅 商玦（没拿旋芒·大秦短剑，皇叔并肩）": HELPED,
	"终章 冰龙厅 商玦+四道士（没拿旋芒·大秦短剑，皇叔并肩）": DRAGONS_BEATEN,
}
## The pairs that must fight alike: 皇叔's copy and 萧辟尘's, at the 湖畔 and in the 冰龙厅.
const TWINS: Array[Array] = [
	[&"native.npc.yulan_tianwu_lake", &"native.npc.xiao_pichen_lake"],
	[&"native.npc.yulan_tianwu_lakebottom", &"native.npc.xiao_pichen_lakebottom"],
	[&"native.npc.yulan_tianwu_lake", &"native.npc.yulan_tianwu_lakebottom"],
]


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_check_twins()
	await _run_targets(tree, _bearer_targets())
	return {"assertions": _count, "failures": _failures.duplicate()}


func _bearer_targets() -> Dictionary[String, Variant]:
	return BEARER_TARGETS


func _check_twins() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for pair: Array in TWINS:
		var a: NpcDefinition = catalog.npc(pair[0])
		var b: NpcDefinition = catalog.npc(pair[1])
		var same: bool = a != null and b != null and a.combat_experience == b.combat_experience and _levels(a) == _levels(b) and a.hooks() != null and b.hooks() != null and a.hooks().fights_beside_player and b.hooks().fights_beside_player
		_check(same, "%s and %s fight alike (exp, skills) and beside the player" % [pair[0], pair[1]])
	for id: StringName in [&"native.npc.yulan_tianwu_lake", &"native.npc.xiao_pichen_lake"]:
		var npc: NpcDefinition = catalog.npc(id)
		_check(npc != null and npc.hooks() != null and npc.hooks().fights_beside_here, "%s stands its ground at the 湖畔 and fights beside the player there" % id)


static func _levels(npc: NpcDefinition) -> Array:
	return npc.skill_levels().map(func(level: NpcSkillLevelDefinition) -> String: return "%s %d" % [level.skill_id, level.raw_level])
