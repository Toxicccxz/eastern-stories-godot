class_name VoxelOcclusion
extends RefCounted

## Only the pixels between a subject and the fixed camera open, as a screen-door pattern of
## dots (owner 2026-11-10, after pixel-art games' dithered see-through). The rest of each
## object, its collision and its shadow remain intact. State belongs to this map.
const SHADER = preload("res://presentation/voxel/shaders/local_occlusion.gdshader")
const PLAIN = preload("res://presentation/voxel/shaders/local_occlusion_plain.gdshader")
const LIMIT: int = 16
## Side of a cell of the screen-plane grid that finds the occluders a subject may be behind
## (plain_when_clear), and the slack around each surface's box (flames sway a little; the
## camera's angle is matched to four decimals).
const CELL: float = 3.0
const PAD: float = 0.25
## The share of an occluder's pixels left out at the heart of an opening (owner 2026-11-10:
## the nearer the middle, the clearer; fully clear was a touch too much): over the person two
## dots in sixteen stay, and the dots thicken evenly to solid at the rim.
const HOLES: float = 0.9
var materials: Dictionary[String, ShaderMaterial] = {}
var subjects := PackedVector4Array()
var roots: Array[Node3D] = []
## 战斗演出 (owner, 2026-11-12: the gorge's walls hid a stage raised in it): a show's space — a
## fight's stage over the map, from its foot to over the fighters' heads — that every occluder
## standing in it or between it and the eye gives way to outright, with a rim of dots
## (occlusion_mask: show_reveal). Empty: none.
var show: Dictionary = {}
## Materials that are no occluder but give way to the show too (the meadow's grass).
var _sharing: Array[ShaderMaterial] = []
## Plain occluders (DECISIONS「手机画质」; the view sets it from the 画质): an occluder no subject
## can stand behind draws with its plain material — the same surface without the see-through, so
## a phone's GPU neither searches the subjects for every pixel of every building nor loses its
## early depth test to the dots' discard; only the surfaces a subject may be behind wear the
## see-through, and every one does while the camera turns or a show is held. False: every
## occluder wears it (the desktop).
var plain_when_clear: bool = false:
	set(value):
		plain_when_clear = value
		if not value:
			_reveal_all()
var plain_materials: Dictionary[String, ShaderMaterial] = {}
## Every occluder surface: its node, its see-through and its plain material, and whether it may
## move (a door's leaf: always see-through).
var surfaces: Array[Dictionary] = []
## The surfaces wearing their plain material now (index -> true).
var plain: Dictionary[int, bool] = {}
## The surfaces a subject may be behind at the last choice; false until a choice has set every
## surface (after a registration, a turn of the camera, a show): then only changes are worn.
var _behind: Dictionary[int, bool] = {}
var _chosen: bool = false
## Screen-plane cells -> surface indices for the camera's angle `_grid_key`, kept per angle.
var _grid: Dictionary[Vector2i, Array] = {}
var _grid_key: String = ""
var _extents := PackedVector4Array()
var _grids: Dictionary[String, Array] = {}
var _last_key: String = ""

## `moves`: a part that swings or slides (a door's leaf, a shutter) keeps the see-through always,
## its box not being where it was built.
func register(root: Node3D, moves: bool = false) -> void:
	roots.append(root)
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		if not (node is MultiMeshInstance3D or node is MeshInstance3D):
			continue
		var mesh := node as GeometryInstance3D
		var original := mesh.material_override as StandardMaterial3D
		if original == null:
			continue
		var emission: Color = original.emission*original.emission_energy_multiplier if original.emission_enabled else Color.BLACK
		var key: String = original.albedo_color.to_html()+str(original.vertex_color_use_as_albedo)+emission.to_html()+str(original.get_meta("night_only",false))
		if not materials.has(key):
			var material := ShaderMaterial.new()
			material.shader = SHADER
			material.set_shader_parameter("tint", original.albedo_color)
			material.set_shader_parameter("vertex_tint",original.vertex_color_use_as_albedo)
			material.set_shader_parameter("emission_tint",emission)
			material.set_shader_parameter("night_only",original.get_meta("night_only",false))
			material.set_shader_parameter("holes",HOLES)
			_show_on(material)
			materials[key] = material
			var flat := ShaderMaterial.new()
			flat.shader = PLAIN
			flat.set_shader_parameter("tint", original.albedo_color)
			flat.set_shader_parameter("vertex_tint",original.vertex_color_use_as_albedo)
			flat.set_shader_parameter("emission_tint",emission)
			flat.set_shader_parameter("night_only",original.get_meta("night_only",false))
			plain_materials[key] = flat
		# The opening's dots must not punch holes in sunlight shadows as the player moves.
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
		surfaces.append({"node": mesh, "reveal": materials[key], "plain": plain_materials[key], "moves": moves})
	_grid_key = ""
	_grids.clear()
	_chosen = false

