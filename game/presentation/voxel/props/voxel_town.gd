extends RefCounted

## The street and the market (美术规划 group A): stalls under cloth awnings, hand carts and an
## escort's cart, water vats, firewood, a pedlar's shoulder pole, tea bushes in rows, trays of
## tea drying on racks, a town gateway, a boundary stone, strings of lanterns, benches, a well
## and low yard fences. Sizes and colours come from the data; whatever stands tall on walkable
## ground is a blocked box in the map layout.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var s: Shapes
var root: Node3D
var rng: RandomNumberGenerator
var ambience: VoxelAmbience
var data: Dictionary

func draw(shapes: Shapes, parent: Node3D, look: Dictionary, w: float, d: float) -> bool:
	s = shapes
	root = parent
	data = look
	match String(look["kind"]):
		"stall": _stall(w,d)
		"cart": _cart(w,d)
		"water_vat": _water_vat(w)
		"firewood": _firewood(w,d)
		"carry_pole": _carry_pole()
		"tea_bushes": _tea_bushes(w,d)
		"tea_basket": _tea_basket()
		"drying_rack": _drying_rack(w,d)
		"gateway": _gateway(w,d)
		"boundary_stone": _boundary_stone(w,d)
		"lantern_string": _lantern_string()
		"bench": _bench(w,d)
		"well": _well(w)
		"fence": _fence(w,d)
		"cargo": _cargo(w,d)
		"tea_stall": _tea_stall(w,d)
		"stone_blocks": _stone_blocks(w,d)
		"haystack": _haystack(w,d)
		"derrick": _derrick(w,d)
		"tethered_horse": _tethered_horse(w,d)
		"horse": _horse(w,d)
		"camel": _camel(w,d)
		_:
			return false
	return true

## 拴在门前的马 (s_street2.c: 福林楼前车马): a hitching post with its iron ring, and a horse tied
## to it, standing along the box's long axis with its head at +z, one hind foot resting; its
## tail stirs. `coat`, `mane`, `blaze` (a white stripe down the face), `saddle` (a cloth and
## saddle on its back), `post` (false: tied to a ring in the wall instead), `post_side`.
func _tethered_horse(w: float, d: float) -> void:
	var coat: String = String(data.get("coat","6a4a34"))
	var mane: String = String(data.get("mane","2a2420"))
	var long: float = maxf(w,d)
	var along_x: bool = w > d
	var horse := Node3D.new()
	horse.rotation.y = PI/2 if along_x else 0.0
	root.add_child(horse)
	var body_h: float = _horse_body(horse,long,coat,mane)
	# A rope halter down to the post's ring; the post on the horse's `post_side` (-1: its left,
	# against the wall it stands by).
	var post_at := Vector3(0.45*float(data.get("post_side",-1.0)),0,long*0.62)
	if data.get("post",true):
		s.box(horse,post_at+Vector3(0,0.55,0),Vector3(0.16,1.1,0.16),String(data.get("timber","5a4a3a")))
		s.box(horse,post_at+Vector3(0,1.12,0),Vector3(0.2,0.06,0.2),"4a3e32")
		s.box(horse,post_at+Vector3(0,0.9,0.1),Vector3(0.1,0.1,0.02),"3a3835")
	var rope_from := Vector3(0,body_h+0.3,long*0.62)
	var rope_to := post_at+Vector3(0,0.9,0.1)
	var span: Vector3 = rope_to-rope_from
	s.tilted_box(horse,(rope_from+rope_to)/2,Vector3(0.025,0.025,span.length()),"a08e62",Vector3(-atan2(span.y,Vector2(span.x,span.z).length()),atan2(span.x,span.z),0))
	if data.get("saddle",false):
		s.box(horse,Vector3(0,body_h+0.28,-0.05),Vector3(0.56,0.06,0.5),String(data.get("cloth","8a3a2a")))
		s.box(horse,Vector3(0,body_h+0.36,-0.05),Vector3(0.34,0.12,0.36),"5a3a28")
	_horse_tail(horse,body_h,long,mane)

## A 关北 pony standing loose (the horse pen of the 马市, 剧情总纲 §3 第六章 ②): the tethered
## horse's body without post or rope, along the box's long axis, head at +z; `coat`, `mane`,
## `blaze`, `saddle` as the tethered one's, `grazing` (head down to the grass).
func _horse(w: float, d: float) -> void:
	var coat: String = String(data.get("coat",_pick(_colors("colors",["5a3a2a","6a4632","4a4a4e","2a2422","7a4a2a"]))))
	var mane: String = String(data.get("mane","2a2420"))
	var long: float = maxf(w,d)
	var along_x: bool = w > d
	var horse := Node3D.new()
	horse.rotation.y = PI/2 if along_x else 0.0
	root.add_child(horse)
	var body_h: float = _horse_body(horse,long,coat,mane,data.get("grazing",false))
	if data.get("saddle",false):
		s.box(horse,Vector3(0,body_h+0.28,-0.05),Vector3(0.56,0.06,0.5),String(data.get("cloth","8a3a2a")))
		s.box(horse,Vector3(0,body_h+0.36,-0.05),Vector3(0.34,0.12,0.36),"5a3a28")
	_horse_tail(horse,body_h,long,mane)

## The horse itself: barrel, chest, legs (one hind foot resting), neck and head with its blaze,
## ears and eyes. Returns the barrel's height, for what goes on its back.
func _horse_body(horse: Node3D, long: float, coat: String, mane: String, grazing: bool = false) -> float:
	var body_h: float = 1.05
	s.box(horse,Vector3(0,body_h,-0.1),Vector3(0.5,0.52,long*0.62),coat)
	s.box(horse,Vector3(0,body_h+0.08,-long*0.36),Vector3(0.44,0.4,0.2),coat)
	s.box(horse,Vector3(0,body_h+0.24,0),Vector3(0.1,0.12,long*0.5),mane)
	for i: int in 4:
		var x: float = -0.16 if i%2==0 else 0.16
		var z: float = long*0.22 if i<2 else -long*0.3
		var lift: float = 0.08 if i==3 else 0.0
		s.box(horse,Vector3(x,(body_h-0.26)/2+lift,z),Vector3(0.12,body_h-0.26,0.14),coat)
		s.box(horse,Vector3(x,0.05+lift,z+0.02),Vector3(0.13,0.1,0.17),"2e2a26")
	# Neck up and forward, the head down to the post (or to the grass).
	var tilt: float = -0.55 if not grazing else -1.05
	var neck_y: float = body_h+0.4 if not grazing else body_h+0.1
	s.tilted_box(horse,Vector3(0,neck_y,long*0.36),Vector3(0.3,0.75,0.3),coat,Vector3(tilt,0,0))
	s.box(horse,Vector3(0,neck_y+0.1,long*0.44),Vector3(0.1,0.5,0.08),mane)
	var head := Node3D.new()
	head.position = Vector3(0,body_h+0.62 if not grazing else body_h-0.2,long*0.56)
	head.rotation.x = 0.35 if not grazing else 0.9
	horse.add_child(head)
	s.box(head,Vector3(0,-0.18,0.1),Vector3(0.26,0.36,0.44),coat)
	s.box(head,Vector3(0,-0.34,0.32),Vector3(0.22,0.18,0.14),Color(coat).darkened(0.25).to_html(false))
	if data.get("blaze",true):
		s.box(head,Vector3(0,-0.16,0.33),Vector3(0.06,0.3,0.01),"e8e2d8")
	for side: float in [-1.0,1.0]:
		s.tilted_box(head,Vector3(side*0.1,0.06,-0.08),Vector3(0.06,0.16,0.04),coat,Vector3(-0.3,0,side*0.3))
		s.box(head,Vector3(side*0.13,-0.1,0.18),Vector3(0.02,0.04,0.04),"1a1816")
	return body_h

