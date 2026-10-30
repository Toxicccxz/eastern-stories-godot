extends RefCounted

## Furniture: what stands on a blocked box of the map layout (its `look`, read from the
## scene's Furnishings nodes). The box is the footprint; these forms only render it.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var s: Shapes
var root: Node3D
var rng: RandomNumberGenerator
## The tea stove's steam (null where nothing moves).
var ambience: VoxelAmbience

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
			# Tucked seats remain inside the authored table collision footprint; `askew` (a seed)
			# leaves them pushed back and turned, as the last sitters left them.
			for z: float in [-d*0.34,d*0.34]:
				var seat := Node3D.new()
				seat.position = Vector3(0,0,z)
				if data.has("askew"):
					var turn: int = hash(int(data["askew"])+roundi(z*100))
					seat.position += Vector3(float(turn%9-4)*0.03,0,signf(z)*0.06)
					seat.rotation.y = float(turn%13-6)*0.035
				root.add_child(seat)
				if s.merged.has(root):
					s.merge(seat,s.merged[root])
				s.box(seat,Vector3(0,0.42,0),Vector3(w*0.69,0.12,d*0.27),"987149")
				for x: float in [-w*0.26,w*0.26]:
					s.box(seat,Vector3(x,0.19,0),Vector3(0.13,0.38,0.17),"654933")
			# `set`: what is on it instead (VoxelLife draws it); a plain setting otherwise.
			if data.has("set"):
				return true
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
					# `curios`: a 多宝格 of porcelain, jade and bronze instead of the store's jars.
					var jar_tone: String = _pick(["e8e6dc","4a6a9a","5a8a6a","a8823a","d8c8b0"] if data.get("curios",false) else ["9b6748","b88b5c","5b8178","7b8a72"])
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
			if data.has("canopy"):
				# 帐幔: four posts, a frame on top and gauze hung on the sides, open at the front.
				var gauze: String = String(data["canopy"])
				for x: float in [-w/2+0.08,w/2-0.08]:
					for z: float in [-d/2+0.08,d/2-0.08]:
						s.box(root,Vector3(x,1.25,z),Vector3(0.07,2.5,0.07),"5c3f2b")
				s.box(root,Vector3(0,2.5,0),Vector3(w,0.08,d),"5c3f2b")
				s.box(root,Vector3(0,1.6,-d/2+0.06),Vector3(w-0.2,1.7,0.03),gauze)
				for x: float in [-w/2+0.06,w/2-0.06]:
					s.box(root,Vector3(x,1.6,0),Vector3(0.03,1.7,d-0.2),gauze)
				for x: float in [-w*0.35,w*0.35]:
					s.box(root,Vector3(x,1.8,d/2-0.06),Vector3(w*0.22,1.3,0.03),gauze)
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
			if data.get("gavel",false):
				# yamen.c: 书案上放着…惊堂木 — the magistrate's gavel block.
				s.box(root,Vector3(w*0.3,1.3,0.1),Vector3(0.26,0.07,0.1),"3a2a22")
			if data.get("incense",false):
				# latebook.c: 上面摆著一座小小的香炉.
				s.box(root,Vector3(-w*0.36,1.32,-d*0.25),Vector3(0.18,0.14,0.18),"7a6a46")
				s.box(root,Vector3(-w*0.36,1.42,-d*0.25),Vector3(0.12,0.05,0.12),"8a7a52")
			if data.has("vase"):
				# moroom.c: 案上一个土定瓶, 中供著数枝菊花.
				_vase(Vector3(-w*0.36,1.25,-d*0.25),String(data["vase"]),data.get("flowers",["e8c84a"]))
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
			if data.get("books",false):
				# club.c: 矮几上摊有书卷放着一支朱砂笔, 一房歙砚, 另几张上好生宣.
				_book(Vector3(-0.3,0.8,-d*0.12),"4e6967")
				_book(Vector3(-0.1,0.8,-d*0.14),"7a6a5a")
				s.box(root,Vector3(0.3,0.79,-d*0.1),Vector3(0.36,0.025,0.28),"e8dcbc")
				s.box(root,Vector3(0.32,0.82,-d*0.2),Vector3(0.22,0.05,0.16),"2a2a2e")
				s.tilted_box(root,Vector3(0.1,0.82,-d*0.02),Vector3(0.03,0.03,0.34),"b83a2a",Vector3(0,0.4,0))
			else:
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
		"ice_chest":
			# 第四章: the 冰匣 of the second 密室 — a knee-high chest cut from dark ice, frost on
			# its lid (`ice`, `frost`, `rim` colours), the one line cut into its face.
			var ice: String = String(data.get("ice","9ab8c4"))
			var frost: String = String(data.get("frost","e8f2f6"))
			var rim: String = String(data.get("rim","6e8ea0"))
			s.box(root,Vector3(0,0.30,0),Vector3(w,0.52,d),ice)
			s.box(root,Vector3(0,0.58,0),Vector3(w+0.04,0.08,d+0.04),rim)
			s.box(root,Vector3(0,0.635,0),Vector3(w*0.92,0.03,d*0.88),frost)
			for x: float in [-w*0.3,w*0.3]:
				s.box(root,Vector3(x,0.655,-d*0.1),Vector3(w*0.18,0.012,d*0.3),frost)
			s.box(root,Vector3(0,0.42,d/2+0.012),Vector3(w*0.6,0.05,0.025),rim)
			s.box(root,Vector3(0,0.12,0),Vector3(w*0.9,0.1,d*0.9),"5a7482")
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
			# `panels` leaves of `panel` silk in a `wood` frame, `height` tall, a spray painted on
			# each in `cloth`.
			var leaves: int = int(data.get("panels",3))
			var tall: float = float(data.get("height",2.0))
			var frame: String = String(data.get("wood","71563e"))
			for i: int in leaves:
				var panel := Node3D.new()
				panel.position.x = (i-(leaves-1)/2.0)*w*0.96/leaves
				panel.rotation.y = 0.14 if i%2==0 else -0.14
				root.add_child(panel)
				if s.merged.has(root):
					s.merge(panel,s.merged[root])
				var pw: float = w*0.99/leaves
				s.box(panel,Vector3(0,0.23+tall/2,0),Vector3(pw,tall,0.10),frame)
				s.box(panel,Vector3(0,0.28+tall/2,0.07),Vector3(pw-0.13,tall*0.88,0.055),String(data.get("panel","c9c3a2")))
				for side: float in [-1,1]:
					s.box(panel,Vector3(side*pw*0.4,0.16,0),Vector3(0.09,0.32,0.19),frame)
				for shoot: int in 2:
					var stem: float = (shoot-0.5)*pw*0.35
					s.box(panel,Vector3(stem,0.18+tall/2,0.105),Vector3(0.035,tall*0.6,0.02),tone)
					for leaf: int in 3:
						s.tilted_box(panel,Vector3(stem+0.08,tall*0.4+leaf*tall*0.17,0.115),Vector3(pw*0.28,0.055,0.02),tone,Vector3(0,0,-0.45))
		"wall_scroll":
			s.box(root,Vector3(0,2.15,0.02),Vector3(w,1.7,0.04),"b29c75")
			s.box(root,Vector3(0,2.17,0.05),Vector3(w*0.76,1.46,0.025),"ddd3af")
			for y: float in [1.27,3.03]:
				s.box(root,Vector3(0,y,0.04),Vector3(w+0.16,0.07,0.09),"71563c")
			if data.get("portrait",false):
				# `robe`, `hat` and a `beard` (an old master's long white one) from the data.
				s.box(root,Vector3(0,1.93,0.073),Vector3(w*0.40,0.70,0.015),String(data.get("robe","9b607a")))
				s.box(root,Vector3(0,2.47,0.073),Vector3(w*0.24,0.33,0.015),"d4ad83")
				s.box(root,Vector3(0,2.66,0.074),Vector3(w*0.32,0.16,0.015),String(data.get("hat","393c3b")))
				s.box(root,Vector3(0,2.18,0.084),Vector3(w*0.12,0.27,0.015),"d4c18e")
				if data.has("beard"):
					s.box(root,Vector3(0,2.24,0.086),Vector3(w*0.12,0.34,0.015),String(data["beard"]))
			elif data.get("steps",false):
				# 舞步图 (latemoon8.c: 玄天玉女翩然起舞的美妙步法; uproom2.c: 各种基本步法): a dancer
				# with flying sleeves, the footprints of the steps winding round her in ink.
				var robe: String = String(data.get("robe","d87a9a"))
				s.box(root,Vector3(0,2.45,0.073),Vector3(w*0.1,0.14,0.012),"d4ad83")
				s.box(root,Vector3(0,2.12,0.073),Vector3(w*0.14,0.5,0.012),robe)
				s.box(root,Vector3(w*0.04,1.8,0.073),Vector3(w*0.22,0.2,0.012),robe)
				for side: float in [-1.0,1.0]:
					s.tilted_box(root,Vector3(side*w*0.16,2.3,0.076),Vector3(w*0.24,0.05,0.01),"e8d8e0",Vector3(0,0,side*0.5))
				for step: int in 8:
					var a: float = step*0.8+0.4
					s.box(root,Vector3(cos(a)*w*0.3,1.95+sin(a)*0.5,0.08),Vector3(0.05,0.08,0.01),"2a2420")
			elif data.get("birds",false):
				# 翎毛丹青 (latemoon1.c: 各式鸟兽虫鱼): a flowering branch across the paper, a bird on it.
				s.tilted_box(root,Vector3(0,2.0,0.073),Vector3(w*0.62,0.035,0.012),"5a4a3a",Vector3(0,0,0.5))
				for bloom: int in 4:
					s.box(root,Vector3((bloom-1.5)*w*0.14,1.86+bloom*0.09,0.078),Vector3(0.07,0.07,0.012),String(data.get("bloom","d8607a")))
				s.box(root,Vector3(w*0.08,2.2,0.08),Vector3(w*0.18,0.1,0.012),String(data.get("bird","3a6a8a")))
				s.box(root,Vector3(w*0.17,2.25,0.08),Vector3(w*0.07,0.07,0.012),String(data.get("bird","3a6a8a")))
				s.box(root,Vector3(-w*0.03,2.17,0.08),Vector3(w*0.1,0.04,0.012),"e8c84a")
			elif data.get("chart",false):
				# 经脉穴道图: a figure in outline, the meridians in red and the points dotted along them.
				s.box(root,Vector3(0,2.5,0.073),Vector3(w*0.16,0.2,0.012),"8a7a64")
				s.box(root,Vector3(0,2.08,0.073),Vector3(w*0.26,0.6,0.012),"8a7a64")
				for side: float in [-1.0,1.0]:
					s.box(root,Vector3(side*w*0.2,2.1,0.073),Vector3(w*0.06,0.5,0.012),"8a7a64")
					s.box(root,Vector3(side*w*0.07,1.6,0.073),Vector3(w*0.08,0.42,0.012),"8a7a64")
					s.box(root,Vector3(side*w*0.06,1.85,0.08),Vector3(0.02,1.1,0.01),"b8342a")
				s.box(root,Vector3(0,2.1,0.08),Vector3(0.02,0.9,0.01),"2f4a8a")
				for point: int in 9:
					s.box(root,Vector3(((point%3)-1)*w*0.06,1.5+point*0.12,0.085),Vector3(0.03,0.03,0.01),"1e1a18")
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
		"square_table": _square_table(w,d,data)
		"chess_table": _chess_table(w,d,data)
		"zither_table": _zither_table(w,d,data)
		"dressing_table": _dressing_table(w,d,tone)
		"tea_stove": _tea_stove(w,d)
		"tea_baskets": _tea_baskets(w,d,data)
		"couch": _couch(w,d,tone,data)
		"flower_stand": _flower_stand(w,data)
		"ceremony_table": _ceremony_table(w,d,data)
		"wardrobe": _wardrobe(w,d,data)
		"bench_seat": _bench_seat(w,d,data)
		"clutter": _clutter(w,d,data)
		"stool": _stool(Vector3.ZERO,minf(w,d)*0.85,_wood(data,"wood",tone))
		"long_bed": _long_bed(w,d,data)
		"kang": _kang(w,d,data)
		"grand_chair": _grand_chair(w,d,data)
		"saw_horse": _saw_horse(w,d)
		"hearth": _hearth(w,d,data)
		"stone_bed": _stone_bed(w,d,data)
		"stone_seat": _stone_seat(w,d,data)
		"round_table": _round_table(w,d,data)
		"table_row": _table_row(w,d,data)
		"chair_row": _chair_row(w,d,data)
		"side_table": _side_table(w,d,data)
		_:
			return false
	return true

