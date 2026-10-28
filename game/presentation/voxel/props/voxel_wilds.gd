extends RefCounted

## The wilds: mountain passes and caves (美术规划 groups C and F). Rocks, bones and dry
## stream beds, a bandit camp's fire, flag, stakes and plunder, the stone beam over a
## canyon, cave mouths, dripstone, slime and pools; the cloud sea below a peak and far
## peaks across the valleys. Sizes and colours come from the data;
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
		"cloud_sea": _cloud_sea(w,d)
		"far_peak": _far_peak(w,d)
		"stuck_swords": _stuck_swords(w,d)
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
		"bone_gate": _bone_gate(w,d)
		"sandbags": _sandbags(w,d)
		"stakes": _stakes(w,d)
		"skull_pit": _skull_pit(w,d)
		"carved_wall": _carved_wall(w)
		"vent": _vent(w,d)
		"flames": _flames(w,d)
		"quarry_face": _quarry_face(w,d)
		"bagua": _bagua()
		"candlestick": _candlestick()
		"brazier": _brazier(w)
		"vase_hollow": _vase_hollow(w,d)
		"iron_gate": _iron_gate(w,d)
		"gate_pier": _gate_pier(w,d)
		"winch": _winch(w,d)
		"iron_chain": _iron_chain(w,d)
		"iron_palisade": _iron_palisade(w,d)
		"tent_pole": _tent_pole(w,d)
		"mirror": _mirror(w,d)
		"mound": _mound(w,d)
		"tiger_head": _tiger_head(w,d)
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

## A bush: its lobes turned and sized by its place, so no two along a path are alike.
func _bush(w: float, d: float) -> void:
	var leaf: Array = _colors("colors",["5d5a33","746e3c","8f8547"])
	var vary: RandomNumberGenerator = Shapes.spot_rng(root.position)
	var turn: float = vary.randf()*TAU
	var lift: float = vary.randf_range(0.85,1.15)
	for i: int in 7:
		var a: float = i*TAU/7.0+turn
		var size: float = vary.randf_range(0.85,1.15)
		s.box(root,Vector3(cos(a)*w*0.3,(0.25+(i%3)*0.12)*lift,sin(a)*d*0.3),Vector3(w*0.4*size,0.35*lift,d*0.4*size),String(leaf[i%leaf.size()]))
	for twig: int in vary.randi_range(2,4):
		var side: float = (twig-1)*w*0.2
		s.tilted_box(root,Vector3(side,0.5*lift,vary.randf_range(-0.1,0.1)*d),Vector3(0.04,0.5*lift,0.04),"6b5a42",Vector3(vary.randf_range(-0.2,0.2),0,(twig-1)*0.5+vary.randf_range(-0.15,0.15)))

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
		var length: float = rng.randf_range(0.3,0.7)
		var courses: int = ceili(length/0.18)
		for c: int in courses:
			var span: float = lerpf(0.26,0.05,float(c)/courses)
			s.box(root,at-Vector3(0,c*0.18+0.09,0),Vector3(span,0.18,span),String(stone[mini(stone.size()-1,floori(float(c)*stone.size()/courses))]))
		if ambience != null and i==0 and data.get("drips",true):
			ambience.drip(root,Vector3(at.x,0.02,at.z),height-0.3-length)

## Slime the leeches leave: glossy puddles and trailing smears (cavern4's 暗黄色的黏稠物).
func _slime(w: float, d: float) -> void:
	var color: String = String(data.get("color","9a8a3c"))+":gloss"
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
	var water: String = String(data.get("color","2f4246"))+":gloss"
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

## Daylight coming into a cave mouth: a pale shaft and its glow, dimmer by night. With
## `haze` [day, night] the rays' opacity follows the light (moonlight through the pines
## shows only at night); `rays` how many.
func _light_shaft(w: float, d: float) -> void:
	var haze := StandardMaterial3D.new()
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.albedo_color = Color(String(data.get("color","f3e3b8")),0.07)
	haze.cull_mode = BaseMaterial3D.CULL_DISABLED
	if data.has("haze"):
		haze.set_meta("haze",data["haze"])
	var height: float = float(data.get("height",2.6))
	# A few thin slanting rays, falling inward (+z) from above the opening.
	for beam: int in int(data.get("rays",4)):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12+beam%2*0.1,0.12+beam%2*0.1,height*1.5)
		var shaft := MeshInstance3D.new()
		shaft.mesh = mesh
		shaft.material_override = haze
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shaft.position = Vector3((beam-1.5)*w*0.18,height*0.5,0.2*beam)
		shaft.rotation = Vector3(float(data.get("slant",0.75)),0,0)
		root.add_child(shaft)
	if data.get("floor_patch",true):
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

## hollow3.c: 山壁天然行成一空穴(vase), 积满寒露 — a mass of rock with a vase-shaped hollow in its
## face, dark within, cold dew pooled at its lip and beading down the stone.
func _vase_hollow(w: float, d: float) -> void:
	var rock: Array = _colors("colors",["6e7478","7a8084","62686c","868c90"])
	var tall: float = float(data.get("height",2.2))
	for i: int in 7:
		var a: float = i*0.9
		s.shard(root,Vector3(cos(a)*w*0.28,tall*0.5*(0.6+0.1*(i%3)),sin(a)*d*0.22-d*0.1),Vector3(w*0.5,tall*(0.7+0.1*(i%2)),d*0.5),_pick(rock),i,a)
	# The hollow: a narrow neck under a round belly, black inside.
	s.box(root,Vector3(0,tall*0.32,d*0.3),Vector3(w*0.36,tall*0.3,d*0.3),"0d0c0b")
	s.box(root,Vector3(0,tall*0.58,d*0.3),Vector3(w*0.18,tall*0.22,d*0.3),"0d0c0b")
	s.box(root,Vector3(0,tall*0.74,d*0.3),Vector3(w*0.28,tall*0.1,d*0.3),"0d0c0b")
	s.box(root,Vector3(0,tall*0.18,d*0.44),Vector3(w*0.3,0.04,0.12),"b8d4e8:mist")
	for drop: int in 5:
		s.box(root,Vector3(-w*0.2+drop*w*0.1,tall*0.12-drop%2*0.06,d*0.5),Vector3(0.04,0.08,0.03),"cfe4f2")

