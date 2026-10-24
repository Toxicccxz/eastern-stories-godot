extends RefCounted

## The wilds: mountain passes and caves (美术规划 groups C and F). Rocks, bones and dry
## stream beds, a bandit camp's fire, flag, stakes and plunder, the stone beam over a
## canyon, cave mouths, dripstone, slime and pools. Sizes and colours come from the data;
## what stands on walkable ground is a blocked box in the map layout.
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
		"boulder": _boulder(w,d)
		"rock_pile": _rock_pile(w,d)
		"standing_rock": _standing_rock(w,d)
		"crag": _crag(w,d)
		"bones": _bones(w,d)
		"dead_log": _dead_log(w,d)
		"dirt_bank": _dirt_bank(w,d)
		"cairn": _cairn()
		"bush": _bush(w,d)
		"trail": _trail()
		"dry_stream": _dry_stream()
		"stone_beam": _stone_beam(w,d)
		"crack": _crack(w)
		"cave_mouth": _cave_mouth(w,d)
		"campfire": _campfire(w,d)
		"banner": _banner()
		"barricade": _barricade(w,d)
		"lean_to": _lean_to(w,d)
		"wine_jars": _wine_jars(w,d)
		"loot_crates": _loot_crates(w,d)
		"bedroll": _bedroll(w,d)
		"lost_pack": _lost_pack()
		"stalagmites": _stalagmites(w,d)
		"overhang": _overhang(w,d)
		"slime": _slime(w,d)
		"pool": _pool(w,d)
		"drip": _drip()
		"light_shaft": _light_shaft(w,d)
		"cart_wheel": _cart_wheel()
		"rough_steps": _rough_steps(w,d)
		"torch": _torch()
		"glow": _glow()
		_:
			return false
	return true

func _colors(key: String, fallback: Array) -> Array:
	return data.get(key,fallback)

func _pick(colors: Array) -> String:
	return String(colors[rng.randi_range(0,colors.size()-1)])

func _boulder(w: float, d: float) -> void:
	var rock: Array = _colors("colors",["8f7f63","9d8c6c","7c6e58"])
	var tall: float = float(data.get("tall",0.7))
	s.shard(root,Vector3(0,tall*minf(w,d)*0.42,0),Vector3(w,tall*minf(w,d),d),_pick(rock),rng.randi(),rng.randf()*TAU)
	for i: int in int(data.get("chips",3)):
		var a: float = rng.randf()*TAU
		var size: float = rng.randf_range(0.12,0.3)
		s.shard(root,Vector3(cos(a)*w*0.6,size*0.3,sin(a)*d*0.6),Vector3(size,size*0.6,size*1.2),_pick(rock),rng.randi(),a)
	if data.get("lichen",true):
		s.shard(root,Vector3(w*0.12,tall*minf(w,d)*0.92,-d*0.1),Vector3(w*0.45,0.04,d*0.35),String(data.get("lichen_color","9a9a5e")),rng.randi())

func _rock_pile(w: float, d: float) -> void:
	var rock: Array = _colors("colors",["8f7f63","9d8c6c","7c6e58","a8987a"])
	for i: int in int(data.get("count",14)):
		var r: float = sqrt(rng.randf())
		var a: float = rng.randf()*TAU
		var size: float = rng.randf_range(0.14,0.42)*(1.2-r*0.6)
		s.shard(root,Vector3(cos(a)*r*w*0.45,size*0.3+(1.0-r)*0.25,sin(a)*r*d*0.45),Vector3(size*1.2,size*0.75,size),_pick(rock),rng.randi(),a)

## 风化岩: a pillar worn into stacked, overhanging lumps.
func _standing_rock(w: float, d: float) -> void:
	var rock: Array = _colors("colors",["9a8466","a8906e","87745b","b19a76"])
	var height: float = float(data.get("height",2.6))
	var y: float = 0.0
	var course: int = 0
	while y < height:
		var t: float = y/height
		var span: float = lerpf(1.0,0.55,t)+sin(course*1.9)*0.12
		var step: float = rng.randf_range(0.35,0.6)
		s.shard(root,Vector3(sin(course*2.3)*0.08*w,y+step*0.5,cos(course*1.7)*0.08*d),Vector3(w*span,step,d*span*0.9),String(rock[course%rock.size()]),rng.randi(),rng.randf_range(-0.3,0.3))
		y += step*0.9
		course += 1
	s.shard(root,Vector3(0,height+0.12,0),Vector3(w*0.75,0.24,d*0.7),String(data.get("cap","8a8a58")),rng.randi())

