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
		"coach": _coach(w,d)
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
		"scarecrow": _scarecrow()
		"shades": _shades(w,d)
		"farm_tools": _farm_tools(w,d)
		"pigsty": _pigsty(w,d)
		"chicken_coop": _chicken_coop(w,d)
		"laundry_line": _laundry_line(w,d)
		"melon_vines": _melon_vines(w,d)
		"bamboo_post": _bamboo_post()
		"pole_eaves": _pole_eaves(w,d)
		"shears": _shears()
		"trough": _trough(w,d)
		_:
			return false
	return true

## 马槽: a long plank trough on two trestles along the box's long side, water in it, wisps of hay
## at its foot; `wood`, `water`.
func _trough(w: float, d: float) -> void:
	var wood: String = String(data.get("wood","6a5038"))
	var long_x: bool = w>=d
	var length: float = maxf(w,d)-0.1
	var across: float = minf(minf(w,d),0.62)
	var along := func(t: float, side: float, y: float) -> Vector3: return Vector3(t,y,side) if long_x else Vector3(side,y,t)
	var span := func(l: float, h: float, a: float) -> Vector3: return Vector3(l,h,a) if long_x else Vector3(a,h,l)
	for t: float in [-length*0.32,length*0.32]:
		s.box(root,along.call(t,0.0,0.2),span.call(0.12,0.4,across*0.9),"4f3c2c")
	s.box(root,along.call(0.0,0.0,0.44),span.call(length,0.08,across),wood)
	for side: float in [-1.0,1.0]:
		s.box(root,along.call(0.0,side*(across/2-0.04),0.6),span.call(length,0.3,0.08),Color(wood).lightened(0.06).to_html(false))
	for end: float in [-1.0,1.0]:
		s.box(root,along.call(end*(length/2-0.04),0.0,0.6),span.call(0.08,0.3,across),wood)
	s.box(root,along.call(0.0,0.0,0.68),span.call(length-0.16,0.02,across-0.16),String(data.get("water","4a6a70:gloss")))
	for wisp: int in 4:
		s.tilted_box(root,along.call(-length*0.4+wisp*length*0.25,(wisp%2-0.5)*across*1.1,0.03),span.call(0.3,0.03,0.05),"c8b474",Vector3(0,wisp*0.7,0))

## 剪刀: flower shears dropped by the beds, the two blades crossed.
func _shears() -> void:
	for side: float in [-1.0,1.0]:
		s.tilted_box(root,Vector3(0,0.03,0),Vector3(0.05,0.03,0.46),"a8b0b0",Vector3(0,side*0.32,0))
		s.tilted_box(root,Vector3(side*0.1,0.03,0.22),Vector3(0.1,0.04,0.12),"6a4a34",Vector3(0,side*0.32,0))

## 茅草铺顶 seen from under (melonguard.c): a thatch eave round the top of a pole shed, its middle
## left open so the room stays in view; the bare poles run across.
func _pole_eaves(w: float, d: float) -> void:
	var straw: Array = _colors("colors",["b8a862","a89a5a","c4b470","9a8c52"])
	var y: float = float(data.get("height",2.9))
	var deep: float = float(data.get("deep",0.9))
	for side: float in [-1.0,1.0]:
		for i: int in ceili(w/0.5):
			s.tilted_box(root,Vector3(-w/2+0.25+i*0.5,y+rng.randf_range(-0.03,0.03),side*(d/2-deep/2)),Vector3(0.52,0.14,deep),_pick(straw),Vector3(side*0.16,0,0))
	s.box(root,Vector3(0,y+0.1,0),Vector3(w,0.07,0.07),"8e8e4c")
	s.box(root,Vector3(0,y+0.1,0),Vector3(0.07,0.07,d),"8e8e4c")

## 斗笠草人: a straw man on a pole among the rice, a farmer's old hat and coat on him.
func _scarecrow() -> void:
	var lean: float = float(data.get("lean",0.05))
	var coat: String = String(data.get("coat","6a6a52"))
	var hat: String = String(data.get("hat","b8a468"))
	s.tilted_box(root,Vector3(0,0.85,0),Vector3(0.08,1.7,0.08),"6a5038",Vector3(0,0,lean))
	s.tilted_box(root,Vector3(0,1.26,0),Vector3(1.15,0.07,0.07),"6a5038",Vector3(0,0,lean))
	s.tilted_box(root,Vector3(0,1.08,0),Vector3(0.6,0.62,0.28),coat,Vector3(0,0,lean))
	for i: int in 6:
		s.tilted_box(root,Vector3(-0.3+i*0.12,0.68,0.02),Vector3(0.09,0.34,0.06),["b8a468","a8945a","c8b474"][i%3],Vector3(0,0,(i-2.5)*0.1))
	s.box(root,Vector3(0,1.58,0),Vector3(0.26,0.26,0.26),"c8b48a")
	for tier: int in 3:
		s.box(root,Vector3(0,1.72+tier*0.05,0),Vector3(1.0-tier*0.32,0.05,1.0-tier*0.32),hat)

