class_name DayClock
extends RefCounted

## The time of day (DECISIONS「昼夜」): where in natured.c's 1440-minute day the world is.
## It goes on with the world clock (WorldSessionController.npc_world_time_allowed(): not in a
## fight, the menu, a transition) at the pacing's day_length_minutes real minutes a day (ES2:
## 24, one game minute a real second), and is saved as `day_seconds`. It decides nothing: no
## NPC, door, spawn or fight reads it; the voxel view lights the map by it and the outdoor
## room's text gets the phase's line.
const DAY_MINUTES: int = 1440
const DAY_SECONDS: int = DAY_MINUTES * 60
## A new game starts in the morning (微曦 + 日出 gone by).
const NEW_GAME_SECONDS: int = 360 * 60

var _phases: Array[DayPhaseDefinition] = []
var _day_ms: int = NEW_GAME_SECONDS * 1000
var _carried_ms: float = 0.0


func _init(phases: Array[DayPhaseDefinition] = []) -> void:
	_phases = phases.duplicate()


## Seconds since 0:00 of the game day (0 ..< DAY_SECONDS).
func day_seconds() -> int:
	return _day_ms / 1000


## Game minutes since 0:00, fractional.
func day_minutes() -> float:
	return float(_day_ms) / 60_000.0


func set_day_seconds(seconds: int) -> void:
	_day_ms = posmod(seconds, DAY_SECONDS) * 1000
	_carried_ms = 0.0


static func is_valid_day_seconds(seconds: int) -> bool:
	return seconds >= 0 and seconds < DAY_SECONDS


func phases() -> Array[DayPhaseDefinition]:
	return _phases


## The phase `minutes` into the day falls in (-1 without phases).
func phase_index_at(minutes: float) -> int:
	var left: float = fposmod(minutes, float(DAY_MINUTES))
	for index: int in _phases.size():
		if left < float(_phases[index].minutes):
			return index
		left -= float(_phases[index].minutes)
	return _phases.size() - 1


func phase_index() -> int:
	return phase_index_at(day_minutes())


## The current phase, or null without phases.
func phase() -> DayPhaseDefinition:
	var index: int = phase_index()
	return null if index < 0 else _phases[index]


## Game seconds from now until the next start of a phase whose id is one of `phase_ids` (going
## round the day); 0 while the day is in one of them, -1 when none of them is a phase.
func seconds_until_phase(phase_ids: Array[StringName]) -> int:
	var now: int = phase_index()
	if now < 0 or _phases.is_empty():
		return -1
	if phase_ids.has(_phases[now].phase_id):
		return 0
	var start: int = 0
	for before: int in now:
		start += _phases[before].minutes * 60
	var ahead: int = start + _phases[now].minutes * 60 - day_seconds()
	for step: int in range(1, _phases.size()):
		var index: int = (now + step) % _phases.size()
		if phase_ids.has(_phases[index].phase_id):
			return ahead
		ahead += _phases[index].minutes * 60
	return -1


## How far through the current phase (0 ..< 1).
func phase_progress() -> float:
	var index: int = phase_index()
	if index < 0:
		return 0.0
	var start: float = 0.0
	for before: int in index:
		start += float(_phases[before].minutes)
	return clampf((day_minutes() - start) / float(_phases[index].minutes), 0.0, 1.0)


## Moves the day on by `delta` real seconds of a day of `day_length_minutes` real minutes.
## Returns the phase begun, if the step crossed into another one (the last crossed when it
## crossed several), else null.
func advance(delta: float, day_length_minutes: int) -> DayPhaseDefinition:
	if not is_finite(delta) or delta <= 0.0 or day_length_minutes <= 0:
		return null
	var before: int = phase_index()
	_carried_ms += delta * 1000.0 * float(DAY_MINUTES) / float(day_length_minutes)
	var whole: int = int(_carried_ms)
	_carried_ms -= whole
	_day_ms = posmod(_day_ms + whole, DAY_SECONDS * 1000)
	var after: int = phase_index()
	return _phases[after] if after != before and after >= 0 else null