## 老松寨's hidden gate (keep1.c): a frame of rough logs across the opening, four or five
## beasts' skulls and iron chains hung from the lintel, dry pine boughs laid over the top so
## it is hard to make out in the forest. Spans the box's width.
func _bone_gate(w: float, d: float) -> void:
	var height: float = float(data.get("height",3.0))
	var wood: Array = _colors("colors",["5a4634","6a533d","4b3a2b"])
	for x: float in [-w/2+0.18,w/2-0.18]:
		s.box(root,Vector3(x,height/2,0),Vector3(0.36,height,0.4),_pick(wood))
		s.box(root,Vector3(x,height+0.08,0),Vector3(0.3,0.2,0.34),String(wood[2]))
	s.box(root,Vector3(0,height-0.15,0),Vector3(w+0.5,0.32,0.36),_pick(wood))
	s.tilted_box(root,Vector3(0,height-0.6,0.05),Vector3(w*0.9,0.14,0.12),String(wood[1]),Vector3(0,0,0.08))
	# The skulls, an odd number of different beasts, and the chains between them.
	var count: int = int(data.get("skulls",5))
	for i: int in count:
		var x: float = -w*0.4+i*w*0.8/maxf(1,count-1)
		var hang: float = 0.35+(i%2)*0.2
		s.box(root,Vector3(x,height-0.3-hang*0.5,0.22),Vector3(0.03,hang,0.03),"4a4a48")
		var skull := Vector3(x,height-0.42-hang,0.24)
		s.box(root,skull,Vector3(0.26,0.22,0.3),_pick(["e2dbc6","d4cbb0","c7bc9d"]))
		s.box(root,skull+Vector3(0,-0.06,0.18),Vector3(0.16,0.12,0.14),_pick(["d4cbb0","c7bc9d"]))
		for side: float in [-1.0,1.0]:
			s.box(root,skull+Vector3(side*0.07,0.02,0.14),Vector3(0.06,0.06,0.03),"2e2620")
			if i%2==0:
				s.tilted_box(root,skull+Vector3(side*0.14,0.14,-0.04),Vector3(0.06,0.06,0.2),"b3a98c",Vector3(-0.7,0,side*0.5))
	for link: int in ceili(w/0.18):
		var x: float = -w/2+0.09+link*0.18
		var sag: float = sin(float(link)/ceili(w/0.18)*PI)*0.35
		s.box(root,Vector3(x,height-0.38-sag,0.2),Vector3(0.12,0.06,0.04) if link%2 else Vector3(0.12,0.04,0.07),"55524c")
	# Dry pine boughs heaped over the frame (乾枯的松枝).
	var dry: Array = _colors("boughs",["7a6a3e","8a7744","6a5c38","94834e"])
	for i: int in ceili(w/0.35)+2:
		var x: float = -w/2-0.3+i*0.35
		s.tilted_box(root,Vector3(x,height+0.2+rng.randf()*0.2,rng.randf_range(-0.2,0.2)),Vector3(0.7,0.14,0.4),_pick(dry),Vector3(rng.randf_range(-0.3,0.3),rng.randf()*TAU,rng.randf_range(-0.2,0.2)))
		if i%2==0:
			s.tilted_box(root,Vector3(x,height-0.1,0.3),Vector3(0.12,0.6,0.08),_pick(dry),Vector3(0.2,0,rng.randf_range(-0.4,0.4)))

## 沙包石堆: sandbags stacked at a stockade's strong point, a pile of stones beside them.
func _sandbags(w: float, d: float) -> void:
	var cloth: Array = _colors("colors",["9a8a62","a8976b","8a7b56"])
	var rows: int = int(data.get("rows",3))
	for row: int in rows:
		var count: int = maxi(1,floori(w/0.55))-row%2
		for i: int in count:
			var x: float = -w/2+0.3+i*0.55+(row%2)*0.27
			s.shard(root,Vector3(x,0.15+row*0.26,-d*0.15),Vector3(0.58,0.3,0.38),_pick(cloth),rng.randi(),rng.randf_range(-0.1,0.1))
	var rock: Array = ["7f7a6c","8d8778","6f6a5e"]
	for i: int in 8:
		var size: float = rng.randf_range(0.18,0.32)
		s.shard(root,Vector3(rng.randf_range(-0.4,0.4)*w,size*0.4+(0.2 if i>5 else 0.0),d*0.22+rng.randf_range(-0.1,0.1)),Vector3(size*1.2,size*0.8,size),_pick(rock),rng.randi(),rng.randf()*TAU)

## 一排木桩: sharpened stakes driven into the ground in a row.
func _stakes(w: float, d: float) -> void:
	var wood: Array = _colors("colors",["6a5038","7d6044","5a4430"])
	for i: int in maxi(1,ceili(w/0.3)):
		var x: float = -w/2+0.15+i*0.3
		var h: float = float(data.get("height",1.6))*rng.randf_range(0.8,1.05)
		s.tilted_box(root,Vector3(x,h/2,0),Vector3(0.18,h,0.18),_pick(wood),Vector3(rng.randf_range(-0.06,0.06),0,rng.randf_range(-0.06,0.06)))
		s.box(root,Vector3(x,h+0.06,0),Vector3(0.1,0.14,0.1),"b59d78")
	s.box(root,Vector3(0,0.5,0),Vector3(w,0.06,0.22),String(data.get("rope","8e7c55")))

## 大坑 (keep3.c): a pit dug in the floor, skulls soaking in a stinking yellow water.
func _skull_pit(w: float, d: float) -> void:
	var rim: Array = _colors("rim",["5c5446","6b6150","4f483c"])
	for i: int in ceili((w+d)*2/0.4):
		var t: float = float(i)/ceili((w+d)*2/0.4)
		var a: float = t*TAU
		s.shard(root,Vector3(cos(a)*w*0.5,0.08,sin(a)*d*0.5),Vector3(0.42,0.18,0.34),_pick(rim),i,a)
	s.box(root,Vector3(0,-0.02,0),Vector3(w*0.9,0.04,d*0.9),"3a3226")
	s.box(root,Vector3(0,0.03,0),Vector3(w*0.84,0.02,d*0.84),String(data.get("water","a8973a"))+":gloss")
	for i: int in int(data.get("skulls",9)):
		var at := Vector3(rng.randf_range(-0.35,0.35)*w,0.05,rng.randf_range(-0.35,0.35)*d)
		s.tilted_box(root,at,Vector3(0.24,0.18,0.28),_pick(["d9d0b4","c9be9e","b8ad8c"]),Vector3(rng.randf_range(-0.4,0.4),rng.randf()*TAU,0))
		s.box(root,at+Vector3(0,0.05,0.1),Vector3(0.06,0.05,0.04),"2e2620")
	if ambience != null:
		ambience.smoke(root,Vector3(0,0.1,0),String(data.get("fumes","9a9a58")),4,0.25)

