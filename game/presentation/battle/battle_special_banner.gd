class_name BattleSpecialBanner
extends Control

## 战斗绝招 (DECISIONS「战斗绝招」): a special's name written over the fight as it opens — a broad
## vermilion brush stroke swept across (a heavy head, hair streaks, the tail breaking into dry
## brush), the name over it in the brush hand. The stroke is laid first, the name pressed on
## it, both held, then gone. One at a time: a new one takes the old one's place.
## The stroke is drawn in blocks the size of the interface's own pixels (rows of streaks), the
## same every time for the same name (seeded by it). Presentation only.

## The stroke's rows, top to bottom, as a share of its height.
const ROWS: int = 11
## How the banner's time is spent: the stroke swept, the name pressed, the fade at the end.
const SWEEP_SHARE: float = 0.22
const PRESS_SHARE: float = 0.12
const FADE_SHARE: float = 0.2
const OUTLINE: Color = Color(0.05, 0.03, 0.02, 0.92)

var _font: Font
var _text: String = ""
var _stroke: Color = Color("b3261e")
var _ink: Color = Color("f6ead2")
var _font_size: int = 60
var _box: Rect2 = Rect2()
## Each row's streaks: [start, end] as shares of the width (a row may break into several).
var _streaks: Array[Array] = []
var _from_left: bool = true
## The banner's time: 0 just begun .. 1 over.
var progress: float = 1.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = load(GameTheme.BRUSH_FONT_PATH) as Font


## `text` written at `middle` (this control's space) over `seconds`: the stroke `size` wide and
## high in `stroke`, swept from the left or the right, the name in `ink` at `font_size`. False
## (nothing shown) with no name or no time.
func present(text: String, middle: Vector2, size: Vector2, seconds: float, from_left: bool, stroke: Color, ink: Color, font_size: int) -> bool:
	clear()
	if text.is_empty() or seconds <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return false
	_text = text
	_stroke = stroke
	_ink = ink
	_font_size = font_size
	_from_left = from_left
	# Wide enough for the name with a head and a tail to spare, inside the screen.
	var wide: float = maxf(size.x, _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x + size.y * 1.6)
	_box = Rect2(middle - Vector2(wide, size.y) / 2.0, Vector2(wide, size.y))
	var room: Rect2 = Rect2(Vector2.ZERO, get_size()).grow(-8.0)
	if room.size.x > _box.size.x and room.size.y > _box.size.y:
		_box.position = _box.position.clamp(room.position, room.end - _box.size)
	_lay(hash(text))
	progress = 0.0
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, "progress", 1.0, seconds)
	_tween.tween_callback(clear)
	queue_redraw()
	return true


## Nothing shown.
func clear() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_text = ""
	progress = 1.0
	queue_redraw()


## Whether a name is written now (tests), and which.
func showing() -> bool:
	return not _text.is_empty() and progress < 1.0


func shown_text() -> String:
	return _text if showing() else ""


## Where the banner stands (tests).
func box() -> Rect2:
	return _box


## How far the stroke is swept (0..1), the name pressed (0..1) and all of it still there (1..0).
func sweep() -> float:
	return clampf(progress / SWEEP_SHARE, 0.0, 1.0)


func press() -> float:
	return clampf((progress - SWEEP_SHARE) / PRESS_SHARE, 0.0, 1.0)


func fade() -> float:
	return clampf((1.0 - progress) / FADE_SHARE, 0.0, 1.0)


func _process(_delta: float) -> void:
	if showing():
		queue_redraw()


## The stroke's rows: the middle ones full and longest, the outer ones shorter and starting
## later; toward the tail a row breaks into dry streaks.
func _lay(seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_streaks.clear()
	for row: int in ROWS:
		var off: float = absf(float(row) - float(ROWS - 1) / 2.0) / (float(ROWS - 1) / 2.0)
		var start: float = 0.05 * off * off + rng.randf_range(0.0, 0.03)
		var end: float = 1.0 - 0.3 * off * off - rng.randf_range(0.0, 0.08)
		var parts: Array = []
		# The body, then the tail in pieces with gaps between (飞白).
		var body: float = lerpf(start, end, rng.randf_range(0.62, 0.8))
		parts.append([start, body])
		var at: float = body + rng.randf_range(0.01, 0.04)
		while at < end:
			var piece: float = rng.randf_range(0.03, 0.09)
			parts.append([at, minf(end, at + piece)])
			at += piece + rng.randf_range(0.015, 0.05)
		_streaks.append(parts)


func _draw() -> void:
	if not showing():
		return
	var alpha: float = fade()
	var swept: float = sweep()
	var row_high: float = _box.size.y / float(ROWS)
	for row: int in _streaks.size():
		var shade: Color = _stroke.darkened(0.12) if row % 3 == 2 else _stroke
		shade.a = alpha * (0.94 if row % 2 == 0 else 0.86)
		for part: Array in _streaks[row]:
			var from: float = float(part[0])
			var to: float = minf(float(part[1]), swept)
			if to <= from:
				continue
			var x0: float = from if _from_left else 1.0 - to
			draw_rect(Rect2(_box.position + Vector2(x0 * _box.size.x, row * row_high), Vector2((to - from) * _box.size.x, row_high + 0.5)), shade)
	var pressed: float = press()
	if pressed <= 0.0:
		return
	# Pressed on: a little large at first, settling to its size.
	var size: int = roundi(float(_font_size) * lerpf(1.25, 1.0, pressed))
	var extent: Vector2 = _font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
	var at: Vector2 = _box.get_center() + Vector2(-extent.x / 2.0, _font.get_ascent(size) - _font.get_height(size) / 2.0)
	draw_string_outline(_font, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, 8, Color(OUTLINE, OUTLINE.a * alpha * pressed))
	draw_string(_font, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color(_ink, alpha * pressed))
