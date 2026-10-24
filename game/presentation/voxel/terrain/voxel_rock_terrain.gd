extends RefCounted

## Rock country and underground surfaces, sampled from the authoritative tile layers.
## Profiles vary by existing physical zone; no second walkability map is authored here.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var shapes: Shapes
var rng: RandomNumberGenerator
var foliage: VoxelFoliage
var profiles: Array[Dictionary] = []
var defaults: Dictionary = {}
var parent: Node3D
var sides: Array[Node3D] = []
var drawn: Dictionary[Vector2i,bool] = {}

static func contour(source: Dictionary[Vector2i,String]) -> Dictionary[Vector2i,String]:
	var keep: Dictionary[Vector2i,bool] = {}
	for cell: Vector2i in source:
		if source[cell] in ["cliff","forest","boundary","chasm"]:
			continue
		for y: int in range(-4,5):
			for x: int in range(-4,5):
				keep[cell+Vector2i(x,y)*16] = true
	var result: Dictionary[Vector2i,String] = {}
	for cell: Vector2i in source:
		if keep.has(cell):
			result[cell] = source[cell]
	return result

func profile(at: Vector2) -> Dictionary:
	for entry: Dictionary in profiles:
		if (entry["rect"] as Rect2).has_point(at):
			return entry["style"]
	return defaults

func draw(cell: Vector2i, kind: String, cells: Dictionary[Vector2i,String]) -> void:
	if drawn.has(cell):
		return
	var p := Vector3(cell.x/32.0,0,cell.y/32.0)
	var data: Dictionary = profile(Vector2(cell))
	var stone: Array = data.get("stone",["615b49","81735a","a28c63","c1aa7d"])
	var floor_colors: Array = data.get("floor",["786d4e","8c7955","a18a61"])
	var hash_value: int = absi(cell.x*73+cell.y*137)
	var rock: bool = kind in ["cliff","boundary","forest","wall","wall_wood","chasm"]
	var color_index: int = posmod(floori(sin(cell.x*0.018)+cos(cell.y*0.027)+2),floor_colors.size())
	shapes.box(parent,p-Vector3(0,0.08,0),Vector3(0.505,0.16,0.505),String(floor_colors[color_index]))
	if kind=="blocked":
		return # The furnishing supplies the volume of this blocked cell.
	if rock:
		var span := Vector2i.ONE
		for extent: int in range(3,1,-1):
			var fits: bool = true
			for y: int in extent:
				for x: int in extent:
					var next := cell+Vector2i(x,y)*16
					fits = fits and cells.get(next,"")==kind and not drawn.has(next)
			if fits:
				span = Vector2i.ONE*extent
				break
		for y: int in span.y:
			for x: int in span.x:
				drawn[cell+Vector2i(x,y)*16] = true
		p += Vector3((span.x-1)*0.25,0,(span.y-1)*0.25)
		var height: float = float(data.get("height",3.5))*(0.80+0.23*sin(p.x*0.5)+0.13*cos(p.z*0.6))
		if kind=="boundary":
			height = 0.18+0.10*sin(p.x*1.2+p.z)
		if kind=="chasm":
			height *= 0.08
		var center := cell+Vector2i(span.x/2,span.y/2)*16
		var north_open: bool = _near_open(center,Vector2i(0,-16),cells)
		var east_open: bool = _near_open(center,Vector2i(16,0),cells)
		var west_open: bool = _near_open(center,Vector2i(-16,0),cells)
		var earth: bool = bool(data.get("earth_east_wall",false)) and west_open and kind in ["wall","wall_wood"]
		# Camera-facing rim is cut away; the far rim retains its irregular silhouette.
		for side: int in 2:
			var low: bool = north_open or (west_open if side==0 else east_open)
			var h: float = minf(height,0.65) if low else height
			var into: Node3D = sides[side]
			for tier: int in 3:
				var thickness: float = [0.54,0.29,0.17][tier]
				var center_height: float = [0.27,0.685,0.915][tier]
				var inset: float = float(tier)*0.025
				var size := Vector3(span.x*0.50-inset,h*thickness,span.y*0.50-inset)
				var shift := Vector3(sin(hash_value+tier*7)*inset,center_height*h,cos(hash_value+tier*3)*inset)
				shapes.box(into,p+shift,size,"ad8e56" if earth else String(stone[mini(tier+1,stone.size()-1)]))
			if not earth and not low and span.x>1 and hash_value%5==0:
				shapes.shard(into,p+Vector3(0,h+0.09,0),Vector3(span.x*0.29,0.18,span.y*0.32),String(stone[2]),hash_value)
			if not low and hash_value%3==0:
				shapes.box(into,p+Vector3(0,h*0.54,0),Vector3(span.x*0.50,0.022,span.y*0.50),"917340" if earth else String(stone[0]))
		if foliage!=null and kind=="boundary" and hash_value%3==0:
			foliage.plant(p+Vector3(0,height+0.03,0),0,0.75,float(hash_value))
		return
	var path: bool = kind=="path"
	if rng.randf()<float(data.get("gravel",0.45)):
		var q := p+Vector3(rng.randf_range(-0.20,0.20),0.025,rng.randf_range(-0.20,0.20))
		shapes.shard(parent,q,Vector3(rng.randf_range(0.08,0.23),0.05,rng.randf_range(0.07,0.18)),String(stone[1+hash_value%(stone.size()-1)]),hash_value)
	if foliage!=null and rng.randf()<float(data.get("grass",0.2))*(0.06 if path else 1.0):
		foliage.plant(p+Vector3(rng.randf_range(-0.17,0.17),0.01,rng.randf_range(-0.17,0.17)),1+hash_value%2 if hash_value%31==0 else 0,float(data.get("grass_height",1.2))*rng.randf_range(0.75,1.25),rng.randf()*TAU)
	if data.get("grooves",false) and hash_value%7==0:
		shapes.tilted_box(parent,p+Vector3(0,0.005,0),Vector3(0.026,0.012,0.35),String(stone[0]),Vector3(0,0.5*sin(cell.x),0))

func _open(kind: String) -> bool:
	return kind in ["rock","grass","path","cave_floor","floor_wood","floor_shop","floor_yard"]

func _near_open(cell: Vector2i, direction: Vector2i, cells: Dictionary[Vector2i,String]) -> bool:
	for i: int in range(1,9):
		if _open(cells.get(cell+direction*i,"")):
			return true
	return false
