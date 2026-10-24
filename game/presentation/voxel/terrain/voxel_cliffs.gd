class_name VoxelCliffs
extends RefCounted

## Blocking rock (`cliff`, `chasm`) raised into stepped masses beside the open ground.
## Heights grow with the distance from walkable cells and are presentation only: the
## authored TileMap still decides every collision. Rock far from any open ground is
## trimmed to the finite landmass's skirt, so a mountain road reads as a ridge.
const TILE: int = 16
const CHUNK: int = 256
const NEIGHBOURS: Array[Vector2i] = [Vector2i(16,0),Vector2i(-16,0),Vector2i(0,16),Vector2i(0,-16)]
var kinds: Array = ["cliff","chasm"]
var heights: Dictionary[Vector2i, float] = {}
var distances: Dictionary[Vector2i, float] = {}
var config: Dictionary = {}
var noise := FastNoiseLite.new()
var root: Node3D
var face_count: int = 0
var _kinds_by_cell: Dictionary[Vector2i, String] = {}

func _init(settings: Dictionary = {}) -> void:
	config = settings
	kinds = settings.get("kinds",["cliff","chasm"])
	noise.seed = int(settings.get("seed",5281))
	noise.frequency = 0.02
	noise.fractal_octaves = 2

## Distances from the open ground (pixels), then the far rock (and any `trim` kinds)
## becomes `boundary`, before the landmass is shaped around what is left.
func prepare(cells: Dictionary[Vector2i, String], blocking: Array) -> void:
	distances.clear()
	var frontier: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if not cells[cell] in blocking and cells[cell] != "boundary":
			distances[cell] = 0.0
			frontier.append(cell)
	# Two-pass chamfer over a breadth-first order: close enough to Euclidean for heights.
	var steps: Array[Vector2i] = [Vector2i(16,0),Vector2i(-16,0),Vector2i(0,16),Vector2i(0,-16),Vector2i(16,16),Vector2i(-16,16),Vector2i(16,-16),Vector2i(-16,-16)]
	var head: int = 0
	while head < frontier.size():
		var at: Vector2i = frontier[head]
		head += 1
		for step: Vector2i in steps:
			var next: Vector2i = at+step
			if not cells.has(next):
				continue
			var d: float = distances[at]+(22.6 if step.x != 0 and step.y != 0 else 16.0)
			if d < distances.get(next,INF):
				distances[next] = d
				frontier.append(next)
	var keep: float = float(config.get("keep",INF))
	var trimmed: Array = config.get("trim",kinds)
	for cell: Vector2i in cells.keys():
		if cells[cell] in trimmed and distances.get(cell,INF) > keep:
			cells[cell] = "boundary"

## Heights for the rock left on the landmass, stepped into whole voxel courses.
func shape(cells: Dictionary[Vector2i, String]) -> void:
	heights.clear()
	var low: float = float(config.get("low",0.8))
	var high: float = float(config.get("high",4.0))
	var rise: float = float(config.get("rise",160.0))
	var step: float = float(config.get("step",0.5))
	var rough: float = float(config.get("rough",0.6))
	var lifts: Array = config.get("lifts",[])
	for cell: Vector2i in cells:
		if not cells[cell] in kinds:
			continue
		var t: float = smoothstep(0.0,rise,distances.get(cell,rise))
		var h: float = lerpf(low,high,t)+noise.get_noise_2d(cell.x,cell.y)*rough
		for lift: Dictionary in lifts:
			var r: Array = lift["rect"]
			if Rect2(r[0],r[1],r[2]-r[0],r[3]-r[1]).has_point(Vector2(cell)):
				h += float(lift.get("by",1.0))
		heights[cell] = maxf(step,snappedf(h,step))

func height(cell: Vector2i) -> float:
	return heights.get(cell,0.0)

