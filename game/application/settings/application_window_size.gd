class_name ApplicationWindowSize
extends RefCounted

## A desktop window opens at the largest of these within 85% of the screen; on a screen
## too small for any, at the largest 16:9 size that is.
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720)]
const SCREEN_SHARE: float = 0.85


static func initial(screen: Vector2i) -> Vector2i:
	var room: Vector2 = Vector2(screen) * SCREEN_SHARE
	for size: Vector2i in SIZES:
		if size.x <= room.x and size.y <= room.y:
			return size
	var width: int = floori(minf(room.x, room.y * 16.0 / 9.0))
	return Vector2i(maxi(width, 1), maxi(floori(width * 9.0 / 16.0), 1))
