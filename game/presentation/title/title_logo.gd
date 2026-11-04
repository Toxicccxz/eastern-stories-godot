class_name TitleLogo
extends Control

## The title's logo (DECISIONS「标题画面」): the brush characters (东方故事, or Eastern Stories —
## one language at a time) built from voxels in a 3D view of their own, each stroke thicker in
## its middle, ink with a few flecks of gold, a vermilion seal (侠; a cut knot where the
## language has no seal) and behind it all a broad vermilion brush stroke. TitleScreen tweens:
##   write  0 → 1   the stroke is laid and the characters written, left to right
##   glint          a band of gold light passing over the strokes
##   charge         the light gathering in them before they burn
##   burn  -0.2 → 1.15  a ragged burning front crossing left to right: ahead of it the ink
##                  glows, behind it the blocks crumble into embers that swirl toward the
##                  viewer; one block in twenty lifts off as a smouldering flake.
## The masks are baked (tools/ui/bake_title_logo.gd); the built blocks are kept per mask.

const LOGO: Shader = preload("res://presentation/title/shaders/title_logo.gdshader")
const EMBERS: Shader = preload("res://presentation/title/shaders/title_embers.gdshader")
const CAMERA_DISTANCE: float = 400.0
const FOV: float = 26.0
## The blocks of one logo, built once per mask and seal in a run.
static var _built: Dictionary = {}

var write: float = 0.0
var burn: float = -0.2
var charge: float = 0.0
var glint: float = -9999.0
var clock: float = 0.0
## Where the logo's middle stands (parts of the screen) and how wide it is (UI pixels).
var at: Vector2 = Vector2(0.28, 0.21)
var width_px: float = 580.0

var _view: SubViewport
var _camera: Camera3D
var _board: Node3D
var _logo_mat: ShaderMaterial
var _ember_mat: ShaderMaterial
var _span: float = 300.0
var _unit: float = 1.0


func _init() -> void:
	name = "TitleLogo"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_view = SubViewport.new()
	_view.name = "LogoView"
	_view.transparent_bg = true
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(_view)
	var shown := TextureRect.new()
	shown.name = "Shown"
	shown.texture = _view.get_texture()
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.set_anchors_preset(Control.PRESET_FULL_RECT)
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var premul := CanvasItemMaterial.new()
	premul.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	shown.material = premul
	add_child(shown)
	_world()


## Builds the logo from `mask_path` (white = ink) and `seal_path` ("" for the cut knot).
func build(mask_path: String, seal_path: String) -> void:
	var parts: Dictionary = parts_for(mask_path, seal_path)
	_span = parts["span"]
	_logo_mat = ShaderMaterial.new()
	_logo_mat.shader = LOGO
	_ember_mat = ShaderMaterial.new()
	_ember_mat.shader = EMBERS
	for child: Node in _board.get_children():
		child.queue_free()
	_board.add_child(_instance("Ink", parts["ink"], _logo_mat))
	_board.add_child(_instance("Embers", parts["embers"], _ember_mat))
	_place()


## The logo's parts for a mask and seal, built once in a run: "ink" and "embers" (MultiMeshes),
## "span" (its width in voxels), "cubes" ([position, colour, in the stroke] per block).
static func parts_for(mask_path: String, seal_path: String) -> Dictionary:
	var key: String = mask_path + "|" + seal_path
	if not _built.has(key):
		_built[key] = _blocks(_ink(mask_path), _ink(seal_path))
	return _built[key]


func texture() -> Texture2D:
	return _view.get_texture()


func _ready() -> void:
	get_viewport().size_changed.connect(_place)
	_place()


func _process(delta: float) -> void:
	clock += delta
	if _logo_mat == null:
		return
	_board.rotation_degrees = Vector3(15.0 + sin(clock * 0.5) * 2.0, -15.0 + sin(clock * 0.37) * 5.0, sin(clock * 0.42) * 0.8)
	for mat: ShaderMaterial in [_logo_mat, _ember_mat]:
		mat.set_shader_parameter("burn", burn)
	_logo_mat.set_shader_parameter("write", write)
	_logo_mat.set_shader_parameter("charge", charge)
	_logo_mat.set_shader_parameter("glint", glint)


## The glint's path across the logo, in world units: from its left (0) to its right (1).
func glint_at(part: float) -> float:
	return _board.position.x + (part - 0.5) * _span * _unit * 1.3


func _world() -> void:
	var world := Node3D.new()
	world.name = "World"
	_view.add_child(world)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8d97ad")
	environment.ambient_light_energy = 0.55
	env.environment = environment
	world.add_child(env)
	# The sun is behind the logo: rims and tops catch it; a key light from the front shows the
	# strokes' relief, a cool fill keeps their shade from going flat.
	for light: Array in [[Vector3(-30, 160, 0), Color("ffd59a"), 2.2, false], [Vector3(-52, -20, 0), Color("fff1dc"), 0.9, true], [Vector3(10, 30, 0), Color("9fb4d8"), 0.35, false]]:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = light[0]
		sun.light_color = light[1]
		sun.light_energy = light[2]
		sun.shadow_enabled = light[3]
		world.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.position = Vector3(0, 0, CAMERA_DISTANCE)
	world.add_child(_camera)
	_board = Node3D.new()
	_board.name = "Board"
	world.add_child(_board)


