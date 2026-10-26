extends RefCounted

## The water's edge (美术规划 group E): a plank jetty on piles, a ferry and fishing skiffs
## riding the swell with their lamps (渔火) at night, a stone-faced bank, mooring posts, nets
## drying on poles, steps going down into the water and the far shore across a wide river
## with its hills and their smoke. The water itself is VoxelWater; the walkable deck is the
## 2D map's own (bridge cells), so these only draw what is there.
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
		"jetty": _jetty(w,d)
		"ferry": _boat(w,d,true)
		"skiff": _boat(w,d,false)
		"bank_stones": _bank_stones()
		"mooring_post": _mooring_post()
		"fishing_net": _fishing_net(w,d)
		"water_steps": _water_steps(w,d)
		"far_shore": _far_shore(w,d)
		"koi": _koi(w,d)
		_:
			return false
	return true

func _colors(key: String, fallback: Array) -> Array:
	return data.get(key,fallback)

func _pick(colors: Array) -> String:
	return String(colors[rng.randi_range(0,colors.size()-1)])

## 锦鲤 (bridge1.c: 浮萍底下有不少艳红锦鲤穿梭来去): fish just under the surface at `level`,
## `count` of them in reds and whites, turning slowly on the swell.
func _koi(w: float, d: float) -> void:
	var tones: Array = _colors("colors",["d8402a","e8702a","f0e0d0","c83a2a"])
	var level: float = float(data.get("level",-0.14))
	for i: int in int(data.get("count",8)):
		var fish := Node3D.new()
		fish.position = Vector3(rng.randf_range(-0.45,0.45)*w,level-0.06,rng.randf_range(-0.45,0.45)*d)
		fish.rotation.y = rng.randf()*TAU
		root.add_child(fish)
		var tone: String = _pick(tones)
		s.box(fish,Vector3.ZERO,Vector3(0.1,0.06,0.3),tone)
		s.box(fish,Vector3(0,0,-0.2),Vector3(0.08,0.04,0.1),tone)
		s.box(fish,Vector3(0,0.02,0.05),Vector3(0.05,0.03,0.12),"f4ece0" if tone != "f0e0d0" else "d8402a")
		if ambience != null:
			ambience.sway(fish,i*1.7,0.12)

## 木栈: planks laid across stringers on piles driven into the riverbed; the deck at `deck`
## units (just above the ground), the piles going down to `bed`; mooring posts at the end.
func _jetty(w: float, d: float) -> void:
	var deck: float = float(data.get("deck",0.04))
	var bed: float = float(data.get("bed",-1.2))
	var planks: Array = _colors("colors",["8a6a45","7a5d3d","96754d","6f5438"])
	var along_z: bool = d>=w
	var length: float = d if along_z else w
	var span: float = w if along_z else d
	var count: int = ceili(length/0.27)
	for i: int in count:
		var t: float = -length/2+0.135+i*length/count
		var at := Vector3(0,deck-0.04,t) if along_z else Vector3(t,deck-0.04,0)
		var size := Vector3(span*rng.randf_range(0.94,1.02),0.08,length/count-0.025)
		if not along_z:
			size = Vector3(size.z,size.y,size.x)
		if rng.randf()<float(data.get("gaps",0.0)):
			continue
		s.box(root,at+Vector3(0,rng.randf_range(-0.01,0.01),0),size,_pick(planks))
	for side: float in [-1.0,1.0]:
		var rail := Vector3(side*(span/2-0.12),deck-0.14,0) if along_z else Vector3(0,deck-0.14,side*(span/2-0.12))
		s.box(root,rail,Vector3(0.14,0.14,length) if along_z else Vector3(length,0.14,0.14),"5c4433")
	var piles: int = maxi(2,ceili(length/1.4))
	for i: int in piles:
		var t: float = -length/2+0.2+i*(length-0.4)/(piles-1)
		for side: float in [-1.0,1.0]:
			var at := Vector3(side*(span/2-0.1),(deck+bed)/2,t) if along_z else Vector3(t,(deck+bed)/2,side*(span/2-0.1))
			s.box(root,at,Vector3(0.2,deck-bed,0.2),"4f3c2c")
			s.box(root,at+Vector3(0,(bed-deck)/2+0.5,0),Vector3(0.23,0.12,0.23),"3d4a3a")
	var far: float = float(data.get("end",1.0))
	for side: float in [-1.0,1.0]:
		var post := Vector3(side*(span/2-0.1),deck+0.45,far*(length/2-0.12)) if along_z else Vector3(far*(length/2-0.12),deck+0.45,side*(span/2-0.1))
		s.box(root,post,Vector3(0.18,0.9,0.18),"5c4433")
		s.box(root,post+Vector3(0,0.25,0),Vector3(0.22,0.06,0.22),"b09a6c")
	if data.get("lamp",true):
		var lamp_at := Vector3(span/2-0.1,deck+1.6,far*(length/2-0.12)) if along_z else Vector3(far*(length/2-0.12),deck+1.6,span/2-0.1)
		s.box(root,lamp_at-Vector3(0,0.55,0),Vector3(0.1,1.1,0.1),"5c4433")
		s.lantern(root,lamp_at+Vector3(0,0.2,0),false,String(data.get("lantern","ffb858")))
		for light: Node in root.get_children():
			if light is OmniLight3D:
				light.set_meta("day_energy",0.4)
				light.set_meta("night_energy",2.2)
				(light as OmniLight3D).omni_range = 5.0
				light.set_meta("flicker",0.1)

