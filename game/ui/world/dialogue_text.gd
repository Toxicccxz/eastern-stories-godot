class_name DialogueText
extends Control

## The dialogue box's line (DECISIONS「对话框」「关键信息高亮」): text wrapped to the control's
## width and typed out a character at a time, with the places the player acts on after (`spans`)
## lit. It is laid out whole before it types, so the box keeps its size and no word jumps; each
## glyph is drawn by itself (as Label draws them), which is what lets a span take its own colour
## and its light. A Label can do neither.
##
## A lit word is in the lantern colour and shimmers for as long as the line shows (owner,
## 2026-11-26: 「亮一下那个不错，改成一直在闪烁着亮」, then of two rhythms 「一道光扫过」): it flares
## white as its last character is typed, and from then on a light runs along it from its first
## character to its last, again and again. The movement is what marks it for a reader who cannot
## tell the colour.

## Seconds the flare takes to settle as the word has been typed.
const FLASH_SECONDS: float = 0.5
## The light that runs along a lit word: seconds it takes to cross the word and to wait before the
## next, how wide it is in characters, and how far toward white a character goes under its middle.
const SWEEP_SECONDS: float = 0.75
const SWEEP_REST: float = 0.55
const SWEEP_WIDTH: float = 1.1
const SWEEP_LIGHT: float = 0.62
## The glow about a glyph at its brightest (its alpha).
const GLOW: float = 0.42
## The font size the pixel measures here are given for.
const FONT_UNIT: float = 18.0
const _AROUND: Array[Vector2] = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1)]

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
		queue_redraw()

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
## When each span had been typed whole and flared (the control's clock; -1: not yet).
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


## The characters of `text` on line `index`: [start, end).
func line_range(index: int) -> Vector2i:
	return _paragraph.get_line_range(index)


## Whether the character at `index` of `text` is lit.
func lit(index: int) -> bool:
	return _span_at(index) >= 0


## How bright the character at `index` is now: 0 its colour, 1 white (tests, the kit).
func brightness(index: int) -> float:
	var span: int = _span_at(index)
	return 0.0 if span < 0 else _light(span, index)


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
	var top: float = 0.0
	for index: int in _paragraph.get_line_count():
		var line: RID = _paragraph.get_line_rid(index)
		_tops.append(top)
		top += server.shaped_text_get_ascent(line) + server.shaped_text_get_descent(line) + spacing
	var height: float = maxf(top - spacing, 0.0)
	if not is_equal_approx(height, _height):
		_height = height
		update_minimum_size()
	queue_redraw()


func _process(delta: float) -> void:
	if spans.is_empty() or not is_visible_in_tree():
		return
	_clock += delta
	for index: int in spans.size():
		if _flared[index] < 0.0 and (visible_characters < 0 or visible_characters >= spans[index].y):
			_flared[index] = _clock
	# A lit word never stands still.
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
						_draw_lit(server, canvas, font, size_of, at, int(glyph.get("index", 0)), _light(span, start), unit)
				x += advance


## One glyph of a lit word, `light` of the way from its colour to white, a glow about it.
func _draw_lit(server: TextServer, canvas: RID, font: RID, size_of: int, at: Vector2, glyph_index: int, light: float, unit: float) -> void:
	if light > 0.02:
		var glow := Color(1.0, 0.95, 0.8, GLOW * light * light)
		for step: Vector2 in _AROUND:
			server.font_draw_glyph(font, canvas, size_of, at + step * unit * (1.0 + light), glyph_index, glow)
	server.font_draw_glyph(font, canvas, size_of, at, glyph_index, key_color.lerp(Color.WHITE, light))


## How bright the character at `index` of span `span` is now: the light running along the word,
## and over it the flare of the moment the word had been typed.
func _light(span: int, index: int) -> float:
	var shimmer: float = 0.0
	var turn: float = fmod(_clock, SWEEP_SECONDS + SWEEP_REST) / SWEEP_SECONDS
	if turn <= 1.0:
		# The light's middle, in characters from the word's first: from before it to past it.
		var length: float = float(spans[span].y - spans[span].x)
		var middle: float = lerpf(-SWEEP_WIDTH, length + SWEEP_WIDTH, turn)
		var away: float = absf(float(index - spans[span].x) + 0.5 - middle) / SWEEP_WIDTH
		shimmer = SWEEP_LIGHT * maxf(0.0, 1.0 - away * away)
	if _flared[span] < 0.0:
		return shimmer
	return maxf(shimmer, clampf(1.0 - (_clock - _flared[span]) / FLASH_SECONDS, 0.0, 1.0))


func _span_at(index: int) -> int:
	for at: int in spans.size():
		if index >= spans[at].x and index < spans[at].y:
			return at
	return -1
