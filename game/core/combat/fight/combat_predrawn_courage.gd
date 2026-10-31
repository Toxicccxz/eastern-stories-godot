class_name CombatPredrawnCourage
extends RefCounted

## 战斗决策层 4 (DECISIONS「战斗内容」): combatd.c fight()'s courage draw, random(victim cps × 3),
## taken one beat early with the NPC's next move (npc_telegraph), so the card can say the
## NPC will guard instead (「起手：守势」). decide() spends it when the victim and the bound are
## still the same; otherwise it draws as before. The threshold is fight()'s: cor + 杀气 / 50.

var victim_id: StringName
var bound: int
var draw: int
var threshold: int


func _init(p_victim_id: StringName = &"", p_bound: int = 0, p_draw: int = 0, p_threshold: int = 0) -> void:
	victim_id = p_victim_id
	bound = p_bound
	draw = p_draw
	threshold = p_threshold


## fight(): the attack comes when the draw is under the threshold (always when the bound
## is 0: random(0) is 0 and 0 < cor).
func attacks() -> bool:
	return bound <= 0 or draw < threshold


func matches(p_victim_id: StringName, p_bound: int) -> bool:
	return victim_id == p_victim_id and bound == p_bound
