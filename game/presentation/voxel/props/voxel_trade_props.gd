extends RefCounted

## Furnishings for shops, workshops and public halls. Positions and blocking boxes
## come from Furnishings; these reusable forms contain no region or gameplay logic.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var s: Shapes
var root: Node3D

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
			s.box(root,Vector3(0,0.10,0),Vector3(w,0.20,d),"7b7459")
			s.box(root,Vector3(0,0.22,0),Vector3(w-0.14,0.07,d-0.14),"625b40")
			for i: int in maxi(4,floori(w*d*9)):
				var p := Vector3(sin(i*12.31)*w*0.40,0.32,cos(i*7.71)*d*0.38)
				var h: float = 0.22+(i%4)*0.09
				s.box(root,p+Vector3(0,h/2,0),Vector3(0.045,h,0.045),"658058")
				s.box(root,p+Vector3(0.07,h*0.5,0),Vector3(0.19,0.065,0.14),"80955a")
				s.box(root,p+Vector3(0,h,0),Vector3(0.15,0.08,0.15),["d5b86b","d3b5a6","bd8194","e3d6ab"][i%4])
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