## 人影: hooded figures in long cloaks, their faces lost in the hood, in a file along the box's
## long side, facing its +z (inn1.c: 四个披著黑斗蓬的人; bridge.c: 浓雾中有许多朦胧的人影). `count`,
## `cloak`, `lean`; `ghostly`: half seen through (the dead in the fog).
func _shades(w: float, d: float) -> void:
	var cloak: String = String(data.get("cloak","1e1c22"))+(":mist" if data.get("ghostly",false) else "")
	var along_x: bool = w>=d
	var span: float = maxf(w,d)
	var count: int = int(data.get("count",maxi(1,floori(span/0.7))))
	for i: int in count:
		var t: float = -span/2+(i+0.5)*span/count
		var at := (Vector3(t,0,0) if along_x else Vector3(0,0,t))+Vector3(sin(i*2.3),0,cos(i*1.7))*0.06
		var lean: float = float(data.get("lean",0.08))*sin(i*1.3+0.4)
		var tall: float = 1.5+0.12*sin(i*2.9)
		s.tilted_box(root,at+Vector3(0,tall*0.42,0),Vector3(0.5,tall*0.84,0.4),cloak,Vector3(0,0,lean))
		s.tilted_box(root,at+Vector3(0,0.06,0),Vector3(0.6,0.12,0.5),cloak,Vector3(0,0,lean))
		var head := at+Vector3(-lean*tall*0.9,tall*0.92,0)
		s.box(root,head,Vector3(0.34,0.36,0.36),cloak)
		s.box(root,head+Vector3(0,-0.02,0.15),Vector3(0.2,0.22,0.08),String(data.get("face","0a0a0c")))

## 农具: what the farmers left by the bund: a harrow on its back, its teeth up, a hoe and a rake
## laid across it, a basket.
func _farm_tools(w: float, d: float) -> void:
	s.box(root,Vector3(-w*0.2,0.1,0),Vector3(w*0.5,0.08,d*0.7),"6e5038")
	for i: int in 5:
		s.box(root,Vector3(-w*0.2-w*0.2+i*w*0.1,0.2,0),Vector3(0.05,0.2,0.05),"3e3e3c")
	s.tilted_box(root,Vector3(w*0.1,0.08,-d*0.1),Vector3(w*0.9,0.05,0.05),"8a6a46",Vector3(0,0.3,0))
	s.box(root,Vector3(w*0.48,0.09,0.1),Vector3(0.1,0.04,0.34),"4a4a48")
	s.box(root,Vector3(w*0.3,0.18,d*0.2),Vector3(0.36,0.36,0.36),"a8945a")
	s.box(root,Vector3(w*0.3,0.34,d*0.2),Vector3(0.3,0.04,0.3),"6a5a3a")