## A crack in the rock floor breathing sulphur (tunnel.c: 隧道中你可以闻到一股硫磺的味道, 想必左近
## 便有温泉或是火山): the split edged with a yellow crust (`crust`), a few crystals, thin fumes
## (`fumes`) curling up from it.
func _vent(w: float, d: float) -> void:
	var crust: Array = _colors("crust",["c8b44a","d8c45a","b8a440"])
	s.box(root,Vector3(0,0.01,0),Vector3(w*0.8,0.02,0.08),"1e1a16")
	for i: int in 9:
		var t: float = (float(i)/8.0-0.5)*w*0.9
		s.shard(root,Vector3(t,0.03,rng.randf_range(-d,d)*0.3),Vector3(rng.randf_range(0.1,0.22),0.05,rng.randf_range(0.08,0.16)),_pick(crust),i,rng.randf()*TAU)
	for crystal: int in 3:
		s.tilted_box(root,Vector3(rng.randf_range(-w,w)*0.3,0.06,rng.randf_range(-d,d)*0.2),Vector3(0.05,0.12,0.05),"e8d86a",Vector3(rng.randf_range(-0.4,0.4),0,rng.randf_range(-0.4,0.4)))
	if ambience != null:
		ambience.smoke(root,Vector3(0,0.05,0),String(data.get("fumes","d8d4a8")),4,0.18)

## Words cut into a rock face with a sword (cave5.c's wall): rows of pale strokes. With `text`
## (sroad1.c: 山壁上刻著「山烟寺」几个大字, 看起来岁月已经颇久了) great characters cut deep, the red
## that once filled them faded, lichen in the strokes.
func _carved_wall(w: float) -> void:
	if data.has("text"):
		var title := Label3D.new()
		title.text = TranslationServer.translate(String(data["text"]))
		title.position = Vector3(0,float(data.get("from",1.6)),0.03)
		title.pixel_size = 0.012
		title.font_size = 96
		title.outline_size = 10
		title.outline_modulate = Color(String(data.get("shade","4a4238")))
		title.modulate = Color(String(data.get("color","9a5a48")))
		# Cut in the stone: lit like the rock round it, dark at night.
		title.shaded = true
		root.add_child(title)
		for patch: int in 6:
			s.box(root,Vector3(rng.randf_range(-w,w)*0.4,title.position.y+rng.randf_range(-0.5,0.5),0.02),Vector3(rng.randf_range(0.1,0.3),rng.randf_range(0.06,0.16),0.02),_pick(["6a7a4a","7a8a52","5a6a42"]))
		return
	var low: float = float(data.get("from",0.9))
	var rows: int = int(data.get("rows",5))
	for row: int in rows:
		for stroke: int in maxi(2,floori(w/0.16)):
			if rng.randf()<0.2:
				continue
			var x: float = -w/2+0.08+stroke*0.16
			var y: float = low+row*0.3
			var tall: bool = rng.randf()<0.5
			s.tilted_box(root,Vector3(x,y,0),Vector3(0.025 if tall else 0.12,0.2 if tall else 0.025,0.03),String(data.get("color","c9bea2")),Vector3(0,0,rng.randf_range(-0.5,0.5)))

## 铜铸的烛台 (passage.c): a bronze candlestick taller than a man's waist, three candles
## burning on its arms.
func _candlestick() -> void:
	var bronze: Array = _colors("colors",["8a6a32","a07c3c","6e5428"])
	var height: float = float(data.get("height",1.4))
	s.box(root,Vector3(0,0.06,0),Vector3(0.4,0.12,0.4),String(bronze[2]))
	s.box(root,Vector3(0,0.16,0),Vector3(0.24,0.1,0.24),String(bronze[0]))
	s.box(root,Vector3(0,height/2,0),Vector3(0.08,height,0.08),String(bronze[1]))
	s.box(root,Vector3(0,height*0.55,0),Vector3(0.16,0.08,0.16),String(bronze[0]))
	for arm: int in 3:
		var x: float = (arm-1)*0.24
		s.box(root,Vector3(x*0.5,height,0),Vector3(absf(x)+0.06,0.05,0.05),String(bronze[1]))
		s.box(root,Vector3(x,height+0.04,0),Vector3(0.12,0.05,0.12),String(bronze[0]))
		s.box(root,Vector3(x,height+0.15,0),Vector3(0.07,0.18,0.07),"e8dcc0")
		var flame := Node3D.new()
		flame.position = Vector3(x,height+0.27,0)
		flame.set_meta("light_fixture",true)
		root.add_child(flame)
		s.box(flame,Vector3(0,0.04,0),Vector3(0.05,0.09,0.05),"ffd88a")
		if ambience != null:
			ambience.flame(flame)
	var light := OmniLight3D.new()
	light.position = Vector3(0,height+0.4,0)
	light.light_color = Color("ffb867")
	light.omni_range = float(data.get("range",4.0))
	light.set_meta("day_energy",float(data.get("day",1.4)))
	light.set_meta("night_energy",float(data.get("night",1.6)))
	light.set_meta("flicker",0.1)
	root.add_child(light)

## 火盆 (keep3.c): an iron basin of coals on three legs, flames and smoke rising.
func _brazier(w: float) -> void:
	var iron: Array = _colors("colors",["3a3532","4a4440","2e2a28"])
	for leg: int in 3:
		var a: float = leg*TAU/3.0
		s.tilted_box(root,Vector3(cos(a)*w*0.28,0.3,sin(a)*w*0.28),Vector3(0.07,0.66,0.07),String(iron[2]),Vector3(-sin(a)*0.3,0,cos(a)*0.3))
	s.box(root,Vector3(0,0.66,0),Vector3(w*0.75,0.22,w*0.75),String(iron[0]))
	s.box(root,Vector3(0,0.78,0),Vector3(w*0.8,0.05,w*0.8),String(iron[1]))
	s.box(root,Vector3(0,0.79,0),Vector3(w*0.6,0.04,w*0.6),"8a3a1e")
	var flames := Node3D.new()
	flames.position = Vector3(0,0.8,0)
	flames.set_meta("light_fixture",true)
	root.add_child(flames)
	for tongue: int in 4:
		var flame := Node3D.new()
		flame.position = Vector3(cos(tongue*1.6)*0.1,0,sin(tongue*1.6)*0.1)
		flames.add_child(flame)
		s.box(flame,Vector3(0,0.15,0),Vector3(0.12,0.3-tongue*0.04,0.12),"ffb858" if tongue%2 else "ffd88a")
		if ambience != null:
			ambience.flame(flame)
	var light := OmniLight3D.new()
	light.position = Vector3(0,1.3,0)
	light.light_color = Color("ff9f55")
	light.omni_range = float(data.get("range",5.0))
	light.set_meta("day_energy",float(data.get("day",1.6)))
	light.set_meta("night_energy",float(data.get("night",2.2)))
	light.set_meta("flicker",0.16)
	root.add_child(light)
	if ambience != null:
		ambience.smoke(root,Vector3(0,1.2,0),"6f6a62",3)