## Holds the show's space: `stage` the stage's transform in the world (its middle and foot, its
## turn), `footprint` in its own frame (units; x along its x, y along its z) and `low` .. `high`
## its height over the foot.
func hold_show(stage: Transform3D, footprint: Rect2, low: float, high: float) -> void:
	show = {"inverse": Projection(stage.affine_inverse()), "box": Vector4(footprint.position.x, footprint.position.y, footprint.end.x, footprint.end.y), "span": Vector2(low, high)}
	for material: ShaderMaterial in materials.values():
		_show_on(material)
	for material: ShaderMaterial in _sharing:
		_show_on(material)

## The show is over: every occluder whole again (but where a person opens it).
func clear_show() -> void:
	show = {}
	for material: ShaderMaterial in materials.values():
		_show_on(material)
	for material: ShaderMaterial in _sharing:
		_show_on(material)

## `material` (its shader includes show_space) gives way to the show as the occluders do.
func share_show(material: ShaderMaterial) -> void:
	if material != null and not _sharing.has(material):
		_sharing.append(material)
		_show_on(material)

func _show_on(material: ShaderMaterial) -> void:
	material.set_shader_parameter("show_on", 0.0 if show.is_empty() else 1.0)
	if not show.is_empty():
		material.set_shader_parameter("show_inverse", show["inverse"])
		material.set_shader_parameter("show_box", show["box"])
		material.set_shader_parameter("show_span", show["span"])

func set_night(amount: float) -> void:
	for material: ShaderMaterial in materials.values():
		material.set_shader_parameter("night_amount",amount)
	for material: ShaderMaterial in plain_materials.values():
		material.set_shader_parameter("night_amount",amount)

func update(camera: Camera3D, points: PackedVector4Array) -> void:
	subjects = points.slice(0, LIMIT)
	var padded: PackedVector4Array = subjects.duplicate()
	padded.resize(LIMIT)
	for material: ShaderMaterial in materials.values():
		material.set_shader_parameter("eye_right", camera.global_basis.x)
		material.set_shader_parameter("eye_up", camera.global_basis.y)
		material.set_shader_parameter("toward_eye", camera.global_basis.z)
		material.set_shader_parameter("subjects", padded)
		material.set_shader_parameter("subject_count", subjects.size())
	if plain_when_clear:
		_choose_materials(camera)

## plain_when_clear, under the loading screen: the grid for `camera`'s angle and every surface on
## its plain material (no one stands anywhere yet), so the first frame shown only puts the few a
## subject is behind on their see-through.
func prepare(camera: Camera3D) -> void:
	var basis: Basis = camera.global_basis
	var key: String = "%.4f,%.4f,%.4f" % [basis.z.x, basis.z.y, basis.z.z]
	if not _grids.has(key):
		_build_grid(basis)
		_grids[key] = [_grid, _extents]
	_grid = _grids[key][0]
	_extents = _grids[key][1]
	_grid_key = key
	_last_key = key
	for index: int in surfaces.size():
		_wear(index, true)
	_behind.clear()
	_chosen = true

