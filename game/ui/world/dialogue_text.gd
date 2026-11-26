class_name DialogueText
extends Control

## The dialogue box's line (DECISIONS「对话框」「关键信息高亮」): text wrapped to the control's
## width and typed out a character at a time, with the places the player acts on after (`spans`)
## lit. It is laid out whole before it types, so the box keeps its size and no word jumps; each
## glyph is drawn by itself (as Label draws them), which is what lets a span take its own colour
## and its mark. A Label can do neither; a RichTextLabel has no mark under a character.

## How a lit word is marked besides its colour (colour alone tells a colour-blind reader nothing).
enum Style {
	## A dot under each 汉字 and kana (the 着重号 of a printed book); a line under letters and Hangul.
	DOTS,
	## The word flares white as its last character is typed, and settles into its colour.
	FLASH,
	## A weight heavier: each glyph drawn again a pixel to the right.
	BOLD,
}

## The mark in use (the owner's pick of the three samples).
static var style: Style = Style.DOTS

## Seconds a FLASH takes to settle.
const FLASH_SECONDS: float = 0.5
## The DOTS, in pixels at FONT_UNIT: a dot's side, its gap under the line's descent, and the room
## all of it takes under each line.
const DOT_SIZE: float = 3.0
const DOT_GAP: float = 1.0
const DOT_ROOM: float = 5.0
## The font size the pixel measures here are given for.
const FONT_UNIT: float = 18.0

## The line, as shown (Korean word joiners and all).
var text: String = "":
	set(value):
		if text == value:
			return
		text = value
		spans = []
		_shape()

## The lit places: [start, end) character ranges of `text` (KeySpans.find()).
var spans: Array[Vector2i] = []:
	set(value):
		spans = value
		_flared.resize(spans.size())
		_flared.fill(-1.0)
		_shape()

## How many characters of `text` show (-1: all), as Label's visible_characters.
var visible_characters: int = -1:
	set(value):
		if visible_characters == value:
			return
		visible_characters = value
		queue_redraw()

var font_size: int = 18:
	set(value):
		font_size = value
		_shape()

## The line's colour, and a lit word's.
var color: Color = UiPalette.BONE:
	set(value):
		color = value
		queue_redraw()
var key_color: Color = UiPalette.LANTERN

var _paragraph := TextParagraph.new()
## Each line's top, and the control's height.
var _tops: PackedFloat32Array = []
var _height: float = 0.0
## When each span flared (the control's clock; -1: not yet).
var _flared: PackedFloat32Array = []
var _clock: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			if not is_equal_approx(_paragraph.width, size.x):
				_wrap()
		NOTIFICATION_THEME_CHANGED, NOTIFICATION_TRANSLATION_CHANGED, NOTIFICATION_ENTER_TREE:
			_shape()


func _get_minimum_size() -> Vector2:
	return Vector2(0.0, _height)


## How many lines the text takes at this width.
func line_count() -> int:
	return _paragraph.get_line_count()


## Whether the character at `index` of `text` is lit.
func lit(index: int) -> bool:
	return _span_at(index) >= 0


func _shape() -> void:
	_paragraph.clear()
	if is_inside_tree() and not text.is_empty():
		_paragraph.add_string(text, get_theme_font(&"font", &"Label"), font_size)
	_wrap()


func _wrap() -> void:
	_paragraph.width = size.x if size.x > 0.0 else -1.0
	_tops.clear()
	var server: TextServer = TextServerManager.get_primary_interface()
	var spacing: float = float(get_theme_constant(&"line_spacing", &"Label")) if is_inside_tree() else 0.0
	# Every line keeps the dots' room, lit or not: the box is as tall from one line to the next.
	if style == Style.DOTS:
		spacing += roundf(DOT_ROOM * font_size / FONT_UNIT)
	var top: float = 0.0
	for index: int in _paragraph.get_line_count():
		var line: RID = _paragraph.get_line_rid(index)
		_tops.append(top)
		top += server.shaped_text_get_ascent(line) + server.shaped_text_get_descent(line) + spacing
	var height: float = maxf(top - (0.0 if style == Style.DOTS else spacing), 0.0)
	if not is_equal_approx(height, _height):
		_height = height
		update_minimum_size()
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	if style != Style.FLASH or spans.is_empty():
		return
	for index: int in spans.size():
		var shown: bool = visible_characters < 0 or visible_characters >= spans[index].y
		if shown and _flared[index] < 0.0:
			_flared[index] = _clock
			queue_redraw()
		elif _flared[index] >= 0.0 and _clock - _flared[index] <= FLASH_SECONDS + delta:
			queue_redraw()