## Its tail, stirring.
func _horse_tail(horse: Node3D, body_h: float, long: float, mane: String) -> void:
	var tail := Node3D.new()
	tail.position = Vector3(0,body_h+0.18,-long*0.46)
	horse.add_child(tail)
	s.tilted_box(tail,Vector3(0,-0.3,-0.06),Vector3(0.08,0.64,0.08),mane,Vector3(0.2,0,0))
	if ambience != null:
		ambience.sway(tail,float(Shapes.place_seed(roundi(root.position.x*8),0,roundi(root.position.z*8),3)%628)/100.0,0.25)

## 骆驼 (关北 A: the caravans at 槐阳城's gate, the camel pen of the 马市): a two-humped camel along
## the box's long axis, head at +z — standing, or `kneeling` (the default) with its legs folded
## under it, chewing; `coat` (dun), `wool` (the darker shag on humps and neck), `load` (bales
## roped between the humps).
func _camel(w: float, d: float) -> void:
	var coat: String = String(data.get("coat","a88a5e"))
	var wool: String = String(data.get("wool","7a5e3e"))
	var long: float = maxf(w,d)
	var along_x: bool = w > d
	var camel := Node3D.new()
	camel.rotation.y = PI/2 if along_x else 0.0
	root.add_child(camel)
	var kneeling: bool = data.get("kneeling",true)
	var body_h: float = 0.62 if kneeling else 1.35
	s.box(camel,Vector3(0,body_h,-0.05),Vector3(0.6,0.62,long*0.6),coat)
	for hump: float in [-0.18,0.2]:
		s.box(camel,Vector3(0,body_h+0.46,hump*long),Vector3(0.42,0.34,long*0.2),wool)
		s.box(camel,Vector3(0,body_h+0.66,hump*long),Vector3(0.26,0.12,long*0.12),wool)
	if kneeling:
		for i: int in 4:
			var x: float = -0.22 if i%2==0 else 0.22
			var z: float = long*0.26 if i<2 else -long*0.28
			s.box(camel,Vector3(x,0.14,z),Vector3(0.16,0.28,0.44),coat)
			s.box(camel,Vector3(x,0.06,z+(0.26 if i<2 else -0.26)),Vector3(0.18,0.12,0.2),"4a3e32")
	else:
		for i: int in 4:
			var x: float = -0.2 if i%2==0 else 0.2
			var z: float = long*0.24 if i<2 else -long*0.28
			s.box(camel,Vector3(x,(body_h-0.3)/2,z),Vector3(0.14,body_h-0.3,0.16),coat)
			s.box(camel,Vector3(x,0.06,z+0.03),Vector3(0.18,0.12,0.22),"4a3e32")
	# The long neck curving up and forward, the head carried high, chewing.
	var neck_base := Vector3(0,body_h+0.1,long*0.3)
	s.tilted_box(camel,neck_base+Vector3(0,0.35,0.15),Vector3(0.26,0.9,0.28),wool,Vector3(-0.5,0,0))
	s.tilted_box(camel,neck_base+Vector3(0,0.95,0.42),Vector3(0.24,0.6,0.26),coat,Vector3(0.25,0,0))
	var head := Node3D.new()
	head.position = neck_base+Vector3(0,1.22,0.5)
	camel.add_child(head)
	s.box(head,Vector3(0,0,0.14),Vector3(0.24,0.26,0.5),coat)
	s.box(head,Vector3(0,-0.08,0.42),Vector3(0.18,0.16,0.14),Color(coat).darkened(0.3).to_html(false))
	for side: float in [-1.0,1.0]:
		s.box(head,Vector3(side*0.1,0.14,-0.08),Vector3(0.06,0.1,0.05),coat)
		s.box(head,Vector3(side*0.12,0.04,0.2),Vector3(0.02,0.04,0.04),"1a1816")
	if data.get("load",false):
		s.box(camel,Vector3(0,body_h+0.5,0),Vector3(0.7,0.4,long*0.16),String(data.get("cloth","8a5a3a")))
		s.box(camel,Vector3(0,body_h+0.66,0),Vector3(0.74,0.04,long*0.44),"a08e62")
	var tail := Node3D.new()
	tail.position = Vector3(0,body_h+0.1,-long*0.42)
	camel.add_child(tail)
	s.tilted_box(tail,Vector3(0,-0.2,-0.04),Vector3(0.06,0.44,0.06),wool,Vector3(0.25,0,0))
	if ambience != null:
		ambience.sway(head,float(Shapes.place_seed(roundi(root.position.x*8),0,roundi(root.position.z*8),5)%628)/100.0,0.12)

func _colors(key: String, fallback: Array) -> Array:
	return data.get(key,fallback)

func _pick(colors: Array) -> String:
	return String(colors[rng.randi_range(0,colors.size()-1)])

## The near corner of a footprint for things set out in front of a stall (its +z side).
func _legs(w: float, d: float, height: float, wood: String) -> void:
	for x: float in [-w/2+0.08,w/2-0.08]:
		for z: float in [-d/2+0.08,d/2-0.08]:
			s.box(root,Vector3(x,height/2,z),Vector3(0.1,height,0.1),wood)

