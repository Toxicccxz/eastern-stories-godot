class_name PlayerLifeFlow
extends RefCounted

## Time-driven part of the player's unconsciousness and death. The session
## feeds it frame time and acts on the events it returns; the rules themselves
## live in UnconsciousReviveDelay and PlayerDeathRules. A death shows its card (what
## it cost, where the corpse lies) until the player goes on; then the ghost is taken to
## 阴间 (damage.c die()'s move(DEATH_ROOM)), where the way back is the gargoyles' and the
## little shop's (d/death).
enum Phase { NONE, UNCONSCIOUS, DEATH_SEQUENCE }
enum Event { NONE, REVIVE_DUE, ENTER_REALM_DUE }

var _phase: Phase = Phase.NONE
var _revive_remaining: float = 0.0
var _revive_total: float = 0.0
var _world_scale: float = 1.0
var _continued: bool = false
var _death_result: PlayerDeathResult
var _corpse_place: String = ""
var _corpse_item_instance_id: StringName = &""

var phase: Phase:
	get: return _phase
var revive_remaining_seconds: float:
	get: return _revive_remaining
var death_result: PlayerDeathResult:
	get: return _death_result
var corpse_place: String:
	get: return _corpse_place
## The corpse the death left (empty when unknown), so the screen can tell whether it
## still lies there (化尸粉 destroys it with all it holds).
var corpse_item_instance_id: StringName:
	get: return _corpse_item_instance_id


func is_active() -> bool:
	return _phase != Phase.NONE


## `delay_seconds` is damage.c's call_out("revive"), in world seconds. With
## `wake_seconds` > 0 (pacing knob player_wake_seconds) the player lies that long in
## real time while world time runs the whole delay (owner, A9).
func begin_unconscious(delay_seconds: int, wake_seconds: float = 0.0) -> void:
	_phase = Phase.UNCONSCIOUS
	_revive_remaining = float(delay_seconds)
	_revive_total = float(delay_seconds)
	_world_scale = maxf(1.0, float(delay_seconds) / wake_seconds) if wake_seconds > 0.0 else 1.0


## World seconds per real second now: above 1 only while the player lies unconscious
## with a quick wake.
func world_time_scale() -> float:
	return _world_scale if _phase == Phase.UNCONSCIOUS else 1.0


## The player lies in the dark for a few seconds, not the delay itself.
func wakes_quickly() -> bool:
	return _phase == Phase.UNCONSCIOUS and _world_scale > 1.0


## How much of the revive delay has passed, 0 to 1.
func revive_progress() -> float:
	return 1.0 if _revive_total <= 0.0 else clampf(1.0 - _revive_remaining / _revive_total, 0.0, 1.0)


## A death replaces a pending revive, as die() calls revive(1) first.
func begin_death(result: PlayerDeathResult, corpse_place: String, corpse_item_instance_id: StringName = &"") -> void:
	_phase = Phase.DEATH_SEQUENCE
	_death_result = result
	_corpse_place = corpse_place
	_corpse_item_instance_id = corpse_item_instance_id
	_continued = false


## The player read the death card and goes on (继续): the ghost goes to 阴间.
func continue_from_death() -> void:
	if _phase == Phase.DEATH_SEQUENCE:
		_continued = true


## Whether the player has gone on from the death card (the move to 阴间 is due).
func continued() -> bool:
	return _phase == Phase.DEATH_SEQUENCE and _continued


## Returns at most one event per call so the session handles each in order. The move to
## 阴间 is due every frame from 继续 on, until the session has made it (finish()).
func advance(delta: float) -> Event:
	match _phase:
		Phase.UNCONSCIOUS:
			_revive_remaining = maxf(0.0, _revive_remaining - delta)
			return Event.REVIVE_DUE if _revive_remaining <= 0.0 else Event.NONE
		Phase.DEATH_SEQUENCE:
			return Event.ENTER_REALM_DUE if _continued else Event.NONE
	return Event.NONE


func finish() -> void:
	_phase = Phase.NONE
	_revive_remaining = 0.0
	_revive_total = 0.0
	_world_scale = 1.0
	_continued = false
