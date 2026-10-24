extends RefCounted

## Reusable barren-country props. Blocking instances come only from Furnishings.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var s: Shapes
var root: Node3D

func draw(shapes: Shapes, parent: Node3D, data: Dictionary, w: float, d: float) -> bool:
	s = shapes
	root = parent
	var stone: String = String(data.get("stone","8d7959"))
	var dark: String = String(data.get("dark","584e40"))
	var wood: String = String(data.get("wood","66503a"))
	var height: float = float(data.get("height",2.2))
	match String(data["kind"]):
		"cave_mouth":
			# The recess starts at a real passage; its roof is above the walk line.
			for x: float in [-w*0.45,w*0.45]:
				for i: int in 3:
					s.shard(root,Vector3(x,height*(i+0.5)/3,d*0.3),Vector3(w*0.22,height/3,d),stone,i)
			s.shard(root,Vector3(0,height,d*0.32),Vector3(w*1.08,0.65,d*1.2),stone,5)
			s.box(root,Vector3(0,height*0.43,d*0.76),Vector3(w*0.73,height*0.86,0.035),dark)
			s.box(root,Vector3(0,0.025,d*0.35),Vector3(w*0.72,0.03,d*0.88),dark)
		"stone_hut", "cleft_shrine":
			var shrine: bool = data["kind"]=="cleft_shrine"
			var h: float = 2.6 if shrine else 3.0
			s.box(root,Vector3(0,h/2,0),Vector3(w,h,d),"ab8d5b" if shrine else stone)
			for z: int in maxi(2,roundi(d/0.65)):
				s.box(root,Vector3(-w*0.505,h*0.5,-d/2+0.3+z*0.65),Vector3(0.025,0.035,0.52),dark)
			# The west opening is visual only, aligned to the original passage.
			s.box(root,Vector3(-w/2-0.012,1.1,0),Vector3(0.03,2.2,minf(d*0.5,2.1)),"292a23")
			for y: int in 5:
				s.box(root,Vector3(0,h+y*0.13,0),Vector3(w+0.30,d*0.0+0.14,d*(1.14-y*0.15)),"665f49" if shrine else "595d50")
			if shrine:
				for z: float in [-1.15,1.15]:
					s.box(root,Vector3(-w/2-0.04,1.15,z),Vector3(0.04,1.65,0.13),"963e2c")
		"campfire":
			for i: int in 10:
				var a: float = i*TAU/10
				s.shard(root,Vector3(cos(a)*w*0.37,0.10,sin(a)*d*0.37),Vector3(w*0.21,0.20,d*0.20),stone,i,a)
			for i: int in 3:
				s.tilted_box(root,Vector3(0,0.14+i*0.05,0),Vector3(w*0.65,0.12,0.13),"4c392a",Vector3(0,i*1.2,0))
			s.box(root,Vector3(0,0.14,0),Vector3(w*0.3,0.04,d*0.3),"ca6128")
			var fire := OmniLight3D.new()
			fire.position.y = 0.9
			fire.light_color = Color("ffab52")
			fire.light_energy = 1.1
			fire.set_meta("night_energy",1.8)
			fire.omni_range = 6.0
			root.add_child(fire)
		"flag_pole":
			s.tilted_box(root,Vector3(0,height/2,0),Vector3(0.09,height,0.09),wood,Vector3(0,0,0.07))
			s.shard(root,Vector3(0,0.15,0),Vector3(w,0.3,d),stone,3)
		"weathered_rock":
			s.shard(root,Vector3(0,height*0.28,0),Vector3(w,height*0.56,d),stone,2)
			s.shard(root,Vector3(-w*0.035,height*0.68,d*0.025),Vector3(w*0.83,height*0.36,d*0.87),stone,5)
			s.shard(root,Vector3(w*0.06,height*0.92,-d*0.06),Vector3(w*0.56,height*0.17,d*0.61),stone,3)
		"stalagmite":
			for i: int in 5:
				var t: float = i/5.0
				s.shard(root,Vector3(sin(i*2.1)*w*0.035,(i+0.5)*height/5,cos(i)*d*0.035),Vector3(w*(1-t*0.73),height/5,d*(1-t*0.62)),stone,i)
		"dead_tree":
			s.tilted_box(root,Vector3(0,height/2,0),Vector3(w*0.15,height,d*0.17),wood,Vector3(0,0,0.12))
			for i: int in 5:
				var side: float = -1.0 if i%2 else 1.0
				s.tilted_box(root,Vector3(side*w*0.18,height*(0.38+i*0.11),0),Vector3(w*0.47,0.11,d*0.12),wood,Vector3(0,i*0.5,side*0.5))
		"camp_cache":
			s.box(root,Vector3(-w*0.19,0.45,0),Vector3(w*0.57,0.9,d*0.9),wood)
			for y: float in [0.13,0.68]:
				s.box(root,Vector3(-w*0.19,y,d*0.46),Vector3(w*0.58,0.08,0.035),"b09561")
			for x: float in [-w*0.38,0]:
				s.box(root,Vector3(x,0.46,d*0.47),Vector3(0.07,0.91,0.04),dark)
			for i: int in 2:
				var at := Vector3(w*0.25,0,-d*0.25+i*d*0.49)
				s.shard(root,at+Vector3(0,0.29,0),Vector3(w*0.34,0.53,d*0.39),"855239",i)
				s.box(root,at+Vector3(0,0.57,0),Vector3(w*0.21,0.09,d*0.25),"463c30")
				s.box(root,at+Vector3(0,0.64,0),Vector3(w*0.24,0.07,d*0.28),"a74c32")
			s.box(root,Vector3(-w*0.17,0.94,0),Vector3(w*0.44,0.08,d*0.65),String(data.get("cloth","973f2d")))
		"scrub":
			for i: int in 7:
				var at := Vector3(sin(i*2.3)*w*0.32,0.12+sin(i*1.7)*0.06,cos(i*2.3)*d*0.32)
				s.box(root,at,Vector3(w*0.25,0.24,d*0.25),String(data.get("leaf","68703a")))
				if i%2==0:
					s.box(root,at+Vector3(0,0.15,0),Vector3(0.07,0.06,0.07),String(data.get("flower","bda56d")))
		"scree":
			for i: int in 48:
				var at := Vector3(sin(i*7.17)*w*0.46,0.035,cos(i*3.79)*d*0.46)
				s.shard(root,at,Vector3(0.07+(i%4)*0.03,0.05,0.10+(i%3)*0.03),stone if i%3 else dark,i,i*0.7)
		"lean_to":
			for x: float in [-w*0.43,w*0.43]:
				for z: float in [-d*0.38,d*0.38]:
					s.box(root,Vector3(x,height/2,z),Vector3(0.12,height,0.12),wood)
			for i: int in 9:
				s.tilted_box(root,Vector3((i-4)*w/9,height,0),Vector3(w/9+0.02,0.14,d),String(data.get("cloth","82764a")),Vector3(0.18,0,0))
			s.box(root,Vector3(0,0.1,0),Vector3(w*0.8,0.18,d*0.6),"8b784a")
		"barricade":
			for i: int in maxi(2,roundi(w/0.35)):
				var x: float = -w*0.45+i*0.35
				s.tilted_box(root,Vector3(x,0.7,0),Vector3(0.13,1.4,d*0.7),wood,Vector3(0.13,0,0.09*sin(i)))
			for y: float in [0.4,0.95]:
				s.box(root,Vector3(0,y,0),Vector3(w,0.10,0.12),"96744d")
		"stone_arch":
			# A roof/overhead beam has no footprint in the walking corridor beneath it.
			for i: int in 9:
				s.shard(root,Vector3((i-4)*w/9,height+sin(i*0.7)*0.10,0),Vector3(w/9+0.03,0.8+0.15*cos(i),d),stone,i)
		"bones":
			s.tilted_box(root,Vector3(0,0.065,0),Vector3(w*0.75,0.09,0.09),"c8b78b",Vector3(0,0.3,0))
			for i: int in 5:
				s.box(root,Vector3((i-2)*w*0.12,0.09,0),Vector3(0.055,0.08,d*0.55-absf(i-2)*0.08),"baaa81")
			s.shard(root,Vector3(w*0.4,0.12,0),Vector3(0.25,0.20,0.22),"d0c09a",2)
		"slick":
			var tint: String = String(data.get("color","62613c"))
			for i: int in 4:
				s.shard(root,Vector3(sin(i*3.1)*w*0.20,0.012+i*0.004,cos(i*2.8)*d*0.16),Vector3(w*0.68,0.012,d*0.66),tint,i,i*0.6)
			var mat: StandardMaterial3D = s.material(tint)
			mat.roughness = 0.17
			mat.metallic = 0.24
			for i: int in 4:
				s.box(root,Vector3((i-1.5)*w*0.12,0.036,sin(i*2.7)*d*0.2),Vector3(w*0.11,0.008,0.018),String(data.get("glint","969576")))
		"cliff_grooves":
			for i: int in 7:
				s.tilted_box(root,Vector3((i-3)*w/8,height*0.5,0),Vector3(0.08,height*(0.55+0.3*sin(i*4.0)),0.03),dark,Vector3(0,0,sin(i*2.0)*0.25))
		"light_pool":
			var lamp := OmniLight3D.new()
			lamp.position.y = height
			lamp.light_color = Color(String(data.get("color","9cb6a3")))
			lamp.light_energy = float(data.get("energy",0.65))
			lamp.omni_range = float(data.get("range",6.0))
			lamp.set_meta("night_energy",float(data.get("night_energy",lamp.light_energy)))
			root.add_child(lamp)
		_:
			return false
	return true
