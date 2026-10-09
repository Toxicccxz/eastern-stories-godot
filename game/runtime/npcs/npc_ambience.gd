class_name NpcAmbience
extends RefCounted

## The rest of std/char.c heart_beat() for the NPCs of the active map: npc.c chat()
## on every beat (the S5B base pulse) while the player is in the NPC's place, since
## char.c turns a healed NPC's heart beat off when no player is there, and the
## greeting call_out an NPC's init() starts when the player arrives
## (keeper.c: remove_call_out("greeting"); call_out("greeting", 1, ob)).
## Beats and greeting countdowns are not saved, as heal cadences are not.

const GREETING_DELAY_SECONDS: float = 1.0
## The kinds of other call_outs: thief.c steal_it and steal.c compelete_steal; taolord.c
## do_recruit; shaowei.c make_stage.
const STEAL: StringName = &"steal"
const RECRUIT: StringName = &"recruit"
const MAKE: StringName = &"make"

var _random: WorldInteractionRandomSource
var _remainder: float = 0.0
var _greetings: Dictionary[StringName, float] = {}
## Other call_outs an NPC starts, by kind, then by NPC: seconds left.
var _calls: Dictionary[StringName, Dictionary] = {}


func _init(random: WorldInteractionRandomSource) -> void:
	_random = random


func random() -> WorldInteractionRandomSource:
	return _random


## The session's current source (tests may replace it at any time).
func set_random(value: WorldInteractionRandomSource) -> void:
	if value != null:
		_random = value


## Beats that came due in `delta` seconds of world time.
func due_beats(delta: float) -> int:
	if _random == null or not is_finite(delta) or delta < 0.0:
		return 0
	_remainder += delta
	var beats: int = int(_remainder / PlayerRecoveryCadence.BASE_PULSE_SECONDS)
	_remainder -= beats * PlayerRecoveryCadence.BASE_PULSE_SECONDS
	return beats


## npc.c chat() on one beat: null, a line to say, or NpcTalk.RANDOM_MOVE.
func chat(talk: NpcTalk) -> Variant:
	if talk == null or not talk.has_chat():
		return null
	var roll: int = _random.legacy_random(100)
	if roll < 0 or roll >= talk.chat_chance:
		return null
	var entries: Array = talk.chat_entries()
	var index: int = _random.legacy_random(entries.size())
	return entries[index] if index >= 0 and index < entries.size() else null


func start_greeting(character_id: StringName) -> void:
	_greetings[character_id] = GREETING_DELAY_SECONDS


func cancel_greeting(character_id: StringName) -> void:
	_greetings.erase(character_id)


func start_call(character_id: StringName, seconds: float, kind: StringName) -> void:
	if not _calls.has(kind):
		_calls[kind] = {}
	_calls[kind][character_id] = seconds


## Every call_out of the NPC (it is gone).
func cancel_call(character_id: StringName) -> void:
	for kind: StringName in _calls:
		_calls[kind].erase(character_id)


func has_call(character_id: StringName, kind: StringName) -> bool:
	return _calls.has(kind) and _calls[kind].has(character_id)


## Every NPC call_out: the player left the map, and each would find nobody (its time
## does not flow while the map is not active).
func clear_calls() -> void:
	_calls.clear()


## The NPCs whose call_out of `kind` runs in these `delta` seconds, in start order.
func due_calls(delta: float, kind: StringName) -> Array[StringName]:
	var due: Array[StringName] = []
	if not is_finite(delta) or delta < 0.0 or not _calls.has(kind):
		return due
	var calls: Dictionary = _calls[kind]
	for character_id: StringName in calls.keys():
		calls[character_id] -= delta
		if calls[character_id] <= 0.0:
			calls.erase(character_id)
			due.append(character_id)
	return due


## The NPCs whose greeting call_out runs in these `delta` seconds, in start order.
func due_greetings(delta: float) -> Array[StringName]:
	var due: Array[StringName] = []
	if not is_finite(delta) or delta < 0.0:
		return due
	for character_id: StringName in _greetings.keys():
		_greetings[character_id] -= delta
		if _greetings[character_id] <= 0.0:
			_greetings.erase(character_id)
			due.append(character_id)
	return due
