class_name GodotRecoveryCadenceRandomSource
extends RecoveryCadenceRandomSource

var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_random.randomize()


func draw_reset_tick() -> int:
	return 5 + _random.randi_range(0, 9)
