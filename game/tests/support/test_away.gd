class_name TestAway
extends RefCounted

## Suites run with nobody moved while the player is away (run_suite.gd, DECISIONS「别的地图
## 时间补算」): pacing.json's away_wander_moves and away_neighbour_pulse_seconds at ES2's 0, so
## a map's people stand where its rooms put them for the suites that walk past them, count
## them or meet them. A suite about the wandering (and the world soak) turns them on with use()
## and restore() when it is done. The rest of the catch-up (healing, waking) stays on.

static var _moves: int = 0
static var _pulse: int = 0


## The suite runner, once: keeps pacing.json's knobs and turns them off.
static func turn_off() -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	_moves = pacing.away_wander_moves
	_pulse = pacing.away_neighbour_pulse_seconds
	_knobs(0, 0)


static func use() -> void:
	_knobs(_moves, _pulse)


static func restore() -> void:
	_knobs(0, 0)


static func _knobs(moves: int, pulse: int) -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	pacing.with_away_catch_up_limit(pacing.away_catch_up_limit_seconds, moves, pulse)
