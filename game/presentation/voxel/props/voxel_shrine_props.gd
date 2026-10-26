extends RefCounted

## Shrines and temples: niches and their gods, offering tables, incense burners, candles,
## prayer cushions and the paper charms on the walls. Faces +z unless rotated; sizes and
## colours from the data. What stands on the floor is a blocked box in the map layout.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var s: Shapes
var root: Node3D
var ambience: VoxelAmbience
var data: Dictionary

func draw(shapes: Shapes, parent: Node3D, look: Dictionary, w: float, d: float) -> bool:
	s = shapes
	root = parent
	data = look
	match String(look["kind"]):
		"shrine_niche": _niche(w,d)
		"earth_god": _earth_god(Vector3.ZERO,1.0)
		"altar_table": _altar_table(w,d)
		"incense_burner": _incense_burner(w)
		"prayer_cushion": _cushion(w)
		"paper_charms": _charms(w)
		"candles": _candles(Vector3.ZERO,int(data.get("count",3)))
		"cobweb": _cobweb(w)
		"rubble": _rubble(w,d)
		"post": _post()
		"paper_burner": _paper_burner(w,d)
		"buddha": _buddha(w,d)
		_:
			return false
	return true

## 神龛: a small roofed niche in a wall, its god inside and a faded cloth over the front.
func _niche(w: float, d: float) -> void:
	var wood: String = String(data.get("wood","5e3b2a"))
	var red: String = String(data.get("cloth","8a3a2c"))
	var base: float = float(data.get("base",0.9))
	s.box(root,Vector3(0,base/2,0),Vector3(w,base,d),String(data.get("plinth","8b7656")))
	s.box(root,Vector3(0,base+0.04,0),Vector3(w+0.08,0.08,d+0.06),wood)
	for x: float in [-w/2+0.06,w/2-0.06]:
		s.box(root,Vector3(x,base+0.7,d*0.3),Vector3(0.1,1.3,0.1),wood)
	s.box(root,Vector3(0,base+0.7,-d/2+0.05),Vector3(w,1.4,0.1),"3a2a20")
	s.box(root,Vector3(0,base+1.42,0.05),Vector3(w+0.3,0.12,d+0.2),wood)
	s.tilted_box(root,Vector3(0,base+1.55,0.05),Vector3(w+0.5,0.1,d*0.7),String(data.get("roof","4c4a44")),Vector3(0.25,0,0))
	for x: float in [-w/2-0.2,w/2+0.2]:
		s.box(root,Vector3(x,base+1.5,d*0.35),Vector3(0.12,0.12,0.12),wood)
	# A torn red cloth across the top, one end hanging loose.
	s.box(root,Vector3(-w*0.1,base+1.26,d*0.36),Vector3(w*0.8,0.22,0.03),red)
	s.tilted_box(root,Vector3(w*0.36,base+1.0,d*0.37),Vector3(0.16,0.5,0.03),red,Vector3(0,0,0.25))
	_earth_god(Vector3(0,base+0.08,0),0.9)
	if data.get("broken",true):
		s.shard(root,Vector3(w*0.25,0.05,d*0.7),Vector3(0.18,0.1,0.14),"a99b84",1)
		s.shard(root,Vector3(-w*0.15,0.04,d*0.8),Vector3(0.12,0.08,0.1),"b5ad97",4)

