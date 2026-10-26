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
## Ground kinds drawn as loose scree (layout `ground`): no paved shoulders or curbs.
var loose: Array = []
## A fern at the foot of each tree (flora `root_ferns`; a dense forest leaves them out).
var root_ferns: bool = true
## The ground style laid at a cell (cell, kind) -> Dictionary: a flora area may lay its own, so
## a stone stops where another style begins (雪亭镇's slabs meeting the 官道's 青石板).
var style_at: Callable
const GRASS: Array[String] = ["grass", "forest_floor", "forest", "boundary"]
const PAVING: Array[String] = ["town_ground", "street", "floor_yard", "rock"]
const STONE: Array[String] = ["899794", "98a29d", "a6ada3", "939e9b", "afb4aa"]

func _point(cell: Vector2i) -> Vector3:
	return Vector3(cell.x/32.0,0,cell.y/32.0)

## Whether `cell` is laid in the same style as the stone being placed (a map without styles
## gives every kind a fresh empty one, which still matches).
func _same_style(cell: Vector2i, kind: String, style: Dictionary) -> bool:
	if not style_at.is_valid():
		return true
	var other: Dictionary = style_at.call(cell,kind)
	return is_same(other,style) or other.is_empty() and style.is_empty()

## Laid in big slabs: other paving stops short of it rather than run its stones in.
func _slab(cell: Vector2i, kind: String) -> bool:
	return style_at.is_valid() and (style_at.call(cell,kind) as Dictionary).get("style","")=="slabs"

## A surface at least two cells thick round `cell`: a strip one cell wide (a cart rut, a
## narrow track) keeps its crisp line, it neither frays nor sheds onto its neighbours.
static func broad(cells: Dictionary[Vector2i,String], cell: Vector2i) -> bool:
	var same: int = 0
	for y: int in range(-1,2):
		for x: int in range(-1,2):
			same += 1 if cells.get(cell+Vector2i(x,y)*16,"")==cells.get(cell,"") else 0
	return same >= 5

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

## 花石子路 (latemoon/park/moon2.c: 以不同颜色的细石砌成各种图案…但每幅图案又有独立的内容):
## pebbles set on edge in panels `panel` cells square, a dark line round each; every panel its own
## figure, picked by its place — a flower of four or six petals, a coin, a fish — in the accent
## pebbles (`accents`: [petal, heart, line, leaf]) over the plain ones (`stones`). Worn pebbles
## are missing here and there (`missing`), the bed showing.
func mosaic(cell: Vector2i, style: Dictionary) -> void:
	var p: Vector3 = _point(cell)
	var size: int = int(style.get("panel",6))
	var c := Vector2i(floori(cell.x/16.0),floori(cell.y/16.0))
	var local := Vector2i(posmod(c.x,size),posmod(c.y,size))
	var panel := Vector2i(floori(float(c.x)/size),floori(float(c.y)/size))
	var figure: int = posmod(panel.x*7+panel.y*13+panel.x*panel.y,4)
	var stones: Array = style.get("stones",["8e8c82","9a978c","84827a","a4a196"])
	var accents: Array = style.get("accents",["ece6d6","b8452f","3e3c38","5e7a4a"])
	shapes.box(parent,p-Vector3(0,0.075,0),Vector3(0.51,0.12,0.51),String(style.get("bed","6a6658")))
	for sy: int in 2:
		for sx: int in 2:
			var f := Vector2(local.x*2+sx+0.5,local.y*2+sy+0.5)-Vector2(size,size)
			var tint: String = String(stones[(c.x*3+c.y*5+sx+sy*2+posmod(c.x*c.y,3))%stones.size()])
			if not style.get("figures",true):
				# Plain cobbles (entrance.c: 用鹅卵石铺成的小路): no panels, no figures.
				pass
			elif local.x==0 and sx==0 or local.y==0 and sy==0:
				tint = String(accents[2])
			else:
				var r: float = f.length()/size
				var a: float = f.angle()
				match figure:
					0, 1:
						var lobes: float = 4.0 if figure==0 else 6.0
						if r<0.2:
							tint = String(accents[1])
						elif r<0.62 and cos(a*lobes)>0.1+r*0.3:
							tint = String(accents[0])
						elif r>0.66 and r<0.8 and cos(a*lobes+PI)>0.6:
							tint = String(accents[3])
					2:
						if r>0.42 and r<0.68:
							tint = String(accents[0])
						elif absf(f.x)<0.9 and absf(f.y)<0.9:
							tint = String(accents[2])
					_:
						# A fish swimming across the panel: a body, a tail and an eye.
						var body: float = pow(f.x/(size*0.55),2)+pow(f.y/(size*0.28),2)
						if body<1.0 and f.x>-size*0.4:
							tint = String(accents[1] if body>0.55 else accents[0])
						elif f.x<-size*0.4 and f.x>-size*0.75 and absf(f.y)<(-f.x-size*0.4)*0.9:
							tint = String(accents[1])
						if absf(f.x-size*0.28)<0.6 and absf(f.y+0.5)<0.6:
							tint = String(accents[2])
			if rng.randf()<float(style.get("missing",0.03)):
				continue
			var at: Vector3 = p+Vector3((sx-0.5)*0.25+rng.randf_range(-0.02,0.02),-0.01+rng.randf_range(-0.01,0.008),(sy-0.5)*0.25+rng.randf_range(-0.02,0.02))
			shapes.box(parent,at,Vector3(0.21,0.07,0.21),tint)