## The colours of a lacquered or plain piece: `top`, `legs`, `trim` (defaults plain wood).
func _wood(look: Dictionary, key: String, fallback: String) -> String:
	return String(look.get(key,fallback))

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

## 八仙桌: a square table for eight, its apron and corner brackets; black lacquer inlaid with
## gold where a grand house has it (`top`, `legs`, `trim`), a tea set or wine on it (`set`).
func _square_table(w: float, d: float, look: Dictionary) -> void:
	var top: String = _wood(look,"top","8d6744")
	var legs: String = _wood(look,"legs","6e4d37")
	var trim: String = _wood(look,"trim","a88255")
	s.box(root,Vector3(0,0.86,0),Vector3(w,0.1,d),top)
	s.box(root,Vector3(0,0.92,0),Vector3(w-0.06,0.025,d-0.06),trim)
	s.box(root,Vector3(0,0.93,0),Vector3(w-0.16,0.026,d-0.16),top)
	if look.has("cloth"):
		# latemoon3.c: 一块大红镶金桌巾 — a cloth over the top, hanging down the front, gold-edged.
		var cloth: String = String(look["cloth"])
		s.box(root,Vector3(0,0.955,0),Vector3(w-0.02,0.02,d-0.02),cloth)
		s.box(root,Vector3(0,0.78,d/2+0.01),Vector3(w*0.7,0.36,0.02),cloth)
		s.box(root,Vector3(0,0.61,d/2+0.015),Vector3(w*0.7,0.04,0.02),String(look.get("border","c9a24a")))
	for x: float in [-w/2+0.08,w/2-0.08]:
		for z: float in [-d/2+0.08,d/2-0.08]:
			s.box(root,Vector3(x,0.42,z),Vector3(0.11,0.84,0.11),legs)
	for side: float in [-1.0,1.0]:
		s.box(root,Vector3(0,0.74,side*(d/2-0.05)),Vector3(w-0.2,0.12,0.04),legs)
		s.box(root,Vector3(side*(w/2-0.05),0.74,0),Vector3(0.04,0.12,d-0.2),legs)
		s.box(root,Vector3(0,0.75,side*(d/2-0.03)),Vector3(w*0.3,0.05,0.02),trim)
	match String(look.get("set","tea")):
		"tea":
			_teapot(Vector3(-0.15,0.94,0.0),String(look.get("teapot","6c9690")))
			for c: int in 4:
				var a: float = c*TAU/4.0+0.5
				s.box(root,Vector3(cos(a)*w*0.3,0.99,sin(a)*d*0.3),Vector3(0.1,0.1,0.1),"e3d5b4")
		"wine":
			s.box(root,Vector3(0,1.08,0),Vector3(0.2,0.3,0.2),"6b4a35")
			s.box(root,Vector3(0,1.26,0),Vector3(0.1,0.06,0.1),"b23a2b")
			for c: int in 3:
				s.box(root,Vector3(-0.3+c*0.3,0.97,0.25),Vector3(0.08,0.07,0.08),"d9cfb4")
			s.box(root,Vector3(0.25,0.95,-0.25),Vector3(0.36,0.03,0.36),"d8d2c2")
			s.box(root,Vector3(0.25,0.98,-0.25),Vector3(0.24,0.04,0.24),String(look.get("dish","b8743a")))
		"incense":
			s.box(root,Vector3(0,1.0,-0.1),Vector3(0.3,0.12,0.24),"7a6a4a")
			s.box(root,Vector3(0,1.15,-0.1),Vector3(0.02,0.2,0.02),"c9a35e")
	# `stools`: [[x, z], ...] as fractions of the table's size (outside it: inside its box).
	for stool: Array in look.get("stools",[]):
		_stool(Vector3(float(stool[0])*w,0,float(stool[1])*d),0.45,_wood(look,"stool","896b49"))

