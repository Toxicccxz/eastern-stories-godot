class_name PlayerRecoveryCadenceResult
extends RefCounted

enum Outcome { ADVANCED, FROZEN, INVALID_INPUT, INVALID_RANDOM }

var outcome: Outcome = Outcome.ADVANCED
var pulses: int = 0
var busy_pulses: int = 0
var opportunities: int = 0
var last_update_count: int = 0