## 土地公: a seated old man with a white beard, black cap and robe, a staff at his side.
## Broken (残破不堪): one arm gone, paint flaking, a crack across him.
func _earth_god(at: Vector3, scale: float) -> void:
	var robe: String = String(data.get("robe","9d6a3c"))
	var broken: bool = data.get("broken",true)
	var k: float = scale
	s.box(root,at+Vector3(0,0.2*k,0),Vector3(0.62*k,0.4*k,0.5*k),robe)
	s.box(root,at+Vector3(0,0.5*k,-0.03*k),Vector3(0.5*k,0.42*k,0.38*k),robe)
	s.box(root,at+Vector3(0,0.42*k,0.1*k),Vector3(0.28*k,0.06*k,0.26*k),"c7a24c")
	s.box(root,at+Vector3(0,0.85*k,0),Vector3(0.3*k,0.3*k,0.28*k),"d6b48b")
	s.box(root,at+Vector3(0,0.73*k,0.13*k),Vector3(0.26*k,0.22*k,0.08*k),"ece6d6")
	s.box(root,at+Vector3(0,0.62*k,0.15*k),Vector3(0.16*k,0.14*k,0.07*k),"e2dccb")
	s.box(root,at+Vector3(0,1.04*k,-0.01*k),Vector3(0.36*k,0.14*k,0.32*k),"2b2724")
	for side: float in [-1.0,1.0]:
		s.box(root,at+Vector3(side*0.24*k,1.05*k,-0.02*k),Vector3(0.14*k,0.05*k,0.07*k),"2b2724")
	s.box(root,at+Vector3(-0.32*k,0.48*k,0.05*k),Vector3(0.14*k,0.3*k,0.16*k),robe)
	s.box(root,at+Vector3(-0.36*k,0.55*k,0.16*k),Vector3(0.05*k,1.0*k,0.05*k),"6b4b2f")
	if broken:
		s.box(root,at+Vector3(0.3*k,0.6*k,0.0),Vector3(0.1*k,0.08*k,0.12*k),"8b7a62")
		s.box(root,at+Vector3(0.06*k,0.88*k,0.145*k),Vector3(0.02*k,0.24*k,0.01*k),"5a4a3a")
		for flake: int in 3:
			s.box(root,at+Vector3((flake-1)*0.14*k,0.3*k,0.256*k),Vector3(0.08*k,0.06*k,0.01*k),"8f8270")
	else:
		s.box(root,at+Vector3(0.32*k,0.48*k,0.05*k),Vector3(0.14*k,0.3*k,0.16*k),robe)
		s.box(root,at+Vector3(0.33*k,0.42*k,0.18*k),Vector3(0.14*k,0.1*k,0.1*k),"d7b45a")

## 供桌: the offering table, an incense burner, offerings and candle stubs on it.
func _altar_table(w: float, d: float) -> void:
	var wood: String = String(data.get("wood","5a3a28"))
	s.box(root,Vector3(0,0.82,0),Vector3(w,0.12,d),wood)
	s.box(root,Vector3(0,0.66,d/2-0.03),Vector3(w-0.1,0.22,0.04),String(data.get("apron","7a2f24")))
	for x: float in [-w/2+0.1,w/2-0.1]:
		for z: float in [-d/2+0.1,d/2-0.1]:
			s.box(root,Vector3(x,0.4,z),Vector3(0.1,0.8,0.1),wood)
	s.box(root,Vector3(0,0.98,0),Vector3(0.36,0.2,0.3),"6f6656")
	s.box(root,Vector3(0,1.09,0),Vector3(0.3,0.03,0.24),"b4ab98")
	# Burnt-out stubs of incense in cold ash: nobody tends it (似乎没有人照顾).
	for stick: int in 3:
		s.tilted_box(root,Vector3((stick-1)*0.06,1.13,0),Vector3(0.02,0.08,0.02),"5a2f25",Vector3(0,0,(stick-1)*0.4))
	# Old offerings gone dry and grey with dust, a cracked cup.
	s.box(root,Vector3(-w*0.3,0.9,0.05),Vector3(0.3,0.03,0.3),"b8b2a2")
	for fruit: int in 3:
		s.box(root,Vector3(-w*0.3+(fruit-1)*0.08,0.94,0.05+fruit%2*0.06),Vector3(0.08,0.06,0.08),["6e5638","5f4a33","7a6644"][fruit])
	s.box(root,Vector3(w*0.28,0.93,0.08),Vector3(0.1,0.1,0.1),"bdb6a4")
	s.box(root,Vector3(w*0.31,0.93,0.08),Vector3(0.02,0.1,0.11),"6e675a")
	# 残烛: one guttering stub the hiding 黄霸 keeps alight, a dead one beside it.
	_candles(Vector3(w*0.4,0.88,-0.05),1)
	s.box(root,Vector3(-w*0.42,0.9,-0.05),Vector3(0.14,0.04,0.14),"e6dcc2")
	s.box(root,Vector3(-w*0.42,0.94,-0.05),Vector3(0.07,0.05,0.07),"d8cdb2")

