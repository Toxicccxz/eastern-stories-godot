class_name CombatRoundBeats
extends RefCounted

## 战斗拍数 A (DECISIONS「战斗拍数」): one fighter's beats in one round — how many it started
## with, how many are left, what each beat spent went on (the move's tag, or the action's
## key) and the beats it won and how (CombatSchoolSkeleton's label). The scheduler keeps one
## per participant per round; the panel reads it (包 B).

var actor_id: StringName
var base: int
var remaining: int
## What each beat went on, in order: a move's tag (平 under &""), perform/<id>, busy...
var spent: Array[StringName] = []
## The beats won this round, by their source (CombatSchoolSkeleton.earn).
var earned: Array[StringName] = []
## Whether the fighter's round-end work (its chat, its next plan) already ran: a beat won
## after that is taken on a fresh draw.
var settled: bool = false


func _init(p_actor_id: StringName = &"", p_base: int = 1) -> void:
	actor_id = p_actor_id
	base = maxi(0, p_base)
	remaining = base


func has_beats() -> bool:
	return remaining > 0


func can_afford(cost: int) -> bool:
	return cost <= remaining


## A beat went on `key` at `cost`; a cost above what is left takes the rest of the round.
func spend(key: StringName, cost: int) -> void:
	remaining = maxi(0, remaining - maxi(1, cost))
	spent.append(key)


## The fighter won a beat from `source`, within `cap` a round. Returns whether it counted.
func earn(source: StringName, cap: int) -> bool:
	if earned.size() >= cap:
		return false
	earned.append(source)
	remaining += 1
	return true


## The fighter is out of the round (unavailable, no target): nothing left to spend.
func forfeit() -> void:
	remaining = 0


func beats_taken() -> int:
	return spent.size()
