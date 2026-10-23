class_name GodotRecoveryCadenceRandomSource
extends RecoveryCadenceRandomSource

var _random: RandomNumberGenerator = RandomNumberGenerator.new()


## `deterministic`: seeded with `seed_value` (a map's catch-up, DECISIONS「别的地图时间补算」).
func _init(seed_value: int = 0, deterministic: bool = false) -> void:
	if deterministic:
		_random.seed = seed_value
	else:
		_random.randomize()


func draw_reset_tick() -> int:
	return 5 + _random.randi_range(0, 9)
