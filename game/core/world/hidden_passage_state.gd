class_name HiddenPassageState
extends RefCounted

## d/snow/weapon_storage.c, for one hidden_passage landmark. Every push adds
## one to `left_trigger`; when it equals the landmark's `pushes` while the
## passage is closed, the floor opens (exits/down here, exits/up below),
## `left_trigger` is deleted and call_out("close_passage", open_seconds) closes
## it again. Pushes while it stands open keep counting, so the count can pass
## `pushes` and never match again until the room resets (reset() deletes
## left_trigger). Native rule (DECISIONS 4C): the passage does not close on a
## player below; once the time is up it closes when nobody is down there.
## Not saved, as ES2 room state is not: Continue finds it closed.
var _left_trigger: int = 0
var _open: bool = false
var _remaining_ms: int = 0

var left_trigger: int:
	get:
		return _left_trigger
var is_open: bool:
	get:
		return _open
var remaining_ms: int:
	get:
		return _remaining_ms


## do_push() with any argument but "shelf", then check_trigger(). True when
## this push opened the passage.
func push(pushes: int, open_ms: int) -> bool:
	_left_trigger += 1
	if _left_trigger != pushes or _open:
		return false
	_open = true
	_left_trigger = 0
	_remaining_ms = open_ms
	return true


## World time passes. True when the passage closes now (close_passage()).
func advance(elapsed_ms: int, player_below: bool) -> bool:
	if not _open:
		return false
	_remaining_ms = maxi(0, _remaining_ms - maxi(0, elapsed_ms))
	if _remaining_ms > 0 or player_below:
		return false
	_open = false
	return true


## Continue with the player below: the way back stands open, its time up.
func open_for_player_below() -> void:
	_open = true
	_remaining_ms = 0


## The room's reset(): delete("left_trigger").
func reset() -> void:
	_left_trigger = 0