## A named crag (飞火崖): a tall, ruddy spire of fractured rock above the road.
func _crag(w: float, d: float) -> void:
	var rock: Array = _colors("colors",["9a5a3c","a8683f","b77a48","8a4f37","c08a55"])
	var height: float = float(data.get("height",9.0))
	var y: float = 0.0
	var course: int = 0
	while y < height:
		var t: float = y/height
		var span: float = lerpf(1.0,0.38,t*t)
		var step: float = rng.randf_range(0.5,0.9)
		var lean := Vector3(t*t*w*0.25,0,-t*d*0.1)
		for lump: int in 3:
			var a: float = lump*2.1+course
			s.shard(root,lean+Vector3(cos(a)*w*span*0.22,y+step*0.5,sin(a)*d*span*0.22),Vector3(w*span*0.7,step,d*span*0.65),String(rock[(course+lump)%rock.size()]),rng.randi(),a)
		y += step*0.85
		course += 1
	# Scorch-dark streaks where the name comes from, and dry tufts on the ledges.
	for streak: int in 5:
		s.box(root,Vector3((streak-2)*w*0.12,height*0.45,d*0.42),Vector3(0.08,height*0.5,0.05),"5a3527")
	for tuft: int in 4:
		s.box(root,Vector3(rng.randf_range(-w,w)*0.3,rng.randf_range(1.0,height*0.8),d*0.35),Vector3(0.3,0.1,0.25),"8e8a4f")

func _bones(w: float, d: float) -> void:
	var bone: Array = _colors("colors",["e2dbc6","d4cbb0","c7bc9d"])
	for i: int in int(data.get("count",5)):
		var a: float = rng.randf()*TAU
		s.tilted_box(root,Vector3(rng.randf_range(-w,w)*0.4,0.04,rng.randf_range(-d,d)*0.4),Vector3(rng.randf_range(0.25,0.5),0.06,0.07),_pick(bone),Vector3(0,a,0))
	if data.get("ribs",true):
		for rib: int in 5:
			s.tilted_box(root,Vector3(-0.15+rib*0.09,0.1,0.05),Vector3(0.04,0.18,0.32),_pick(bone),Vector3(0.6,0,0))
	if data.get("skull",true):
		# A wild goat's skull, its horns swept back: 野羊山 is named for them.
		var skull: Vector3 = Vector3(w*0.25,0.11,-d*0.15)
		s.box(root,skull,Vector3(0.22,0.18,0.3),_pick(bone))
		s.box(root,skull+Vector3(0,-0.03,0.2),Vector3(0.14,0.1,0.16),_pick(bone))
		for side: float in [-1.0,1.0]:
			s.box(root,skull+Vector3(side*0.06,0.03,0.1),Vector3(0.05,0.05,0.03),"3a3128")
			for seg: int in 3:
				s.tilted_box(root,skull+Vector3(side*(0.1+seg*0.04),0.12+seg*0.05,-0.05-seg*0.09),Vector3(0.07,0.07,0.14),"b3a98c",Vector3(-0.5-seg*0.3,0,side*0.3))

func _dead_log(w: float, d: float) -> void:
	var bark: Array = _colors("colors",["6e6253","7d705f","5c5246"])
	s.tilted_box(root,Vector3(0,0.16,0),Vector3(w,0.3,0.32),String(bark[0]),Vector3(0,0,0.04))
	for knot: int in 3:
		s.box(root,Vector3((knot-1)*w*0.3,0.32,0.03),Vector3(0.12,0.05,0.2),String(bark[2]))
	s.box(root,Vector3(w*0.5,0.16,0),Vector3(0.05,0.28,0.3),"a39072")
	for limb: int in 2:
		s.tilted_box(root,Vector3((limb-0.5)*w*0.4,0.35,0.25),Vector3(0.08,0.5,0.08),String(bark[1]),Vector3(0.7,0,0.4*(limb*2-1)))

## 土坎: a low earth step with stones and roots in its face. Blocks nothing.
func _dirt_bank(w: float, d: float) -> void:
	var soil: Array = _colors("colors",["9a7f58","8a7050","a88c62"])
	var height: float = float(data.get("height",0.35))
	for i: int in ceili(w/0.5):
		var x: float = -w/2+0.25+i*0.5
		var h: float = height*(0.75+0.45*absf(sin(i*1.3)))
		s.box(root,Vector3(x,h/2,0),Vector3(0.5,h,d),_pick(soil))
		if rng.randf()<0.45:
			s.shard(root,Vector3(x+rng.randf_range(-0.15,0.15),h*0.5,d*0.5),Vector3(0.18,0.14,0.12),"8f8670",rng.randi())
		if rng.randf()<0.3:
			s.tilted_box(root,Vector3(x,h*0.6,d*0.52),Vector3(0.03,0.25,0.03),"5e4a36",Vector3(0,0,0.6))
		if rng.randf()<0.5:
			s.box(root,Vector3(x,h+0.03,0),Vector3(0.42,0.06,d*0.8),String(data.get("top","8c8a52")))