## The view follows the window; the logo stands at `at`, `width_px` wide.
func _place() -> void:
	if not is_inside_tree():
		return
	var window: Vector2i = get_tree().root.size.max(Vector2i(64, 64))
	_view.size = window
	var screen := Vector2(window)
	var world_width: float = 2.0 * CAMERA_DISTANCE * tan(deg_to_rad(FOV) / 2.0) * screen.x / screen.y
	_unit = world_width * (width_px / 1280.0) / _span
	_board.scale = Vector3.ONE * _unit
	_board.position = _camera.project_position(at * screen, CAMERA_DISTANCE)
	if _logo_mat != null:
		var toward: Vector3 = (_camera.position - _board.position).normalized()
		for mat: ShaderMaterial in [_logo_mat, _ember_mat]:
			mat.set_shader_parameter("unit", _unit)
			mat.set_shader_parameter("toward", toward)


static func _instance(node_name: String, multimesh: MultiMesh, material: ShaderMaterial) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.custom_aabb = AABB(Vector3(-2000, -2000, -2000), Vector3(4000, 4000, 4000))
	return instance


## The mask as rows of ink (true) and paper; empty when there is none.
static func _ink(path: String) -> Array[PackedByteArray]:
	var rows: Array[PackedByteArray] = []
	if path.is_empty() or not ResourceLoader.exists(path):
		return rows
	var texture: Texture2D = load(path) as Texture2D
	var image: Image = null if texture == null else texture.get_image()
	if image == null:
		return rows
	for y: int in image.get_height():
		var row := PackedByteArray()
		row.resize(image.get_width())
		for x: int in image.get_width():
			row[x] = 1 if image.get_pixel(x, y).r > 0.5 else 0
		rows.append(row)
	return rows


## Every block: [the ink's MultiMesh, the embers' MultiMesh, the logo's span in voxels].
static func _blocks(ink: Array[PackedByteArray], seal: Array[PackedByteArray]) -> Dictionary:
	var h: int = ink.size()
	var w: int = 0 if h == 0 else ink[0].size()
	var cubes: Array = []
	var sparks: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var depth: PackedFloat32Array = _distance(ink, w, h)
	for y: int in h:
		for x: int in w:
			if ink[y][x] == 0:
				continue
			var tall: int = clampi(int(1.0 + depth[y * w + x] * 0.9), 1, 5)
			var spot := Vector3(x - w / 2.0, h / 2.0 - y, 0.0)
			for z: int in tall:
				var c: Color = Color("15151a").lerp(Color("3a3c4a"), float(z) / 4.0).lerp(Color("0e0e12"), rng.randf() * 0.3)
				if z == tall - 1 and rng.randf() < 0.022:
					c = Color("e8b54a")
				cubes.append([spot + Vector3(0, 0, z), c, false])
			sparks.append(spot + Vector3(0, 0, tall))
	_brush(cubes, sparks, w, h, rng)
	var side: int = _seal(cubes, seal, w, h, rng)
	var span: float = float(w + side + 6)
	var shift := Vector3(-(side + 6) / 2.0, 0, 0)
	var ink_mesh := MultiMesh.new()
	ink_mesh.transform_format = MultiMesh.TRANSFORM_3D
	ink_mesh.use_colors = true
	ink_mesh.use_custom_data = true
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	ink_mesh.mesh = cube
	ink_mesh.instance_count = cubes.size()
	for index: int in cubes.size():
		var p: Vector3 = cubes[index][0] + shift
		ink_mesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, p))
		ink_mesh.set_instance_color(index, cubes[index][1])
		# z: when it is written (the stroke first, then the characters, left to right); w: when
		# the burning front reaches it.
		var xn: float = clampf((p.x + span / 2.0) / span, 0.0, 1.0)
		var written: float = xn * 0.32 + rng.randf() * 0.03 if cubes[index][2] else 0.3 + xn * 0.58 + rng.randf() * 0.1
		ink_mesh.set_instance_custom_data(index, Color(rng.randf(), rng.randf(), written, _burn_order(p, span, rng)))
	var ember_mesh := MultiMesh.new()
	ember_mesh.transform_format = MultiMesh.TRANSFORM_3D
	ember_mesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	ember_mesh.mesh = quad
	ember_mesh.instance_count = sparks.size()
	for index: int in sparks.size():
		var q: Vector3 = sparks[index] + shift
		ember_mesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, q))
		ember_mesh.set_instance_custom_data(index, Color(rng.randf(), rng.randf(), _burn_order(q, span, rng) + rng.randf() * 0.03, rng.randf()))
	return {"ink": ink_mesh, "embers": ember_mesh, "span": span, "cubes": cubes}


