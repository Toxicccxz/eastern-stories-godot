class_name ApplicationWindowSize
extends RefCounted

## A desktop window opens at the largest of these within 85% of the screen; on a screen
## too small for any, at the largest 16:9 size that is.
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720)]
const SCREEN_SHARE: float = 0.85
## 分辨率's choices, smallest first; AUTO is the size above, or the whole monitor.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
]
const AUTO: Vector2i = Vector2i.ZERO
const INVALID: Vector2i = Vector2i(-1, -1)


static func initial(screen: Vector2i) -> Vector2i:
	var room: Vector2 = Vector2(screen) * SCREEN_SHARE
	for size: Vector2i in SIZES:
		if size.x <= room.x and size.y <= room.y:
			return size
	var width: int = floori(minf(room.x, room.y * 16.0 / 9.0))
	return Vector2i(maxi(width, 1), maxi(floori(width * 9.0 / 16.0), 1))


static func is_valid(resolution: Vector2i) -> bool:
	return resolution == AUTO or RESOLUTIONS.has(resolution)


static func storage_value(resolution: Vector2i) -> String:
	return "" if resolution == AUTO else "%dx%d" % [resolution.x, resolution.y]


static func from_storage(value: String) -> Vector2i:
	if value.is_empty():
		return AUTO
	for resolution: Vector2i in RESOLUTIONS:
		if storage_value(resolution) == value:
			return resolution
	return INVALID


## What fits in `room`, smallest first.
static func choices(room: Vector2i) -> Array[Vector2i]:
	var fitting: Array[Vector2i] = []
	for resolution: Vector2i in RESOLUTIONS:
		if resolution.x <= room.x and resolution.y <= room.y:
			fitting.append(resolution)
	return fitting


## The choice closest below `resolution` that fits in `room` (a smaller monitor than the one
## it was chosen on), AUTO when none does.
static func fitted(resolution: Vector2i, room: Vector2i) -> Vector2i:
	var best: Vector2i = AUTO
	if resolution == AUTO:
		return best
	for choice: Vector2i in choices(room):
		if choice.x <= resolution.x and choice.y <= resolution.y:
			best = choice
	return best


## How much of `screen` the map is drawn at when the window covers it.
static func picture_scale(resolution: Vector2i, screen: Vector2i) -> float:
	if resolution == AUTO or screen.x <= 0 or screen.y <= 0:
		return 1.0
	return minf(1.0, minf(float(resolution.x) / screen.x, float(resolution.y) / screen.y))