## 云海: a sea of cloud below a peak or along a gorge's depths (clifftop.c: 一片云雾之中突出几座
## 山峰): billows of mist in see-through slabs (`colors`, ":haze") that drift slowly about where
## they lie, the faint shimmer of water through it (`shimmer`: 好似水波的微光), and `peaks`
## ([[x, z, height, radius], ...] units from its middle) of far rock standing out of it.
func _cloud_sea(w: float, d: float) -> void:
	var mist: Array = _colors("colors",["e6ecef","d6dfe4","f2f5f6"])
	var drifting := Node3D.new()
	root.add_child(drifting)
	var count: int = int(data.get("count",maxi(8,floori(w*d/12.0))))
	var thick: Array = data.get("thickness",[0.3,0.9])
	var suffix: String = ":haze" if data.get("haze",false) else ":mist"
	for i: int in count:
		# A billow: a broad flat bank, a rounder heap on it, a small crown.
		var at := Vector3(rng.randf_range(-0.5,0.5)*w,rng.randf_range(-0.3,0.3),rng.randf_range(-0.5,0.5)*d)
		var size: float = rng.randf_range(1.8,4.4)*float(data.get("billow",1.0))
		var tall: float = rng.randf_range(float(thick[0]),float(thick[1]))
		s.box(drifting,at,Vector3(size*rng.randf_range(1.3,2.0),tall*0.5,size*1.1),_pick(mist)+suffix)
		s.box(drifting,at+Vector3(rng.randf_range(-0.3,0.3)*size,tall*0.45,0),Vector3(size*0.95,tall*0.7,size*0.7),_pick(mist)+suffix)
		if i%2==0:
			s.box(drifting,at+Vector3(rng.randf_range(-0.2,0.2)*size,tall*0.95,0),Vector3(size*0.45,tall*0.45,size*0.4),String(mist[mist.size()-1])+suffix)
	if ambience != null:
		ambience.drift(drifting,root.position.x*0.37+root.position.z*0.11,float(data.get("drift",1.2)))
	for i: int in int(data.get("shimmer",0)):
		s.box(root,Vector3(rng.randf_range(-0.45,0.45)*w,-0.35,rng.randf_range(-0.45,0.45)*d),Vector3(rng.randf_range(1.0,2.4),0.015,0.05),String(data.get("shimmer_color","e4f0f2")))
	var rock: Array = _colors("rock",["8e9aa2","9aa6ad","a7b2b8","84909a"])
	for peak: Array in data.get("peaks",[]):
		var base := Vector3(float(peak[0]),-1.0,float(peak[1]))
		var top: float = float(peak[2])
		var radius: float = float(peak[3])
		var tiers: int = ceili(top/0.7)
		for tier: int in tiers:
			var t: float = float(tier)/tiers
			var r: float = radius*(1.0-t*0.8)
			s.box(root,base+Vector3(sin(tier*1.9)*r*0.15,tier*0.7+0.35,cos(tier*1.3)*r*0.12),Vector3(r*1.6,0.7,r*1.3),_pick(rock)+suffix)
		if peak.size() > 4 and peak[4]:
			# A pine bent on the summit, as far peaks are drawn.
			s.box(root,base+Vector3(0,top+0.5,0),Vector3(0.9,0.6,0.7),"5a6a64"+suffix)

## A far peak seen across the valleys (wpath4.c: 西面山顶上竖立在虹台中央的「擎天柱」): a main
## summit and two shoulders of stepped rock in the blue of distance (`colors`; `haze`: seen
## through), rising `height` units from below the ground, a white stone terrace on its top
## (`platform`: 虹台), a tall pillar in the terrace's middle (`pillar`: its height), or a white
## tower of storeys on its summit (`tower`: ladder2.c 山顶上矗立著一座雄伟的白色楼阁).
func _far_peak(w: float, d: float) -> void:
	var haze: String = ":haze" if data.get("haze",false) else ""
	var slopes: Array = _colors("colors",["9fb1bb","a9bac3","b4c4cc","95a7b2"])
	var height: float = float(data.get("height",9.0))
	var radius: float = minf(w,d)/2
	var summit: float = 0.0
	for shoulder: Array in [[0.0,0.0,1.0],[-0.5,0.2,0.6],[0.48,-0.15,0.72]]:
		var top: float = height*float(shoulder[2])
		var r: float = radius*(0.5+0.5*float(shoulder[2]))
		var tiers: int = ceili(top/0.8)
		for tier: int in tiers:
			var t: float = float(tier)/tiers
			var rr: float = r*(1.0-t*0.84)
			var at := Vector3(float(shoulder[0])*radius+sin(tier*1.7+top)*rr*0.12,-1.0+tier*0.8+0.4,float(shoulder[1])*radius+cos(tier*1.3)*rr*0.1)
			s.box(root,at,Vector3(rr*1.5,0.8,rr*1.2),_pick(slopes)+haze)
		if shoulder[2] == 1.0:
			summit = -1.0+tiers*0.8
	if data.get("platform",false):
		var top: float = radius*0.36
		s.box(root,Vector3(0,summit+0.15,0),Vector3(top*2.0,0.3,top*1.7),"dcd8cc"+haze)
		for i: int in 10:
			var a: float = i*TAU/10.0
			s.box(root,Vector3(cos(a)*top,summit+0.5,sin(a)*top*0.85),Vector3(0.2,0.5,0.2),"e8e4d8"+haze)
	if data.has("pillar"):
		var tall: float = float(data["pillar"])
		s.box(root,Vector3(0,summit+0.3+tall/2,0),Vector3(0.7,tall,0.7),"ece8dc"+haze)
		s.box(root,Vector3(0,summit+0.35+tall,0),Vector3(1.0,0.3,1.0),"d8c48a"+haze)
	if data.has("tower"):
		# A white tower of storeys on the summit (`tower`: storeys), each eave dark against
		# the white walls, a gilt point on top: seen far off, above the clouds.
		var storeys: int = int(data["tower"])
		var span: float = radius*0.42
		var y: float = summit+0.2
		s.box(root,Vector3(0,y,0),Vector3(span*2.4,0.4,span*2.2),"d8d4c8"+haze)
		for storey: int in storeys:
			var side: float = span*(1.6-storey*0.28)
			s.box(root,Vector3(0,y+0.2+0.75,0),Vector3(side,1.5,side*0.9),"f2efe6"+haze)
			s.box(root,Vector3(0,y+0.2+1.0,side*0.46),Vector3(side*0.3,0.5,0.02),"8a6a4a"+haze)
			s.box(root,Vector3(0,y+0.2+1.6,0),Vector3(side+0.7,0.22,side*0.9+0.7),String(data.get("eaves","4a5458"))+haze)
			y += 1.8
		s.box(root,Vector3(0,y+0.4,0),Vector3(0.22,0.8,0.22),"d8c48a"+haze)
