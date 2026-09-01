class_name GodotWorldInteractionRandomSource
extends WorldInteractionRandomSource

var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = 0, deterministic: bool = false) -> void:
	if deterministic:
		_random.seed = seed_value
	else:
		_random.randomize()


func configure_seed(value: int) -> void:
	_random.seed = value


func capture_random_state() -> RandomStreamSnapshot:
	return RandomStreamSnapshot.new(
		RandomStreamSnapshot.GODOT_PCG32_ADAPTER_ID,
		_random.seed,
		_random.state,
	)


func restore_random_state(snapshot: RandomStreamSnapshot) -> bool:
	if snapshot == null or not snapshot.is_supported():
		return false
	_random.seed = snapshot.seed
	_random.state = snapshot.state
	return true


func next_below(exclusive_upper_bound: int) -> int:
	if exclusive_upper_bound <= 0:
		return -1
	return _random.randi_range(0, exclusive_upper_bound - 1)