func _cairn() -> void:
	var rock: Array = _colors("colors",["9d8c6c","a8987a","8a7b62"])
	for i: int in int(data.get("stones",5)):
		var size: float = 0.42-i*0.06
		s.shard(root,Vector3(sin(i*2.0)*0.03,0.1+i*0.17,0),Vector3(size,0.17,size*0.85),String(rock[i%rock.size()]),i,i*0.7)

func _bush(w: float, d: float) -> void:
	var leaf: Array = _colors("colors",["5d5a33","746e3c","8f8547"])
	for i: int in 7:
		var a: float = i*TAU/7.0
		s.box(root,Vector3(cos(a)*w*0.3,0.25+(i%3)*0.12,sin(a)*d*0.3),Vector3(w*0.4,0.35,d*0.4),String(leaf[i%leaf.size()]))
	for twig: int in 3:
		s.tilted_box(root,Vector3((twig-1)*w*0.2,0.5,0),Vector3(0.04,0.5,0.04),"6b5a42",Vector3(0,0,(twig-1)*0.5))

func _local(at: Array) -> Vector3:
	return Vector3(float(at[0])/32.0,0,float(at[1])/32.0)-root.position

## A trodden goat path: worn dirt and hoof-scuffed grit along `points` (pixels).
func _trail() -> void:
	var points: Array = data.get("points",[])
	var color: String = String(data.get("color","a99169"))
	for i: int in points.size()-1:
		var a: Vector3 = _local(points[i])
		var b: Vector3 = _local(points[i+1])
		var steps: int = maxi(1,ceili(a.distance_to(b)/0.32))
		for k: int in steps:
			var at: Vector3 = a.lerp(b,(k+0.5)/steps)+Vector3(rng.randf_range(-0.08,0.08),0.012,rng.randf_range(-0.08,0.08))
			s.shard(root,at,Vector3(0.34,0.015,0.24),color,rng.randi(),atan2(b.x-a.x,b.z-a.z))
			if rng.randf()<0.35:
				s.box(root,at+Vector3(rng.randf_range(-0.1,0.1),0.012,rng.randf_range(-0.1,0.1)),Vector3(0.05,0.012,0.06),"6f5f48")

## A dry stream bed (乾涸的山涧): pale sand, cracked mud plates and rounded cobbles.
func _dry_stream() -> void:
	var points: Array = data.get("points",[])
	var width: float = float(data.get("width",48))/32.0
	var cobbles: Array = _colors("cobbles",["b7ad97","a39a86","c6bda6","8f877a"])
	for i: int in points.size()-1:
		var a: Vector3 = _local(points[i])
		var b: Vector3 = _local(points[i+1])
		var along: Vector3 = (b-a).normalized()
		var across := Vector3(-along.z,0,along.x)
		var steps: int = maxi(1,ceili(a.distance_to(b)/0.3))
		for k: int in steps:
			var at: Vector3 = a.lerp(b,(k+0.5)/steps)
			var meander: float = sin((i*steps+k)*0.45)*width*0.18
			var centre: Vector3 = at+across*meander
			s.shard(root,centre+Vector3(0,0.01,0),Vector3(width*0.95,0.02,0.4),String(data.get("sand","c3b08a")),rng.randi(),atan2(along.x,along.z))
			if rng.randf()<0.5:
				s.shard(root,centre+across*rng.randf_range(-0.3,0.3)*width+Vector3(0,0.022,0),Vector3(rng.randf_range(0.2,0.4),0.012,rng.randf_range(0.18,0.32)),String(data.get("mud","a58e68")),rng.randi(),rng.randf()*TAU)
			for c: int in 2:
				if rng.randf()<0.8:
					var size: float = rng.randf_range(0.08,0.22)
					s.shard(root,centre+across*rng.randf_range(-0.5,0.5)*width+Vector3(0,size*0.3,0),Vector3(size*1.3,size*0.6,size),_pick(cobbles),rng.randi(),rng.randf()*TAU)