## Flagstones of random running lengths. Layout `ground`: {"style": "paving", "stones": [...],
## "worn": [...], "bed": hex, "moss": hex} gives a town its own stone (绮云镇's 青石).
func paving(cell: Vector2i, cells: Dictionary[Vector2i,String], painted: Dictionary[Vector2i,bool], style: Dictionary = {}) -> void:
	var p: Vector3 = _point(cell)
	var width: int = rng.randi_range(1,3)
	var depth: int = rng.randi_range(1,2)
	# Random running lengths, with staggered joints and no stones over a doorway footprint.
	for extent: Vector2i in [Vector2i(width,depth), Vector2i(width,1), Vector2i(1,1)]:
		var free: bool = true
		for y: int in extent.y:
			for x: int in extent.x:
				var next := cell+Vector2i(x,y)*16
				free = free and cells.get(next,"") in PAVING and not painted.has(next) and not _covered(next) and not _slab(next,cells[next])
		if free:
			width = extent.x
			depth = extent.y
			break
	for y: int in depth:
		for x: int in width:
			painted[cell+Vector2i(x,y)*16] = true
	p += Vector3((width-1)*0.25,0,(depth-1)*0.25)
	shapes.box(parent,p-Vector3(0,0.075,0),Vector3(width*0.5+0.01,0.12,depth*0.5+0.01),String(style.get("bed","787c66")))
	var worn: float = wear(p)
	if worn>0.25:
		shapes.shard(parent,p+Vector3(0,0.002,0),Vector3(width*0.64,0.02,depth*0.64),String(style.get("mud","81775f")),rng.randi())
	if worn<0.43 or rng.randf()<0.20:
		var size := Vector3(width*0.5-0.02,0.09,depth*0.5-0.02)
		var yaw: float = rng.randf_range(-0.065,0.065)
		p += Vector3(rng.randf_range(-0.025,0.025),rng.randf_range(-0.02,0.015),rng.randf_range(-0.025,0.025))
		var stones: Array = style.get("stones",STONE)
		var tint: String = String(stones[rng.randi_range(0,stones.size()-1)])
		if worn>0.15:
			var worn_stones: Array = style.get("worn",["7b8b83","89958b","939c8e"])
			tint = String(worn_stones[rng.randi_range(0,worn_stones.size()-1)])
		shapes.shard(parent,p,size,tint,rng.randi(),yaw)
		# Selected broken corners and fissures, not a grid-wide noise overlay.
		if rng.randf()<0.08:
			shapes.tilted_box(parent,p+Vector3(size.x*0.26,0.047,0.04),Vector3(size.x*0.27,0.008,0.018),String(style.get("crack","707c72")),Vector3(0,-0.35,0))
		if style.has("moss") and rng.randf()<float(style.get("moss_chance",0.12)):
			# Moss in the joints of old flags.
			shapes.box(parent,p+Vector3(size.x*0.5,0.03,rng.randf_range(-0.2,0.2)*depth),Vector3(0.04,0.02,depth*0.4),String(style["moss"]))
	if foliage != null and (rng.randf()<0.10 or worn>0.15 and rng.randf()<0.25):
		foliage.plant(p+Vector3(-width*0.25+0.03,0.03,depth*0.19),0,rng.randf_range(0.19,0.40),rng.randf()*TAU)

