class_name VoxelLoader
extends Control

## The waiting animation in the maps' own look (owner, 2026-11-07: 符合体素的风格): little
## cubes drop in one after another and build a small shape on its shadow, stand a moment,
## then rise and fade, and it begins again. What it builds, in what colours, how big and how
## quickly is LoadingScreenDefinition's `voxel` (data/common/loading_screen.json). Drawn in
## flat faces (a light top, a mid left, a dark right), no texture. It follows the clock: a long
## frame skips ahead, never slows it. The map's loading screen, the shell's waits and the
## title's white while a journey starts all show it.

## Shares of a round: the cubes drop in during BUILD, the shape stands until HOLD, then rises
## away until the round ends.
const BUILD_SHARE: float = 0.55
const HOLD_SHARE: float = 0.8
## How long one cube takes to fall into place (share of a round), and from how high (cubes).
const DROP_SHARE: float = 0.14
const DROP_CUBES: float = 3.0
## How far the shadow reaches past the base's cubes' centres, in cubes (0.5 is their edge).
const SHADOW_PAD: float = 0.7

var _cubes: Array[Vector3i] = []
var _colours: Array[Color] = []
## A cube's half width; its top face is half as tall, its sides as tall as that half width.
var _half: float = 10.0
var _cycle_ms: int = 2400
var _began_ms: int = 0
## The drawing order (back to front) as indices into _cubes.
var _order: Array[int] = []
## Where the grid's origin stands inside the control, so the shape is centred.
var _origin: Vector2 = Vector2.ZERO


func _init(definition: LoadingScreenDefinition = null) -> void:
	name = "VoxelLoader"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if definition == null:
		definition = GameContent.catalog().loading_screen()
	if definition == null:
		definition = LoadingScreenDefinition.new()
	_cubes = definition.voxel_cubes.duplicate()
	_colours = definition.voxel_colours.duplicate()
	_half = float(definition.voxel_cube_px)
	_cycle_ms = definition.voxel_cycle_ms
	_measure()
	restart()


## Whether there is anything to build.
func has_cubes() -> bool:
	return not _cubes.is_empty()


## From the first cube again.
func restart() -> void:
	_began_ms = Time.get_ticks_msec()
	queue_redraw()


## Where in its round it stands (0..1).
func phase() -> float:
	return fposmod(float(Time.get_ticks_msec() - _began_ms) / float(_cycle_ms), 1.0)


func _process(_delta: float) -> void:
	if is_visible_in_tree() and modulate.a > 0.0:
		queue_redraw()


## Screen position of a cube's top-face centre at grid `at`, before any drop.
func _top_of(at: Vector3i) -> Vector2:
	return Vector2(float(at.x - at.y) * _half, float(at.x + at.y) * _half / 2.0 - float(at.z) * _half)


## Screen position of grid point `at` on the floor the base stands on.
func _floor_of(at: Vector2) -> Vector2:
	return Vector2((at.x - at.y) * _half, (at.x + at.y) * _half / 2.0 + _half)


## Its size and the drawing order (the drop and the rise share the room above the shape).
func _measure() -> void:
	_order.clear()
	if _cubes.is_empty():
		custom_minimum_size = Vector2.ZERO
		return
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for index: int in _cubes.size():
		_order.append(index)
		var top: Vector2 = _top_of(_cubes[index])
		low = low.min(top + Vector2(-_half, -_half / 2.0))
		high = high.max(top + Vector2(_half, _half * 1.5))
		if _cubes[index].z == 0:
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var floor_point: Vector2 = _floor_of(Vector2(_cubes[index].x, _cubes[index].y) + corner * SHADOW_PAD)
				low = low.min(floor_point)
				high = high.max(floor_point)
	# Further back (smaller x + y) first, lower first.
	_order.sort_custom(func(a: int, b: int) -> bool:
		var ca: Vector3i = _cubes[a]
		var cb: Vector3i = _cubes[b]
		if ca.x + ca.y != cb.x + cb.y:
			return ca.x + ca.y < cb.x + cb.y
		if ca.z != cb.z:
			return ca.z < cb.z
		return ca.x < cb.x)
	var drop: float = DROP_CUBES * _half
	custom_minimum_size = (high - low + Vector2(0.0, drop)).ceil()
	_origin = Vector2(-low.x, -low.y + drop)


