class_name GodotWorldInteractionRandomSource
extends WorldInteractionRandomSource

var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = 0, deterministic: bool = false) -> void:
	if deterministic:
		_random.seed = seed_value
	else:
		_random.randomize()


func next_below(exclusive_upper_bound: int) -> int:
	if exclusive_upper_bound <= 0:
		return -1
	return _random.randi_range(0, exclusive_upper_bound - 1)
