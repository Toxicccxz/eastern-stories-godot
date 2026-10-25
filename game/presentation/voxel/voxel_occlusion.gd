class_name VoxelOcclusion
extends RefCounted

## Only the pixels between a subject and the fixed camera fade. The rest of each
## object, its collision and its shadow remain intact. State belongs to this map.
const SHADER = preload("res://presentation/voxel/shaders/local_occlusion.gdshader")
const BLEND = preload("res://presentation/voxel/shaders/local_occlusion_blend.gdshader")
const DEPTH = preload("res://presentation/voxel/shaders/local_occlusion_depth.gdshader")
const PLAIN = preload("res://presentation/voxel/shaders/local_occlusion_plain.gdshader")
const LIMIT: int = 16
## Side of a cell of the screen-plane grid that finds the occluders a subject may be behind.
const CELL: float = 3.0
## Slack around each surface's box: flickering flames scale a little, and the camera angle
## is matched to four decimals.
const PAD: float = 0.25
var materials: Dictionary[String, ShaderMaterial] = {}
## The same colours without the reveal: occluders no subject is behind draw in one opaque
## pass, so a phone keeps its early depth test and skips two passes over every building.
var plain_materials: Dictionary[String, ShaderMaterial] = {}
var subjects := PackedVector4Array()
var roots: Array[Node3D] = []
## Every occluder surface: its node, its reveal and plain material.
var surfaces: Array[Dictionary] = []
## The surfaces drawing the reveal material now (index -> true).
var revealing: Dictionary[int, bool] = {}
## Screen-plane cells -> surface indices, for the camera angle `_grid_key` (built once the
## camera has held an angle for two frames, then kept per angle; while it turns, every
## surface reveals).
var _grid: Dictionary[Vector2i, Array] = {}
var _grid_key: String = ""
var _grid_extents := PackedVector4Array()
var _grids: Dictionary[String, Array] = {}
var _last_key: String = ""

func register(root: Node3D) -> void:
	roots.append(root)
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		if not (node is MultiMeshInstance3D or node is MeshInstance3D):
			continue
		var mesh := node as GeometryInstance3D
		var original := mesh.material_override as StandardMaterial3D
		# A merged batch's shadow-only caster (VoxelShapes) keeps casting as it is.
		if original == null or mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var emission: Color = original.emission*original.emission_energy_multiplier if original.emission_enabled else Color.BLACK
		var key: String = original.albedo_color.to_html()+str(original.vertex_color_use_as_albedo)+emission.to_html()+str(original.get_meta("night_only",false))
		if not materials.has(key):
			var material := ShaderMaterial.new()
			material.shader = SHADER
			material.set_shader_parameter("tint", original.albedo_color)
			var blend := ShaderMaterial.new()
			blend.shader = BLEND
			blend.set_shader_parameter("tint", original.albedo_color)
			var depth := ShaderMaterial.new()
			depth.shader = DEPTH
			depth.render_priority = -100
			blend.render_priority = -99
			material.next_pass = depth
			depth.next_pass = blend
			for pass_material: ShaderMaterial in [material,blend]:
				pass_material.set_shader_parameter("vertex_tint",original.vertex_color_use_as_albedo)
				pass_material.set_shader_parameter("emission_tint",emission)
				pass_material.set_shader_parameter("night_only",original.get_meta("night_only",false))
			materials[key] = material
			var plain := ShaderMaterial.new()
			plain.shader = PLAIN
			plain.set_shader_parameter("tint", original.albedo_color)
			plain.set_shader_parameter("vertex_tint",original.vertex_color_use_as_albedo)
			plain.set_shader_parameter("emission_tint",emission)
			plain.set_shader_parameter("night_only",original.get_meta("night_only",false))
			plain_materials[key] = plain
		# The blended colour pass must not erase sunlight shadows as the player moves.
		if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			var shadow: GeometryInstance3D
			if mesh is MultiMeshInstance3D:
				shadow = MultiMeshInstance3D.new()
				(shadow as MultiMeshInstance3D).multimesh = (mesh as MultiMeshInstance3D).multimesh
			else:
				shadow = MeshInstance3D.new()
				(shadow as MeshInstance3D).mesh = (mesh as MeshInstance3D).mesh
			shadow.material_override = original
			shadow.transform = mesh.transform
			shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			mesh.get_parent().add_child(shadow)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.material_override = materials[key]
		revealing[surfaces.size()] = true
		surfaces.append({"node":mesh,"reveal":materials[key],"plain":plain_materials[key]})
	_grid_key = ""
	_grids.clear()