## 棋桌: a low table with a Go board ruled on it, bowls of black and white stones, a game
## half played.
func _chess_table(w: float, d: float, look: Dictionary) -> void:
	_table(w,d,float(look.get("height",0.72)))
	var y: float = float(look.get("height",0.72))+0.13
	var board: float = minf(w,d)*0.62
	s.box(root,Vector3(0,y,-d*0.15),Vector3(board,0.06,board),"c9a96a")
	for i: int in 7:
		var t: float = -board/2+0.05+i*(board-0.1)/6.0
		s.box(root,Vector3(t,y+0.032,-d*0.15),Vector3(0.012,0.006,board-0.1),"5a4632")
		s.box(root,Vector3(0,y+0.032,-d*0.15+t),Vector3(board-0.1,0.006,0.012),"5a4632")
	for i: int in 14:
		var at := Vector3(rng.randf_range(-0.42,0.42)*board,y+0.045,-d*0.15+rng.randf_range(-0.42,0.42)*board)
		s.box(root,at,Vector3(0.05,0.025,0.05),"2a2622" if i%2 else "efe8d6")
	for x: float in [-board*0.65,board*0.65]:
		s.box(root,Vector3(x,y+0.05,-d*0.15),Vector3(0.18,0.12,0.18),"6b4a35")
		s.box(root,Vector3(x,y+0.11,-d*0.15),Vector3(0.12,0.02,0.12),"2a2622" if x<0 else "efe8d6")

## 琴桌: a long low table with a seven-stringed 琴 laid along it, an incense burner at its end.
func _zither_table(w: float, d: float, look: Dictionary) -> void:
	_table(w,d,float(look.get("height",0.7)))
	var y: float = float(look.get("height",0.7))+0.15
	var long_x: bool = w>=d
	var length: float = maxf(w,d)*0.78
	s.box(root,Vector3(-0.05,y+0.04,-d*0.15),Vector3(length,0.07,0.32) if long_x else Vector3(0.32,0.07,length),String(look.get("zither","5a3b2c")))
	for string: int in 7:
		var offset: float = -0.12+string*0.04
		s.box(root,Vector3(-0.05,y+0.085,-d*0.15+offset) if long_x else Vector3(offset,y+0.085,-d*0.15),Vector3(length*0.9,0.006,0.008) if long_x else Vector3(0.008,0.006,length*0.9),"e8e0cc")
	s.box(root,Vector3(w*0.4,y+0.08,-d*0.15) if long_x else Vector3(0,y+0.08,d*0.32),Vector3(0.18,0.16,0.18),"8b6f45")

## 梳妆台: a small table with a round bronze mirror on a stand, a comb box and a powder jar.
func _dressing_table(w: float, d: float, tone: String) -> void:
	_table(w,d,0.82)
	s.box(root,Vector3(0,1.05,-d*0.3),Vector3(0.08,0.36,0.08),"6a4c33")
	s.box(root,Vector3(0,1.42,-d*0.3),Vector3(0.62,0.62,0.05),"b89548")
	s.box(root,Vector3(0,1.42,-d*0.3+0.03),Vector3(0.5,0.5,0.02),"d9d2b8:gloss")
	s.box(root,Vector3(-w*0.3,0.98,0),Vector3(0.3,0.16,0.22),tone)
	s.box(root,Vector3(w*0.28,0.99,0.05),Vector3(0.14,0.16,0.14),"e3d5b4")
	_stool(Vector3(0,0,d*0.55),0.5,"896b49")

## 茶炉: a clay stove with its charcoal glowing, a kettle steaming on top, a fan and a
## basket of charcoal beside it.
func _tea_stove(w: float, d: float) -> void:
	s.box(root,Vector3(0,0.38,0),Vector3(w*0.62,0.76,d*0.62),"8a5a3e")
	s.box(root,Vector3(0,0.78,0),Vector3(w*0.7,0.06,d*0.7),"6b4a35")
	s.box(root,Vector3(0,0.3,d*0.31+0.01),Vector3(0.24,0.2,0.02),"ff8a3a:glow")
	s.box(root,Vector3(0,0.98,0),Vector3(0.38,0.32,0.38),"4a4440")
	s.box(root,Vector3(0,1.16,0),Vector3(0.12,0.06,0.12),"6a625a")
	s.tilted_box(root,Vector3(0.24,1.04,0),Vector3(0.22,0.07,0.07),"4a4440",Vector3(0,0,0.5))
	s.box(root,Vector3(-w*0.42,0.16,d*0.25),Vector3(0.3,0.3,0.3),"a68a55")
	s.box(root,Vector3(-w*0.42,0.32,d*0.25),Vector3(0.24,0.04,0.24),"2a2622")
	s.tilted_box(root,Vector3(w*0.35,0.81,d*0.25),Vector3(0.24,0.02,0.3),"c9b98e",Vector3(0,0.6,0))
	var glow := OmniLight3D.new()
	glow.position = Vector3(0,0.4,d*0.5)
	glow.light_color = Color("ff9a4a")
	glow.omni_range = 2.4
	glow.set_meta("day_energy",0.3)
	glow.set_meta("night_energy",0.7)
	glow.set_meta("flicker",0.15)
	root.add_child(glow)
	if ambience != null:
		ambience.smoke(root,Vector3(0.3,1.15,0),"eeece6",4,0.12)

