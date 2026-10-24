extends RefCounted

## Small earth shrines and their devotional fittings, sized and coloured by data.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")

func draw(s: Shapes, root: Node3D, data: Dictionary, w: float, d: float) -> bool:
	var clay: String = String(data.get("clay","a78654"))
	var red: String = String(data.get("red","8b3f2d"))
	match String(data["kind"]):
		"earth_shrine":
			# Open front: a recess framed in clay, the broken old god inside it.
			s.box(root,Vector3(0,0.22,0),Vector3(w,0.44,d),"70604a")
			# Cut through the niche's rear and hood, as with the near wall: the god
			# remains legible from either fixed angle without rotating the furnishing.
			s.box(root,Vector3(0,0.67,-d*0.42),Vector3(w,0.9,d*0.15),"564939")
			for x: float in [-w*0.45,w*0.45]:
				s.box(root,Vector3(x,1.4,-d*0.25),Vector3(w*0.1,2.35,d*0.45),clay)
			s.box(root,Vector3(0,2.77,-d*0.35),Vector3(w,0.18,d*0.28),clay)
			for layer: int in 4:
				s.box(root,Vector3(0,2.89+layer*0.13,-d*0.35),Vector3(w*(1.16-layer*0.18),0.14,d*0.35),"615e4b" if layer%2 else "7b7154")
			s.box(root,Vector3(0,1.10,0),Vector3(w*0.40,1.18,d*0.57),red)
			s.box(root,Vector3(0,1.93,0),Vector3(0.63,0.65,0.52),"b79d70")
			s.box(root,Vector3(0,2.32,0),Vector3(0.80,0.16,0.65),"504c3b")
			for x: float in [-0.17,0.17]:
				s.box(root,Vector3(x,1.98,0.275),Vector3(0.07,0.045,0.025),"40382d")
			s.box(root,Vector3(0,1.68,0.32),Vector3(0.37,0.30,0.09),"d0c19b")
			for i: int in 3:
				s.box(root,Vector3((i-1)*0.12,1.46-absf(i-1)*0.04,0.35),Vector3(0.095,0.22,0.08),"c5b993")
			s.box(root,Vector3(-w*0.27,1.27,0.04),Vector3(0.20,0.40,0.27),clay)
			# Missing right forearm, chipped plinth and a fallen piece beside it.
			s.shard(root,Vector3(w*0.29,0.52,d*0.29),Vector3(0.24,0.15,0.18),"aa946d",2)
			s.tilted_box(root,Vector3(0.12,1.07,d*0.30),Vector3(0.03,0.63,0.02),"553c30",Vector3(0,0,0.19))
		"offering_table":
			for x: float in [-w*0.39,w*0.39]:
				for z: float in [-d*0.35,d*0.35]:
					s.box(root,Vector3(x,0.43,z),Vector3(0.11,0.86,0.11),"594331")
			s.box(root,Vector3(0,0.91,0),Vector3(w,0.14,d),"816144")
			s.box(root,Vector3(0,1.07,0),Vector3(0.54,0.22,0.40),"625d3f")
			s.box(root,Vector3(0,1.21,0),Vector3(0.45,0.04,0.31),"b5a27c")
			for x: float in [-0.12,0,0.12]:
				s.box(root,Vector3(x,1.43,0),Vector3(0.026,0.44,0.026),"805438")
				s.box(root,Vector3(x,1.66,0),Vector3(0.03,0.04,0.03),"ed9652")
			for x: float in [-w*0.32,w*0.32]:
				s.box(root,Vector3(x,1.01,0),Vector3(0.40,0.05,d*0.55),"a99a75")
				for i: int in 3:
					s.shard(root,Vector3(x+(i-1)*0.10,1.10,0),Vector3(0.17,0.15,0.18),"af612e" if x<0 else "b9ab7a",i)
		"votive_candles":
			for i: int in 3:
				var h: float = 0.15+i*0.09
				var p := Vector3((i-1)*w*0.27,0,cos(i*2.0)*d*0.15)
				s.box(root,p+Vector3(0,0.025,0),Vector3(w*0.24,0.05,d*0.45),"755c3d")
				s.box(root,p+Vector3(0,h/2,0),Vector3(0.10,h,0.10),red)
				s.box(root,p+Vector3(0,h+0.06,0),Vector3(0.055,0.12,0.055),"ffd58b")
			var light := OmniLight3D.new()
			light.position.y = 0.65
			light.light_color = Color("ffbd69")
			light.light_energy = 0.9
			light.set_meta("night_energy",1.15)
			light.omni_range = 5.5
			root.add_child(light)
		"torn_mat":
			for i: int in 12:
				s.box(root,Vector3((i-5.5)*w/12,0.025,0),Vector3(w/13,0.05,d*(0.90-0.10*sin(i*2.7))),"92804e" if i%3 else "b09b60")
			for z: float in [-d*0.39,d*0.39]:
				s.box(root,Vector3(0,0.054,z),Vector3(w*0.8,0.015,0.025),red)
		"paper_charms":
			for i: int in 3:
				var p := Vector3((i-1)*w*0.28,1.85+sin(i*3.0)*0.18,0)
				s.box(root,p,Vector3(w*0.21,0.70-i*0.10,0.02),"c4aa66")
				for j: int in 5-i:
					s.box(root,p+Vector3(sin(j)*0.05,(j-2)*0.10,0.014),Vector3(0.08+(j%2)*0.04,0.025,0.01),red)
		_:
			return false
	return true
