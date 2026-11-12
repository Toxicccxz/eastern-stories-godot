class_name BattleBeatFill
extends Control

## 节拍填格 (DECISIONS「节拍填格」): a move pressed sends its beat into the strip — a bar in the
## move's tag colour lifts off the pressed button, flies up into the slot (a 重's two slots as
## one long slot) and fills it from the left like a progress bar, a bright edge leading, the
## move's one character showing as it fills, a short flash when it is full. Drawn over the whole
## panel (the rows dim while the round plays; this does not), takes no input and holds nothing
## up: the fight resolves the beat meanwhile. Only what the panel hands it is shown.

signal finished

## The share of the effect spent flying; the rest fills; the last of it flashes.
const TRAVEL: float = 0.4
const FLASH: float = 0.88
const AFTERIMAGES: int = 3
const EDGE_PX: float = 3.0
const WOOD := Color("b07a44")
const WOOD_SIDE := Color("6a4324")
const TEXT := Color("f5e6c8")
const FREE_LINE := Color(0.95, 0.85, 0.65, 0.35)

## The effects playing: from (Rect2), to (Rect2), colour, glyph, t (0..1), seconds.
var _plays: Array[Dictionary] = []
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = GameTheme.pixel_font()
	set_process(false)


## The beat leaves `from` (the pressed button) and fills `to` (its slot or slots), both in this
## control's space, in `colour` with `glyph`, over `seconds`. False (and nothing shown) for no time.
func play(from: Rect2, to: Rect2, colour: Color, glyph: String, seconds: float) -> bool:
	if seconds <= 0.0 or to.size == Vector2.ZERO:
		return false
	_plays.append({"from": from, "to": to, "colour": colour, "glyph": glyph, "t": 0.0, "seconds": seconds})
	set_process(true)
	queue_redraw()
	return true


func playing() -> bool:
	return not _plays.is_empty()


## How far the newest effect has gone (0..1; 1 when none plays) (tests).
func progress() -> float:
	return 1.0 if _plays.is_empty() else float(_plays.back()["t"])


## Everything stopped (the fight is over).
func clear() -> void:
	_plays.clear()
	set_process(false)
	queue_redraw()


## Moves the effects on by `delta` seconds; one done says `finished`.
func advance(delta: float) -> void:
	for entry: Dictionary in _plays.duplicate():
		entry["t"] = minf(1.0, float(entry["t"]) + delta / float(entry["seconds"]))
		if float(entry["t"]) >= 1.0:
			_plays.erase(entry)
			finished.emit()
	set_process(not _plays.is_empty())
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


## How much of the slot is filled at `t` (0 while the bar flies, then 0..1, eased out).
static func fill_share(t: float) -> float:
	if t <= TRAVEL:
		return 0.0
	var f: float = clampf((t - TRAVEL) / (FLASH - TRAVEL), 0.0, 1.0)
	return 1.0 - (1.0 - f) * (1.0 - f)


## Where the flying bar is at `t` (it shrinks from the button's size to a bar as tall as the slot).
static func bar_at(from: Rect2, to: Rect2, t: float) -> Rect2:
	var f: float = clampf(t / TRAVEL, 0.0, 1.0)
	var eased: float = f * f * (3.0 - 2.0 * f)
	var start := Rect2(from.position + Vector2(0, from.size.y * 0.35), Vector2(from.size.x, from.size.y * 0.3))
	var end := Rect2(to.position, Vector2(minf(to.size.x, start.size.x) * 0.5, to.size.y))
	return Rect2(start.position.lerp(end.position, eased), start.size.lerp(end.size, eased))


func _draw() -> void:
	for entry: Dictionary in _plays:
		var t: float = float(entry["t"])
		var from: Rect2 = entry["from"]
		var to: Rect2 = entry["to"]
		var colour: Color = entry["colour"]
		# The slot as it was (free) until it fills: the strip already holds it underneath.
		draw_rect(Rect2(to.position + Vector2(0, 2), to.size), WOOD_SIDE)
		draw_rect(to, WOOD)
		draw_rect(Rect2(to.position + Vector2(3, 3), to.size - Vector2(6, 6)), FREE_LINE, false, 1.0)
		if t < TRAVEL:
			# The bar and the ghosts it leaves on its way up.
			for n: int in range(AFTERIMAGES, 0, -1):
				var ghost: Rect2 = bar_at(from, to, maxf(0.0, t - 0.04 * n))
				draw_rect(ghost, Color(colour, 0.18 * (AFTERIMAGES + 1 - n)))
			var bar: Rect2 = bar_at(from, to, t)
			draw_rect(bar.grow(2.0), Color(colour.lightened(0.5), 0.5))
			draw_rect(bar, colour.lightened(0.15))
			continue
		# The slot filling from the left, the edge leading.
		var share: float = fill_share(t)
		var filled := Rect2(to.position, Vector2(to.size.x * share, to.size.y))
		draw_rect(filled, colour)
		if share < 1.0:
			draw_rect(Rect2(Vector2(filled.end.x - EDGE_PX, to.position.y), Vector2(EDGE_PX, to.size.y)), Color(1.0, 0.95, 0.8, 0.95))
		draw_rect(to.grow(1.0), Color(colour.lightened(0.4), 0.9), false, 2.0)
		var glyph: String = entry["glyph"]
		if not glyph.is_empty() and _font != null and share > 0.5:
			var px: int = int(clampf(to.size.y * 0.42, 12.0, 20.0))
			var width: float = _font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			var centre: Vector2 = to.get_center()
			draw_string(_font, Vector2(centre.x - width * 0.5, centre.y + px * 0.35), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(TEXT, clampf((share - 0.5) * 2.0, 0.0, 1.0)))
		if t > FLASH:
			var flash: float = 1.0 - (t - FLASH) / (1.0 - FLASH)
			draw_rect(to.grow(2.0 + 4.0 * (1.0 - flash)), Color(1.0, 0.95, 0.8, 0.45 * flash))