## 摊子: a trestle of boards under a slanting cloth awning on two poles, its wares on top
## and in baskets beneath. `goods`: greens, fruit, fish, meat, eggs, pottery, sweets, toys, tea,
## cloth, straw (sandals and hats), baskets; `awning`: two stripe colours (or [] for none).
func _stall(w: float, d: float) -> void:
	var wood: String = String(data.get("wood","7a5a3e"))
	var top: float = 0.82
	_legs(w,d*0.8,top,wood)
	s.box(root,Vector3(0,top,0),Vector3(w,0.08,d*0.8),String(data.get("board","a07a52")))
	s.box(root,Vector3(0,top+0.08,d*0.38),Vector3(w,0.1,0.05),wood)
	var awning: Array = data.get("awning",["c8bc94","5f7f8c"])
	if not awning.is_empty():
		for x: float in [-w/2+0.06,w/2-0.06]:
			s.box(root,Vector3(x,1.25,-d/2+0.06),Vector3(0.08,2.5,0.08),wood)
			s.box(root,Vector3(x,0.95,d/2-0.06),Vector3(0.07,1.9,0.07),wood)
		var stripes: int = maxi(3,ceili(w/0.36))
		var slope: float = atan2(2.5-1.9,d)
		var cloth := Node3D.new()
		cloth.position = Vector3(0,2.22,0)
		root.add_child(cloth)
		for stripe: int in stripes:
			var x: float = -w/2+(stripe+0.5)*w/stripes
			s.tilted_box(cloth,Vector3(x,0,0),Vector3(w/stripes+0.01,0.05,d+0.3),String(awning[stripe%awning.size()]),Vector3(slope,0,0))
			s.box(cloth,Vector3(x,-0.24,d/2+0.13),Vector3(w/stripes,0.2,0.04),String(awning[stripe%awning.size()]))
	_wares(String(data.get("goods","greens")),w,d*0.8,top+0.06)
	# Baskets and a sack under the boards.
	for i: int in maxi(1,floori(w/0.9)):
		var at := Vector3(-w/2+0.4+i*0.9,0,-d*0.1)
		s.box(root,at+Vector3(0,0.18,0),Vector3(0.36,0.34,0.36),_pick(["a68a55","b89a5e","947a4a"]))

func _wares(goods: String, w: float, d: float, y: float) -> void:
	var count: int = maxi(2,floori(w/0.32))
	for i: int in count:
		var x: float = -w/2+0.18+i*(w-0.36)/maxf(1,count-1)
		for row: int in 2:
			var z: float = (row-0.5)*d*0.45
			var at := Vector3(x+rng.randf_range(-0.03,0.03),y,z)
			match goods:
				"greens":
					s.box(root,at+Vector3(0,0.07,0),Vector3(0.24,0.14,0.2),_pick(["5f8a3c","74a04a","8db35a","4f7a35"]))
					s.box(root,at+Vector3(0.05,0.15,0),Vector3(0.1,0.06,0.16),_pick(["d9dcc0","c9b44a"]))
				"fruit":
					for f: int in 3:
						s.box(root,at+Vector3((f-1)*0.08,0.06+f%2*0.07,0),Vector3(0.09,0.09,0.09),_pick(["d28a3a","c9452f","e0c04e","9ab04a"]))
				"fish":
					s.box(root,at+Vector3(0,0.025,0),Vector3(0.3,0.05,0.4),"5b6c6a")
					s.tilted_box(root,at+Vector3(0,0.07,0),Vector3(0.08,0.06,0.3),_pick(["9eb3b0","b9c6bd","7f948f"]),Vector3(0,rng.randf_range(-0.5,0.5),0))
				"meat":
					s.box(root,at+Vector3(0,0.06,0),Vector3(0.26,0.12,0.22),_pick(["9e3a32","b5473b","c4655a"]))
					s.box(root,at+Vector3(0.06,0.13,0),Vector3(0.1,0.04,0.18),"e6d6c2")
				"eggs":
					s.box(root,at+Vector3(0,0.05,0),Vector3(0.26,0.1,0.26),"a68a55")
					for e: int in 3:
						s.box(root,at+Vector3((e-1)*0.07,0.12,0.02*e),Vector3(0.06,0.07,0.06),"efe6cf")
				"pottery":
					s.box(root,at+Vector3(0,0.12,0),Vector3(0.2,0.24,0.2),_pick(["8b5440","6b4a35","5d7f78","b08a5e"]))
					s.box(root,at+Vector3(0,0.26,0),Vector3(0.12,0.05,0.12),"473b2c")
				"sweets":
					s.box(root,at+Vector3(0,0.03,0),Vector3(0.26,0.05,0.26),"d9cfb4")
					s.box(root,at+Vector3(0,0.08,0),Vector3(0.16,0.06,0.16),_pick(["d65a4a","e6b85c","f1e3bd","c47aa0"]))
				"toys":
					s.box(root,at+Vector3(0,0.1,0),Vector3(0.12,0.2,0.12),_pick(["c8432f","3f6a8f","e2c25c","5d8160"]))
					s.box(root,at+Vector3(0,0.23,0),Vector3(0.1,0.08,0.1),"efe0c0")
				"tea":
					s.box(root,at+Vector3(0,0.08,0),Vector3(0.22,0.16,0.22),_pick(["5d7f78","8b5440","6b5a3e"]))
					s.box(root,at+Vector3(0,0.18,0),Vector3(0.12,0.04,0.12),"c0392b")
				"cloth":
					s.box(root,at+Vector3(0,0.06+row*0.02,0),Vector3(0.26,0.12,0.36),_pick(["4a6f8f","b4473a","d6b862","5d8160","a77ba0","e8e0cc"]))
				"straw":
					s.box(root,at+Vector3(0,0.03,0),Vector3(0.24,0.05,0.34),"c4ad72")
					s.box(root,at+Vector3(0,0.08,0),Vector3(0.16,0.05,0.2),"b39a5c")
				_:
					s.box(root,at+Vector3(0,0.12,0),Vector3(0.24,0.24,0.24),_pick(["a68a55","b89a5e","947a4a"]))