## plain_when_clear: the see-through only on the surfaces a subject may be behind — its box in
## the camera's plane overlapping the subject's opening (local_reveal's reach: the subject's `w`
## across, 1.25 times that up) and some of it nearer the eye than the subject. Every surface
## wears it while the camera turns (its angle not yet held for two frames) or a show is held.
func _choose_materials(camera: Camera3D) -> void:
	var basis: Basis = camera.global_basis
	var key: String = "%.4f,%.4f,%.4f" % [basis.z.x, basis.z.y, basis.z.z]
	var held: bool = key == _last_key
	_last_key = key
	if not held or not show.is_empty():
		_reveal_all()
		return
	if key != _grid_key:
		if not _grids.has(key):
			_build_grid(basis)
			_grids[key] = [_grid, _extents]
		_grid = _grids[key][0]
		_extents = _grids[key][1]
		_grid_key = key
	var behind: Dictionary[int, bool] = {}
	for subject: Vector4 in subjects:
		var at := Vector3(subject.x, subject.y, subject.z)
		var right: float = at.dot(basis.x)
		var up: float = at.dot(basis.y)
		var depth: float = at.dot(basis.z)
		var reach := Vector2(subject.w, subject.w*1.25)
		for x: int in range(floori((right-reach.x)/CELL), floori((right+reach.x)/CELL)+1):
			for y: int in range(floori((up-reach.y)/CELL), floori((up+reach.y)/CELL)+1):
				for index: int in _grid.get(Vector2i(x, y), []):
					var span: Vector4 = _extents[index*2]
					if span.x <= right+reach.x and span.y >= right-reach.x and span.z <= up+reach.y and span.w >= up-reach.y and _extents[index*2+1].x > depth+0.1:
						behind[index] = true
	if not _chosen:
		_chosen = true
		for index: int in surfaces.size():
			_wear(index, not behind.has(index))
	else:
		for index: int in _behind:
			if not behind.has(index):
				_wear(index, true)
		for index: int in behind:
			if not _behind.has(index):
				_wear(index, false)
	_behind = behind

## Surface `index` on its plain material (`flat`) or its see-through; a moving part always sees
## through.
func _wear(index: int, flat: bool) -> void:
	var surface: Dictionary = surfaces[index]
	if bool(surface["moves"]):
		flat = false
	if flat == plain.has(index):
		return
	var node := surface["node"] as GeometryInstance3D
	if not is_instance_valid(node):
		return
	node.material_override = surface["plain"] if flat else surface["reveal"]
	if flat:
		plain[index] = true
	else:
		plain.erase(index)

## Every surface back on its see-through material (the camera turning, a show, the switch off);
## the next choice sets them all again.
func _reveal_all() -> void:
	for index: int in plain:
		var node := surfaces[index]["node"] as GeometryInstance3D
		if is_instance_valid(node):
			node.material_override = surfaces[index]["reveal"]
	plain.clear()
	_behind.clear()
	_chosen = false

## Each surface's box in the camera's plane (right and up spans, and how near the eye it comes),
## and the cells of CELL it covers.
func _build_grid(basis: Basis) -> void:
	_grid = {}
	_extents = PackedVector4Array()
	_extents.resize(surfaces.size()*2)
	for index: int in surfaces.size():
		var node := surfaces[index]["node"] as GeometryInstance3D
		if not is_instance_valid(node):
			continue
		var box: AABB = node.global_transform*node.get_aabb()
		var centre: Vector3 = box.get_center()
		var half: Vector3 = box.size*0.5
		var spans: Array[float] = []
		for axis: Vector3 in [basis.x, basis.y, basis.z]:
			spans.append(centre.dot(axis))
			spans.append(absf(half.x*axis.x)+absf(half.y*axis.y)+absf(half.z*axis.z)+PAD)
		var span := Vector4(spans[0]-spans[1], spans[0]+spans[1], spans[2]-spans[3], spans[2]+spans[3])
		_extents[index*2] = span
		_extents[index*2+1] = Vector4(spans[4]+spans[5], 0, 0, 0)
		for x: int in range(floori(span.x/CELL), floori(span.y/CELL)+1):
			for y: int in range(floori(span.z/CELL), floori(span.w/CELL)+1):
				var cell := Vector2i(x, y)
				if not _grid.has(cell):
					_grid[cell] = []
				(_grid[cell] as Array).append(index)