## 石梁: a slab of rock spanning a gorge high overhead, cracked, loose stones in its
## underside and grit trickling from it. `height` in units, the span along the box.
func _stone_beam(w: float, d: float) -> void:
	var rock: Array = _colors("colors",["8d7c62","9c896b","7b6c56","a59272"])
	var height: float = float(data.get("height",6.0))
	var segments: int = ceili(w/0.6)
	for i: int in segments:
		var x: float = -w/2+(i+0.5)*w/segments
		var sag: float = sin(float(i)/(segments-1)*PI)*0.35
		var thick: float = float(data.get("thickness",1.3))+absf(sin(i*1.7))*0.5
		s.shard(root,Vector3(x,height-sag,0),Vector3(w/segments+0.1,thick,d),_pick(rock),rng.randi(),rng.randf_range(-0.05,0.05))
		s.shard(root,Vector3(x,height-sag-thick*0.55,rng.randf_range(-0.2,0.2)*d),Vector3(w/segments*0.7,0.35,d*0.6),_pick(rock),rng.randi())
		if i%3==1:
			s.box(root,Vector3(x,height-sag+thick*0.5,d*0.2),Vector3(0.06,0.05,d*0.6),"4a3f33")
		if rng.randf()<0.4:
			s.box(root,Vector3(x,height-sag+thick*0.52,rng.randf_range(-0.3,0.3)*d),Vector3(0.35,0.08,0.3),String(data.get("growth","8b8a52")))
	# Its ends rest on rock piers that rise from the walls either side.
	for end: float in [-1.0,1.0]:
		var pier: float = height-0.4
		var y: float = 0.0
		var course: int = 0
		while y < pier:
			s.shard(root,Vector3(end*(w/2-0.2),y+0.4,sin(course*1.3)*0.1),Vector3(1.3-course*0.03,0.8,d*1.2),_pick(rock),rng.randi(),rng.randf_range(-0.2,0.2))
			y += 0.75
			course += 1
	if ambience != null:
		for trickle: int in 2:
			ambience.drip(root,Vector3((trickle-0.5)*w*0.3,0.02,0),height-0.8,String(data.get("grit","b9a77f")))

## A dark crack high in a rock face (mroad4's crack, 离地三四丈).
func _crack(w: float) -> void:
	var low: float = float(data.get("from",2.6))
	var high: float = float(data.get("to",5.0))
	var y: float = low
	var i: int = 0
	while y < high:
		var step: float = 0.35
		s.box(root,Vector3(sin(i*1.3)*0.08,y+step/2,0),Vector3(w*(0.55+0.45*sin(i*0.9+1.0)),step,0.1),"1b1714")
		y += step
		i += 1
	for lip: int in 4:
		s.shard(root,Vector3((lip-1.5)*w*0.4,low-0.1+lip*0.5,0.08),Vector3(0.2,0.14,0.12),"6e604d",lip)

## A black cave mouth in a rock face, opening toward +z.
func _cave_mouth(w: float, d: float) -> void:
	var height: float = float(data.get("height",2.6))
	var rock: Array = _colors("colors",["6f6150","7c6c58","5f5446"])
	s.box(root,Vector3(0,height*0.45,-d*0.1),Vector3(w,height*0.9,d*0.8),"0f0d0c")
	for i: int in 9:
		var t: float = float(i)/8.0
		var a: float = PI*t
		s.shard(root,Vector3(-cos(a)*w*0.55,sin(a)*height*0.95+0.1,d*0.3),Vector3(0.5,0.45,0.45),_pick(rock),i,a)
	for drip: int in 4:
		s.box(root,Vector3((drip-1.5)*w*0.18,height*0.8-drip%2*0.15,d*0.3),Vector3(0.06,0.3,0.06),String(data.get("slime","8f8a4a")))

