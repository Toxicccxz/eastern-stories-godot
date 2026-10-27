extends RefCounted

## Fittings and decor that block nothing (lamps, windows, rugs, signs, stairs) or that the
## street layout places (boards, stone lions, flagpoles). Same materials and batching.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var s: Shapes
var root: Node3D
var ambience: VoxelAmbience

func draw(shapes: Shapes, parent: Node3D, data: Dictionary, w: float, d: float) -> bool:
	s = shapes
	root = parent
	match String(data["kind"]):
		"curtain":
			s.box(root,Vector3(0,2.85,0),Vector3(w,0.12,0.12),"77583b")
			for side: float in [-1,1]:
				for fold: int in 4:
					s.box(root,Vector3(side*(w*0.34+fold*w*0.033),1.58,0.045*(fold%2)),Vector3(w*0.05,2.42,0.06),"465e80" if fold%2 else "5a7295")
				s.box(root,Vector3(side*w*0.39,1.40,0.08),Vector3(w*0.20,0.08,0.05),"b1a477")
			if data.has("text"):
				var label := Label3D.new()
				label.text = tr(String(data["text"]))
				label.position = Vector3(0,2.55,0.08)
				label.font_size = 32
				label.pixel_size = 0.005
				label.modulate = Color("d3c49c")
				root.add_child(label)
		"closed_door":
			s.box(root,Vector3(0,1.35,0),Vector3(w,2.7,0.12),"6b4d38")
			for i: int in 6:
				s.box(root,Vector3(-w*0.42+i*w*0.168,1.35,0.08),Vector3(w*0.15,2.56,0.08),"906d49")
			for y: float in [0.4,2.2]:
				s.box(root,Vector3(0,y,0.14),Vector3(w*0.94,0.13,0.06),"634b35")
			for x: float in [-0.12,0.12]:
				s.box(root,Vector3(x,1.2,0.17),Vector3(0.10,0.17,0.08),"ac9767")
		"straw_patch":
			for i: int in 32:
				var x: float = sin(i*7.13)*w*0.43
				var z: float = cos(i*4.31)*d*0.43
				s.tilted_box(root,Vector3(x,0.02+(i%3)*0.007,z),Vector3(0.035,0.014,0.20+(i%4)*0.07),"a49667" if i%2 else "b6aa7a",Vector3(0,i*0.91,0))
		"rug":
			var cloth: String = String(data.get("cloth","883f3f"))
			var border: String = String(data.get("border","bd9d62"))
			s.box(root,Vector3(0,0.018,0),Vector3(w,0.028,d),cloth)
			for x: float in [-w/2+0.08,w/2-0.08]:
				s.box(root,Vector3(x,0.036,0),Vector3(0.08,0.008,d-0.12),border)
			for z: float in [-d/2+0.08,d/2-0.08]:
				s.box(root,Vector3(0,0.036,z),Vector3(w-0.12,0.008,0.08),border)
			for x: int in floori(w/0.8):
				for z: int in floori(d/0.8):
					var motif := Vector3(-w/2+0.48+x*0.8,0.037,-d/2+0.48+z*0.8)
					s.tilted_box(root,motif,Vector3(0.09,0.008,0.09),String(data.get("motif","b7845e")),Vector3(0,PI/4,0))
		"lantern":
			# A street lantern on its post: by its place a little taller or shorter, its paper
			# a shade off its neighbours'.
			var vary: RandomNumberGenerator = Shapes.spot_rng(root.position)
			s.lantern(root,Vector3(0,1.5*vary.randf_range(0.9,1.1),0),true,Shapes.tinted(String(data.get("paper","ffb858")),vary,0.05),vary.randf_range(0.94,1.06))
			_set_lamp(root,0.5,1.1,4.0,float(data.get("flicker",0.0)))
		"hanging_lantern":
			var vary: RandomNumberGenerator = Shapes.spot_rng(root.position)
			var size: float = vary.randf_range(0.9,1.1)
			s.box(root,Vector3(0,3.85,0),Vector3(0.045,1.0,0.045),"594732")
			s.lantern(root,Vector3(0,3.15,0),false,Shapes.tinted(String(data.get("paper","ffb858")),vary,0.05),size)
			_set_lamp(root,0.65,1.7,8.0,float(data.get("flicker",0.0)))
		"pot": s.pot(root,Vector3.ZERO)
		"lamp_stand": _lamp_stand(data)
		"lantern_post": _lantern_post(data)
		"red_door":
			# `leaf`/`trim`: a door of another make (晚月庄's bronze door, its pale green arch door).
			# As wide as its doorway (a hall's 128 px one), never narrower than a 64 px one's.
			var wide: float = maxf(1.8,w-0.2)
			s.box(root,Vector3(0,1.25,0),Vector3(wide,2.5,0.2),String(data.get("leaf","a34736")))
			s.box(root,Vector3(0,2.58,0),Vector3(wide+0.2,0.12,0.3),"d5b37b")
			for x: float in [-wide/2+0.11,wide/2-0.11]:
				s.box(root,Vector3(x,1.25,0.12),Vector3(0.13,2.5,0.12),String(data.get("trim","bf8853")))
			for y: float in [0.38,1.52,2.1]:
				s.box(root,Vector3(0,y,0.13),Vector3(wide-0.2,0.09,0.10),String(data.get("trim","c09563")))
			s.box(root,Vector3(0,1.0,0.15),Vector3(0.035,2.0,0.04),"65432e")
			for x: float in [-wide/2-0.03,wide/2+0.03]:
				s.box(root,Vector3(x,1.3,0.13),Vector3(0.035,2.58,0.025),"e0eadb")
			s.box(root,Vector3(0,2.62,0.13),Vector3(wide+0.1,0.035,0.025),"e0eadb")
			var glow: StandardMaterial3D = s.material("e0eadb")
			glow.emission_enabled = true
			glow.emission = Color("dcebdc")
			glow.emission_energy_multiplier = 0.65
			var light := OmniLight3D.new()
			light.position = Vector3(0,1.3,0.4)
			light.light_color = Color("e4f3e8")
			light.light_energy = 0.4
			light.set_meta("night_energy",0.55)
			light.omni_range = 3.5
			root.add_child(light)
		"board":
			for x: float in [-0.85,0.85]:
				s.box(root,Vector3(x,1,0),Vector3(0.15,2,0.15),"826a48")
			s.box(root,Vector3(0,1.45,0),Vector3(1.8,0.9,0.16),"a38b60")
			for x: float in [-0.5,0,0.5]:
				s.box(root,Vector3(x,1.5,0.1),Vector3(0.35,0.6,0.03),"e4d4aa")
		"stairs":
			# A flight up a floor (`colors`: steps, posts, rail; timber unless set, 白石梯 white).
			var colors: Array = data.get("colors",["96724c","715239","936c45"])
			for i: int in 6:
				s.box(root,Vector3(0,0.07+i*0.10,d/2-i*d/6),Vector3(w,0.14+i*0.2,d/6),String(colors[0]))
			for x: float in [-w*0.47,w*0.47]:
				for i: int in 4:
					s.box(root,Vector3(x,0.35+i*0.15,d*0.4-i*d*0.25),Vector3(0.10,0.7+i*0.3,0.10),String(colors[1]))
				s.tilted_box(root,Vector3(x,0.95,0),Vector3(0.12,0.12,d*1.04),String(colors[2]),Vector3(0.4,0,0))
		"window":
			s.box(root,Vector3(0,2,0),Vector3(w,1.65,0.18),"745438")
			s.box(root,Vector3(0,2,0.10),Vector3(w-0.18,1.46,0.04),"a4b7af")
			for x: int in 5:
				s.box(root,Vector3(-w*0.4+x*w*0.2,2,0.14),Vector3(0.065,1.52,0.055),"886744")
			for y: float in [1.32,1.78,2.24,2.70]:
				s.box(root,Vector3(0,y,0.15),Vector3(w,0.06,0.06),"886744")
			s.box(root,Vector3(0,1.16,0.20),Vector3(w+0.2,0.12,0.44),"a37c52")
			if data.get("shut",false):
				# 门窗都紧紧的关著: wooden shutters closed over it, a bar across; no light comes in.
				for leaf: float in [-1.0,1.0]:
					s.box(root,Vector3(leaf*(w/4-0.02),2,0.19),Vector3(w/2-0.06,1.5,0.05),"6e5038")
				s.box(root,Vector3(0,2,0.23),Vector3(w-0.1,0.08,0.04),"4a3626")
				return true
			var light := SpotLight3D.new()
			light.position = Vector3(0,2.4,0.40)
			light.rotation_degrees = Vector3(-35,180,0)
			light.light_color = Color("e1d7ae")
			light.spot_range = 9.0
			light.spot_angle = 52
			light.spot_attenuation = 0.75
			light.set_meta("day_energy",1.2)
			light.set_meta("night_energy",0.10)
			root.add_child(light)
		"stairwell":
			# A real recess in the floor; entering still uses the authored 2D portal.
			s.box(root,Vector3(0,-1.30,0),Vector3(w,0.12,d),"302b26")
			s.box(root,Vector3(0,-0.65,d/2-0.04),Vector3(w,1.30,0.08),"47372b")
			for i: int in 5:
				var h: float = -0.06-i*0.24
				s.box(root,Vector3(0,h-0.09,-d/2+(i+0.5)*d/5),Vector3(w-0.24,0.18,d/5),["b58e5c","a07b4f","87653f","6c5135","503e2c"][i])
				s.box(root,Vector3(0,h+0.008,-d/2+i*d/5+0.025),Vector3(w-0.27,0.025,0.035),"c5a677" if i<2 else "8c7049")
			for x: float in [-w/2+0.06,w/2-0.06]:
				s.box(root,Vector3(x,-0.58,0),Vector3(0.12,1.36,d),"715238")
				for i: int in 3:
					s.box(root,Vector3(x,0.45,-d/2+0.06+i*(d-0.12)/2),Vector3(0.10,0.9,0.10),"715239")
				s.box(root,Vector3(x,0.93,0),Vector3(0.15,0.12,d+0.04),"b39160")
			s.box(root,Vector3(0,0.045,-d/2-0.08),Vector3(w+0.16,0.09,0.16),"bba071")
			for z: float in [-d/2-0.46,-d/2-0.83]:
				for side: float in [-1,1]:
					s.tilted_box(root,Vector3(side*0.14,0.058,z),Vector3(0.09,0.035,0.39),"c4ab76",Vector3(0,side*PI/4,0))
			s.lantern(root,Vector3(-w/2-0.28,1.55,-d/2+0.08),true)
			_set_lamp(root,0.45,1.15,4.2)
		"drop":
			# 挑空: an upper floor's opening over a tall hall (west_2f.c: 侧厅是挑高建筑): the walls
			# going down and, far below, the hall's own floor and a table in the lamplight.
			var depth: float = float(data.get("depth",3.4))
			s.box(root,Vector3(0,-depth,0),Vector3(w,0.12,d),String(data.get("below","7a5a3e")))
			for board: int in floori(w/0.5):
				s.box(root,Vector3(-w/2+0.25+board*0.5,-depth+0.065,0),Vector3(0.02,0.012,d),"5e4430")
			for side: float in [-1.0,1.0]:
				s.box(root,Vector3(0,-depth/2,side*d/2),Vector3(w,depth,0.08),"4a3628")
				s.box(root,Vector3(side*w/2,-depth/2,0),Vector3(0.08,depth,d),"4a3628")
			s.box(root,Vector3(-w*0.18,-depth+0.82,0),Vector3(1.2,0.08,0.7),"8a6040")
			for x: float in [-w*0.18-0.5,-w*0.18+0.5]:
				s.box(root,Vector3(x,-depth+0.42,0),Vector3(0.08,0.8,0.08),"5c4030")
			s.box(root,Vector3(w*0.28,-depth+0.2,d*0.1),Vector3(0.9,0.06,0.9),String(data.get("rug","8a3a30")))
			var glow := OmniLight3D.new()
			glow.position = Vector3(0,-depth+1.4,0)
			glow.light_color = Color("ffc27a")
			glow.omni_range = 4.0
			glow.set_meta("day_energy",0.6)
			glow.set_meta("night_energy",1.2)
			root.add_child(glow)
		"runner":
			s.box(root,Vector3(0,0.018,0),Vector3(w,0.028,d),String(data.get("cloth","485f61")))
			for z: float in [-d*0.44,d*0.44]:
				s.box(root,Vector3(0,0.036,z),Vector3(w,0.008,0.06),"bca270")
		"sign":
			# A board with its words (`board`, `letters`, `height` above the floor, `tall`); long
			# words wrap within the board (`wrap`: true).
			var y: float = float(data.get("height",1.7))
			var tall: float = float(data.get("tall",0.9))
			s.box(root,Vector3(0,y,0),Vector3(w,tall,0.12),String(data.get("board","463b2d")))
			if data.has("frame"):
				s.box(root,Vector3(0,y,-0.02),Vector3(w+0.14,tall+0.14,0.1),String(data["frame"]))
			var title := Label3D.new()
			title.text = tr(String(data.get("text","")))
			title.position = Vector3(0,y,0.075)
			title.pixel_size = float(data.get("pixel_size",0.006))
			title.font_size = 40
			title.modulate = Color(String(data.get("letters","e3c38b")).get_slice(":",0))
			title.outline_size = 0
			if data.get("wrap",false):
				title.width = (w-0.1)/title.pixel_size
				title.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			root.add_child(title)
			if String(data.get("letters","")).ends_with(":glow"):
				for edge: float in [-1.0,1.0]:
					s.box(root,Vector3(0,y+edge*(tall/2-0.05),0.075),Vector3(w-0.12,0.035,0.02),String(data["letters"]))
		"stone_lion": _stone_lion(data)
		"drum": _drum(w,d,data)
		"flagpole":
			s.box(root,Vector3(0,0.12,0),Vector3(0.7,0.24,0.7),"8c8a7f")
			s.box(root,Vector3(0,3.2,0),Vector3(0.16,6.4,0.16),"6e5038")
			s.box(root,Vector3(0,6.45,0),Vector3(0.24,0.14,0.24),"c9a35e")
			s.box(root,Vector3(0.62,6.33,0),Vector3(1.2,0.07,0.07),"6e5038")
			# `flutter`: the cloth on a node of its own that stirs in the wind about the pole.
			var cloth: Node3D = root
			if data.get("flutter",false):
				cloth = Node3D.new()
				cloth.position = Vector3(0.08,5.2,0)
				root.add_child(cloth)
				if ambience != null:
					ambience.flutter(cloth,root.position.x*0.7)
			var at: Vector3 = Vector3(0.54,0,0) if cloth != root else Vector3(0.62,5.2,0)
			s.box(cloth,at,Vector3(1.1,2.2,0.04),String(data.get("cloth","b8432f")))
			var title := Label3D.new()
			title.text = tr(String(data.get("text","")))
			title.position = at+Vector3(0,0,0.03)
			title.pixel_size = 0.009
			title.font_size = 52
			title.width = 120.0
			title.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			title.modulate = Color("f1d9a0")
			title.outline_size = 0
			cloth.add_child(title)
		"bear_skin":
			# 熊皮 (keep3.c): a great bear's hide spread flat, head and paws at its corners.
			var fur: String = String(data.get("fur","4a3426"))
			var dark: String = String(data.get("dark","3a281d"))
			s.box(root,Vector3(0,0.025,0),Vector3(w*0.62,0.04,d*0.78),fur)
			s.box(root,Vector3(0,0.03,0),Vector3(w*0.3,0.042,d*0.5),dark)
			for side: float in [-1.0,1.0]:
				for end: float in [-1.0,1.0]:
					s.tilted_box(root,Vector3(side*w*0.38,0.024,end*d*0.3),Vector3(w*0.26,0.035,d*0.12),fur,Vector3(0,side*end*0.5,0))
					for claw: int in 3:
						s.box(root,Vector3(side*w*0.5,0.03,end*d*0.3+(claw-1)*0.07),Vector3(0.08,0.03,0.025),"d8d0bc")
			s.box(root,Vector3(0,0.09,d*0.45),Vector3(w*0.22,0.16,d*0.18),fur)
			s.box(root,Vector3(0,0.07,d*0.56),Vector3(w*0.12,0.1,d*0.08),dark)
			for side: float in [-1.0,1.0]:
				s.box(root,Vector3(side*w*0.08,0.19,d*0.42),Vector3(0.08,0.06,0.06),fur)
		"stains":
			# Dark wet patches on a floor (blood under a butcher's rack, spilt wine), flat.
			var colors: Array = data.get("colors",["5e2a26","6e3430","4e2422"])
			for i: int in int(data.get("count",6)):
				var at := Vector3(sin(i*5.17)*w*0.42,0.013+i*0.0005,cos(i*3.91)*d*0.42)
				s.tilted_box(root,at,Vector3(0.18+0.12*absf(sin(i*2.3)),0.006,0.12+0.1*absf(cos(i*1.7))),String(colors[i%colors.size()]),Vector3(0,i*0.9,0))
		"silk_curtain":
			# 亮晶晶的帘幕 (passage.c): very thin silk in hanging strips, shimmering and stirring
			# in the draught from the water behind it.
			var height: float = float(data.get("height",2.6))
			s.box(root,Vector3(0,height+0.06,0),Vector3(w+0.2,0.1,0.1),String(data.get("rod","8a6a32")))
			var colors: Array = data.get("colors",["d8e4e8","c4d6dc","e8f0f2"])
			for i: int in ceili(w/0.22):
				var strip := Node3D.new()
				strip.position = Vector3(-w/2+0.11+i*0.22,height,0)
				root.add_child(strip)
				s.box(strip,Vector3(0,-height/2,0),Vector3(0.2,height,0.02),String(colors[i%colors.size()])+":gloss")
				if ambience != null:
					ambience.sway(strip,i*0.7,0.05)
		"chained_door":
			# cave0.c: 一道厚厚的木门, 上面用一条手臂粗的铁链拴著 — thick planks, iron bands, the
			# chain hung across in links as thick as an arm, a padlock; frost at its foot.
			var wood: Array = data.get("colors",["5a4634","64503c","4e3d2e"])
			s.box(root,Vector3(0,1.2,0),Vector3(w,2.4,0.3),String(wood[2]))
			for plank: int in maxi(3,roundi(w/0.32)):
				var x: float = -w/2+(plank+0.5)*w/maxi(3,roundi(w/0.32))
				s.box(root,Vector3(x,1.18+sin(plank*2.1)*0.03,0.16),Vector3(w/maxi(3,roundi(w/0.32))-0.03,2.3,0.06),String(wood[plank%2]))
			for y: float in [0.45,1.95]:
				s.box(root,Vector3(0,y,0.21),Vector3(w*0.96,0.12,0.04),"3b3936")
			var links: int = maxi(5,roundi(w/0.22))
			for link: int in links:
				var t: float = float(link)/(links-1)
				var at := Vector3(-w*0.46+t*w*0.92,1.25-sin(t*PI)*0.32,0.3)
				s.tilted_box(root,at,Vector3(0.2,0.11,0.07) if link%2 else Vector3(0.2,0.07,0.11),"4a4744" if link%3 else "5a5450",Vector3(0,0,(t-0.5)*0.7))
			s.box(root,Vector3(0,0.86,0.34),Vector3(0.22,0.26,0.1),"5d564c")
			s.box(root,Vector3(0,1.02,0.34),Vector3(0.12,0.1,0.06),"3e3a35")
			for x: float in [-w*0.46,w*0.46]:
				s.box(root,Vector3(x,1.25,0.28),Vector3(0.1,0.18,0.1),"3b3936")
			for i: int in 5:
				s.box(root,Vector3(-w*0.4+i*w*0.2,0.03,0.42),Vector3(0.18,0.03,0.12),"c9d3d6")
		"stone_door":
			# entrance.c: 一扇大石门, 门上苔迹斑斑 — one slab in a frame of rough blocks, its
			# face carved in panels, moss creeping up it, a crack across.
			var stone: Array = data.get("colors",["6e7266","787b6e","646a5e"])
			var moss: Array = data.get("moss",["4d6a3c","5d7a45","3f5a33"])
			s.box(root,Vector3(0,1.3,0),Vector3(w,2.6,0.34),String(stone[0]))
			for y: float in [0.75,1.85]:
				s.box(root,Vector3(0,y,0.18),Vector3(w*0.78,0.78,0.04),String(stone[1]))
			s.tilted_box(root,Vector3(w*0.1,1.4,0.2),Vector3(w*0.5,0.03,0.03),"3c3d36",Vector3(0,0,0.5))
			for side: float in [-1.0,1.0]:
				for course: int in 5:
					s.shard(root,Vector3(side*(w/2+0.12),0.3+course*0.55,0),Vector3(0.36,0.55,0.5),String(stone[(course+int(side>0))%stone.size()]),course+int(side>0)*5)
			s.box(root,Vector3(0,2.78,0),Vector3(w+0.6,0.36,0.52),String(stone[2]))
			for i: int in 14:
				var x: float = sin(i*7.7)*w*0.45
				var y: float = absf(sin(i*3.1))*(1.4 if i%3 else 2.5)+0.05
				s.box(root,Vector3(x,y,0.2),Vector3(0.16+0.1*(i%3),0.12+0.08*(i%2),0.04),String(moss[i%moss.size()]))
		"wall_sword":
			# outdoor.c: 东首墙上挂这一把木剑 — a plain wooden sword on two pegs.
			var y: float = float(data.get("height",1.7))
			for x: float in [-0.3,0.3]:
				s.box(root,Vector3(x,y-0.02,0.06),Vector3(0.06,0.06,0.12),"5a4634")
			s.box(root,Vector3(0.1,y+0.04,0.1),Vector3(1.05,0.07,0.035),String(data.get("blade","a47c4e")))
			s.box(root,Vector3(-0.47,y+0.04,0.1),Vector3(0.05,0.22,0.06),"6b4a32")
			s.box(root,Vector3(-0.6,y+0.04,0.1),Vector3(0.22,0.06,0.05),"7a5a3e")
			s.box(root,Vector3(-0.74,y+0.04,0.1),Vector3(0.05,0.05,0.05),"b23a2b")
		_:
			return false
	return true