## Old 大石板 (layout `ground`: {"style": "slabs", "lengths": [min, max] cells along a row,
## "depths": [min, max] cells deep, "stones": [...], "worn": [...], "bed": the joints,
## "cracks", "broken", "sunk": chances, "moss", "tufts"}): big flags laid long ago and walked on
## since (square.c: 整齐地铺著大石板). A whole stretch is laid at once, row by row in random
## lengths and depths, so the joints wander instead of lining up; each stone is a little skewed,
## tilted and set high or low, worn at the corners, now and then cracked through, broken in two
## or sunk with mud and grass in the gap. No stone crosses a doorway, a building or other ground.
func slabs(cell: Vector2i, cells: Dictionary[Vector2i,String], painted: Dictionary[Vector2i,bool], style: Dictionary) -> void:
	var kind: String = cells[cell]
	var stretch: Dictionary[Vector2i,bool] = {cell: true}
	var queue: Array[Vector2i] = [cell]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		for shift: Vector2i in [Vector2i(-16,0),Vector2i(16,0),Vector2i(0,-16),Vector2i(0,16)]:
			var next: Vector2i = at+shift
			if not stretch.has(next) and cells.get(next,"")==kind and not painted.has(next) and not _covered(next) and _same_style(next,kind,style):
				stretch[next] = true
				queue.append(next)
	var order: Array[Vector2i] = stretch.keys()
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y<b.y or a.y==b.y and a.x<b.x)
	for start: Vector2i in order:
		if not painted.has(start):
			_flag(start,stretch,painted,style)