func _campfire(w: float, d: float) -> void:
	for i: int in 9:
		var a: float = i*TAU/9.0
		s.shard(root,Vector3(cos(a)*w*0.38,0.08,sin(a)*d*0.38),Vector3(0.2,0.16,0.18),["7d7262","6b6155","8c8170"][i%3],i,a)
	s.box(root,Vector3(0,0.02,0),Vector3(w*0.6,0.03,d*0.6),"2c2621")
	for log_index: int in 4:
		s.tilted_box(root,Vector3(0,0.12,0),Vector3(0.1,0.1,w*0.55),"5e4532",Vector3(0.35,log_index*PI/4,0))
	var flames := Node3D.new()
	flames.position = Vector3(0,0.12,0)
	flames.set_meta("light_fixture",true)
	root.add_child(flames)
	for tongue: int in 5:
		var a: float = tongue*1.3
		var flame := Node3D.new()
		flame.position = Vector3(cos(a)*0.08,0,sin(a)*0.08)
		flames.add_child(flame)
		s.box(flame,Vector3(0,0.18,0),Vector3(0.12,0.36-tongue*0.04,0.12),"ffb858" if tongue%2 else "ffd88a")
		if ambience != null:
			ambience.flame(flame)
	var light := OmniLight3D.new()
	light.position = Vector3(0,0.7,0)
	light.light_color = Color("ff9f55")
	light.omni_range = float(data.get("range",6.0))
	light.set_meta("day_energy",0.35)
	light.set_meta("night_energy",2.6)
	light.set_meta("flicker",0.18)
	root.add_child(light)
	if data.get("pot",false):
		for leg: int in 3:
			var a: float = leg*TAU/3.0
			s.tilted_box(root,Vector3(cos(a)*0.35,0.5,sin(a)*0.35),Vector3(0.05,1.1,0.05),"4f3c2c",Vector3(-sin(a)*0.35,0,cos(a)*0.35))
		s.box(root,Vector3(0,0.62,0),Vector3(0.38,0.3,0.38),"2f2b28")
	if ambience != null:
		ambience.smoke(root,Vector3(0,0.6,0))

## 破旗: a tattered flag on a pole, its strips stirring in the wind.
func _banner() -> void:
	var height: float = float(data.get("height",3.4))
	var cloth: String = String(data.get("cloth","8e3b2c"))
	s.tilted_box(root,Vector3(0,height/2,0),Vector3(0.12,height,0.12),"5c4635",Vector3(0,0,0.04))
	s.box(root,Vector3(0,0.15,0),Vector3(0.5,0.3,0.5),"7d7262")
	for strip: int in 4:
		var piece := Node3D.new()
		piece.position = Vector3(0.08,height-0.25-strip*0.26,0)
		root.add_child(piece)
		var length: float = [1.1,0.95,0.7,0.5][strip]
		s.box(piece,Vector3(length/2,0,0),Vector3(length,0.24,0.03),cloth if strip!=2 else String(data.get("trim","b0a271")))
		if ambience != null:
			ambience.flutter(piece,strip*0.6)
	if data.has("text"):
		var title := Label3D.new()
		title.text = tr(String(data["text"]))
		title.position = Vector3(0.5,height-0.5,0.03)
		title.pixel_size = 0.008
		title.font_size = 48
		title.modulate = Color("e8d7a8")
		title.outline_size = 0
		root.add_child(title)

## 拦路木栅: sharpened stakes crossed along a beam, to bar a way (a blocked box).
func _barricade(w: float, d: float) -> void:
	s.box(root,Vector3(0,0.55,0),Vector3(w,0.16,0.16),"6a5038")
	for i: int in ceili(w/0.45):
		var x: float = -w/2+0.22+i*0.45
		for side: float in [-1.0,1.0]:
			s.tilted_box(root,Vector3(x,0.55,0),Vector3(0.09,1.4,0.09),"7d6044",Vector3(side*0.6,0,0))
			s.tilted_box(root,Vector3(x,0.55,0)+Vector3(0,0.6,side*0.38),Vector3(0.06,0.16,0.06),"b59d78",Vector3(side*0.6,0,0))
	for rope: int in 2:
		s.box(root,Vector3(0,0.42+rope*0.24,0),Vector3(w,0.03,0.2),"a08e62")

## 草棚: a lean-to of poles and straw against the wind, bedding under it.
func _lean_to(w: float, d: float) -> void:
	var height: float = float(data.get("height",1.9))
	for x: float in [-w/2+0.1,w/2-0.1]:
		s.box(root,Vector3(x,height/2,-d/2+0.1),Vector3(0.12,height,0.12),"6a5038")
		s.box(root,Vector3(x,0.3,d/2-0.1),Vector3(0.1,0.6,0.1),"6a5038")
	var slope: float = atan2(height-0.6,d)
	for row: int in 6:
		s.tilted_box(root,Vector3(0,height-0.1-(height-0.6)*(row+0.5)/6.0,-d/2+(row+0.5)*d/6.0),Vector3(w+0.3,0.12,d/6.0+0.08),["b39b5e","a68e55","c0a86a"][row%3],Vector3(slope,0,0))
	s.box(root,Vector3(0,0.04,0),Vector3(w*0.85,0.06,d*0.8),"a8955f")
	_bedroll_at(Vector3(-w*0.2,0,0))

