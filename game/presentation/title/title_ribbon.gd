class_name TitleRibbon
extends Node2D

## The silk ribbon through the title's lettering (TitleLogo, DECISIONS「标题画面」): a narrow band
## of silk running through the characters, in front of some and behind others (where it runs behind
## it shows only between their strokes), the title in the other language on it where it runs in
## front; it floats, swaying slowly all along, and its loose ends stream away past the first and
## last characters, slowly turning over in the wind, their swallowtail tips cut. It arrives on the
## wind, threading itself through the lettering, and leaves drifting on and fading. Laid out on
## the lettering's ink box from its TitleScreenDefinition Ribbon (the points it runs through);
## drawn as one triangle mesh a frame in title_ribbon.gdshader, which cuts the band away where the
## lettering stands in front of it.
##
## The band is a strip of silk `_length` long (its material, 0 the trailing tip, `_length` the
## leading one) slid along a track: the way in, then where it rests, then on toward the way out.
## `show_part` says how far along: 0 not yet come, 1 at rest, then drifting on as it fades.

const SHADER: Shader = preload("res://presentation/title/shaders/title_ribbon.gdshader")
const ROMAN: FontFile = preload("res://assets/fonts/Cinzel-VariableFont_wght.ttf")
const ROMAN_WEIGHT: int = 600
## The band's columns, apart (band widths).
const COLUMN_STEP: float = 0.3
## Swallowtail tips: how deep the notch (band widths).
const NOTCH: float = 0.55
## The wind, slow and large like silk floating in water (owner, 2026-11-22: quick small waves read
## as twitching; it should still be lively): the whole band sways (band widths; its wave's length
## in parts of the band's length; radians a second) and breathes (turning a little, radians); the
## loose ends wave more toward their tips (band widths; length in band widths) and slowly turn over
## showing their reverse (radians at the tips); arriving, it all moves a little more.
const WIND: Dictionary[String, float] = {
	"sway": 0.25, "sway_length": 0.9, "sway_speed": 0.9,
	"breathe": 0.35, "breathe_speed": 0.7,
	"tail_wave": 0.6, "wave_length": 9.0, "wave_speed": 1.6,
	"turn_most": 2.0, "turn_length": 14.0, "turn_speed": 0.8,
	"flight_wave": 0.3, "flight_turn": 0.35,
}
## Leaving, it drifts on along its way this much of its length while it fades (owner, 2026-11-22:
## drawn right out in the leaving's second it twitched).
const LEAVE_DRIFT: float = 0.35
## The track's samples between two of the path's points.
const SAMPLES: int = 40
## The words: their size against the band, the room between letters (parts of their size), and a
## mask's height against the band.
const TEXT_SIZE: float = 0.56
const TRACKING: float = 0.16
const MASK_TALL: float = 0.62
## The silk's colours: its three steps lit from above, its selvedge, its sheen, its reverse in the
## light (a loose end turned over) and in the shade (behind the lettering), the words and the words'
## shadow.
const SILK: Dictionary[String, String] = {
	"front_light": "a63a2e", "front": "8e2f26", "front_dark": "781f1a", "edge_colour": "6e211a",
	"sheen_colour": "c7614d", "back": "e9cabb", "inner": "5a1915", "text_colour": "f5ead2",
}
const TEXT_SHADOW := Color(0.15, 0.035, 0.03, 0.6)

## The points it runs through, in percent of the ink box (TitleScreenDefinition.Ribbon).
var config: TitleScreenDefinition.Ribbon = TitleScreenDefinition.Ribbon.new()
## The band's width (view pixels), where its seal is stamped, and how low the ribbon reaches at
## rest.
var band: float = 30.0
var seal_at: Vector2 = Vector2.ZERO
var bottom: float = 0.0

