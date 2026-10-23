extends RefCounted

## Fittings and decor that block nothing (lamps, windows, rugs, signs, stairs) or that the
## street layout places (boards, stone lions, flagpoles). Same materials and batching.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var s: Shapes
var root: Node3D

func draw(shapes: Shapes, parent: Node3D, data: Dictionary, w: float, d: float) -> bool:
	s = shapes
	root = parent
	match String(data["kind"]):
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
			s.lantern(root,Vector3(0,1.5,0),true)
			_set_lamp(root,0.5,1.1,4.0)
		"hanging_lantern":
			s.box(root,Vector3(0,3.85,0),Vector3(0.045,1.0,0.045),"594732")
			s.lantern(root,Vector3(0,3.15,0))
			_set_lamp(root,0.65,1.7,8.0)
		"pot": s.pot(root,Vector3.ZERO)
		"red_door":
			s.box(root,Vector3(0,1.25,0),Vector3(1.8,2.5,0.2),"a34736")
			s.box(root,Vector3(0,2.58,0),Vector3(2,0.12,0.3),"d5b37b")
			for x: float in [-0.79,0.79]:
				s.box(root,Vector3(x,1.25,0.12),Vector3(0.13,2.5,0.12),"bf8853")
			for y: float in [0.38,1.52,2.1]:
				s.box(root,Vector3(0,y,0.13),Vector3(1.6,0.09,0.10),"c09563")
			s.box(root,Vector3(0,1.0,0.15),Vector3(0.035,2.0,0.04),"65432e")
			for x: float in [-0.93,0.93]:
				s.box(root,Vector3(x,1.3,0.13),Vector3(0.035,2.58,0.025),"e0eadb")
			s.box(root,Vector3(0,2.62,0.13),Vector3(1.90,0.035,0.025),"e0eadb")
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
			for i: int in 6:
				s.box(root,Vector3(0,0.07+i*0.10,d/2-i*d/6),Vector3(w,0.14+i*0.2,d/6),"96724c")
			for x: float in [-w*0.47,w*0.47]:
				for i: int in 4:
					s.box(root,Vector3(x,0.35+i*0.15,d*0.4-i*d*0.25),Vector3(0.10,0.7+i*0.3,0.10),"715239")
				s.tilted_box(root,Vector3(x,0.95,0),Vector3(0.12,0.12,d*1.04),"936c45",Vector3(0.4,0,0))
		"window":
			s.box(root,Vector3(0,2,0),Vector3(w,1.65,0.18),"745438")
			s.box(root,Vector3(0,2,0.10),Vector3(w-0.18,1.46,0.04),"a4b7af")
			for x: int in 5:
				s.box(root,Vector3(-w*0.4+x*w*0.2,2,0.14),Vector3(0.065,1.52,0.055),"886744")
			for y: float in [1.32,1.78,2.24,2.70]:
				s.box(root,Vector3(0,y,0.15),Vector3(w,0.06,0.06),"886744")
			s.box(root,Vector3(0,1.16,0.20),Vector3(w+0.2,0.12,0.44),"a37c52")
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
		"runner":
			s.box(root,Vector3(0,0.018,0),Vector3(w,0.028,d),"485f61")
			for z: float in [-d*0.44,d*0.44]:
				s.box(root,Vector3(0,0.036,z),Vector3(w,0.008,0.06),"bca270")
		"sign":
			s.box(root,Vector3(0,1.7,0),Vector3(w,0.9,0.12),"463b2d")
			var title := Label3D.new()
			title.text = tr(String(data.get("text","")))
			title.position = Vector3(0,1.7,0.075)
			title.pixel_size = 0.006
			title.font_size = 40
			title.modulate = Color("e3c38b")
			title.outline_size = 0
			root.add_child(title)
		"stone_lion":
			# A crouching guardian on its plinth, facing +z.
			s.box(root,Vector3(0,0.25,0),Vector3(0.9,0.5,0.9),"8f8f86")
			s.box(root,Vector3(0,0.53,0),Vector3(1.0,0.08,1.0),"a3a398")
			s.box(root,Vector3(0,0.95,-0.12),Vector3(0.62,0.72,0.62),"b1b0a4")
			s.box(root,Vector3(0,1.48,0.10),Vector3(0.58,0.52,0.50),"b8b7ab")
			s.box(root,Vector3(0,1.62,0.05),Vector3(0.74,0.36,0.44),"9d9c90")
			s.box(root,Vector3(0,1.40,0.37),Vector3(0.30,0.18,0.10),"8e8d82")
			for x: float in [-0.17,0.17]:
				s.box(root,Vector3(x,0.72,0.26),Vector3(0.18,0.38,0.22),"a9a89c")
			s.box(root,Vector3(0.24,0.70,0.36),Vector3(0.24,0.20,0.24),"9a998d")
		"flagpole":
			s.box(root,Vector3(0,0.12,0),Vector3(0.7,0.24,0.7),"8c8a7f")
			s.box(root,Vector3(0,3.2,0),Vector3(0.16,6.4,0.16),"6e5038")
			s.box(root,Vector3(0,6.45,0),Vector3(0.24,0.14,0.24),"c9a35e")
			s.box(root,Vector3(0.62,5.2,0),Vector3(1.1,2.2,0.04),"b8432f")
			s.box(root,Vector3(0.62,6.33,0),Vector3(1.2,0.07,0.07),"6e5038")
			var title := Label3D.new()
			title.text = tr(String(data.get("text","")))
			title.position = Vector3(0.62,5.2,0.03)
			title.pixel_size = 0.009
			title.font_size = 52
			title.width = 120.0
			title.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			title.modulate = Color("f1d9a0")
			title.outline_size = 0
			root.add_child(title)
		_:
			return false
	return true

func _set_lamp(node: Node3D, day: float, night: float, radius: float) -> void:
	for child: Node in node.get_children():
		if child is OmniLight3D:
			(child as OmniLight3D).omni_range = radius
			child.set_meta("day_energy",day)
			child.set_meta("night_energy",night)

