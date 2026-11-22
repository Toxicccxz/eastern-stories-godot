class_name TitleRibbon
extends Node2D

## The silk ribbon woven through the foot of the title's lettering (TitleLogo, DECISIONS「标题画面」):
## a narrow band of faded crimson silk running under the characters, the lettering lying over it
## in some spans and the band over the lettering in the others, the title in the other language
## along it; past the last character it twists — its pale back showing — and trails a swallowtail
## that stirs in the wind. Laid out on the lettering's ink box from its TitleScreenDefinition
## Ribbon (percent of that box); drawn in title_ribbon.gdshader, which cuts the band away where the
## lettering lies over it.

const SHADER: Shader = preload("res://presentation/title/shaders/title_ribbon.gdshader")
const ROMAN: FontFile = preload("res://assets/fonts/Cinzel-VariableFont_wght.ttf")
const ROMAN_WEIGHT: int = 600
const SAMPLES: int = 48
## How far the band arches up in its middle and rises to its fold, against the lettering's height.
const ARCH: float = 0.035
const RISE: float = 0.015
## The twist past the fold: how far along and how far down the band comes out of it (band widths),
## how much narrower it shows mid-twist.
const TWIST_ALONG: float = 0.9
const TWIST_DOWN: float = 0.42
const TWIST_PINCH: float = 0.5
## The tail: how long (lettering heights), how much it rises, its swallowtail's depth (band widths).
const TAIL_LONG: float = 0.5
const TAIL_RISE: float = 0.08
const NOTCH: float = 0.36
## The left end is cut on a slant, its bottom reaching this far further left (band widths).
const LEFT_SLANT: float = 0.35
## The words: their size against the band, how much of the band's run they fill (from where to
## where, 0 its start and 1 its fold, so the seal keeps the fold), the most room between letters
## (parts of their size), and a mask's height against the band.
const TEXT_SIZE: float = 0.6
const TEXT_RUN: Vector2 = Vector2(0.25, 0.86)
const TEXT_SPACE_MOST: float = 0.55
const MASK_TALL: float = 0.62
## The tail's sway at its tip (UI pixels at 1280 wide).
const SWAY: float = 4.0
const TEXT_COLOUR := Color(0.96, 0.92, 0.82)

## How the band runs, in percent of the ink box (TitleScreenDefinition.Ribbon).
var config: TitleScreenDefinition.Ribbon = TitleScreenDefinition.Ribbon.new()
## The band's width, the main run's centreline from its start to the fold (view pixels), the fold
## and the band's direction there, and how low the ribbon reaches.
var band: float = 30.0
var centre: PackedVector2Array = []
var fold: Vector2 = Vector2.ZERO
var fold_direction: Vector2 = Vector2.RIGHT
## Where the band comes out of its twist into the tail.
var twist_out: Vector2 = Vector2.ZERO
var bottom: float = 0.0

var _band_mat: ShaderMaterial
var _text_mat: ShaderMaterial
var _text: Node2D
var _words: String = ""
var _mask: Texture2D
var _font: FontVariation
var _font_size: int = 16
var _spacing: float = 0.0
var _polygons: Array[Array] = []


func _init() -> void:
	name = "Ribbon"
	_band_mat = _material(0)
	material = _band_mat
	_text = Node2D.new()
	_text.name = "Line"
	_text_mat = _material(1)
	_text.material = _text_mat
	_text.draw.connect(_draw_words)
	add_child(_text)
	_font = FontVariation.new()
	_font.base_font = ROMAN
	_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): ROMAN_WEIGHT}


## The words along the band: `words` set in Cinzel, or `mask` (red = ink) when there is one.
func set_words(words: String, mask: Texture2D) -> void:
	_words = words
	_mask = mask
	_text_mat.set_shader_parameter("mode", 2 if mask != null else 1)
	_text.queue_redraw()


func words() -> String:
	return _words


