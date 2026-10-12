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
## A dial's turns since it last opened or the room reset (jitan.c add("forward", 1)).
var _turns: Dictionary[String, int] = {}

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
## this push opened the passage. With `every_push` there is no count (d/village/road6.c
## do_pushaside()): every push opens the way, again while it stands open, and does not
## put the closing off (the first call_out closes it).
func push(pushes: int, open_ms: int, every_push: bool = false) -> bool:
	if every_push:
		if not _open:
			_open = true
			_remaining_ms = open_ms
		return true
	_left_trigger += 1
	if _left_trigger != pushes or _open:
		return false
	_open = true
	_left_trigger = 0
	_remaining_ms = open_ms
	return true


## jitan.c do_turn(): one more turn of `count`.
func turn(count: String) -> void:
	_turns[count] = _turns.get(count, 0) + 1


## The turns counted so far, by count.
func turns() -> Dictionary[String, int]:
	return _turns.duplicate()


## jitan.c do_press(): the turns are exactly `combination` and the way is shut: it opens for
## `open_ms`. The turns are cleared either way (delete("forward"); owner's M4, 默认: a press
## that opens nothing clears them too). True when it opened.
func press(combination: Dictionary[String, int], open_ms: int) -> bool:
	var right: bool = not _open
	for count: String in combination:
		right = right and _turns.get(count, 0) == combination[count]
	for count: String in _turns:
		right = right and combination.has(count)
	_turns.clear()
	if right:
		_open = true
		_remaining_ms = open_ms
	return right


## The way opened from below (owner, 京师 plan Q2 (a)): shut, it opens for `open_ms`.
## True when it opened.
func open_from_below(open_ms: int) -> bool:
	if _open:
		return false
	_open = true
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


## The room's reset(): delete("left_trigger") (jitan.c: delete("forward"), delete("backward")).
func reset() -> void:
	_left_trigger = 0
	_turns.clear()
