class_name TitleLogo
extends Control

## The title's logo (DECISIONS「标题画面」): the title's characters as giant slabs of rock
## (TitleMonument) fallen onto the 沙盘 and stuck in it, in a 3D view of their own laid over the
## 沙盘 and seen from the south and above like it. Nothing of the view but the stones and what
## they do to the ground shows: their shadows, the craters and cracks where they struck, the
## rubble and dust they threw up. The sun stands behind them (their rims catch it, their
## shadows fall forward on the land), a cool light fills their faces. TitleScreen tweens:
##   write  0 → 1   the arrival: one by one, left to right, each stone falls out of the sky,
##                  strikes the ground, shudders and digs in; cracks run out, rubble flies, dust
##                  rolls; the seal last (ARRIVAL_SECONDS for 0 → 1)
##   glint          a band of gold light passing over the stones
##   charge         the stones trembling before they break
##   burn  -0.2 → 1.15  the leaving: the stones break along their seams and the pieces topple
##                  and sink into the ground (LEAVING_SECONDS for 0 → 1)
## The view keeps a full alpha (use_hdr_2d) and is shown through title_view.gdshader.

const STONES: Shader = preload("res://presentation/title/shaders/title_logo.gdshader")
const RUBBLE: Shader = preload("res://presentation/title/shaders/title_chips.gdshader")
const DUST: Shader = preload("res://presentation/title/shaders/title_dust.gdshader")
const GROUND: Shader = preload("res://presentation/title/shaders/title_ground.gdshader")
const VIEW: Shader = preload("res://presentation/title/shaders/title_view.gdshader")
const CAMERA_DISTANCE: float = 400.0
const FOV: float = 26.0
## How long `write` 0 → 1 and `burn` 0 → 1 take (TitleScreen tweens them linearly over these).
const ARRIVAL_SECONDS: float = 3.6
const LEAVING_SECONDS: float = 1.5
## The stones' turn toward the viewer (degrees): seen from above like the 沙盘, a little from
## their left.
const LOOK := Vector3(17.0, -8.0, 0.0)
## Dust puffs per stone.
const PUFFS: int = 18
## The meshes of one monument, built once in a run.
static var _meshes: Dictionary = {}

var write: float = 0.0
var burn: float = -0.2
var charge: float = 0.0
var glint: float = -9999.0
var clock: float = 0.0
## Where the stones' middle stands (parts of the screen) and how wide they are (UI pixels at
## 1280 wide).
var at: Vector2 = Vector2(0.3, 0.24)
var width_px: float = 760.0

var monument: TitleMonument
var _view: SubViewport
var _camera: Camera3D
var _board: Node3D
## The stones' own space (voxels, the ground at y = 0) under the board.
var _space: Node3D
var _materials: Array[ShaderMaterial] = []
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
	# A full alpha: the shadows, cracks and dust lie see-through on the 沙盘.
	_view.use_hdr_2d = true
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
	var look := ShaderMaterial.new()
	look.shader = VIEW
	shown.material = look
	add_child(shown)
	_world()


## Builds the stones of `mask_path` (white = ink) and `seal_path` ("" for the cut knot).
func build(mask_path: String, seal_path: String) -> void:
	monument = TitleMonument.of(mask_path, seal_path)
	var meshes: Dictionary = meshes_for(monument)
	_span = monument.span
	for child: Node in _space.get_children():
		child.queue_free()
	_materials.clear()
	var stones: ShaderMaterial = _material(STONES)
	var rubble: ShaderMaterial = _material(RUBBLE)
	var dust: ShaderMaterial = _material(DUST)
	var ground: ShaderMaterial = _material(GROUND)
	_space.add_child(_instance("Stones", meshes["stones"], stones, true))
	_space.add_child(_instance("Rubble", meshes["rubble"], rubble, true))
	_space.add_child(_instance("Dust", meshes["dust"], dust, false))
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(monument.span * 3.0, 260.0)
	var land := MeshInstance3D.new()
	land.name = "Ground"
	land.mesh = floor_mesh
	land.material_override = ground
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	land.position = Vector3(monument.middle_x, 0.0, 90.0)
	_space.add_child(land)
	var info := PackedVector4Array()
	var more := PackedVector4Array()
	for stone: TitleMonument.Stone in monument.stones:
		info.append(Vector4(stone.pivot.x, stone.pivot.y, stone.pivot.z, stone.land))
		more.append(Vector4(stone.half_width, 0.0, 0.0, 0.0))
	var parts := PackedVector4Array()
	for fragment: TitleMonument.Fragment in monument.fragments:
		parts.append(Vector4(fragment.centre.x, fragment.centre.y, fragment.centre.z, fragment.leave))
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter("stone_info", info)
		mat.set_shader_parameter("stone_more", more)
		mat.set_shader_parameter("stone_count", monument.stones.size())
		mat.set_shader_parameter("fragments", parts)
		mat.set_shader_parameter("write_secs", ARRIVAL_SECONDS)
		mat.set_shader_parameter("burn_secs", LEAVING_SECONDS)
	_place()