## 大竹箩: great round bamboo baskets brimming with tea, a scoop in one.
func _tea_baskets(w: float, d: float, look: Dictionary) -> void:
	var count: int = int(look.get("count",maxi(1,floori(w/0.9))))
	var leaves: Array = look.get("leaves",["4f5a32","5c6b38","6f7c42","3f4a2c"])
	for i: int in count:
		var at := Vector3(-w/2+(i+0.5)*w/count,0,0)
		var size: float = minf(w/count,d)*0.92
		s.box(root,at+Vector3(0,0.42,0),Vector3(size,0.84,size),"a68a55")
		for band: float in [0.18,0.5,0.8]:
			s.box(root,at+Vector3(0,band,0),Vector3(size+0.03,0.05,size+0.03),"8a7044")
		s.box(root,at+Vector3(0,0.86,0),Vector3(size*0.88,0.08,size*0.88),String(leaves[i%leaves.size()]))
		s.box(root,at+Vector3(0,0.92,0),Vector3(size*0.5,0.06,size*0.5),String(leaves[(i+1)%leaves.size()]))
	s.tilted_box(root,Vector3(-w/2+0.5,0.95,0.1),Vector3(0.08,0.06,0.5),"8a6a45",Vector3(0.5,0.3,0))

## 罗汉床: a broad couch with railed back and sides, a low table on it, cushions.
func _couch(w: float, d: float, tone: String, look: Dictionary) -> void:
	var wood: String = _wood(look,"wood","5c3f2b")
	s.box(root,Vector3(0,0.28,0),Vector3(w,0.12,d),wood)
	for x: float in [-w/2+0.08,w/2-0.08]:
		for z: float in [-d/2+0.08,d/2-0.08]:
			s.box(root,Vector3(x,0.12,z),Vector3(0.12,0.24,0.12),wood)
	s.box(root,Vector3(0,0.37,0),Vector3(w-0.1,0.08,d-0.1),tone)
	s.box(root,Vector3(0,0.75,-d/2+0.06),Vector3(w,0.75,0.08),wood)
	for x: float in [-w/2+0.06,w/2-0.06]:
		s.box(root,Vector3(x,0.58,0),Vector3(0.08,0.45,d),wood)
	s.box(root,Vector3(0,0.75,-d/2+0.11),Vector3(w*0.7,0.5,0.03),_wood(look,"panel","8d6744"))
	s.box(root,Vector3(0,0.55,0.05),Vector3(w*0.28,0.16,d*0.42),_wood(look,"table","6e4d37"))
	_teapot(Vector3(0,0.63,0.05),"6c9690")
	for x: float in [-w*0.32,w*0.32]:
		s.box(root,Vector3(x,0.52,-d*0.2),Vector3(0.5,0.22,0.3),_wood(look,"cushion","9b4a3a"))

## 花架: a tall slender stand with a potted orchid (or another flower: `flower`).
func _flower_stand(w: float, look: Dictionary) -> void:
	var wood: String = _wood(look,"wood","5c3f2b")
	for x: float in [-w*0.3,w*0.3]:
		for z: float in [-w*0.3,w*0.3]:
			s.box(root,Vector3(x,0.5,z),Vector3(0.06,1.0,0.06),wood)
	s.box(root,Vector3(0,1.0,0),Vector3(w*0.75,0.06,w*0.75),wood)
	s.box(root,Vector3(0,1.15,0),Vector3(0.26,0.24,0.26),String(look.get("pot","d8d2c2")))
	for leaf: int in 5:
		var a: float = leaf*TAU/5.0
		s.tilted_box(root,Vector3(cos(a)*0.12,1.4,sin(a)*0.12),Vector3(0.04,0.4,0.02),"4f7a3c",Vector3(sin(a)*0.6,a,-cos(a)*0.6))
	s.box(root,Vector3(0.05,1.62,0),Vector3(0.1,0.08,0.1),String(look.get("flower","e8dcef")))

## 喜案 (红娘庄): a table under red silk, a pair of red candles, a double-happiness card,
## red thread on spools, a wedding register and a brush.
func _ceremony_table(w: float, d: float, look: Dictionary) -> void:
	_table(w,d,0.84)
	var red: String = String(look.get("cloth","b8322a"))
	s.box(root,Vector3(0,0.96,-d*0.15),Vector3(w+0.04,0.03,d*0.66),red)
	s.box(root,Vector3(0,0.66,d*0.18),Vector3(w*0.8,0.6,0.03),red)
	s.box(root,Vector3(0,0.7,d*0.2),Vector3(0.3,0.3,0.02),"e6c66e")
	for x: float in [-w*0.35,w*0.35]:
		s.box(root,Vector3(x,1.05,-d*0.3),Vector3(0.12,0.12,0.12),"b89548")
		s.box(root,Vector3(x,1.25,-d*0.3),Vector3(0.07,0.3,0.07),"c0392b")
		s.box(root,Vector3(x,1.44,-d*0.3),Vector3(0.04,0.08,0.04),"ffd88a")
	s.box(root,Vector3(0,1.1,-d*0.38),Vector3(0.36,0.36,0.03),"c0392b")
	s.box(root,Vector3(0,1.1,-d*0.36),Vector3(0.2,0.2,0.01),"e6c66e")
	s.box(root,Vector3(-w*0.12,1.0,0.0),Vector3(0.5,0.06,0.36),"d8ccaa")
	for spool: int in 3:
		s.box(root,Vector3(w*0.2+spool*0.13,1.03,0.05),Vector3(0.09,0.1,0.09),"c0392b")
	var candle := OmniLight3D.new()
	candle.position = Vector3(0,1.5,-d*0.1)
	candle.light_color = Color("ffc27d")
	candle.omni_range = 3.5
	candle.set_meta("day_energy",0.4)
	candle.set_meta("night_energy",1.0)
	candle.set_meta("flicker",0.12)
	root.add_child(candle)

## 衣柜: a tall two-door cabinet with brass plates, something folded on top.
func _wardrobe(w: float, d: float, look: Dictionary) -> void:
	var wood: String = _wood(look,"wood","6a4a34")
	var height: float = float(look.get("height",2.3))
	# `count` cupboards side by side along the box (a changing room's row of them).
	var count: int = maxi(1,int(look.get("count",1)))
	var each: float = w/count
	for i: int in count:
		var cx: float = -w/2+each*(i+0.5)
		var cw: float = each-0.06
		s.box(root,Vector3(cx,height/2,0),Vector3(cw,height-0.04*(i%2),d),wood)
		s.box(root,Vector3(cx,height+0.05-0.04*(i%2),0),Vector3(cw+0.08,0.1,d+0.08),_wood(look,"trim","8d6744"))
		for x: float in [-cw*0.25,cw*0.25]:
			s.box(root,Vector3(cx+x,height*0.55,d/2+0.015),Vector3(cw*0.44,height*0.7,0.03),_wood(look,"panel","7d573d"))
			s.box(root,Vector3(cx+x*0.25,height*0.55,d/2+0.035),Vector3(0.1,0.16,0.02),"c9a35e")
		s.box(root,Vector3(cx,height*0.12,d/2+0.015),Vector3(cw*0.9,height*0.14,0.03),_wood(look,"panel","7d573d"))
	if look.has("cloth"):
		s.box(root,Vector3(w*0.1,height+0.18,0),Vector3(w*0.6,0.16,d*0.7),String(look["cloth"]))