## A hand cart: a bed on two spoked wheels, its shafts resting on the ground, loaded with
## `cargo` (sacks, crates, jars, firewood, none). `flag`: an escort's banner on a staff (镖旗).
func _cart(w: float, d: float) -> void:
	var wood: Array = _colors("colors",["7a5a3e","8a6a45","6a4c33"])
	var bed_y: float = 0.72
	s.box(root,Vector3(0,bed_y,0),Vector3(w*0.62,0.1,d*0.92),String(wood[0]))
	for x: float in [-w*0.31,w*0.31]:
		s.box(root,Vector3(x,bed_y+0.2,0),Vector3(0.07,0.32,d*0.92),String(wood[1]))
	for x: float in [-w*0.2,w*0.2]:
		s.tilted_box(root,Vector3(x,0.42,d*0.62),Vector3(0.08,0.08,d*0.62),String(wood[2]),Vector3(0.62,0,0))
	for side: float in [-1.0,1.0]:
		var wheel := Node3D.new()
		wheel.position = Vector3(side*(w*0.36+0.06),0.5,-d*0.05)
		root.add_child(wheel)
		for spoke: int in 8:
			var a: float = spoke*TAU/8.0
			s.box(wheel,Vector3(0,sin(a)*0.43,cos(a)*0.43),Vector3(0.08,0.22,0.22),"4f3a29")
			s.tilted_box(wheel,Vector3(0,sin(a)*0.2,cos(a)*0.2),Vector3(0.04,0.4,0.04),"6a4c33",Vector3(-a,0,0))
		s.box(wheel,Vector3.ZERO,Vector3(0.14,0.14,0.14),"3d3530")
	var cargo: String = String(data.get("cargo","sacks"))
	for i: int in 4:
		var at := Vector3((i%2-0.5)*w*0.3,bed_y+0.05,(floori(i/2.0)-0.5)*d*0.42)
		match cargo:
			"sacks": s.shard(root,at+Vector3(0,0.24,0),Vector3(0.5,0.42,0.6),_pick(["b09a69","bdaa7b","a78f5d"]),i)
			"crates":
				s.box(root,at+Vector3(0,0.24,0),Vector3(0.5,0.46,0.5),_pick(["8a6a45","9a7a52"]))
				s.box(root,at+Vector3(0,0.24,0.255),Vector3(0.06,0.46,0.02),"4f3c2c")
			"jars":
				s.box(root,at+Vector3(0,0.24,0),Vector3(0.38,0.46,0.38),_pick(["6b4a35","7b5a3e"]))
				s.box(root,at+Vector3(0,0.5,0),Vector3(0.26,0.06,0.26),"b23a2b")
			"firewood":
				s.tilted_box(root,at+Vector3(0,0.14,0),Vector3(0.12,0.12,0.9),_pick(["7a5f43","8c6e4c"]),Vector3(0,0.1*i,0))
			"stone":
				# Cut stone from the quarry: heavy blocks, the cart bed sagging under them.
				s.shard(root,at+Vector3(0,0.2,0),Vector3(0.5,0.34,0.62),_pick(_colors("stones",["8a8c80","7d8074","969688","74786d"])),i,0.1*i)
				if i%2==0:
					s.shard(root,at+Vector3(0.05,0.52,0.05),Vector3(0.4,0.28,0.44),_pick(_colors("stones",["8a8c80","7d8074","969688"])),i+3,0.3)
	if cargo in ["crates","sacks"] and data.get("covered",false):
		s.box(root,Vector3(0,bed_y+0.55,0),Vector3(w*0.66,0.08,d*0.86),String(data.get("tarp","6f6a52")))
	if data.has("flag"):
		var staff := Node3D.new()
		staff.position = Vector3(w*0.25,bed_y,-d*0.38)
		root.add_child(staff)
		s.box(staff,Vector3(0,1.3,0),Vector3(0.07,2.6,0.07),"5b4433")
		var cloth := Node3D.new()
		cloth.position = Vector3(0.04,2.5,0)
		staff.add_child(cloth)
		s.box(cloth,Vector3(0.36,-0.32,0),Vector3(0.68,0.64,0.03),String(data.get("cloth","b8412f")))
		for tooth: int in 4:
			s.box(cloth,Vector3(0.06+tooth*0.18,-0.7,0),Vector3(0.1,0.12,0.03),String(data.get("trim","e2c25c")))
		var title := Label3D.new()
		title.text = TranslationServer.translate(String(data["flag"]))
		title.position = Vector3(0.36,-0.32,0.03)
		title.pixel_size = 0.008
		title.font_size = 56
		title.outline_size = 0
		title.modulate = Color(String(data.get("letters","f1e3bd")))
		cloth.add_child(title)
		if ambience != null:
			ambience.flutter(cloth,root.position.x)

## 水缸: a great glazed vat of water (for fire and for the kitchen), a ladle on its rim. By its
## place taller or squatter, the glaze a shade off, a crack down one side on some, a plank lid
## (`lid`, else now and then) on some, the ladle laid across it any old way.
func _water_vat(w: float) -> void:
	var vary: RandomNumberGenerator = Shapes.spot_rng(root.position)
	var glaze: String = Shapes.tinted(String(data.get("glaze","4d5b55")),vary,0.05)
	var h: float = vary.randf_range(0.9,1.08)
	s.box(root,Vector3(0,0.42*h,0),Vector3(w*0.82,0.8*h,w*0.82),glaze)
	s.box(root,Vector3(0,0.12*h,0),Vector3(w*0.66,0.22*h,w*0.66),glaze)
	s.box(root,Vector3(0,0.84*h,0),Vector3(w*0.92,0.08,w*0.92),"6b7a72")
	s.box(root,Vector3(0,0.82*h,0),Vector3(w*0.7,0.02,w*0.7),"3e5f63:gloss")
	if vary.randf()<0.4:
		var a: float = vary.randf()*TAU
		s.tilted_box(root,Vector3(cos(a)*w*0.41,0.5*h,sin(a)*w*0.41),Vector3(0.02,0.36*h,0.02),Color(glaze.get_slice(":",0)).darkened(0.35).to_html(false),Vector3(0,-a,vary.randf_range(-0.3,0.3)))
	s.tilted_box(root,Vector3(w*0.25,0.92*h,0),Vector3(0.05,0.05,0.6),"8a6a45",Vector3(0,vary.randf()*TAU,0.3))
	if data.get("lid",vary.randf()<0.3):
		s.tilted_box(root,Vector3(-w*0.12,0.9*h,0),Vector3(w*0.55,0.06,w*0.85),"8a6a45",Vector3(0,0.4,0.08))

## 柴堆: split logs stacked crosswise against a wall, a bundle of kindling on top.
func _firewood(w: float, d: float) -> void:
	var bark: Array = _colors("colors",["7a5f43","8c6e4c","6a5039","a3845d"])
	var layers: int = int(data.get("layers",5))
	for layer: int in layers:
		var across: bool = layer%2==1
		var count: int = maxi(2,floori((d if across else w)/0.2))
		for i: int in count:
			var offset: float = -((d if across else w)/2)+0.1+i*((d if across else w)-0.2)/maxf(1,count-1)
			var at := Vector3(0 if across else offset,0.09+layer*0.17,offset if across else 0)
			s.box(root,at,Vector3(w*0.95 if across else 0.16,0.16,0.16 if across else d*0.95),_pick(bark))
			s.box(root,at+(Vector3(w*0.48,0,0) if across else Vector3(0,0,d*0.48)),Vector3(0.02 if across else 0.13,0.13,0.13 if across else 0.02),"c9ad7c")
	s.box(root,Vector3(0,0.12+layers*0.17,0),Vector3(w*0.6,0.12,d*0.4),"8f7a52")
	s.box(root,Vector3(0,0.13+layers*0.17,0),Vector3(0.05,0.13,d*0.42),"5c4a35")

