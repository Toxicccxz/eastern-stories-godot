class_name VoxelGround
extends RefCounted

## Surface wear follows the authored ground types; collision remains in the 2D map.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var shapes: Shapes
var parent: Node3D
var foliage: VoxelFoliage
var rng: RandomNumberGenerator
var noise: FastNoiseLite
var footprints: Array[Rect2] = []
var weather: Array = []
## Map colours for shoulders and chips (layout `ground_tints`); defaults are the town's.
var tints: Dictionary = {}
const GRASS: Array[String] = ["grass", "forest_floor", "forest", "boundary"]
const PAVING: Array[String] = ["town_ground", "street", "floor_yard", "rock"]
const STONE: Array[String] = ["899794", "98a29d", "a6ada3", "939e9b", "afb4aa"]

func _point(cell: Vector2i) -> Vector3:
	return Vector3(cell.x/32.0,0,cell.y/32.0)

func _covered(cell: Vector2i) -> bool:
	for rect: Rect2 in footprints:
		if rect.has_point(Vector2(cell)):
			return true
	return false

func wear(at: Vector3) -> float:
	var result: float = 0.0
	for patch: Dictionary in weather:
		var p: Array = patch["at"]
		var radius: Array = patch["radius"]
		var delta := Vector2((at.x*32-p[0])/radius[0],(at.z*32-p[1])/radius[1])
		result = maxf(result, 1.0-delta.length()+noise.get_noise_2d(at.x*150,at.z*150)*0.22)
	return result

func paving(cell: Vector2i, cells: Dictionary[Vector2i,String], painted: Dictionary[Vector2i,bool]) -> void:
	var p: Vector3 = _point(cell)
	var width: int = rng.randi_range(1,3)
	var depth: int = rng.randi_range(1,2)
	# Random running lengths, with staggered joints and no stones over a doorway footprint.
	for extent: Vector2i in [Vector2i(width,depth), Vector2i(width,1), Vector2i(1,1)]:
		var free: bool = true
		for y: int in extent.y:
			for x: int in extent.x:
				var next := cell+Vector2i(x,y)*16
				free = free and cells.get(next,"") in PAVING and not painted.has(next) and not _covered(next)
		if free:
			width = extent.x
			depth = extent.y
			break
	for y: int in depth:
		for x: int in width:
			painted[cell+Vector2i(x,y)*16] = true
	p += Vector3((width-1)*0.25,0,(depth-1)*0.25)
	shapes.box(parent,p-Vector3(0,0.075,0),Vector3(width*0.5+0.01,0.12,depth*0.5+0.01),"787c66")
	var worn: float = wear(p)
	if worn>0.25:
		shapes.shard(parent,p+Vector3(0,0.002,0),Vector3(width*0.64,0.02,depth*0.64),"81775f",rng.randi())
	if worn<0.43 or rng.randf()<0.20:
		var size := Vector3(width*0.5-0.02,0.09,depth*0.5-0.02)
		var yaw: float = rng.randf_range(-0.065,0.065)
		p += Vector3(rng.randf_range(-0.025,0.025),rng.randf_range(-0.02,0.015),rng.randf_range(-0.025,0.025))
		var tint: String = STONE[rng.randi_range(0,STONE.size()-1)]
		if worn>0.15:
			tint = ["7b8b83","89958b","939c8e"][rng.randi_range(0,2)]
		shapes.shard(parent,p,size,tint,rng.randi(),yaw)
		# Selected broken corners and fissures, not a grid-wide noise overlay.
		if rng.randf()<0.08:
			shapes.tilted_box(parent,p+Vector3(size.x*0.26,0.047,0.04),Vector3(size.x*0.27,0.008,0.018),"707c72",Vector3(0,-0.35,0))
	if foliage != null and (rng.randf()<0.10 or worn>0.15 and rng.randf()<0.25):
		foliage.plant(p+Vector3(-width*0.25+0.03,0.03,depth*0.19),0,rng.randf_range(0.19,0.40),rng.randf()*TAU)

