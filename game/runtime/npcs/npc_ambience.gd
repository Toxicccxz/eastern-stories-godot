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
## do_recruit; shaowei.c make_stage. sword_soul.c chant_sword is kept on the NPC (saved).
const STEAL: StringName = &"steal"
const RECRUIT: StringName = &"recruit"
const MAKE: StringName = &"make"
## champion.c's test blows, pacing.json trial_blow_ms apart (DECISIONS「响应性」).
const TRIAL: StringName = &"trial"
## An NPC's own init() call_outs (NpcHooks calls): call/<index>.
const CALL_PREFIX: String = "call/"

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
	var pulse: float = GameContent.catalog().pacing().heart_beat_seconds
	var beats: int = int(_remainder / pulse)
	_remainder -= beats * pulse
	return beats


## npc.c chat() on one beat: null, a line to say, or NpcTalk.RANDOM_MOVE. `chance` is the
## NPC's own chat_chance when create() drew it (walker.c), -1 for the definition's.
func chat(talk: NpcTalk, chance: int = -1) -> Variant:
	var shown: int = talk.chat_chance if talk != null and chance < 0 else chance
	if talk == null or not talk.has_chat() or shown <= 0:
		return null
	var roll: int = _random.legacy_random(100)
	if roll < 0 or roll >= shown:
		return null
	var entries: Array = talk.chat_entries()
	var index: int = _random.legacy_random(entries.size())
	return entries[index] if index >= 0 and index < entries.size() else null


## A greeting answers the player's arrival: within pacing.json's reaction beat.
func start_greeting(character_id: StringName) -> void:
	_greetings[character_id] = GameContent.catalog().pacing().reaction_seconds(GREETING_DELAY_SECONDS)


func cancel_greeting(character_id: StringName) -> void:
	_greetings.erase(character_id)


func start_call(character_id: StringName, seconds: float, kind: StringName) -> void:
	if not _calls.has(kind):
		_calls[kind] = {}
	_calls[kind][character_id] = seconds


## A call_out that answers what the player just did (a master's 拜师 answer, a sentence, a
## zombie's end): ES2's `es2_seconds`, or pacing.json's reaction beat when that is sooner
## (DECISIONS「响应性」).
func start_reaction(character_id: StringName, es2_seconds: float, kind: StringName) -> void:
	start_call(character_id, GameContent.catalog().pacing().reaction_seconds(es2_seconds), kind)


## Seconds until the NPC's call_out of `kind` (-1: none).
func call_left(character_id: StringName, kind: StringName) -> float:
	return float(_calls[kind][character_id]) if has_call(character_id, kind) else -1.0


## 继续 (DECISIONS「响应性」): the NPC's next call_out of `kind` comes now.
func hurry_call(character_id: StringName, kind: StringName) -> void:
	if has_call(character_id, kind):
		_calls[kind][character_id] = 0.0


## 继续 for the NPC's own calls `indices` (a told sequence): the soonest comes now and the
## rest keep their spacing.
func hurry_own_calls(character_id: StringName, indices: Array[int]) -> void:
	var soonest: float = INF
	for index: int in indices:
		var left: float = call_left(character_id, own_call(index))
		if left >= 0.0:
			soonest = minf(soonest, left)
	if soonest == INF or soonest <= 0.0:
		return
	for index: int in indices:
		var kind: StringName = own_call(index)
		if has_call(character_id, kind):
			_calls[kind][character_id] = float(_calls[kind][character_id]) - soonest


## The kind of an NPC's own call_out (NpcHooks calls[index]).
static func own_call(index: int) -> StringName:
	return StringName(CALL_PREFIX + str(index))


## The NPCs' own call_outs whose time runs out in `delta` seconds, in start order within
## each: [character_id, index] pairs.
func due_own_calls(delta: float) -> Array[Array]:
	var due: Array[Array] = []
	for kind: StringName in _calls.keys():
		if String(kind).begins_with(CALL_PREFIX):
			for character_id: StringName in due_calls(delta, kind):
				due.append([character_id, String(kind).trim_prefix(CALL_PREFIX).to_int()])
	return due


## Every call_out of the NPC (it is gone).
func cancel_call(character_id: StringName) -> void:
	for kind: StringName in _calls:
		_calls[kind].erase(character_id)


## Whether one of the NPC's own call_outs (NpcHooks calls) is still to come.
func has_own_calls(character_id: StringName) -> bool:
	for kind: StringName in _calls:
		if String(kind).begins_with(CALL_PREFIX) and _calls[kind].has(character_id):
			return true
	return false


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
