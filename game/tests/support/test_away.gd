class_name TestAway
extends RefCounted

## Suites run with nothing changed by time nobody watches (run_suite.gd): pacing.json's
## away_wander_moves and away_neighbour_pulse_seconds at ES2's 0 (DECISIONS「别的地图时间补算」),
## so a map's people stand where its rooms put them for the suites that walk past them, count
## them or meet them; and corpses that do not decay (DECISIONS「尸体腐烂」), as the suites
## written before it loot, raise and dissolve them minutes on. A suite about these (and the
## world soak) turns them on with use() and restore() when it is done. The rest of the
## catch-up (healing, waking) stays on.

static var _moves: int = 0
static var _pulse: int = 0
static var _decay: Array[int] = [0, 0, 0]


## The suite runner, once: keeps pacing.json's knobs and turns them off.
static func turn_off() -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	_moves = pacing.away_wander_moves
	_pulse = pacing.away_neighbour_pulse_seconds
	_decay = [pacing.corpse_rot_seconds, pacing.corpse_bones_seconds, pacing.corpse_scatter_seconds]
	_knobs(0, 0, [0, 0, 0])


static func use() -> void:
	_knobs(_moves, _pulse, _decay)


static func restore() -> void:
	_knobs(0, 0, [0, 0, 0])


static func _knobs(moves: int, pulse: int, decay: Array[int]) -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	pacing.with_away_catch_up_limit(pacing.away_catch_up_limit_seconds, moves, pulse)
	pacing.with_corpse_decay(decay[0], decay[1], decay[2])
