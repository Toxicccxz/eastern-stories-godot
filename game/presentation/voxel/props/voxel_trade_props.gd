extends RefCounted

## Furnishings for shops, workshops and public halls. Positions and blocking boxes
## come from Furnishings; these reusable forms contain no region or gameplay logic.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var s: Shapes
var root: Node3D
var rng: RandomNumberGenerator
var ambience: VoxelAmbience

func draw(shapes: Shapes, parent: Node3D, data: Dictionary, w: float, d: float) -> bool:
	s = shapes
	root = parent
	var wood: String = String(data.get("wood","806044"))
	var cloth: String = String(data.get("cloth","728478"))
	match String(data["kind"]):
		"shop_counter":
			s.box(root,Vector3(0,0.57,0),Vector3(w,1.14,d),wood)
			s.box(root,Vector3(0,1.18,0),Vector3(w+0.06,0.13,d+0.06),"ad875c")
			for i: int in maxi(1,floori(w/0.8)):
				s.box(root,Vector3(-w/2+0.40+i*0.8,0.58,d/2+0.014),Vector3(0.62,0.77,0.028),"654a36")
			# Ledger, abacus, sign and a working surface suited to the business.
			_book(Vector3(-w*0.25,1.30,0),cloth)
			s.box(root,Vector3(w*0.25,1.30,0),Vector3(0.75,0.06,d*0.70),"4b4031")
			for i: int in 7:
				for j: int in 2:
					s.box(root,Vector3(w*0.25-0.29+i*0.095,1.35,(j-0.5)*0.12),Vector3(0.055,0.055,0.07),"b79c66")
			var goods: String = String(data.get("goods","coins"))
			for i: int in 3:
				var p := Vector3(-0.38+i*0.35,1.27,0)
				if goods=="herbs":
					s.box(root,p+Vector3(0,0.06,0),Vector3(0.28,0.12,0.32),"cbbb8f")
					s.box(root,p+Vector3(0,0.13,0),Vector3(0.18,0.04,0.21),"738256")
				elif goods=="tea":
					s.box(root,p+Vector3(0,0.12,0),Vector3(0.18,0.24,0.18),["5d7f78","8b5440","3f5a52"][i])
					s.box(root,p+Vector3(0,0.26,0),Vector3(0.1,0.04,0.1),"3d3530")
				elif goods=="books":
					s.box(root,p+Vector3(0,0.05+i*0.03,0),Vector3(0.3,0.1+i*0.06,0.22),["4e6967","ad8055","c9b98e"][i])
				elif goods=="meat":
					s.box(root,p+Vector3(0,0.06,0),Vector3(0.3,0.1,0.24),["9e3a32","b5473b","c4655a"][i])
					s.box(root,p+Vector3(0.05,0.12,0),Vector3(0.1,0.03,0.2),"e6d6c2")
				elif goods=="cloth":
					s.box(root,p+Vector3(0,0.05+i*0.02,0),Vector3(0.3,0.1,0.36),["4a6f8f","b4473a","d6b862"][i])
				elif goods=="blades":
					s.box(root,p+Vector3(0,0.03,0),Vector3(0.08,0.04,0.55),"b9c2bf")
					s.box(root,p+Vector3(0,0.04,-0.32),Vector3(0.14,0.06,0.1),"5b4433")
				elif goods=="mail":
					s.box(root,p+Vector3(0,0.04,0),Vector3(0.29,0.08,0.36),"d6c79d")
					s.box(root,p+Vector3(0,0.09,0),Vector3(0.07,0.02,0.08),"a15339")
				else:
					s.box(root,p+Vector3(0,0.04+i*0.025,0),Vector3(0.22,0.08+i*0.05,0.22),"ba9b53" if goods=="coins" else "aea99b")
		"strongbox":
			s.box(root,Vector3(0,0.47,0),Vector3(w,0.90,d),"625a4b")
			s.box(root,Vector3(0,0.96,0),Vector3(w+0.03,0.10,d+0.03),"897b5b")
			for x: float in [-w*0.34,w*0.34]:
				s.box(root,Vector3(x,0.49,d/2+0.015),Vector3(0.09,0.89,0.03),"3e4542")
				s.box(root,Vector3(x,1.02,0),Vector3(0.09,0.02,d),"414941")
			s.box(root,Vector3(0,0.66,d/2+0.035),Vector3(0.22,0.28,0.07),"c1a158")
			s.box(root,Vector3(0,0.64,d/2+0.073),Vector3(0.04,0.09,0.012),"4d4435")
		"herb_cabinet":
			s.box(root,Vector3(0,1.65,0),Vector3(w,3.3,d),"573d32")
			var cols: int = maxi(3,floori(w/0.34))
			for y: int in 12:
				for x: int in cols:
					var p := Vector3(-w/2+(x+0.5)*w/cols,0.22+y*0.25,d/2+0.025)
					s.box(root,p,Vector3(w/cols-0.035,0.215,0.05),["82573f","906348","774d38"][(x+y*3)%3])
					s.box(root,p+Vector3(0,0,0.04),Vector3(0.07,0.035,0.04),"b29b64")
			s.box(root,Vector3(0,3.34,0),Vector3(w+0.10,0.13,d+0.10),"936a49")
		"bookcase", "empty_shelf", "weapon_rack":
			var kind: String = String(data["kind"])
			var height: float = 2.35 if kind=="weapon_rack" else 2.8
			for x: float in [-w/2+0.07,w/2-0.07]:
				s.box(root,Vector3(x,height/2,0),Vector3(0.14,height,d),wood)
			for y: float in [0.18,height*0.49,height]:
				s.box(root,Vector3(0,y,0),Vector3(w,0.12,d),"9b7851")
			if kind=="bookcase":
				for row: int in 2:
					for col: int in maxi(2,floori(w/0.28)):
						var p := Vector3(-w/2+0.21+col*0.28,0.27+row*height*0.49,0)
						s.box(root,p+Vector3(0,0.34,0),Vector3(0.18,0.67-0.07*(col%3),d*0.82),["698079","ab8a5c","65738a","b7ac83"][col%4])
						s.box(root,p+Vector3(0,0.39,d*0.42),Vector3(0.13,0.05,0.012),"d0c1a2")
			elif kind=="weapon_rack":
				for i: int in maxi(2,floori(w/0.38)):
					var p := Vector3(-w/2+0.22+i*0.38,0,0)
					s.box(root,p+Vector3(0,1.15,0),Vector3(0.055,2.2,0.055),"92704c")
					s.box(root,p+Vector3(0,2.2,0),Vector3(0.14,0.42,0.055),"bcc3b7")
					if i%3==1:
						s.box(root,p+Vector3(0.08,2.14,0),Vector3(0.25,0.25,0.07),"899a9b")
		"forge":
			s.box(root,Vector3(0,0.28,0),Vector3(w,0.55,d),"555b54")
			for x: float in [-w*0.38,w*0.38]:
				s.box(root,Vector3(x,1.0,-d*0.12),Vector3(w*0.24,1.0,d*0.75),"746c5b")
			s.box(root,Vector3(0,1.0,-d*0.39),Vector3(w,1.0,d*0.22),"5e5e53")
			s.box(root,Vector3(0,1.62,-d*0.17),Vector3(w*0.9,0.22,d*0.6),"767263")
			s.box(root,Vector3(0,2.2,-d*0.30),Vector3(w*0.37,1.0,d*0.34),"686758")
			for i: int in 5:
				s.box(root,Vector3((i-2)*w*0.105,0.68+(i%2)*0.07,d*0.12),Vector3(w*0.105,0.2+(i%2)*0.14,d*0.32),"ffb858")
			_lamp(Vector3(0,1.0,d*0.39),"ff984c",1.4,2.2,8)
		"anvil":
			s.box(root,Vector3(0,0.37,0),Vector3(w*0.72,0.74,d*0.75),"64503a")
			s.box(root,Vector3(0,0.84,0),Vector3(w*0.64,0.20,d*0.65),"424b4c")
			s.box(root,Vector3(0,1.05,0),Vector3(w*0.36,0.32,d*0.45),"667274")
			s.box(root,Vector3(0,1.26,0),Vector3(w*0.85,0.18,d*0.66),"9da9a4")
			s.box(root,Vector3(w*0.46,1.26,0),Vector3(w*0.23,0.11,d*0.25),"889696")
			s.tilted_box(root,Vector3(-w*0.1,1.40,0.04),Vector3(0.10,0.10,0.70),"ad8856",Vector3(0,0.30,0))
			s.box(root,Vector3(-w*0.05,1.44,-0.22),Vector3(0.33,0.22,0.19),"4e5b5c")
		"tool_rack":
			s.box(root,Vector3(0,0.10,0),Vector3(w,0.20,d),wood)
			for i: int in maxi(2,floori(w/0.45)):
				var x: float = -w/2+0.25+i*0.45
				s.tilted_box(root,Vector3(x,0.78,0),Vector3(0.065,1.40,0.065),"b29462",Vector3(0,0,0.06))
				s.box(root,Vector3(x,1.42,0),Vector3(0.27,0.30 if i%2==0 else 0.14,0.09),"839596")
		"grain_sacks":
			var cols: int = maxi(1,floori(w/0.70))
			for i: int in cols:
				var p := Vector3(-w/2+(i+0.5)*w/cols,0,0)
				s.box(root,p+Vector3(0,0.38,0),Vector3(w/cols*0.85,0.72,d*0.80),cloth)
				s.box(root,p+Vector3(0,0.78,0),Vector3(w/cols*0.63,0.11,d*0.63),"c4af79")
				s.box(root,p+Vector3(0,0.87,0),Vector3(0.18,0.10,0.17),"79684a")
				if i%2==0:
					s.box(root,p+Vector3(0,0.40,d*0.405),Vector3(0.035,0.58,0.012),"907b54")
		"millstone":
			_disk(Vector3(0,0.22,0),minf(w,d)*0.48,0.44,"827e66")
			_disk(Vector3(0,0.60,0),minf(w,d)*0.39,0.28,"aaa78a")
			_disk(Vector3(0,0.83,0),minf(w,d)*0.36,0.17,"b9b599")
			s.box(root,Vector3(0,1.07,0),Vector3(0.15,0.38,0.15),"6c5438")
			s.box(root,Vector3(w*0.20,1.21,0),Vector3(w*0.52,0.13,0.13),"a18251")
			s.box(root,Vector3(w*0.43,1.40,0),Vector3(0.10,0.45,0.10),"705635")
			for i: int in 8:
				var a: float = i*TAU/8
				s.box(root,Vector3(cos(a)*w*0.21,0.925,sin(a)*d*0.21),Vector3(0.10,0.02,0.08),"777961")
		"chair":
			s.box(root,Vector3(0,0.63,0),Vector3(w*0.90,0.16,d*0.88),wood)
			for x: float in [-w*0.36,w*0.36]:
				for z: float in [-d*0.34,d*0.34]:
					s.box(root,Vector3(x,0.30,z),Vector3(0.11,0.60,0.11),wood)
				s.box(root,Vector3(x,0.95,0),Vector3(0.10,0.10,d*0.84),"aa855b")
				s.box(root,Vector3(x,0.80,d*0.28),Vector3(0.09,0.32,0.09),wood)
			s.box(root,Vector3(0,1.22,-d*0.34),Vector3(w*0.85,1.10,0.13),wood)
			s.box(root,Vector3(0,1.27,-d*0.25),Vector3(w*0.54,0.66,0.05),"a58355")
			s.box(root,Vector3(0,0.73,0),Vector3(w*0.69,0.06,d*0.64),cloth)
		"stone_pillar":
			s.box(root,Vector3(0,0.18,0),Vector3(w,0.36,d),"88958a")
			s.box(root,Vector3(0,1.75,0),Vector3(w*0.64,2.8,d*0.64),"acb3a0")
			s.box(root,Vector3(0,3.20,0),Vector3(w*0.88,0.18,d*0.88),"8f9f92")
			for i: int in 8:
				s.box(root,Vector3(-0.12+(i%2)*0.20,2.75-floori(i/2.0)*0.36,d*0.325),Vector3(0.08,0.17,0.018),"697a73")
		"altar":
			s.box(root,Vector3(0,0.59,0),Vector3(w,1.18,d),"4b372e")
			s.box(root,Vector3(0,1.23,0),Vector3(w+0.08,0.15,d+0.08),"806344")
			s.box(root,Vector3(0,1.65,-d*0.13),Vector3(1.25,0.64,0.8),"8f6545")
			s.box(root,Vector3(0,2.20,-d*0.13),Vector3(0.85,0.85,0.64),"9d7449")
			s.box(root,Vector3(0,2.90,-d*0.13),Vector3(0.55,0.52,0.47),"b06345")
			s.box(root,Vector3(0,3.21,-d*0.13),Vector3(0.69,0.20,0.56),"403d34")
			for x: float in [-0.13,0.13]:
				s.box(root,Vector3(x,2.98,-d*0.13+0.245),Vector3(0.08,0.055,0.022),"352c26")
			s.box(root,Vector3(0,2.74,-d*0.13+0.25),Vector3(0.28,0.25,0.05),"42382b")
			for x: float in [-w*0.35,w*0.35]:
				s.box(root,Vector3(x,1.51,0.08),Vector3(0.15,0.48,0.15),"a85f3c")
				s.box(root,Vector3(x,1.80,0.08),Vector3(0.075,0.13,0.075),"ffd88a")
			_lamp(Vector3(0,2.3,d*0.68),"ffc27d",0.6,1.1,6.0)
		"flower_bed":
			var flowers: Array = data.get("flowers",["d5b86b","d3b5a6","bd8194","e3d6ab"])
			s.box(root,Vector3(0,0.10,0),Vector3(w,0.20,d),"7b7459")
			s.box(root,Vector3(0,0.22,0),Vector3(w-0.14,0.07,d-0.14),"625b40")
			for i: int in maxi(4,floori(w*d*9)):
				var p := Vector3(sin(i*12.31)*w*0.40,0.32,cos(i*7.71)*d*0.38)
				var h: float = 0.22+(i%4)*0.09
				s.box(root,p+Vector3(0,h/2,0),Vector3(0.045,h,0.045),"658058")
				s.box(root,p+Vector3(0.07,h*0.5,0),Vector3(0.19,0.065,0.14),"80955a")
				s.box(root,p+Vector3(0,h,0),Vector3(0.15,0.08,0.15),String(flowers[i%flowers.size()]))
		"meat_rack": _meat_rack(w,d,data)
		"chopping_block": _chopping_block(w,data)
		"ox_head": _ox_head(data)
		"coffin": _coffin(w,d,data)
		"cloth_shelf": _cloth_shelf(w,d,data)
		"cutting_table": _cutting_table(w,d,data)
		"gaming_table": _gaming_table(w,d,data)
		"sundry_shelf": _sundry_shelf(w,d,data)
		"herb_mortar": _herb_mortar(w,data)
		"armor_stand": _armor_stand(data)
		"tea_shelf": _tea_shelf(w,d,data)
		"steelyard": _steelyard(data)
		"cauldron": _cauldron(w,data)
		"training_post": _training_post(data)
		"stone_weights": _stone_weights()
		_:
			return false
	return true

