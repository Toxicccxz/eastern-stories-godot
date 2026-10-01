class_name PacingDefinition
extends RefCounted

## Game-wide timing, one record in game/data/common/pacing.json. ES2 ran every
## living object on one driver heart_beat; the native combat round is that beat.
var _combat_round_ms: int

## Seconds between two combat rounds of an encounter (the scheduler's opportunity interval).
var combat_round_seconds: float:
	get:
		return float(_combat_round_ms) / 1000.0


func _init(p_combat_round_ms: int = 0) -> void:
	_combat_round_ms = p_combat_round_ms


static func from_record(reader: ContentRecordReader) -> PacingDefinition:
	var definition: PacingDefinition = PacingDefinition.new(reader.required_integer("combat_round_ms"))
	reader.finish()
	if definition._combat_round_ms <= 0:
		reader.fail("combat_round_ms", "must be positive")
	return definition
