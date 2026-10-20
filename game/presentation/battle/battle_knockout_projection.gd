class_name BattleKnockoutProjection
extends RefCounted

## DECISIONS「了结 / 放过」: one who fell while the player's side was killing them, waiting
## on the player's choice. Read-only value snapshot.
var _revive_seconds: int
## Seconds until they come to, counted on the fight's clock (0: any moment now).
var revive_seconds: int:
	get: return _revive_seconds
var _quest_target: bool
## Killing them does the task 朱鸿雪 gave.
var quest_target: bool:
	get: return _quest_target
var _own_master: bool
## They are the player's own master: killing them leaves the family (弑师).
var own_master: bool:
	get: return _own_master


func _init(p_revive_seconds: int = 0, p_quest_target: bool = false, p_own_master: bool = false) -> void:
	_revive_seconds = p_revive_seconds
	_quest_target = p_quest_target
	_own_master = p_own_master