## A boat on the water along its long axis (+z its bow): a hull of planks with a raised stern,
## thwarts and, on a `ferry`, a woven bamboo canopy (船篷) amidships and a long pole; a skiff
## carries a net and a lamp at its stern that is lit at night (渔火). Rides the swell.
func _boat(w: float, d: float, ferry: bool) -> void:
	var hull := Node3D.new()
	root.add_child(hull)
	hull.position.y = float(data.get("float",-0.12))
	var long_z: bool = d>=w
	if not long_z:
		hull.rotation.y = PI/2
	var length: float = maxf(w,d)
	var beam: float = minf(w,d)
	var wood: Array = _colors("colors",["5b4433","6a5039","4f3a2b"])
	var segments: int = maxi(4,ceili(length/0.4))
	for i: int in segments:
		var t: float = (float(i)+0.5)/segments
		var z: float = -length/2+t*length
		var taper: float = 1.0-pow(absf(t-0.5)*2.0,2.2)*0.75
		var rise: float = pow(absf(t-0.5)*2.0,3.0)*0.45
		s.box(hull,Vector3(0,0.05+rise*0.5,z),Vector3(beam*taper*0.8,0.18,length/segments+0.02),String(wood[2]))
		for side: float in [-1.0,1.0]:
			s.box(hull,Vector3(side*beam*taper*0.44,0.3+rise,z),Vector3(0.08,0.42,length/segments+0.02),String(wood[i%2]))
		if i%3==1 and t>0.15 and t<0.85:
			s.box(hull,Vector3(0,0.38,z),Vector3(beam*taper*0.82,0.06,0.16),"8a6a45")
	if ferry:
		var canopy: Array = _colors("canopy",["6e5a3a","7d6a45","5f4f34"])
		var span: float = length*0.36
		for i: int in 7:
			var a: float = -PI/2+i*PI/6
			s.box(hull,Vector3(sin(a)*beam*0.42,0.55+cos(a)*0.75,0),Vector3(0.22,0.1,span),String(canopy[i%canopy.size()]))
		for z: float in [-span/2,span/2]:
			s.box(hull,Vector3(0,0.9,z),Vector3(beam*0.82,0.06,0.06),"4f3a2b")
		s.tilted_box(hull,Vector3(beam*0.3,1.4,-length*0.32),Vector3(0.06,3.2,0.06),"8a7044",Vector3(-0.35,0,0.2))
		s.box(hull,Vector3(0,0.46,length*0.32),Vector3(beam*0.5,0.12,0.5),String(data.get("mat","b39a5c")))
	else:
		s.box(hull,Vector3(-beam*0.1,0.42,length*0.2),Vector3(beam*0.4,0.1,length*0.25),String(data.get("net","8e8a6c")))
		s.tilted_box(hull,Vector3(beam*0.2,0.5,-length*0.1),Vector3(0.05,0.05,length*0.7),"8a7044",Vector3(0.1,0,0))
	if data.get("lamp",true):
		var stern := Vector3(0,0.55,-length*0.42)
		s.box(hull,stern+Vector3(0,0.35,0),Vector3(0.06,0.7,0.06),"4f3a2b")
		var housing := Node3D.new()
		housing.set_meta("light_fixture",true)
		housing.position = stern+Vector3(0,0.82,0.12)
		hull.add_child(housing)
		s.box(housing,Vector3.ZERO,Vector3(0.24,0.3,0.24),String(data.get("lantern","ffb858")))
		s.box(housing,Vector3(0,0.18,0),Vector3(0.28,0.05,0.28),"3d3530")
		var lamp := OmniLight3D.new()
		lamp.position = housing.position
		lamp.light_color = Color("ffbd72")
		lamp.omni_range = float(data.get("reach",4.5))
		lamp.set_meta("day_energy",0.0)
		lamp.set_meta("night_energy",float(data.get("night",2.0)))
		lamp.set_meta("flicker",0.12)
		hull.add_child(lamp)
	if ambience != null:
		ambience.bob(hull,root.position.x*0.7+root.position.z*0.3,float(data.get("swell",0.07)),float(data.get("roll",0.05)))