## A lamp's reach and its day and night strength; `flicker` makes its flame waver (灯火摇曳).
## 纯金铸成的长灯架上挂了一排饰丽的宫灯 (晚月庄's corridors): a gilded standard on a square foot,
## its arm hung with two palace lanterns (lacquered frames, glowing paper sides, red tassels);
## one light for the pair.
## A crouching guardian on its plinth, facing +z, in its own greys; `colors` (plinth, body, light,
## dark — an iron lion in blacks) recolours it; `standing` (w_street1.c: 姿势是立著的, 而且大小要
## 大得多): upright on its four legs, head high, half again as tall; `mark`: the character cut in
## its forehead.
func _stone_lion(data: Dictionary) -> void:
	var tones: Array = data.get("colors",[]).duplicate()
	for missing: int in range(tones.size(),4):
		tones.append(["8f8f86","b1b0a4","b8b7ab","9d9c90"][missing])
	var plinth: String = String(tones[0])
	var body: String = String(tones[1])
	var light: String = String(tones[2])
	var dark: String = String(tones[3])
	if not data.has("colors") and not data.get("standing",false):
		# The lion every region has had: its eight shades as they were.
		s.box(root,Vector3(0,0.25,0),Vector3(0.9,0.5,0.9),"8f8f86")
		s.box(root,Vector3(0,0.53,0),Vector3(1.0,0.08,1.0),"a3a398")
		s.box(root,Vector3(0,0.95,-0.12),Vector3(0.62,0.72,0.62),"b1b0a4")
		s.box(root,Vector3(0,1.48,0.10),Vector3(0.58,0.52,0.50),"b8b7ab")
		s.box(root,Vector3(0,1.62,0.05),Vector3(0.74,0.36,0.44),"9d9c90")
		s.box(root,Vector3(0,1.40,0.37),Vector3(0.30,0.18,0.10),"8e8d82")
		for x: float in [-0.17,0.17]:
			s.box(root,Vector3(x,0.72,0.26),Vector3(0.18,0.38,0.22),"a9a89c")
		s.box(root,Vector3(-0.24 if data.get("mirror",false) else 0.24,0.70,0.36),Vector3(0.24,0.20,0.24),"9a998d")
		return
	if data.get("standing",false):
		s.box(root,Vector3(0,0.3,0),Vector3(1.1,0.6,1.5),plinth)
		s.box(root,Vector3(0,0.64,0),Vector3(1.2,0.08,1.6),light)
		for x: float in [-0.26,0.26]:
			for z: float in [-0.45,0.4]:
				s.box(root,Vector3(x,1.08,z),Vector3(0.22,0.8,0.24),dark)
		s.box(root,Vector3(0,1.72,-0.08),Vector3(0.78,0.74,1.3),body)
		s.box(root,Vector3(0,2.0,0.0),Vector3(0.62,0.3,0.8),light)
		# The mane in curls, the head raised, the jaw open, the tail curled over the back.
		for curl: int in 8:
			var a: float = curl*TAU/8.0
			s.box(root,Vector3(cos(a)*0.4,2.2+sin(a)*0.34,0.5),Vector3(0.2,0.2,0.2),dark if curl%2 else light)
		s.box(root,Vector3(0,2.32,0.66),Vector3(0.6,0.56,0.5),light)
		s.box(root,Vector3(0,2.1,0.95),Vector3(0.34,0.2,0.16),dark)
		s.box(root,Vector3(0,2.5,0.9),Vector3(0.44,0.2,0.1),body)
		for x: float in [-0.16,0.16]:
			s.box(root,Vector3(x,2.46,0.92),Vector3(0.08,0.08,0.04),"2a2622")
		s.tilted_box(root,Vector3(0,2.3,-0.7),Vector3(0.14,0.7,0.14),dark,Vector3(-0.6,0,0))
		if data.has("mark"):
			var mark := Label3D.new()
			mark.text = tr(String(data["mark"]))
			mark.position = Vector3(0,2.62,0.92)
			mark.pixel_size = 0.004
			mark.font_size = 44
			mark.outline_size = 0
			mark.modulate = Color("3a3a36")
			root.add_child(mark)
		return
	s.box(root,Vector3(0,0.25,0),Vector3(0.9,0.5,0.9),plinth)
	s.box(root,Vector3(0,0.53,0),Vector3(1.0,0.08,1.0),light)
	s.box(root,Vector3(0,0.95,-0.12),Vector3(0.62,0.72,0.62),body)
	s.box(root,Vector3(0,1.48,0.10),Vector3(0.58,0.52,0.50),light)
	s.box(root,Vector3(0,1.62,0.05),Vector3(0.74,0.36,0.44),dark)
	s.box(root,Vector3(0,1.40,0.37),Vector3(0.30,0.18,0.10),dark)
	for x: float in [-0.17,0.17]:
		s.box(root,Vector3(x,0.72,0.26),Vector3(0.18,0.38,0.22),body)
	# The ball under one forepaw; `mirror`: the other paw (the pair either side of a door).
	s.box(root,Vector3(-0.24 if data.get("mirror",false) else 0.24,0.70,0.36),Vector3(0.24,0.20,0.24),dark)