func _wine_jars(w: float, d: float) -> void:
	var clay: Array = _colors("colors",["6b4a35","7b5a3e","5b3f2f"])
	for i: int in int(data.get("count",4)):
		var at := Vector3((i%2-0.5)*w*0.45,0,(floori(i/2.0)-0.5)*d*0.45)
		if i==int(data.get("broken",-1)):
			for shard: int in 4:
				s.shard(root,at+Vector3(rng.randf_range(-0.2,0.2),0.05,rng.randf_range(-0.2,0.2)),Vector3(0.2,0.08,0.14),String(clay[shard%clay.size()]),shard,rng.randf()*TAU)
			s.box(root,at+Vector3(0,0.006,0),Vector3(0.6,0.012,0.45),"4c3324")
			continue
		var tilt: float = 0.5 if i==int(data.get("tipped",-1)) else 0.0
		var jar := Node3D.new()
		jar.position = at
		jar.rotation.x = tilt
		root.add_child(jar)
		s.box(jar,Vector3(0,0.3,0),Vector3(0.42,0.5,0.42),String(clay[i%clay.size()]))
		s.box(jar,Vector3(0,0.58,0),Vector3(0.24,0.1,0.24),String(clay[(i+1)%clay.size()]))
		s.box(jar,Vector3(0,0.66,0),Vector3(0.3,0.08,0.3),"b23a2b")
		s.box(jar,Vector3(0,0.35,0.215),Vector3(0.18,0.2,0.02),"d7b26a")

## 抢来的货箱: crates and bundles taken off the road, one split open.
func _loot_crates(w: float, d: float) -> void:
	var wood: Array = _colors("colors",["8a6a45","9a7a52","7a5d3d"])
	s.box(root,Vector3(-w*0.22,0.32,-d*0.1),Vector3(0.7,0.64,0.6),String(wood[0]))
	s.box(root,Vector3(-w*0.22,0.86,-d*0.1),Vector3(0.55,0.44,0.5),String(wood[1]))
	for band: float in [-0.2,0.2]:
		s.box(root,Vector3(-w*0.22+band,0.32,-d*0.1+0.31),Vector3(0.06,0.64,0.02),"4f3c2c")
	s.box(root,Vector3(-w*0.22,0.86,-d*0.1+0.26),Vector3(0.3,0.16,0.02),"c9b98e")
	# The split crate: its lid off, bolts of cloth spilling out.
	s.box(root,Vector3(w*0.25,0.22,d*0.1),Vector3(0.7,0.44,0.6),String(wood[2]))
	s.tilted_box(root,Vector3(w*0.25+0.45,0.12,d*0.1+0.2),Vector3(0.7,0.05,0.6),String(wood[1]),Vector3(0,0.4,0.5))
	for bolt: int in 3:
		s.tilted_box(root,Vector3(w*0.25-0.15+bolt*0.15,0.48,d*0.1),Vector3(0.14,0.14,0.55),["3d6a8c","a3423a","c9a24e"][bolt],Vector3(0,0.2*bolt,0))
	s.tilted_box(root,Vector3(w*0.25+0.2,0.06,d*0.1+0.5),Vector3(0.6,0.04,0.3),"3d6a8c",Vector3(0,0.6,0))
	s.box(root,Vector3(w*0.05,0.18,d*0.35),Vector3(0.5,0.36,0.4),"a8915f")
	s.box(root,Vector3(w*0.05,0.38,d*0.35),Vector3(0.08,0.06,0.42),"6a5038")

func _bedroll(_w: float, _d: float) -> void:
	_bedroll_at(Vector3.ZERO)

func _bedroll_at(at: Vector3) -> void:
	s.box(root,at+Vector3(0,0.04,0),Vector3(0.8,0.07,1.6),"a58f5c")
	s.box(root,at+Vector3(0,0.12,-0.6),Vector3(0.75,0.14,0.3),String(data.get("blanket","6b5a4a")))
	s.tilted_box(root,at+Vector3(0.05,0.1,0.2),Vector3(0.7,0.08,0.7),String(data.get("blanket","6b5a4a")),Vector3(0,0.15,0))

## A traveller's rotted bundle and a rusted blade: someone came this way and stayed.
func _lost_pack() -> void:
	s.shard(root,Vector3(0,0.12,0),Vector3(0.6,0.24,0.45),"6e604a",3)
	s.box(root,Vector3(0.05,0.26,0),Vector3(0.08,0.04,0.48),"4f4130")
	s.tilted_box(root,Vector3(0.5,0.03,0.2),Vector3(0.07,0.03,0.85),"7a5a46",Vector3(0,0.5,0))
	s.tilted_box(root,Vector3(0.35,0.04,-0.12),Vector3(0.14,0.05,0.1),"4a3b2e",Vector3(0,0.5,0))
	s.box(root,Vector3(-0.35,0.05,0.3),Vector3(0.18,0.1,0.14),"9f6f3c")

