class_name VoxelFoliage
extends Node3D

## Instanced meadow tufts: rooted wind motion and local actor contact with a short
## fading trail. Nothing here adds collision, consumes gameplay RNG or enters saves.
const SHADER = preload("res://presentation/voxel/shaders/meadow.gdshader")
const CONTACT_LIMIT: int = 32
var colors: Array = []
var butterfly_count: int = 8
var material: ShaderMaterial
var roots := PackedVector3Array()
var flowers := PackedVector3Array()
var contacts := PackedVector4Array()
var trails: Array[Vector4] = []
var clock: float = 0.0
var _last: Dictionary[int, Vector3] = {}
var _batches: Dictionary[String, Array] = {}
var _meshes: Dictionary[int, ArrayMesh] = {}
var butterflies: Array[Node3D] = []
var _butterfly_homes := PackedVector3Array()
var _near: Vector3 = Vector3.INF

func plant(at: Vector3, kind: int, size: float, angle: float) -> void:
	var chunk := Vector2i(floori(at.x / 8.0), floori(at.z / 8.0))
	var key: String = "%d:%d:%d" % [chunk.x, chunk.y, kind]
	if not _batches.has(key):
		_batches[key] = [kind, []]
	(_batches[key][1] as Array).append(Transform3D(Basis(Vector3.UP, angle).scaled(Vector3.ONE * size), at))
	roots.append(at)
	if kind > 0 and kind < 5:
		flowers.append(at)

