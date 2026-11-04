class_name ApplicationUiScale
extends RefCounted

## 界面缩放: the whole interface drawn this many percent of its size (the world camera
## makes up for it, so the map, with the names and labels drawn on it, stays as large as
## at 100%).
const DEFAULT: int = 100
const PERCENTS: Array[int] = [100, 125, 150]


static func is_valid(percent: int) -> bool:
	return PERCENTS.has(percent)


static func factor(percent: int) -> float:
	return float(percent if is_valid(percent) else DEFAULT) / 100.0


## The pixel interface (DECISIONS「像素界面」) draws one grid pixel as 1.5 logical pixels; it is
## a whole number of screen pixels only when the whole scale (the window's stretch times this
## setting) is a multiple of 2/3. 2560×1440 at 100% is 2 already (3 screen pixels a grid
## pixel); 1920×1080 at 100% (1.5) is drawn at 4/3 (2 screen pixels).
const PIXEL_SCALE_STEP: float = 2.0 / 3.0


## The content scale for `percent` in a `window` (screen pixels) over the project's `base`
## size: the nearest whole-pixel scale to what the setting asks for, never under one step.
static func pixel_factor(percent: int, window: Vector2i, base: Vector2i) -> float:
	if window.x <= 0 or window.y <= 0 or base.x <= 0 or base.y <= 0:
		return factor(percent)
	var stretch: float = minf(float(window.x) / float(base.x), float(window.y) / float(base.y))
	var steps: int = maxi(1, roundi(stretch * factor(percent) / PIXEL_SCALE_STEP))
	return float(steps) * PIXEL_SCALE_STEP / stretch