## 货担: a pedlar's shoulder pole set down between two deep baskets.
func _carry_pole() -> void:
	var goods: Array = _colors("colors",["d28a3a","5f8a3c","c9452f"])
	for z: float in [-0.55,0.55]:
		s.box(root,Vector3(0,0.24,z),Vector3(0.42,0.44,0.42),"a68a55")
		s.box(root,Vector3(0,0.47,z),Vector3(0.36,0.06,0.36),String(goods[0 if z<0 else 1]))
		for rope: float in [-0.17,0.17]:
			s.tilted_box(root,Vector3(rope,0.62,z),Vector3(0.02,0.36,0.02),"b09a6c",Vector3(0,0,-rope*1.5))
	s.tilted_box(root,Vector3(0.05,0.62,0),Vector3(0.07,0.06,1.7),"8a6a45",Vector3(0,0.15,0.05))

## 茶垄: a row of clipped tea bushes along the box's long side, new leaves pale on their tops.
func _tea_bushes(w: float, d: float) -> void:
	var leaves: Array = _colors("colors",["2f5233","3b6338","4a7540"])
	var tips: Array = _colors("tips",["7fa354","93b860","a6c46b"])
	var height: float = float(data.get("height",0.8))
	var along_x: bool = w>=d
	var length: float = w if along_x else d
	var span: float = minf(w,d)
	var count: int = maxi(1,floori(length/0.55))
	for i: int in count:
		var t: float = -length/2+(i+0.5)*length/count
		var at := Vector3(t,0,0) if along_x else Vector3(0,0,t)
		var h: float = height*rng.randf_range(0.85,1.1)
		var bulge: float = maxf(span*1.15,0.7)
		s.box(root,at+Vector3(0,h*0.4,0),Vector3(0.62 if along_x else bulge,h*0.8,bulge if along_x else 0.62),_pick(leaves))
		s.box(root,at+Vector3(0,h*0.86,0),Vector3(0.5 if along_x else bulge*0.85,h*0.16,bulge*0.85 if along_x else 0.5),_pick(leaves))
		for tip: int in 3:
			s.box(root,at+Vector3(rng.randf_range(-0.22,0.22),h*0.95,rng.randf_range(-0.22,0.22)*bulge),Vector3(0.1,0.06,0.1),_pick(tips))

## 茶篓: a deep picker's basket with fresh leaves heaped in it.
func _tea_basket() -> void:
	s.box(root,Vector3(0,0.24,0),Vector3(0.38,0.46,0.38),"a68a55")
	for band: float in [0.12,0.36]:
		s.box(root,Vector3(0,band,0),Vector3(0.41,0.04,0.41),"8a7044")
	s.box(root,Vector3(0,0.5,0),Vector3(0.32,0.08,0.32),String(data.get("leaves","6f9a4e")))
	s.tilted_box(root,Vector3(0,0.6,0.2),Vector3(0.3,0.04,0.04),"8a7044",Vector3(0.6,0,0))

## 晾晒架: round bamboo trays of tea (or herbs) drying on a tiered rack.
func _drying_rack(w: float, d: float) -> void:
	var tiers: int = int(data.get("tiers",3))
	var wood: String = String(data.get("wood","8a7044"))
	for x: float in [-w/2+0.06,w/2-0.06]:
		for z: float in [-d/2+0.06,d/2-0.06]:
			s.box(root,Vector3(x,0.25+tiers*0.24,z),Vector3(0.07,0.5+tiers*0.48,0.07),wood)
	var leaves: Array = _colors("colors",["5c6b38","6f7c42","8a8a4c","7a6a3a"])
	for tier: int in tiers:
		var y: float = 0.45+tier*0.46
		for x: float in [-w/2+0.07,w/2-0.07]:
			s.box(root,Vector3(x,y-0.04,0),Vector3(0.05,0.05,d),wood)
		for i: int in maxi(1,floori(w/0.7)):
			var at := Vector3(-w/2+0.35+i*0.7,y,0)
			s.box(root,at,Vector3(0.62,0.05,minf(0.62,d*0.9)),"b39a5c")
			s.box(root,at+Vector3(0,0.035,0),Vector3(0.5,0.03,minf(0.5,d*0.8)),String(leaves[(tier+i)%leaves.size()]))

## 镇口门楼: a timber gateway over the road, its plaque on the beam (`text`), a little tiled
## roof on top. Its posts stand at the ends of its width, on blocked boxes of the layout.
func _gateway(w: float, d: float) -> void:
	# `stone`: a 石牌楼 (n_gate.c: 一座高大的石牌楼上面刻著「北门」两个大字) — grey stone posts and
	# lintels, a stone cap instead of tiles, the words cut in a panel, no lanterns.
	var stone: bool = data.get("stone",false)
	# `worn` (mstreet1.c: 一座牌坊, 年代久远, 上面的字迹早已看不出是什么字): the lacquer gone grey and
	# flaked off the posts, moss at their feet, tiles missing from the cap, the board blank.
	var worn: bool = data.get("worn",false)
	var timber: String = String(data.get("timber","8a8a80" if stone else "5f4331"))
	var posts: String = String(data.get("posts","9a9a92" if stone else "8e3a2c"))
	var height: float = float(data.get("height",4.2))
	var faded: String = String(data.get("faded","6e6a62"))
	for x: float in [-w/2+0.2,w/2-0.2]:
		s.box(root,Vector3(x,0.25,0),Vector3(0.6,0.5,0.6),"8a8a7e")
		s.box(root,Vector3(x,height/2,0),Vector3(0.3,height,0.3),posts)
		if worn:
			s.box(root,Vector3(x,height*0.28,0),Vector3(0.32,height*0.56,0.32),faded)
			for patch: int in 3:
				s.box(root,Vector3(x+(0.17 if patch%2 else -0.17),height*(0.62+patch*0.11),0.08*(patch-1)),Vector3(0.03,0.22+patch*0.06,0.14),faded)
			s.shard(root,Vector3(x-0.2,0.52,0.2),Vector3(0.36,0.08,0.3),"56713f",3 if x<0 else 5)
		s.tilted_box(root,Vector3(x+(0.3 if x<0 else -0.3),height-0.9,0),Vector3(0.12,0.9,0.12),timber,Vector3(0,0,0.7 if x<0 else -0.7))
	s.box(root,Vector3(0,height-0.35,0),Vector3(w+0.3,0.22,0.36),timber)
	s.box(root,Vector3(0,height+0.05,0),Vector3(w+0.5,0.18,0.42),timber)
	var tint := Color(String(data.get("roof","7a7a72" if stone else "4a5560")))
	for row: int in 4:
		var z: float = -0.75+row*0.5
		for col: int in ceili((w+1.4)/0.37):
			if worn and (col*7+row*3)%11==0:
				continue
			var x: float = -(w+1.4)/2+0.185+col*0.37
			var lift: float = pow(absf(x)/((w+1.4)/2),5)*0.3
			s.box(root,Vector3(x,height+0.5-absf(z)*0.45+lift,z),Vector3(0.38,0.12,0.52),tint.lightened(((col+row)%3)*0.03).to_html(false))
	s.box(root,Vector3(0,height+0.78,0),Vector3(w+0.9,0.2,0.24),tint.darkened(0.12).to_html(false))
	if worn and not data.has("text"):
		# The board still hangs, split, its words weathered to nothing.
		var board: String = String(data.get("board","7a756a"))
		s.box(root,Vector3(0,height-0.72,0.2),Vector3(minf(w*0.55,2.6),0.34,0.08),board)
		s.box(root,Vector3(-0.1,height-1.0,0.2),Vector3(minf(w*0.55,2.6)*0.86,0.2,0.08),Color(board).darkened(0.12).to_html(false))
		for scratch: int in 3:
			s.box(root,Vector3(-0.6+scratch*0.55,height-0.74,0.25),Vector3(0.22,0.12,0.02),Color(board).darkened(0.25).to_html(false))
	if data.has("text"):
		s.box(root,Vector3(0,height-0.85,0.2),Vector3(minf(w*0.55,2.6),0.62,0.08),String(data.get("board","6a6a62" if stone else "2b2520")))
		var title := Label3D.new()
		title.text = TranslationServer.translate(String(data["text"]))
		title.position = Vector3(0,height-0.85,0.25)
		title.pixel_size = 0.008
		title.font_size = 56
		title.outline_size = 0
		title.modulate = Color(String(data.get("letters","ece6d6" if stone else "e6c66e")))
		root.add_child(title)
		var back := title.duplicate() as Label3D
		back.position.z = -0.25
		back.rotation.y = PI
		root.add_child(back)
	if data.get("lanterns",not stone):
		for x: float in [-w/2+0.2,w/2-0.2]:
			s.lantern(root,Vector3(x,height-1.4,0.35),false,String(data.get("lantern","d8452f:glow")))
	if stone:
		# Carved cloud scrolls on the posts' heads, moss at their feet.
		for x: float in [-w/2+0.2,w/2-0.2]:
			s.box(root,Vector3(x,height-0.6,0),Vector3(0.44,0.16,0.44),String(data.get("carving","a8a89e")))
			s.shard(root,Vector3(x+0.2,0.06,0.3),Vector3(0.5,0.1,0.4),"56713f",3)