func finish() -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER
	for batch: Array in _batches.values():
		var kind: int = batch[0]
		if not _meshes.has(kind):
			_meshes[kind] = _tuft(kind)
		var transforms: Array = batch[1]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _meshes[kind]
		multi.instance_count = transforms.size()
		for i: int in transforms.size():
			multi.set_instance_transform(i, transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.material_override = material
		instance.extra_cull_margin = 1.0
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	_batches.clear()
	_make_butterflies()

func advance(delta: float, positions: PackedVector3Array) -> void:
	clock += delta
	for i: int in range(trails.size() - 1, -1, -1):
		trails[i].w = maxf(0.0, trails[i].w - delta / 0.85)
		if trails[i].w <= 0.0:
			trails.remove_at(i)
	contacts.clear()
	for i: int in mini(positions.size(), 16):
		var p: Vector3 = positions[i]
		contacts.append(Vector4(p.x, p.y, p.z, 1.0))
		if _last.has(i) and p.distance_to(_last[i]) > 0.24:
			var old: Vector3 = _last[i]
			if p.distance_to(old) < 2.0:
				trails.push_front(Vector4(old.x, old.y, old.z, 1.0))
			_last[i] = p
		elif not _last.has(i):
			_last[i] = p
	trails.resize(mini(trails.size(), 16))
	for trail: Vector4 in trails:
		if contacts.size() < CONTACT_LIMIT:
			contacts.append(trail)
	var padded: PackedVector4Array = contacts.duplicate()
	padded.resize(CONTACT_LIMIT)
	material.set_shader_parameter("contacts", padded)
	material.set_shader_parameter("contact_count", contacts.size())
	material.set_shader_parameter("wind_clock", clock)
	if not positions.is_empty():
		_animate_butterflies(positions[0])

func _tuft(kind: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var greens: Array[String] = ["3e6947", "60884d", "8da85d", "b1b96d"]
	if not colors.is_empty():
		greens.assign(colors)
	for blade: int in 5:
		var angle: float = blade * TAU / 5.0 + kind * 0.3
		var direction := Vector3(sin(angle), 0, cos(angle))
		var height: float = 0.35 + (blade % 3) * 0.16
		_blade(surface,direction,height,greens,blade)
	if kind == 5:
		# Broad low fern fronds form an intermediate layer below the tree canopy.
		for frond: int in 7:
			var angle: float = frond*TAU/7.0
			for leaf: int in 4:
				var distance: float = 0.13+leaf*0.13
				var at := Vector3(sin(angle)*distance,0.75-leaf*0.12-frond*0.009,cos(angle)*distance)
				_box(surface,at,Vector3(0.22-leaf*0.03,0.08,0.23-leaf*0.03),Color(greens[(frond+leaf)%4]))
	elif kind > 0:
		var color: Color = [Color("f2e8c5"), Color("edc26b"), Color("dba4b9"), Color("a7a2cf")][(kind - 1) % 4]
		for stem: int in 2:
			var at := Vector3(-0.12 if stem == 0 else 0.17, 0, 0.1 * stem)
			var height: float = 0.65 + stem * 0.19
			_box(surface, at + Vector3.UP * height / 2.0, Vector3(0.045, height, 0.045), Color("698854"))
			# Four disjoint petals meet the centre instead of overlapping five boxes.
			for direction: Vector3 in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
				_box(surface,at+direction*0.115+Vector3.UP*height,Vector3(0.11,0.045,0.11),color)
			_box(surface, at + Vector3.UP * (height + 0.035), Vector3(0.095, 0.055, 0.095), Color("c99542"))
	surface.index()
	return surface.commit()

static func _blade(surface: SurfaceTool, direction: Vector3, height: float, greens: Array[String], blade: int) -> void:
	# A continuous tapered prism: no segment caps, intersecting steps or coplanar tops.
	var across: Vector3 = direction.cross(Vector3.UP)
	for segment: int in 3:
		var rings: Array[PackedVector3Array] = []
		for station: int in [segment,segment+1]:
			var t: float = station/3.0
			var center: Vector3 = direction*(0.06+t*t*0.24)+Vector3.UP*(0.012+height*t)
			var width: float = lerpf(0.10,0.018,t)*0.5
			var thickness: float = lerpf(0.055,0.018,t)*0.5
			rings.append(PackedVector3Array([center-across*width-direction*thickness,center+across*width-direction*thickness,center+across*width+direction*thickness,center-across*width+direction*thickness]))
		for side: int in 4:
			var next: int = (side+1)%4
			var a: Vector3 = rings[0][side]
			var b: Vector3 = rings[0][next]
			var c: Vector3 = rings[1][next]
			var d: Vector3 = rings[1][side]
			surface.set_color(Color(greens[(blade+segment)%4]).srgb_to_linear())
			surface.set_normal((c-a).cross(b-a).normalized())
			for p: Vector3 in [a,b,c,a,c,d]:
				surface.add_vertex(p)
		if segment==2:
			surface.set_normal(Vector3.UP)
			for index: int in [0,2,1,0,3,2]:
				surface.add_vertex(rings[1][index])

static func _box(surface: SurfaceTool, at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var arrays: Array = mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index: int in indices:
		surface.set_color(color.srgb_to_linear())
		surface.set_normal(normals[index])
		surface.add_vertex(vertices[index] + at)

func _make_butterflies() -> void:
	var shapes := preload("res://presentation/voxel/props/voxel_shapes.gd").new()
	for i: int in butterfly_count:
		var insect := Node3D.new()
		add_child(insect)
		butterflies.append(insect)
		_butterfly_homes.append(Vector3.ZERO)
		for side: float in [-1.0, 1.0]:
			var wing := Node3D.new()
			insect.add_child(wing)
			shapes.box(wing, Vector3(side * 0.09, 0, 0), Vector3(0.16, 0.025, 0.22), "f2e3ac" if i % 2 else "d6b8cd")
	shapes.flush()

func _animate_butterflies(player: Vector3) -> void:
	if not _near.is_finite() or player.distance_to(_near) > 6.0:
		_near = player
		var nearby := PackedVector3Array()
		for i: int in range(0, flowers.size(), 7):
			if flowers[i].distance_squared_to(player) < 100:
				nearby.append(flowers[i])
		for i: int in butterflies.size():
			butterflies[i].visible = not nearby.is_empty()
			if not nearby.is_empty():
				_butterfly_homes[i] = nearby[(i * 17) % nearby.size()]
	for i: int in butterflies.size():
		var t: float = clock + i * 2.1
		butterflies[i].position = _butterfly_homes[i] + Vector3(sin(t * 0.7) * 0.8, 0.9 + sin(t * 1.8) * 0.25, cos(t * 0.6) * 0.6)
		butterflies[i].rotation.y = -t * 0.7
		for side: int in 2:
			(butterflies[i].get_child(side) as Node3D).rotation.z = sin(t * 17.0) * 0.85 * (1 if side else -1)
