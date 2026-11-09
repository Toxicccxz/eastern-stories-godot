class_name BattlePanelChrome
extends Control

## 战斗演出 E (DECISIONS「战斗演出 E」): what a side panel (a BattleParticipantCard in panel mode)
## is dressed in, drawn behind its rows. Two styles (battle_stage.json panels.style):
## - banner (阵旗): a hanging cloth — a wooden pole across the top past the cloth's edges with a
##   knob at each end (gold on the current target's), the side's colour down both cloth edges,
##   three cords with knots hanging below;
## - ink (水墨): no frame — a soft wash of ink behind the bust and rows, a thin line of the side's
##   colour down the edge facing the screen's side (gold on the current target's).
## Presentation only.

const POLE: Color = Color("5a3820")
const POLE_LIGHT: Color = Color("7d5230")
const KNOB: Color = Color("3d2d16")
const CLOTH: Color = Color("2a1e17")
const CORD: Color = Color("8a5a35")
const INK: Color = Color(0.04, 0.03, 0.03)

var style: String = "banner"
## 0: the player's side (on the left), 1: the other (on the right).
var side: int = 0
var current: bool = false
var side_colour: Color = UiPalette.PATINA


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	resized.connect(queue_redraw)


func dress(p_style: String, p_side: int, p_current: bool, colour: Color) -> void:
	if p_style == style and p_side == side and p_current == current and colour == side_colour:
		return
	style = p_style
	side = p_side
	current = p_current
	side_colour = colour
	queue_redraw()


func _draw() -> void:
	# The whole card (its container keeps this inside the card's margins).
	var card := get_parent() as Control
	var box := Rect2(-position, card.size) if card != null else Rect2(Vector2.ZERO, size)
	if style == "ink":
		_draw_ink(box)
	else:
		_draw_banner(box)


func _draw_banner(box: Rect2) -> void:
	# The cloth, its side-coloured edges and a darker hem.
	draw_rect(box, Color(CLOTH, 0.94))
	draw_rect(Rect2(box.position, Vector2(4, box.size.y)), side_colour)
	draw_rect(Rect2(Vector2(box.end.x - 4, box.position.y), Vector2(4, box.size.y)), side_colour)
	draw_rect(Rect2(Vector2(box.position.x, box.end.y - 5), Vector2(box.size.x, 5)), side_colour.darkened(0.45))
	# The pole across the top, past the cloth, and its two knobs.
	var pole := Rect2(Vector2(box.position.x - 6, box.position.y - 9), Vector2(box.size.x + 12, 8))
	draw_rect(pole, POLE)
	draw_rect(Rect2(pole.position, Vector2(pole.size.x, 2)), POLE_LIGHT)
	var knob: Color = UiPalette.LANTERN if current else KNOB
	for x: float in [pole.position.x - 2, pole.end.x - 8]:
		draw_rect(Rect2(Vector2(x, pole.position.y - 2), Vector2(10, 12)), knob)
		draw_rect(Rect2(Vector2(x, pole.position.y - 2), Vector2(10, 2)), knob.lightened(0.3))
	# Three cords hanging from the hem, a knot on each.
	for share: float in [0.25, 0.5, 0.75]:
		var x: float = roundf(box.position.x + box.size.x * share) - 1.0
		var length: float = 18.0 if share == 0.5 else 12.0
		draw_rect(Rect2(Vector2(x, box.end.y), Vector2(2, length)), CORD)
		draw_rect(Rect2(Vector2(x - 2, box.end.y + length), Vector2(6, 6)), side_colour)


func _draw_ink(box: Rect2) -> void:
	# A pale mist of paper behind the bust (ink on a dark scene does not show; the paper does).
	var portrait: float = box.size.y * 0.52
	var centre := Vector2(box.get_center().x, box.position.y + portrait * 0.55)
	var reach: float = maxf(box.size.x * 0.62, portrait * 0.6)
	for ring: int in 16:
		var share: float = 1.0 - float(ring) / 16.0
		draw_circle(centre, reach * share, Color(UiPalette.PAPER, 0.022))
	# The rows on a band of ink with dry-brush ends (ragged rows of pixels, the same each time).
	var band := Rect2(Vector2(box.position.x, box.position.y + portrait), Vector2(box.size.x, box.size.y - portrait))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + side
	var step: float = 3.0
	var y: float = band.position.y
	while y < band.end.y:
		var ragged_left: float = rng.randf_range(0.0, 14.0)
		var ragged_right: float = rng.randf_range(0.0, 14.0)
		var fade: float = clampf((y - band.position.y) / 18.0, 0.0, 1.0) * clampf((band.end.y - y) / 10.0, 0.0, 1.0)
		draw_rect(Rect2(Vector2(band.position.x + ragged_left, y), Vector2(band.size.x - ragged_left - ragged_right, step)), Color(INK, 0.78 * fade))
		y += step
	# A brush stroke of the side's colour under the bust, and the side's line down the edge facing
	# the screen's side (gold on the current target's).
	var stroke_y: float = band.position.y - 2.0
	var x0: float = box.position.x + 10.0
	var length: float = box.size.x - 20.0
	for index: int in int(length / 2.0):
		var t: float = float(index) / (length / 2.0)
		var thick: float = 4.0 * sin(t * PI) + 1.0
		if rng.randf() < 0.12 and t > 0.7:
			continue
		draw_rect(Rect2(Vector2(x0 + index * 2.0, stroke_y - thick * 0.5), Vector2(2, thick)), Color(side_colour, 0.9))
	var x: float = box.position.x if side == 0 else box.end.x - 2
	var line: Color = UiPalette.LANTERN if current else side_colour
	draw_rect(Rect2(Vector2(x, box.position.y + 6), Vector2(2, box.size.y - 12)), line)
