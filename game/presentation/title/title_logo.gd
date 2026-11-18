class_name TitleLogo
extends Control

## The title's logo (DECISIONS「标题画面」): the brush characters (东方故事, or Eastern Stories —
## one language at a time) built in a 3D view of their own from blocks of every size and
## material — stone, wood, iron, bronze, jade glass, gold and lamp-stones that blink — each
## showing what time did to it: rust and verdigris, moss on its top, cracks, a few loose and
## rocking, a few hanging off a stroke's lower edge and swinging. Strokes stand out in relief
## toward their middle; a vermilion seal (侠; a cut knot where the language has no seal) and
## behind it all a broad vermilion brush stroke. TitleScreen tweens:
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
## How many voxels the brush's ink is made bolder by, all round.
const THICKEN: int = 1
## A character block's side in voxels, and how often each is tried (bigger ones only where
## the stroke has room).
const BLOCK_SIZES: Array[int] = [1, 2, 3, 4, 5]
const BLOCK_WEIGHTS: PackedFloat32Array = [0.04, 0.24, 0.36, 0.26, 0.1]
## Materials come in patches this many voxels across (a run of stone, a band of iron, a stretch
## of wood), PATCH_KEEP of the blocks in one being its material; the rest are strays.
const PATCH: int = 11
const PATCH_KEEP: float = 0.72
## The dark bed under the blocks is laid in runs this long.
const CORE_RUN: int = 4
## Materials (the low three bits of a block's code; the shader draws each its own way). PLAIN is
## the vermilion stroke and the seal.
const PLAIN: int = 0
const STONE: int = 1
const WOOD: int = 2
const IRON: int = 3
const BRONZE: int = 4
const GLASS: int = 5
const GOLD: int = 6
const LAMP: int = 7
## What time did to a block (the code's upper bits).
const LOOSE: int = 1
const RUSTED: int = 2
const MOSSY: int = 4
const CRACKED: int = 8
const HANGING: int = 16
## Per material: how often it is picked, whether it makes up patches or only strays (gold and
## the lamp-stones are accents), its colours, how likely each state is. The palette
## stays dark so the characters read against the sky and the stroke; gold, glass and the
## lamp-stones are the light in it.
const MATERIALS: Dictionary = {
	STONE: {"weight": 40, "patch": true, "colours": ["2e3036", "3c3e44", "46444a", "353a40", "48403a"], MOSSY: 0.15, CRACKED: 0.35, LOOSE: 0.06},
	WOOD: {"weight": 18, "patch": true, "colours": ["452a16", "52341f", "38231a", "5e4128"], MOSSY: 0.12, CRACKED: 0.2, LOOSE: 0.07},
	IRON: {"weight": 16, "patch": true, "colours": ["2c3036", "383b40", "24272b"], RUSTED: 0.45, LOOSE: 0.05},
	BRONZE: {"weight": 10, "patch": true, "colours": ["6a4822", "74522a", "553a1a"], RUSTED: 0.45, LOOSE: 0.05},
	GLASS: {"weight": 9, "patch": false, "colours": ["2f7a5e", "1f5c6c", "4a7c9a", "8a5a1c"], CRACKED: 0.2, LOOSE: 0.04},
	GOLD: {"weight": 6, "patch": false, "colours": ["c9973a", "b8862e"], LOOSE: 0.05},
	LAMP: {"weight": 9, "patch": false, "colours": ["ffc85a", "7fe6ff", "ff8a3a", "c8ff8a"], LOOSE: 0.03},
}
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
## "span" (its width in voxels), "cubes" ([centre, colour, in the stroke] per block, then
## [size, code, tilt] for the characters' blocks and their bed).
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
		# Soft enough that the characters' shadow on the stroke does not fill their gaps.
		sun.shadow_opacity = 0.55
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
	var thick: Array[PackedByteArray] = _thicken(ink, w, h)
	_pack(cubes, sparks, thick, w, h, rng)
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
		var entry: Array = cubes[index]
		var p: Vector3 = entry[0] + shift
		var basis := Basis.IDENTITY
		var code: int = 0
		if entry.size() > 3:
			basis = Basis.from_euler(entry[5]) * Basis.from_scale(entry[3])
			code = entry[4]
		ink_mesh.set_instance_transform(index, Transform3D(basis, p))
		# The colour's alpha carries the block's material and what has become of it (code / 255).
		var colour: Color = entry[1]
		colour.a = code / 255.0
		ink_mesh.set_instance_color(index, colour)
		# z: when it is written (the stroke first, then the characters, left to right); w: when
		# the burning front reaches it.
		var xn: float = clampf((p.x + span / 2.0) / span, 0.0, 1.0)
		var written: float = xn * 0.32 + rng.randf() * 0.03 if entry[2] else 0.3 + xn * 0.58 + rng.randf() * 0.1
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


