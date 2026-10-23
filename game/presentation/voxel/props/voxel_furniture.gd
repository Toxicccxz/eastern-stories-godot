extends RefCounted

## Furniture: what stands on a blocked box of the map layout (its `look`, read from the
## scene's Furnishings nodes). The box is the footprint; these forms only render it.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var s: Shapes
var root: Node3D
var rng: RandomNumberGenerator

func draw(shapes: Shapes, parent: Node3D, data: Dictionary, w: float, d: float) -> bool:
	s = shapes
	root = parent
	var tone: String = String(data.get("cloth","738a79"))
	match String(data["kind"]):
		"table":
			s.box(root,Vector3(0,0.86,0),Vector3(w,0.18,d),"76523a")
			for board: int in 3:
				s.box(root,Vector3(0,0.96,(board-1)*d/3),Vector3(w-0.05,0.07,d/3-0.012),["ae8155","a97c51","b2865a"][board])
			for x: float in [-w*0.4,w*0.4]:
				for z: float in [-d*0.35,d*0.35]:
					s.box(root,Vector3(x,0.43,z),Vector3(0.15,0.86,0.15),"765138")
			# Tucked seats remain inside the authored table collision footprint.
			for z: float in [-d*0.34,d*0.34]:
				s.box(root,Vector3(0,0.42,z),Vector3(w*0.69,0.12,d*0.27),"987149")
				for x: float in [-w*0.26,w*0.26]:
					s.box(root,Vector3(x,0.19,z),Vector3(0.13,0.38,0.17),"654933")
			s.box(root,Vector3(-0.4,1.01,0),Vector3(0.4,0.08,0.3),"d9d8b7")
			s.box(root,Vector3(0.35,1.13,0),Vector3(0.22,0.28,0.22),"72998a")
			s.box(root,Vector3(0.52,1.12,0),Vector3(0.15,0.08,0.07),"72998a")
			s.box(root,Vector3(0.2,1.05,0.2),Vector3(0.13,0.1,0.13),"e4dbb8")
			s.box(root,Vector3(-0.4,1.08,0),Vector3(0.23,0.08,0.18),"c29356")
			s.box(root,Vector3(w*0.32,1.01,-d*0.3),Vector3(0.24,0.03,0.025),"d3b57b")
			s.box(root,Vector3(w*0.32,1.01,-d*0.3+0.055),Vector3(0.24,0.03,0.025),"d3b57b")
		"counter":
			s.box(root,Vector3(0,0.6,0),Vector3(w,1.2,d),"825b3b")
			s.box(root,Vector3(0,1.25,0),Vector3(w+0.12,0.15,d+0.12),"bc8654")
			for x: int in ceili(w/0.8):
				s.box(root,Vector3(-w/2+0.4+x*0.8,0.6,d/2+0.02),Vector3(0.68,0.8,0.05),"a16c44")
				s.box(root,Vector3(-w/2+0.4+x*0.8,0.6,d/2+0.055),Vector3(0.52,0.60,0.03),"74513a")
				s.box(root,Vector3(-w/2+0.4+x*0.8,0.6,d/2+0.075),Vector3(0.44,0.49,0.02),"94704a")
			for i: int in 4:
				s.box(root,Vector3(-w/2+0.8+i*0.33,1.5,0),Vector3(0.22,0.34,0.22),_pick(["a36d4c","568075","b98b5b"]))
			s.box(root,Vector3(w*0.2,1.37,0),Vector3(1.1,0.09,0.4),"e2d2a8")
			s.box(root,Vector3(w*0.2,1.42,0),Vector3(0.022,0.01,0.38),"9d7a53")
			s.box(root,Vector3(-w*0.23,1.4,0),Vector3(0.8,0.10,0.36),"624632")
			for row: int in 2:
				for bead: int in 7:
					s.box(root,Vector3(-w*0.23-0.30+bead*0.1,1.47,(row-0.5)*0.12),Vector3(0.06,0.06,0.07),"b29462")
		"shelf":
			s.box(root,Vector3(0,1.4,-d*0.45),Vector3(w,2.8,0.06),"674a36")
			for x: float in [-w*0.5,-w*0.25,0,w*0.25,w*0.5]:
				s.box(root,Vector3(x,1.45,0),Vector3(0.12,2.9,d),"775138")
			for y: float in [0.30,1.12,1.94,2.76]:
				s.box(root,Vector3(0,y,0),Vector3(w,0.1,d),"755137")
				if y>2.5:
					continue
				for x: int in floori(w/0.62):
					var jar := Vector3(-w/2+0.38+x*0.62,y+0.07,0)
					var h: float = rng.randf_range(0.37,0.60)
					var jar_tone: String = _pick(["9b6748","b88b5c","5b8178","7b8a72"])
					s.box(root,jar+Vector3(0,h*0.47,0),Vector3(0.34,h*0.62,0.34),jar_tone)
					s.box(root,jar+Vector3(0,h*0.12,0),Vector3(0.25,h*0.24,0.25),jar_tone)
					s.box(root,jar+Vector3(0,h*0.84,0),Vector3(0.23,h*0.20,0.23),jar_tone)
					s.box(root,jar+Vector3(0,h,0),Vector3(0.26,0.08,0.26),"a75b43")
					s.box(root,jar+Vector3(0,h*0.50,0.177),Vector3(0.12,0.18,0.018),"dcc598")
		"bed":
			# Plain guest-room bed inside its authored blocked footprint, head at -x.
			s.box(root,Vector3(0,0.24,0),Vector3(w,0.48,d),"7a573c")
			s.box(root,Vector3(0,0.52,0),Vector3(w-0.16,0.14,d-0.16),"e4d9bf")
			var quilt: String = String(data.get("quilt","6f8f86"))
			s.box(root,Vector3(w*0.12,0.63,0),Vector3(w*0.70,0.10,d-0.10),quilt)
			for z: float in [-d*0.22,d*0.22]:
				s.box(root,Vector3(w*0.12,0.685,z),Vector3(w*0.70,0.012,0.06),"d9c99c")
			s.box(root,Vector3(w*0.47-0.02,0.64,0),Vector3(0.06,0.12,d-0.06),"d9c99c")
			s.box(root,Vector3(-w/2+0.48,0.66,0),Vector3(0.46,0.15,d*0.58),"f0e8d4")
			s.box(root,Vector3(-w/2+0.06,0.82,0),Vector3(0.12,0.96,d),"68472f")
			s.box(root,Vector3(-w/2+0.06,1.33,0),Vector3(0.16,0.08,d+0.08),"8c6644")
			s.box(root,Vector3(w/2-0.06,0.62,0),Vector3(0.12,0.46,d),"68472f")
			for x: float in [-w/2+0.08,w/2-0.08]:
				for z: float in [-d/2+0.08,d/2-0.08]:
					s.box(root,Vector3(x,0.5,z),Vector3(0.16,1.0 if x<0 else 0.86,0.16),"5c3f2b")
		"writing_desk":
			_table(w,d,1.12)
			if data.has("cloth"):
				s.box(root,Vector3(0,1.251,-d*0.15),Vector3(w*0.96,0.025,d*0.65),tone)
			# A tucked stool, open paper, stitched books, inkstone and two brushes.
			_stool(Vector3(0,0,d*0.34),0.64,"896b49")
			s.box(root,Vector3(-w*0.15,1.25,-d*0.16),Vector3(w*0.4,0.035,d*0.40),"e4d8af")
			for x: float in [-w*0.34,w*0.04]:
				s.box(root,Vector3(x,1.28,-d*0.16),Vector3(0.06,0.06,d*0.46),"95714b")
			for i: int in 5:
				s.box(root,Vector3(-w*0.27+i*0.13,1.274,-d*0.2),Vector3(0.025,0.012,0.19+0.06*(i%2)),"746a54")
			_book(Vector3(w*0.30,1.24,-d*0.27),"4e6967")
			_book(Vector3(w*0.29,1.35,-d*0.29),"ad8055")
			s.box(root,Vector3(w*0.12,1.28,0.12),Vector3(0.29,0.075,0.21),"414745")
			s.box(root,Vector3(w*0.12,1.32,0.12),Vector3(0.18,0.018,0.12),"242f31")
			for x: float in [0.24,0.34]:
				s.tilted_box(root,Vector3(x,1.28,0.36),Vector3(0.035,0.035,0.48),"b99b68",Vector3(0,0.18,0))
		"tea_table":
			_table(w,d,0.62)
			for x: float in [-w*0.32,w*0.32]:
				s.box(root,Vector3(x,0.11,d*0.30),Vector3(0.70,0.20,0.66),tone)
				s.box(root,Vector3(x,0.215,d*0.30),Vector3(0.57,0.025,0.53),"b2a884")
			s.box(root,Vector3(0,0.75,-d*0.12),Vector3(1.22,0.07,0.70),"594934")
			_teapot(Vector3(-0.22,0.80,-d*0.13),"6c9690")
			for x: float in [-0.42,0.28,0.48]:
				s.box(root,Vector3(x,0.85,0.05),Vector3(0.14,0.12,0.14),"e3d5b4")
				s.box(root,Vector3(x,0.914,0.05),Vector3(0.085,0.012,0.085),"756248")
		"travel_chest":
			_chest(w,d)
			if data.get("packed",true):
				s.box(root,Vector3(-w*0.15,0.94,0),Vector3(w*0.48,0.30,d*0.65),tone)
				s.box(root,Vector3(-w*0.15,1.11,0),Vector3(w*0.32,0.05,d*0.5),tone)
				for x: float in [-w*0.27,-w*0.03]:
					s.box(root,Vector3(x,1.145,0),Vector3(0.045,0.03,d*0.66),"c8b78e")
				s.box(root,Vector3(w*0.27,0.98,0),Vector3(w*0.20,0.38,d*0.56),"b79b6c")
				s.box(root,Vector3(w*0.27,1.18,0),Vector3(0.07,0.04,d*0.56),"66543c")
		"linen_cabinet":
			_chest(w,d)
			for i: int in 3:
				s.box(root,Vector3(-w*0.18,0.86+i*0.13,0),Vector3(w*0.48,0.12,d*0.72),["d9cda8",tone,"d9cda8"][i])
				s.box(root,Vector3(-w*0.18,0.89+i*0.13,d*0.36+0.006),Vector3(w*0.39,0.025,0.014),"b4a380")
			_teapot(Vector3(w*0.29,0.84,0),"a0835b")
		"washstand":
			for x: float in [-w*0.37,w*0.37]:
				for z: float in [-d*0.36,d*0.36]:
					s.box(root,Vector3(x,0.50,z),Vector3(0.12,1.0,0.12),"795c40")
			s.box(root,Vector3(0,0.30,0),Vector3(w*0.86,0.09,d*0.83),"9a7951")
			s.box(root,Vector3(0,1.01,0),Vector3(w,0.12,d),"a38156")
			s.box(root,Vector3(0,1.13,0),Vector3(w*0.65,0.16,d*0.60),"57787b")
			s.box(root,Vector3(0,1.215,0),Vector3(w*0.53,0.018,d*0.48),"a3b6a5")
			for x: float in [-w*0.37,w*0.37]:
				s.box(root,Vector3(x,1.62,-d*0.39),Vector3(0.09,1.18,0.09),"715438")
			s.box(root,Vector3(0,2.16,-d*0.39),Vector3(w*0.86,0.09,0.10),"99774d")
			s.box(root,Vector3(w*0.12,1.83,-d*0.34),Vector3(w*0.43,0.59,0.045),"ded6b9")
			s.box(root,Vector3(w*0.12,1.58,-d*0.31),Vector3(w*0.43,0.055,0.018),tone)
			s.box(root,Vector3(-w*0.18,0.48,0),Vector3(w*0.42,0.25,d*0.44),tone)
		"clothes_rack":
			for x: float in [-w*0.38,w*0.38]:
				s.box(root,Vector3(x,1.18,0),Vector3(0.11,2.36,0.12),"73543c")
				s.box(root,Vector3(x,0.075,0),Vector3(0.25,0.15,d),"886646")
			s.box(root,Vector3(0,2.30,0),Vector3(w,0.13,0.14),"a07b51")
			s.box(root,Vector3(0,1.46,0.03),Vector3(w*0.37,1.13,0.15),tone)
			s.box(root,Vector3(0,1.91,0.03),Vector3(w*0.70,0.36,0.15),tone)
			s.box(root,Vector3(-w*0.06,1.68,0.12),Vector3(0.065,0.72,0.035),"c8b89a")
			s.box(root,Vector3(0,1.36,0.12),Vector3(w*0.38,0.09,0.04),"545e57")
			s.box(root,Vector3(0,2.10,0),Vector3(0.08,0.28,0.08),"b49b6c")
		"folding_screen":
			for i: int in 3:
				var panel := Node3D.new()
				panel.position.x = (i-1)*w*0.32
				panel.rotation.y = 0.14 if i%2==0 else -0.14
				root.add_child(panel)
				var pw: float = w*0.33
				s.box(panel,Vector3(0,1.23,0),Vector3(pw,2.0,0.10),"71563e")
				s.box(panel,Vector3(0,1.28,0.07),Vector3(pw-0.13,1.76,0.055),"c9c3a2")
				for side: float in [-1,1]:
					s.box(panel,Vector3(side*pw*0.4,0.16,0),Vector3(0.09,0.32,0.19),"71563e")
				for shoot: int in 2:
					var stem: float = (shoot-0.5)*pw*0.35
					s.box(panel,Vector3(stem,1.18,0.105),Vector3(0.035,1.21,0.02),tone)
					for leaf: int in 3:
						s.tilted_box(panel,Vector3(stem+0.08,0.8+leaf*0.35,0.115),Vector3(pw*0.28,0.055,0.02),tone,Vector3(0,0,-0.45))
		"wall_scroll":
			s.box(root,Vector3(0,2.15,0.02),Vector3(w,1.7,0.04),"b29c75")
			s.box(root,Vector3(0,2.17,0.05),Vector3(w*0.76,1.46,0.025),"ddd3af")
			for y: float in [1.27,3.03]:
				s.box(root,Vector3(0,y,0.04),Vector3(w+0.16,0.07,0.09),"71563c")
			if data.get("portrait",false):
				s.box(root,Vector3(0,1.93,0.073),Vector3(w*0.40,0.70,0.015),"9b607a")
				s.box(root,Vector3(0,2.47,0.073),Vector3(w*0.24,0.33,0.015),"d4ad83")
				s.box(root,Vector3(0,2.66,0.074),Vector3(w*0.32,0.16,0.015),"393c3b")
				s.box(root,Vector3(0,2.18,0.084),Vector3(w*0.12,0.27,0.015),"d4c18e")
			elif data.get("calligraphy",false):
				for col: int in 3:
					for row: int in 4:
						var at := Vector3((col-1)*w*0.23,2.65-row*0.28,0.075)
						s.box(root,at,Vector3(w*0.12,0.035,0.015),"515a50")
						s.box(root,at+Vector3(w*0.03,-0.05,0),Vector3(0.025,0.18,0.015),"515a50")
			else:
				for i: int in 7:
					var h: float = [0.25,0.48,0.66,0.52,0.34,0.43,0.27][i]
					s.box(root,Vector3(-w*0.30+i*w*0.10,1.54+h/2,0.071),Vector3(w*0.11,h,0.012),"7f9385")
				s.box(root,Vector3(w*0.15,2.57,0.076),Vector3(0.20,0.20,0.015),"b88b65")
		"slippers":
			for x: float in [-0.17,0.17]:
				s.box(root,Vector3(x,0.045,0),Vector3(0.22,0.07,0.43),"5c4a3a")
				s.box(root,Vector3(x,0.095,-0.10),Vector3(0.22,0.07,0.23),tone)
		_:
			return false
	return true