var _band_mat: ShaderMaterial
var _text_mat: ShaderMaterial
var _text: Node2D
var _mesh := ArrayMesh.new()
var _words: String = ""
var _mask: Texture2D
var _font: FontVariation
var _font_size: int = 16
## The track: its points, how far along each is, its across direction there (toward the band's
## lower edge), how far in front (1) or behind the lettering (0).
var _track := PackedVector2Array()
var _along := PackedFloat32Array()
var _across := PackedVector2Array()
var _depth := PackedFloat32Array()
## The band: its length, where on the track its trailing tip rests (the way in's length), where it
## is held (between its two loose ends), and where the words' middles sit on it.
var _length: float = 0.0
var _way_in: float = 0.0
var _way_out: float = 0.0
var _held: Vector2 = Vector2.ZERO
var _text_at: Array[float] = []
## How far along the track (0 at rest), how far gone, its speed arriving (eased), and the wind's
## clock.
var _offset: float = 0.0
var _gone: float = 0.0
var _flight: float = 0.0
var _clock: float = 0.0
var _laid: bool = false


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
	for uniform: String in SILK:
		var c := Color(SILK[uniform])
		for mat: ShaderMaterial in [_band_mat, _text_mat]:
			mat.set_shader_parameter(uniform, Vector3(c.r, c.g, c.b))


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
func lay(ink: Rect2, letters: Texture2D, letters_rect: Rect2, view_size: Vector2, _unit: float) -> void:
	band = ink.size.y * config.band / 100.0
	_build_track(ink)
	for mat: ShaderMaterial in [_band_mat, _text_mat]:
		mat.set_shader_parameter("letters", letters)
		mat.set_shader_parameter("letters_rect", Vector4(letters_rect.position.x, letters_rect.position.y, letters_rect.size.x, letters_rect.size.y))
		mat.set_shader_parameter("view_size", view_size)
		mat.set_shader_parameter("band", band)
	_font_size = maxi(8, roundi(band * TEXT_SIZE))
	_laid = true
	_rebuild()


## How far the ribbon has come: `arrived` 0 not yet come → 1 at rest in the lettering,
## `gone` 0 at rest → 1 drifted on and faded away.
func show_part(arrived: float, gone: float) -> void:
	var leaving: float = clampf(gone, 0.0, 1.0)
	var offset: float = lerpf(-(_way_in + _length), 0.0, clampf(arrived, 0.0, 1.0)) + leaving * _length * LEAVE_DRIFT
	if is_equal_approx(offset, _offset) and is_equal_approx(leaving, _gone):
		return
	if _laid and leaving <= 0.0:
		# Arriving fast, the band stirs more; easing toward it, so a frame's jump never jolts it.
		var stir: float = clampf(absf(offset - _offset) / (band * 0.8), 0.0, 1.0)
		_flight = maxf(_flight, lerpf(_flight, stir, 0.3))
	_offset = offset
	_gone = leaving
	for mat: ShaderMaterial in [_band_mat, _text_mat]:
		mat.set_shader_parameter("fade", 1.0 - smoothstep(0.15, 1.0, leaving))
	_rebuild()


## Whether any of the band is on the screen.
func showing() -> bool:
	return _offset > -(_way_in + _length) + 1.0 and _gone < 1.0


func _process(delta: float) -> void:
	_clock += delta
	# The flight's speed, eased, stirs the whole band.
	_flight = maxf(0.0, _flight - delta * 2.5)
	if _laid and showing():
		_rebuild()


