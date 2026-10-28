class_name SkyState
extends RefCounted

## How much cloud there is (DECISIONS「天气」): which of natured.c's five `weather_msg` lines
## the sky is at. ES2 declares the five and never uses them; here the sky turns through them,
## one step at a time, every 2–4 game hours. It goes on with the world clock as the DayClock
## does (the pacing's day_length_minutes real minutes a day; stopped in a fight, the menu, a
## transition) and is saved as `sky_level` and `sky_minutes_left`. It decides nothing: no
## NPC, door, spawn or fight reads it; the voxel view dims and greys the light by it and the
## outdoor room's text gets its line. With the pacing's `sky_weather` off (经典) the session
## never advances it and reports level 0.
const LEVELS: int = 5
## Game minutes between two changes: MIN_MINUTES + random(MAX_MINUTES - MIN_MINUTES + 1).
const MIN_MINUTES: int = 120
const MAX_MINUTES: int = 240
## A new game: a few light clouds, the first change midway through the range.
const NEW_GAME_LEVEL: int = 1
const NEW_GAME_MINUTES: int = 180

var _level: int = NEW_GAME_LEVEL
var _left_ms: int = NEW_GAME_MINUTES * 60_000
var _carried_ms: float = 0.0


## 0 (万里无云) .. 4 (乌云密布).
func level() -> int:
	return _level


## Whole game minutes until the next change (0 ..= MAX_MINUTES).
func minutes_left() -> int:
	return _left_ms / 60_000


func set_state(level: int, minutes_left: int) -> void:
	_level = clampi(level, 0, LEVELS - 1)
	_left_ms = clampi(minutes_left, 0, MAX_MINUTES) * 60_000
	_carried_ms = 0.0


static func is_valid_level(level: int) -> bool:
	return level >= 0 and level < LEVELS


static func is_valid_minutes_left(minutes: int) -> bool:
	return minutes >= 0 and minutes <= MAX_MINUTES


## Moves the sky on by `delta` real seconds of a day of `day_length_minutes` real minutes,
## drawing each change's direction and the wait to the next from `random`. Returns true when
## the level changed.
func advance(delta: float, day_length_minutes: int, random: WorldInteractionRandomSource) -> bool:
	if not is_finite(delta) or delta <= 0.0 or day_length_minutes <= 0 or random == null:
		return false
	_carried_ms += delta * 1000.0 * float(DayClock.DAY_MINUTES) / float(day_length_minutes)
	var whole: int = int(_carried_ms)
	_carried_ms -= whole
	_left_ms -= whole
	var changed: bool = false
	while _left_ms <= 0:
		_level += _direction(random)
		changed = true
		_left_ms += (MIN_MINUTES + random.legacy_random(MAX_MINUTES - MIN_MINUTES + 1)) * 60_000
	return changed


## One step: up from clear, down from overcast, either way between.
func _direction(random: WorldInteractionRandomSource) -> int:
	if _level <= 0:
		return 1
	if _level >= LEVELS - 1:
		return -1
	return -1 if random.legacy_random(2) == 0 else 1
