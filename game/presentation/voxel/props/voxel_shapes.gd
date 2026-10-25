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
## Nodes whose forms go into another node's batches (`merge`): a prop that never moves into
## its neighbourhood's shared node, a facade's parts into the building's body. The same
## picture with one batch per colour there instead of one per part; both nodes must be in
## the tree, posed, before anything is drawn into the first.
var merged: Dictionary[Node3D, Node3D] = {}
## Nodes already as small as a batch cell (a building's body, a neighbourhood of props): their
## batches are not cut again by position.
var compact: Dictionary[Node3D, bool] = {}
## The render profile's batching (phones): plain matte colours of one parent, mesh and cell
## share a batch with a colour per instance, and every shadow caster of a parent, mesh and
## cell, whatever its colour, is one shadow-only batch. Far fewer draws, the same picture.
var merged_batches: bool = VoxelRenderQuality.current().merged_batches
var _tinted: StandardMaterial3D
var _shadow_material: StandardMaterial3D

## A colour key; "<hex>:gloss" is the same colour, wet and shiny (its own material);
## "<hex>:glow" gives off its own light (a red paper lantern, gilt letters catching the sun);
## "<hex>:haze" is seen through, flat, as far hills in the mist (fainter by night); "<hex>:mist"
## is seen through but lit like the land (a cloud sea: white by day, dark blue by night).
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

func merge(node: Node3D, into: Node3D) -> void:
	merged[node] = into
	compact[into] = true

func _instance(parent: Node3D, transform: Transform3D, hex: String, mesh: Mesh) -> void:
	transform = frame*transform
	if merged.has(parent):
		var into: Node3D = merged[parent]
		transform = into.global_transform.affine_inverse()*parent.global_transform*transform
		parent = into
	var cell: String = ""
	if spatial_batching and not compact.has(parent):
		# Mobile lighting chooses lights per instance. A map-wide ground instance
		# otherwise exceeds that budget and changes lights abruptly while walking.
		cell = ":%d:%d" % [floori(transform.origin.x/spatial_cell_size),floori(transform.origin.z/spatial_cell_size)]
	var key: String = str(parent.get_instance_id()) + hex + str(mesh.get_instance_id()) + cell
	if not batches.has(key):
		batches[key] = {"parent":parent,"color":hex,"mesh":mesh,"transforms":[],"cell":cell}
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
	if merged_batches:
		_flush_merged(light_bounds)
		return
	for key: String in batches:
		var entry: Dictionary = batches[key]
		_flush_batch(entry,entry["transforms"],light_bounds)
	batches.clear()

func _flush_merged(light_bounds: Array[AABB]) -> void:
	var tinted: Dictionary = {}
	var casters: Dictionary = {}
	for key: String in batches:
		var entry: Dictionary = batches[key]
		var group: String = str((entry["parent"] as Node3D).get_instance_id())+"|"+str((entry["mesh"] as Mesh).get_instance_id())+String(entry["cell"])
		var shadow: bool = _casts_shadow(entry)
		if shadow:
			if not casters.has(group):
				casters[group] = {"parent":entry["parent"],"mesh":entry["mesh"],"transforms":[]}
			(casters[group]["transforms"] as Array).append_array(entry["transforms"])
		if not _plain(entry):
			entry["shadowless"] = shadow
			_flush_batch(entry,entry["transforms"],light_bounds)
			continue
		if not tinted.has(group):
			tinted[group] = {"parent":entry["parent"],"mesh":entry["mesh"],"color":"","transforms":[],"colors":[],"shadowless":true}
		var linear: Color = color(entry["color"]).srgb_to_linear()
		(tinted[group]["transforms"] as Array).append_array(entry["transforms"])
		for i: int in (entry["transforms"] as Array).size():
			(tinted[group]["colors"] as Array).append(linear)
	for group: String in tinted:
		_flush_batch(tinted[group],tinted[group]["transforms"],light_bounds,0,tinted[group]["colors"])
	if _shadow_material == null and not casters.is_empty():
		_shadow_material = StandardMaterial3D.new()
	for group: String in casters:
		var entry: Dictionary = casters[group]
		var instance := _multimesh(entry["mesh"],entry["transforms"],[])
		instance.material_override = _shadow_material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		(entry["parent"] as Node3D).add_child(instance)
	batches.clear()

