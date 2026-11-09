class_name BattleVoxelBanner
extends SubViewport

## 战斗演出 E (DECISIONS「战斗演出 E」), owner 2026-11-09: the side panel's banner made of voxels and
## alive — a cloth of bricks hanging from a wooden pole, dyed dark in its side's colour (the
## player's 铜绿, the other's 朱漆) with a woven grain, a bright border and a trim, a darker hem
## and a swallowtail foot, a cord with a knot and a fringe hanging from each tail; the pole's ends
## gold on the current target's. The cloth ripples (banner_cloth.gdshader), flaps hard when its
## side strikes (gust()), and is let down from the pole when the panel opens (unfurl). Drawn in a
## world of its own and shown behind the panel's rows (BattlePanelChrome).
## Presentation only.

const SHADER: Shader = preload("res://presentation/voxel/shaders/banner_cloth.gdshader")
const POLE: Color = Color("5a3820")
const POLE_LIGHT: Color = Color("7d5230")
const KNOB: Color = Color("3d2d16")
const TRIM: Color = Color("9a743a")
const CORD: Color = Color("8a5a35")
## The cloth's bricks across; the rest follow the panel's shape.
const COLUMNS: int = 26
## Rows of the swallowtail under the cloth, of a cord and its fringe under each tail.
const TAIL_ROWS: int = 5
const CORD_ROWS: int = 7
## Bricks of room round the banner (the pole's ends, the sway).
const MARGIN_SIDE: int = 3
const MARGIN_TOP: int = 3
const MARGIN_FOOT: int = 1
const THICKNESS: float = 0.5
## How quickly a flap dies away (of 1 a second).
const GUST_FADE: float = 1.3

var cloth_rows: int = 0
var side: int = 0
var current: bool = false
var side_colour: Color = UiPalette.PATINA
var gust_now: float = 0.0
var _material: ShaderMaterial
var _mesh: MultiMeshInstance3D
var _camera: Camera3D
var _unfurl_tween: Tween
var _clock: float = 0.0


func _init() -> void:
	transparent_bg = true
	own_world_3d = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	msaa_3d = Viewport.MSAA_DISABLED
	size = Vector2i(64, 64)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 0.1
	_camera.far = 200.0
	add_child(_camera)
	_mesh = MultiMeshInstance3D.new()
	_mesh.name = "Banner"
	add_child(_mesh)


## The bricks a banner of `rows` cloth rows (COLUMNS across) needs, laid again only when the shape,
## the side or its colour changed; `p_current`: the pole's ends gold.
func build(rows: int, p_side: int, dye: Color, p_current: bool) -> void:
	if rows == cloth_rows and p_side == side and dye == side_colour and p_current == current and _mesh.multimesh != null:
		return
	cloth_rows = maxi(4, rows)
	side = p_side
	side_colour = dye
	current = p_current
	var bricks: Array[Array] = [] # [position, size, colour, flex, row]
	var rng := RandomNumberGenerator.new()
	rng.seed = 31 + side
	var cloth: Color = side_colour.darkened(0.66).lerp(Color("2a1e17"), 0.35)
	var hem: Color = side_colour.darkened(0.35)
	var centre: float = float(COLUMNS) / 2.0
	# The cloth, then the swallowtail.
	for row: int in cloth_rows + TAIL_ROWS:
		for column: int in COLUMNS:
			if row >= cloth_rows:
				var cut: float = float(row - cloth_rows + 1) * centre / float(TAIL_ROWS + 1)
				if absf(float(column) + 0.5 - centre) <= cut:
					continue
			var edge: int = mini(column, COLUMNS - 1 - column)
			var colour: Color = cloth
			if edge == 0:
				colour = side_colour.darkened(0.15)
			elif edge == 1:
				colour = side_colour
			elif edge == 2:
				colour = TRIM.darkened(0.25)
			elif row >= cloth_rows - 2:
				colour = hem
			elif row == 1 or row == cloth_rows - 3:
				colour = TRIM.darkened(0.25)
			# The weave: rows and columns a shade apart, every brick a little its own.
			var weave: float = (0.014 if row % 2 == 0 else -0.008) + rng.randf_range(-0.02, 0.02)
			colour = colour.lightened(weave) if weave > 0.0 else colour.darkened(-weave)
			bricks.append([Vector3(column + 0.5, -(row + 0.5), 0.0), Vector3(1.0, 1.0, THICKNESS), colour, 1.0, float(row)])
	# A cord with a knot and a fringe from each tail's tip.
	for column: int in [1, COLUMNS - 2]:
		for at: int in CORD_ROWS:
			var row: int = cloth_rows + TAIL_ROWS + at
			var knot: bool = at == 3
			var width: float = 1.0 if knot else (0.4 if at < 3 else 0.7)
			var colour: Color = side_colour if knot else CORD.darkened(0.1 * float(at % 2))
			bricks.append([Vector3(column + 0.5, -(row + 0.5), 0.0), Vector3(width, 1.0, width * 0.8), colour, 1.0, float(row)])
	# The pole across the top, past the cloth, and its two ends.
	for column: int in range(-1, COLUMNS + 1):
		var grain: Color = POLE.lightened(0.06) if (column * 7) % 5 == 0 else POLE
		bricks.append([Vector3(column + 0.5, 0.5, 0.0), Vector3(1.0, 1.0, 1.0), grain, 0.0, -1.0])
		bricks.append([Vector3(column + 0.5, 1.0, -0.2), Vector3(1.0, 0.25, 0.6), POLE_LIGHT, 0.0, -1.0])
	var knob: Color = UiPalette.LANTERN if current else KNOB
	for column: int in [-2, COLUMNS + 1]:
		bricks.append([Vector3(column + 0.5, 0.5, 0.0), Vector3(1.2, 1.6, 1.2), knob, 0.0, -1.0])
		bricks.append([Vector3(column + 0.5, 1.45, 0.0), Vector3(0.8, 0.4, 0.8), knob.lightened(0.3), 0.0, -1.0])
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = _material
	multi.mesh = box
	multi.instance_count = bricks.size()
	for index: int in bricks.size():
		var brick: Array = bricks[index]
		multi.set_instance_transform(index, Transform3D(Basis().scaled(brick[1]), brick[0]))
		multi.set_instance_color(index, brick[2])
		multi.set_instance_custom_data(index, Color(float(brick[3]), float(brick[4]), 0.0, 0.0))
	_mesh.multimesh = multi
	_material.set_shader_parameter("rows", float(cloth_rows + TAIL_ROWS + CORD_ROWS))
	_material.set_shader_parameter("lean", -1.0 if side == 0 else 1.0)
	_frame()