## One flag of an old pavement from `start` (its north-west cell), as long and deep as the cells
## left free allow.
func _flag(start: Vector2i, stretch: Dictionary[Vector2i,bool], painted: Dictionary[Vector2i,bool], style: Dictionary) -> void:
	var lengths: Array = style.get("lengths",[2,3])
	var depths: Array = style.get("depths",[1,2])
	var across: int = rng.randi_range(int(lengths[0]),int(lengths[1]))
	var deep: int = rng.randi_range(int(depths[0]),int(depths[1]))
	while deep>1 and not _free(start,1,deep,stretch,painted):
		deep -= 1
	while across>1 and not _free(start,across,deep,stretch,painted):
		across -= 1
	for y: int in deep:
		for x: int in across:
			painted[start+Vector2i(x,y)*16] = true
	var p: Vector3 = _point(start)+Vector3((across-1)*0.25,0,(deep-1)*0.25)
	shapes.box(parent,p-Vector3(0,0.075,0),Vector3(across*0.5+0.01,0.12,deep*0.5+0.01),String(style.get("bed","6f6c5e")))
	var worn: float = wear(p)
	var stones: Array = style.get("stones",STONE)
	var tint: String = String(stones[rng.randi_range(0,stones.size()-1)])
	if worn>0.15:
		var worn_stones: Array = style.get("worn",stones)
		tint = String(worn_stones[rng.randi_range(0,worn_stones.size()-1)])
	var joint: float = float(style.get("joint",0.04))+rng.randf_range(0.0,0.035)
	var stone := Vector3(across*0.5-joint,0.09,deep*0.5-joint)
	var mud: String = String(style.get("mud","81775f"))
	if worn>0.43 and rng.randf()>=0.20 or rng.randf()<float(style.get("sunk",0.025)):
		# A flag lifted or sunk: mud on the bed where a puddle can lie, grass at its edge.
		shapes.shard(parent,p+Vector3(0,0.002,0),Vector3(stone.x*1.15,0.02,stone.z*1.15),mud,rng.randi())
		if foliage != null:
			foliage.plant(p+Vector3(stone.x*0.4,0.02,-stone.z*0.3),0,rng.randf_range(0.3,0.55),rng.randf()*TAU)
		return
	var at: Vector3 = p+Vector3(rng.randf_range(-0.025,0.025),rng.randf_range(-0.022,0.012),rng.randf_range(-0.025,0.025))
	var lean := Vector3(rng.randf_range(-0.035,0.035),rng.randf_range(-0.05,0.05),rng.randf_range(-0.035,0.035))
	if across>1 and rng.randf()<float(style.get("broken",0.10)):
		# Broken in two across its length, the halves settled apart.
		var cut: float = rng.randf_range(0.35,0.65)
		var left := Vector3(stone.x*cut-0.02,stone.y,stone.z)
		var right := Vector3(stone.x*(1.0-cut)-0.02,stone.y,stone.z)
		shapes.tilted_box(parent,at+Vector3(-stone.x*0.5+left.x*0.5,0,0),left,tint,lean)
		shapes.tilted_box(parent,at+Vector3(stone.x*0.5-right.x*0.5,-0.015,0),right,tint,-lean)
	elif rng.randf()<0.35:
		# Worn round at the corners.
		shapes.shard(parent,at,stone+Vector3(0.04,0,0.04),tint,rng.randi(),lean.y)
	else:
		shapes.tilted_box(parent,at,stone,tint,lean)
	if worn>0.3:
		shapes.shard(parent,at+Vector3(0,0.047,0),Vector3(stone.x*0.6,0.012,stone.z*0.6),mud,rng.randi())
	if rng.randf()<float(style.get("cracks",0.12)):
		# A fissure across an old stone, not a grid-wide noise overlay.
		shapes.tilted_box(parent,at+Vector3(rng.randf_range(-0.1,0.1)*across,0.048,0),Vector3(stone.x*0.55,0.008,0.02),String(style.get("crack","6a675a")),Vector3(0,rng.randf_range(-0.6,0.6),0))
	if style.has("moss") and rng.randf()<float(style.get("moss_chance",0.08)):
		shapes.box(parent,p+Vector3(stone.x*0.5,0.03,0),Vector3(0.04,0.02,stone.z*0.7),String(style["moss"]))
	if foliage != null and rng.randf()<float(style.get("tufts",0.10)):
		# Grass in a joint, at a corner where feet seldom go.
		foliage.plant(p+Vector3(-stone.x*0.5,0.03,stone.z*0.5),0,rng.randf_range(0.19,0.36),rng.randf()*TAU)

func _free(start: Vector2i, across: int, deep: int, stretch: Dictionary[Vector2i,bool], painted: Dictionary[Vector2i,bool]) -> bool:
	for y: int in deep:
		for x: int in across:
			var next: Vector2i = start+Vector2i(x,y)*16
			if not stretch.has(next) or painted.has(next):
				return false
	return true