func _draw() -> void:
	var server: TextServer = TextServerManager.get_primary_interface()
	var canvas: RID = get_canvas_item()
	var unit: float = maxf(1.0, roundf(font_size / FONT_UNIT))
	for index: int in _paragraph.get_line_count():
		var line: RID = _paragraph.get_line_rid(index)
		var baseline: float = _tops[index] + server.shaped_text_get_ascent(line)
		var x: float = 0.0
		for glyph: Dictionary in server.shaped_text_get_glyphs(line):
			var start: int = int(glyph.get("start", 0))
			if visible_characters >= 0 and start >= visible_characters:
				return
			var span: int = _span_at(start)
			var advance: float = float(glyph.get("advance", 0.0))
			var font: RID = glyph.get("font_rid", RID())
			var size_of: int = int(glyph.get("font_size", font_size))
			var offset: Vector2 = glyph.get("offset", Vector2.ZERO)
			for _repeat: int in maxi(int(glyph.get("repeat", 1)), 1):
				var at := Vector2(x + offset.x, baseline + offset.y)
				if font.is_valid():
					if span < 0:
						server.font_draw_glyph(font, canvas, size_of, at, int(glyph.get("index", 0)), color)
					else:
						_draw_key(server, canvas, font, size_of, at, int(glyph.get("index", 0)), span, unit)
				if span >= 0 and style == Style.DOTS:
					_draw_mark(start, x, advance, baseline, server.shaped_text_get_descent(line), unit)
				x += advance


## One glyph of a lit word, in the style's look.
func _draw_key(server: TextServer, canvas: RID, font: RID, size_of: int, at: Vector2, glyph_index: int, span: int, unit: float) -> void:
	var tint: Color = key_color
	if style == Style.FLASH and _flared[span] >= 0.0:
		var left: float = clampf(1.0 - (_clock - _flared[span]) / FLASH_SECONDS, 0.0, 1.0)
		# A glow that shrinks back into the word: the glyph again around itself, fading.
		if left > 0.0:
			var glow := Color(1.0, 0.96, 0.82, 0.5 * left * left)
			for step: Vector2 in [Vector2(-unit, 0), Vector2(unit, 0), Vector2(0, -unit), Vector2(0, unit), Vector2(-unit, -unit), Vector2(unit, unit), Vector2(-unit, unit), Vector2(unit, -unit)]:
				server.font_draw_glyph(font, canvas, size_of, at + step * (1.0 + left), glyph_index, glow)
		tint = key_color.lerp(Color.WHITE, left)
	server.font_draw_glyph(font, canvas, size_of, at, glyph_index, tint)
	if style == Style.BOLD:
		server.font_draw_glyph(font, canvas, size_of, at + Vector2(unit, 0.0), glyph_index, tint)


## The DOTS mark under one glyph: a dot under a 汉字 or kana, a stretch of line under anything else.
func _draw_mark(start: int, x: float, advance: float, baseline: float, descent: float, unit: float) -> void:
	if start < 0 or start >= text.length() or advance <= 0.0:
		return
	var scale: float = font_size / FONT_UNIT
	if _square(text.unicode_at(start)):
		# Under the line's descent, clear of the character's foot.
		var dot: float = roundf(DOT_SIZE * scale)
		draw_rect(Rect2(roundf(x + (advance - dot) / 2.0), roundf(baseline + descent + DOT_GAP * scale), dot, dot), key_color)
	elif text[start] != KoreanText.WORD_JOINER:
		# Close under the letters, as an underline is written (their tails cross it).
		draw_rect(Rect2(x, baseline + roundf(4.0 * scale), advance, 2.0 * unit), key_color)


## A character written in a square of its own: 汉字, kana.
static func _square(code: int) -> bool:
	return (code >= 0x4E00 and code <= 0x9FFF) or (code >= 0x3400 and code <= 0x4DBF) or (code >= 0x3040 and code <= 0x30FF)


func _span_at(index: int) -> int:
	for at: int in spans.size():
		if index >= spans[at].x and index < spans[at].y:
			return at
	return -1