## 界碑: a stone stood by the road where the town's land begins, its name cut in it.
func _boundary_stone(w: float, d: float) -> void:
	var stone: Array = _colors("colors",["8a8a7e","9a998c","7c7b70"])
	s.shard(root,Vector3(0,0.1,0),Vector3(w*1.1,0.2,d*1.1),String(stone[2]),3)
	s.box(root,Vector3(0,0.75,0),Vector3(w*0.62,1.3,d*0.4),String(stone[0]))
	s.box(root,Vector3(0,1.44,0),Vector3(w*0.5,0.1,d*0.34),String(stone[1]))
	if data.has("text"):
		var title := Label3D.new()
		title.text = TranslationServer.translate(String(data["text"]))
		title.position = Vector3(0,0.8,d*0.21)
		title.pixel_size = 0.006
		title.font_size = 44
		title.width = 40.0
		title.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		title.outline_size = 0
		title.modulate = Color(String(data.get("letters","9b2f25")))
		root.add_child(title)

## A string of paper lanterns slung between two points (`points`: [[x, y, height], ...] px and
## units), every `spacing` units; only the middle one lights the street (one lamp per string).
func _lantern_string() -> void:
	var points: Array = data.get("points",[])
	if points.size()<2:
		return
	var ends: Array[Vector3] = []
	for p: Array in points:
		ends.append(Vector3(float(p[0])/32.0,float(p[2]) if p.size()>2 else 3.2,float(p[1])/32.0)-root.position)
	var paper: String = String(data.get("paper","d8452f:glow"))
	# Hung by hand, not by rule: by the string's place each span sags its own amount, the
	# lanterns are not evenly spaced, one or two are missing, their paper not quite one red.
	var vary: RandomNumberGenerator = Shapes.spot_rng(root.position)
	var spacing: float = float(data.get("spacing",0.9))
	for i: int in ends.size()-1:
		var a: Vector3 = ends[i]
		var b: Vector3 = ends[i+1]
		var length: float = a.distance_to(b)
		var count: int = maxi(1,floori(length/(spacing*vary.randf_range(0.85,1.2))))
		var sag: float = float(data.get("sag",0.35))*vary.randf_range(0.75,1.3)
		for j: int in count+1:
			var t: float = clampf(float(j)/count+(vary.randf_range(-0.12,0.12)/count if j>0 and j<count else 0.0),0.0,1.0)
			var at: Vector3 = a.lerp(b,t)-Vector3(0,sin(t*PI)*sag,0)
			s.box(root,at,Vector3(0.04,0.04,0.04),"3d3530")
			if j>0 and j<count and vary.randf()>=0.1:
				var hang := Node3D.new()
				hang.set_meta("light_fixture",true)
				hang.position = at-Vector3(0,0.24,0)
				root.add_child(hang)
				s.box(hang,Vector3.ZERO,Vector3(0.22,0.28,0.22)*vary.randf_range(0.92,1.08),Shapes.tinted(paper,vary,0.06))
				s.box(hang,Vector3(0,0.16,0),Vector3(0.26,0.04,0.26),"3d3530")
				s.box(hang,Vector3(0,-0.2,0),Vector3(0.04,0.1,0.04),"c8a24e")
				if ambience != null:
					ambience.sway(hang,at.x+at.z,0.06)
		var middle: Vector3 = a.lerp(b,0.5)-Vector3(0,sag+0.3,0)
		var lamp := OmniLight3D.new()
		lamp.position = middle
		lamp.light_color = Color(paper.get_slice(":",0)).lerp(Color("ffbd72"),0.5)
		lamp.omni_range = float(data.get("reach",4.0))
		lamp.set_meta("day_energy",0.0)
		lamp.set_meta("night_energy",float(data.get("night",1.6)))
		lamp.set_meta("flicker",0.08)
		root.add_child(lamp)

## 条凳: a long bench of one plank on splayed legs; `cups` leaves a teacup or two on it.
func _bench(w: float, d: float) -> void:
	var wood: String = String(data.get("wood","8a6a45"))
	var long_x: bool = w>=d
	var length: float = maxf(w,d)
	var size := Vector3(length,0.08,0.32) if long_x else Vector3(0.32,0.08,length)
	s.box(root,Vector3(0,0.46,0),size,wood)
	for end: float in [-1.0,1.0]:
		for side: float in [-1.0,1.0]:
			var at := Vector3(end*(length/2-0.18),0.22,side*0.1) if long_x else Vector3(side*0.1,0.22,end*(length/2-0.18))
			s.tilted_box(root,at,Vector3(0.06,0.46,0.06),"5c4433",Vector3(side*0.15 if long_x else 0,0,0 if long_x else side*0.15))
	if data.get("cups",false):
		s.box(root,Vector3(0.2,0.55,0) if long_x else Vector3(0,0.55,0.2),Vector3(0.1,0.1,0.1),"e3d5b4")

