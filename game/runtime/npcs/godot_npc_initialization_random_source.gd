class_name GodotNpcInitializationRandomSource
extends NpcInitializationRandomSource

var _generator: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_seed: int = 0, use_deterministic_seed: bool = false) -> void:
	if use_deterministic_seed:
		_generator.seed = p_seed
	else:
		_generator.randomize()


func configure_seed(value: int) -> void:
	_generator.seed = value


func next_below(exclusive_upper_bound: int) -> int:
	if exclusive_upper_bound <= 0:
		return -1
	return _generator.randi_range(0, exclusive_upper_bound - 1)