## 驳岸: dressed stone blocks along a bank, stepped and weed-stained near the water.
## `points`: the bank's line in px; `height` of the face above the water (units).
func _bank_stones() -> void:
	var points: Array = data.get("points",[])
	var stone: Array = _colors("colors",["7c7f76","8a8d82","6f7269","969888"])
	var height: float = float(data.get("height",0.5))
	for i: int in points.size()-1:
		var a := Vector3(float(points[i][0])/32.0,0,float(points[i][1])/32.0)-root.position
		var b := Vector3(float(points[i+1][0])/32.0,0,float(points[i+1][1])/32.0)-root.position
		var length: float = a.distance_to(b)
		var yaw: float = atan2(b.x-a.x,b.z-a.z)
		var count: int = maxi(1,ceili(length/0.5))
		for j: int in count:
			var at: Vector3 = a.lerp(b,(j+0.5)/count)
			for course: int in 2:
				s.shard(root,at+Vector3(0,-course*height*0.5-height*0.25+0.04,0),Vector3(0.55,height*0.5,0.4),_pick(stone),j+course*3,yaw+PI/2+rng.randf_range(-0.08,0.08))
			if rng.randf()<0.4:
				s.box(root,at+Vector3(0,-height+0.06,0),Vector3(0.5,0.08,0.42),String(data.get("weed","3f5a3a")))

## 系船桩: a squat stone post with a rope round it.
func _mooring_post() -> void:
	s.box(root,Vector3(0,0.3,0),Vector3(0.32,0.6,0.32),String(data.get("stone","8a8a7e")))
	s.box(root,Vector3(0,0.64,0),Vector3(0.38,0.1,0.38),"9a998c")
	s.box(root,Vector3(0,0.4,0),Vector3(0.36,0.06,0.36),"b09a6c")
	if data.get("rope",true):
		s.tilted_box(root,Vector3(0,0.3,0.55),Vector3(0.04,0.04,1.0),"b09a6c",Vector3(0.35,0,0))

## 晒网: a fishing net hung to dry on poles, sagging between them, floats along its top.
func _fishing_net(w: float, d: float) -> void:
	var along_x: bool = w>=d
	var length: float = maxf(w,d)
	var height: float = float(data.get("height",1.9))
	for t: float in [-length/2+0.1,0.0,length/2-0.1]:
		s.box(root,Vector3(t,height/2,0) if along_x else Vector3(0,height/2,t),Vector3(0.09,height,0.09),"6a5038")
	var net := Node3D.new()
	root.add_child(net)
	var cells: int = ceili(length/0.16)
	for i: int in cells:
		var t: float = -length/2+0.08+i*0.16
		var sag: float = sin(fposmod(t+length/2,length/2)/(length/2)*PI)*0.25
		var drop: float = height*0.75-sag
		s.box(net,Vector3(t,height-0.1-drop/2-sag,0) if along_x else Vector3(0,height-0.1-drop/2-sag,t),Vector3(0.02,drop,0.02),String(data.get("net","8e8a6c")))
		if i%4==0:
			s.box(net,Vector3(t,height-0.12-sag,0) if along_x else Vector3(0,height-0.12-sag,t),Vector3(0.1,0.08,0.1),"c9452f")
	for row: int in 5:
		var y: float = height-0.3-row*height*0.15
		s.box(net,Vector3(0,y,0),Vector3(length,0.015,0.015) if along_x else Vector3(0.015,0.015,length),String(data.get("net","8e8a6c")))
	if ambience != null:
		ambience.sway(net,root.position.x,0.03)

