class_name TitleLogo
extends Control

## The title's logo (DECISIONS「标题画面」): a giant statue of the title (东方故事, or Eastern
## Stories — one language at a time) in big blocks of many sizes and materials, on a stepped
## stone plinth on a grassy rise lost in cloud (TitleMonument), in a 3D view of its own over
## the 沙盘, seen from the south and a little above like the 沙盘 itself. The sun stands behind
## it (its edges catch the light, its shadow falls on the plinth), a cool light fills its face,
## cloud banks its foot and wisps drift round it. TitleScreen tweens:
##   write  0 → 1   the arrival: the plinth's stones, then the characters' blocks, left to right
##                  and bottom up, then the seal fall from the sky and land, chips flying
##                  (ARRIVAL_SECONDS for the whole of it)
##   glint          a band of gold light passing over the blocks
##   charge         the statue trembling before it breaks
##   burn  -0.2 → 1.15  the leaving: the blocks tumble away and fall into the cloud, the tops of
##                  the characters first, then the plinth (LEAVING_SECONDS)
## Once standing, loose blocks rattle now and then, some hang off a stroke and swing, pieces not
## joined to their character hover, the lamp-stones blink.

const LOGO: Shader = preload("res://presentation/title/shaders/title_logo.gdshader")
const CHIPS: Shader = preload("res://presentation/title/shaders/title_chips.gdshader")
const MIST: Shader = preload("res://presentation/title/shaders/title_mist.gdshader")
const CAMERA_DISTANCE: float = 400.0
const FOV: float = 26.0
## How long `write` 0 → 1 and `burn` 0 → 1 take (TitleScreen tweens them linearly over these).
const ARRIVAL_SECONDS: float = 3.6
const LEAVING_SECONDS: float = 1.5
## The statue's turn toward the viewer (degrees): looking down on it a little, from its left.
const LOOK := Vector3(13.0, -9.0, 0.0)
## The meshes of one monument, built once per mask and seal in a run.
static var _meshes: Dictionary = {}

var write: float = 0.0
var burn: float = -0.2
var charge: float = 0.0
var glint: float = -9999.0
var clock: float = 0.0
## Where the statue's middle stands (parts of the screen) and how wide it is, rise and all
## (UI pixels at 1280 wide).
var at: Vector2 = Vector2(0.3, 0.26)
var width_px: float = 760.0

var monument: TitleMonument
var _view: SubViewport
var _camera: Camera3D
var _sun: DirectionalLight3D
var _board: Node3D
var _logo_mat: ShaderMaterial
var _chip_mat: ShaderMaterial
var _mist_mat: ShaderMaterial
## The cloud band over the statue's foot (2D: the 3D view keeps too little of a see-through
## edge for soft cloud).
var _mist: ColorRect
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
	_mist_mat = ShaderMaterial.new()
	_mist_mat.shader = MIST
	_mist = ColorRect.new()
	_mist.name = "Mist"
	_mist.material = _mist_mat
	_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mist.visible = false
	add_child(_mist)
	_world()


## Builds the statue of `mask_path` (white = ink) and `seal_path` ("" for the cut knot).
func build(mask_path: String, seal_path: String) -> void:
	monument = TitleMonument.of(mask_path, seal_path)
	var meshes: Dictionary = meshes_for(monument)
	_span = monument.span
	_logo_mat = ShaderMaterial.new()
	_logo_mat.shader = LOGO
	_chip_mat = ShaderMaterial.new()
	_chip_mat.shader = CHIPS
	for mat: ShaderMaterial in [_logo_mat, _chip_mat]:
		mat.set_shader_parameter("write_secs", ARRIVAL_SECONDS)
		mat.set_shader_parameter("burn_secs", LEAVING_SECONDS)
	for child: Node in _board.get_children():
		child.queue_free()
	_board.add_child(_instance("Blocks", meshes["blocks"], _logo_mat, true))
	_board.add_child(_instance("Chips", meshes["chips"], _chip_mat, true))
	_mist.visible = true
	_place()


## The statue's MultiMeshes, built once per monument: "blocks" (one box per block: colour and
## material, then seed, state, when it lands, when it falls) and "chips" (stones that burst off
## them).
static func meshes_for(built: TitleMonument) -> Dictionary:
	if _meshes.has(built):
		return _meshes[built]
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	var blocks := MultiMesh.new()
	blocks.transform_format = MultiMesh.TRANSFORM_3D
	blocks.use_colors = true
	blocks.use_custom_data = true
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	blocks.mesh = cube
	blocks.instance_count = built.blocks.size()
	var seeds := PackedFloat32Array()
	for index: int in built.blocks.size():
		var block: TitleMonument.Block = built.blocks[index]
		var p: Vector3 = block.centre - built.middle
		blocks.set_instance_transform(index, Transform3D(Basis.from_euler(block.tilt) * Basis.from_scale(block.size), p))
		var colour: Color = block.colour
		colour.a = block.material / 255.0
		blocks.set_instance_color(index, colour)
		var seed: float = rng.randf()
		seeds.append(seed)
		blocks.set_instance_custom_data(index, Color(seed, block.state, block.land, block.fall))
	var result: Dictionary = {"blocks": blocks, "chips": _chips(built, seeds, rng)}
	_meshes[built] = result
	return result