## Dripstone rising from a cave floor, wet and pale at the tips.
func _stalagmites(w: float, d: float) -> void:
	var stone: Array = _colors("colors",["6f6a5f","7f796b","918a79","a8a08c"])
	for i: int in int(data.get("count",5)):
		var a: float = rng.randf()*TAU
		var r: float = sqrt(rng.randf())
		var at := Vector3(cos(a)*r*w*0.42,0,sin(a)*r*d*0.42)
		var height: float = rng.randf_range(0.5,1.0)*float(data.get("height",1.6))
		var courses: int = ceili(height/0.22)
		for c: int in courses:
			var t: float = float(c)/courses
			var span: float = lerpf(0.42,0.08,t)
			s.box(root,at+Vector3(0,c*0.22+0.11,0),Vector3(span,0.22,span),String(stone[mini(stone.size()-1,floori(t*stone.size()))]))

## A lip of rock jutting from a cave wall at `height`, stalactites hanging from it.
func _overhang(w: float, d: float) -> void:
	var stone: Array = _colors("colors",["5c574d","6a6458","787163"])
	var height: float = float(data.get("height",2.4))
	s.shard(root,Vector3(0,height,0),Vector3(w,0.4,d),String(stone[0]),rng.randi())
	for i: int in int(data.get("count",6)):
		var at := Vector3(rng.randf_range(-0.42,0.42)*w,height-0.2,rng.randf_range(-0.42,0.42)*d)
		var length: float = rng.randf_range(0.4,1.1)
		var courses: int = ceili(length/0.18)
		for c: int in courses:
			var span: float = lerpf(0.26,0.05,float(c)/courses)
			s.box(root,at-Vector3(0,c*0.18+0.09,0),Vector3(span,0.18,span),String(stone[mini(stone.size()-1,floori(float(c)*stone.size()/courses))]))
		if ambience != null and i==0 and data.get("drips",true):
			ambience.drip(root,Vector3(at.x,0.02,at.z),height-0.3-length)

## Slime the leeches leave: glossy puddles and trailing smears (cavern4's 暗黄色的黏稠物).
func _slime(w: float, d: float) -> void:
	var color: String = String(data.get("color","9a8a3c"))
	var gloss: StandardMaterial3D = s.material(color)
	gloss.roughness = 0.08
	gloss.metallic = 0.25
	for lobe: int in int(data.get("lobes",4)):
		var at := Vector3(rng.randf_range(-0.35,0.35)*w,0.012+lobe*0.002,rng.randf_range(-0.35,0.35)*d)
		s.shard(root,at,Vector3(rng.randf_range(0.3,0.6)*w,0.025,rng.randf_range(0.3,0.6)*d),color,rng.randi(),rng.randf()*TAU)
	for smear: int in int(data.get("trails",3)):
		var a: float = rng.randf()*TAU
		for k: int in 5:
			s.box(root,Vector3(cos(a)*(0.3+k*0.22)*w*0.5,0.01,sin(a)*(0.3+k*0.22)*d*0.5),Vector3(0.12,0.012,0.12),color)
	if data.get("strands",false):
		for strand: int in 3:
			s.box(root,Vector3(rng.randf_range(-0.3,0.3)*w,0.12,rng.randf_range(-0.3,0.3)*d),Vector3(0.025,0.22,0.025),color)

func _pool(w: float, d: float) -> void:
	var water: String = String(data.get("color","2f4246"))
	var mat: StandardMaterial3D = s.material(water)
	mat.roughness = 0.05
	mat.metallic = 0.45
	s.shard(root,Vector3(0,0.008,0),Vector3(w*1.05,0.02,d*1.05),String(data.get("rim","4b4a42")),rng.randi())
	s.shard(root,Vector3(0,0.02,0),Vector3(w*0.9,0.02,d*0.9),water,rng.randi())
	for glint: int in 3:
		s.box(root,Vector3(rng.randf_range(-0.3,0.3)*w,0.034,rng.randf_range(-0.3,0.3)*d),Vector3(0.2,0.004,0.03),"9fb7b6")
	if data.get("drip",true) and ambience != null:
		ambience.drip(root,Vector3(0,0.03,0),float(data.get("height",2.6)))

func _drip() -> void:
	s.shard(root,Vector3(0,0.01,0),Vector3(0.5,0.015,0.4),"3c4648",rng.randi())
	if ambience != null:
		ambience.drip(root,Vector3(0,0.02,0),float(data.get("height",2.6)))

