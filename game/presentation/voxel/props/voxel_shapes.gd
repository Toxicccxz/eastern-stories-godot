extends RefCounted

## Small authored voxel forms, batched by material; only large footprints get collisions.
var batches: Dictionary = {}
var materials: Dictionary = {}
var cube := BoxMesh.new()
var stones: Dictionary[int, ArrayMesh] = {}
var spatial_batching: bool = false
var spatial_cell_size: float = 12.0
## Placed in front of every form drawn while set: many trees share one grove parent (and so
## one batch per colour) yet each keeps its own position, turn and size.
var frame := Transform3D.IDENTITY

## A colour key; "<hex>:gloss" is the same colour, wet and shiny (its own material).
func color(hex: String) -> Color:
	return Color.html(hex.get_slice(":",0))

func box(parent: Node3D, at: Vector3, size: Vector3, hex: String) -> void:
	_instance(parent, Transform3D(Basis.from_scale(size), at), hex, cube)

func tilted_box(parent: Node3D, at: Vector3, size: Vector3, hex: String, angles: Vector3) -> void:
	_instance(parent, Transform3D(Basis.from_euler(angles).scaled_local(size), at), hex, cube)

func shard(parent: Node3D, at: Vector3, size: Vector3, hex: String, variant: int, yaw: float = 0.0) -> void:
	# Reusable chipped, bevelled stones. Variants change silhouette, not just colour.
	variant = posmod(variant, 8)
	if not stones.has(variant):
		stones[variant] = _stone_mesh(variant)
	_instance(parent, Transform3D(Basis(Vector3.UP, yaw).scaled_local(size), at), hex, stones[variant])

func _instance(parent: Node3D, transform: Transform3D, hex: String, mesh: Mesh) -> void:
	transform = frame*transform
	var key: String = str(parent.get_instance_id()) + hex + str(mesh.get_instance_id())
	if spatial_batching:
		# Mobile lighting chooses lights per instance. A map-wide ground instance
		# otherwise exceeds that budget and changes lights abruptly while walking.
		key += ":%d:%d" % [floori(transform.origin.x/spatial_cell_size),floori(transform.origin.z/spatial_cell_size)]
	if not batches.has(key):
		batches[key] = {"parent":parent,"color":hex,"mesh":mesh,"transforms":[]}
	var transforms: Array = batches[key]["transforms"]
	transforms.append(transform)

func _stone_mesh(variant: int) -> ArrayMesh:
	var random := RandomNumberGenerator.new()
	random.seed = 193 + variant * 97
	var corners := PackedVector2Array([
		Vector2(-0.5,-0.32), Vector2(-0.30,-0.5), Vector2(0.30,-0.5), Vector2(0.5,-0.31),
		Vector2(0.5,0.30), Vector2(0.31,0.5), Vector2(-0.33,0.5), Vector2(-0.5,0.32)])
	for i: int in corners.size():
		corners[i] += Vector2(random.randf_range(-0.065,0.065), random.randf_range(-0.065,0.065))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i+1)%corners.size()]
		var top_a := Vector3(a.x*0.91,0.5,a.y*0.91)
		var top_b := Vector3(b.x*0.91,0.5,b.y*0.91)
		var rim_a := Vector3(a.x,0.12,a.y)
		var rim_b := Vector3(b.x,0.12,b.y)
		var low_a := Vector3(a.x,-0.5,a.y)
		var low_b := Vector3(b.x,-0.5,b.y)
		for triangle: Array in [[Vector3(0,0.5,0),top_a,top_b], [top_a,rim_a,rim_b], [top_a,rim_b,top_b], [rim_a,low_a,low_b], [rim_a,low_b,rim_b]]:
			var normal: Vector3 = ((triangle[2] as Vector3)-(triangle[0] as Vector3)).cross((triangle[1] as Vector3)-(triangle[0] as Vector3)).normalized()
			surface.set_normal(normal)
			for vertex: Vector3 in triangle:
				surface.add_vertex(vertex)
	return surface.commit()

func flush(light_bounds: Array[AABB] = []) -> void:
	for key: String in batches:
		var entry: Dictionary = batches[key]
		_flush_batch(entry,entry["transforms"],light_bounds)
	batches.clear()