## 猪圈 (fmhousback.c: 在后院的左侧有个猪圈): a low wall of field stone round a floor of trampled mud,
## a lean-to of thatch along the back, the slop trough, straw in a corner. The pigs are `critters`.
func _pigsty(w: float, d: float) -> void:
	s.box(root,Vector3(0,0.015,0),Vector3(w,0.03,d),"5e4e38")
	for i: int in 8:
		s.shard(root,Vector3(rng.randf_range(-0.42,0.42)*w,0.035,rng.randf_range(-0.2,0.42)*d),Vector3(rng.randf_range(0.5,1.0),0.015,rng.randf_range(0.4,0.8)),["4e4030","6a5840"][i%2],i,rng.randf()*TAU)
	var stone: Array = _colors("colors",["8a7c64","978a70","7a6e5a","a39577"])
	for side: int in 4:
		var along_x: bool = side<2
		var length: float = w if along_x else d
		var fixed: float = (d if along_x else w)/2*(1 if side%2 else -1)
		for i: int in ceili(length/0.42):
			var t: float = -length/2+0.21+i*0.42
			var tall: float = 0.62+0.08*sin(i*2.1+side)
			var at := Vector3(t,tall/2,fixed) if along_x else Vector3(fixed,tall/2,t)
			s.shard(root,at,Vector3(0.44,tall,0.3) if along_x else Vector3(0.3,tall,0.44),_pick(stone),i+side*9,0.0)
	var depth: float = minf(d*0.34,1.6)
	for x: float in [-w*0.44,w*0.44]:
		s.box(root,Vector3(x,0.8,-d/2+depth),Vector3(0.14,1.6,0.14),"6a5038")
	for i: int in ceili(depth/0.2):
		var z: float = -d/2+0.1+i*0.2
		s.box(root,Vector3(0,1.72-float(i)*0.16,z),Vector3(w*0.98,0.09,0.22),["b8a262","a89254","c0aa6a"][i%3])
	s.box(root,Vector3(-w*0.1,0.14,d*0.34),Vector3(w*0.4,0.28,0.34),"6e5a42")
	s.box(root,Vector3(-w*0.1,0.27,d*0.34),Vector3(w*0.36,0.03,0.24),"8a7a4e")
	for i: int in 9:
		s.tilted_box(root,Vector3(w*0.28+rng.randf_range(-0.4,0.4),0.08,-d*0.1+rng.randf_range(-0.4,0.4)),Vector3(0.44,0.03,0.05),"c8b474",Vector3(0,rng.randf()*TAU,0))

## 一排鸡笼 (fmhousback.c: 右面是一排鸡笼，两个红皮鸡蛋落在鸡笼后边的槽里): wooden coops side by side
## on stilts, slat fronts, a thatch lid; behind them the trough with its `eggs` red eggs.
func _chicken_coop(w: float, d: float) -> void:
	# The row leaves the trough's west end clear of it, so the eggs show from the yard.
	var row: float = w*0.8
	var coops: int = maxi(2,floori(row/1.5))
	var span: float = row/coops
	for i: int in coops:
		var x: float = w/2-row+span*(i+0.5)
		for leg: float in [-span*0.4,span*0.4]:
			s.box(root,Vector3(x+leg,0.2,d*0.3),Vector3(0.08,0.4,0.08),"6e5038")
		s.box(root,Vector3(x,0.72,d*0.12),Vector3(span*0.9,0.64,d*0.6),"8a6a46")
		s.box(root,Vector3(x,0.72,d*0.12+d*0.31),Vector3(span*0.62,0.46,0.02),"2a2018")
		for slat: int in 5:
			s.box(root,Vector3(x-span*0.26+slat*span*0.13,0.72,d*0.12+d*0.325),Vector3(0.035,0.46,0.03),"b08a58")
		s.tilted_box(root,Vector3(x,1.1,d*0.12),Vector3(span*0.98,0.1,d*0.74),["b8a262","a89254"][i%2],Vector3(0.14,0,0))
	s.box(root,Vector3(0,0.16,-d*0.34),Vector3(w*0.9,0.3,0.28),"6e5a42")
	s.box(root,Vector3(0,0.3,-d*0.34),Vector3(w*0.86,0.03,0.2),"c8b474")
	for i: int in int(data.get("eggs",2)):
		s.box(root,Vector3(-w*0.44+i*0.3,0.35,-d*0.34),Vector3(0.11,0.13,0.15),"c8603a")

## 晾的衣服: a line between two forked poles, washing on it stirring; `clothes`: their colours.
func _laundry_line(w: float, d: float) -> void:
	var along_x: bool = w>=d
	var length: float = maxf(w,d)
	var cloths: Array = _colors("clothes",["6a8aa8","c8b8a0","b86a5a"])
	for t: float in [-length/2+0.1,length/2-0.1]:
		s.box(root,Vector3(t,0.95,0) if along_x else Vector3(0,0.95,t),Vector3(0.09,1.9,0.09),"6a5038")
	s.box(root,Vector3(0,1.86,0),Vector3(length,0.02,0.02) if along_x else Vector3(0.02,0.02,length),"b09a6c")
	var count: int = maxi(2,floori(length/0.8))
	for i: int in count:
		var t: float = -length/2+(i+0.5)*length/count
		var hang := Node3D.new()
		hang.position = Vector3(t,1.84,0) if along_x else Vector3(0,1.84,t)
		root.add_child(hang)
		var size := Vector2(minf(0.6,length/count*0.8),0.7+0.15*(i%2))
		s.box(hang,Vector3(0,-size.y/2,0),Vector3(size.x,size.y,0.03) if along_x else Vector3(0.03,size.y,size.x),String(cloths[i%cloths.size()]))
		if ambience != null:
			ambience.sway(hang,root.position.x+i*1.3,0.08)