## 葬剑: swords driven point-down into the earth (`count`), leaning, the blades rusted, a faded
## tassel on a hilt here and there.
func _stuck_swords(w: float, d: float) -> void:
	var steel: Array = _colors("colors",["8a8e8a","7d6a58","9a9e98","6e5a48"])
	for i: int in int(data.get("count",5)):
		var at := Vector3(rng.randf_range(-0.42,0.42)*w,-0.1,rng.randf_range(-0.42,0.42)*d)
		s.frame = Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.3,0.3),rng.randf()*TAU,rng.randf_range(-0.3,0.3))),at)
		s.box(root,Vector3(0,0.42,0),Vector3(0.07,0.84,0.025),_pick(steel))
		s.box(root,Vector3(0,0.86,0),Vector3(0.26,0.05,0.07),"6a5a3a")
		s.box(root,Vector3(0,1.0,0),Vector3(0.05,0.24,0.05),"3f2c22")
		s.box(root,Vector3(0,1.14,0),Vector3(0.08,0.06,0.08),"8a7a4a")
		if i%3==0:
			s.box(root,Vector3(0.03,0.96,0.04),Vector3(0.04,0.22,0.03),String(data.get("tassel","8a3a30")))
	s.frame = Transform3D.IDENTITY

## 火光冲天 (eight5.c): fire standing up out of scorched ground, tongues of several heights
## jumping, embers glowing in the black, its light wavering over everything near (`height`
## of the tallest tongue, `count` of tongues).
func _flames(w: float, d: float) -> void:
	s.box(root,Vector3(0,0.02,0),Vector3(w*0.9,0.04,d*0.9),"1f1a17")
	for ember: int in 9:
		s.box(root,Vector3(rng.randf_range(-0.4,0.4)*w,0.05,rng.randf_range(-0.4,0.4)*d),Vector3(0.16,0.05,0.12),_pick(["d4562c:glow","e8873a:glow","9e3a22:glow"]))
	var tall: float = float(data.get("height",2.4))
	for tongue: int in int(data.get("count",8)):
		var flame := Node3D.new()
		flame.position = Vector3(rng.randf_range(-0.35,0.35)*w,0.04,rng.randf_range(-0.35,0.35)*d)
		flame.set_meta("light_fixture",true)
		root.add_child(flame)
		var h: float = tall*rng.randf_range(0.35,1.0)
		s.box(flame,Vector3(0,h*0.3,0),Vector3(0.34,h*0.6,0.34),"e8622f:glow")
		s.box(flame,Vector3(0,h*0.62,0),Vector3(0.22,h*0.5,0.22),"ffa24a:glow")
		s.box(flame,Vector3(0,h*0.9,0),Vector3(0.1,h*0.28,0.1),"ffe09a:glow")
		if ambience != null:
			ambience.flame(flame)
	var light := OmniLight3D.new()
	light.position = Vector3(0,tall*0.6,0)
	light.light_color = Color("ff8a3d")
	light.omni_range = float(data.get("range",8.0))
	light.set_meta("day_energy",float(data.get("day",1.8)))
	light.set_meta("night_energy",3.2)
	light.set_meta("flicker",0.22)
	root.add_child(light)
	if ambience != null:
		ambience.smoke(root,Vector3(0,tall,0),"4a3a32",5,0.4)

## 采石场的石壁 (field1.c: 经过多年的采挖已经看不出原来的模样): a face cut back in benches, each
## bench's riser dressed flat and paler than the weathered rock, rows of wedge holes where the
## next block will be split off, a block half split and left, chips heaped at the foot. It
## stands against the cliff (`on_cliff`), its benches `steps` high, the cut face toward +z.
func _quarry_face(w: float, d: float) -> void:
	var fresh: Array = _colors("colors",["a3a493","adad9b","9a9b8b","b6b4a2"])
	var steps: int = int(data.get("steps",3))
	var rise: float = float(data.get("rise",0.9))
	for step: int in steps:
		var depth: float = d*(1.0-float(step)/steps)
		var z: float = -d/2+depth/2
		var y: float = step*rise
		# The riser: courses of squared stone, joints showing, some blocks already gone.
		for x: int in maxi(2,roundi(w/0.7)):
			var px: float = -w/2+(x+0.5)*w/maxi(2,roundi(w/0.7))
			if rng.randf() < 0.12:
				continue
			s.box(root,Vector3(px,y+rise/2,z+rng.randf_range(-0.04,0.04)),Vector3(w/maxi(2,roundi(w/0.7))-0.05,rise-0.04,depth),_pick(fresh))
		# Wedge holes along the bench's edge.
		for hole: int in maxi(3,floori(w/0.3)):
			s.box(root,Vector3(-w/2+0.15+hole*0.3,y+rise-0.02,-d/2+depth-0.18),Vector3(0.06,0.05,0.06),"4e4b43")
		# Chisel marks scored down the riser.
		for mark: int in maxi(2,floori(w/0.5)):
			s.tilted_box(root,Vector3(-w/2+0.25+mark*0.5,y+rise*0.5,-d/2+depth+0.01),Vector3(0.025,rise*0.7,0.02),"7c7b6e",Vector3(0,0,rng.randf_range(-0.25,0.25)))
	# A block split half off and left where it fell.
	s.tilted_box(root,Vector3(w*0.25,0.28,d/2+0.2),Vector3(0.9,0.5,0.6),_pick(fresh),Vector3(0,0.3,0.12))
	for chip: int in 14:
		s.shard(root,Vector3(rng.randf_range(-0.45,0.45)*w,0.06,d/2+rng.randf_range(0.0,0.45)),Vector3(0.16,0.1,0.13),_pick(fresh),chip,rng.randf()*TAU)