## 石阶: stone steps going down from the bank into the water (toward +z), the lowest awash.
func _water_steps(w: float, d: float) -> void:
	var stone: Array = _colors("colors",["8a8d82","7c7f76","969888"])
	var steps: int = int(data.get("count",4))
	for i: int in steps:
		var z: float = -d/2+(i+0.5)*d/steps
		s.box(root,Vector3(0,-0.1-i*0.14,z),Vector3(w,0.2+i*0.0,d/steps+0.02),String(stone[i%stone.size()]))
		s.box(root,Vector3(0,-0.005-i*0.14,z-d/steps*0.45),Vector3(w,0.02,0.05),"a3a597")

## The far shore across a wide river: a low bank with reeds, then a mountain rising behind
## (`peaks`: [[x, height, radius], ...] units across the box), its summit's smoke (`smoke`:
## [x, height]) curling up (日照山的袅袅炊烟). The view looks north, so the far (south) shore is
## nearest the camera: it is drawn in mist (`haze`, a colour seen through), 隐约可见.
func _far_shore(w: float, d: float) -> void:
	var mist: String = ":haze" if data.get("haze",true) else ""
	var bank: Array = _colors("bank",["6b6a50","76734f","5f6046"])
	var slopes: Array = _colors("colors",["8fa3a8","9aaeb2","a5b8bb","8598a0"])
	var rock: Array = _colors("rock",["a8b4b4","b2bdbc","9eabac"])
	s.box(root,Vector3(0,-0.1,-d/2+0.6),Vector3(w,0.3,1.2),String(bank[0]))
	for i: int in ceili(w/0.9):
		var x: float = -w/2+0.45+i*0.9
		s.box(root,Vector3(x,0.18,-d/2+0.4),Vector3(0.12,0.36+rng.randf()*0.3,0.12),_pick(["7f8a4a","8f9a5a","6f7a40"]))
	var peaks: Array = data.get("peaks",[[0.0,8.0,6.0]])
	for index: int in peaks.size():
		var peak: Array = peaks[index]
		var px: float = float(peak[0])
		var top: float = float(peak[1])
		var radius: float = float(peak[2])
		var tiers: int = ceili(top/0.8)
		for tier: int in tiers:
			var t: float = float(tier)/tiers
			var r: float = radius*(1.0-t*0.85)
			var y: float = tier*0.8
			for slab: int in 3:
				var off: float = (slab-1)*r*0.35
				s.box(root,Vector3(px+off*0.6,y+0.4,d*0.15+off*0.2),Vector3(r*(1.5-absf(slab-1)*0.5),0.8,r*(0.9-absf(slab-1)*0.25)),(_pick(slopes) if t<0.75 else _pick(rock))+mist)
		# A hall on the summit (`temple`: the index of its peak), seen small across the water.
		if int(data.get("temple",-1))==index:
			s.box(root,Vector3(px,top+0.5,d*0.15),Vector3(1.4,1.0,1.0),"c9c0a8"+mist)
			s.box(root,Vector3(px,top+1.15,d*0.15),Vector3(1.9,0.3,1.4),"7a7f86"+mist)
	var trees: int = int(data.get("trees",30))
	for i: int in trees:
		var x: float = rng.randf_range(-0.48,0.48)*w
		var z: float = rng.randf_range(-0.4,-0.1)*d
		var size: float = rng.randf_range(0.5,1.0)
		s.box(root,Vector3(x,size*0.6,z),Vector3(size*1.2,size*1.1,size),_pick(["7f9690","889e96","92a69c"])+mist)
	if data.has("smoke") and ambience != null:
		var at: Array = data["smoke"]
		ambience.smoke(root,Vector3(float(at[0]),float(at[1]),d*0.15),String(data.get("smoke_color","c9c8c0")),7,0.5)