## 长凳 against a wall, for waiting customers or gamblers, a cushion on it (`cloth`).
func _bench_seat(w: float, d: float, look: Dictionary) -> void:
	var wood: String = _wood(look,"wood","6e4d37")
	s.box(root,Vector3(0,0.46,0),Vector3(w,0.08,d),wood)
	for x: float in [-w/2+0.1,w/2-0.1]:
		s.box(root,Vector3(x,0.22,0),Vector3(0.08,0.44,d*0.8),wood)
	if look.has("cloth"):
		s.box(root,Vector3(0,0.52,0),Vector3(w*0.85,0.05,d*0.85),String(look["cloth"]))

## Lived-in odds and ends in a little heap by a wall (`items`: jar, bowls, basket, books,
## sandals, umbrella, broom, bucket, cups, bundle, gourd, abacus), low enough to walk round.
func _clutter(w: float, d: float, look: Dictionary) -> void:
	var items: Array = look.get("items",["jar","basket","bowls"])
	for i: int in items.size():
		var at := Vector3((float(i)/maxf(1,items.size()-1)-0.5)*w*0.7 if items.size()>1 else 0.0,0,sin(i*2.7)*d*0.25)
		match String(items[i]):
			"jar":
				s.box(root,at+Vector3(0,0.2,0),Vector3(0.3,0.38,0.3),_pick(["6b4a35","7b5a3e","5d7f78","8b5440"]))
				s.box(root,at+Vector3(0,0.42,0),Vector3(0.18,0.06,0.18),"b23a2b")
			"bowls":
				for b: int in 3:
					s.box(root,at+Vector3(0,0.03+b*0.05,0),Vector3(0.2,0.045,0.2),"d8d2c2")
			"basket":
				s.box(root,at+Vector3(0,0.15,0),Vector3(0.36,0.28,0.36),"a68a55")
				s.box(root,at+Vector3(0,0.3,0),Vector3(0.28,0.05,0.28),_pick(["d28a3a","6f9a4e","c9b98e"]))
			"books":
				for b: int in 3:
					s.box(root,at+Vector3(0.02*b,0.04+b*0.07,0),Vector3(0.32,0.06,0.24),["4e6967","ad8055","c9b98e"][b])
			"sandals":
				for x: float in [-0.08,0.08]:
					s.box(root,at+Vector3(x,0.02,0),Vector3(0.12,0.03,0.3),"b39a5c")
			"umbrella":
				s.tilted_box(root,at+Vector3(0,0.55,0),Vector3(0.14,1.1,0.14),"c9a24e",Vector3(0.2,0,0))
			"broom":
				s.tilted_box(root,at+Vector3(0,0.6,0),Vector3(0.04,1.2,0.04),"8a7044",Vector3(0.22,0,0))
				s.box(root,at+Vector3(0,0.1,-0.12),Vector3(0.22,0.2,0.08),"c4ad72")
			"bucket":
				s.box(root,at+Vector3(0,0.17,0),Vector3(0.3,0.32,0.3),"8a6a45")
				s.box(root,at+Vector3(0,0.32,0),Vector3(0.24,0.02,0.24),"3e5f63:gloss")
				s.box(root,at+Vector3(0,0.42,0),Vector3(0.3,0.03,0.03),"5a4130")
			"cups":
				s.box(root,at+Vector3(0,0.02,0),Vector3(0.3,0.03,0.2),"6a4c33")
				for c: int in 3:
					s.box(root,at+Vector3(-0.09+c*0.09,0.07,0),Vector3(0.06,0.07,0.06),"e3d5b4")
			"bundle":
				s.shard(root,at+Vector3(0,0.13,0),Vector3(0.4,0.26,0.32),_pick(["6b5a4a","4a6f8f","8a3a3a"]),i)
				s.box(root,at+Vector3(0,0.27,0),Vector3(0.06,0.04,0.34),"b09a6c")
			"gourd":
				s.box(root,at+Vector3(0,0.12,0),Vector3(0.2,0.22,0.2),"c9a24e")
				s.box(root,at+Vector3(0,0.28,0),Vector3(0.13,0.13,0.13),"c9a24e")
			"abacus":
				s.box(root,at+Vector3(0,0.03,0),Vector3(0.44,0.05,0.24),"4b4031")
				for bead: int in 6:
					s.box(root,at+Vector3(-0.15+bead*0.06,0.07,0),Vector3(0.04,0.04,0.18),"b79c66")

## 大通铺: a long raised sleeping platform for a household's servants, a row of folded quilts
## (`quilts`) and pillows along it, a step board in front, shoes left under the edge.
func _long_bed(w: float, d: float, look: Dictionary) -> void:
	var wood: String = _wood(look,"wood","6e5038")
	var along_x: bool = w>=d
	var length: float = maxf(w,d)
	var depth: float = minf(w,d)
	var frame := Node3D.new()
	frame.rotation.y = 0.0 if along_x else PI/2
	root.add_child(frame)
	if s.merged.has(root):
		s.merge(frame,s.merged[root])
	s.box(frame,Vector3(0,0.24,0),Vector3(length,0.48,depth),wood)
	s.box(frame,Vector3(0,0.5,0),Vector3(length-0.08,0.06,depth-0.08),"b49a6c")
	s.box(frame,Vector3(0,0.12,depth/2+0.12),Vector3(length*0.96,0.08,0.24),_wood(look,"step","7d5c3e"))
	var quilts: Array = look.get("quilts",["5a6e86","8a5a48","6f7f5a","a08a5a"])
	var places: int = maxi(2,floori(length/0.85))
	for i: int in places:
		var x: float = -length/2+(i+0.5)*length/places
		s.box(frame,Vector3(x,0.6,-depth*0.12),Vector3(0.62,0.16,depth*0.42),String(quilts[i%quilts.size()]))
		s.box(frame,Vector3(x,0.6,-depth*0.4),Vector3(0.36,0.12,0.18),"d8ccaa")
		if i%3==1:
			for side: float in [-0.09,0.09]:
				s.box(frame,Vector3(x+side,0.05,depth/2+0.34),Vector3(0.12,0.06,0.24),"4a3a2c")

## 炕: a brick sleeping platform warmed from beneath, its fire mouth at one end (cold: the
## servants are home for the winter only on frosty nights), a reed mat and a quilt chest on it.
func _kang(w: float, d: float, look: Dictionary) -> void:
	var brick: Array = look.get("colors",["8a6a54","7d5e4a","96755c"])
	for course: int in 4:
		s.box(root,Vector3(0,0.08+course*0.15,0),Vector3(w,0.15,d),String(brick[course%brick.size()]))
	s.box(root,Vector3(0,0.66,0),Vector3(w-0.06,0.05,d-0.06),"c2a876")
	for strip: int in floori((w-0.1)/0.12):
		s.box(root,Vector3(-w/2+0.1+strip*0.12,0.69,0),Vector3(0.02,0.012,d-0.1),"a88c5c")
	s.box(root,Vector3(w/2+0.02,0.25,0),Vector3(0.06,0.3,0.36),"1e1a17")
	s.box(root,Vector3(-w*0.25,0.86,-d*0.3),Vector3(w*0.38,0.3,d*0.3),"7a573c")
	s.box(root,Vector3(-w*0.25,1.04,-d*0.3),Vector3(w*0.34,0.08,d*0.26),"6b5a8a")