func _flush_batch(entry: Dictionary, transforms: Array, light_bounds: Array[AABB], depth: int = 0) -> void:
	var mesh: Mesh = entry["mesh"]
	var parent: Node3D = entry["parent"]
	if not light_bounds.is_empty() and depth<12:
		var bounds: AABB = (transforms[0] as Transform3D)*mesh.get_aabb()
		for i: int in range(1,transforms.size()):
			bounds = bounds.merge((transforms[i] as Transform3D)*mesh.get_aabb())
		var world_bounds: AABB = parent.global_transform*bounds
		var overlaps: int = 0
		for light: AABB in light_bounds:
			if world_bounds.intersects(light):
				overlaps += 1
			if overlaps>8:
				break
		if overlaps>8:
			if transforms.size()>1:
				var axis: int = bounds.size.max_axis_index()
				transforms.sort_custom(func(a: Transform3D,b: Transform3D) -> bool: return a.origin[axis]<b.origin[axis])
				var middle: int = transforms.size()/2
				_flush_batch(entry,transforms.slice(0,middle),light_bounds,depth+1)
				_flush_batch(entry,transforms.slice(middle),light_bounds,depth+1)
				return
			# Long plinths and beams are one box, but must not collect the lights of
			# an entire building. Subdivide without moving or overlapping their faces.
			var transform: Transform3D = transforms[0]
			var size: Vector3 = transform.basis.get_scale().abs()
			var axis: int = size.max_axis_index()
			if mesh==cube and size[axis]>1.0:
				var offset: Vector3 = transform.basis[axis]*0.25
				transform.basis[axis] *= 0.5
				transform.origin -= offset
				_flush_batch(entry,[transform],light_bounds,depth+1)
				transform.origin += offset*2.0
				_flush_batch(entry,[transform],light_bounds,depth+1)
				return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i: int in transforms.size():
		multi.set_instance_transform(i,transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = material(entry["color"])
	# The ground's own boxes and stones lie flat: their shadows would fall on nothing, yet they
	# would fill every shadow map pass (meta `flat` on the parent they are drawn into).
	if entry["color"] in ["ffd88a","ffb858"] or parent.get_meta("light_fixture",false) or parent.get_meta("flat",false):
		# Tiny opaque lantern caps otherwise project enormous square shadows from
		# the point source inside them. The housing represents a diffuse emitter.
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

func material(hex: String) -> StandardMaterial3D:
	if not materials.has(hex):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color(hex)
		mat.roughness = 0.93
		if hex.ends_with(":gloss"):
			mat.roughness = 0.08
			mat.metallic = 0.3
		if hex == "ffd88a" or hex == "ffb858":
			mat.emission_enabled = true
			mat.emission = color(hex)
			mat.emission_energy_multiplier = 1.5
		materials[hex] = mat
	return materials[hex]

func solid(parent: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body

func lantern(parent: Node3D, at: Vector3, standing: bool = false) -> void:
	var housing := Node3D.new()
	housing.set_meta("light_fixture",true)
	parent.add_child(housing)
	if standing:
		box(housing,at+Vector3(0,-0.65,0),Vector3(0.12,1.3,0.12),"483b32")
	box(housing,at,Vector3(0.34,0.45,0.34),"ffb858")
	for y: float in [-0.25,0.25]:
		box(housing,at+Vector3(0,y,0),Vector3(0.44,0.07,0.44),"993f35")
	for x: float in [-0.17,0.17]:
		box(housing,at+Vector3(x,0,0.175),Vector3(0.045,0.44,0.04),"ba613c")
	box(housing,at+Vector3(0,-0.36,0),Vector3(0.06,0.16,0.06),"b54135")
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color("ffbd72")
	lamp.light_energy = 1.1
	lamp.omni_range = 3.2
	lamp.set_meta("night_energy",2.8)
	lamp.set_meta("day_energy",1.1)
	parent.add_child(lamp)

func window(parent: Node3D, at: Vector3, size: Vector3) -> void:
	box(parent,at,size,"d7bb88")
	var mat: StandardMaterial3D = material("d7bb88")
	mat.emission_enabled = true
	mat.emission = Color("ffbb6e")
	mat.emission_energy_multiplier = 0.9
	mat.set_meta("night_only",true)

func pot(parent: Node3D, at: Vector3, green: bool = true) -> void:
	box(parent,at+Vector3(0,0.22,0),Vector3(0.44,0.42,0.44),"8b5440")
	box(parent,at+Vector3(0,0.43,0),Vector3(0.5,0.08,0.5),"be8660")
	box(parent,at+Vector3(0,0.48,0),Vector3(0.37,0.04,0.37),"473b2c")
	if green:
		for i: int in 7:
			var a: float = i*TAU/7
			box(parent,at+Vector3(cos(a)*0.19,0.65+float(i%3)*0.09,sin(a)*0.19),Vector3(0.18,0.4,0.16),["417653","689951","8eaa58"][i%3])

func table(parent: Node3D, at: Vector3) -> void:
	box(parent,at+Vector3(0,0.72,0),Vector3(1.65,0.14,0.95),"ae7049")
	for x: float in [-0.64,0.64]:
		for z: float in [-0.33,0.33]:
			box(parent,at+Vector3(x,0.35,z),Vector3(0.13,0.7,0.13),"654536")
	for z: float in [-0.82,0.82]:
		box(parent,at+Vector3(0,0.38,z),Vector3(1.4,0.1,0.32),"855737")
		for x: float in [-0.5,0.5]:
			box(parent,at+Vector3(x,0.17,z),Vector3(0.12,0.34,0.24),"573c30")
	box(parent,at+Vector3(-0.3,0.83,0),Vector3(0.32,0.06,0.29),"d5d8ba")
	box(parent,at+Vector3(-0.3,0.89,0),Vector3(0.2,0.08,0.17),"b6773f")
	box(parent,at+Vector3(0.32,0.91,0.08),Vector3(0.19,0.25,0.19),"648b83")
	box(parent,at+Vector3(0.44,0.9,0.08),Vector3(0.1,0.08,0.08),"7aaba2")
	box(parent,at+Vector3(0.2,0.84,-0.26),Vector3(0.13,0.1,0.13),"e0dbbd")
	solid(parent,at+Vector3(0,0.4,0),Vector3(1.65,0.8,0.95))
