extends RefCounted

## What a voxel build costs (DECISIONS「搭建开销」): the plain colours of one place share a
## batch and nothing else does; the short ways through the build give what the long ways gave,
## in the same order, since every later draw from the map's seed depends on that order.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	_test_plain_colours_pool(tree)
	_test_split_keeps_each_stone_its_colour(tree)
	_test_cells_within()
	_test_covered()
	_test_landmass_order()
	_test_quads_are_surface_tool_triangles()
	_test_room_floors()
	return {"assertions": assertions, "failures": failures}


func _test_plain_colours_pool(tree: SceneTree) -> void:
	var holder := Node3D.new()
	tree.root.add_child(holder)
	var other := Node3D.new()
	tree.root.add_child(other)
	var shapes := Shapes.new()
	shapes.spatial_batching = true
	shapes.box(holder, Vector3(1, 0, 1), Vector3.ONE, "aa2200")
	shapes.box(holder, Vector3(2, 0, 1), Vector3.ONE, "00aa22")
	shapes.box(holder, Vector3(3, 0, 1), Vector3.ONE, "aa2200")
	shapes.box(holder, Vector3(30, 0, 1), Vector3.ONE, "aa2200")
	shapes.box(other, Vector3(1, 0, 1), Vector3.ONE, "aa2200")
	shapes.shard(holder, Vector3(1, 0, 2), Vector3.ONE, "aa2200", 3)
	shapes.box(holder, Vector3(4, 0, 1), Vector3.ONE, "aa2200:glow")
	shapes.box(holder, Vector3(5, 0, 1), Vector3.ONE, "aa2200:gloss")
	shapes.box(holder, Vector3(6, 0, 1), Vector3.ONE, "ffd88a")
	shapes.window(holder, Vector3(7, 0, 1), Vector3.ONE)
	_check(shapes.batches.size() == 9, "drawn, every colour is its own batch: %d" % shapes.batches.size())
	shapes.pool_plain_colours()
	var pooled: Array[Dictionary] = []
	var own: Array[String] = []
	for entry: Dictionary in shapes.batches.values():
		if entry.has("colors"):
			pooled.append(entry)
		else:
			own.append(entry["color"])
	own.sort()
	_check(own == ["aa2200:gloss", "aa2200:glow", "d7bb88", "ffd88a"], "what glows or shines, and a colour asked to, keeps its own batch: %s" % [own])
	_check(pooled.size() == 4, "one batch per parent, mesh and cell, whatever the colours: %d" % pooled.size())
	var street: Dictionary = pooled[0]
	var red: Color = Color("aa2200").srgb_to_linear()
	var green: Color = Color("00aa22").srgb_to_linear()
	var by_x: Dictionary = {}
	for i: int in (street["transforms"] as Array).size():
		by_x[roundi((street["transforms"][i] as Transform3D).origin.x)] = street["colors"][i]
	_check(by_x == {1: red, 2: green, 3: red}, "each stone keeps its colour, in linear light: %s" % [by_x])
	shapes.flush()
	var instance: MultiMeshInstance3D = null
	for child: Node in holder.get_children():
		var mesh := child as MultiMeshInstance3D
		if mesh != null and mesh.multimesh.instance_count == 3:
			instance = mesh
	_check(instance != null and instance.multimesh.use_colors, "the three stones are one instance, coloured per stone")
	var material: StandardMaterial3D = instance.material_override if instance != null else null
	_check(material != null and material.vertex_color_use_as_albedo and is_equal_approx(material.roughness, 0.93) and material.albedo_color == Color.WHITE, "lit like any plain colour, the colour from the instance")
	var occlusion := VoxelOcclusion.new()
	occlusion.register(holder)
	_check(occlusion.materials.size() == 5, "the plain colours share one reveal material: %d" % occlusion.materials.size())
	var shadows: int = 0
	for child: Node in holder.get_children():
		var mesh := child as MultiMeshInstance3D
		if mesh != null and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and mesh.multimesh.use_colors:
			shadows += 1
			_check(mesh.material_override == material, "its shadow stays in the original material")
	_check(shadows == 3, "and the pooled batches keep their shadows: %d" % shadows)
	holder.free()
	other.free()


## The headless server keeps no instances: what would become one, as it is handed over.
class Recorder extends "res://presentation/voxel/props/voxel_shapes.gd":
	var added: Array = []

	func _add_batch(_entry: Dictionary, transforms: Array, colors: PackedColorArray) -> void:
		added.append([transforms, colors])


