class_name NpcIdleTuning
extends RefCounted

## Native (NPC 活起来; DECISIONS「街上的人会动」): how the people of a map move about inside their
## own room while nothing else moves them — the `npc_idle` record inside
## game/data/common/pacing.json. Who moves how is each person's entry in
## game/data/<region>/npc_life.json (NpcLifeBook). Only the body's place inside its zone
## changes: which room it is in, and when it changes room, stay ES2's (random_move). Left
## out (or `enabled` false, 经典模式): everyone stands where they were put, as before.
## - pause_min_ms / pause_max_ms: how long one stands before its next stroll or look.
## - stroll_min_px / stroll_max_px: how far one stroll goes (straight-line, from where it is).
## - home_radius_px: a stroll ends no farther than this from the person's own spot (its
##   spawn marker), so a crowd does not drift to one end of a street; an entry may set less.
## - speed_px: the walking speed of a stroll (pixels a second; a room move walks faster).
## - stop_reach_px: a person the player comes this near stops and turns to them.

var enabled: bool = false
var pause_min_ms: int = 0
var pause_max_ms: int = 0
var stroll_min_px: int = 0
var stroll_max_px: int = 0
var home_radius_px: int = 0
var speed_px: int = 0
var stop_reach_px: int = 0

const KEYS: Array[String] = [
	"pause_min_ms", "pause_max_ms", "stroll_min_px", "stroll_max_px", "home_radius_px",
	"speed_px", "stop_reach_px",
]


## A pause drawn from `random` (0..1), in seconds.
func pause_seconds(random: float) -> float:
	return lerpf(float(pause_min_ms), float(maxi(pause_max_ms, pause_min_ms)), clampf(random, 0.0, 1.0)) / 1000.0


static func from_record(reader: ContentRecordReader) -> NpcIdleTuning:
	var tuning: NpcIdleTuning = NpcIdleTuning.new()
	tuning.enabled = reader.boolean("enabled", false)
	for key: String in KEYS:
		tuning.set(key, reader.integer(key, 0))
	reader.finish()
	for key: String in KEYS:
		if int(tuning.get(key)) < 0:
			reader.fail(key, "must not be negative")
	if tuning.pause_max_ms < tuning.pause_min_ms:
		reader.fail("pause_max_ms", "must not be below pause_min_ms")
	if tuning.stroll_max_px < tuning.stroll_min_px:
		reader.fail("stroll_max_px", "must not be below stroll_min_px")
	if tuning.enabled and (tuning.speed_px <= 0 or tuning.pause_max_ms <= 0):
		reader.fail("speed_px", "speed_px and pause_max_ms must be positive when enabled")
	return tuning