func edge(cell: Vector2i, cells: Dictionary[Vector2i,String]) -> void:
	var kind: String = cells[cell]
	if kind not in PAVING and kind not in ["path","riverbank"] or kind in loose:
		return
	var paved: bool = kind in PAVING
	var p: Vector3 = _point(cell)
	for shift: Vector2i in [Vector2i(-16,0),Vector2i(16,0),Vector2i(0,-16),Vector2i(0,16)]:
		var neighbor: Vector2i = cell+shift
		if paved and not _covered(neighbor) and cells.get(neighbor,"") in ["path","riverbank"]:
			if broad(cells,neighbor):
				_spill(p,Vector3(shift.x/16.0,0,shift.y/16.0))
			continue
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

## Where flags give way to a dirt path: earth trodden onto the stone's edge, a loose or broken
## stone kicked out onto the dirt, grit between, so neither surface ends in a ruled line.
func _spill(p: Vector3, outward: Vector3) -> void:
	var along := Vector3(-outward.z,0,outward.x)
	var edge_at: Vector3 = p+outward*0.25
	if rng.randf()<0.4:
		shapes.shard(parent,edge_at-outward*rng.randf_range(0.02,0.12)+along*rng.randf_range(-0.15,0.15)+Vector3(0,0.05,0),Vector3(rng.randf_range(0.25,0.45),0.012,rng.randf_range(0.2,0.4)),String(tints.get("dust","ae976d")),rng.randi(),rng.randf()*TAU)
	if rng.randf()<0.25:
		var size: float = rng.randf_range(0.14,0.3)
		shapes.shard(parent,edge_at+outward*rng.randf_range(0.08,0.4)+along*rng.randf_range(-0.2,0.2)+Vector3(0,size*0.15,0),Vector3(size*1.3,size*0.45,size),String(tints.get("chips",["89917a","a6aa8b","b1ab8e"])[rng.randi_range(0,2)]),rng.randi(),rng.randf()*TAU)
	for grit: int in rng.randi_range(0,2):
		shapes.shard(parent,edge_at+outward*rng.randf_range(-0.1,0.45)+along*rng.randf_range(-0.25,0.25)+Vector3(0,0.035,0),Vector3(rng.randf_range(0.05,0.11),0.05,rng.randf_range(0.05,0.12)),String(tints.get("grit","b8ad8b")),rng.randi(),rng.randf()*TAU)

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
		if root_ferns:
			foliage.plant(at+Vector3(cos(angle)*1.1*scale,0,sin(angle)*1.1*scale),5,0.6,rng.randf()*TAU)

func dirt(cell: Vector2i) -> void:
	var p: Vector3 = _point(cell)
	var grain: float = noise.get_noise_2d(cell.x*1.7,cell.y*1.7)
	if grain>0.08:
		shapes.shard(parent,p+Vector3(0,0.007,0),Vector3(0.62,0.016,0.46),String(tints.get("dust","ae976d")),rng.randi(),rng.randf()*TAU)
	if rng.randf()<0.32:
		var at: Vector3 = p+Vector3(rng.randf_range(-0.24,0.24),0.025,rng.randf_range(-0.24,0.24))
		shapes.shard(parent,at,Vector3(0.09,0.035,0.12),String(tints.get("grit","b8ad8b")),rng.randi())