func _test_split_keeps_each_stone_its_colour(tree: SceneTree) -> void:
	var holder := Node3D.new()
	tree.root.add_child(holder)
	var lights: Array[AABB] = []
	for i: int in 16:
		lights.append(AABB(Vector3(i * 1.5 - 0.5, -1, -1), Vector3(1, 2, 2)))
	var shapes := Recorder.new()
	shapes.spatial_batching = true
	shapes.spatial_cell_size = 1000.0
	var sent: Dictionary = {}
	# Out of order along the row, as a stretch of ground is drawn.
	for step: int in 30:
		var i: int = step * 7 % 30
		var hex: String = Color(i / 30.0, 0.5, 1.0 - i / 30.0).to_html(false)
		shapes.box(holder, Vector3(i * 0.8, 0, 0), Vector3(0.5, 0.5, 0.5), hex)
		sent[i] = Color(hex).srgb_to_linear()
	shapes.pool_plain_colours()
	shapes.flush(lights)
	_check(shapes.added.size() > 1, "many lights over one pooled batch split it: %d" % shapes.added.size())
	var seen: Dictionary = {}
	var alike: bool = true
	var within_budget: bool = true
	for part: Array in shapes.added:
		var transforms: Array = part[0]
		var colors: PackedColorArray = part[1]
		alike = alike and colors.size() == transforms.size()
		var bounds := AABB()
		for i: int in transforms.size():
			var origin: Vector3 = (transforms[i] as Transform3D).origin
			var at: int = roundi(origin.x / 0.8)
			seen[at] = true
			alike = alike and colors[i].is_equal_approx(sent[at])
			var box := AABB(origin - Vector3(0.25, 0.25, 0.25), Vector3(0.5, 0.5, 0.5))
			bounds = box if i == 0 else bounds.merge(box)
		var count: int = 0
		for light: AABB in lights:
			count += int(bounds.intersects(light))
		within_budget = within_budget and count <= 8
	_check(seen.size() == 30 and alike, "every stone comes out once, in its own colour: %d" % seen.size())
	_check(within_budget, "each part stays within Mobile's eight lights")
	holder.free()


func _test_cells_within() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 32, 32), Rect2(-24, -40, 74, 110), Rect2(8, 8, 16, 16), Rect2(9, 9, 6, 6), Rect2(-8, 24, 32.5, 15.5)]
	for rect: Rect2 in rects:
		var slow: Array[Vector2i] = []
		for y: int in range(-13, 14):
			for x: int in range(-13, 14):
				var cell := Vector2i(x * 16 + 8, y * 16 + 8)
				if rect.has_point(Vector2(cell)):
					slow.append(cell)
		_check(VoxelMapGeometry.cells_within(rect) == slow, "the grid's cells inside %s, row by row" % rect)


func _test_covered() -> void:
	var ground := VoxelGround.new()
	ground.footprints = [Rect2(16, 16, 64, 48), Rect2(-40, -8, 30, 30)]
	var same: bool = true
	for y: int in range(-5, 6):
		for x: int in range(-5, 6):
			var cell := Vector2i(x * 16 + 8, y * 16 + 8)
			var under: bool = false
			for rect: Rect2 in ground.footprints:
				under = under or rect.has_point(Vector2(cell))
			same = same and ground.covered(cell) == under
	_check(same, "a building's cells, as its footprint has them")
	ground.footprints.append(Rect2(200, 200, 16, 16))
	_check(ground.covered(Vector2i(200, 200)), "a footprint added later counts")


