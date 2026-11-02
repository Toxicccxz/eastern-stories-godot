extends RefCounted

## Small authored voxel forms, batched by material; only large footprints get collisions.
var batches: Dictionary = {}
var materials: Dictionary = {}
## One small number per parent, colour and mesh: the parts of a batch's key.
var _slots: Dictionary = {}
var cube := BoxMesh.new()
var stones: Dictionary[int, ArrayMesh] = {}
var _pooled: StandardMaterial3D
const LIGHT_SPLIT_DEPTH: int = 12
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
## A merged node's place in the node it merges into, read when the first form is drawn into it.
var _merged_pose: Dictionary[Node3D, Transform3D] = {}

## A colour key; "<hex>:gloss" is the same colour, wet and shiny (its own material);
## "<hex>:glow" gives off its own light (a red paper lantern, gilt letters catching the sun);
## "<hex>:haze" is seen through, flat, as far hills in the mist (fainter by night); "<hex>:mist"
## is seen through but lit like the land (a cloud sea: white by day, dark blue by night).
func color(hex: String) -> Color:
	return Color.html(hex.get_slice(":",0))

## A seed from a place on the map, the same every build: what varies about a prop (a lantern
## taller than its neighbour, a vat with a crack) follows where it stands, not what was drawn
## before it, so one change elsewhere never reshuffles the whole map.
static func place_seed(x: int, y: int, z: int = 0, salt: int = 0) -> int:
	var h: int = (x*73856093) ^ (y*19349663) ^ (z*83492791) ^ (salt*2654435761)
	h = (h ^ (h >> 13))*1274126177
	return (h ^ (h >> 16)) & 0x7fffffff

## A random source seeded by a spot (units) and a salt.
static func spot_rng(at: Vector3, salt: int = 0) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = place_seed(roundi(at.x*8.0),roundi(at.y*8.0),roundi(at.z*8.0),salt)
	return random

## `hex` shifted a little in brightness and hue (within `amount`), its ":gloss"/":glow" kept:
## paper lanterns of one string that are not quite one colour. The shifts are in coarse steps,
## so a map's many lanterns fall into a few colours (each colour is a batch), not one each.
static func tinted(hex: String, random: RandomNumberGenerator, amount: float = 0.05) -> String:
	var tint: Color = Color.html(hex.get_slice(":",0))
	tint.v = clampf(tint.v+snappedf(random.randf_range(-amount,amount),0.03),0.0,1.0)
	tint.h = fposmod(tint.h+snappedf(random.randf_range(-amount*0.3,amount*0.3),0.01),1.0)
	var suffix: String = hex.substr(hex.find(":")) if hex.contains(":") else ""
	return tint.to_html(false)+suffix

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
		if not _merged_pose.has(parent):
			_merged_pose[parent] = into.global_transform.affine_inverse()*parent.global_transform
		transform = _merged_pose[parent]*transform
		parent = into
	var cell: int = -1
	if spatial_batching and not compact.has(parent):
		# Mobile lighting chooses lights per instance. A map-wide ground instance
		# otherwise exceeds that budget and changes lights abruptly while walking.
		cell = (floori(transform.origin.x/spatial_cell_size)+16384 << 16) | (floori(transform.origin.z/spatial_cell_size) & 0xffff)
	var key := Vector4i(_slot(parent),_slot(hex),_slot(mesh),cell)
	var entry: Variant = batches.get(key)
	if entry == null:
		entry = {"parent":parent,"color":hex,"mesh":mesh,"transforms":[]}
		batches[key] = entry
	(entry["transforms"] as Array).append(transform)

func _slot(thing: Variant) -> int:
	var slot: Variant = _slots.get(thing)
	if slot == null:
		slot = _slots.size()
		_slots[thing] = slot
	return slot

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

## A colour that is only a colour: no glow, no gloss, nothing seen through, and no material
## of its own asked for (`window` and the like make theirs glow by the colour's name).
func _plain(hex: String) -> bool:
	return not hex.contains(":") and hex != "ffd88a" and hex != "ffb858" and not materials.has(hex)

