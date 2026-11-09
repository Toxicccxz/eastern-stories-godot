class_name BattleBeatStamps
extends Control

## 战斗拍数 B (DECISIONS「战斗拍数」): an enemy's beat plan as stamps down the edge of its card
## that faces the middle of the screen — the first beat a solid vermilion seal bearing what
## it is (the move's tag, the perform's 「」 word, 守 for 守势, ？ unread), each beat it only
## reads an empty dashed seal with ？. The stamps lie over the card, take no room in its
## layout and no input, and show only what the card hands them. They start under the name
## line, so the name stays readable.

const SIZE: float = 24.0
const GAP: float = 6.0
const TOP: float = 46.0
## The seal sticks out past the card's edge by this much.
const OUT: float = 14.0
const SOLID := Color(0.72, 0.22, 0.16, 0.96)
const SOLID_EDGE := Color(0.45, 0.12, 0.08)
const HOLLOW := Color(0.82, 0.32, 0.24, 0.9)
const TEXT := Color("f5e6c8")
const DASH: float = 3.0
const STRIKE := Color(0.12, 0.08, 0.06, 0.95)

var _first: String = ""
var _read: int = 0
## Whether the first seal is a settled beat (solid) or one only read (hollow, its word kept).
var _settled: bool = true
## 战斗拍数 E: the first seal struck through (失衡 took that beat), until the plan changes.
var _struck: bool = false
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = GameTheme.pixel_font()


## `first`: the first beat's word ("" for no plan), `settled` whether it is the settled beat
## (solid) or one the enemy only reads (hollow); `read`: how many read beats follow.
func present(first: String, read: int, settled: bool = true) -> void:
	if first == _first and read == _read and settled == _settled:
		return
	_struck = false
	_first = first
	_read = maxi(0, read)
	_settled = settled
	queue_redraw()


## 战斗拍数 E: 失衡 took the first beat — a stroke of ink through its seal.
func strike_first() -> void:
	if _first.is_empty():
		return
	_struck = true
	queue_redraw()


func first_struck() -> bool:
	return _struck


func first_settled() -> bool:
	return _settled


func first_text() -> String:
	return _first


func read_count() -> int:
	return _read


func _draw() -> void:
	if _first.is_empty():
		return
	var x: float = -OUT
	var y: float = TOP
	var seal := Rect2(Vector2(x, y), Vector2(SIZE, SIZE))
	if _settled:
		draw_rect(seal, SOLID)
		draw_rect(seal, SOLID_EDGE, false, 1.5)
	else:
		_dashed(seal, HOLLOW)
	_word(seal, _first)
	if _struck:
		draw_line(seal.position + Vector2(-3, SIZE * 0.78), seal.position + Vector2(SIZE + 3, SIZE * 0.22), STRIKE, 3.5)
	for _index: int in _read:
		y += SIZE + GAP
		var hollow := Rect2(Vector2(x, y), Vector2(SIZE, SIZE))
		_dashed(hollow, HOLLOW)
		_word(hollow, "？")


func _word(seal: Rect2, text: String) -> void:
	if _font == null:
		return
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(_font, seal.position + Vector2((seal.size.x - width) * 0.5, seal.size.y - 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT)


func _dashed(rect: Rect2, color: Color) -> void:
	var corners: Array[Vector2] = [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]
	for index: int in 4:
		var from: Vector2 = corners[index]
		var to: Vector2 = corners[(index + 1) % 4]
		var length: float = from.distance_to(to)
		var step: Vector2 = (to - from) / length
		var at: float = 0.0
		while at < length:
			draw_line(from + step * at, from + step * minf(at + DASH, length), color, 1.5)
			at += DASH * 2.0