## The monument's MultiMeshes, built once: "stones" (a box per voxel column: colour and
## material + 16 × stone; seed, marks, -, fragment), "rubble" (seed, stone) and "dust" (seed,
## stone, heading, size).
static func meshes_for(built: TitleMonument) -> Dictionary:
	if _meshes.has(built):
		return _meshes[built]
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	var stones: MultiMesh = _boxes(built.blocks.size())
	for index: int in built.blocks.size():
		var block: TitleMonument.Block = built.blocks[index]
		stones.set_instance_transform(index, Transform3D(block.basis * Basis.from_scale(block.size), block.centre))
		var colour: Color = block.colour
		colour.a = (block.material + 16 * block.stone) / 255.0
		stones.set_instance_color(index, colour)
		stones.set_instance_custom_data(index, Color(rng.randf(), block.marks, 0.0, block.fragment))
	var rubble: MultiMesh = _boxes(built.rubble.size())
	for index: int in built.rubble.size():
		var chunk: Array = built.rubble[index]
		rubble.set_instance_transform(index, Transform3D((chunk[2] as Basis) * Basis.from_scale(chunk[1]), chunk[0]))
		rubble.set_instance_color(index, chunk[3])
		rubble.set_instance_custom_data(index, Color(rng.randf(), chunk[4], 0.0, 0.0))
	var dust := MultiMesh.new()
	dust.transform_format = MultiMesh.TRANSFORM_3D
	dust.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	dust.mesh = quad
	dust.instance_count = built.stones.size() * PUFFS
	for index: int in built.stones.size():
		var stone: TitleMonument.Stone = built.stones[index]
		for k: int in PUFFS:
			var at := Vector3(stone.pivot.x + rng.randf_range(-stone.half_width, stone.half_width), rng.randf_range(0.5, 3.0), rng.randf_range(-TitleMonument.DEPTH, TitleMonument.DEPTH))
			dust.set_instance_transform(index * PUFFS + k, Transform3D(Basis.IDENTITY, at))
			dust.set_instance_custom_data(index * PUFFS + k, Color(rng.randf(), index, rng.randf() * TAU, rng.randf_range(5.0, 11.0)))
	var result: Dictionary = {"stones": stones, "rubble": rubble, "dust": dust}
	_meshes[built] = result
	return result


static func _boxes(count: int) -> MultiMesh:
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_colors = true
	mesh.use_custom_data = true
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	mesh.mesh = cube
	mesh.instance_count = count
	return mesh


func texture() -> Texture2D:
	return _view.get_texture()


func _ready() -> void:
	get_viewport().size_changed.connect(_place)
	_place()


func _process(delta: float) -> void:
	clock += delta
	if monument == null:
		return
	_board.rotation_degrees = LOOK + Vector3(sin(clock * 0.31) * 0.5, sin(clock * 0.23) * 1.2, 0.0)
	var space := Projection(_space.global_transform)
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter("space", space)
		mat.set_shader_parameter("write", write)
		mat.set_shader_parameter("burn", burn)
		mat.set_shader_parameter("charge", charge)
		mat.set_shader_parameter("glint", glint)


## The glint's path across the stones, in world units: from their left (0) to their right (1).
func glint_at(part: float) -> float:
	return _board.position.x + (part - 0.5) * _span * _unit * 1.2


func _material(shader: Shader) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_materials.append(mat)
	return mat


func _world() -> void:
	var world := Node3D.new()
	world.name = "World"
	_view.add_child(world)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8f9bb3")
	environment.ambient_light_energy = 0.55
	env.environment = environment
	world.add_child(env)
	# The sun behind the stones, high on their left: rims and tops catch it, their shadows fall
	# forward on the land. A cool light fills their faces from the front right.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("ffd8a0")
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = CAMERA_DISTANCE * 2.0
	world.add_child(sun)
	sun.basis = Basis.looking_at(Vector3(0.45, -0.55, 0.7).normalized(), Vector3.UP)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_color = Color("c4d0e6")
	fill.light_energy = 1.1
	world.add_child(fill)
	fill.basis = Basis.looking_at(Vector3(-0.35, -0.4, -0.85).normalized(), Vector3.UP)
	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.far = CAMERA_DISTANCE * 4.0
	_camera.position = Vector3(0, 0, CAMERA_DISTANCE)
	world.add_child(_camera)
	_board = Node3D.new()
	_board.name = "Board"
	world.add_child(_board)
	_space = Node3D.new()
	_space.name = "Space"
	_board.add_child(_space)


## The view follows the window; the stones stand at `at`, `width_px` wide.
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
	if monument != null:
		_space.position = Vector3(-monument.middle_x, -monument.tall / 2.0, 0.0)


static func _instance(node_name: String, multimesh: MultiMesh, material: ShaderMaterial, shadows: bool) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-2000, -2000, -2000), Vector3(4000, 4000, 4000))
	return instance
