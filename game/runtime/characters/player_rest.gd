class_name PlayerRest
extends RefCounted

## The player's rest under way (歇到回满; RestRules, DECISIONS「歇到回满」): the session runs the
## world `world_scale` times as fast while it lasts, by the same beats as ordinary play, and asks
## judge() each frame whether it is over. Transient: not saved (a Continue finds the player
## standing, as when they stood up).

var _active: bool = false
var _scale: float = 1.0
var _limit_seconds: float = 0.0
var _world_seconds: float = 0.0
var _currents: Vector3i = Vector3i.ZERO


func active() -> bool:
	return _active


## World seconds per real second while the rest lasts (1 when none does).
func world_scale() -> float:
	return _scale if _active else 1.0


## World seconds the rest has lasted.
func world_seconds() -> float:
	return _world_seconds


func begin(state: CharacterState, world_scale: int, limit_seconds: int) -> void:
	_active = true
	_scale = maxf(1.0, float(world_scale))
	_limit_seconds = float(limit_seconds)
	_world_seconds = 0.0
	_currents = RestRules.currents(state)


## `world_seconds` of world time went by resting: why the rest is over now, or NONE. Something
## coming at the player is the caller's to tell (ATTACKED, SCENE, MOVED, FELL).
func judge(state: CharacterState, world_seconds: float) -> RestRules.Outcome:
	if not _active:
		return RestRules.Outcome.NONE
	_world_seconds += maxf(world_seconds, 0.0)
	if RestRules.hurt_since(state, _currents):
		return RestRules.Outcome.HURT
	_currents = RestRules.currents(state)
	if RestRules.rested(state):
		return RestRules.Outcome.RESTED
	if not RestRules.can_recover(state):
		return RestRules.Outcome.THIRSTY
	if _world_seconds >= _limit_seconds:
		return RestRules.Outcome.LIMIT
	return RestRules.Outcome.NONE


## World time is held (a window open): what the player spends meanwhile (练习, 请教, 打工) is theirs,
## not a hurt; the next frame of the rest compares with the values now.
func rebase(state: CharacterState) -> void:
	if _active:
		_currents = RestRules.currents(state)


func end() -> void:
	_active = false
	_scale = 1.0