func _test_landmass_order() -> void:
	var source: Dictionary[Vector2i, String] = {Vector2i(8, 8): "street", Vector2i(-88, 408): "grass", Vector2i(900, 40): "boundary", Vector2i(280, 200): "path"}
	var required: Array[Rect2] = [Rect2(-100, 300, 200, 120)]
	var config: Dictionary = {"minimum_margin": 40.0, "maximum_margin": 96.0}
	var land := VoxelLandmass.new()
	land.build(source, required, config)
	# The patches as the long way finds them, order included: terrain() walks them in order, and
	# the order of the cells is the order of every draw that follows.
	var cores: Dictionary[Vector2i, bool] = {}
	for at: Vector2i in source:
		if source[at] != "boundary":
			cores[Vector2i(floori(at.x / 32.0), floori(at.y / 32.0))] = true
	for rect: Rect2 in required:
		for y: int in range(floori(rect.position.y / 32), ceili(rect.end.y / 32)):
			for x: int in range(floori(rect.position.x / 32), ceili(rect.end.x / 32)):
				cores[Vector2i(x, y)] = true
	var distances: Dictionary[Vector2i, float] = {}
	var reach: int = ceili(96.0 / 32) + 1
	for core: Vector2i in cores:
		for y: int in range(-reach, reach + 1):
			for x: int in range(-reach, reach + 1):
				var offset := Vector2(maxf(absf(x * 32) - 16.0, 0), maxf(absf(y * 32) - 16.0, 0))
				if offset.length() > 96.0:
					continue
				var at := core + Vector2i(x, y)
				distances[at] = minf(distances.get(at, INF), offset.length())
	var contour := FastNoiseLite.new()
	contour.seed = 3927
	contour.frequency = 0.009
	contour.fractal_octaves = 2
	var patches: Array[Vector2i] = []
	for at: Vector2i in distances:
		var variation: float = clampf(0.5 + contour.get_noise_2dv((Vector2(at) + Vector2.ONE * 0.5) * 32) * 1.5, 0, 1)
		if distances[at] <= lerpf(40.0, 96.0, variation):
			patches.append(at)
	_check(not patches.is_empty() and land.patches.keys() == patches, "the same patches in the same order: %d vs %d" % [land.patches.size(), patches.size()])


func _test_quads_are_surface_tool_triangles() -> void:
	var land := VoxelLandmass.new()
	var quads := VoxelLandmass.Quads.new()
	var slow := SurfaceTool.new()
	slow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners: Array[Vector3] = [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]
	for normal: Vector3 in [Vector3.UP, Vector3.DOWN]:
		var color := Color("9b8966")
		land._quad(quads, corners[0], corners[1], corners[2], corners[3], normal, color)
		slow.set_normal(normal)
		slow.set_color(color.srgb_to_linear())
		var outward: bool = (corners[2] - corners[0]).cross(corners[1] - corners[0]).dot(normal) > 0
		for index: int in [0, 1, 2, 0, 2, 3] if outward else [0, 2, 1, 0, 3, 2]:
			slow.add_vertex(corners[index])
	var fast: Array = quads.commit().surface_get_arrays(0)
	var long: Array = slow.commit().surface_get_arrays(0)
	_check(fast[Mesh.ARRAY_VERTEX] == long[Mesh.ARRAY_VERTEX], "the same triangles, the same way round")
	_check(fast[Mesh.ARRAY_NORMAL] == long[Mesh.ARRAY_NORMAL], "the same normals")
	var colours: PackedColorArray = fast[Mesh.ARRAY_COLOR]
	var long_colours: PackedColorArray = long[Mesh.ARRAY_COLOR]
	var same: bool = colours.size() == long_colours.size()
	for i: int in colours.size():
		same = same and colours[i].is_equal_approx(long_colours[i])
	_check(same, "the same colours")


func _test_room_floors() -> void:
	var life := VoxelLife.new()
	life.rooms = {&"east": {"rect": Rect2(32, 0, 48, 32)}, &"west": {"rect": Rect2(0, 0, 48, 32)}, &"empty": {"rect": Rect2(500, 500, 16, 16)}}
	var cells: Dictionary[Vector2i, String] = {}
	var kinds: Array[String] = ["floor_wood", "wall", "floor_shop"]
	var turn: int = 0
	# The ground's own order, no row or column in it.
	for x: int in [7, 2, 0, 5, 3, 1, 4, 6]:
		for y: int in [1, 0, 2]:
			cells[Vector2i(x * 16 + 8, y * 16 + 8)] = kinds[turn % kinds.size()]
			turn += 1
	var floors: Dictionary = life._floors(cells)
	for zone_id: StringName in life.rooms:
		var slow: Array[Vector2i] = []
		for cell: Vector2i in cells:
			if (life.rooms[zone_id]["rect"] as Rect2).has_point(Vector2(cell)) and not cells[cell] in VoxelLife.WALKABLE_NOT:
				slow.append(cell)
		var quick: Array[Vector2i] = []
		quick.assign((floors[zone_id] as Dictionary).keys())
		_check(quick == slow, "%s: its floor in the ground's order: %s vs %s" % [zone_id, quick, slow])


func _check(ok: bool, label: String) -> bool:
	assertions += 1
	if not ok:
		failures.append(label)
	return ok
