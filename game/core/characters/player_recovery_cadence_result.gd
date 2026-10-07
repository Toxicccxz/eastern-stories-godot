class_name PlayerRecoveryCadenceResult
extends RefCounted

enum Outcome { ADVANCED, FROZEN, INVALID_INPUT, INVALID_RANDOM }

var outcome: Outcome = Outcome.ADVANCED
var pulses: int = 0
var busy_pulses: int = 0
var opportunities: int = 0
var last_update_count: int = 0
## Conditions updated on this advance's ticks and the lines they told the character.
var conditions_updated: int = 0
var lines: Array[ColoredLine] = []
## What the character's room saw (ConditionUpdateResult.room_lines): templates naming it as {name}.
var room_lines: Array[String] = []
