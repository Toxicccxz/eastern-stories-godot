class_name BattleModeTitle
extends Control

## 战斗拍数 E (DECISIONS「战斗拍数 E · 重招」), owner 2026-11-09「那个死斗/切磋字样太难看了，没有体素的风格」:
## the mode's word at the top of the battle screen built of blocks — each pixel of the game's
## pixel face (GameTheme.PIXEL_FONT_PATH, at its own 12-pixel grid) one block, worn a shade here
## and there, laid over a broad ragged brush stroke of blocks in the mode's ground (切磋 jade,
## 死斗 soot, 拆招 dark gold) — the title screen's logo in small. Drawn in a world of its own,
## lit from the upper left, swaying a little; the blocks drop into place column by column when
## the word changes. The glyphs come straight from the font's outlines (TextServer contours,
## sampled at each pixel's middle), so any language's word builds and nothing is rendered to
## make them; a word the face has no glyph for draws nothing and the Label under it shows
## instead (BattlePresentationController keeps the Label's text for hover and the suites).
## Presentation only.

## The pixel face's own grid: one font pixel, one block.
const GLYPH_SIZE: int = 12
const LETTER_DEPTH: float = 2.2
const STROKE_DEPTH: float = 0.6
## Blocks round the word (the stroke runs past it; the sway needs room).
const MARGIN: Vector2 = Vector2(5.0, 3.0)
const FOV: float = 18.0
const DROP_SECONDS: float = 0.42
const DROP_HEIGHT: float = 7.0

## The colours of each mode's word: [face, flecks, stroke]; by CombatEncounterMode.Value.
const LOOKS: Dictionary[int, Array] = {
	CombatEncounterMode.Value.SPAR: [Color("efe2c0"), Color("a8d0b8"), Color("2c5a4a")],
	CombatEncounterMode.Value.LESSON: [Color("f2cf72"), Color("fff0b8"), Color("6a4a14")],
	CombatEncounterMode.Value.LETHAL: [Color("e04a2c"), Color("ffa040"), Color("6a1a12")],
	CombatEncounterMode.Value.SCRIPTED: [Color("f1e4c6"), Color("e9b84c"), Color("6b1c12")],
}

## The masks built in a run, by text.
static var _masks: Dictionary[String, Array] = {}

var text: String = ""
var mode: int = -1
var clock: float = 0.0
var _view: SubViewport
var _camera: Camera3D
var _board: Node3D
var _letters: MultiMeshInstance3D
var _stroke: MultiMeshInstance3D
## Each letter block's resting place (the drop moves them from above it).
var _rest: Array[Vector3] = []
var _span: Vector2 = Vector2.ONE
var _drop: float = 1.0


func _init() -> void:
	name = "VoxelModeTitle"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_view = SubViewport.new()
	_view.name = "TitleView"
	_view.transparent_bg = true
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view.size = Vector2i(64, 32)
	add_child(_view)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8a7c6c")
	environment.ambient_light_energy = 0.45
	var world := WorldEnvironment.new()
	world.environment = environment
	_view.add_child(world)
	for light: Array in [[Vector3(-50, -38, 0), Color("fff0d8"), 1.3], [Vector3(15, 160, 0), Color("ffb070"), 0.35]]:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = light[0]
		sun.light_color = light[1]
		sun.light_energy = light[2]
		_view.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = FOV
	_view.add_child(_camera)
	_board = Node3D.new()
	_board.name = "Board"
	_view.add_child(_board)
	_letters = _instance("Letters")
	_stroke = _instance("Stroke")
	resized.connect(_fit)
	visibility_changed.connect(_fit)


## The word `p_text` in `p_mode`'s look (CombatEncounterMode.Value); false when the face draws
## none of it (the Label shows then). The blocks drop in when the word or the look changed.
func present(p_text: String, p_mode: int) -> bool:
	if p_text == text and p_mode == mode:
		return not _rest.is_empty()
	text = p_text
	mode = p_mode
	var mask: Array = mask_of(text)
	_rest.clear()
	if mask.is_empty() or (mask[0] as PackedByteArray).is_empty():
		_letters.multimesh = null
		_stroke.multimesh = null
		_fit()
		return false
	_build(mask, LOOKS.get(mode, LOOKS[CombatEncounterMode.Value.LETHAL]))
	_drop = 0.0
	set_process(true)
	_fit()
	return true


## Whether a word stands built (tests).
func built() -> bool:
	return not _rest.is_empty()


## The blocks of the word now (tests).
func block_count() -> int:
	return _rest.size()