## 井: a stone well-head with a windlass on two posts, a bucket on its lip.
func _well(w: float) -> void:
	var stone: Array = _colors("colors",["8a8a7e","9a998c","7c7b70"])
	for i: int in 8:
		var a: float = i*TAU/8.0
		s.box(root,Vector3(cos(a)*w*0.36,0.35,sin(a)*w*0.36),Vector3(w*0.32,0.7,w*0.32),String(stone[i%stone.size()]))
	s.box(root,Vector3(0,0.66,0),Vector3(w*0.55,0.04,w*0.55),"23302f")
	for x: float in [-w*0.42,w*0.42]:
		s.box(root,Vector3(x,1.15,0),Vector3(0.12,1.0,0.12),"6a4c33")
	s.box(root,Vector3(0,1.55,0),Vector3(w*0.9,0.12,0.12),"7a5a3e")
	s.box(root,Vector3(0,1.55,0),Vector3(0.3,0.22,0.22),"8a7044")
	s.box(root,Vector3(0,1.1,0),Vector3(0.02,0.8,0.02),"b09a6c")
	s.box(root,Vector3(w*0.3,0.82,w*0.25),Vector3(0.26,0.26,0.26),"7a5a3e")
	if data.get("cups",false):
		# s_street1.c: 井旁用绳索绑著几只杯子供人取水喝 — cups on cords from the crossbar.
		for i: int in 3:
			var x: float = -w*0.3+i*w*0.3
			s.box(root,Vector3(x,1.25,0.1),Vector3(0.02,0.6,0.02),"b09a6c")
			s.box(root,Vector3(x,0.9,0.1),Vector3(0.14,0.12,0.14),["8a6a4a","a08a66","7a5a3e"][i])

## 矮墙/篱笆: a low wall or a wattle fence where a yard meets the street (`style`: "wall",
## "wattle", "bamboo"), along the box's long side.
func _fence(w: float, d: float) -> void:
	var style: String = String(data.get("style","wattle"))
	var along_x: bool = w>=d
	var length: float = maxf(w,d)
	var height: float = float(data.get("height",0.9))
	if style=="wall":
		var plaster: String = String(data.get("wall","b9bfb4"))
		s.box(root,Vector3(0,height/2,0),Vector3(length,height,0.3) if along_x else Vector3(0.3,height,length),plaster)
		s.box(root,Vector3(0,0.12,0),Vector3(length+0.04,0.24,0.34) if along_x else Vector3(0.34,0.24,length+0.04),"848572")
		var tint := Color(String(data.get("roof","4a5560")))
		for i: int in ceili(length/0.37):
			var t: float = -length/2+0.185+i*0.37
			s.box(root,Vector3(t,height+0.08,0) if along_x else Vector3(0,height+0.08,t),Vector3(0.38,0.12,0.52) if along_x else Vector3(0.52,0.12,0.38),tint.lightened((i%3)*0.03).to_html(false))
		return
	var posts: int = maxi(2,ceili(length/0.6)+1)
	for i: int in posts:
		var t: float = -length/2+i*length/(posts-1)
		s.box(root,Vector3(t,height/2,0) if along_x else Vector3(0,height/2,t),Vector3(0.09,height,0.09),"6a5038" if style=="wattle" else "7a8a4a")
	if style=="bamboo":
		for rail: float in [height*0.35,height*0.8]:
			s.box(root,Vector3(0,rail,0),Vector3(length,0.05,0.05) if along_x else Vector3(0.05,0.05,length),"8a9a52")
		for i: int in ceili(length/0.14):
			var t: float = -length/2+0.07+i*0.14
			s.box(root,Vector3(t,height*0.55,0.04) if along_x else Vector3(0.04,height*0.55,t),Vector3(0.04,height*0.9,0.04),["8fa05a","7a8a4a"][i%2])
		return
	for band: int in 4:
		var y: float = 0.18+band*height*0.2
		s.box(root,Vector3(0,y,0),Vector3(length,0.08,0.1) if along_x else Vector3(0.1,0.08,length),["8f7a52","a08a5c"][band%2])

## Bales, crates and casks waiting on a quay or in a yard, a coil of rope on top.
func _cargo(w: float, d: float) -> void:
	var wood: Array = _colors("colors",["8a6a45","9a7a52","7a5d3d"])
	var count: int = maxi(2,floori(w*d/0.6))
	for i: int in count:
		var at := Vector3(rng.randf_range(-0.38,0.38)*w,0,rng.randf_range(-0.38,0.38)*d)
		match i%3:
			0:
				s.box(root,at+Vector3(0,0.28,0),Vector3(0.6,0.56,0.6),_pick(wood))
				s.box(root,at+Vector3(0,0.28,0.31),Vector3(0.05,0.56,0.02),"4f3c2c")
			1:
				s.shard(root,at+Vector3(0,0.26,0),Vector3(0.7,0.5,0.55),_pick(["b09a69","bdaa7b","c9b98e"]),i)
				s.box(root,at+Vector3(0,0.26,0),Vector3(0.72,0.04,0.04),"6a5038")
			2:
				s.box(root,at+Vector3(0,0.3,0),Vector3(0.48,0.6,0.48),"6b4a35")
				for band: float in [0.12,0.48]:
					s.box(root,at+Vector3(0,band,0),Vector3(0.5,0.05,0.5),"3d3d3a")
	s.box(root,Vector3(0,0.7,0),Vector3(0.4,0.1,0.4),"a08a5c")
	s.box(root,Vector3(0,0.76,0),Vector3(0.22,0.04,0.22),"6a5a3e")

## 茶摊: a low table with a tea set, stools round it, a big kettle on a brazier by it.
func _tea_stall(w: float, d: float) -> void:
	var wood: String = String(data.get("wood","8a6a45"))
	s.box(root,Vector3(0,0.55,0),Vector3(w*0.55,0.07,d*0.55),wood)
	for x: float in [-w*0.22,w*0.22]:
		for z: float in [-d*0.22,d*0.22]:
			s.box(root,Vector3(x,0.27,z),Vector3(0.07,0.54,0.07),"5c4433")
	s.box(root,Vector3(-0.1,0.66,0),Vector3(0.24,0.18,0.24),"5d7f78")
	for c: int in 3:
		s.box(root,Vector3(0.2+c*0.1-0.1,0.62,0.18-c*0.08),Vector3(0.08,0.08,0.08),"e3d5b4")
	for corner: Vector2 in [Vector2(-0.42,-0.42),Vector2(0.42,0.42),Vector2(-0.42,0.42)]:
		s.box(root,Vector3(corner.x*w,0.3,corner.y*d),Vector3(0.3,0.06,0.3),wood)
		s.box(root,Vector3(corner.x*w,0.14,corner.y*d),Vector3(0.22,0.28,0.22),"5c4433")
	var brazier := Vector3(w*0.42,0,-d*0.42)
	s.box(root,brazier+Vector3(0,0.2,0),Vector3(0.36,0.4,0.36),"5e5a52")
	s.box(root,brazier+Vector3(0,0.42,0),Vector3(0.24,0.04,0.24),"ff8a3a:glow")
	s.box(root,brazier+Vector3(0,0.58,0),Vector3(0.3,0.26,0.3),"3a3632")
	if ambience != null:
		ambience.smoke(root,brazier+Vector3(0,0.8,0),"e8e6df",4,0.14)

