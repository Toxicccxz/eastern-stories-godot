class_name CombatSkeletonState
extends RefCounted

## 战斗拍数 A (DECISIONS「战斗拍数」): what a fighter's school skeleton (CombatSchoolSkeleton)
## reads of this fight — its own last move and whether it landed, whether it is 近身 (the
## `close` state: pulled apart at the start, close once a move of its lands, apart again
## once one misses), and the moves it used this round (for 换招). Kept by the scheduler for
## the fight, never saved.

var close: bool = false
var attacked: bool = false
var last_action_id: StringName = &""
var last_tag: StringName = &""
var last_landed: bool = false
var round_moves: Array[StringName] = []


## A new round began: the moves of the last one are forgotten (the rest stays).
func new_round() -> void:
	round_moves.clear()


## The fighter's move `action_id` (tag `tag`) struck or missed; `tracks_close` whether its
## skeleton keeps the 近身 state. Returns whether it changed its move from the last one this
## round (the 换招 fact).
func note_attack(action_id: StringName, tag: StringName, landed: bool, tracks_close: bool) -> bool:
	var changed: bool = not round_moves.is_empty() and round_moves.back() != action_id
	attacked = true
	last_action_id = action_id
	last_tag = tag
	last_landed = landed
	round_moves.append(action_id)
	if tracks_close:
		close = landed
	return changed