## 八卦古阵 (entrance.c: 洞口上方似乎刻着一副图): the eight trigrams carved round a 太极 in a
## disc cut into the rock face, the paint long faded (`height` of its centre, `radius`).
func _bagua() -> void:
	var y: float = float(data.get("height",2.6))
	if data.get("floor",false):
		# latemoon8.c: 地板上隐约看到一幅先天八卦图 — the same disc laid flat in the floor, face up.
		var disc := Node3D.new()
		disc.position.y = 0.01
		disc.rotation.x = -PI/2
		root.add_child(disc)
		if s.merged.has(root):
			s.merge(disc,s.merged[root])
		root = disc
		y = 0.0
	var r: float = float(data.get("radius",0.8))
	var stone: String = String(data.get("stone","6d6c62"))
	var paint: String = String(data.get("paint","b8a46a"))
	s.box(root,Vector3(0,y,0),Vector3(r*2.1,r*2.1,0.06),stone)
	for side: int in 8:
		var a: float = side*TAU/8.0
		var at := Vector3(cos(a)*r*0.78,y+sin(a)*r*0.78,0.05)
		var bars := Node3D.new()
		bars.position = at
		bars.rotation.z = a+PI/2
		root.add_child(bars)
		if s.merged.has(root):
			s.merge(bars,s.merged[root])
		for line: int in 3:
			# A trigram: three lines, broken (yin) or whole (yang) by the trigram's bits.
			var whole: bool = (side >> line) & 1 == 1
			var ly: float = (line-1)*0.1
			if whole:
				s.box(bars,Vector3(0,ly,0),Vector3(r*0.42,0.05,0.03),paint)
			else:
				for half: float in [-1.0,1.0]:
					s.box(bars,Vector3(half*r*0.13,ly,0),Vector3(r*0.17,0.05,0.03),paint)
	# 太极: a dark and a pale half, each with the other's eye.
	s.box(root,Vector3(-r*0.13,y,0.05),Vector3(r*0.26,r*0.5,0.03),"2e2c28")
	s.box(root,Vector3(r*0.13,y,0.05),Vector3(r*0.26,r*0.5,0.03),"d9cfb0")
	s.box(root,Vector3(-r*0.13,y+r*0.12,0.07),Vector3(0.06,0.06,0.02),"d9cfb0")
	s.box(root,Vector3(r*0.13,y-r*0.12,0.07),Vector3(0.06,0.06,0.02),"2e2c28")

## 铁门 (canyon5.c: 两片诺大的铁门, 它是上下开合的, 现在已经高高的抬起): the pass's great iron gate
## raised over the way — a leaf of rusted plates and bars, spikes along its foot, hauled up on
## chains over the piers' heads (`raised`: how high its foot hangs, `height` of the piers; `iron`
## the leaf's colours). Spans the box's width; blocks nothing. The stone piers it hangs between are
## the layout's blocked boxes with a `gate_pier` look (`piers`: draw them here as well).
func _iron_gate(w: float, d: float) -> void:
	var iron: Array = _colors("iron",["3a3633","48423d","2f2b28","5a4a3a"])
	var raised: float = float(data.get("raised",2.6))
	var height: float = float(data.get("height",5.2))
	var deep: float = maxf(d,0.8)
	if data.get("piers",false):
		for side: float in [-1.0,1.0]:
			var pier := Node3D.new()
			pier.position = Vector3(side*(w/2-0.35),0,0)
			root.add_child(pier)
			if s.merged.has(root):
				s.merge(pier,s.merged[root])
			_pier_at(pier,0.7,deep,height,_colors("posts",["8a7a5a","9a8864","7a6a4e"]),String(iron[0]),int(side))
	var span: float = w-1.4
	s.box(root,Vector3(0,height+0.3,0),Vector3(w,0.4,deep*0.9),String(iron[1]))
	# The leaf: plates riveted in rows, bars across, spikes along its foot.
	var leaf_h: float = height-raised+0.2
	var cols: int = maxi(2,ceili(span/0.6))
	for row: int in ceili(leaf_h/0.5):
		var y: float = minf(raised+row*0.5+0.25,height-0.05)
		for col: int in cols:
			var x: float = -span/2+(col+0.5)*span/cols
			s.box(root,Vector3(x,y,0),Vector3(span/cols-0.03,0.47,0.12),String(iron[(row*3+col)%iron.size()]))
			if (row+col)%2==0:
				s.box(root,Vector3(x,y,0.08),Vector3(0.06,0.06,0.04),"6a5a48")
	for bar: float in [0.3,0.55,0.8]:
		s.box(root,Vector3(0,raised+leaf_h*bar,0.1),Vector3(span,0.14,0.08),String(iron[2]))
	for spike: int in ceili(span/0.35):
		var x: float = -span/2+0.17+spike*0.35
		s.box(root,Vector3(x,raised-0.22,0),Vector3(0.08,0.44,0.08),String(iron[2]))
		s.box(root,Vector3(x,raised-0.5,0),Vector3(0.05,0.14,0.05),"7a6a58")
	# Chains from the leaf's top corners over the piers' heads.
	for side: float in [-1.0,1.0]:
		for link: int in 12:
			var t: float = float(link)/12.0
			var at := Vector3(side*(span/2-0.2+t*0.5),height-t*0.3,0.2+t*0.1)
			s.box(root,at,Vector3(0.06,0.12,0.04) if link%2 else Vector3(0.05,0.08,0.07),"4a4642")

## One of the gate's stone piers (canyon5.c: 两片诺大的铁门 hang between them): squared courses of
## stone, iron-bound, a cap, rust streaked down its face, grit at its foot (`height`, `colors` the
## stone's, `iron` the bands'). A blocked box in the layout; fills the box.
func _gate_pier(w: float, d: float) -> void:
	_pier_at(root,w,maxf(d,0.8),float(data.get("height",5.6)),_colors("colors",["8a7a5a","9a8864","7a6a4e","a89470"]),String(data.get("iron","3a3633")),int(root.position.x*3+root.position.z))

func _pier_at(into: Node3D, w: float, deep: float, height: float, stone: Array, iron: String, salt: int) -> void:
	var y: float = 0.0
	var course: int = 0
	while y < height:
		var h: float = minf(0.5,height-y)
		s.shard(into,Vector3(sin(course*1.7+salt)*0.03,y+h/2,0),Vector3(w,h,deep),String(stone[(course+salt)%stone.size()]),course+salt,0.0)
		y += h
		course += 1
	s.box(into,Vector3(0,height+0.15,0),Vector3(w+0.2,0.3,deep+0.2),String(stone[0]))
	for band: float in [1.2,2.8,4.2]:
		if band < height:
			s.box(into,Vector3(0,band,0),Vector3(w+0.08,0.12,deep+0.06),iron)
	s.box(into,Vector3(w*0.25,height*0.4,deep/2+0.01),Vector3(0.1,height*0.6,0.02),"6a4a30")
	s.shard(into,Vector3(-w*0.3,0.08,deep/2+0.3),Vector3(0.5,0.16,0.4),String(stone[1%stone.size()]),salt+5,0.3)