## 瓜藤 (melonfarm.c: 熟透了的西瓜已与瓜蒂脱开): runners and broad leaves low over the sand, striped
## melons lying among them, some with their stems dried off; `count` melons. `heap`: only melons,
## brought in and piled.
func _melon_vines(w: float, d: float) -> void:
	var heap: bool = data.get("heap",false)
	var leaves: Array = _colors("colors",["4a7a3a","5a8a42","3e6a34","6a9a4a"])
	if not heap:
		for i: int in ceili(w*d*5.0):
			var at := Vector3(rng.randf_range(-0.5,0.5)*w,0.06+rng.randf()*0.08,rng.randf_range(-0.5,0.5)*d)
			s.tilted_box(root,at,Vector3(rng.randf_range(0.22,0.4),0.04,rng.randf_range(0.2,0.34)),_pick(leaves),Vector3(rng.randf_range(-0.2,0.2),rng.randf()*TAU,rng.randf_range(-0.2,0.2)))
		for i: int in ceili(maxf(w,d)):
			s.tilted_box(root,Vector3(rng.randf_range(-0.4,0.4)*w,0.04,rng.randf_range(-0.4,0.4)*d),Vector3(rng.randf_range(0.9,1.5),0.03,0.04),"5e7a3a",Vector3(0,rng.randf()*TAU,0))
	for i: int in int(data.get("count",6)):
		var size: float = rng.randf_range(0.36,0.5)
		var at := Vector3(rng.randf_range(-0.42,0.42)*w,size*0.42,rng.randf_range(-0.42,0.42)*d)
		if heap and i>=3:
			at.y += size*0.7
		var yaw: float = rng.randf()*TAU
		var melon := Node3D.new()
		melon.position = at
		melon.rotation.y = yaw
		root.add_child(melon)
		if s.merged.has(root):
			s.merge(melon,s.merged[root])
		s.box(melon,Vector3.ZERO,Vector3(size,size*0.84,size*1.3),"2e5a2e")
		for stripe: int in 4:
			s.box(melon,Vector3(-size*0.36+stripe*size*0.24,0,0),Vector3(size*0.08,size*0.87,size*1.33),"8ab85a")
		if i%2==0:
			s.box(melon,Vector3(0,size*0.3,size*0.68),Vector3(0.03,0.08,0.05),"7a6a3e")

## 竹竿: one pole of the shed's frame, jointed.
func _bamboo_post() -> void:
	var tall: float = float(data.get("height",2.8))
	s.box(root,Vector3(0,tall/2,0),Vector3(0.16,tall,0.16),String(data.get("color","8a8a4a")))
	for joint: float in [0.9,1.8,2.6]:
		if joint<tall:
			s.box(root,Vector3(0,joint,0),Vector3(0.19,0.04,0.19),"6e6e38")

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
				"glass":
					# 番坊's glass: strings of beads on a felt, a cup or two among them, catching the light.
					s.box(root,at+Vector3(0,0.012,0),Vector3(0.28,0.02,0.34),"7a2a2a")
					for bead: int in 4:
						s.box(root,at+Vector3(-0.09+bead*0.06,0.04,rng.randf_range(-0.1,0.1)),Vector3(0.05,0.05,0.05),_pick(["3a8ac8:gloss","4ab89a:gloss","d8a040:gloss","c84a6a:gloss","e8e0f0:gloss"]))
					if rng.randf() < 0.4:
						s.box(root,at+Vector3(0.06,0.1,0.08),Vector3(0.08,0.16,0.08),_pick(["6ac0d8:gloss","a8d8a0:gloss","e8c878:gloss"]))
				"spice":
					# Sacks with their mouths rolled down, a heap of colour in each.
					s.box(root,at+Vector3(0,0.1,0),Vector3(0.26,0.2,0.26),_pick(["b89a6a","a88a5a","c8aa78"]))
					s.box(root,at+Vector3(0,0.21,0),Vector3(0.2,0.06,0.2),_pick(["d8a020","b8381e","3a2a1e","c8862a","e8d8a0","8a4a2a"]))
				"copper":
					# Kettles with long spouts and hammered plates.
					if (i+row)%2 == 0:
						s.box(root,at+Vector3(0,0.1,0),Vector3(0.16,0.2,0.16),_pick(["b8733a:gloss","c88a4a:gloss","a8622e:gloss"]))
						s.box(root,at+Vector3(0,0.23,0),Vector3(0.06,0.06,0.06),"8a4a22")
						s.tilted_box(root,at+Vector3(0.12,0.14,0),Vector3(0.12,0.03,0.03),"b8733a:gloss",Vector3(0,0,0.6))
					else:
						s.tilted_box(root,at+Vector3(0,0.12,0),Vector3(0.26,0.26,0.02),_pick(["c88a4a:gloss","d89a5a:gloss","b8733a:gloss"]),Vector3(-0.5,0,0))
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