## 太师椅: a black lacquered armchair, its tall back with a carved panel, the arms stepped down,
## a footrest in front; set on a low dais (`dais`, its colour `dais_color`) in a hall.
func _grand_chair(w: float, d: float, look: Dictionary) -> void:
	var lacquer: String = _wood(look,"wood","1f1b19")
	var trim: String = _wood(look,"trim","b8923e")
	if look.get("dais",true):
		s.box(root,Vector3(0,0.08,0),Vector3(w,0.16,d),_wood(look,"dais_color","5c3f2b"))
	var y: float = 0.16 if look.get("dais",true) else 0.0
	s.box(root,Vector3(0,y+0.62,0),Vector3(w*0.72,0.12,d*0.62),lacquer)
	for x: float in [-w*0.32,w*0.32]:
		for z: float in [-d*0.26,d*0.26]:
			s.box(root,Vector3(x,y+0.3,z),Vector3(0.11,0.6,0.11),lacquer)
		s.box(root,Vector3(x,y+0.9,-d*0.02),Vector3(0.1,0.1,d*0.6),lacquer)
		s.box(root,Vector3(x,y+0.78,d*0.24),Vector3(0.09,0.3,0.09),lacquer)
	s.box(root,Vector3(0,y+1.25,-d*0.3),Vector3(w*0.72,1.15,0.12),lacquer)
	s.box(root,Vector3(0,y+1.3,-d*0.23),Vector3(w*0.36,0.62,0.04),"3a2a22")
	s.box(root,Vector3(0,y+1.3,-d*0.205),Vector3(w*0.2,0.3,0.02),trim)
	s.box(root,Vector3(0,y+1.87,-d*0.3),Vector3(w*0.82,0.1,0.16),lacquer)
	s.box(root,Vector3(0,y+0.7,0.02),Vector3(w*0.55,0.05,d*0.5),_wood(look,"cushion","7a2a24"))
	s.box(root,Vector3(0,y+0.08,d*0.38),Vector3(w*0.6,0.1,d*0.18),lacquer)
	if String(look.get("hide",""))=="tiger":
		# 虎皮披于军椅 (camp7.c): a tiger's skin thrown over the back and seat, its stripes, the
		# tail hanging down beside the leg.
		var fur: String = String(look.get("fur","c87a2a"))
		s.box(root,Vector3(0,y+0.74,0.02),Vector3(w*0.6,0.06,d*0.56),fur)
		s.box(root,Vector3(0,y+1.35,-d*0.2),Vector3(w*0.62,0.9,0.06),fur)
		for stripe: int in 4:
			s.box(root,Vector3(-w*0.22+stripe*w*0.15,y+0.775,0.0),Vector3(0.05,0.02,d*0.5),"1e1812")
			s.box(root,Vector3(0,y+1.0+stripe*0.2,-d*0.2+0.035),Vector3(w*0.5,0.04,0.02),"1e1812")
		s.tilted_box(root,Vector3(w*0.3,y+0.5,d*0.22),Vector3(0.06,0.5,0.06),fur,Vector3(0,0,0.3))

## 锯木架: a saw-horse with a log across it half cut through, the saw left in the cut, sawdust.
func _saw_horse(w: float, d: float) -> void:
	for x: float in [-w*0.3,w*0.3]:
		for side: float in [-1.0,1.0]:
			s.tilted_box(root,Vector3(x,0.32,side*0.12),Vector3(0.08,0.66,0.08),"7a5f43",Vector3(side*0.35,0,0))
	s.box(root,Vector3(0,0.62,0),Vector3(w*0.8,0.08,0.1),"6a5039")
	s.tilted_box(root,Vector3(0,0.78,0),Vector3(w*1.05,0.24,0.24),"8c6e4c",Vector3(0,0.2,0))
	s.box(root,Vector3(w*0.1,0.92,0),Vector3(0.02,0.28,0.5),"9aa0a0")
	s.box(root,Vector3(w*0.1,0.92,0.32),Vector3(0.05,0.08,0.18),"6a4c33")
	s.box(root,Vector3(0,0.012,0.1),Vector3(w*0.6,0.02,d*0.5),"c9ad7c")

## 石炉: a hearth of stacked stones with the fire in it (`fire`: "low" a few embers and a weak
## flame, "high" a blaze that lights the room 像白天似的, "none" cold ash and charred sticks), a
## pot on it steaming (`pot`), ash and a few sticks by it.
func _hearth(w: float, d: float, look: Dictionary) -> void:
	var stone: Array = look.get("colors",["6f6a5e","7c766a","666257","88816f"])
	var ring: int = maxi(8,roundi((w+d)*3.0))
	for i: int in ring:
		var a: float = i*TAU/ring
		for course: int in 2:
			s.shard(root,Vector3(cos(a)*w*0.4,0.14+course*0.24,sin(a)*d*0.4),Vector3(0.3,0.26,0.26),String(stone[(i+course)%stone.size()]),i+course,a)
	s.box(root,Vector3(0,0.05,0),Vector3(w*0.62,0.08,d*0.62),"2e2925")
	var high: bool = String(look.get("fire","low"))=="high"
	var cold: bool = String(look.get("fire","low"))=="none"
	for stick: int in 4:
		s.tilted_box(root,Vector3(0,0.16,0),Vector3(0.09,0.09,w*0.5),"2a2420" if cold else "4a3626",Vector3(0.3,stick*PI/4,0))
	if cold:
		s.box(root,Vector3(0,0.1,0),Vector3(w*0.45,0.05,d*0.45),"8e8a84")
		return
	for ember: int in 7:
		s.box(root,Vector3(sin(ember*2.3)*w*0.18,0.12,cos(ember*1.7)*d*0.18),Vector3(0.1,0.05,0.1),"e2703a:glow" if ember%2 else "b8452a:glow")
	var flames := Node3D.new()
	flames.position = Vector3(0,0.16,0)
	root.add_child(flames)
	for tongue: int in 7 if high else 3:
		var a: float = tongue*1.7
		var flame := Node3D.new()
		flame.position = Vector3(cos(a)*0.12,0,sin(a)*0.12)
		flames.add_child(flame)
		var tall: float = (0.75-tongue*0.06) if high else (0.26-tongue*0.04)
		s.box(flame,Vector3(0,tall/2,0),Vector3(0.14,tall,0.14),"ffb858:glow" if tongue%2 else "ffd88a:glow")
		if ambience != null:
			ambience.flame(flame)
	var light := OmniLight3D.new()
	light.position = Vector3(0,0.9,0)
	light.light_color = Color("ffa860")
	light.omni_range = 9.0 if high else 3.5
	light.set_meta("day_energy",1.6 if high else 0.35)
	light.set_meta("night_energy",3.0 if high else 0.9)
	light.set_meta("flicker",0.16 if high else 0.25)
	root.add_child(light)
	if look.get("pot",false):
		for leg: int in 3:
			var a: float = leg*TAU/3.0
			s.tilted_box(root,Vector3(cos(a)*w*0.34,0.55,sin(a)*d*0.34),Vector3(0.05,1.0,0.05),"3d3530",Vector3(-sin(a)*0.3,0,cos(a)*0.3))
		s.box(root,Vector3(0,0.62,0),Vector3(0.46,0.34,0.46),"2f2b28")
		s.box(root,Vector3(0,0.8,0),Vector3(0.5,0.04,0.5),"3a3632")
		if ambience != null:
			ambience.smoke(root,Vector3(0,0.9,0),"d8d4c8",4,0.18)
	for ash: int in 3:
		s.box(root,Vector3(w*0.45+ash*0.08,0.015,-d*0.2+ash*0.17),Vector3(0.16,0.02,0.12),"8a857c")
	if ambience != null and high:
		ambience.smoke(root,Vector3(0,1.4,0),"8d877c",5,0.26)