## The word as rows of ink (1) and paper (0), one per font pixel; empty when the face has no
## glyph for one of its characters. Sampled from the glyphs' outlines at each pixel's middle
## (even-odd), the pixel face's outlines being its pixels' edges.
static func mask_of(word: String) -> Array:
	if _masks.has(word):
		return _masks[word]
	var rows: Array = []
	var font := load(GameTheme.PIXEL_FONT_PATH) as FontFile
	var server: TextServer = TextServerManager.get_primary_interface()
	if font == null or server == null or word.strip_edges().is_empty():
		_masks[word] = rows
		return rows
	var rid: RID = font.get_rids()[0]
	var ascent: int = ceili(server.font_get_ascent(rid, GLYPH_SIZE))
	var descent: int = ceili(server.font_get_descent(rid, GLYPH_SIZE))
	var height: int = ascent + descent
	var glyphs: Array = []
	var width: int = 0
	for index: int in word.length():
		var code: int = word.unicode_at(index)
		var glyph: int = server.font_get_glyph_index(rid, GLYPH_SIZE, code, 0)
		if glyph == 0 and code != 32:
			_masks[word] = rows
			return rows
		var advance: int = roundi(server.font_get_glyph_advance(rid, GLYPH_SIZE, glyph).x)
		glyphs.append([width, server.font_get_glyph_contours(rid, GLYPH_SIZE, glyph)])
		width += advance
	# One flat grid while drawing (a PackedByteArray taken out of an Array is a copy).
	var grid := PackedByteArray()
	grid.resize(width * height)
	for entry: Array in glyphs:
		var left: int = entry[0]
		var contours: Dictionary = entry[1]
		var points: PackedVector3Array = contours.get("points", PackedVector3Array())
		var ends: PackedInt32Array = contours.get("contours", PackedInt32Array())
		if points.is_empty():
			continue
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for point: Vector3 in points:
			low = low.min(Vector2(point.x, point.y))
			high = high.max(Vector2(point.x, point.y))
		for py: int in range(floori(low.y), ceili(high.y)):
			for px: int in range(floori(low.x), ceili(high.x)):
				if _inside(Vector2(px + 0.5, py + 0.5), points, ends):
					var x: int = left + px
					var y: int = py + ascent
					if x >= 0 and x < width and y >= 0 and y < height:
						grid[y * width + x] = 1
	for y: int in height:
		rows.append(grid.slice(y * width, (y + 1) * width))
	# Cropped to the ink, top and bottom.
	var top: int = 0
	while top < rows.size() and not (rows[top] as PackedByteArray).has(1):
		top += 1
	var bottom: int = rows.size()
	while bottom > top and not (rows[bottom - 1] as PackedByteArray).has(1):
		bottom -= 1
	rows = rows.slice(top, bottom)
	_masks[word] = rows
	return rows


## Even-odd: whether `at` lies inside the outlines (`ends`: each contour's last point).
static func _inside(at: Vector2, points: PackedVector3Array, ends: PackedInt32Array) -> bool:
	var inside: bool = false
	var start: int = 0
	for end: int in ends:
		var previous: int = end
		for index: int in range(start, end + 1):
			var a := Vector2(points[index].x, points[index].y)
			var b := Vector2(points[previous].x, points[previous].y)
			if (a.y > at.y) != (b.y > at.y) and at.x < (b.x - a.x) * (at.y - a.y) / (b.y - a.y) + a.x:
				inside = not inside
			previous = index
		start = end + 1
	return inside