## 车马行的车 (native; DECISIONS「车马行」): a two-wheeled cart under an arched oilcloth hood, a
## curtain hung at its back, a horse in its shafts at +z along the box's long axis, a pennant
## saying 车马行 on a staff at the back corner (read from either side, so from either view), and
## the driver sat on the front of the bed with his whip and 斗笠, waiting for a fare. `hood` the
## oilcloth, `curtain`, `colors` the wood, `coat` / `mane` / `blaze` the horse's, `pennant` its
## cloth, `driver` (false: the seat is empty), `driver_coat`, `hat`.
func _coach(w: float, d: float) -> void:
	var long: float = maxf(w,d)
	var wide: float = minf(w,d)
	var coach := Node3D.new()
	coach.rotation.y = PI/2 if w > d else 0.0
	root.add_child(coach)
	var wood: Array = _colors("colors",["6a4c33","7a5a3e","56402e"])
	var hood: String = String(data.get("hood","3e4a5a"))
	var cart_len: float = long*0.44
	var cart_z: float = -long*0.26
	var bed_y: float = 0.82
	var front: float = cart_z+cart_len/2.0
	s.box(coach,Vector3(0,bed_y,cart_z),Vector3(wide*0.8,0.12,cart_len),String(wood[0]))
	for side: float in [-1.0,1.0]:
		s.box(coach,Vector3(side*wide*0.4,bed_y+0.17,cart_z),Vector3(0.06,0.24,cart_len),String(wood[1]))
	# The hood: an arch of oilcloth slats over the bed, a little shorter than it at the front.
	var arch: float = wide*0.43
	var slats: int = 7
	for i: int in slats:
		var a: float = PI*float(i)/float(slats-1)
		var at := Vector3(cos(a)*arch,bed_y+0.28+sin(a)*arch*1.15,cart_z-cart_len*0.06)
		s.tilted_box(coach,at,Vector3(arch*0.62,0.07,cart_len*0.84),hood,Vector3(0,0,a+PI/2.0))
	s.box(coach,Vector3(0,bed_y+0.28+arch*0.55,cart_z-cart_len*0.47),Vector3(arch*1.5,arch*1.1,0.04),String(data.get("curtain","8a3a2a")))
	# Two spoked wheels.
	for side: float in [-1.0,1.0]:
		var wheel := Node3D.new()
		wheel.position = Vector3(side*(wide*0.44+0.07),0.56,cart_z)
		coach.add_child(wheel)
		for spoke: int in 10:
			var a: float = spoke*TAU/10.0
			s.box(wheel,Vector3(0,sin(a)*0.5,cos(a)*0.5),Vector3(0.09,0.22,0.22),"4a3626")
			s.tilted_box(wheel,Vector3(0,sin(a)*0.24,cos(a)*0.24),Vector3(0.04,0.46,0.04),String(wood[2]),Vector3(-a,0,0))
		s.box(wheel,Vector3.ZERO,Vector3(0.16,0.16,0.16),"3a322c")
	# The shafts from the bed to the horse's shoulders, a yoke across.
	var horse_long: float = long*0.5
	var horse_z: float = long*0.22
	var shoulder: float = horse_z+horse_long*0.2
	for side: float in [-1.0,1.0]:
		var from := Vector3(side*wide*0.3,bed_y-0.02,front)
		var to := Vector3(side*0.33,1.0,shoulder)
		var span: Vector3 = to-from
		s.tilted_box(coach,(from+to)/2.0,Vector3(0.07,0.07,span.length()),String(wood[2]),Vector3(-atan2(span.y,Vector2(span.x,span.z).length()),atan2(span.x,span.z),0))
	s.box(coach,Vector3(0,1.38,shoulder),Vector3(0.74,0.08,0.1),String(wood[1]))
	var horse := Node3D.new()
	horse.position = Vector3(0,0,horse_z)
	coach.add_child(horse)
	var mane: String = String(data.get("mane","2a2420"))
	var body_h: float = _horse_body(horse,horse_long,String(data.get("coat","6a4632")),mane)
	s.box(horse,Vector3(0,body_h+0.3,horse_long*0.14),Vector3(0.36,0.1,0.18),String(data.get("curtain","8a3a2a")))
	_horse_tail(horse,body_h,horse_long,mane)
	var staff := Node3D.new()
	staff.position = Vector3(wide*0.4,bed_y,cart_z-cart_len*0.44)
	coach.add_child(staff)
	s.box(staff,Vector3(0,0.95,0),Vector3(0.06,1.9,0.06),"5b4433")
	var pennant := Node3D.new()
	pennant.position = Vector3(0.03,1.84,0)
	staff.add_child(pennant)
	s.box(pennant,Vector3(0.33,-0.22,0),Vector3(0.62,0.4,0.03),String(data.get("pennant","b8412f")))
	for side: float in [1.0,-1.0]:
		var title := Label3D.new()
		title.text = TranslationServer.translate("车马行")
		title.position = Vector3(0.33,-0.22,0.02*side)
		title.rotation.y = 0.0 if side > 0.0 else PI
		title.pixel_size = 0.0045
		title.font_size = 40
		title.outline_size = 0
		title.modulate = Color("f1e3bd")
		pennant.add_child(title)
	if ambience != null:
		ambience.flutter(pennant,root.position.x)
	if not data.get("driver",true):
		return
	# The driver on the front of the bed, his legs over its edge, the whip up.
	var driver := Node3D.new()
	driver.position = Vector3(-wide*0.12,bed_y+0.06,front-0.22)
	coach.add_child(driver)
	var coat: String = String(data.get("driver_coat","4a5866"))
	s.box(driver,Vector3(0,0.06,0.2),Vector3(0.3,0.12,0.34),"3a3a40")
	s.box(driver,Vector3(0,-0.2,0.36),Vector3(0.26,0.4,0.1),"3a3a40")
	s.box(driver,Vector3(0,0.36,0),Vector3(0.36,0.5,0.26),coat)
	s.box(driver,Vector3(0,0.74,0.02),Vector3(0.22,0.24,0.22),"d2a07a")
	s.box(driver,Vector3(0,0.9,0.02),Vector3(0.62,0.04,0.62),String(data.get("hat","c8a868")))
	s.box(driver,Vector3(0,0.96,0.02),Vector3(0.3,0.08,0.3),String(data.get("hat","c8a868")))
	s.box(driver,Vector3(0.22,0.42,0.14),Vector3(0.1,0.32,0.1),coat)
	s.tilted_box(driver,Vector3(0.26,0.88,0.42),Vector3(0.03,0.03,0.9),"5a4433",Vector3(-0.9,0,0))


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
	# `bells`: wind bells instead of lanterns (`metal` their bronze), and no lamp.
	var bells: bool = data.get("bells",false)
	var metal: String = String(data.get("metal","6a8a6a"))
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
			if not (j>0 and j<count and vary.randf()>=0.1):
				continue
			if bells:
				# 第十章 B: a string of wind bells (岚城's streets), small bronze bells on short cords, no light.
				var bell := Node3D.new()
				bell.position = at-Vector3(0,0.14,0)
				root.add_child(bell)
				s.box(bell,Vector3(0,0.05,0),Vector3(0.02,0.12,0.02),String(data.get("cord","d8907a")))
				s.box(bell,Vector3(0,-0.06,0),Vector3(0.12,0.12,0.12),Shapes.tinted(metal,vary,0.08))
				s.box(bell,Vector3(0,-0.14,0),Vector3(0.16,0.03,0.16),Shapes.tinted(metal,vary,0.08))
				if ambience != null:
					ambience.sway(bell,at.x+at.z,0.22)
			else:
				var hang := Node3D.new()
				hang.set_meta("light_fixture",true)
				hang.position = at-Vector3(0,0.24,0)
				root.add_child(hang)
				s.box(hang,Vector3.ZERO,Vector3(0.22,0.28,0.22)*vary.randf_range(0.92,1.08),Shapes.tinted(paper,vary,0.06))
				s.box(hang,Vector3(0,0.16,0),Vector3(0.26,0.04,0.26),"3d3530")
				s.box(hang,Vector3(0,-0.2,0),Vector3(0.04,0.1,0.04),"c8a24e")
				if ambience != null:
					ambience.sway(hang,at.x+at.z,0.06)
		if bells:
			continue
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