func set_night(amount: float) -> void:
	for material: ShaderMaterial in materials.values():
		for pass_material: ShaderMaterial in _passes(material):
			pass_material.set_shader_parameter("night_amount",amount)
	for material: ShaderMaterial in plain_materials.values():
		material.set_shader_parameter("night_amount",amount)

func _passes(first: ShaderMaterial) -> Array[ShaderMaterial]:
	var result: Array[ShaderMaterial] = []
	var material: ShaderMaterial = first
	while material!=null:
		result.append(material)
		material = material.next_pass as ShaderMaterial
	return result

func update(camera: Camera3D, points: PackedVector4Array) -> void:
	subjects = points.slice(0, LIMIT)
	var padded: PackedVector4Array = subjects.duplicate()
	padded.resize(LIMIT)
	for material: ShaderMaterial in materials.values():
		for pass_material: ShaderMaterial in _passes(material):
			pass_material.set_shader_parameter("eye_right", camera.global_basis.x)
			pass_material.set_shader_parameter("eye_up", camera.global_basis.y)
			pass_material.set_shader_parameter("toward_eye", camera.global_basis.z)
			pass_material.set_shader_parameter("subjects", padded)
			pass_material.set_shader_parameter("subject_count", subjects.size())
	_choose_materials(camera)

## Reveal only the surfaces a subject can be behind (local_reveal's test against each
## surface's box in the camera plane); the rest draw plain. Occluders stay where they were
## built (shutters and cutaways only show or hide; flames sway within PAD).
func _choose_materials(camera: Camera3D) -> void:
	var basis: Basis = camera.global_basis
	var key: String = "%.4f,%.4f,%.4f" % [basis.z.x, basis.z.y, basis.z.z]
	var stable: bool = key == _last_key
	_last_key = key
	var wanted: Dictionary[int, bool] = {}
	if not stable:
		for index: int in surfaces.size():
			wanted[index] = true
	else:
		if key != _grid_key:
			if not _grids.has(key):
				_build_grid(basis)
				_grids[key] = [_grid, _grid_extents]
			_grid = _grids[key][0]
			_grid_extents = _grids[key][1]
			_grid_key = key
		for subject: Vector4 in subjects:
			var at := Vector3(subject.x, subject.y, subject.z)
			var right: float = at.dot(basis.x)
			var up: float = at.dot(basis.y)
			var depth: float = at.dot(basis.z)
			var reach := Vector2(subject.w, subject.w*1.25)
			for x: int in range(floori((right-reach.x)/CELL), floori((right+reach.x)/CELL)+1):
				for y: int in range(floori((up-reach.y)/CELL), floori((up+reach.y)/CELL)+1):
					for index: int in _grid.get(Vector2i(x, y), []):
						var extent: Vector4 = _grid_extents[index*2]
						var far: Vector4 = _grid_extents[index*2+1]
						if extent.x <= right+reach.x and extent.y >= right-reach.x and extent.z <= up+reach.y and extent.w >= up-reach.y and far.x > depth+0.1:
							wanted[index] = true
	for index: int in revealing:
		if not wanted.has(index):
			(surfaces[index]["node"] as GeometryInstance3D).material_override = surfaces[index]["plain"]
	for index: int in wanted:
		if not revealing.has(index):
			(surfaces[index]["node"] as GeometryInstance3D).material_override = surfaces[index]["reveal"]
	revealing = wanted

func _build_grid(basis: Basis) -> void:
	_grid = {}
	_grid_extents = PackedVector4Array()
	_grid_extents.resize(surfaces.size()*2)
	for index: int in surfaces.size():
		var node := surfaces[index]["node"] as GeometryInstance3D
		var box: AABB = node.global_transform*node.get_aabb()
		var centre: Vector3 = box.get_center()
		var half: Vector3 = box.size*0.5
		var spans: Array[float] = []
		for axis: Vector3 in [basis.x, basis.y, basis.z]:
			spans.append(centre.dot(axis))
			spans.append(absf(half.x*axis.x)+absf(half.y*axis.y)+absf(half.z*axis.z)+PAD)
		var extent := Vector4(spans[0]-spans[1], spans[0]+spans[1], spans[2]-spans[3], spans[2]+spans[3])
		_grid_extents[index*2] = extent
		_grid_extents[index*2+1] = Vector4(spans[4]+spans[5], 0, 0, 0)
		for x: int in range(floori(extent.x/CELL), floori(extent.y/CELL)+1):
			for y: int in range(floori(extent.z/CELL), floori(extent.w/CELL)+1):
				var cell := Vector2i(x, y)
				if not _grid.has(cell):
					_grid[cell] = []
				_grid[cell].append(index)