## One merged mesh per chunk: tops and only the faces that show above a lower neighbour.
func build(parent: Node3D) -> void:
	root = Node3D.new()
	root.name = "Cliffs"
	parent.add_child(root)
	var strata: Array = config.get("strata",["7d6e58","8c7b60","9a876a","a48f6d","8f7d63"])
	var tops: Array = config.get("tops",["8b8a5c","978f62","a0956a"])
	var dark: String = String(config.get("dark","2a2420"))
	var band: float = float(config.get("band",0.5))
	var grooves: float = float(config.get("grooves",0.0))
	var by_chunk: Dictionary[Vector2i, Array] = {}
	for cell: Vector2i in heights:
		var chunk := Vector2i(floori(float(cell.x)/CHUNK),floori(float(cell.y)/CHUNK))
		if not by_chunk.has(chunk):
			by_chunk[chunk] = []
		by_chunk[chunk].append(cell)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	face_count = 0
	for chunk: Vector2i in by_chunk:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for cell: Vector2i in by_chunk[chunk]:
			var h: float = heights[cell]
			var x0: float = (cell.x-8)/32.0
			var z0: float = (cell.y-8)/32.0
			var x1: float = x0+0.5
			var z1: float = z0+0.5
			var shade: float = noise.get_noise_2d(cell.x*3.0,cell.y*3.0)
			var top: Color = Color(String(tops[clampi(roundi((shade+0.5)*(tops.size()-1)),0,tops.size()-1)]))
			_quad(surface,Vector3(x0,h,z0),Vector3(x1,h,z0),Vector3(x1,h,z1),Vector3(x0,h,z1),Vector3.UP,top)
			for shift: Vector2i in NEIGHBOURS:
				var below: float = heights.get(cell+shift,0.0)
				if below >= h:
					continue
				var normal := Vector3(shift.x/16.0,0,shift.y/16.0)
				var a: Vector3
				var b: Vector3
				if shift.x > 0:
					a = Vector3(x1,0,z1)
					b = Vector3(x1,0,z0)
				elif shift.x < 0:
					a = Vector3(x0,0,z0)
					b = Vector3(x0,0,z1)
				elif shift.y > 0:
					a = Vector3(x0,0,z1)
					b = Vector3(x1,0,z1)
				else:
					a = Vector3(x1,0,z0)
					b = Vector3(x0,0,z0)
				var gouge: bool = grooves > 0.0 and absi(cell.x*7+cell.y*13+shift.x*3+shift.y)%97 < int(grooves*97)
				var y: float = below
				while y < h-0.001:
					var next: float = minf(h,floorf(y/band+1.001)*band)
					var course: int = floori(y/band+0.001)
					var tint: Color = Color(String(strata[posmod(course+roundi(shade*2.0),strata.size())]))
					if cells_kind(cell) == "chasm":
						tint = Color(dark)
					elif gouge:
						tint = tint.darkened(0.32)
					_quad(surface,a+Vector3.UP*next,b+Vector3.UP*next,b+Vector3.UP*y,a+Vector3.UP*y,normal,tint)
					y = next
		var instance := MeshInstance3D.new()
		instance.mesh = surface.commit()
		instance.material_override = material
		root.add_child(instance)

func remember(cells: Dictionary[Vector2i, String]) -> void:
	_kinds_by_cell.clear()
	for cell: Vector2i in heights:
		_kinds_by_cell[cell] = cells.get(cell,"cliff")

func cells_kind(cell: Vector2i) -> String:
	return _kinds_by_cell.get(cell,"cliff")

## Rock faces that look onto open ground, for scattered outcrops and growth.
func faces_open(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for shift: Vector2i in NEIGHBOURS:
		if not heights.has(cell+shift) and distances.get(cell+shift,INF) == 0.0:
			result.append(shift)
	return result

func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	face_count += 1
	surface.set_normal(normal)
	surface.set_color(color.srgb_to_linear())
	var points: Array[Vector3] = [a,b,c,d]
	var outward: bool = (c-a).cross(b-a).dot(normal) > 0
	for index: int in [0,1,2,0,2,3] if outward else [0,2,1,0,3,2]:
		surface.add_vertex(points[index])