func _material(mode: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("mode", mode)
	return mat


## The track: the way in (from `from`, fading in), the path through its points (a Catmull-Rom
## curve), the way out (to `to`, fading out).
func _build_track(ink: Rect2) -> void:
	var tall: float = ink.size.y
	var count: int = config.points()
	var points := PackedVector2Array()
	var fronts := PackedFloat32Array()
	for i: int in count:
		points.append(_in_box(ink, config.path[i * 3], config.path[i * 3 + 1]))
		fronts.append(float(config.path[i * 3 + 2]))
	# The path, SAMPLES a stretch; the band changes sides halfway between two points that differ.
	var path := PackedVector2Array()
	var path_depth := PackedFloat32Array()
	for i: int in count - 1:
		var p0: Vector2 = points[maxi(i - 1, 0)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[mini(i + 2, count - 1)]
		for k: int in SAMPLES:
			var t: float = float(k) / SAMPLES
			path.append(_catmull(p0, p1, p2, p3, t))
			path_depth.append(lerpf(fronts[i], fronts[i + 1], smoothstep(0.38, 0.62, t)))
	path.append(points[count - 1])
	path_depth.append(fronts[count - 1])
	var first_way: Vector2 = (path[1] - path[0]).normalized()
	var last_way: Vector2 = (path[path.size() - 1] - path[path.size() - 2]).normalized()
	var start: Vector2 = path[0]
	var finish: Vector2 = path[path.size() - 1]
	var from: Vector2 = _in_box(ink, config.from[0], config.from[1])
	var to: Vector2 = _in_box(ink, config.to[0], config.to[1])
	var way_in: PackedVector2Array = _bezier(from, from.lerp(start, 0.4), start - first_way * tall * 0.9, start)
	var way_out: PackedVector2Array = _bezier(finish, finish + last_way * tall * 0.9, finish.lerp(to, 0.6), to)
	_track.clear()
	_along.clear()
	_across.clear()
	_depth.clear()
	for point: Vector2 in way_in:
		_add_point(point, path_depth[0])
	_way_in = _along[_along.size() - 1]
	var path_from: int = _track.size() - 1
	for i: int in path.size():
		_add_point(path[i], path_depth[i])
	var path_end: float = _along[_along.size() - 1]
	_length = path_end - _way_in
	for point: Vector2 in way_out:
		_add_point(point, path_depth[path_depth.size() - 1])
	_way_out = _along[_along.size() - 1] - path_end
	# How far along the band each of the path's points lies.
	var on_path: Array[float] = []
	for i: int in count:
		on_path.append(_along[mini(path_from + i * SAMPLES, _along.size() - 1)] - _way_in)
	_held = Vector2(on_path[config.held[0]], on_path[config.held[1]])
	# The across direction: the track's normal, kept on one side all along — the lower side where
	# the path starts, so the words read the right way up at rest.
	var normals := PackedVector2Array()
	normals.resize(_track.size())
	for i: int in _track.size():
		var t: Vector2 = (_track[mini(i + 1, _track.size() - 1)] - _track[maxi(i - 1, 0)]).normalized()
		normals[i] = Vector2(-t.y, t.x)
	if normals[path_from].y < 0.0:
		normals[path_from] = -normals[path_from]
	for i: int in range(path_from + 1, _track.size()):
		if normals[i].dot(normals[i - 1]) < 0.0:
			normals[i] = -normals[i]
	for i: int in range(path_from - 1, -1, -1):
		if normals[i].dot(normals[i + 1]) < 0.0:
			normals[i] = -normals[i]
	_across = normals
	_text_at.clear()
	for point: int in config.text:
		_text_at.append(on_path[point])
	seal_at = _at(_way_in + on_path[config.seal])[0]
	# How low it reaches at rest, with room for the wind.
	bottom = 0.0
	for i: int in _track.size():
		if _along[i] >= _way_in and _along[i] <= path_end:
			bottom = maxf(bottom, _track[i].y + band * (0.5 + WIND["sway"] + WIND["tail_wave"]))


static func _in_box(ink: Rect2, x: float, y: float) -> Vector2:
	return ink.position + Vector2(ink.size.x * x / 100.0, ink.size.y * y / 100.0)


func _add_point(point: Vector2, depth: float) -> void:
	if not _track.is_empty() and point.distance_to(_track[_track.size() - 1]) < 0.01:
		return
	_along.append(0.0 if _track.is_empty() else _along[_along.size() - 1] + point.distance_to(_track[_track.size() - 1]))
	_track.append(point)
	_depth.append(depth)


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


static func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps: int = 60
	for i: int in steps + 1:
		var t: float = float(i) / steps
		var u: float = 1.0 - t
		points.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
	return points


## The track at `distance` along it: [point, direction, across, depth, shows].
func _at(distance: float) -> Array:
	var end: float = _along[_along.size() - 1]
	var d: float = clampf(distance, 0.0, end)
	var i: int = clampi(_along.bsearch(d) - 1, 0, _track.size() - 2)
	var span: float = maxf(0.0001, _along[i + 1] - _along[i])
	var k: float = clampf((d - _along[i]) / span, 0.0, 1.0)
	var direction: Vector2 = (_track[i + 1] - _track[i]).normalized()
	# Fading in along the way in's first half, out along the way out's second half; gone past
	# either end.
	var shows: float = smoothstep(0.0, _way_in * 0.55, distance) * (1.0 - smoothstep(end - _way_out * 0.55, end, distance))
	return [_track[i].lerp(_track[i + 1], k), direction, _across[i].slerp(_across[i + 1], k), lerpf(_depth[i], _depth[i + 1], k), shows]


## How loose the band is at `s` along it: 0 held, rising to 1 at either tip.
func _loose(s: float) -> float:
	if s < _held.x:
		return clampf((_held.x - s) / maxf(1.0, _held.x), 0.0, 1.0)
	if s > _held.y:
		return clampf((s - _held.y) / maxf(1.0, _length - _held.y), 0.0, 1.0)
	return 0.0


## The band at `s` along it now: [middle, direction, across (its length the half-width, turned over
## when the reverse shows), depth, face showing, shows].
func _pose(s: float) -> Array:
	var place: Array = _at(_way_in + s + _offset)
	var loose: float = _loose(s)
	var t: float = _clock
	# The whole band sways in two slow waves; the loose ends' own waves run out from the middle
	# toward both tips.
	var sway_length: float = maxf(band, WIND["sway_length"] * _length)
	var sway: float = WIND["sway"] * (0.7 * sin(TAU * s / sway_length - WIND["sway_speed"] * t) + 0.3 * sin(TAU * s / (0.37 * sway_length) + 0.8 * WIND["sway_speed"] * t + 1.7))
	var from_middle: float = absf(s - (_held.x + _held.y) / 2.0) / band
	var tail: float = (WIND["tail_wave"] * pow(loose, 1.4) + WIND["flight_wave"] * _flight) * sin(TAU * from_middle / WIND["wave_length"] - WIND["wave_speed"] * t)
	var turn: float = (WIND["turn_most"] * pow(loose, 1.2) + WIND["flight_turn"] * _flight) * sin(TAU * from_middle / WIND["turn_length"] - WIND["turn_speed"] * t + 1.3)
	turn += WIND["breathe"] * sin(TAU * s / maxf(band, 0.5 * _length) - WIND["breathe_speed"] * t + 0.6)
	var across: Vector2 = place[2]
	var middle: Vector2 = (place[0] as Vector2) + across * band * (sway + tail)
	var width: float = cos(turn)
	var face: float = 1.0 if width >= 0.0 else 0.0
	return [middle, place[1], across * (band / 2.0) * width, place[3], face, place[4]]


## The mesh for now: the band's columns, those behind the lettering first, then the shadows of
## those in front, then those in front.
func _rebuild() -> void:
	if _track.size() < 2:
		return
	var step: float = band * COLUMN_STEP
	var count: int = maxi(2, ceili(_length / step) + 1)
	var columns: Array[Array] = []
	for c: int in count:
		var s: float = minf(_length, c * step)
		columns.append(_pose(s))
	# Three layers, each [vertices, colours, uvs] (packed arrays are values: kept in one Array
	# and appended to through it).
	var behind: Array = [PackedVector2Array(), PackedColorArray(), PackedVector2Array()]
	var shadow: Array = [PackedVector2Array(), PackedColorArray(), PackedVector2Array()]
	var front: Array = [PackedVector2Array(), PackedColorArray(), PackedVector2Array()]
	var drop := Vector2(0.0, band * 0.16)
	for c: int in count - 1:
		var a: Array = columns[c]
		var b: Array = columns[c + 1]
		if float(a[5]) <= 0.001 and float(b[5]) <= 0.001:
			continue
		var depth: float = (float(a[3]) + float(b[3])) / 2.0
		var target: Array = front if depth >= 0.5 else behind
		var notch_a: float = NOTCH if c == 0 else 0.0
		var notch_b: float = NOTCH if c == count - 2 else 0.0
		_segment(target, a, b, notch_a, notch_b, Vector2.ZERO, false)
		if depth >= 0.3:
			# Its shadow fades in as it comes out in front (no step where it changes sides).
			_segment(shadow, a, b, notch_a, notch_b, drop, true)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector2Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	for part: Array in [behind, shadow, front]:
		vertices.append_array(part[0])
		colours.append_array(part[1])
		uvs.append_array(part[2])
	_mesh.clear_surfaces()
	if not vertices.is_empty():
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colours
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	queue_redraw()
	_text.queue_redraw()


## One stretch of band between two columns, as three points across each (upper edge, middle, lower
## edge); a tip's middle point pulled back into a swallowtail notch.
func _segment(target: Array, a: Array, b: Array, notch_a: float, notch_b: float, drop: Vector2, is_shadow: bool) -> void:
	var rows: Array[PackedVector2Array] = []
	for pose: Array in [a, b]:
		var m: Vector2 = (pose[0] as Vector2) + drop
		var across: Vector2 = pose[2]
		rows.append(PackedVector2Array([m - across, m, m + across]))
	rows[0][1] += (a[1] as Vector2) * band * notch_a
	rows[1][1] -= (b[1] as Vector2) * band * notch_b
	var colour_a := Color(float(a[4]), float(a[3]), 1.0 if is_shadow else 0.0, float(a[5]) * (smoothstep(0.3, 0.8, float(a[3])) if is_shadow else 1.0))
	var colour_b := Color(float(b[4]), float(b[3]), 1.0 if is_shadow else 0.0, float(b[5]) * (smoothstep(0.3, 0.8, float(b[3])) if is_shadow else 1.0))
	var vs: Array[float] = [0.0, 0.5, 1.0]
	for r: int in 2:
		var t0: Vector2 = rows[0][r]
		var t1: Vector2 = rows[1][r]
		var b0: Vector2 = rows[0][r + 1]
		var b1: Vector2 = rows[1][r + 1]
		var v: PackedVector2Array = target[0]
		v.append_array([t0, t1, b1, t0, b1, b0])
		target[0] = v
		var c: PackedColorArray = target[1]
		c.append_array([colour_a, colour_b, colour_b, colour_a, colour_b, colour_a])
		target[1] = c
		var u: PackedVector2Array = target[2]
		u.append_array([Vector2(0, vs[r]), Vector2(1, vs[r]), Vector2(1, vs[r + 1]), Vector2(0, vs[r]), Vector2(1, vs[r + 1]), Vector2(0, vs[r + 1])])
		target[2] = u


func _draw() -> void:
	if _mesh.get_surface_count() > 0:
		draw_mesh(_mesh, null)


## The words where the band runs in front, riding it (each letter, or each slice of the mask, on
## the band where it is now, upright to it): the whole line on one point, or a word on each of the
## Ribbon's text points when there are as many words; hidden where the band shows its reverse or
## runs behind.
func _draw_words() -> void:
	if not _laid or _text_at.is_empty() or (_words.is_empty() and _mask == null):
		return
	if _mask != null:
		# The mask is padded (TitleLogo.MASK_PAD): its ink is MASK_TALL of the band.
		var ink_share: float = (_mask.get_height() - 2.0 * TitleLogo.MASK_PAD) / _mask.get_height()
		var tall: float = band * MASK_TALL / ink_share
		var wide: float = tall * _mask.get_width() / _mask.get_height()
		var slices: int = 28
		var slice: float = wide / slices
		var source_slice: float = float(_mask.get_width()) / slices
		for i: int in slices:
			var s: float = _text_at[0] - wide / 2.0 + (i + 0.5) * slice
			var shown: float = _word_shown(s)
			if shown <= 0.0:
				continue
			_put(_pose(s))
			_text.draw_texture_rect_region(_mask, Rect2(-slice / 2.0 - 0.5, -tall / 2.0, slice + 1.0, tall), Rect2(i * source_slice, 0.0, source_slice, _mask.get_height()), Color(1, 1, 1, shown))
		_text.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var parts: PackedStringArray = _words.split(" ", false)
	if parts.size() != _text_at.size():
		parts = PackedStringArray([_words])
	for p: int in parts.size():
		_draw_run(parts[p], _text_at[p])
	_text.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## One run of letters centred `middle` along the band.
func _draw_run(run: String, middle: float) -> void:
	var space: float = _font_size * TRACKING
	var widths: Array[float] = []
	var total: float = 0.0
	for i: int in run.length():
		var w: float = _font.get_char_size(run.unicode_at(i), _font_size).x
		widths.append(w)
		total += w + (space if i < run.length() - 1 else 0.0)
	var at: float = middle - total / 2.0
	# Capitals sit centred on the band: half their height under the middle.
	var drop: float = _font.get_ascent(_font_size) * 0.36
	var colour := Color(SILK["text_colour"])
	for i: int in run.length():
		var s: float = at + widths[i] / 2.0
		at += widths[i] + space
		var shown: float = _word_shown(s)
		if shown <= 0.0:
			continue
		_put(_pose(s))
		var glyph := Vector2(-widths[i] / 2.0, drop)
		_text.draw_char(_font, glyph + Vector2(0.0, maxf(1.0, band * 0.03)), run[i], _font_size, Color(TEXT_SHADOW, TEXT_SHADOW.a * shown))
		_text.draw_char(_font, glyph, run[i], _font_size, Color(colour, shown))


## How much of a word at `s` along the band shows: its outer face toward us, in front.
func _word_shown(s: float) -> float:
	var pose: Array = _pose(s)
	return smoothstep(0.5, 0.9, float(pose[3])) * smoothstep(0.5, 0.9, float(pose[4])) * float(pose[5])


## Sets the words' frame to the band at `pose`: along it, and across it (squashed as it turns).
func _put(pose: Array) -> void:
	var along: Vector2 = pose[1]
	var across: Vector2 = (pose[2] as Vector2) / (band / 2.0)
	_text.draw_set_transform_matrix(Transform2D(along, across, pose[0]))