func edge(cell: Vector2i, cells: Dictionary[Vector2i,String]) -> void:
	var kind: String = cells[cell]
	if kind not in PAVING and kind not in ["path","riverbank"]:
		return
	var paved: bool = kind in PAVING
	var p: Vector3 = _point(cell)
	for shift: Vector2i in [Vector2i(-16,0),Vector2i(16,0),Vector2i(0,-16),Vector2i(0,16)]:
		var neighbor: Vector2i = cell+shift
		if _covered(neighbor) or cells.get(neighbor,"") not in GRASS:
			continue
		var outward := Vector3(shift.x/16.0,0,shift.y/16.0)
		var along := Vector3(-outward.z,0,outward.x)
		var edge_at: Vector3 = p+outward*0.25
		var drift: float = noise.get_noise_2d(cell.x*2.2,cell.y*2.2)*0.30
		# An uneven soil shoulder overlaps both original tiles and hides their hard seam.
		var mud_at: Vector3 = edge_at+outward*drift
		shapes.shard(parent,mud_at+Vector3(0,0.014,0),Vector3(0.70,0.025,0.80),String(tints.get("mud","91805c" if paved else "ae9669")),rng.randi(),rng.randf()*TAU)
		if not paved:
			var bank_at: Vector3 = edge_at+outward*(0.18+drift)+along*rng.randf_range(-0.13,0.13)
			shapes.shard(parent,bank_at+Vector3(0,0.031,0),Vector3(rng.randf_range(0.42,0.67),0.035,rng.randf_range(0.38,0.66)),String(tints.get("bank","718a50")),rng.randi(),rng.randf()*TAU)
		if paved and rng.randf()<0.67:
			var curb_at: Vector3 = edge_at+outward*(0.10+drift)+along*rng.randf_range(-0.08,0.08)
			shapes.shard(parent,curb_at+Vector3(0,0.055,0),Vector3(0.24,0.14,rng.randf_range(0.32,0.49)),"8c9680",rng.randi(),atan2(outward.z,outward.x)+rng.randf_range(-0.12,0.12))
		for chip: int in rng.randi_range(2,4):
			var chip_at: Vector3 = edge_at+outward*rng.randf_range(-0.23,0.52)+along*rng.randf_range(-0.30,0.30)
			shapes.shard(parent,chip_at+Vector3(0,0.04,0),Vector3(rng.randf_range(0.06,0.17),0.065,rng.randf_range(0.07,0.2)),String(tints.get("chips",["89917a","a6aa8b","b1ab8e"])[chip%3]),rng.randi(),rng.randf()*TAU)
		for tuft: int in 2:
			var tuft_at: Vector3 = edge_at+outward*rng.randf_range(0.03,0.55)+along*rng.randf_range(-0.25,0.25)
			foliage.plant(tuft_at,1 if rng.randf()<0.17 else 0,rng.randf_range(0.32,0.73),rng.randf()*TAU)

func puddles() -> void:
	for patch: Dictionary in weather:
		var pos: Array = patch["at"]
		var radius: Array = patch["radius"]
		var center := Vector3(float(pos[0])/32,0,float(pos[1])/32)
		var size := Vector3(float(radius[0])/16,0.025,float(radius[1])/16)
		var water: bool = patch.get("water",false)
		for lobe: int in 3:
			var at: Vector3 = center+Vector3((lobe-1)*size.x*0.16,0.024,sin(lobe*3.0)*size.z*0.17)
			shapes.shard(parent,at,size*Vector3(0.65,1,0.72),"746d53",lobe*2,0.12*lobe)
			if water:
				shapes.shard(parent,at+Vector3(0,0.017,0),size*Vector3(0.54,0.3,0.61),"527581",lobe*2,0.12*lobe)
		if water:
			var mat: StandardMaterial3D = shapes.material("527581")
			mat.roughness = 0.19
			mat.metallic = 0.28
			for glint: int in 4:
				shapes.tilted_box(parent,center+Vector3(rng.randf_range(-0.4,0.4),0.050,(glint-1.5)*size.z*0.09),Vector3(size.x*rng.randf_range(0.035,0.11),0.005,0.018),"9dafac",Vector3(0,-0.25,0))
		for pebble: int in 9:
			var angle: float = rng.randf()*TAU
			var pebble_at: Vector3 = center+Vector3(cos(angle)*size.x*0.47,0.045,sin(angle)*size.z*0.43)
			shapes.shard(parent,pebble_at,Vector3(0.16,0.09,0.13),"8b927f",rng.randi(),angle)