## 大皮鼓 (court1.c: 门口有一面大皮鼓, 让百姓击鼓申冤用的): a great drum on its stand, red body
## with brass studs, the hide pale, a mallet leaning on the frame.
func _drum(w: float, d: float, data: Dictionary) -> void:
	var red: String = String(data.get("body","9a2e24"))
	var frame: String = String(data.get("frame","5a3a28"))
	var r: float = minf(w,d)*0.42
	for x: float in [-w*0.4,w*0.4]:
		s.box(root,Vector3(x,0.5,0),Vector3(0.12,1.0,0.5),frame)
	s.box(root,Vector3(0,0.3,0),Vector3(w*0.9,0.1,0.14),frame)
	for i: int in 3:
		var a: float = i*PI/3.0
		s.tilted_box(root,Vector3(0,1.0,0),Vector3(r*2,0.6,r*2*0.82),red,Vector3(PI/2,a,0))
	s.tilted_box(root,Vector3(0,1.0,0.31),Vector3(r*1.7,r*1.7,0.03),String(data.get("hide","e8d8b0")),Vector3(0,0,PI/4))
	s.tilted_box(root,Vector3(0,1.0,-0.31),Vector3(r*1.7,r*1.7,0.03),String(data.get("hide","e8d8b0")),Vector3(0,0,PI/4))
	for stud: int in 10:
		var a: float = stud*TAU/10.0
		s.box(root,Vector3(cos(a)*r*0.95,1.0+sin(a)*r*0.95,0.3),Vector3(0.05,0.05,0.05),"d6b25a")
	s.tilted_box(root,Vector3(w*0.4,0.7,0.3),Vector3(0.05,0.9,0.05),"c8a870",Vector3(0,0,0.5))
	s.box(root,Vector3(w*0.4-0.2,1.1,0.3),Vector3(0.1,0.12,0.1),"8a2a22")