## Lays the band on the ink box `ink` (view pixels) of the lettering drawn from `letters_rect` with
## `letters`, in a view `view_size` big, `unit` pixels to a UI pixel.
func lay(ink: Rect2, letters: Texture2D, letters_rect: Rect2, view_size: Vector2, unit: float) -> void:
	band = ink.size.y * config.band / 100.0
	var x0: float = ink.position.x + ink.size.x * config.from / 100.0
	var x1: float = ink.position.x + ink.size.x * config.fold / 100.0
	var y0: float = ink.position.y + ink.size.y * config.y / 100.0
	centre.clear()
	for i: int in SAMPLES + 1:
		var s: float = float(i) / SAMPLES
		centre.append(Vector2(lerpf(x0, x1, s), y0 - ink.size.y * (ARCH * sin(PI * s) + RISE * s)))
	fold = centre[SAMPLES]
	fold_direction = (centre[SAMPLES] - centre[SAMPLES - 1]).normalized()
	_build()
	var spans := Vector4(-1.0, -1.0, -1.0, -1.0)
	for i: int in mini(config.under.size(), 4):
		spans[i] = ink.position.x + ink.size.x * config.under[i] / 100.0
	for mat: ShaderMaterial in [_band_mat, _text_mat]:
		mat.set_shader_parameter("letters", letters)
		mat.set_shader_parameter("letters_rect", Vector4(letters_rect.position.x, letters_rect.position.y, letters_rect.size.x, letters_rect.size.y))
		mat.set_shader_parameter("view_size", view_size)
		mat.set_shader_parameter("under", spans)
		mat.set_shader_parameter("reveal_from", fold.x)
		mat.set_shader_parameter("reveal_to", x0 - band)
		mat.set_shader_parameter("band", band)
		mat.set_shader_parameter("sway", SWAY * unit)
		mat.set_shader_parameter("text_colour", Vector3(TEXT_COLOUR.r, TEXT_COLOUR.g, TEXT_COLOUR.b))
	_font_size = maxi(8, roundi(band * TEXT_SIZE))
	var run: float = _run_length(TEXT_RUN.x, TEXT_RUN.y)
	var natural: float = _font.get_string_size(_words, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	_spacing = clampf((run - natural) / maxf(1.0, _words.length() - 1), 0.0, _font_size * TEXT_SPACE_MOST)
	queue_redraw()
	_text.queue_redraw()


## Unrolled from the fold leftward (0 → 1), and faded (1 shown, 0 gone).
func show_part(unrolled: float, shown: float) -> void:
	for mat: ShaderMaterial in [_band_mat, _text_mat]:
		mat.set_shader_parameter("reveal", unrolled)
		mat.set_shader_parameter("fade", shown)


func _material(mode: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("mode", mode)
	return mat


## The band as polygons, drawn in order: its shadow, the tail, the twist, the main run.
func _build() -> void:
	_polygons.clear()
	var half: float = band / 2.0
	var normals := PackedVector2Array()
	for i: int in centre.size():
		var a: Vector2 = centre[maxi(0, i - 1)]
		var b: Vector2 = centre[mini(centre.size() - 1, i + 1)]
		var t: Vector2 = (b - a).normalized()
		normals.append(Vector2(-t.y, t.x))
	# The main run as a quad a segment (one long outline of nearly straight edges does not
	# triangulate); the left end slanted. Its shadow is the same, a little lower.
	var run: Array[Array] = []
	var shadow: Array[Array] = []
	for i: int in SAMPLES:
		# The slant reaches out at the bottom (moving the top in would cross a short first quad).
		var bottom0: Vector2 = centre[i] + normals[i] * half - (Vector2(band * LEFT_SLANT, 0.0) if i == 0 else Vector2.ZERO)
		var quad := PackedVector2Array([centre[i] - normals[i] * half, centre[i + 1] - normals[i + 1] * half, centre[i + 1] + normals[i + 1] * half, bottom0])
		var s0: float = float(i) / SAMPLES
		var s1: float = float(i + 1) / SAMPLES
		var uvs := PackedVector2Array([Vector2(s0, 0.0), Vector2(s1, 0.0), Vector2(s1, 1.0), Vector2(s0, 1.0)])
		run.append([quad, _colours(4, Color(1, 0, 0)), uvs])
		var low := PackedVector2Array()
		for point: Vector2 in quad:
			low.append(point + Vector2(0.0, band * 0.14))
		shadow.append([low, _colours(4, Color(0, 0, 0)), uvs])
	# The twist: from the fold's end, down and along, narrowing in its middle; its back shows.
	var t: Vector2 = fold_direction
	var n: Vector2 = Vector2(-t.y, t.x)
	var out: Vector2 = fold + t * band * TWIST_ALONG + n * band * TWIST_DOWN
	twist_out = out
	var mid: Vector2 = (fold + out) / 2.0
	var twist := PackedVector2Array([fold - n * half, mid - n * half * (1.0 - TWIST_PINCH), out - n * half, out + n * half, mid + n * half * (1.0 - TWIST_PINCH), fold + n * half])
	var twist_uvs := PackedVector2Array([Vector2(0, 0), Vector2(0.5, 0.15), Vector2(1, 0), Vector2(1, 1), Vector2(0.5, 0.85), Vector2(0, 1)])
	# The tail: on from the twist, rising a little, cut into a swallowtail; it sways toward its tip.
	var tail_length: float = band / (config.band / 100.0) * TAIL_LONG
	var tail_end: Vector2 = out + t * tail_length - n * tail_length * TAIL_RISE
	var tail_t: Vector2 = (tail_end - out).normalized()
	var tail_n := Vector2(-tail_t.y, tail_t.x)
	var tail := PackedVector2Array([out - n * half, tail_end - tail_n * half, tail_end - tail_t * band * NOTCH, tail_end + tail_n * half, out + n * half])
	var tail_uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0.9, 0.5), Vector2(1, 1), Vector2(0, 1)])
	var tail_colours := PackedColorArray([Color(1, 0, 0), Color(1, 1, 0), Color(1, 0.8, 0), Color(1, 1, 0), Color(1, 0, 0)])
	_polygons.append_array(shadow)
	_polygons.append([tail, tail_colours, tail_uvs])
	_polygons.append([twist, _colours(twist.size(), Color(0.5, 0, 0)), twist_uvs])
	_polygons.append_array(run)
	bottom = 0.0
	for polygon: Array in _polygons:
		for point: Vector2 in polygon[0]:
			bottom = maxf(bottom, point.y)


