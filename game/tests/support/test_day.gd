class_name TestDay
extends RefCounted

## Suites run with the day standing still (run_suite.gd): pacing.json's day_length_minutes
## put so long that no real second of a suite moves the DayClock's day_seconds (DECISIONS
## 「昼夜」), as the suites written before it save, Continue and compare whole saves after a
## few frames. A suite about the day (day_night_test) turns it on with use() and restore()
## when it is done, as TestAway does.

## 1440 game minutes over a million real minutes: a real second is a game millisecond.
const STILL_MINUTES: int = 1_000_000

static var _length: int = PacingDefinition.ES2_DAY_LENGTH_MINUTES


## The suite runner, once: keeps pacing.json's day length and stops the day.
static func turn_off() -> void:
	_length = GameContent.catalog().pacing().day_length_minutes
	GameContent.catalog().pacing().with_day_length(STILL_MINUTES)


static func use() -> void:
	GameContent.catalog().pacing().with_day_length(_length)


static func restore() -> void:
	GameContent.catalog().pacing().with_day_length(STILL_MINUTES)