func _lamp_stand(data: Dictionary) -> void:
	var gold: String = String(data.get("gold","c9a24a"))
	var dark: String = String(data.get("shade","a07a32"))
	s.box(root,Vector3(0,0.08,0),Vector3(0.46,0.16,0.46),dark)
	s.box(root,Vector3(0,0.2,0),Vector3(0.3,0.1,0.3),gold)
	s.box(root,Vector3(0,1.55,0),Vector3(0.1,2.8,0.1),gold)
	for y: float in [0.9,1.9]:
		s.box(root,Vector3(0,y,0),Vector3(0.16,0.08,0.16),dark)
	s.box(root,Vector3(0,2.92,0),Vector3(1.3,0.08,0.08),gold)
	s.box(root,Vector3(0,3.0,0),Vector3(0.14,0.14,0.14),dark)
	var paper: String = String(data.get("paper","f0c878:glow"))
	for side: float in [-0.56,0.56]:
		var at := Vector3(side,2.45,0)
		s.box(root,at+Vector3(0,0.36,0),Vector3(0.03,0.2,0.03),gold)
		s.box(root,at,Vector3(0.36,0.44,0.36),paper)
		for y: float in [-0.25,0.25]:
			s.box(root,at+Vector3(0,y,0),Vector3(0.46,0.06,0.46),"8a2a22")
		for x: float in [-0.2,0.2]:
			for z: float in [-0.2,0.2]:
				s.box(root,at+Vector3(x,0,z),Vector3(0.05,0.5,0.05),"8a2a22")
		s.box(root,at+Vector3(0,-0.42,0),Vector3(0.05,0.3,0.05),"c8382a")
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0,2.4,0)
	lamp.light_color = Color("ffc878")
	root.add_child(lamp)
	_set_lamp(root,0.6,2.4,5.0,float(data.get("flicker",0.04)))