## 石料: blocks cut at the quarry, stacked in courses that do not quite line up (切割整齐 means
## squared, not new: arrises chipped, some weathered and mossed from lying long), a few set
## aside on edge, chips and dust round the foot (`rows` high, `colors`, `moss`).
func _stone_blocks(w: float, d: float) -> void:
	var stones: Array = _colors("colors",["8b8d80","96978a","7f8276","a19f90","888a7c"])
	var moss: String = String(data.get("moss","5d7446"))
	var rows: int = int(data.get("rows",2))
	var block := Vector3(0.62,0.4,0.46)
	var cols: int = maxi(1,floori(w/(block.x+0.04)))
	var deep: int = maxi(1,floori(d/(block.z+0.04)))
	for row: int in rows:
		for z: int in deep:
			for x: int in cols-(row%2 if cols > 1 else 0):
				if row > 0 and rng.randf() < 0.18:
					continue
				var at := Vector3(-w/2+(x+0.5+(row%2)*0.5)*w/cols,0.2+row*0.41,-d/2+(z+0.5)*d/deep)+Vector3(rng.randf_range(-0.04,0.04),0,rng.randf_range(-0.04,0.04))
				var size := Vector3(block.x*rng.randf_range(0.85,1.05),block.y*rng.randf_range(0.9,1.05),block.z*rng.randf_range(0.85,1.05))
				var hex: String = _pick(stones)
				s.tilted_box(root,at,size,hex,Vector3(0,rng.randf_range(-0.07,0.07),0))
				# A chipped arris, a darker weathered face toward the weather.
				s.box(root,at+Vector3(size.x*0.38,size.y*0.4,size.z*0.4),Vector3(0.14,0.1,0.1),Color(hex).darkened(0.18).to_html(false))
				if row == rows-1 and rng.randf() < float(data.get("mossy",0.3)):
					s.box(root,at+Vector3(rng.randf_range(-0.15,0.15),size.y/2+0.01,0),Vector3(size.x*0.5,0.02,size.z*0.6),moss)
	for chip: int in int(data.get("chips",10)):
		var a: float = rng.randf()*TAU
		s.shard(root,Vector3(cos(a)*(w/2+rng.randf_range(0.05,0.4)),0.04,sin(a)*(d/2+rng.randf_range(0.05,0.3))),Vector3(0.12,0.07,0.1),_pick(stones),chip,a)

## 乾草: hay heaped 像山一般 by a stable, its top slumped, loose stalks round it, a fork left in it.
func _haystack(w: float, d: float) -> void:
	var straw: Array = _colors("colors",["c2a865","b39858","cdb574","a88d4e"])
	var tiers: int = int(data.get("tiers",5))
	for tier: int in tiers:
		var t: float = float(tier)/tiers
		var shrink: float = 1.0-t*0.75
		for lump: int in 3:
			var off := Vector3(sin(tier*2.1+lump*2.4)*w*0.1,0,cos(tier*1.3+lump*1.9)*d*0.1)
			s.shard(root,off+Vector3(0,0.25+tier*0.42,0),Vector3(w*shrink*rng.randf_range(0.7,0.9),0.5,d*shrink*rng.randf_range(0.7,0.9)),_pick(straw),tier*3+lump,lump*1.1)
	for stalk: int in 18:
		var a: float = rng.randf()*TAU
		s.tilted_box(root,Vector3(cos(a)*(w/2+rng.randf_range(0.0,0.35)),0.02,sin(a)*(d/2+rng.randf_range(0.0,0.3))),Vector3(0.03,0.015,0.28),_pick(straw),Vector3(0,rng.randf()*TAU,0))
	if data.get("fork",true):
		s.tilted_box(root,Vector3(w*0.2,tiers*0.36,d*0.1),Vector3(0.05,1.6,0.05),"6e5236",Vector3(0.35,0,0.2))

## 吊杆: a wooden hoist over the quarry's face, three legs lashed at the top, a pulley and rope,
## a hook with a sling of stone hanging under it, a windlass at its foot.
func _derrick(w: float, d: float) -> void:
	var height: float = float(data.get("height",4.6))
	var wood: Array = _colors("colors",["6e5236","7a5c3d","5f4630"])
	var apex := Vector3(0,height,0)
	for leg: int in 3:
		var a: float = leg*TAU/3.0+0.5
		var foot := Vector3(cos(a)*w*0.42,0,sin(a)*d*0.42)
		var along: Vector3 = apex-foot
		var up: Vector3 = along.normalized()
		var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.z)<0.9 else Vector3.RIGHT).normalized()
		s._instance(root,Transform3D(Basis(side,up,side.cross(up)).scaled_local(Vector3(0.14,along.length(),0.14)),(apex+foot)/2.0),String(wood[leg%wood.size()]),s.cube)
	s.box(root,apex+Vector3(0,0.05,0),Vector3(0.3,0.24,0.3),"5a4a36")
	s.box(root,apex-Vector3(0,0.25,0),Vector3(0.22,0.22,0.08),"3e3a35")
	var drop: float = height*0.55
	s.box(root,apex-Vector3(0,0.3+drop/2,0),Vector3(0.04,drop,0.04),"8e7c55")
	s.box(root,apex-Vector3(0,0.35+drop,0),Vector3(0.12,0.12,0.06),"3e3a35")
	s.shard(root,apex-Vector3(0,0.65+drop,0),Vector3(0.6,0.36,0.44),"8b8d80",3,0.2)
	var windlass := Vector3(w*0.3,0.45,-d*0.2)
	for x: float in [-0.3,0.3]:
		s.box(root,windlass+Vector3(x,0,0),Vector3(0.08,0.9,0.08),String(wood[1]))
	s.box(root,windlass+Vector3(0,0.3,0),Vector3(0.7,0.18,0.18),String(wood[2]))
	s.box(root,windlass+Vector3(0,0.3,0),Vector3(0.4,0.26,0.26),"8e7c55")