## 石床: a platform of dressed stone, a mat of straw on it (`mat` false: bare and dusty).
func _stone_bed(w: float, d: float, look: Dictionary) -> void:
	var stone: Array = look.get("colors",["7a7668","857f70","6e6b5f"])
	s.box(root,Vector3(0,0.24,0),Vector3(w,0.48,d),String(stone[0]))
	for block: int in maxi(2,roundi(w/0.7)):
		var x: float = -w/2+(block+0.5)*w/maxi(2,roundi(w/0.7))
		s.box(root,Vector3(x,0.24,d/2+0.01),Vector3(w/maxi(2,roundi(w/0.7))-0.04,0.42,0.03),String(stone[1+block%2]))
	s.box(root,Vector3(0,0.5,0),Vector3(w-0.06,0.05,d-0.06),String(stone[1]))
	if look.get("mat",true):
		s.box(root,Vector3(0,0.54,0),Vector3(w*0.84,0.04,d*0.8),"a4936a")
		s.box(root,Vector3(-w*0.34,0.6,0),Vector3(w*0.14,0.1,d*0.6),"8a7a58")
	else:
		for i: int in 6:
			s.box(root,Vector3(sin(i*2.1)*w*0.35,0.53,cos(i*1.3)*d*0.3),Vector3(0.2,0.012,0.14),"9a968a")

## 石椅: a seat cut from one stone, a slab for its back (`back` false: a block to sit on).
func _stone_seat(w: float, d: float, look: Dictionary) -> void:
	var stone: Array = look.get("colors",["7d7a6c","878274","716e62"])
	s.shard(root,Vector3(0,0.22,0),Vector3(w*0.82,0.44,d*0.72),String(stone[0]),int(look.get("seed",1)))
	s.box(root,Vector3(0,0.46,0.02),Vector3(w*0.76,0.06,d*0.64),String(stone[1]))
	if look.get("back",true):
		s.box(root,Vector3(0,0.92,-d*0.3),Vector3(w*0.8,0.9,0.14),String(stone[2]))
		s.box(root,Vector3(0,1.39,-d*0.3),Vector3(w*0.9,0.08,0.18),String(stone[1]))

## A vase with a spray of flowers standing at `at` (its foot): white jade (`vase`) holding peonies,
## chrysanthemums or 琼花 (`flowers`, a few colours).
func _vase(at: Vector3, vase: String, flowers: Array, tall: float = 0.42) -> void:
	s.box(root,at+Vector3(0,tall*0.3,0),Vector3(0.2,tall*0.6,0.2),vase)
	s.box(root,at+Vector3(0,tall*0.72,0),Vector3(0.12,tall*0.3,0.12),vase)
	s.box(root,at+Vector3(0,tall*0.9,0),Vector3(0.16,0.04,0.16),vase)
	for i: int in 5:
		var a: float = i*TAU/5.0
		var bloom := at+Vector3(cos(a)*0.14,tall+0.12+0.08*(i%2),sin(a)*0.12)
		s.box(root,bloom-Vector3(0,0.08,0),Vector3(0.03,0.16,0.03),"5a7a3a")
		s.box(root,bloom,Vector3(0.13,0.1,0.13),String(flowers[i%flowers.size()]))
	s.box(root,at+Vector3(0,tall+0.26,0),Vector3(0.12,0.1,0.12),String(flowers[0]))

## 大圆桌 (eat1.c, eat2.c): a round top of carved wood under its silk cloth (`cloth`, `border`),
## `seats` chairs round it turned to the middle (cane seats: `cane`), and on it `set`: "feast"
## (purple jade plates, porcelain bowls, gold chopsticks) or "meal" (bowls and a pot).
func _round_table(w: float, d: float, look: Dictionary) -> void:
	var wood: Array = look.get("colors",["8a5a3a","9a6640","7a4e32"])
	var r: float = minf(w,d)*0.31
	var top: float = 0.82
	s.box(root,Vector3(0,top*0.5,0),Vector3(0.3,top,0.3),String(wood[2]))
	s.box(root,Vector3(0,0.06,0),Vector3(r,0.12,r),String(wood[2]))
	for turn: float in [0.0,PI/4]:
		s.tilted_box(root,Vector3(0,top,0),Vector3(r*1.84,0.1,r*0.78),String(wood[0]),Vector3(0,turn,0))
		s.tilted_box(root,Vector3(0,top,0),Vector3(r*0.78,0.1,r*1.84),String(wood[0]),Vector3(0,turn,0))
	if look.has("cloth"):
		var cloth: String = String(look["cloth"])
		for turn: float in [0.0,PI/4]:
			s.tilted_box(root,Vector3(0,top+0.065,0),Vector3(r*1.7,0.03,r*0.72),cloth,Vector3(0,turn,0))
			s.tilted_box(root,Vector3(0,top+0.065,0),Vector3(r*0.72,0.03,r*1.7),cloth,Vector3(0,turn,0))
		for i: int in 8:
			var a: float = i*TAU/8.0+PI/8
			s.tilted_box(root,Vector3(cos(a)*r*0.92,top-0.06,sin(a)*r*0.92),Vector3(0.05,0.2,r*0.72),String(look.get("border","c9a24a")),Vector3(0,-a,0))
	var seats: int = int(look.get("seats",8))
	for i: int in seats:
		var a: float = i*TAU/seats
		var seat := Node3D.new()
		seat.position = Vector3(cos(a)*(r+0.42),0,sin(a)*(r+0.42))
		seat.rotation.y = -a-PI/2
		root.add_child(seat)
		if s.merged.has(root):
			s.merge(seat,s.merged[root])
		s.box(seat,Vector3(0,0.45,0),Vector3(0.42,0.08,0.4),String(look.get("cane",wood[1])))
		for x: float in [-0.16,0.16]:
			s.box(seat,Vector3(x,0.22,0.12),Vector3(0.06,0.44,0.06),String(wood[2]))
			s.box(seat,Vector3(x,0.62,-0.17),Vector3(0.06,0.82,0.06),String(wood[2]))
		s.box(seat,Vector3(0,0.86,-0.17),Vector3(0.4,0.12,0.05),String(wood[1]))
	var places: int = maxi(4,seats/2)
	var feast: bool = String(look.get("set","meal"))=="feast"
	for i: int in places:
		var a: float = i*TAU/places
		var at := Vector3(cos(a)*r*0.7,top+0.09,sin(a)*r*0.7)
		if feast:
			s.box(root,at,Vector3(0.24,0.025,0.24),"7a5a8a")
			s.box(root,at+Vector3(0,0.05,0),Vector3(0.13,0.07,0.13),"eeece6")
			s.tilted_box(root,at+Vector3(0.12,0.03,0),Vector3(0.02,0.015,0.24),"d8b04a",Vector3(0,a,0))
		else:
			s.box(root,at+Vector3(0,0.04,0),Vector3(0.14,0.08,0.14),"e2dccb")
	if feast:
		for i: int in 3:
			var a: float = i*TAU/3.0
			s.box(root,Vector3(cos(a)*r*0.28,top+0.12,sin(a)*r*0.28),Vector3(0.3,0.06,0.3),["eeece6","d8c8a8","c8d8d0"][i])
			s.box(root,Vector3(cos(a)*r*0.28,top+0.17,sin(a)*r*0.28),Vector3(0.18,0.06,0.18),["c84a2a","8a6a3a","5a8a4a"][i])
	else:
		_teapot(Vector3(0,top+0.07,0),"6c8a80")

