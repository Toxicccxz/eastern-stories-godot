class_name BattleCounterRing
extends Control

## 战斗界面第二轮 (DECISIONS「战斗界面 · 节拍条」): the counter ring as a small map the player
## reads, never a verdict on a button. Four round seals on a diamond — 快 at the top, 重 on the
## right, 守 at the bottom, 虚 on the left — joined clockwise by arrows that read 「克」
## (快→重→守→虚→快, CombatMoveTags.BEATS). `light(tag)` brightens that tag's two arrows: the
## one leaving it marked 克 (what it beats), the one coming in marked 怕 (what beats it); the
## others stay faint. `mark(tag)` rings the seal of the target's next move (他起手) without
## lighting an arrow. Nothing here touches a rule.

const SIZE := Vector2(150, 130)
const COMPACT_SIZE := Vector2(76, 68)
const SEAL: float = 15.0
const COMPACT_SEAL: float = 9.0
const TITLE_LINE: float = 16.0
const FAINT := Color(0.85, 0.75, 0.6, 0.28)
const LIT := UiPalette.LANTERN
## The diamond's corners as fractions of the drawing box.
const PLACES: Dictionary[StringName, Vector2] = {
	CombatMoveTags.QUICK: Vector2(0.5, 0.0), CombatMoveTags.HEAVY: Vector2(1.0, 0.5),
	CombatMoveTags.GUARD: Vector2(0.5, 1.0), CombatMoveTags.FEINT: Vector2(0.0, 0.5),
}

var _lit: StringName = &""
var _marked: StringName = &""
var _compact: bool = false
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_font = GameTheme.pixel_font()
	# TRANSLATORS: hover of the battle panel's counter ring.
	tooltip_text = tr("克制：快克重、重克守、守克虚、虚克快。箭头从克的一方指向被克的一方；想克他起手的那一类，就找指向它的那一印。")
	_fit()


func set_compact(on: bool) -> void:
	_compact = on
	_fit()
	queue_redraw()


## Brightens `tag`'s two arrows (&"" none).
func light(tag: StringName) -> void:
	if tag != _lit:
		_lit = tag
		queue_redraw()


## Rings the seal of `tag` (the target's next move; &"" none).
func mark(tag: StringName) -> void:
	if tag != _marked:
		_marked = tag
		queue_redraw()


func lit() -> StringName:
	return _lit


func marked() -> StringName:
	return _marked


func _fit() -> void:
	custom_minimum_size = (COMPACT_SIZE if _compact else SIZE) + Vector2(0, 0.0 if _compact else TITLE_LINE)


func _seal() -> float:
	return COMPACT_SEAL if _compact else SEAL


func _centre_of(tag: StringName) -> Vector2:
	var box: Vector2 = COMPACT_SIZE if _compact else SIZE
	var top: float = 0.0 if _compact else TITLE_LINE
	var inner := Rect2(Vector2(_seal() + 2, top + _seal() + 2), box - Vector2(_seal() + 2, _seal() + 2) * 2.0)
	var offset: Vector2 = Vector2((size.x - box.x) * 0.5, 0)
	return offset + inner.position + inner.size * PLACES[tag]


func _draw() -> void:
	if _font == null:
		return
	var text_size: int = 12 if _compact else GameTheme.text_size(18)
	if not _compact:
		# TRANSLATORS: the small title over the battle panel's counter ring.
		var title: String = tr("克制")
		var width: float = _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(_font, Vector2((size.x - width) * 0.5, 12), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiPalette.MUTED)
	for from: StringName in CombatMoveTags.ALL:
		var to: StringName = CombatMoveTags.BEATS[from]
		var lit: bool = not _lit.is_empty() and (from == _lit or to == _lit)
		_arrow(_centre_of(from), _centre_of(to), LIT if lit else FAINT, 2.0 if lit else 1.0)
		if lit and not _compact:
			# TRANSLATORS: the word on a lit arrow of the counter ring: 克 the lit tag beats the next one; 怕 the one before beats it.
			var word: String = tr("克") if from == _lit else tr("怕")
			var middle: Vector2 = (_centre_of(from) + _centre_of(to)) * 0.5
			var outward: Vector2 = (middle - (_centre_of(CombatMoveTags.QUICK) + _centre_of(CombatMoveTags.GUARD)) * 0.5).normalized() * 12.0
			var width: float = _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(_font, middle + outward + Vector2(-width * 0.5, 5), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, LIT)
	for tag: StringName in CombatMoveTags.ALL:
		var centre: Vector2 = _centre_of(tag)
		var color: Color = BattleBeatChips.COLORS[tag]
		var dim: bool = not _lit.is_empty() and tag != _lit and CombatMoveTags.BEATS[tag] != _lit and CombatMoveTags.BEATS[_lit] != tag
		draw_circle(centre, _seal(), color.darkened(0.45) if dim else color)
		draw_arc(centre, _seal(), 0.0, TAU, 24, UiPalette.INK, 1.0)
		if tag == _marked:
			draw_arc(centre, _seal() + 3.0, 0.0, TAU, 28, UiPalette.BONE, 2.0)
		var glyph: String = CombatMoveTags.label(tag)
		var width: float = _font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		draw_string(_font, centre + Vector2(-width * 0.5, text_size * 0.35), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, UiPalette.BONE)


## An arrow from seal to seal, stopping short of both.
func _arrow(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var direction: Vector2 = (to - from).normalized()
	var start: Vector2 = from + direction * (_seal() + 3.0)
	var end: Vector2 = to - direction * (_seal() + 3.0)
	draw_line(start, end, color, width)
	var side: Vector2 = Vector2(-direction.y, direction.x)
	var head: float = 6.0 if not _compact else 4.0
	draw_colored_polygon(PackedVector2Array([end, end - direction * head + side * head * 0.6, end - direction * head - side * head * 0.6]), color)