## The ink one voxel bolder all round, so the brush's hairlines carry blocks.
static func _thicken(ink: Array[PackedByteArray], w: int, h: int) -> Array[PackedByteArray]:
	var rows: Array[PackedByteArray] = []
	for y: int in h:
		var row := PackedByteArray()
		row.resize(w)
		for x: int in w:
			var on: int = 0
			for dy: int in range(-THICKEN, THICKEN + 1):
				for dx: int in range(-THICKEN, THICKEN + 1):
					var qx: int = x + dx
					var qy: int = y + dy
					if absi(dx) + absi(dy) <= THICKEN + 1 and qx >= 0 and qy >= 0 and qx < w and qy < h and ink[qy][qx] == 1:
						on = 1
			row[x] = on
		rows.append(row)
	return rows


## The characters laid in blocks of every size (BLOCK_SIZES; bigger mid-stroke), each one of
## MATERIALS with what time has done to it (rust, moss, cracks, loose, hanging off an edge),
## raised in relief toward the middle of the stroke. Leftover voxels become small chips.
## Character blocks are [centre, colour, false, size, code, tilt]; code = material | state << 3.
static func _pack(cubes: Array, sparks: Array[Vector3], ink: Array[PackedByteArray], w: int, h: int, rng: RandomNumberGenerator) -> void:
	var depth: PackedFloat32Array = _distance(ink, w, h)
	var taken := PackedByteArray()
	taken.resize(w * h)
	var front := PackedFloat32Array()
	front.resize(w * h)
	var cells: Array[Vector2i] = []
	for y: int in h:
		for x: int in w:
			if ink[y][x] == 1:
				cells.append(Vector2i(x, y))
	for i: int in range(cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Vector2i = cells[i]
		cells[i] = cells[j]
		cells[j] = swap
	var weights: PackedFloat32Array = BLOCK_WEIGHTS
	var patches: Dictionary = {}
	for cell: Vector2i in cells:
		if taken[cell.y * w + cell.x] == 1:
			continue
		var room: int = clampi(int(depth[cell.y * w + cell.x] * 2.0 + 1.0), 1, BLOCK_SIZES[-1])
		var want: int = BLOCK_SIZES[rng.rand_weighted(weights)]
		want = mini(want, room)
		var anchor := Vector2i(-1, -1)
		var size: int = want
		while size >= 2:
			anchor = _fit(ink, taken, w, h, cell, size, rng)
			if anchor.x >= 0:
				break
			size -= 1
		if anchor.x < 0:
			anchor = cell
			size = 1
		var mid: float = 0.0
		for y: int in range(anchor.y, anchor.y + size):
			for x: int in range(anchor.x, anchor.x + size):
				taken[y * w + x] = 1
				mid = maxf(mid, depth[y * w + x])
		var hangs_free: bool = anchor.y + size < h
		if hangs_free:
			for x: int in range(anchor.x, anchor.x + size):
				if ink[anchor.y + size][x] == 1:
					hangs_free = false
		# The patch a block is in, its borders ragged.
		var where := Vector2i(floori((anchor.x + rng.randi_range(-3, 3)) / float(PATCH)), floori((anchor.y + rng.randi_range(-3, 3)) / float(PATCH)))
		if not patches.has(where):
			patches[where] = _pick(rng, true)
		var kind: int = patches[where] if rng.randf() < PATCH_KEEP else _pick(rng, false)
		var block: Array = _block(anchor, size, mid, hangs_free, kind if size > 1 else STONE, w, h, rng)
		cubes.append(block)
		var face: float = (block[0] as Vector3).z + (block[3] as Vector3).z / 2.0
		for y: int in range(anchor.y, anchor.y + size):
			for x: int in range(anchor.x, anchor.x + size):
				front[y * w + x] = face
	for cell: Vector2i in cells:
		sparks.append(Vector3(cell.x - w / 2.0, h / 2.0 - cell.y, front[cell.y * w + cell.x]))
	_core(cubes, ink, w, h)


## Under the blocks a dark bed the exact shape of the characters, so what shows between them
## is the character, not the stroke behind it: short runs one voxel deep.
static func _core(cubes: Array, ink: Array[PackedByteArray], w: int, h: int) -> void:
	for y: int in h:
		var x: int = 0
		while x < w:
			if ink[y][x] == 0:
				x += 1
				continue
			var run: int = 0
			while x + run < w and ink[y][x + run] == 1 and run < CORE_RUN:
				run += 1
			cubes.append([Vector3(x + run / 2.0 - w / 2.0, h / 2.0 - y - 0.5, 0.5), Color("121216"), false, Vector3(run, 1.0, 1.0), PLAIN, Vector3.ZERO])
			x += run


## Where an s-block holding `cell` fits: all of it free ink. (-1, -1) if
## nowhere.
static func _fit(ink: Array[PackedByteArray], taken: PackedByteArray, w: int, h: int, cell: Vector2i, s: int, rng: RandomNumberGenerator) -> Vector2i:
	var need: int = s * s
	var start: int = rng.randi_range(0, s * s - 1)
	for k: int in s * s:
		var o: int = (start + k) % (s * s)
		var anchor := Vector2i(cell.x - o % s, cell.y - o / s)
		if anchor.x < 0 or anchor.y < 0 or anchor.x + s > w or anchor.y + s > h:
			continue
		var inked: int = 0
		var free: bool = true
		for y: int in range(anchor.y, anchor.y + s):
			for x: int in range(anchor.x, anchor.x + s):
				if taken[y * w + x] == 1:
					free = false
					break
				inked += ink[y][x]
			if not free:
				break
		if free and inked >= need:
			return anchor
	return Vector2i(-1, -1)


## One block: its material, colour, relief, small skew and what time did to it.
static func _block(anchor: Vector2i, s: int, mid: float, hangs_free: bool, kind: int, w: int, h: int, rng: RandomNumberGenerator) -> Array:
	var look: Dictionary = MATERIALS[kind]
	var colours: Array = look["colours"]
	var colour := Color(colours[rng.randi() % colours.size()]).lerp(Color.BLACK, rng.randf() * 0.12)
	var state: int = 0
	for flag: int in [RUSTED, MOSSY, CRACKED, LOOSE]:
		if rng.randf() < float(look.get(flag, 0.0)):
			state |= flag
	var gap: float = rng.randf_range(0.05, 0.12)
	var face: float = 1.2 + s * 0.3 + mid * 0.22 + rng.randf() * 0.4
	if s == 1:
		face = rng.randf_range(0.6, 1.4)
	face = clampf(face, 0.6, 5.5)
	var size := Vector3(s - gap, s - gap, face)
	var centre := Vector3(anchor.x + s / 2.0 - w / 2.0, h / 2.0 - anchor.y - s / 2.0, 1.0 + face / 2.0)
	var tilt := Vector3(rng.randf_range(-0.015, 0.015), rng.randf_range(-0.015, 0.015), rng.randf_range(-0.025, 0.025))
	if state & LOOSE:
		# Loose: it leans out of the stroke and stands proud of it.
		tilt.x += rng.randf_range(0.08, 0.18)
		centre.z += rng.randf_range(0.4, 1.2)
		if hangs_free and s <= 3 and rng.randf() < 0.55:
			# Hanging off the stroke's lower edge by a corner, swinging.
			state = (state & ~LOOSE) | HANGING
			tilt.z = rng.randf_range(0.25, 0.5) * (1.0 if rng.randf() < 0.5 else -1.0)
			centre.y -= s * 0.4
	return [centre, colour, false, size, kind | (state << 3), tilt]


## A material by weight: of those that make up patches, or of all of them.
static func _pick(rng: RandomNumberGenerator, patch: bool) -> int:
	var kinds: Array[int] = []
	var weights := PackedFloat32Array()
	for kind: int in MATERIALS:
		if MATERIALS[kind]["patch"] or not patch:
			kinds.append(kind)
			weights.append(float(MATERIALS[kind]["weight"]))
	return kinds[rng.rand_weighted(weights)]


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
