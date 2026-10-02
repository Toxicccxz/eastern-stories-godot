class_name PacingDefinition
extends RefCounted

## Game-wide timing, one record in game/data/common/pacing.json. ES2 ran every
## living object on one driver heart_beat; the native combat round is that beat.
## Rooms reset on the driver's `time to reset` (adm/etc/config.ES2: 1800).
const ES2_ROOM_RESET_SECONDS: int = 1800

var _combat_round_ms: int
var _room_reset_seconds: int

## Seconds between two combat rounds of an encounter (the scheduler's opportunity interval).
var combat_round_seconds: float:
	get:
		return float(_combat_round_ms) / 1000.0
## MudOS TIME_TO_RESET: a room resets half to all of this many seconds after its last reset.
var room_reset_seconds: int:
	get:
		return _room_reset_seconds


func _init(p_combat_round_ms: int = 0, p_room_reset_seconds: int = ES2_ROOM_RESET_SECONDS) -> void:
	_combat_round_ms = p_combat_round_ms
	_room_reset_seconds = p_room_reset_seconds


static func from_record(reader: ContentRecordReader) -> PacingDefinition:
	var definition: PacingDefinition = PacingDefinition.new(
		reader.required_integer("combat_round_ms"),
		reader.integer("room_reset_seconds", ES2_ROOM_RESET_SECONDS),
	)
	reader.finish()
	if definition._combat_round_ms <= 0:
		reader.fail("combat_round_ms", "must be positive")
	if definition._room_reset_seconds < 2:
		reader.fail("room_reset_seconds", "must be at least 2")
	return definition
