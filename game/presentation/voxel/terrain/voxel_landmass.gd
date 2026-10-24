class_name VoxelLandmass
extends RefCounted

## A finite presentation footprint around authored terrain. It never defines
## walkability: the source TileMap and physical zones retain that authority.
const PATCH: int = 32
const TILE: int = 16
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]
var patches: Dictionary[Vector2i, bool] = {}
var minimum_margin: float = 48.0
var maximum_margin: float = 112.0
var depth: float = 2.2
## Layout `edge`: "top", "bottom" and three "strata" colours (soil by default).
var colors: Dictionary = {}
var _contour := FastNoiseLite.new()

func build(source: Dictionary[Vector2i,String], required_rects: Array[Rect2], config: Dictionary) -> void:
	patches.clear()
	minimum_margin = maxf(16.0,float(config.get("minimum_margin",48.0)))
	maximum_margin = maxf(minimum_margin,float(config.get("maximum_margin",112.0)))
	depth = maxf(0.8,float(config.get("depth",2.2)))
	colors = config
	_contour.seed = 3927
	_contour.frequency = 0.009
	_contour.fractal_octaves = 2
	var required: Dictionary[Vector2i,bool] = {}
	for at: Vector2i in source:
		if source[at]!="boundary":
			required[_patch(Vector2(at))] = true
	for rect: Rect2 in required_rects:
		for y: int in range(floori(rect.position.y/PATCH),ceili(rect.end.y/PATCH)):
			for x: int in range(floori(rect.position.x/PATCH),ceili(rect.end.x/PATCH)):
				required[Vector2i(x,y)] = true
	var distances: Dictionary[Vector2i,float] = {}
	var reach: int = ceili(maximum_margin/PATCH)+1
	for core: Vector2i in required:
		for y: int in range(-reach,reach+1):
			for x: int in range(-reach,reach+1):
				# Distance to the nearest required patch, not to its centre.
				var offset := Vector2(maxf(absf(x*PATCH)-PATCH*0.5,0),maxf(absf(y*PATCH)-PATCH*0.5,0))
				var distance: float = offset.length()
				if distance>maximum_margin:
					continue
				var at := core+Vector2i(x,y)
				distances[at] = minf(distances.get(at,INF),distance)
	for at: Vector2i in distances:
		var center: Vector2 = (Vector2(at)+Vector2.ONE*0.5)*PATCH
		var variation: float = clampf(0.5+_contour.get_noise_2dv(center)*1.5,0,1)
		var margin: float = lerpf(minimum_margin,maximum_margin,variation)
		if distances[at]<=margin:
			patches[at] = true

func _patch(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x/PATCH),floori(at.y/PATCH))

func contains(at: Vector2) -> bool:
	return patches.has(_patch(at))

func supports(at: Vector2, radius: float) -> bool:
	for y: int in range(floori((at.y-radius)/PATCH),floori((at.y+radius)/PATCH)+1):
		for x: int in range(floori((at.x-radius)/PATCH),floori((at.x+radius)/PATCH)+1):
			if not patches.has(Vector2i(x,y)):
				return false
	return true

func terrain(source: Dictionary[Vector2i,String]) -> Dictionary[Vector2i,String]:
	var result: Dictionary[Vector2i,String] = {}
	# Keep authored order so stone merging still follows the original map grid.
	for at: Vector2i in source:
		if contains(Vector2(at)):
			result[at] = source[at]
	for patch: Vector2i in patches:
		for y: int in 2:
			for x: int in 2:
				var at := patch*PATCH+Vector2i(x*TILE+8,y*TILE+8)
				if not result.has(at):
					result[at] = "boundary"
	return result

func make_base(parent: Node3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for patch: Vector2i in patches:
		var x: float = float(patch.x)
		var z: float = float(patch.y)
		_quad(surface,Vector3(x,-0.12,z),Vector3(x+1,-0.12,z),Vector3(x+1,-0.12,z+1),Vector3(x,-0.12,z+1),Vector3.UP,Color(String(colors.get("top","6b7951"))))
		_quad(surface,Vector3(x,-depth,z),Vector3(x,-depth,z+1),Vector3(x+1,-depth,z+1),Vector3(x+1,-depth,z),Vector3.DOWN,Color(String(colors.get("bottom","665e4b"))))
		for direction: Vector2i in DIRECTIONS:
			if patches.has(patch+direction):
				continue
			var normal := Vector3(direction.x,0,direction.y)
			var tangent := Vector3(-normal.z,0,normal.x)
			var center := Vector3(x+0.5,0,z+0.5)+normal*0.5
			var a: Vector3 = center-tangent*0.5
			var b: Vector3 = center+tangent*0.5
			var shade: float = _contour.get_noise_2d(x*58,z*58)
			var strata: Array = colors.get("strata",["8a805b","9b8966","786b54"])
			for layer: int in 3:
				var top_a: Vector3 = a+Vector3.UP*_level(a,layer)
				var top_b: Vector3 = b+Vector3.UP*_level(b,layer)
				var low_a: Vector3 = a+Vector3.UP*_level(a,layer+1)
				var low_b: Vector3 = b+Vector3.UP*_level(b,layer+1)
				var base := Color(String(strata[layer]))
				var color: Color = base.lightened(shade*0.12) if shade>0 else base.darkened(-shade*0.14)
				_quad(surface,top_a,top_b,low_b,low_a,normal,color)
	var geometry := MeshInstance3D.new()
	geometry.name = "LandmassCutaway"
	geometry.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	geometry.material_override = material
	parent.add_child(geometry)

func _level(at: Vector3, layer: int) -> float:
	if layer==0:
		return -0.12
	if layer==3:
		return -depth
	# Matching heights at shared corners keep the soil strata watertight.
	return -depth*([0.0,0.23,0.63][layer]+_contour.get_noise_2d(at.x*46,at.z*46)*0.07)

func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	var points: Array[Vector3] = [a,b,c,d]
	surface.set_normal(normal)
	surface.set_color(color.srgb_to_linear())
	var outward: bool = (c-a).cross(b-a).dot(normal)>0
	var indices := PackedInt32Array([0,1,2,0,2,3] if outward else [0,2,1,0,3,2])
	for index: int in indices:
		surface.add_vertex(points[index])