## The batches of one place that differ only in a plain colour become one, its colours per
## instance: a town's hundreds of colours are hundreds of nodes and buffers per street block
## otherwise, most of them a stone or two (DECISIONS「搭建开销」). The same picture: colours,
## place and shape are the same, and the light-aware split still applies. Once everything is
## drawn, so that any colour made to glow on the way stays out.
func pool_plain_colours() -> void:
	var pooled: Dictionary = {}
	for key: Vector4i in batches:
		var entry: Dictionary = batches[key]
		var hex: String = entry["color"]
		if not _plain(hex):
			pooled[key] = entry
			continue
		var place := Vector4i(key.x,-1,key.z,key.w)
		if not pooled.has(place):
			pooled[place] = {"parent":entry["parent"],"color":"","mesh":entry["mesh"],"transforms":[],"colors":PackedColorArray()}
		var into: Dictionary = pooled[place]
		var transforms: Array = entry["transforms"]
		(into["transforms"] as Array).append_array(transforms)
		# Instance colours are multiplied in as they are; a material's albedo is taken as sRGB.
		var run := PackedColorArray()
		run.resize(transforms.size())
		run.fill(color(hex).srgb_to_linear())
		var colors: PackedColorArray = into["colors"]
		colors.append_array(run)
		into["colors"] = colors
	batches = pooled

func flush(light_bounds: Array[AABB] = []) -> void:
	for key: Variant in batches:
		flush_one(key,light_bounds)
	batches.clear()

## One batch of flush(), for a build that goes over several frames; batches.clear() is the caller's.
func flush_one(key: Variant, light_bounds: Array[AABB] = []) -> void:
	var entry: Dictionary = batches[key]
	_flush_batch(entry,entry["transforms"],entry.get("colors",PackedColorArray()),light_bounds)

func _flush_batch(entry: Dictionary, transforms: Array, colors: PackedColorArray, light_bounds: Array[AABB], depth: int = 0) -> void:
	var mesh: Mesh = entry["mesh"]
	var parent: Node3D = entry["parent"]
	if not light_bounds.is_empty() and depth<LIGHT_SPLIT_DEPTH:
		var shape: AABB = mesh.get_aabb()
		var bounds: AABB = (transforms[0] as Transform3D)*shape
		for transform: Transform3D in transforms:
			bounds = bounds.merge(transform*shape)
		var world_bounds: AABB = parent.global_transform*bounds
		var overlaps: int = 0
		for light: AABB in light_bounds:
			if world_bounds.intersects(light):
				overlaps += 1
			if overlaps>8:
				break
		if overlaps>8:
			if transforms.size()>1:
				_split_batch(entry,transforms,colors,light_bounds,depth,bounds.size.max_axis_index())
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
				_flush_batch(entry,[transform],colors,light_bounds,depth+1)
				transform.origin += offset*2.0
				_flush_batch(entry,[transform],colors,light_bounds,depth+1)
				return
	_add_batch(entry,transforms,colors)