## The banner's whole height in bricks (pole and margins too) and width, for the panel's sizing.
static func bricks_high(rows: int) -> int:
	return MARGIN_TOP + rows + TAIL_ROWS + CORD_ROWS + MARGIN_FOOT


static func bricks_wide() -> int:
	return COLUMNS + MARGIN_SIDE * 2


## The camera on the banner from a little to the stage's side and a little above, so the bricks'
## sides and tops show; as high as the banner with its margins.
func _frame() -> void:
	var high: float = float(bricks_high(cloth_rows))
	var middle := Vector3(float(COLUMNS) / 2.0, float(MARGIN_TOP) - high / 2.0, 0.0)
	var yaw: float = deg_to_rad(10.0) * (1.0 if side == 0 else -1.0)
	var pitch: float = deg_to_rad(7.0)
	var away := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 60.0
	_camera.size = high
	_camera.position = middle + away
	_camera.look_at(middle, Vector3.UP)


## Let down from the pole over `seconds` after `delay` (rolled up till then; 0: at once).
func let_down(seconds: float, delay: float = 0.0) -> void:
	if _unfurl_tween != null and _unfurl_tween.is_valid():
		_unfurl_tween.kill()
	if seconds <= 0.0:
		_material.set_shader_parameter("unfurl", 1.0)
		return
	_material.set_shader_parameter("unfurl", 0.0)
	_unfurl_tween = create_tween()
	if delay > 0.0:
		_unfurl_tween.tween_interval(delay)
	# A flap as it drops open.
	_unfurl_tween.tween_callback(gust.bind(0.9))
	_unfurl_tween.tween_method(func(share: float) -> void: _material.set_shader_parameter("unfurl", share), 0.0, 1.0, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## How far it is let down now (0 .. 1; tests).
func unfurled() -> float:
	return float(_material.get_shader_parameter("unfurl"))


## A flap (`amount` 0 .. 1; the strongest asked wins), dying away.
func gust(amount: float) -> void:
	gust_now = maxf(gust_now, clampf(amount, 0.0, 1.0))
	_material.set_shader_parameter("gust", gust_now)
	set_process(true)


func _process(delta: float) -> void:
	if gust_now <= 0.0:
		set_process(false)
		return
	gust_now = move_toward(gust_now, 0.0, delta * GUST_FADE)
	_material.set_shader_parameter("gust", gust_now)