## `tall`: raised on a carved stand (a hall's); `lit`: sticks burning, their smoke rising.
func _incense_burner(w: float) -> void:
	var bronze: String = String(data.get("bronze","6f5a3e"))
	var y: float = 0.0
	if data.get("tall",false):
		y = 0.7
		s.box(root,Vector3(0,0.05,0),Vector3(w*0.9,0.1,w*0.9),"5c3f2b")
		s.box(root,Vector3(0,0.38,0),Vector3(w*0.4,0.6,w*0.4),"6e4a34")
		s.box(root,Vector3(0,0.69,0),Vector3(w*0.85,0.06,w*0.85),"5c3f2b")
	for leg: int in 3:
		var a: float = leg*TAU/3.0
		s.box(root,Vector3(cos(a)*w*0.3,y+0.18,sin(a)*w*0.3),Vector3(0.1,0.36,0.1),bronze)
	s.box(root,Vector3(0,y+0.5,0),Vector3(w*0.8,0.4,w*0.8),bronze)
	s.box(root,Vector3(0,y+0.72,0),Vector3(w*0.9,0.06,w*0.9),"8a7350")
	s.box(root,Vector3(0,y+0.74,0),Vector3(w*0.7,0.03,w*0.7),"aaa294")
	for side: float in [-1.0,1.0]:
		s.box(root,Vector3(side*w*0.47,y+0.8,0),Vector3(0.06,0.18,0.14),bronze)
	if data.get("lit",false):
		# Three sticks burning, their tips glowing, a thread of smoke.
		for stick: int in 3:
			s.box(root,Vector3((stick-1)*0.07,y+0.9,0),Vector3(0.02,0.3,0.02),"8a3a2a")
			s.box(root,Vector3((stick-1)*0.07,y+1.06,0),Vector3(0.03,0.03,0.03),"ff8a3a:glow")
		if ambience != null:
			ambience.smoke(root,Vector3(0,y+1.1,0),String(data.get("smoke","d8d2c4")),5,0.1)
		return
	# Cold: burnt-down sticks leaning in the ash.
	for stick: int in 5:
		s.tilted_box(root,Vector3((stick-2)*0.07,y+0.82,sin(stick*1.7)*0.06),Vector3(0.02,0.14,0.02),"5a2f25",Vector3(0,0,(stick-2)*0.3))

## 蒲团: a round straw cushion, worn through on one side.
func _cushion(w: float) -> void:
	for ring: int in 3:
		var span: float = w*(1.0-ring*0.22)
		s.box(root,Vector3(0,0.05+ring*0.04,0),Vector3(span,0.08,span*0.92),["8f7a4c","a28b58","b39b65"][ring])
	if data.get("worn",true):
		s.box(root,Vector3(w*0.18,0.16,w*0.1),Vector3(w*0.25,0.02,w*0.2),"6e5d3a")
		for straw: int in 4:
			s.tilted_box(root,Vector3(w*0.5,0.02,(straw-1.5)*0.08),Vector3(0.2,0.02,0.02),"b8a46c",Vector3(0,straw*0.4,0))