## A broad vermilion stroke behind the letters: a heavy round head on the left, hair streaks
## along it, thinning and breaking into dry brush (飞白) toward the tail.
static func _brush(cubes: Array, sparks: Array[Vector3], w: int, h: int, rng: RandomNumberGenerator) -> void:
	var x0: int = -w / 2 - 18
	var x1: int = w / 2 + 30
	for x: int in range(x0, x1):
		var t: float = float(x - x0) / float(x1 - x0)
		var half: float = h * 0.36 * lerpf(1.1, 0.6, smoothstep(0.1, 1.0, t))
		if t < 0.06:
			half *= sqrt(t / 0.06) * 0.6 + 0.4
		half += sin(x * 0.23) * 1.6 + sin(x * 0.71) * 0.9
		var mid: float = -6.0 + sin(t * 3.2) * 3.0 - t * 5.0
		for y: int in range(int(mid - half), int(mid + half) + 1):
			var v: float = (y - mid) / half
			var hair: float = sin(y * 2.3 + sin(y * 0.7) * 3.0) * 0.5 + 0.5
			if t > 0.5 and hair > 1.0 - (t - 0.5) * 1.4:
				continue
			if absf(v) > 0.86 and rng.randf() < 0.45:
				continue
			var c: Color = Color("b02e1c").lerp(Color("d9472a"), hair * 0.35).lerp(Color("7d1d11"), absf(v) * 0.35)
			cubes.append([Vector3(x, y, -4), c.darkened(0.15), true])
			cubes.append([Vector3(x, y, -3), c, true])
			if rng.randf() < 0.15:
				sparks.append(Vector3(x, y, -2))


## The seal at the lower right of the last character: 侠 cut into vermilion, or, with no glyph
## (a language without one), a cut square knot. Returns its side.
static func _seal(cubes: Array, glyph: Array[PackedByteArray], w: int, h: int, rng: RandomNumberGenerator) -> int:
	var sh: int = glyph.size()
	var sw: int = 0 if sh == 0 else glyph[0].size()
	var side: int = maxi(maxi(sw, sh) + 6, 26)
	var corner := Vector3(w / 2.0 + 4.0, -h / 2.0 + side - 2.0, 0.0)
	for y: int in side:
		for x: int in side:
			var cut: bool
			if sh > 0:
				var gx: int = x - (side - sw) / 2
				var gy: int = y - (side - sh) / 2
				cut = gx >= 0 and gy >= 0 and gx < sw and gy < sh and glyph[gy][gx] == 1
			else:
				var ring: int = mini(mini(x, y), mini(side - 1 - x, side - 1 - y))
				cut = ring == 3 or (ring >= 7 and ring <= 8) or (x == side / 2 and ring >= 7) or (y == side / 2 and ring >= 7)
			var rim: bool = x == 0 or y == 0 or x == side - 1 or y == side - 1
			if rng.randf() < 0.06 and not rim:
				continue
			var c: Color = Color("b8321f").lerp(Color("8f2416"), rng.randf() * 0.5)
			for z: int in (1 if cut else 3):
				cubes.append([corner + Vector3(x, -y, z), Color("e9d6b8") if cut else c, false])
	return side


static func _burn_order(p: Vector3, span: float, rng: RandomNumberGenerator) -> float:
	var xn: float = clampf((p.x + span / 2.0) / span, 0.0, 1.0)
	return clampf(xn * 0.82 + 0.1 * (sin(p.y * 0.19 + xn * 9.0) * 0.5 + 0.5) + rng.randf() * 0.02, 0.0, 1.0)


## Chamfer distance from the edge of the ink (1 at the edge): strokes are thickest mid-stroke.
static func _distance(ink: Array[PackedByteArray], w: int, h: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(w * h)
	for y: int in h:
		for x: int in w:
			d[y * w + x] = 999.0 if ink[y][x] == 1 else 0.0
	for pass_index: int in 2:
		var ys: Array = range(h) if pass_index == 0 else range(h - 1, -1, -1)
		var xs: Array = range(w) if pass_index == 0 else range(w - 1, -1, -1)
		var step: int = 1 if pass_index == 0 else -1
		for y: int in ys:
			for x: int in xs:
				var i: int = y * w + x
				if d[i] == 0.0:
					continue
				var best: float = d[i]
				var px: int = x - step
				var py: int = y - step
				best = minf(best, d[y * w + px] + 1.0 if px >= 0 and px < w else 1.0)
				best = minf(best, d[py * w + x] + 1.0 if py >= 0 and py < h else 1.0)
				if px >= 0 and px < w and py >= 0 and py < h:
					best = minf(best, d[py * w + px] + 1.4)
				var qx: int = x + step
				if qx >= 0 and qx < w and py >= 0 and py < h:
					best = minf(best, d[py * w + qx] + 1.4)
				d[i] = best
	return d