## 绞盘 (canyon6.c: 铁门的后面有个很大的机械装置, 这是个很大的绞盘): the windlass that raises
## the gate — a great drum on iron-bound timber uprights, bars through its axle to heave on,
## the chain wound thick on it and running off up toward the gate (`chain_to`: [dx, dz]
## units, `chain_rise` units it climbs).
func _winch(w: float, d: float) -> void:
	var wood: Array = _colors("colors",["5a4634","6a533d","4b3a2b"])
	var iron: String = String(data.get("iron","3a3633"))
	s.box(root,Vector3(0,0.1,0),Vector3(w,0.2,d),"7d7262")
	for x: float in [-w/2+0.25,w/2-0.25]:
		s.box(root,Vector3(x,0.8,0),Vector3(0.3,1.4,0.3),_pick(wood))
		s.box(root,Vector3(x,0.8,0),Vector3(0.34,0.12,0.34),iron)
	s.box(root,Vector3(0,1.3,0),Vector3(w-0.2,0.14,0.14),iron)
	var drum := Node3D.new()
	drum.position = Vector3(0,1.3,0)
	root.add_child(drum)
	if s.merged.has(root):
		s.merge(drum,s.merged[root])
	for stave: int in 10:
		var a: float = stave*TAU/10.0
		s.tilted_box(drum,Vector3(0,cos(a)*0.42,sin(a)*0.42),Vector3(w-0.9,0.16,0.28),String(wood[stave%wood.size()]),Vector3(a,0,0))
	for hoop: float in [-0.3,0.3]:
		s.box(drum,Vector3((w-0.9)*hoop,0,0),Vector3(0.1,1.0,1.0),iron)
	for wind: int in 14:
		var a: float = wind*0.9
		s.tilted_box(drum,Vector3(-0.25+wind*0.04,cos(a)*0.5,sin(a)*0.5),Vector3(0.1,0.1,0.14),"4a4642",Vector3(a,0,0))
	for bar: int in 4:
		var a: float = bar*PI/2+0.4
		s.tilted_box(drum,Vector3(w/2-0.55,cos(a)*0.6,sin(a)*0.6),Vector3(0.1,1.3,0.1),String(wood[0]),Vector3(a,0,0))
	# A pawl so the gate hangs where it is; the chain off the drum up toward the gate.
	s.box(root,Vector3(-w/2+0.25,1.75,0.3),Vector3(0.12,0.5,0.12),iron)
	var to: Array = data.get("chain_to",[-0.3,-4.0])
	var climb: float = float(data.get("chain_rise",3.6))
	for link: int in 22:
		var t: float = float(link)/22.0
		s.box(root,Vector3(float(to[0])*t,1.8+climb*t,float(to[1])*t),Vector3(0.06,0.12,0.05) if link%2 else Vector3(0.05,0.08,0.08),"4a4642")
	s.box(root,Vector3(0,0.015,d/2+0.2),Vector3(w*0.8,0.03,0.3),"5a4a3a")

## 铁索 (road.c, canyon1.c: 一长条铁索缘山壁而下, 十七、八丈): the long iron chain on the rock
## face, from a stake and ring at its top (`height` units above the prop's footing) down to
## `drop` units below it, its links flat and edge-on by turns, rusted here and there, held to
## the rock by pitons; `face` is how far (units, -z) the rock stands behind the prop.
func _iron_chain(_w: float, _d: float) -> void:
	var top: float = float(data.get("height",0.0))
	var drop: float = float(data.get("drop",0.0))
	var face: float = float(data.get("face",0.0))
	var links: int = int(data.get("links",maxi(8,ceili((top+drop)/0.22))))
	s.tilted_box(root,Vector3(0,top+0.25,face-0.1),Vector3(0.12,0.5,0.12),"4a4642",Vector3(0.3,0,0))
	s.box(root,Vector3(0,top+0.45,face),Vector3(0.26,0.08,0.26),"3a3633")
	for i: int in links:
		var t: float = float(i)/links
		var y: float = top-(top+drop)*t
		var sway: float = sin(t*9.0)*0.12*(1.0-absf(t*2-1))
		var at := Vector3(sway,y,face+0.08)
		s.box(root,at,Vector3(0.07,0.22,0.04) if i%2 else Vector3(0.05,0.2,0.09),"3f3b37" if i%5 else "6a4a30")
		if i%9==4:
			s.box(root,Vector3(sway,y,face-0.06),Vector3(0.1,0.1,0.3),"2f2b28")

## 铁栅 (canyon3.c: 军营四周为铁栅所包围; canyon5.c: 铁栅的映满你整双眼眸): the garrison's iron
## palisade — close-set bars with spiked heads, rusting, two rails through them, a stone sill,
## along the box's long side.
func _iron_palisade(w: float, d: float) -> void:
	var iron: Array = _colors("colors",["3a3835","46423e","2e2c2a"])
	var height: float = float(data.get("height",2.6))
	var long: bool = w >= d
	var length: float = maxf(w,d)
	var vary: RandomNumberGenerator = Shapes.spot_rng(root.position)
	s.box(root,Vector3(0,0.12,0),Vector3(w,0.24,d),String(data.get("sill","7d7262")))
	for i: int in maxi(2,ceili(length/0.3)):
		var along: float = -length/2+0.15+i*0.3
		var h: float = height*vary.randf_range(0.92,1.04)
		var at := Vector3(along,0,0) if long else Vector3(0,0,along)
		var tone: String = String(iron[i%iron.size()]) if vary.randf()>0.15 else "6a4a30"
		s.box(root,at+Vector3(0,0.2+h/2,0),Vector3(0.09,h,0.09),tone)
		s.box(root,at+Vector3(0,0.2+h+0.1,0),Vector3(0.05,0.2,0.05),String(iron[2]))
	for rail: float in [0.8,height-0.4]:
		s.box(root,Vector3(0,0.2+rail,0),Vector3(length,0.08,0.14) if long else Vector3(0.14,0.08,length),String(iron[1]))