## A colour that can share a batch: Shapes' own matte material, left as made by its caller.
func _plain(entry: Dictionary) -> bool:
	var mat: StandardMaterial3D = material(entry["color"])
	return not mat.emission_enabled and mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and is_equal_approx(mat.roughness,0.93) \
		and is_zero_approx(mat.metallic) and mat.get_meta_list().is_empty() and is_equal_approx(mat.albedo_color.a,1.0) \
		and not (entry["parent"] as Node3D).get_meta("light_fixture",false)

func _casts_shadow(entry: Dictionary) -> bool:
	var hex: String = entry["color"]
	return not (hex in ["ffd88a","ffb858"] or hex.ends_with(":glow") or hex.ends_with(":haze") or hex.ends_with(":mist") or (entry["parent"] as Node3D).get_meta("light_fixture",false) \
		or (entry["parent"] as Node3D).get_meta("flat",false)) \
		and material(entry["color"]).transparency==BaseMaterial3D.TRANSPARENCY_DISABLED

func _multimesh(mesh: Mesh, transforms: Array, colors: Array) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not colors.is_empty()
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i: int in transforms.size():
		multi.set_instance_transform(i,transforms[i])
		if not colors.is_empty():
			multi.set_instance_color(i,colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	return instance

func _flush_batch(entry: Dictionary, transforms: Array, light_bounds: Array[AABB], depth: int = 0, colors: Array = []) -> void:
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
				var order: Array = range(transforms.size())
				order.sort_custom(func(a: int,b: int) -> bool: return (transforms[a] as Transform3D).origin[axis]<(transforms[b] as Transform3D).origin[axis])
				var sorted: Array = order.map(func(i: int) -> Transform3D: return transforms[i])
				var tints: Array = [] if colors.is_empty() else order.map(func(i: int) -> Color: return colors[i])
				var middle: int = transforms.size()/2
				_flush_batch(entry,sorted.slice(0,middle),light_bounds,depth+1,tints.slice(0,middle))
				_flush_batch(entry,sorted.slice(middle),light_bounds,depth+1,tints.slice(middle))
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
				_flush_batch(entry,[transform],light_bounds,depth+1,colors)
				transform.origin += offset*2.0
				_flush_batch(entry,[transform],light_bounds,depth+1,colors)
				return
	var instance := _multimesh(mesh,transforms,colors)
	if colors.is_empty():
		instance.material_override = material(entry["color"])
	else:
		if _tinted == null:
			_tinted = StandardMaterial3D.new()
			_tinted.vertex_color_use_as_albedo = true
			_tinted.roughness = 0.93
		instance.material_override = _tinted
	# A merged batch's shadow is drawn by its parent's shadow-only batch.
	# The ground's own boxes and stones lie flat: their shadows would fall on nothing, yet they
	# would fill every shadow map pass (meta `flat` on the parent they are drawn into).
	if entry.get("shadowless",false) or entry["color"] in ["ffd88a","ffb858"] or String(entry["color"]).ends_with(":glow") or String(entry["color"]).ends_with(":haze") \
			or String(entry["color"]).ends_with(":mist") or parent.get_meta("light_fixture",false) or parent.get_meta("flat",false):
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
		if hex.ends_with(":haze"):
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.5
			mat.set_meta("haze",[0.5,0.22])
		if hex.ends_with(":mist"):
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 1.0
			mat.albedo_color.a = 0.55
			mat.set_meta("haze",[0.55,0.4])
		if hex.ends_with(":glow"):
			mat.emission_enabled = true
			mat.emission = color(hex)
			mat.emission_energy_multiplier = 0.9
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

## A paper lantern with its light; `paper` another glowing colour ("d8452f:glow", a red one).
func lantern(parent: Node3D, at: Vector3, standing: bool = false, paper: String = "ffb858") -> void:
	var housing := Node3D.new()
	housing.set_meta("light_fixture",true)
	parent.add_child(housing)
	if standing:
		box(housing,at+Vector3(0,-0.65,0),Vector3(0.12,1.3,0.12),"483b32")
	box(housing,at,Vector3(0.34,0.45,0.34),paper)
	for y: float in [-0.25,0.25]:
		box(housing,at+Vector3(0,y,0),Vector3(0.44,0.07,0.44),"993f35")
	for x: float in [-0.17,0.17]:
		box(housing,at+Vector3(x,0,0.175),Vector3(0.045,0.44,0.04),"ba613c")
	box(housing,at+Vector3(0,-0.36,0),Vector3(0.06,0.16,0.06),"b54135")
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color("ffbd72") if paper == "ffb858" else color(paper).lerp(color("ffbd72"),0.55)
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