## gate.c: 门口挂著两串灯笼 — a red post with a string of lanterns down from its bracket
## (`count`), the lowest lit at night.
func _lantern_post(data: Dictionary) -> void:
	s.box(root,Vector3(0,0.1,0),Vector3(0.4,0.2,0.4),"6a6258")
	s.box(root,Vector3(0,1.6,0),Vector3(0.14,3.2,0.14),"8a2a22")
	s.box(root,Vector3(0.3,3.15,0),Vector3(0.7,0.1,0.1),"8a2a22")
	var count: int = int(data.get("count",3))
	for i: int in count:
		var at := Vector3(0.55,2.75-i*0.52,0)
		s.box(root,at+Vector3(0,0.28,0),Vector3(0.03,0.12,0.03),"594732")
		s.box(root,at,Vector3(0.36,0.38,0.36),"d8452f:glow")
		for y: float in [-0.2,0.2]:
			s.box(root,at+Vector3(0,y,0),Vector3(0.3,0.05,0.3),"2a2420")
		s.box(root,at+Vector3(0,0,0.185),Vector3(0.14,0.18,0.01),"f2d27a")
	s.box(root,Vector3(0.55,2.75-count*0.52+0.2,0),Vector3(0.04,0.22,0.04),"c8382a")
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.55,2.2,0)
	lamp.light_color = Color("ff9a68")
	root.add_child(lamp)
	_set_lamp(root,0.5,2.0,4.5,0.05)

func _set_lamp(node: Node3D, day: float, night: float, radius: float, flicker: float = 0.0) -> void:
	for child: Node in node.get_children():
		if child is OmniLight3D:
			(child as OmniLight3D).omni_range = radius
			child.set_meta("day_energy",day)
			child.set_meta("night_energy",night)
			if flicker > 0.0:
				child.set_meta("flicker",flicker)

