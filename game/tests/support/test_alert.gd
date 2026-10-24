class_name TestAlert
extends RefCounted

## Suites run with the gang's alert beat at ES2's 0 (run_suite.gd, DECISIONS「进门一起上」):
## those written before it expect a fight the tick the player comes into reach. A suite about
## the beat turns pacing.json's on with use() and restore() when it is done.

static var _production_ms: int = 0


## The suite runner, once: keeps pacing.json's beat and turns it off.
static func turn_off() -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	_production_ms = roundi(pacing.hostile_alert_seconds * 1000.0)
	pacing.with_hostile_alert(0)


static func use() -> void:
	GameContent.catalog().pacing().with_hostile_alert(_production_ms)


static func restore() -> void:
	GameContent.catalog().pacing().with_hostile_alert(0)


## The beat pacing.json sets (milliseconds).
static func production_ms() -> int:
	return _production_ms