static func _colours(count: int, colour: Color) -> PackedColorArray:
	var colours := PackedColorArray()
	colours.resize(count)
	colours.fill(colour)
	return colours


func _draw() -> void:
	for polygon: Array in _polygons:
		draw_polygon(polygon[0], polygon[1], polygon[2])


## The words along the main run's centreline: each letter on the curve, turned with it (or the
## mask, centred on the run and turned to its middle).
func _draw_words() -> void:
	if centre.size() < 2 or (_words.is_empty() and _mask == null):
		return
	if _mask != null:
		# The mask is padded (TitleLogo.MASK_PAD): its ink is MASK_TALL of the band.
		var ink_share: float = (_mask.get_height() - 2.0 * TitleLogo.MASK_PAD) / _mask.get_height()
		var tall: float = band * MASK_TALL / ink_share
		var wide: float = tall * _mask.get_width() / _mask.get_height()
		var at: float = _run_length(0.0, (TEXT_RUN.x + TEXT_RUN.y) / 2.0)
		var place: Array = _along(at)
		_text.draw_set_transform(place[0], (place[1] as Vector2).angle(), Vector2.ONE)
		_text.draw_texture_rect(_mask, Rect2(-wide / 2.0, -tall / 2.0, wide, tall), false)
		_text.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var run: float = _run_length(TEXT_RUN.x, TEXT_RUN.y)
	var widths: Array[float] = []
	var total: float = 0.0
	for i: int in _words.length():
		var w: float = _font.get_char_size(_words.unicode_at(i), _font_size).x
		widths.append(w)
		total += w + (_spacing if i < _words.length() - 1 else 0.0)
	var at: float = _run_length(0.0, TEXT_RUN.x) + (run - total) / 2.0
	# Capitals sit centred on the band: half their height under the centreline.
	var drop: float = _font.get_ascent(_font_size) * 0.36
	for i: int in _words.length():
		var place: Array = _along(at + widths[i] / 2.0)
		_text.draw_set_transform(place[0], (place[1] as Vector2).angle(), Vector2.ONE)
		var glyph := Vector2(-widths[i] / 2.0, drop)
		_text.draw_char(_font, glyph + Vector2(0.0, maxf(1.0, band * 0.03)), _words[i], _font_size, Color(0.15, 0.04, 0.03, 0.55))
		_text.draw_char(_font, glyph, _words[i], _font_size, TEXT_COLOUR)
		at += widths[i] + _spacing
	_text.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The run's length between two of its parts (0 its start, 1 the fold).
func _run_length(from: float, to: float) -> float:
	var length: float = 0.0
	var i0: int = int(from * SAMPLES)
	var i1: int = int(to * SAMPLES)
	for i: int in range(i0, mini(i1, SAMPLES)):
		length += centre[i].distance_to(centre[i + 1])
	return length


## The point `distance` along the run from its start, and the run's direction there.
func _along(distance: float) -> Array:
	var left: float = distance
	for i: int in SAMPLES:
		var step: float = centre[i].distance_to(centre[i + 1])
		if left <= step or i == SAMPLES - 1:
			var d: Vector2 = (centre[i + 1] - centre[i]).normalized()
			return [centre[i] + d * clampf(left, 0.0, step), d]
		left -= step
	return [centre[SAMPLES], fold_direction]