## Chips that burst off the blocks that land and break with a thump: three per big block, at
## its foot, in its colour.
static func _chips(built: TitleMonument, seeds: PackedFloat32Array, rng: RandomNumberGenerator) -> MultiMesh:
	var chips: Array[Array] = []
	for index: int in built.blocks.size():
		var block: TitleMonument.Block = built.blocks[index]
		if block.part in [TitleMonument.Part.GROUND, TitleMonument.Part.DETAIL] or (block.size.x < 1.5 and block.part != TitleMonument.Part.PLINTH):
			continue
		for k: int in 3:
			chips.append([block.centre - built.middle - Vector3(0.0, block.size.y / 2.0 - 0.3, 0.0), seeds[index], block])
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_colors = true
	mesh.use_custom_data = true
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	mesh.mesh = cube
	mesh.instance_count = chips.size()
	for index: int in chips.size():
		var chip: Array = chips[index]
		var block: TitleMonument.Block = chip[2]
		var side: float = rng.randf_range(0.3, 0.75)
		mesh.set_instance_transform(index, Transform3D(Basis.from_euler(Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU) * Basis.from_scale(Vector3.ONE * side), chip[0]))
		mesh.set_instance_color(index, block.colour.darkened(0.15))
		mesh.set_instance_custom_data(index, Color(chip[1], rng.randf(), block.land, block.fall))
	return mesh


func texture() -> Texture2D:
	return _view.get_texture()


func _ready() -> void:
	get_viewport().size_changed.connect(_place)
	_place()


func _process(delta: float) -> void:
	clock += delta
	if _logo_mat == null:
		return
	_board.rotation_degrees = LOOK + Vector3(sin(clock * 0.31) * 0.8, sin(clock * 0.23) * 2.0, 0.0)
	for mat: ShaderMaterial in [_logo_mat, _chip_mat]:
		mat.set_shader_parameter("write", write)
		mat.set_shader_parameter("burn", burn)
	var turned: Basis = _board.global_transform.basis.orthonormalized()
	_chip_mat.set_shader_parameter("up_dir", turned.y)
	_chip_mat.set_shader_parameter("right_dir", turned.x)
	_chip_mat.set_shader_parameter("toward_dir", turned.z)
	_logo_mat.set_shader_parameter("charge", charge)
	_logo_mat.set_shader_parameter("glint", glint)
	_lay_mist()


## Where the statue's foot stands on screen, in parts of it.
func foot_on_screen() -> Vector2:
	if monument == null or not is_inside_tree():
		return at
	var mid: float = (monument.letters_to + monument.letters_from) / 2.0
	var screen: Vector2 = _on_view(Vector3(mid, -9.0, 0.0))
	return screen / Vector2(_view.size).max(Vector2.ONE)


## The cloud band over the rise's rim and below it, following the statue as it sways.
func _lay_mist() -> void:
	var mid: float = (monument.letters_to + monument.letters_from) / 2.0
	var half: float = (monument.letters_to - monument.letters_from) / 2.0 + TitleMonument.RISE.x
	var front: float = TitleMonument.DEPTH / 2.0 + TitleMonument.RISE.z
	var left: Vector2 = _on_view(Vector3(mid - half - 8.0, -8.0, 0.0))
	var right: Vector2 = _on_view(Vector3(mid + half + 8.0, -8.0, 0.0))
	var top: Vector2 = _on_view(Vector3(mid, -7.0, front))
	var bottom: Vector2 = _on_view(Vector3(mid, -17.0, front))
	var tall_px: float = maxf(bottom.y - top.y, 8.0)
	var to_ui: Vector2 = size / Vector2(_view.size).max(Vector2.ONE)
	_mist.position = Vector2(left.x, top.y - tall_px * 0.8) * to_ui
	_mist.size = Vector2(right.x - left.x, tall_px * 2.2) * to_ui
	_mist_mat.set_shader_parameter("time", clock)
	_mist_mat.set_shader_parameter("aspect", _mist.size.x / maxf(_mist.size.y, 1.0))
	_mist_mat.set_shader_parameter("fade", 1.0 - smoothstep(0.3, 1.0, burn))


## A point of the monument (cells) on the view, in its pixels.
func _on_view(point: Vector3) -> Vector2:
	return _camera.unproject_position(_board.global_transform * (point - monument.middle))


## The glint's path across the statue, in world units: from its left (0) to its right (1).
func glint_at(part: float) -> float:
	return _board.position.x + (part - 0.5) * _span * _unit * 1.2


func _world() -> void:
	var world := Node3D.new()
	world.name = "World"
	_view.add_child(world)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8f9bb3")
	environment.ambient_light_energy = 0.6
	env.environment = environment
	world.add_child(env)
	# The sun behind the statue, high on its left: edges and tops catch it, its shadow falls
	# forward on the plinth. A cool light fills its face from the front right.
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.light_color = Color("ffd8a0")
	_sun.light_energy = 2.3
	_sun.shadow_enabled = true
	_sun.shadow_opacity = 0.8
	_sun.shadow_blur = 1.5
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = CAMERA_DISTANCE * 2.0
	world.add_child(_sun)
	_sun.basis = Basis.looking_at(Vector3(0.5, -0.62, 0.6).normalized(), Vector3.UP)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_color = Color("b4c4e0")
	fill.light_energy = 1.3
	world.add_child(fill)
	fill.basis = Basis.looking_at(Vector3(-0.35, -0.45, -0.82).normalized(), Vector3.UP)
	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.far = CAMERA_DISTANCE * 4.0
	_camera.position = Vector3(0, 0, CAMERA_DISTANCE)
	world.add_child(_camera)
	_board = Node3D.new()
	_board.name = "Board"
	world.add_child(_board)


## The view follows the window; the statue stands at `at`, `width_px` wide.
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
		for mat: ShaderMaterial in [_logo_mat, _chip_mat]:
			mat.set_shader_parameter("unit", _unit)


static func _instance(node_name: String, multimesh: MultiMesh, material: ShaderMaterial, shadows: bool) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-2000, -2000, -2000), Vector3(4000, 4000, 4000))
	return instance