func _build(mask: Array, colours: Array) -> void:
	var height: int = mask.size()
	var width: int = (mask[0] as PackedByteArray).size()
	_span = Vector2(width, height) + MARGIN * 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text) + mode
	var face: Color = colours[0]
	var fleck: Color = colours[1]
	var ground: Color = colours[2]
	# The letters: one block a pixel, worn a shade each, a few flecks of the mode's second colour.
	var letters: Array[Array] = []
	for y: int in height:
		var row: PackedByteArray = mask[y]
		for x: int in width:
			if row[x] == 0:
				continue
			var colour: Color = face
			var roll: float = rng.randf()
			if roll < 0.12:
				colour = fleck
			elif roll < 0.45:
				colour = face.darkened(rng.randf_range(0.04, 0.16))
			# The pixel's top edge open to the light reads as the stroke's lit rim.
			if y == 0 or (mask[y - 1] as PackedByteArray)[x] == 0:
				colour = colour.lightened(0.1)
			letters.append([Vector3(float(x) + 0.5 - width / 2.0, float(height) / 2.0 - float(y) - 0.5, 0.0), Vector3(1.0, 1.0, LETTER_DEPTH), colour])
	_rest.clear()
	for block: Array in letters:
		_rest.append(block[0])
	_letters.multimesh = _multi(letters)
	# The brush stroke behind: a broad band, swelling in the middle, its ends tapering and broken
	# into dry-brush streaks, laid a little aslant.
	var stroke: Array[Array] = []
	var reach: float = float(width) / 2.0 + MARGIN.x - 0.5
	var half: float = float(height) * 0.36
	var x: float = -reach
	while x <= reach:
		var along: float = (x + reach) / (2.0 * reach)
		var swell: float = sin(along * PI) * 0.65 + 0.35
		var middle: float = (along - 0.5) * 1.6 - float(height) * 0.06
		var top: float = middle + half * swell + rng.randf_range(-0.6, 0.6)
		var foot: float = middle - half * swell + rng.randf_range(-0.6, 0.6)
		var y: float = foot
		while y <= top:
			var dry: bool = (along > 0.82 and rng.randf() < (along - 0.82) * 4.0) or (along < 0.05 and rng.randf() < 0.4)
			if not dry:
				var shade: Color = ground.lightened(rng.randf_range(0.0, 0.06)) if rng.randf() < 0.3 else ground.darkened(rng.randf_range(0.0, 0.08))
				stroke.append([Vector3(x, y, -LETTER_DEPTH / 2.0 - STROKE_DEPTH / 2.0 - 0.1), Vector3(1.0, 1.0, STROKE_DEPTH), shade])
			y += 1.0
		x += 1.0
	_stroke.multimesh = _multi(stroke)


func _multi(blocks: Array[Array]) -> MultiMesh:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.9
	box.material = material
	multi.mesh = box
	multi.instance_count = blocks.size()
	for index: int in blocks.size():
		var block: Array = blocks[index]
		multi.set_instance_transform(index, Transform3D(Basis().scaled(block[1]), block[0]))
		multi.set_instance_color(index, block[2])
	return multi


func _instance(node_name: String) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_board.add_child(instance)
	return instance


## The picture as tall as this control, as wide as the word wants, centred; the view at whole
## screen pixels; drawn only while shown.
func _fit() -> void:
	var drawn: Rect2 = _drawn()
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() and built() else SubViewport.UPDATE_DISABLED
	if not drawn.has_area():
		queue_redraw()
		return
	var screen_scale: float = get_viewport().get_final_transform().get_scale().x if is_inside_tree() else 1.0
	var pixels := Vector2i((drawn.size * screen_scale).round()).max(Vector2i(8, 8))
	if _view.size != pixels:
		_view.size = pixels
	# The camera frames the word and its margins at the view's aspect.
	var distance: float = (_span.y / 2.0) / tan(deg_to_rad(FOV) / 2.0)
	_camera.position = Vector3(0.0, 0.0, distance)
	queue_redraw()


func _drawn() -> Rect2:
	if not built() or size.y <= 0.0:
		return Rect2()
	var tall: float = size.y * 1.55
	var wide: float = tall * _span.x / _span.y
	return Rect2(Vector2((size.x - wide) / 2.0, (size.y - tall) / 2.0), Vector2(wide, tall))


func _draw() -> void:
	var drawn: Rect2 = _drawn()
	if drawn.has_area():
		draw_texture_rect(_view.get_texture(), drawn, false)


func _process(delta: float) -> void:
	if not built():
		set_process(false)
		return
	clock += delta
	_board.rotation_degrees = Vector3(17.0 + sin(clock * 0.6) * 1.5, -11.0 + sin(clock * 0.45) * 4.0, sin(clock * 0.5) * 0.6)
	if _drop < 1.0:
		_drop = minf(1.0, _drop + delta / DROP_SECONDS)
		_place_letters()


## The drop: each column falls from above in turn, left to right, and lands with a small bounce.
func _place_letters() -> void:
	var multi: MultiMesh = _letters.multimesh
	if multi == null:
		return
	var left: float = -_span.x / 2.0
	for index: int in _rest.size():
		var rest: Vector3 = _rest[index]
		var start: float = (rest.x - left) / _span.x * 0.55
		var share: float = clampf((_drop - start) / 0.45, 0.0, 1.0)
		var lift: float = (1.0 - ease(share, 0.4)) * DROP_HEIGHT
		var basis := Basis().scaled(Vector3(1.0, 1.0, LETTER_DEPTH))
		multi.set_instance_transform(index, Transform3D(basis, rest + Vector3(0.0, lift, 0.0)))
	_letters.visible = true
