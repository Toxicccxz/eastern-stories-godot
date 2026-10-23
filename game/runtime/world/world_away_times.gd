class_name WorldAwayTimes
extends RefCounted

## 别的地图时间补算 (DECISIONS): the world clock and how long each map has gone without
## the player. The clock runs while NPC world time does (WorldSessionController
## npc_world_time_allowed(): not in a fight, the menu, a transition); each map keeps the
## clock time it was last caught up to, which the player's departure sets and a catch-up
## moves on. A map never stamped has gone without the player since the session began.
## The save keeps what each map is owed (owed_by_map()), not the clock, which starts at 0
## in every session.

var _clock_ms: int = 0
var _carried_ms: float = 0.0
var _last_ms: Dictionary[StringName, int] = {}


func clock_ms() -> int:
	return _clock_ms


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	_carried_ms += delta * 1000.0
	var whole: int = int(_carried_ms)
	_carried_ms -= whole
	_clock_ms += whole


## Milliseconds of world time `map_id` has not been caught up for.
func owed_ms(map_id: StringName) -> int:
	return maxi(_clock_ms - _last_ms.get(map_id, 0), 0)


## The map is caught up to now: the player is there, left it just now, or it was caught up.
func stamp(map_id: StringName) -> void:
	_last_ms[map_id] = _clock_ms


## What each of `map_ids` is owed, leaving out those owed nothing (the save's away_ms).
func owed_by_map(map_ids: Array[StringName]) -> Dictionary[StringName, int]:
	var owed: Dictionary[StringName, int] = {}
	for map_id: StringName in map_ids:
		var ms: int = owed_ms(map_id)
		if ms > 0:
			owed[map_id] = ms
	return owed


## Continue: each map owed what the save says (the clock starts again at 0); a map the save
## leaves out is owed nothing.
func restore(owed: Dictionary[StringName, int]) -> void:
	_clock_ms = 0
	_carried_ms = 0.0
	_last_ms.clear()
	for map_id: StringName in owed:
		_last_ms[map_id] = -owed[map_id]