func _pick(colors: Array) -> String:
	return String(colors[rng.randi_range(0,colors.size()-1)])

func _table(w: float, d: float, h: float) -> void:
	s.box(root,Vector3(0,h,-d*0.15),Vector3(w,0.16,d*0.65),"8d6744")
	for plank: int in 3:
		s.box(root,Vector3(0,h+0.10,-d*0.37+plank*d*0.22),Vector3(w-0.04,0.05,d*0.21),["a88255","b08a5d","a17b51"][plank])
	for x: float in [-w*0.4,w*0.4]:
		for z: float in [-d*0.38,d*0.08]:
			s.box(root,Vector3(x,h/2,z),Vector3(0.12,h,0.12),"71513a")

func _stool(at: Vector3, w: float, tone: String) -> void:
	s.box(root,at+Vector3(0,0.48,0),Vector3(w,0.13,w),tone)
	for x: float in [-w*0.34,w*0.34]:
		for z: float in [-w*0.34,w*0.34]:
			s.box(root,at+Vector3(x,0.22,z),Vector3(0.10,0.44,0.10),"71513a")

func _book(at: Vector3, tone: String) -> void:
	s.box(root,at,Vector3(0.52,0.10,0.37),tone)
	s.box(root,at+Vector3(0.015,0,0.012),Vector3(0.49,0.055,0.36),"d8ccaa")
	s.box(root,at+Vector3(-0.20,0.056,0),Vector3(0.055,0.015,0.35),tone)