## 紫檀雕案 in a row along a wall (latemoon1.c: 东西两面各设著七张): `count` carved tables,
## each with a white jade vase of flowers (`vase`, `flowers`); dark wood (`colors`), gilt `trim`.
func _table_row(w: float, d: float, look: Dictionary) -> void:
	var wood: Array = look.get("colors",["5a2e24","6a3828","4e2820"])
	var count: int = maxi(1,int(look.get("count",3)))
	var step: float = w/count
	for i: int in count:
		var x: float = -w/2+step*(i+0.5)
		var long: float = step-0.18
		s.box(root,Vector3(x,0.9,0),Vector3(long,0.08,d*0.86),String(wood[0]))
		s.box(root,Vector3(x,0.95,0),Vector3(long+0.06,0.04,d*0.92),String(wood[1]))
		for side: float in [-1.0,1.0]:
			s.box(root,Vector3(x+side*(long/2-0.06),0.45,0),Vector3(0.08,0.9,d*0.7),String(wood[2]))
			s.box(root,Vector3(x+side*(long/2-0.06),0.74,0),Vector3(0.1,0.04,d*0.82),String(look.get("trim","b8923e")))
		s.box(root,Vector3(x,0.78,d*0.4),Vector3(long-0.18,0.14,0.03),String(wood[1]))
		s.box(root,Vector3(x,0.78,d*0.42),Vector3(long*0.4,0.05,0.01),String(look.get("trim","b8923e")))
		_vase(Vector3(x,0.97,0),String(look.get("vase","eeece4")),look.get("flowers",["e8a0b4","f2c0cc"]))

## Chairs in a row (`count`, facing local +z): lacquered (`colors`), a cushion on each
## (`cushion`), a small tea table after every second chair (`tables`).
func _chair_row(w: float, d: float, look: Dictionary) -> void:
	var wood: Array = look.get("colors",["7a2a22","8a3226","6a241e"])
	var count: int = maxi(1,int(look.get("count",2)))
	var tables: bool = look.get("tables",false)
	# A table follows chairs 0, 2, 4… unless that chair is the last.
	var slots: int = count+(count/2 if tables else 0)
	var step: float = w/slots
	var slot: int = 0
	for i: int in count:
		var x: float = -w/2+step*(slot+0.5)
		var seat: float = minf(step*0.85,0.72)
		s.box(root,Vector3(x,0.5,0),Vector3(seat,0.08,d*0.7),String(wood[0]))
		for side: float in [-1.0,1.0]:
			s.box(root,Vector3(x+side*seat*0.4,0.25,d*0.25),Vector3(0.07,0.5,0.07),String(wood[2]))
			s.box(root,Vector3(x+side*seat*0.4,0.62,-d*0.3),Vector3(0.07,1.24,0.07),String(wood[2]))
			s.box(root,Vector3(x+side*seat*0.42,0.74,0),Vector3(0.06,0.06,d*0.6),String(wood[1]))
		s.box(root,Vector3(x,1.2,-d*0.3),Vector3(seat,0.1,0.07),String(wood[1]))
		s.box(root,Vector3(x,0.86,-d*0.31),Vector3(seat*0.5,0.6,0.04),String(wood[1]))
		if look.has("cushion"):
			s.box(root,Vector3(x,0.57,0.02),Vector3(seat*0.82,0.06,d*0.56),String(look["cushion"]))
			s.box(root,Vector3(x,0.82,-d*0.26),Vector3(seat*0.6,0.4,0.05),String(look["cushion"]))
		slot += 1
		if tables and i%2==0 and i<count-1:
			var tx: float = -w/2+step*(slot+0.5)
			s.box(root,Vector3(tx,0.64,-d*0.05),Vector3(step*0.7,0.06,d*0.6),String(wood[1]))
			for side: float in [-1.0,1.0]:
				s.box(root,Vector3(tx+side*step*0.28,0.32,-d*0.05),Vector3(0.06,0.64,d*0.5),String(wood[2]))
			s.box(root,Vector3(tx,0.72,-d*0.05),Vector3(0.1,0.1,0.1),"e2dccb")
			slot += 1

## 高几 / 小几: a small stand (`tall`: a high one) with what it holds (`holds`): "vase" (a vase of
## `flowers`), "ding" (文王鼎, a spoon and an incense box) or "tea"; `plum`: a top shaped like a
## plum blossom (梅花式), five round lobes.
func _side_table(w: float, d: float, look: Dictionary) -> void:
	var wood: Array = look.get("colors",["5a2e24","6a3828","4e2820"])
	var h: float = 1.1 if look.get("tall",false) else 0.62
	var top: float = minf(w,d)*0.8
	if look.get("plum",false):
		for i: int in 5:
			var a: float = i*TAU/5.0
			s.box(root,Vector3(cos(a)*top*0.22,h,sin(a)*top*0.22),Vector3(top*0.5,0.06,top*0.5),String(wood[0]))
	else:
		s.box(root,Vector3(0,h,0),Vector3(top,0.06,top),String(wood[0]))
	s.box(root,Vector3(0,h-0.07,0),Vector3(top*0.86,0.08,top*0.86),String(wood[1]))
	for x: float in [-top*0.36,top*0.36]:
		for z: float in [-top*0.36,top*0.36]:
			s.box(root,Vector3(x,h/2,z),Vector3(0.06,h,0.06),String(wood[2]))
	match String(look.get("holds","vase")):
		"ding":
			s.box(root,Vector3(0,h+0.18,0),Vector3(0.26,0.22,0.26),"6a5a3a")
			for i: int in 3:
				var a: float = i*TAU/3.0
				s.box(root,Vector3(cos(a)*0.09,h+0.06,sin(a)*0.09),Vector3(0.04,0.1,0.04),"5a4a30")
			for side: float in [-1.0,1.0]:
				s.box(root,Vector3(side*0.1,h+0.33,0),Vector3(0.03,0.1,0.08),"6a5a3a")
			s.box(root,Vector3(0.2,h+0.06,0.12),Vector3(0.12,0.08,0.1),"8a3226")
		"tea":
			_teapot(Vector3(0,h+0.03,0),"6c8a80")
		_:
			_vase(Vector3(0,h+0.03,0),String(look.get("vase","eeece4")),look.get("flowers",["e8a0b4"]),0.5 if look.get("tall",false) else 0.36)