func roots(at: Vector3, scale: float) -> void:
	shapes.shard(parent,at-Vector3(0,0.015,0),Vector3(1.8*scale,0.12,1.65*scale),"6e7250",rng.randi(),rng.randf()*TAU)
	for branch: int in rng.randi_range(3,5):
		var angle: float = branch*1.4+rng.randf_range(-0.3,0.3)
		for segment: int in 4:
			var distance: float = (0.23+segment*0.25)*scale
			var bend: float = angle+segment*0.11
			var thick: float = (0.22-segment*0.045)*scale
			shapes.tilted_box(parent,at+Vector3(cos(bend)*distance,thick*0.24,sin(bend)*distance),Vector3(0.38*scale,thick,thick),"6b6244",Vector3(0,-bend,0.025))
		foliage.plant(at+Vector3(cos(angle)*1.1*scale,0,sin(angle)*1.1*scale),5,0.6,rng.randf()*TAU)

func dirt(cell: Vector2i) -> void:
	var p: Vector3 = _point(cell)
	var grain: float = noise.get_noise_2d(cell.x*1.7,cell.y*1.7)
	if grain>0.08:
		shapes.shard(parent,p+Vector3(0,0.007,0),Vector3(0.62,0.016,0.46),String(tints.get("dust","ae976d")),rng.randi(),rng.randf()*TAU)
	if rng.randf()<0.32:
		var at: Vector3 = p+Vector3(rng.randf_range(-0.24,0.24),0.025,rng.randf_range(-0.24,0.24))
		shapes.shard(parent,at,Vector3(0.09,0.035,0.12),String(tints.get("grit","b8ad8b")),rng.randi())

## Loose ground on a wild map (layout `ground`, style "scree"): a tile in broad tint
## patches, scattered gravel and the odd half-buried stone. `wet` adds slick glints.
func scree(cell: Vector2i, p: Vector3, colors: Array, growth: float, style: Dictionary) -> void:
	var tint: String = String(colors[clampi(roundi((growth+0.5)*(colors.size()-1)),0,colors.size()-1)])
	shapes.box(parent,p-Vector3(0,0.06,0),Vector3(0.5,0.12,0.5),tint)
	var pebbles: Array = style.get("pebbles",["9a8d72","847a64","b0a283","6f6656"])
	var density: float = float(style.get("gravel",0.7))
	for i: int in 3:
		if rng.randf()<density*(0.6 if i else 1.0):
			var at: Vector3 = p+Vector3(rng.randf_range(-0.22,0.22),0.02,rng.randf_range(-0.22,0.22))
			var size: float = rng.randf_range(0.05,0.13)
			shapes.shard(parent,at,Vector3(size*rng.randf_range(0.8,1.5),size*0.6,size),String(pebbles[rng.randi_range(0,pebbles.size()-1)]),rng.randi(),rng.randf()*TAU)
	if rng.randf()<float(style.get("stones",0.05)):
		var size: float = rng.randf_range(0.18,0.34)
		shapes.shard(parent,p+Vector3(rng.randf_range(-0.12,0.12),size*0.18,rng.randf_range(-0.12,0.12)),Vector3(size*1.3,size*0.7,size),String(pebbles[rng.randi_range(0,pebbles.size()-1)]),rng.randi(),rng.randf()*TAU)
	if style.get("wet",false) and rng.randf()<float(style.get("wet_chance",0.12)):
		var glint: StandardMaterial3D = shapes.material(String(style.get("sheen","4c5a5c")))
		glint.roughness = 0.12
		glint.metallic = 0.35
		shapes.shard(parent,p+Vector3(rng.randf_range(-0.15,0.15),0.008,rng.randf_range(-0.15,0.15)),Vector3(rng.randf_range(0.18,0.4),0.012,rng.randf_range(0.14,0.3)),String(style.get("sheen","4c5a5c")),rng.randi(),rng.randf()*TAU)