func _teapot(at: Vector3, tone: String) -> void:
	s.box(root,at+Vector3(0,0.15,0),Vector3(0.30,0.26,0.30),tone)
	s.box(root,at+Vector3(0,0.30,0),Vector3(0.23,0.045,0.23),tone)
	s.box(root,at+Vector3(0,0.35,0),Vector3(0.07,0.06,0.07),"b2ba9c")
	s.tilted_box(root,at+Vector3(0.20,0.18,0),Vector3(0.22,0.10,0.10),tone,Vector3(0,0,0.35))
	s.box(root,at+Vector3(-0.20,0.18,0),Vector3(0.10,0.20,0.065),tone)

func _chest(w: float, d: float) -> void:
	s.box(root,Vector3(0,0.41,0),Vector3(w,0.70,d),"886447")
	s.box(root,Vector3(0,0.78,0),Vector3(w+0.035,0.10,d+0.035),"a78055")
	for x: float in [-w*0.32,w*0.32]:
		s.box(root,Vector3(x,0.42,d/2+0.015),Vector3(0.07,0.68,0.035),"574b37")
		s.box(root,Vector3(x,0.837,0),Vector3(0.07,0.02,d),"6f6044")
	s.box(root,Vector3(0,0.61,d/2+0.03),Vector3(0.17,0.24,0.06),"c2a666")
