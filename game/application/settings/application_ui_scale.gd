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


## The logical area a phone's interface keeps (the MOBILE contract's qualified safe landscape).
const MOBILE_LEAST := Vector2(800, 480)


## The content scale for `percent` in a `window` (screen pixels) over the project's `base`
## size: the nearest whole-pixel scale to what the setting asks for, never under one step and
## never over the largest setting's (the interface is laid out down to 150 % of the base
## size). Whole steps are coarse on a small screen: at 1280×720 and on a Steam Deck the three
## settings all draw at 4/3; at 1920×1080 125 % and 150 % both draw at 2.
## On a phone or tablet (`mobile`) it is as large as the layouts allow, whatever the setting:
## the largest whole step that still leaves MOBILE_LEAST logical units (owner, 2026-11-21:
## 界面太小、字也太小 — a 2400×1080 phone drew the 100 % interface at 4/3, 16-pixel text on a
## 6.5-inch screen; now at 2). A phone held in the hand shows the 1280×720 base far smaller
## than any monitor, so the settings all come out alike there (levels_differ()).
static func pixel_factor(percent: int, window: Vector2i, base: Vector2i, mobile: bool = false) -> float:
	if window.x <= 0 or window.y <= 0 or base.x <= 0 or base.y <= 0:
		return factor(percent)
	var stretch: float = minf(float(window.x) / float(base.x), float(window.y) / float(base.y))
	if mobile:
		var fit: int = floori(minf(float(window.x) / MOBILE_LEAST.x, float(window.y) / MOBILE_LEAST.y) / PIXEL_SCALE_STEP + 0.001)
		return float(maxi(1, fit)) * PIXEL_SCALE_STEP / stretch
	var most: int = maxi(1, floori(stretch * factor(PERCENTS[PERCENTS.size() - 1]) / PIXEL_SCALE_STEP + 0.001))
	var steps: int = clampi(roundi(stretch * factor(percent) / PIXEL_SCALE_STEP), 1, most)
	return float(steps) * PIXEL_SCALE_STEP / stretch


## The title's menu column keeps about the share of the screen it has at 1920×1080 (owner,
## 2026-11-23: at 1280×720 the interface's whole step of 4/3 drew it half again as large against
## the screen, crowding the title): its own whole step nearest TITLE_MENU_SHARE of the window's
## stretch (times the setting), never larger than the interface's `current` content scale. The
## scale to draw the column at inside the interface (1 where they agree).
const TITLE_MENU_SHARE: float = 8.0 / 9.0


static func title_menu_scale(percent: int, window: Vector2i, base: Vector2i, current: float) -> float:
	if window.x <= 0 or window.y <= 0 or base.x <= 0 or base.y <= 0 or current <= 0.0:
		return 1.0
	var stretch: float = minf(float(window.x) / float(base.x), float(window.y) / float(base.y))
	var steps: int = maxi(1, roundi(stretch * TITLE_MENU_SHARE * factor(percent) / PIXEL_SCALE_STEP))
	return minf(1.0, float(steps) * PIXEL_SCALE_STEP / (stretch * current))


## Whether the three settings draw differently in `window`: on a small one they all come out
## at the same whole step, and the 设置 page says so.
static func levels_differ(window: Vector2i, base: Vector2i, mobile: bool = false) -> bool:
	return not is_equal_approx(pixel_factor(PERCENTS[0], window, base, mobile), pixel_factor(PERCENTS[PERCENTS.size() - 1], window, base, mobile))