## The batch's instance under its parent.
func _add_batch(entry: Dictionary, transforms: Array, colors: PackedColorArray) -> void:
	var parent: Node3D = entry["parent"]
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not colors.is_empty()
	multi.mesh = entry["mesh"]
	multi.instance_count = transforms.size()
	for i: int in transforms.size():
		multi.set_instance_transform(i,transforms[i])
	for i: int in colors.size():
		multi.set_instance_color(i,colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = _plain_material() if colors.size()>0 else material(entry["color"])
	# The ground's own boxes and stones lie flat: their shadows would fall on nothing, yet they
	# would fill every shadow map pass (meta `flat` on the parent they are drawn into).
	if entry["color"] in ["ffd88a","ffb858"] or String(entry["color"]).ends_with(":glow") or String(entry["color"]).ends_with(":haze") or String(entry["color"]).ends_with(":mist") or parent.get_meta("light_fixture",false) or parent.get_meta("flat",false):
		# Tiny opaque lantern caps otherwise project enormous square shadows from
		# the point source inside them. The housing represents a diffuse emitter.
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

## Half the batch by place along `axis`, each half again if it needs it.
func _split_batch(entry: Dictionary, transforms: Array, colors: PackedColorArray, light_bounds: Array[AABB], depth: int, axis: int) -> void:
	var order: Array[Vector2] = []
	for i: int in transforms.size():
		order.append(Vector2((transforms[i] as Transform3D).origin[axis],i))
	order.sort()
	var middle: int = transforms.size()/2
	for half: Array[Vector2] in [order.slice(0,middle),order.slice(middle)]:
		var part: Array = []
		var tints := PackedColorArray()
		for item: Vector2 in half:
			part.append(transforms[int(item.y)])
			if not colors.is_empty():
				tints.append(colors[int(item.y)])
		_flush_batch(entry,part,tints,light_bounds,depth+1)

func _plain_material() -> StandardMaterial3D:
	if _pooled == null:
		_pooled = StandardMaterial3D.new()
		_pooled.vertex_color_use_as_albedo = true
		_pooled.roughness = 0.93
	return _pooled

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
## A paper lantern at `at`: on its own post from the ground when `standing`, else hung;
## `size` scales the lantern (not the post), a little bigger or smaller than its neighbours.
func lantern(parent: Node3D, at: Vector3, standing: bool = false, paper: String = "ffb858", size: float = 1.0) -> void:
	var housing := Node3D.new()
	housing.set_meta("light_fixture",true)
	parent.add_child(housing)
	if standing:
		box(housing,Vector3(at.x,at.y/2,at.z),Vector3(0.12,at.y,0.12),"483b32")
	box(housing,at,Vector3(0.34,0.45,0.34)*size,paper)
	for y: float in [-0.25,0.25]:
		box(housing,at+Vector3(0,y*size,0),Vector3(0.44,0.07,0.44)*size,"993f35")
	for x: float in [-0.17,0.17]:
		box(housing,at+Vector3(x,0,0.175)*size,Vector3(0.045,0.44,0.04)*size,"ba613c")
	box(housing,at+Vector3(0,-0.36*size,0),Vector3(0.06,0.16,0.06)*size,"b54135")
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

## A flower pot: by its place a little bigger or smaller, the glaze a shade off, and what
## grows in it (when `green`) leafy, or in flower of one colour or another.
func pot(parent: Node3D, at: Vector3, green: bool = true) -> void:
	var vary: RandomNumberGenerator = spot_rng(parent.position+at,3)
	var size: float = vary.randf_range(0.88,1.1)
	var clay: String = tinted("8b5440",vary,0.06)
	box(parent,at+Vector3(0,0.22*size,0),Vector3(0.44,0.42,0.44)*size,clay)
	box(parent,at+Vector3(0,0.43*size,0),Vector3(0.5,0.08,0.5)*size,tinted("be8660",vary,0.05))
	box(parent,at+Vector3(0,0.48*size,0),Vector3(0.37,0.04,0.37)*size,"473b2c")
	if green:
		var turn: float = vary.randf()*TAU
		for i: int in 7:
			var a: float = i*TAU/7+turn
			box(parent,at+Vector3(cos(a)*0.19,0.65+float(i%3)*0.09,sin(a)*0.19)*size,Vector3(0.18,0.4,0.16)*size,["417653","689951","8eaa58"][i%3])
		if vary.randf()<0.4:
			var bloom: String = ["d84a5a","e8a0b4","f2dc8e","b890d0","f0f0e8"][vary.randi_range(0,4)]
			for i: int in 3:
				var a: float = i*2.1+turn
				box(parent,at+Vector3(cos(a)*0.12,0.84+(i%2)*0.06,sin(a)*0.12)*size,Vector3(0.1,0.07,0.1)*size,bloom)

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