## How far cube `rank` (in the order it drops in) has come at `t` (0..1 of a round):
## [height above its place in pixels, alpha].
func _cube_state(rank: int, t: float) -> Vector2:
	var count: int = _cubes.size()
	var start: float = BUILD_SHARE * float(rank) / float(maxi(count, 1)) * (1.0 - DROP_SHARE / BUILD_SHARE)
	var landed: float = clampf((t - start) / DROP_SHARE, 0.0, 1.0)
	if t < start:
		return Vector2(0.0, 0.0)
	var height: float = 0.0
	var alpha: float = 1.0
	if landed < 1.0:
		# Ease out with a small bounce at the end.
		var fall: float = 1.0 - pow(1.0 - landed, 3.0)
		height = DROP_CUBES * _half * (1.0 - fall)
		alpha = clampf(landed * 3.0, 0.0, 1.0)
	if t > HOLD_SHARE:
		var away: float = (t - HOLD_SHARE) / (1.0 - HOLD_SHARE)
		# The last to come is the first to go.
		var stagger: float = clampf(away * 1.6 - 0.6 * float(count - 1 - rank) / float(maxi(count - 1, 1)), 0.0, 1.0)
		height += stagger * stagger * DROP_CUBES * _half
		alpha *= 1.0 - stagger
	return Vector2(height, alpha)


func _draw() -> void:
	if _cubes.is_empty():
		return
	var t: float = phase()
	var centre: Vector2 = ((size - custom_minimum_size) / 2.0).floor() + _origin
	# The shadow the shape stands on, darker as more of it has come.
	var settled: float = 0.0
	for rank: int in _cubes.size():
		settled += _cube_state(rank, t).y
	settled /= float(_cubes.size())
	var ground: PackedVector2Array = []
	var base_low: Vector2i = Vector2i(1 << 20, 1 << 20)
	var base_high: Vector2i = Vector2i(-(1 << 20), -(1 << 20))
	for at: Vector3i in _cubes:
		if at.z == 0:
			base_low = base_low.min(Vector2i(at.x, at.y))
			base_high = base_high.max(Vector2i(at.x, at.y))
	if base_low.x <= base_high.x:
		var pad: float = SHADOW_PAD
		for corner: Vector2 in [Vector2(base_low.x - pad, base_low.y - pad), Vector2(base_high.x + pad, base_low.y - pad), Vector2(base_high.x + pad, base_high.y + pad), Vector2(base_low.x - pad, base_high.y + pad)]:
			ground.append((centre + _floor_of(corner)).round())
		draw_colored_polygon(ground, Color(0.0, 0.0, 0.0, 0.28 * settled))
	for index: int in _order:
		var state: Vector2 = _cube_state(index, t)
		if state.y <= 0.0:
			continue
		var top: Vector2 = (centre + _top_of(_cubes[index]) - Vector2(0.0, state.x)).round()
		_draw_cube(top, _colours[index], state.y)


## One cube, its top face centred on `top`.
func _draw_cube(top: Vector2, colour: Color, alpha: float) -> void:
	var h: float = _half
	var up := top + Vector2(0.0, -h / 2.0)
	var right := top + Vector2(h, 0.0)
	var front := top + Vector2(0.0, h / 2.0)
	var left := top + Vector2(-h, 0.0)
	var down := Vector2(0.0, h)
	var lit: Color = colour.lightened(0.18)
	var dark: Color = colour.darkened(0.3)
	lit.a = alpha
	dark.a = alpha
	var mid: Color = colour
	mid.a = alpha
	draw_colored_polygon(PackedVector2Array([left, front, front + down, left + down]), mid)
	draw_colored_polygon(PackedVector2Array([front, right, right + down, front + down]), dark)
	draw_colored_polygon(PackedVector2Array([up, right, front, left]), lit)
	# A worn top edge: one light line along its back.
	var rim: Color = colour.lightened(0.38)
	rim.a = alpha * 0.8
	draw_line(left, up, rim, 1.0)
	draw_line(up, right, rim, 1.0)