func _book(at: Vector3, tone: String) -> void:
	s.box(root,at,Vector3(0.65,0.10,0.42),tone)
	s.box(root,at+Vector3(0.02,0,0.015),Vector3(0.61,0.055,0.41),"e0d2ae")

func _disk(at: Vector3, r: float, h: float, tone: String) -> void:
	var step: float = r/5
	for row: int in 10:
		var z: float = (row-4.5)*step
		var half: float = floorf(sqrt(maxf(0,r*r-z*z))/step)*step
		s.box(root,at+Vector3(0,0,z),Vector3(half*2,h,step-0.002),tone)

func _lamp(at: Vector3, tone: String, day: float, night: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color(tone)
	light.light_energy = day
	light.omni_range = reach
	light.set_meta("day_energy",day)
	light.set_meta("night_energy",night)
	root.add_child(light)

func _pick(colors: Array) -> String:
	return String(colors[rng.randi_range(0,colors.size()-1)])

## 肉架: a beam on posts hung with hooks of raw meat, red and running (肉架上挂满了血淋淋的
## 生肉), drips on the boards beneath.
func _meat_rack(w: float, d: float, data: Dictionary) -> void:
	var wood: String = String(data.get("wood","5a4130"))
	var height: float = float(data.get("height",2.3))
	var along_x: bool = w>=d
	var length: float = maxf(w,d)
	for t: float in [-length/2+0.08,length/2-0.08]:
		s.box(root,Vector3(t,height/2,0) if along_x else Vector3(0,height/2,t),Vector3(0.14,height,0.14),wood)
	s.box(root,Vector3(0,height,0),Vector3(length,0.12,0.12) if along_x else Vector3(0.12,0.12,length),wood)
	var meat: Array = data.get("colors",["9e3a32","b5473b","8a2f2a","c4655a"])
	var count: int = maxi(2,floori(length/0.32))
	for i: int in count:
		var t: float = -length/2+0.25+i*(length-0.5)/maxf(1,count-1)
		var hang := Vector3(t,height-0.08,0) if along_x else Vector3(0,height-0.08,t)
		var drop: float = rng.randf_range(0.55,1.0)
		s.box(root,hang-Vector3(0,0.08,0),Vector3(0.02,0.16,0.02),"8a8d82")
		var piece := Node3D.new()
		piece.position = hang-Vector3(0,0.16,0)
		root.add_child(piece)
		s.box(piece,Vector3(0,-drop/2,0),Vector3(rng.randf_range(0.18,0.3),drop,rng.randf_range(0.12,0.2)),_pick(meat))
		s.box(piece,Vector3(0.04,-drop*0.4,0.06),Vector3(0.1,drop*0.5,0.03),"e6d6c2")
		if i%3==0:
			s.box(root,Vector3(hang.x,0.01,hang.z),Vector3(0.16,0.012,0.12),"6e2622")
		if ambience != null:
			ambience.sway(piece,t*1.3,0.03)

## 砧板: a thick round block on a stump, a cleaver bitten into it, a joint beside it.
func _chopping_block(w: float, data: Dictionary) -> void:
	s.box(root,Vector3(0,0.4,0),Vector3(w*0.62,0.8,w*0.62),"6b5039")
	s.box(root,Vector3(0,0.84,0),Vector3(w*0.72,0.1,w*0.72),"b49b72")
	s.box(root,Vector3(0,0.9,0),Vector3(w*0.62,0.02,w*0.62),"8a3530")
	s.tilted_box(root,Vector3(0.05,1.02,0),Vector3(0.36,0.2,0.03),"aab3b0",Vector3(0,0.4,0.2))
	s.tilted_box(root,Vector3(-0.15,1.14,0.1),Vector3(0.05,0.05,0.26),"5a4130",Vector3(0,0.4,0))
	s.box(root,Vector3(-w*0.2,0.95,-w*0.15),Vector3(0.3,0.12,0.22),String(data.get("meat","b5473b")))

## 牛头: an ox's head hung up as the shop's sign (西首铺子外挂着个牛头), horns and all.
func _ox_head(data: Dictionary) -> void:
	var y: float = float(data.get("height",2.4))
	s.box(root,Vector3(0,y,0),Vector3(0.2,0.2,0.2),"5a4130")
	s.box(root,Vector3(0,y-0.3,0.12),Vector3(0.56,0.55,0.5),String(data.get("hide","6b4a33")))
	s.box(root,Vector3(0,y-0.58,0.36),Vector3(0.4,0.3,0.32),String(data.get("hide","6b4a33")))
	s.box(root,Vector3(0,y-0.66,0.53),Vector3(0.32,0.16,0.04),"3a2a22")
	for side: float in [-1.0,1.0]:
		s.box(root,Vector3(side*0.18,y-0.24,0.38),Vector3(0.08,0.06,0.02),"1e1a18")
		s.tilted_box(root,Vector3(side*0.42,y-0.04,0.12),Vector3(0.36,0.09,0.09),"d8ccaa",Vector3(0,0,side*-0.6))
		s.tilted_box(root,Vector3(side*0.62,y+0.14,0.12),Vector3(0.18,0.07,0.07),"b8ab88",Vector3(0,0,side*-1.2))
		s.box(root,Vector3(side*0.34,y-0.26,0.08),Vector3(0.12,0.18,0.08),String(data.get("hide","6b4a33")))
	s.box(root,Vector3(0,y-0.7,0.3),Vector3(0.12,0.12,0.04),"8a2f2a")
	if ambience != null:
		ambience.sway(root,root.position.x,0.02)

## 棺材: a coffin on two trestles, thick-ended and lacquered; `open` slides its lid aside.
func _coffin(w: float, d: float, data: Dictionary) -> void:
	var lacquer: String = String(data.get("lacquer","2c2420"))
	var along_x: bool = w>=d
	var length: float = maxf(w,d)
	var span: float = minf(w,d)
	var body := Node3D.new()
	root.add_child(body)
	if not along_x:
		body.rotation.y = PI/2
	for x: float in [-length*0.32,length*0.32]:
		s.box(body,Vector3(x,0.22,0),Vector3(0.12,0.44,span*0.95),"5a4130")
	for i: int in 6:
		var t: float = (i+0.5)/6.0
		var x: float = -length/2+t*length
		var swell: float = lerpf(0.75,1.0,t)
		s.box(body,Vector3(x,0.44+0.3*swell,0),Vector3(length/6+0.01,0.6*swell,span*0.8*swell),lacquer)
	s.box(body,Vector3(length/2-0.02,0.76,0),Vector3(0.04,0.46,span*0.62),String(data.get("end","8a2f2a")))
	s.box(body,Vector3(length/2+0.005,0.76,0),Vector3(0.02,0.18,0.18),"c9a35e")
	if data.get("open",false):
		s.box(body,Vector3(0,1.07,0),Vector3(length*0.9,0.02,span*0.62),"14110f")
		s.tilted_box(body,Vector3(length*0.15,1.12,span*0.35),Vector3(length*0.95,0.1,span*0.75),lacquer,Vector3(0,0.15,0.08))
	else:
		s.box(body,Vector3(0,1.1,0),Vector3(length+0.04,0.1,span*0.85),lacquer)

## 布架: pigeonholes of folded bolts, every colour a cloth shop sells, one bolt unrolled down the front.
func _cloth_shelf(w: float, d: float, data: Dictionary) -> void:
	var wood: String = String(data.get("wood","6a4a34"))
	var height: float = float(data.get("height",2.6))
	s.box(root,Vector3(0,height/2,-d*0.42),Vector3(w,height,0.08),wood)
	var cols: int = maxi(2,floori(w/0.5))
	var rows: int = 4
	for x: int in cols+1:
		s.box(root,Vector3(-w/2+x*w/cols,height/2,0),Vector3(0.07,height,d),wood)
	for y: int in rows+1:
		s.box(root,Vector3(0,0.1+y*(height-0.2)/rows,0),Vector3(w,0.07,d),wood)
	var cloth: Array = data.get("colors",["4a6f8f","b4473a","d6b862","5d8160","a77ba0","e8e0cc","3d4a5c","c98a4a","7a3a4a"])
	for x: int in cols:
		for y: int in rows:
			var at := Vector3(-w/2+(x+0.5)*w/cols,0.14+y*(height-0.2)/rows,0)
			var hex: String = String(cloth[(x*3+y*5)%cloth.size()])
			for fold: int in 3:
				s.box(root,at+Vector3(0,0.06+fold*0.12,0.02),Vector3(w/cols-0.14,0.11,d*0.78),hex)
			s.box(root,at+Vector3(0,0.17,d*0.4),Vector3(w/cols-0.18,0.01,0.01),Color(hex).darkened(0.25).to_html(false))
	s.box(root,Vector3(-w*0.2,height+0.07,0),Vector3(w*0.25,0.08,d*0.7),String(cloth[1]))
	s.tilted_box(root,Vector3(-w*0.2,height-0.25,d*0.42),Vector3(w*0.22,0.6,0.02),String(cloth[1]),Vector3(0.05,0,0))

## 裁衣案: a long cutting table, a length of cloth spread on it, the ruler, shears, chalk and a
## pincushion; a finished robe folded at its end.
func _cutting_table(w: float, d: float, data: Dictionary) -> void:
	_cutting_top(w,d)
	s.box(root,Vector3(-w*0.1,0.92,0),Vector3(w*0.7,0.015,d*0.8),String(data.get("cloth","4a6f8f")))
	s.box(root,Vector3(-w*0.1,0.94,-d*0.3),Vector3(w*0.6,0.02,0.06),"c9a96a")
	s.tilted_box(root,Vector3(w*0.2,0.95,0.1),Vector3(0.22,0.02,0.06),"8a8d82",Vector3(0,0.5,0))
	s.tilted_box(root,Vector3(w*0.2,0.95,0.16),Vector3(0.22,0.02,0.06),"8a8d82",Vector3(0,-0.5,0))
	s.box(root,Vector3(w*0.38,0.98,-d*0.2),Vector3(0.14,0.1,0.14),"b8412f")
	s.box(root,Vector3(w*0.38,0.98,d*0.2),Vector3(0.36,0.14,0.3),String(data.get("robe","8a3a3a")))

func _cutting_top(w: float, d: float) -> void:
	s.box(root,Vector3(0,0.86,0),Vector3(w,0.1,d),"9a7a52")
	for x: float in [-w/2+0.1,w/2-0.1]:
		for z: float in [-d/2+0.1,d/2-0.1]:
			s.box(root,Vector3(x,0.4,z),Vector3(0.1,0.8,0.1),"6a4c33")
	s.box(root,Vector3(0,0.3,0),Vector3(w-0.2,0.06,d-0.2),"7a5a3e")

## 赌桌: a gaming table, its top marked out for 大 and 小, a dice cup and bowl, strings of
## cash, dominoes and the croupier's rake (赌，胜者赢双).
func _gaming_table(w: float, d: float, data: Dictionary) -> void:
	_cutting_top(w,d)
	s.box(root,Vector3(0,0.92,0),Vector3(w-0.12,0.02,d-0.12),String(data.get("felt","2f4a3a")))
	for side: float in [-1.0,1.0]:
		s.box(root,Vector3(side*w*0.22,0.935,0),Vector3(w*0.36,0.01,d*0.6),String(data.get("marks","8a3a2c")))
		var title := Label3D.new()
		title.text = TranslationServer.translate("大" if side<0 else "小")
		title.position = Vector3(side*w*0.22,0.95,0)
		title.rotation.x = -PI/2
		title.pixel_size = 0.006
		title.font_size = 48
		title.outline_size = 0
		title.modulate = Color("e6c66e")
		root.add_child(title)
	s.box(root,Vector3(0,1.0,-d*0.32),Vector3(0.3,0.14,0.3),"d8d2c2")
	s.box(root,Vector3(0,1.15,-d*0.32),Vector3(0.2,0.24,0.2),"3a2a22")
	for die: int in 3:
		s.box(root,Vector3(-0.05+die*0.06,1.08,-d*0.32+0.04),Vector3(0.045,0.045,0.045),"efe8d6")
	for pile: int in 6:
		var at := Vector3(rng.randf_range(-0.4,0.4)*w,0.95,rng.randf_range(-0.1,0.4)*d)
		for coin: int in rng.randi_range(1,4):
			s.box(root,at+Vector3(0,coin*0.025,0),Vector3(0.09,0.02,0.09),"c9a35e")
	for tile: int in 5:
		s.box(root,Vector3(-w*0.4+tile*0.07,0.96,d*0.35),Vector3(0.05,0.03,0.1),"e8e0cc")
	s.tilted_box(root,Vector3(w*0.35,0.97,-d*0.2),Vector3(0.04,0.03,0.6),"8a6a45",Vector3(0,0.7,0))
	for stool: int in int(data.get("stools",4)):
		var a: float = stool*TAU/float(data.get("stools",4))+0.3
		var at := Vector3(cos(a)*w*0.42,0,sin(a)*d*0.42)
		s.box(root,at+Vector3(0,0.42,0),Vector3(0.36,0.06,0.36),"6b4e36")
		s.box(root,at+Vector3(0,0.2,0),Vector3(0.26,0.4,0.26),"4f3a29")

## 杂货架: a general store's shelves — baskets, brooms, oil jars, rope, lamps, bowls, sandals.
func _sundry_shelf(w: float, d: float, data: Dictionary) -> void:
	var wood: String = String(data.get("wood","6e5038"))
	var height: float = float(data.get("height",2.5))
	for x: float in [-w/2+0.06,w/2-0.06]:
		s.box(root,Vector3(x,height/2,0),Vector3(0.1,height,d),wood)
	for y: float in [0.1,height*0.36,height*0.68,height]:
		s.box(root,Vector3(0,y,0),Vector3(w,0.07,d),wood)
	var cols: int = maxi(2,floori(w/0.42))
	for row: int in 3:
		var y: float = [0.14,height*0.36+0.04,height*0.68+0.04][row]
		for col: int in cols:
			var at := Vector3(-w/2+(col+0.5)*w/cols,y,0)
			match (col+row*2)%6:
				0:
					s.box(root,at+Vector3(0,0.15,0),Vector3(0.28,0.3,0.28),"a68a55")
				1:
					s.box(root,at+Vector3(0,0.18,0),Vector3(0.2,0.36,0.2),"5b3f2f")
					s.box(root,at+Vector3(0,0.4,0),Vector3(0.12,0.06,0.12),"b23a2b")
				2:
					s.box(root,at+Vector3(0,0.06,0),Vector3(0.3,0.12,0.3),"b09a6c")
					s.box(root,at+Vector3(0,0.13,0),Vector3(0.14,0.04,0.14),"8a7044")
				3:
					for bowl: int in 3:
						s.box(root,at+Vector3(0,0.04+bowl*0.06,0),Vector3(0.22,0.05,0.22),"d8d2c2")
				4:
					s.box(root,at+Vector3(0,0.03,0),Vector3(0.26,0.05,0.34),"c4ad72")
				5:
					s.box(root,at+Vector3(0,0.14,0),Vector3(0.16,0.24,0.16),"8a6a3e")
					s.box(root,at+Vector3(0,0.28,0),Vector3(0.1,0.05,0.1),"ffb858")
	for broom: int in 2:
		s.tilted_box(root,Vector3(w/2+0.12,0.75,-d*0.2+broom*0.25),Vector3(0.04,1.4,0.04),"8a7044",Vector3(0,0,-0.12))
		s.box(root,Vector3(w/2+0.2,0.12,-d*0.2+broom*0.25),Vector3(0.16,0.26,0.12),"c4ad72")

## 药碾: the boat-shaped iron trough and its wheel for grinding herbs, on a low stand.
func _herb_mortar(w: float, data: Dictionary) -> void:
	s.box(root,Vector3(0,0.2,0),Vector3(w*0.8,0.4,w*0.4),String(data.get("wood","6a4c33")))
	s.box(root,Vector3(0,0.5,0),Vector3(w*0.75,0.2,0.26),"4a4440")
	s.box(root,Vector3(0,0.6,0),Vector3(w*0.6,0.02,0.12),"7d8a52")
	s.box(root,Vector3(0.05,0.66,0),Vector3(0.06,0.3,0.3),"5a5450")
	s.box(root,Vector3(0.05,0.66,0),Vector3(0.5,0.04,0.04),"8a6a45")

## 甲架: armour on a stand — a scaled coat, helmet and a round shield leaned against it.
func _armor_stand(data: Dictionary) -> void:
	s.box(root,Vector3(0,0.05,0),Vector3(0.6,0.1,0.5),"5b4433")
	s.box(root,Vector3(0,0.9,0),Vector3(0.08,1.7,0.08),"5b4433")
	s.box(root,Vector3(0,1.5,0),Vector3(0.7,0.08,0.08),"5b4433")
	var scales: String = String(data.get("scales","6f7a7a"))
	s.box(root,Vector3(0,1.15,0),Vector3(0.6,0.7,0.32),scales)
	for row: int in 4:
		s.box(root,Vector3(0,0.86+row*0.16,0.17),Vector3(0.62,0.04,0.02),Color(scales).lightened(0.18).to_html(false))
	s.box(root,Vector3(0,1.72,0),Vector3(0.34,0.3,0.34),scales)
	s.box(root,Vector3(0,1.92,0),Vector3(0.06,0.14,0.06),"b8412f")
	s.tilted_box(root,Vector3(0.36,0.4,0.15),Vector3(0.6,0.6,0.06),String(data.get("shield","7a4a32")),Vector3(-0.2,0.4,0))

## 茶叶架: shelves of tea jars and paper-wrapped bricks, each with its red label.
func _tea_shelf(w: float, d: float, data: Dictionary) -> void:
	var wood: String = String(data.get("wood","5c3f2b"))
	var height: float = float(data.get("height",2.4))
	for x: float in [-w/2+0.06,w/2-0.06]:
		s.box(root,Vector3(x,height/2,0),Vector3(0.1,height,d),wood)
	s.box(root,Vector3(0,height/2,-d/2+0.03),Vector3(w,height,0.06),wood)
	var jars: Array = data.get("colors",["5d7f78","8b5440","3f5a52","b08a5e","6b5a3e"])
	for row: int in 4:
		var y: float = 0.1+row*(height-0.2)/4.0
		s.box(root,Vector3(0,y,0),Vector3(w,0.06,d),wood)
		var count: int = maxi(2,floori(w/0.3))
		for i: int in count:
			var at := Vector3(-w/2+0.2+i*(w-0.4)/maxf(1,count-1),y+0.03,0)
			if (i+row)%3==2:
				s.box(root,at+Vector3(0,0.08,0),Vector3(0.24,0.16,0.18),"d8ccaa")
				s.box(root,at+Vector3(0,0.08,0.092),Vector3(0.08,0.1,0.01),"b8412f")
			else:
				s.box(root,at+Vector3(0,0.14,0),Vector3(0.2,0.28,0.2),String(jars[(i+row)%jars.size()]))
				s.box(root,at+Vector3(0,0.3,0),Vector3(0.12,0.05,0.12),"3d3530")
				s.box(root,at+Vector3(0,0.15,0.102),Vector3(0.1,0.12,0.01),"c0392b")
	s.box(root,Vector3(0,height+0.05,0),Vector3(w+0.08,0.1,d+0.08),wood)

## 秤: a steelyard hung from a beam or hook, its pan and sliding weight.
func _steelyard(data: Dictionary) -> void:
	var y: float = float(data.get("height",2.2))
	s.box(root,Vector3(0,y,0),Vector3(0.03,0.3,0.03),"8a8d82")
	s.tilted_box(root,Vector3(0,y-0.2,0),Vector3(0.9,0.03,0.03),"8a6a45",Vector3(0,0,0.06))
	s.box(root,Vector3(-0.35,y-0.5,0),Vector3(0.02,0.5,0.02),"8a8d82")
	s.box(root,Vector3(-0.35,y-0.76,0),Vector3(0.36,0.04,0.36),"8a8d82")
	s.box(root,Vector3(0.3,y-0.3,0),Vector3(0.08,0.12,0.08),"3d3d3a")

## 大锅灶: a brick stove with a great iron pot of rice gruel, its fire showing under it, steam
## rising, a ladle and a stack of bowls by it (斋院's kitchen).
func _cauldron(w: float, data: Dictionary) -> void:
	s.box(root,Vector3(0,0.45,0),Vector3(w*0.9,0.9,w*0.8),String(data.get("brick","8a6a54")))
	s.box(root,Vector3(0,0.92,0),Vector3(w*0.95,0.06,w*0.85),"6e5646")
	s.box(root,Vector3(0,0.28,w*0.4+0.01),Vector3(0.4,0.3,0.02),"ff8a3a:glow")
	s.box(root,Vector3(0,1.02,0),Vector3(w*0.62,0.22,w*0.58),"2f2c2a")
	s.box(root,Vector3(0,1.14,0),Vector3(w*0.52,0.02,w*0.48),String(data.get("gruel","e2d8bc")))
	s.tilted_box(root,Vector3(w*0.2,1.3,0),Vector3(0.05,0.6,0.05),"8a6a45",Vector3(0,0,0.5))
	for bowl: int in 4:
		s.box(root,Vector3(-w*0.35,0.98+bowl*0.06,w*0.25),Vector3(0.22,0.05,0.22),"d8d2c2")
	var fire := OmniLight3D.new()
	fire.position = Vector3(0,0.3,w*0.6)
	fire.light_color = Color("ff9a4a")
	fire.omni_range = 2.6
	fire.set_meta("day_energy",0.3)
	fire.set_meta("night_energy",0.8)
	fire.set_meta("flicker",0.18)
	root.add_child(fire)
	if ambience != null:
		ambience.smoke(root,Vector3(0,1.2,0),"eeece6",5,0.18)

## 木人桩: a post with three stubby arms and a leg, the wood worn pale where it is struck.
func _training_post(data: Dictionary) -> void:
	var wood: String = String(data.get("wood","7a5a3e"))
	s.box(root,Vector3(0,0.1,0),Vector3(0.6,0.2,0.6),"6a5a48")
	s.box(root,Vector3(0,1.0,0),Vector3(0.3,1.8,0.3),wood)
	s.box(root,Vector3(0,1.25,0.15),Vector3(0.22,0.4,0.04),"b49b72")
	for arm: Vector3 in [Vector3(-0.12,1.45,0.3),Vector3(0.12,1.45,0.3),Vector3(0,1.1,0.32)]:
		s.tilted_box(root,arm,Vector3(0.08,0.08,0.4),"8a6a45",Vector3(-0.2,0,0))
	s.tilted_box(root,Vector3(0,0.55,0.3),Vector3(0.09,0.09,0.42),"8a6a45",Vector3(0.6,0,0))

## 石锁: a pair of stone padlock weights for strength training, left on the floor.
func _stone_weights() -> void:
	for i: int in 2:
		var at := Vector3(-0.2+i*0.42,0,0.05*i)
		s.box(root,at+Vector3(0,0.14,0),Vector3(0.32,0.26,0.2),["8a8a7e","9a998c"][i])
		s.box(root,at+Vector3(0,0.33,0),Vector3(0.2,0.08,0.06),"7c7b70")
		for side: float in [-0.1,0.1]:
			s.box(root,at+Vector3(side,0.31,0),Vector3(0.05,0.12,0.06),"7c7b70")