## Old paper charms pasted on a wall, yellowed, the red writing faded, one hanging off.
func _charms(w: float) -> void:
	var count: int = int(data.get("count",4))
	var height: float = float(data.get("height",1.7))
	for i: int in count:
		var x: float = -w/2+(i+0.5)*w/count
		var y: float = height+sin(i*2.1)*0.18
		var loose: bool = i==count-1
		var paper := Node3D.new()
		paper.position = Vector3(x,y,0.04)
		paper.rotation.z = 0.35 if loose else sin(i*1.3)*0.08
		root.add_child(paper)
		s.box(paper,Vector3.ZERO,Vector3(0.2,0.48,0.015),["d8c27a","cbb46c","e0cc8a"][i%3])
		s.box(paper,Vector3(0,0.02,0.01),Vector3(0.05,0.34,0.01),"a8473a")
		s.box(paper,Vector3(0,0.16,0.01),Vector3(0.12,0.04,0.01),"a8473a")

## Candle stubs in their wax, each flame a flickering little light.
func _candles(at: Vector3, count: int) -> void:
	for i: int in count:
		var base: Vector3 = at+Vector3(i*0.1-(count-1)*0.05,0,sin(i*2.0)*0.06)
		var height: float = [0.18,0.1,0.14][i%3]
		s.box(root,base+Vector3(0,0.02,0),Vector3(0.14,0.04,0.14),"e6dcc2")
		s.box(root,base+Vector3(0,height/2,0),Vector3(0.07,height,0.07),"efe5cc")
		var flame := Node3D.new()
		flame.position = base+Vector3(0,height,0)
		flame.set_meta("light_fixture",true)
		root.add_child(flame)
		s.box(flame,Vector3(0,0.05,0),Vector3(0.04,0.1,0.04),"ffd88a")
		if ambience != null:
			ambience.flame(flame)
	var light := OmniLight3D.new()
	light.position = at+Vector3(0,0.45,0)
	light.light_color = Color("ffb867")
	light.omni_range = float(data.get("range",3.6))
	light.set_meta("day_energy",0.45)
	light.set_meta("night_energy",1.25)
	light.set_meta("flicker",0.12)
	root.add_child(light)

## A web strung across a corner, high up (`height`).
func _cobweb(w: float) -> void:
	var silk: String = String(data.get("color","d9d6cc"))
	var at := Vector3(0,float(data.get("height",2.6)),0)
	for strand: int in 5:
		s.tilted_box(root,at,Vector3(w,0.012,0.012),silk,Vector3(0,(strand-2)*0.35,(strand-2)*0.2))
	for ring: int in 3:
		s.tilted_box(root,at+Vector3(0,-0.05*(ring+1),0),Vector3(w*0.3*(ring+1),0.01,0.01),silk,Vector3(0,0.8,0))

func _rubble(w: float, d: float) -> void:
	var colors: Array = data.get("colors",["8f7f63","a08d6c","b0a07f","7d6e58"])
	for i: int in int(data.get("count",10)):
		var a: float = i*2.4
		var r: float = fposmod(i*0.37,1.0)
		var size: float = 0.1+fposmod(i*0.53,1.0)*0.18
		s.shard(root,Vector3(cos(a)*r*w*0.45,size*0.3,sin(a)*r*d*0.45),Vector3(size*1.3,size*0.6,size),String(colors[i%colors.size()]),i,a)

func _post() -> void:
	var wood: String = String(data.get("wood","6b4b33"))
	var height: float = float(data.get("height",3.1))
	s.box(root,Vector3(0,0.12,0),Vector3(0.5,0.24,0.5),"8a7e68")
	s.box(root,Vector3(0,height/2,0),Vector3(0.3,height,0.3),wood)
	for crack: int in 2:
		s.box(root,Vector3(0.155,0.8+crack*0.9,0),Vector3(0.01,0.5,0.06),"3d2c20")