## A forest floor (layout `ground`, style "litter"): a tile in broad tint patches strewn with
## fallen needles (`needles`: colours, `strew`: about how many to a tile), the odd cone,
## twig and cushion of moss.
func litter(cell: Vector2i, p: Vector3, colors: Array, growth: float, style: Dictionary) -> void:
	var tint: String = String(colors[clampi(roundi((growth+0.5)*(colors.size()-1)),0,colors.size()-1)])
	shapes.box(parent,p-Vector3(0,0.06,0),Vector3(0.5,0.12,0.5),tint)
	var needles: Array = style.get("needles",["8a5a36","9c6a3e","7a4f31","a8794a"])
	var strew: float = float(style.get("strew",1.2))
	while strew > 0.0:
		if rng.randf() < strew:
			var at: Vector3 = p+Vector3(rng.randf_range(-0.21,0.21),0.008,rng.randf_range(-0.21,0.21))
			shapes.tilted_box(parent,at,Vector3(rng.randf_range(0.12,0.22),0.014,0.024),String(needles[rng.randi_range(0,needles.size()-1)]),Vector3(0,rng.randf()*TAU,0))
		strew -= 1.0
	if rng.randf() < float(style.get("cones",0.03)):
		var at: Vector3 = p+Vector3(rng.randf_range(-0.18,0.18),0.05,rng.randf_range(-0.18,0.18))
		var cone := Vector3(0,rng.randf()*TAU,1.45)
		shapes.tilted_box(parent,at,Vector3(0.1,0.16,0.1),String(style.get("cone","6e4a2e")),cone)
		shapes.tilted_box(parent,at+Vector3(0,0.01,0),Vector3(0.13,0.07,0.13),String(style.get("cone_scales","8a5f3a")),cone)
	if rng.randf() < float(style.get("twigs",0.04)):
		shapes.tilted_box(parent,p+Vector3(rng.randf_range(-0.15,0.15),0.02,rng.randf_range(-0.15,0.15)),Vector3(0.42,0.035,0.035),"5d4634",Vector3(0,rng.randf()*TAU,0))
	if growth < float(style.get("moss_below",-0.1)) and rng.randf() < float(style.get("moss",0.18)):
		var moss: Array = style.get("moss_colors",["4f6b38","5d7a3f","6e8a47"])
		shapes.shard(parent,p+Vector3(rng.randf_range(-0.15,0.15),0.012,rng.randf_range(-0.15,0.15)),Vector3(rng.randf_range(0.2,0.4),0.03,rng.randf_range(0.18,0.34)),String(moss[rng.randi_range(0,moss.size()-1)]),rng.randi(),rng.randf()*TAU)

## A bough of a great tree walked along in the air (layout `ground`, style "bark"): thick
## grey-brown wood with ridged bark, sprigs of needles out over its edges.
func bark(cell: Vector2i, p: Vector3, colors: Array, cells: Dictionary[Vector2i,String], style: Dictionary) -> void:
	var thick: float = float(style.get("thickness",0.45))
	shapes.box(parent,p-Vector3(0,thick/2,0),Vector3(0.5,thick,0.5),String(colors[absi(cell.x*7+cell.y*3)/16%colors.size()]))
	if rng.randf() < 0.45:
		shapes.box(parent,p+Vector3(rng.randf_range(-0.16,0.16),0.012,0),Vector3(0.06,0.03,0.42),String(style.get("ridge","4a3a2e")))
	var sprigs: Array = style.get("sprigs",["2c4a36","3a5c40","4b6d48"])
	for shift: Vector2i in [Vector2i(-16,0),Vector2i(16,0),Vector2i(0,-16),Vector2i(0,16)]:
		if cells.get(cell+shift,"") == cells[cell]:
			continue
		var out := Vector3(shift.x,0,shift.y)/16.0
		shapes.box(parent,p+out*0.24-Vector3(0,thick*0.5,0),Vector3(0.5 if shift.x==0 else 0.06,thick*0.9,0.06 if shift.x==0 else 0.5),String(style.get("side","56443a")))
		if rng.randf() < float(style.get("sprig_chance",0.35)):
			var at: Vector3 = p+out*rng.randf_range(0.3,0.5)+Vector3(rng.randf_range(-0.15,0.15),-0.05,rng.randf_range(-0.15,0.15))
			shapes.box(parent,at,Vector3(rng.randf_range(0.2,0.36),0.14,rng.randf_range(0.2,0.36)),String(sprigs[rng.randi_range(0,sprigs.size()-1)]))

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
		shapes.shard(parent,p+Vector3(rng.randf_range(-0.15,0.15),0.008,rng.randf_range(-0.15,0.15)),Vector3(rng.randf_range(0.18,0.4),0.012,rng.randf_range(0.14,0.3)),String(style.get("sheen","4c5a5c"))+":gloss",rng.randi(),rng.randf()*TAU)