## Daylight coming into a cave mouth: a pale shaft and its glow, dimmer by night.
func _light_shaft(w: float, d: float) -> void:
	var haze := StandardMaterial3D.new()
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.albedo_color = Color(String(data.get("color","f3e3b8")),0.13)
	haze.cull_mode = BaseMaterial3D.CULL_DISABLED
	var height: float = float(data.get("height",2.6))
	for beam: int in 3:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(w*(0.5-beam*0.12),0.05,height*1.4)
		var shaft := MeshInstance3D.new()
		shaft.mesh = mesh
		shaft.material_override = haze
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shaft.position = Vector3((beam-1)*w*0.22,height*0.5,0)
		shaft.rotation = Vector3(-0.85,0,0)
		root.add_child(shaft)
	s.shard(root,Vector3(0,0.006,d*0.2),Vector3(w,0.01,d*0.8),String(data.get("floor","a6987a")),rng.randi())
	var light := OmniLight3D.new()
	light.position = Vector3(0,height*0.7,0)
	light.light_color = Color(String(data.get("light","ffe7b5")))
	light.omni_range = float(data.get("range",7.0))
	light.set_meta("day_energy",float(data.get("day",1.6)))
	light.set_meta("night_energy",float(data.get("night",0.35)))
	root.add_child(light)

## A broken cart wheel half sunk in the weeds: carts used to come this way.
func _cart_wheel() -> void:
	var wood: String = String(data.get("wood","6e5a42"))
	var wheel := Node3D.new()
	wheel.rotation = Vector3(1.2,rng.randf()*TAU,0)
	wheel.position.y = 0.25
	root.add_child(wheel)
	for i: int in 10:
		var a: float = i*TAU/10.0
		if i==7:
			continue
		s.tilted_box(wheel,Vector3(cos(a)*0.55,0,sin(a)*0.55),Vector3(0.36,0.1,0.12),wood,Vector3(0,-a+PI/2,0))
	for spoke: int in 5:
		s.tilted_box(wheel,Vector3.ZERO,Vector3(1.0,0.06,0.06),"5a4936",Vector3(0,spoke*PI/5,0))
	s.box(wheel,Vector3.ZERO,Vector3(0.2,0.14,0.2),"4f3f2e")

## Rough stone steps laid across a steep stretch of road (visual; the slope is the road).
func _rough_steps(w: float, d: float) -> void:
	var stone: Array = _colors("colors",["9a8d72","a89a7c","8a7e66"])
	var count: int = int(data.get("count",4))
	for i: int in count:
		var z: float = -d/2+(i+0.5)*d/count
		s.shard(root,Vector3(rng.randf_range(-0.05,0.05),0.03+i*0.012,z),Vector3(w*rng.randf_range(0.8,0.95),0.08,d/count*0.55),_pick(stone),rng.randi(),rng.randf_range(-0.08,0.08))

## A pitch torch stuck in the ground: a watch fire for the night.
func _torch() -> void:
	var height: float = float(data.get("height",1.8))
	s.tilted_box(root,Vector3(0,height/2,0),Vector3(0.1,height,0.1),"5c4635",Vector3(0.08,0,0.05))
	s.box(root,Vector3(0,height,0),Vector3(0.2,0.26,0.2),"3b2f26")
	var flame := Node3D.new()
	flame.position = Vector3(0.02,height+0.12,0)
	flame.set_meta("light_fixture",true)
	root.add_child(flame)
	s.box(flame,Vector3(0,0.14,0),Vector3(0.16,0.28,0.16),"ffb858")
	s.box(flame,Vector3(0,0.22,0),Vector3(0.09,0.2,0.09),"ffd88a")
	if ambience != null:
		ambience.flame(flame)
		ambience.smoke(root,Vector3(0,height+0.4,0),"6f6a62",3)
	var light := OmniLight3D.new()
	light.position = Vector3(0,height+0.3,0)
	light.light_color = Color("ffa45c")
	light.omni_range = float(data.get("range",5.0))
	light.set_meta("day_energy",0.2)
	light.set_meta("night_energy",2.0)
	light.set_meta("flicker",0.2)
	root.add_child(light)

## Light from somewhere unseen (a doorway's candles, a glow off wet rock): only a light.
func _glow() -> void:
	var light := OmniLight3D.new()
	light.position = Vector3(0,float(data.get("height",1.2)),0)
	light.light_color = Color(String(data.get("color","ffb867")))
	light.omni_range = float(data.get("range",3.5))
	light.set_meta("day_energy",float(data.get("day",0.2)))
	light.set_meta("night_energy",float(data.get("night",1.2)))
	if data.has("flicker"):
		light.set_meta("flicker",float(data["flicker"]))
	root.add_child(light)
