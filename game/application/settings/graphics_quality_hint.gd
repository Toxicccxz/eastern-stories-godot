class_name GraphicsQualityHint
extends RefCounted

## DECISIONS「画质」: whether the game has been slow long enough to say once that 画质 can go
## lower. Fed the real time each frame took (not the game's): after the map has been up for
## `settle_seconds` (the first frames of a map are its building), each whole second is slow when
## its frames came at fewer than `below_fps`; `seconds` slow seconds in a row and it is time.
var below_fps: float = 30.0
var seconds: int = 5
var settle_seconds: float = 10.0
var _up: float = 0.0
var _window: float = 0.0
var _frames: int = 0
var _slow_run: int = 0


func _init(config: Dictionary = {}) -> void:
	var values: Dictionary = GraphicsQuality.slow_hint() if config.is_empty() else config
	below_fps = float(values.get("below_fps", below_fps))
	seconds = int(values.get("seconds", seconds))
	settle_seconds = float(values.get("settle_seconds", settle_seconds))


## One frame that took `real_seconds`; true once the slow seconds in a row are enough.
func advance(real_seconds: float) -> bool:
	_up += real_seconds
	if _up < settle_seconds:
		return false
	_window += real_seconds
	_frames += 1
	if _window < 1.0:
		return false
	_slow_run = _slow_run + 1 if float(_frames) / _window < below_fps else 0
	_window = 0.0
	_frames = 0
	return _slow_run >= seconds