## A tent's centre pole (camp3.c: 由粗略的布料所搭成的小营帐): lashed at three heights, the
## roof's cloth gathered round its head, a hook and a sword belt hung on it (`height`, `cloth`).
func _tent_pole(_w: float, _d: float) -> void:
	var height: float = float(data.get("height",3.1))
	var cloth: String = String(data.get("cloth","8a7a5c"))
	s.tilted_box(root,Vector3(0,height/2,0),Vector3(0.16,height,0.16),"6a5038",Vector3(0,0,0.02))
	s.box(root,Vector3(0,0.06,0),Vector3(0.5,0.12,0.5),"5a4a3a")
	for band: float in [0.9,2.1,height-0.35]:
		s.box(root,Vector3(0,band,0),Vector3(0.22,0.1,0.22),"a08e62")
	s.box(root,Vector3(0,height-0.1,0),Vector3(0.6,0.2,0.6),cloth)
	s.box(root,Vector3(0,height+0.1,0),Vector3(0.3,0.26,0.3),"5a4a3a")
	s.box(root,Vector3(0.14,1.7,0),Vector3(0.2,0.04,0.04),"4a4642")
	s.box(root,Vector3(0.25,1.45,0),Vector3(0.05,0.5,0.08),String(data.get("belt","5a3a28")))

## 镜子 (stone_forest3.c: 北侧奇特的镜子, 镜面反射日光, 强照黄石穿林路): a great oval mirror in a
## bronze frame on a stone foot, its face a pale glare, its light thrown on the ground before
## it and out over the path (`height`; `light`, `range`, `day`, `night`).
func _mirror(w: float, d: float) -> void:
	var height: float = float(data.get("height",3.2))
	var bronze: Array = _colors("colors",["7a5a2a","8a6a34","5e4620"])
	s.shard(root,Vector3(0,0.2,0),Vector3(w*0.6,0.4,d*1.2),"8a7a5a",3,0.1)
	s.box(root,Vector3(0,0.55,0),Vector3(0.5,0.3,0.5),String(bronze[2]))
	var rows: int = maxi(3,ceili((height-0.7)/0.3))
	for row: int in rows:
		var t: float = (row+0.5)/rows
		var half: float = w*0.46*sin(t*PI)+0.1
		var y: float = 0.7+row*0.3+0.15
		s.box(root,Vector3(0,y,0),Vector3(half*2+0.2,0.31,0.14),String(bronze[row%bronze.size()]))
		s.box(root,Vector3(0,y,0.05),Vector3(half*2,0.3,0.06),"e8f0f4:glow" if row%3 else "cfe0ea:glow")
	s.shard(root,Vector3(0,0.012,d*0.8),Vector3(w*0.9,0.02,d*1.2),"e0d8b0",5,0.0)
	var light := OmniLight3D.new()
	light.position = Vector3(0,height*0.6,1.0)
	light.light_color = Color(String(data.get("light","fff4d0")))
	light.omni_range = float(data.get("range",9.0))
	light.set_meta("day_energy",float(data.get("day",2.4)))
	light.set_meta("night_energy",float(data.get("night",0.9)))
	root.add_child(light)

## 半圆形的土堆 (road.c): a half-round mound of earth at the path's end, dry tufts on it, stones in
## its skirt, the chain's stake and ring driven into its top (`chain`).
func _mound(w: float, d: float) -> void:
	var soil: Array = _colors("colors",["9a7d52","a88a5c","8c7049"])
	var tall: float = float(data.get("height",0.9))
	for tier: int in 4:
		var t: float = float(tier)/4.0
		var span: float = 1.0-t*0.55
		s.shard(root,Vector3(0,tall*t*0.9+tall*0.12,0),Vector3(w*span,tall*0.3,d*span),String(soil[tier%soil.size()]),tier,tier*0.5)
	for i: int in 6:
		var a: float = i*1.1
		s.shard(root,Vector3(cos(a)*w*0.45,0.08,sin(a)*d*0.45),Vector3(0.22,0.14,0.18),"8a8470",i,a)
	for tuft: int in 5:
		var a: float = tuft*1.3+0.4
		s.box(root,Vector3(cos(a)*w*0.25,tall*0.75,sin(a)*d*0.25),Vector3(0.12,0.3,0.1),String(data.get("grass","9a9452")))
	if data.get("chain",false):
		s.tilted_box(root,Vector3(0,tall+0.3,-d*0.1),Vector3(0.14,0.7,0.14),"4a4642",Vector3(-0.2,0,0))
		s.box(root,Vector3(0,tall+0.62,-d*0.05),Vector3(0.3,0.08,0.3),"3a3633")

## 虎头 (camp8.c: 虎头挂于营顶): a tiger's head mounted up high — orange, black-striped, the pale
## muzzle, ears, the jaw open on its teeth, 王 on its brow; hung on a wall (`wall_mounted`,
## facing +z) or set on a tent's roof (`elevation`); `height` lifts it on its mount.
func _tiger_head(_w: float, _d: float) -> void:
	var fur: String = String(data.get("fur","c87a2a"))
	var y: float = float(data.get("height",0.0))
	s.box(root,Vector3(0,y,0),Vector3(0.7,0.6,0.55),fur)
	s.box(root,Vector3(0,y-0.08,0.3),Vector3(0.44,0.3,0.26),"efe6d8")
	s.box(root,Vector3(0,y+0.04,0.42),Vector3(0.14,0.1,0.08),"3a2a24")
	s.box(root,Vector3(0,y-0.2,0.32),Vector3(0.4,0.1,0.22),"8a2a24")
	for side: float in [-1.0,1.0]:
		s.box(root,Vector3(side*0.18,y+0.1,0.28),Vector3(0.1,0.08,0.04),"e8d060")
		s.box(root,Vector3(side*0.12,y+0.1,0.29),Vector3(0.04,0.06,0.03),"1a1410")
		s.box(root,Vector3(side*0.26,y+0.34,-0.05),Vector3(0.16,0.16,0.14),fur)
		s.box(root,Vector3(side*0.26,y+0.35,0.02),Vector3(0.08,0.08,0.03),"3a2a24")
		for tooth: int in 2:
			s.box(root,Vector3(side*(0.08+tooth*0.1),y-0.26,0.4),Vector3(0.04,0.1,0.04),"f0ead8")
	for stripe: int in 5:
		var x: float = -0.28+stripe*0.14
		s.box(root,Vector3(x,y+0.18+(stripe%2)*0.06,0.0),Vector3(0.05,0.2,0.56),"1e1812")
		s.box(root,Vector3(x,y-0.1,-0.28),Vector3(0.05,0.3,0.03),"1e1812")
	for bar: int in 3:
		s.box(root,Vector3(0,y+0.26-bar*0.06,0.29),Vector3(0.18 if bar!=1 else 0.12,0.025,0.03),"1e1812")
	s.box(root,Vector3(0,y+0.2,0.29),Vector3(0.025,0.16,0.03),"1e1812")