## 金纸亭 (temple0.c: 庙外的小空地边有一个简陋的金纸亭): a little stove of bricks to burn paper money
## in, a tiled cap on posts over it, its mouth black with soot, ash and charred scraps spilt out
## before it, a curl of smoke.
func _paper_burner(w: float, d: float) -> void:
	var brick: Array = data.get("colors",["7d5a46","8a6450","70503e"])
	for course: int in 6:
		for side: int in 4:
			var along_x: bool = side < 2
			var fixed: float = (d if along_x else w)*0.32*(1 if side%2 else -1)
			var at := Vector3(0,0.1+course*0.18,fixed) if along_x else Vector3(fixed,0.1+course*0.18,0)
			s.box(root,at,Vector3(w*0.66,0.16,0.12) if along_x else Vector3(0.12,0.16,d*0.66),String(brick[(course+side)%brick.size()]))
	s.box(root,Vector3(0,0.52,d*0.33),Vector3(w*0.3,0.36,0.14),"1c1815")
	s.box(root,Vector3(0,1.18,0),Vector3(w*0.72,0.08,d*0.72),"5a4a3c")
	for x: float in [-w*0.36,w*0.36]:
		for z: float in [-d*0.36,d*0.36]:
			s.box(root,Vector3(x,1.45,z),Vector3(0.08,0.55,0.08),"5e4434")
	s.box(root,Vector3(0,1.78,0),Vector3(w*0.95,0.12,d*0.95),"4f4a40")
	s.box(root,Vector3(0,1.9,0),Vector3(w*0.6,0.12,d*0.6),"5a554a")
	s.box(root,Vector3(0,2.02,0),Vector3(0.14,0.2,0.14),"5a554a")
	for scrap: int in 7:
		s.box(root,Vector3(sin(scrap*2.3)*w*0.25,0.02,d*0.45+absf(cos(scrap*1.7))*0.3),Vector3(0.12,0.012,0.09),["3a3530","d2b25a","2a2622","8a857c"][scrap%4])
	if ambience != null:
		ambience.smoke(root,Vector3(0,2.1,0),"9a978d",4,0.2)

## 佛像 with its 夜明珠 (cavehall.c: 佛像顶部有一颗夜明珠发出莹莹的光芒): a seated figure on a
## lotus base, hands in its lap, the pearl on its crown glowing pale blue-white and lighting the
## hall day and night (`stone`: the figure's colours).
func _buddha(w: float, d: float) -> void:
	var stone: Array = data.get("stone",["8d8a7c","9a9789","807d70"])
	var k: float = minf(w,d)*0.55
	for petal: int in 10:
		var a: float = petal*TAU/10.0
		s.tilted_box(root,Vector3(cos(a)*k*0.72,0.32,sin(a)*k*0.62),Vector3(k*0.42,0.2,k*0.3),String(stone[petal%2]),Vector3(0,-a,0.25))
	s.box(root,Vector3(0,0.2,0),Vector3(k*1.5,0.4,k*1.3),String(stone[2]))
	s.box(root,Vector3(0,0.62,0),Vector3(k*1.25,0.38,k*1.0),String(stone[0]))
	s.box(root,Vector3(0,1.22,-k*0.05),Vector3(k*0.8,0.9,k*0.6),String(stone[1]))
	s.box(root,Vector3(0,0.9,k*0.22),Vector3(k*0.5,0.12,k*0.3),String(stone[0]))
	for side: float in [-1.0,1.0]:
		s.box(root,Vector3(side*k*0.44,1.25,0),Vector3(k*0.18,0.7,k*0.3),String(stone[1]))
	s.box(root,Vector3(0,1.86,-k*0.02),Vector3(k*0.46,0.46,k*0.42),String(stone[0]))
	s.box(root,Vector3(0,2.16,-k*0.02),Vector3(k*0.36,0.18,k*0.34),String(stone[2]))
	s.box(root,Vector3(0,2.38,0),Vector3(0.22,0.22,0.22),"e6f2ff:glow")
	var light := OmniLight3D.new()
	light.position = Vector3(0,2.5,0.6)
	light.light_color = Color("cfe4ff")
	light.omni_range = float(data.get("range",7.0))
	light.set_meta("day_energy",1.2)
	light.set_meta("night_energy",1.8)
	root.add_child(light)
