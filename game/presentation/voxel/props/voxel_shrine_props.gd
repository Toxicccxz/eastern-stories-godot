extends RefCounted

## Shrines and temples: niches and their gods, offering tables, incense burners, candles,
## prayer cushions and the paper charms on the walls; a hall's gilt god on his altar, the
## masters' spirit tablets, a sword kept on its stand, the sacred books on their red-clothed
## table. Faces +z unless rotated; sizes and colours from the data. What stands on the floor
## is a blocked box in the map layout.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var s: Shapes
var root: Node3D
var ambience: VoxelAmbience
var data: Dictionary

func draw(shapes: Shapes, parent: Node3D, look: Dictionary, w: float, d: float) -> bool:
	s = shapes
	root = parent
	data = look
	match String(look["kind"]):
		"shrine_niche": _niche(w,d)
		"earth_god": _earth_god(Vector3.ZERO,1.0)
		"altar_table": _altar_table(w,d)
		"incense_burner": _incense_burner(w)
		"prayer_cushion": _cushion(w)
		"paper_charms": _charms(w)
		"candles": _candles(Vector3.ZERO,int(data.get("count",3)))
		"cobweb": _cobweb(w)
		"rubble": _rubble(w,d)
		"post": _post()
		"paper_burner": _paper_burner(w,d)
		"buddha": _buddha(w,d)
		"deity": _deity(w,d)
		"spirit_tablets": _spirit_tablets(w,d)
		"sword_stand": _sword_stand(w,d)
		"scripture_table": _scripture_table(w,d)
		"beast_statue": _beast_statue(w,d)
		"pagoda": _pagoda(w,d)
		"temple_bell": _temple_bell(w,d)
		"brick_shrine": _brick_shrine(w,d)
		"pill_furnace": _pill_furnace(w,d)
		"dragon_pillar": _dragon_pillar(w,d)
		_:
			return false
	return true

## 龙柱顶天 (camp8.c): a red pillar from floor to roof, a gilt dragon coiling up it, its head out
## near the top over the pearl (`height`, `column`, `gilt`).
func _dragon_pillar(w: float, d: float) -> void:
	var height: float = float(data.get("height",3.2))
	var column: String = String(data.get("column","8a2a24"))
	var gilt: String = String(data.get("gilt","c9a24a"))
	var r: float = minf(w,d)*0.5
	s.box(root,Vector3(0,0.1,0),Vector3(r*2,0.2,r*2),"6a5a4a")
	s.box(root,Vector3(0,height/2,0),Vector3(r*1.1,height,r*1.1),column)
	s.box(root,Vector3(0,height-0.1,0),Vector3(r*1.5,0.2,r*1.5),gilt)
	var turns: int = 18
	for i: int in turns:
		var a: float = i*TAU*2.4/turns
		var y: float = 0.4+(height-1.0)*float(i)/turns
		s.box(root,Vector3(cos(a)*r*0.65,y,sin(a)*r*0.65),Vector3(0.14,0.16,0.14),gilt if i%3 else "e8d890")
	var last: float = TAU*2.4
	var head := Vector3(cos(last)*r*0.75,height-0.5,sin(last)*r*0.75)
	s.box(root,head,Vector3(0.24,0.2,0.3),gilt)
	s.box(root,head+Vector3(0,0.14,0),Vector3(0.06,0.14,0.06),gilt)
	s.box(root,head+Vector3(0,0.0,0.3),Vector3(0.12,0.12,0.12),"e8e0c0:glow")

## A sacred beast in gilt and glaze on its plinth beside a god (uproom.c: 雨神「天龙」、火神
## 「凤凰」): `beast` "dragon" (coiled, rearing, whiskered), "phoenix" (wings raised, a long
## tail sweeping down) or "crane"; `colors` [body, highlight, gilt], `base` the plinth.
func _beast_statue(w: float, d: float) -> void:
	var tones: Array = data.get("colors",["3a6a8a","4a7a9a","c9a24a"])
	var body: String = String(tones[0])
	var light: String = String(tones[1])
	var gilt: String = String(tones[2])
	var base: String = String(data.get("base","8a7a6a"))
	s.box(root,Vector3(0,0.3,0),Vector3(minf(w,1.2),0.6,minf(d,1.2)),base)
	s.box(root,Vector3(0,0.63,0),Vector3(minf(w,1.2)+0.08,0.06,minf(d,1.2)+0.08),gilt)
	var y: float = 0.66
	match String(data.get("beast","dragon")):
		"phoenix":
			s.box(root,Vector3(0,y+0.45,0),Vector3(0.3,0.5,0.34),body)
			s.box(root,Vector3(0,y+0.85,0.1),Vector3(0.12,0.4,0.12),body)
			s.box(root,Vector3(0,y+1.08,0.16),Vector3(0.16,0.14,0.18),light)
			s.box(root,Vector3(0,y+1.1,0.28),Vector3(0.05,0.05,0.1),gilt)
			for i: int in 3:
				s.box(root,Vector3(0,y+1.18+i*0.06,0.08-i*0.07),Vector3(0.03,0.1,0.03),gilt)
			for side: float in [-1.0,1.0]:
				for f: int in 4:
					s.tilted_box(root,Vector3(side*(0.22+f*0.1),y+0.7+f*0.12,-0.02),Vector3(0.1,0.45-f*0.06,0.06),light if f%2 else body,Vector3(0,0,-side*(0.35+f*0.15)))
			for t: int in 5:
				s.tilted_box(root,Vector3((t-2)*0.07,y+0.25-t*0.02,-0.32-t*0.04),Vector3(0.06,0.04,0.6),[body,light,gilt][t%3],Vector3(0.5,0,0))
			for side: float in [-0.08,0.08]:
				s.box(root,Vector3(side,y+0.1,0.04),Vector3(0.04,0.2,0.04),gilt)
		"tiger", "leopard":
			# altar.c: 虎豹熊鹰四位将军 — a big cat standing on the plinth, stripes or spots on it.
			s.box(root,Vector3(0,y+0.5,0),Vector3(0.44,0.4,0.9),body)
			for leg: float in [-0.14,0.14]:
				for z: float in [-0.3,0.3]:
					s.box(root,Vector3(leg,y+0.18,z),Vector3(0.12,0.36,0.14),body)
			s.box(root,Vector3(0,y+0.78,0.46),Vector3(0.36,0.34,0.36),body)
			s.box(root,Vector3(0,y+0.68,0.68),Vector3(0.24,0.16,0.14),light)
			for ear: float in [-0.12,0.12]:
				s.box(root,Vector3(ear,y+0.98,0.4),Vector3(0.08,0.08,0.06),light)
			s.tilted_box(root,Vector3(0,y+0.6,-0.6),Vector3(0.08,0.08,0.5),body,Vector3(0.4,0,0))
			for i: int in 7:
				var z: float = -0.36+i*0.12
				if String(data.get("beast","")) == "tiger":
					s.box(root,Vector3(0,y+0.5,z),Vector3(0.46,0.42,0.04),gilt if i%2 else "2a2622")
				else:
					s.box(root,Vector3(0.12*(1 if i%2 else -1),y+0.6+0.1*(i%3),z),Vector3(0.07,0.07,0.07),"2a2622")
		"bear":
			# A bear sitting up on its haunches, dark, a pale muzzle.
			s.box(root,Vector3(0,y+0.5,0),Vector3(0.62,0.9,0.5),body)
			s.box(root,Vector3(0,y+0.2,0.2),Vector3(0.7,0.36,0.5),body)
			s.box(root,Vector3(0,y+1.1,0.08),Vector3(0.42,0.38,0.4),body)
			s.box(root,Vector3(0,y+1.0,0.3),Vector3(0.2,0.16,0.14),light)
			for ear: float in [-0.16,0.16]:
				s.box(root,Vector3(ear,y+1.3,0.02),Vector3(0.1,0.1,0.08),light)
			for arm: float in [-0.34,0.34]:
				s.tilted_box(root,Vector3(arm,y+0.6,0.22),Vector3(0.14,0.5,0.14),body,Vector3(-0.5,0,0))
			s.box(root,Vector3(0,y+0.66,0.26),Vector3(0.3,0.3,0.04),gilt)
		"eagle":
			# An eagle perched, wings half spread, hooked beak gilt.
			s.box(root,Vector3(0,y+0.2,0),Vector3(0.3,0.4,0.26),light)
			s.box(root,Vector3(0,y+0.62,0.02),Vector3(0.3,0.5,0.34),body)
			s.box(root,Vector3(0,y+0.98,0.1),Vector3(0.2,0.22,0.22),light)
			s.box(root,Vector3(0,y+0.96,0.24),Vector3(0.08,0.08,0.1),gilt)
			for side: float in [-1.0,1.0]:
				for f: int in 3:
					s.tilted_box(root,Vector3(side*(0.24+f*0.16),y+0.7+f*0.1,-0.04),Vector3(0.14,0.5-f*0.08,0.06),body if f%2 else light,Vector3(0,0,-side*(0.6+f*0.2)))
			s.tilted_box(root,Vector3(0,y+0.3,-0.26),Vector3(0.22,0.06,0.4),body,Vector3(0.5,0,0))
		"crane":
			s.box(root,Vector3(0,y+0.62,0),Vector3(0.22,0.24,0.42),body)
			s.box(root,Vector3(0,y+0.95,0.2),Vector3(0.06,0.5,0.06),body)
			s.box(root,Vector3(0,y+1.2,0.25),Vector3(0.08,0.08,0.14),light)
			s.box(root,Vector3(0,y+1.26,0.24),Vector3(0.05,0.03,0.05),"c8382a")
			for side: float in [-0.06,0.06]:
				s.box(root,Vector3(side,y+0.25,0),Vector3(0.03,0.5,0.03),"2a2a2a")
		_:
			# A dragon rearing in a coil: scaled loops rising round the plinth, its head up.
			for i: int in 12:
				var a: float = i*TAU*1.6/12
				var at := Vector3(cos(a)*0.28,y+0.1+i*0.08,sin(a)*0.22)
				s.box(root,at,Vector3(0.2,0.18,0.2),body if i%2 else light)
				if i%3==0:
					s.box(root,at+Vector3(0,0.12,0),Vector3(0.06,0.1,0.06),gilt)
			var head := Vector3(0.08,y+1.1,0.12)
			s.box(root,head,Vector3(0.26,0.22,0.36),body)
			s.box(root,head+Vector3(0,-0.06,0.2),Vector3(0.2,0.08,0.14),light)
			for side: float in [-1.0,1.0]:
				s.tilted_box(root,head+Vector3(side*0.1,0.16,-0.08),Vector3(0.04,0.22,0.04),gilt,Vector3(-0.5,0,side*0.3))
				s.tilted_box(root,head+Vector3(side*0.14,-0.08,0.26),Vector3(0.02,0.02,0.3),gilt,Vector3(0.3,side*0.4,0))
			s.box(root,Vector3(0.3,y+0.2,0.3),Vector3(0.12,0.12,0.12),"e8e4d8")

## 小庙 (tree_tomb.c: 一间砖砌的小庙, 庙里供奉的当然就是「树王公」, 神像左手残缺不全, 木刻的神像竟然
## 有一条条白蚁的痕迹): a little brick temple on a step, a tiled gable roof, the front open on
## the wooden 树王公 (brown, one hand missing, termite trails on him), cups and incense before him.
func _brick_shrine(w: float, d: float) -> void:
	var bricks: Array = data.get("bricks",["8a6a5a","9a7a66","7a5e4e","a08470"])
	var height: float = float(data.get("height",1.9))
	s.box(root,Vector3(0,0.08,0),Vector3(w+0.2,0.16,d+0.2),"8a8a7e")
	for course: int in ceili((height-0.16)/0.2):
		var y: float = 0.26+course*0.2
		for side: int in 3:
			var at: Vector3 = [Vector3(-w/2+0.08,y,0),Vector3(w/2-0.08,y,0),Vector3(0,y,-d/2+0.08)][side]
			var size: Vector3 = Vector3(0.16,0.19,d) if side<2 else Vector3(w,0.19,0.16)
			s.box(root,at+Vector3(0.0,0,0.02*(course%2)),size,String(bricks[(course+side)%bricks.size()]))
	s.box(root,Vector3(0,height+0.04,0),Vector3(w+0.3,0.08,d+0.3),"5a4a3e")
	var tint := Color(String(data.get("roof","4a4e50")))
	for row: int in 3:
		for side: float in [-1.0,1.0]:
			s.tilted_box(root,Vector3(0,height+0.16+row*0.14,side*(d*0.3-row*0.1)),Vector3(w+0.36,0.08,d*0.36),tint.lightened(row*0.05).to_html(false),Vector3(side*0.4,0,0))
	s.box(root,Vector3(0,height+0.62,0),Vector3(w+0.5,0.1,0.14),tint.darkened(0.15).to_html(false))
	s.box(root,Vector3(0,height*0.55,-d*0.1),Vector3(w-0.36,height-0.3,d-0.3),"120f0d")
	# 树王公: a wood-cut figure seated on a block, the left hand gone, pale termite trails.
	var wood: String = String(data.get("wood","6a4a34"))
	s.box(root,Vector3(0,0.46,-d*0.14),Vector3(0.36,0.36,0.3),wood)
	s.box(root,Vector3(0,0.86,-d*0.16),Vector3(0.3,0.44,0.26),wood)
	s.box(root,Vector3(0,1.2,-d*0.16),Vector3(0.22,0.24,0.22),"8a6a4a")
	s.box(root,Vector3(0.18,0.78,-d*0.08),Vector3(0.08,0.3,0.08),wood)
	for trail: int in 3:
		s.box(root,Vector3(-0.1+trail*0.1,0.74+trail*0.12,-d*0.16+0.14),Vector3(0.02,0.16,0.01),"d8d0b8")
	s.box(root,Vector3(0,0.3,d*0.22),Vector3(w-0.5,0.08,0.3),"5a4a3e")
	for cup: int in 3:
		s.box(root,Vector3(-0.2+cup*0.2,0.38,d*0.22),Vector3(0.08,0.07,0.08),"8a7a5a")
	s.box(root,Vector3(0,0.42,d*0.38),Vector3(0.12,0.16,0.12),"5a4a3a")
	for stick: int in 3:
		s.box(root,Vector3(-0.03+stick*0.03,0.62,d*0.38),Vector3(0.012,0.3,0.012),"b8352a:glow" if stick==1 else "a08060")
	if ambience != null:
		ambience.smoke(root,Vector3(0,0.8,d*0.38),"a8a098",3,0.12)

## 丹炉 (stove.c: 雷霆不断击向一粒粒仙丹, 仙丹慢慢由黑转为红色, 炉门好象开着): the immortal's
## furnace — a bronze tripod with a round belly, a domed lid with a knob, the door open on +z and
## the pills reddening inside, flames licking round them, smoke out of the lid.
func _pill_furnace(w: float, d: float) -> void:
	var bronze: Array = data.get("colors",["5d5440","706549","4a4434","8a7a52"])
	var tall: float = float(data.get("height",2.6))
	var r: float = minf(w,d)*0.42
	for leg: int in 3:
		var a: float = leg*TAU/3.0+PI/2
		s.tilted_box(root,Vector3(cos(a)*r*0.7,0.35,sin(a)*r*0.7),Vector3(0.18,0.7,0.18),String(bronze[2]),Vector3(0,-a,0))
		s.box(root,Vector3(cos(a)*r*0.8,0.06,sin(a)*r*0.8),Vector3(0.26,0.12,0.26),String(bronze[2]))
	for i: int in 3:
		var a: float = i*PI/3.0
		s.tilted_box(root,Vector3(0,tall*0.42,0),Vector3(r*2,tall*0.44,r*2*0.82),String(bronze[i%2]),Vector3(0,a,0))
	s.box(root,Vector3(0,tall*0.66,0),Vector3(r*1.5,0.1,r*1.5),String(bronze[3]))
	for tier: int in 4:
		s.box(root,Vector3(0,tall*0.68+tier*0.14,0),Vector3(r*(1.4-tier*0.28),0.16,r*(1.4-tier*0.28)),String(bronze[tier%2]))
	s.box(root,Vector3(0,tall*0.68+0.68,0),Vector3(0.2,0.3,0.2),String(bronze[3]))
	for ear: float in [-1.0,1.0]:
		s.box(root,Vector3(ear*r*1.0,tall*0.6,0),Vector3(0.14,0.3,0.26),String(bronze[2]))
	# The door open: black inside, the pills on a tray, flames.
	s.box(root,Vector3(0,tall*0.36,r*0.8),Vector3(0.6,0.5,0.2),"0f0c0a")
	s.tilted_box(root,Vector3(0.42,tall*0.36,r*0.78),Vector3(0.3,0.5,0.04),String(bronze[1]),Vector3(0,-0.9,0))
	s.box(root,Vector3(0,tall*0.2,r*0.5),Vector3(0.7,0.04,0.5),String(bronze[2]))
	for pill: int in 7:
		var at := Vector3(-0.24+pill*0.08,tall*0.24,r*0.5+(pill%2)*0.1-0.05)
		s.box(root,at,Vector3(0.06,0.06,0.06),["2a2422","6a2a22:glow","c8362a:glow"][pill%3])
	# `flame` and `flame_tip`: the fire's colours (a 丹房 whose fire burns blue: 逆灵宫); the light below takes the flame's.
	var flame_color: String = String(data.get("flame","e8622f"))
	var flame_tip: String = String(data.get("flame_tip","ffd27a"))
	for tongue: int in 4:
		var flame := Node3D.new()
		flame.position = Vector3(-0.2+tongue*0.13,tall*0.26,r*0.72-(tongue%2)*0.2)
		flame.set_meta("light_fixture",true)
		root.add_child(flame)
		s.box(flame,Vector3(0,0.14,0),Vector3(0.14,0.28,0.12),flame_color+":glow")
		s.box(flame,Vector3(0,0.3,0),Vector3(0.08,0.2,0.07),flame_tip+":glow")
		if ambience != null:
			ambience.flame(flame)
	var light := OmniLight3D.new()
	light.position = Vector3(0,tall*0.4,r*1.2)
	light.light_color = Color("ff7a3a") if not data.has("flame") else Color(flame_color).lightened(0.2)
	light.omni_range = float(data.get("range",7.0))
	light.set_meta("day_energy",1.6)
	light.set_meta("night_energy",2.4)
	light.set_meta("flicker",0.25)
	root.add_child(light)
	if ambience != null:
		ambience.smoke(root,Vector3(0,tall*0.68+0.9,0),"a09890",5,0.3)

## 神龛: a small roofed niche in a wall, its god inside and a faded cloth over the front.
func _niche(w: float, d: float) -> void:
	var wood: String = String(data.get("wood","5e3b2a"))
	var red: String = String(data.get("cloth","8a3a2c"))
	var base: float = float(data.get("base",0.9))
	s.box(root,Vector3(0,base/2,0),Vector3(w,base,d),String(data.get("plinth","8b7656")))
	s.box(root,Vector3(0,base+0.04,0),Vector3(w+0.08,0.08,d+0.06),wood)
	for x: float in [-w/2+0.06,w/2-0.06]:
		s.box(root,Vector3(x,base+0.7,d*0.3),Vector3(0.1,1.3,0.1),wood)
	s.box(root,Vector3(0,base+0.7,-d/2+0.05),Vector3(w,1.4,0.1),"3a2a20")
	s.box(root,Vector3(0,base+1.42,0.05),Vector3(w+0.3,0.12,d+0.2),wood)
	s.tilted_box(root,Vector3(0,base+1.55,0.05),Vector3(w+0.5,0.1,d*0.7),String(data.get("roof","4c4a44")),Vector3(0.25,0,0))
	for x: float in [-w/2-0.2,w/2+0.2]:
		s.box(root,Vector3(x,base+1.5,d*0.35),Vector3(0.12,0.12,0.12),wood)
	# A torn red cloth across the top, one end hanging loose.
	s.box(root,Vector3(-w*0.1,base+1.26,d*0.36),Vector3(w*0.8,0.22,0.03),red)
	s.tilted_box(root,Vector3(w*0.36,base+1.0,d*0.37),Vector3(0.16,0.5,0.03),red,Vector3(0,0,0.25))
	_earth_god(Vector3(0,base+0.08,0),0.9)
	if data.get("broken",true):
		s.shard(root,Vector3(w*0.25,0.05,d*0.7),Vector3(0.18,0.1,0.14),"a99b84",1)
		s.shard(root,Vector3(-w*0.15,0.04,d*0.8),Vector3(0.12,0.08,0.1),"b5ad97",4)

## 土地公: a seated old man with a white beard, black cap and robe, a staff at his side.
## Broken (残破不堪): one arm gone, paint flaking, a crack across him.
func _earth_god(at: Vector3, scale: float) -> void:
	var robe: String = String(data.get("robe","9d6a3c"))
	var broken: bool = data.get("broken",true)
	var k: float = scale
	s.box(root,at+Vector3(0,0.2*k,0),Vector3(0.62*k,0.4*k,0.5*k),robe)
	s.box(root,at+Vector3(0,0.5*k,-0.03*k),Vector3(0.5*k,0.42*k,0.38*k),robe)
	s.box(root,at+Vector3(0,0.42*k,0.1*k),Vector3(0.28*k,0.06*k,0.26*k),"c7a24c")
	s.box(root,at+Vector3(0,0.85*k,0),Vector3(0.3*k,0.3*k,0.28*k),"d6b48b")
	s.box(root,at+Vector3(0,0.73*k,0.13*k),Vector3(0.26*k,0.22*k,0.08*k),"ece6d6")
	s.box(root,at+Vector3(0,0.62*k,0.15*k),Vector3(0.16*k,0.14*k,0.07*k),"e2dccb")
	s.box(root,at+Vector3(0,1.04*k,-0.01*k),Vector3(0.36*k,0.14*k,0.32*k),"2b2724")
	for side: float in [-1.0,1.0]:
		s.box(root,at+Vector3(side*0.24*k,1.05*k,-0.02*k),Vector3(0.14*k,0.05*k,0.07*k),"2b2724")
	s.box(root,at+Vector3(-0.32*k,0.48*k,0.05*k),Vector3(0.14*k,0.3*k,0.16*k),robe)
	s.box(root,at+Vector3(-0.36*k,0.55*k,0.16*k),Vector3(0.05*k,1.0*k,0.05*k),"6b4b2f")
	if broken:
		s.box(root,at+Vector3(0.3*k,0.6*k,0.0),Vector3(0.1*k,0.08*k,0.12*k),"8b7a62")
		s.box(root,at+Vector3(0.06*k,0.88*k,0.145*k),Vector3(0.02*k,0.24*k,0.01*k),"5a4a3a")
		for flake: int in 3:
			s.box(root,at+Vector3((flake-1)*0.14*k,0.3*k,0.256*k),Vector3(0.08*k,0.06*k,0.01*k),"8f8270")
	else:
		s.box(root,at+Vector3(0.32*k,0.48*k,0.05*k),Vector3(0.14*k,0.3*k,0.16*k),robe)
		s.box(root,at+Vector3(0.33*k,0.42*k,0.18*k),Vector3(0.14*k,0.1*k,0.1*k),"d7b45a")

## 供桌: the offering table, an incense burner, offerings and candle stubs on it.
func _altar_table(w: float, d: float) -> void:
	var wood: String = String(data.get("wood","5a3a28"))
	s.box(root,Vector3(0,0.82,0),Vector3(w,0.12,d),wood)
	s.box(root,Vector3(0,0.66,d/2-0.03),Vector3(w-0.1,0.22,0.04),String(data.get("apron","7a2f24")))
	for x: float in [-w/2+0.1,w/2-0.1]:
		for z: float in [-d/2+0.1,d/2-0.1]:
			s.box(root,Vector3(x,0.4,z),Vector3(0.1,0.8,0.1),wood)
	if data.get("fresh",false):
		_offerings(w,d)
		return
	s.box(root,Vector3(0,0.98,0),Vector3(0.36,0.2,0.3),"6f6656")
	s.box(root,Vector3(0,1.09,0),Vector3(0.3,0.03,0.24),"b4ab98")
	# Burnt-out stubs of incense in cold ash: nobody tends it (似乎没有人照顾).
	for stick: int in 3:
		s.tilted_box(root,Vector3((stick-1)*0.06,1.13,0),Vector3(0.02,0.08,0.02),"5a2f25",Vector3(0,0,(stick-1)*0.4))
	# Old offerings gone dry and grey with dust, a cracked cup.
	s.box(root,Vector3(-w*0.3,0.9,0.05),Vector3(0.3,0.03,0.3),"b8b2a2")
	for fruit: int in 3:
		s.box(root,Vector3(-w*0.3+(fruit-1)*0.08,0.94,0.05+fruit%2*0.06),Vector3(0.08,0.06,0.08),["6e5638","5f4a33","7a6644"][fruit])
	s.box(root,Vector3(w*0.28,0.93,0.08),Vector3(0.1,0.1,0.1),"bdb6a4")
	s.box(root,Vector3(w*0.31,0.93,0.08),Vector3(0.02,0.1,0.11),"6e675a")
	# 残烛: one guttering stub the hiding 黄霸 keeps alight, a dead one beside it.
	_candles(Vector3(w*0.4,0.88,-0.05),1)
	s.box(root,Vector3(-w*0.42,0.9,-0.05),Vector3(0.14,0.04,0.14),"e6dcc2")
	s.box(root,Vector3(-w*0.42,0.94,-0.05),Vector3(0.07,0.05,0.07),"d8cdb2")

## `tall`: raised on a carved stand (a hall's); `lit`: sticks burning, their smoke rising.
func _incense_burner(w: float) -> void:
	var bronze: String = String(data.get("bronze","6f5a3e"))
	var y: float = 0.0
	if data.get("tall",false):
		y = 0.7
		s.box(root,Vector3(0,0.05,0),Vector3(w*0.9,0.1,w*0.9),"5c3f2b")
		s.box(root,Vector3(0,0.38,0),Vector3(w*0.4,0.6,w*0.4),"6e4a34")
		s.box(root,Vector3(0,0.69,0),Vector3(w*0.85,0.06,w*0.85),"5c3f2b")
	for leg: int in 3:
		var a: float = leg*TAU/3.0
		s.box(root,Vector3(cos(a)*w*0.3,y+0.18,sin(a)*w*0.3),Vector3(0.1,0.36,0.1),bronze)
	s.box(root,Vector3(0,y+0.5,0),Vector3(w*0.8,0.4,w*0.8),bronze)
	s.box(root,Vector3(0,y+0.72,0),Vector3(w*0.9,0.06,w*0.9),"8a7350")
	s.box(root,Vector3(0,y+0.74,0),Vector3(w*0.7,0.03,w*0.7),"aaa294")
	for side: float in [-1.0,1.0]:
		s.box(root,Vector3(side*w*0.47,y+0.8,0),Vector3(0.06,0.18,0.14),bronze)
	if data.get("lit",false):
		# Three sticks burning, their tips glowing, a thread of smoke.
		for stick: int in 3:
			s.box(root,Vector3((stick-1)*0.07,y+0.9,0),Vector3(0.02,0.3,0.02),"8a3a2a")
			s.box(root,Vector3((stick-1)*0.07,y+1.06,0),Vector3(0.03,0.03,0.03),"ff8a3a:glow")
		if ambience != null:
			ambience.smoke(root,Vector3(0,y+1.1,0),String(data.get("smoke","d8d2c4")),5,0.1)
		return
	# Cold: burnt-down sticks leaning in the ash.
	for stick: int in 5:
		s.tilted_box(root,Vector3((stick-2)*0.07,y+0.82,sin(stick*1.7)*0.06),Vector3(0.02,0.14,0.02),"5a2f25",Vector3(0,0,(stick-2)*0.3))

## 蒲团: a round straw cushion, worn through on one side.
func _cushion(w: float) -> void:
	for ring: int in 3:
		var span: float = w*(1.0-ring*0.22)
		s.box(root,Vector3(0,0.05+ring*0.04,0),Vector3(span,0.08,span*0.92),["8f7a4c","a28b58","b39b65"][ring])
	if data.get("worn",true):
		s.box(root,Vector3(w*0.18,0.16,w*0.1),Vector3(w*0.25,0.02,w*0.2),"6e5d3a")
		for straw: int in 4:
			s.tilted_box(root,Vector3(w*0.5,0.02,(straw-1.5)*0.08),Vector3(0.2,0.02,0.02),"b8a46c",Vector3(0,straw*0.4,0))

## Old paper charms pasted on a wall, yellowed, the red writing faded, one hanging off.
func _charms(w: float) -> void:
	var count: int = int(data.get("count",4))
	var height: float = float(data.get("height",1.7))
	for i: int in count:
		var x: float = -w/2+(i+0.5)*w/count
		var y: float = height+sin(i*2.1)*0.18
		var loose: bool = i==count-1
		var paper := Node3D.new()
		paper.position = Vector3(x,y,0.04)
		paper.rotation.z = 0.35 if loose else sin(i*1.3)*0.08
		root.add_child(paper)
		s.box(paper,Vector3.ZERO,Vector3(0.2,0.48,0.015),["d8c27a","cbb46c","e0cc8a"][i%3])
		s.box(paper,Vector3(0,0.02,0.01),Vector3(0.05,0.34,0.01),"a8473a")
		s.box(paper,Vector3(0,0.16,0.01),Vector3(0.12,0.04,0.01),"a8473a")

## Candle stubs in their wax, each flame a flickering little light.
func _candles(at: Vector3, count: int) -> void:
	for i: int in count:
		var base: Vector3 = at+Vector3(i*0.1-(count-1)*0.05,0,sin(i*2.0)*0.06)
		var height: float = [0.18,0.1,0.14][i%3]
		s.box(root,base+Vector3(0,0.02,0),Vector3(0.14,0.04,0.14),"e6dcc2")
		s.box(root,base+Vector3(0,height/2,0),Vector3(0.07,height,0.07),"efe5cc")
		var flame := Node3D.new()
		flame.position = base+Vector3(0,height,0)
		flame.set_meta("light_fixture",true)
		root.add_child(flame)
		s.box(flame,Vector3(0,0.05,0),Vector3(0.04,0.1,0.04),"ffd88a")
		if ambience != null:
			ambience.flame(flame)
	var light := OmniLight3D.new()
	light.position = at+Vector3(0,0.45,0)
	light.light_color = Color("ffb867")
	light.omni_range = float(data.get("range",3.6))
	light.set_meta("day_energy",0.45)
	light.set_meta("night_energy",1.25)
	light.set_meta("flicker",0.12)
	root.add_child(light)

## A web strung across a corner, high up (`height`).
func _cobweb(w: float) -> void:
	var silk: String = String(data.get("color","d9d6cc"))
	var at := Vector3(0,float(data.get("height",2.6)),0)
	for strand: int in 5:
		s.tilted_box(root,at,Vector3(w,0.012,0.012),silk,Vector3(0,(strand-2)*0.35,(strand-2)*0.2))
	for ring: int in 3:
		s.tilted_box(root,at+Vector3(0,-0.05*(ring+1),0),Vector3(w*0.3*(ring+1),0.01,0.01),silk,Vector3(0,0.8,0))

func _rubble(w: float, d: float) -> void:
	var colors: Array = data.get("colors",["8f7f63","a08d6c","b0a07f","7d6e58"])
	for i: int in int(data.get("count",10)):
		var a: float = i*2.4
		var r: float = fposmod(i*0.37,1.0)
		var size: float = 0.1+fposmod(i*0.53,1.0)*0.18
		s.shard(root,Vector3(cos(a)*r*w*0.45,size*0.3,sin(a)*r*d*0.45),Vector3(size*1.3,size*0.6,size),String(colors[i%colors.size()]),i,a)

func _post() -> void:
	var wood: String = String(data.get("wood","6b4b33"))
	var height: float = float(data.get("height",3.1))
	s.box(root,Vector3(0,0.12,0),Vector3(0.5,0.24,0.5),"8a7e68")
	s.box(root,Vector3(0,height/2,0),Vector3(0.3,height,0.3),wood)
	for crack: int in 2:
		s.box(root,Vector3(0.155,0.8+crack*0.9,0),Vector3(0.01,0.5,0.06),"3d2c20")

## 金纸亭 (temple0.c: 庙外的小空地边有一个简陋的金纸亭): a little stove of bricks to burn paper money
## in, a tiled cap on posts over it, its mouth black with soot, ash and charred scraps spilt out
## before it, a curl of smoke.
func _paper_burner(w: float, d: float) -> void:
	var brick: Array = data.get("colors",["7d5a46","8a6450","70503e"])
	for course: int in 6:
		for side: int in 4:
			var along_x: bool = side < 2
			var fixed: float = (d if along_x else w)*0.32*(1 if side%2 else -1)
			var at := Vector3(0,0.1+course*0.18,fixed) if along_x else Vector3(fixed,0.1+course*0.18,0)
			s.box(root,at,Vector3(w*0.66,0.16,0.12) if along_x else Vector3(0.12,0.16,d*0.66),String(brick[(course+side)%brick.size()]))
	s.box(root,Vector3(0,0.52,d*0.33),Vector3(w*0.3,0.36,0.14),"1c1815")
	s.box(root,Vector3(0,1.18,0),Vector3(w*0.72,0.08,d*0.72),"5a4a3c")
	for x: float in [-w*0.36,w*0.36]:
		for z: float in [-d*0.36,d*0.36]:
			s.box(root,Vector3(x,1.45,z),Vector3(0.08,0.55,0.08),"5e4434")
	s.box(root,Vector3(0,1.78,0),Vector3(w*0.95,0.12,d*0.95),"4f4a40")
	s.box(root,Vector3(0,1.9,0),Vector3(w*0.6,0.12,d*0.6),"5a554a")
	s.box(root,Vector3(0,2.02,0),Vector3(0.14,0.2,0.14),"5a554a")
	for scrap: int in 7:
		s.box(root,Vector3(sin(scrap*2.3)*w*0.25,0.02,d*0.45+absf(cos(scrap*1.7))*0.3),Vector3(0.12,0.012,0.09),["3a3530","d2b25a","2a2622","8a857c"][scrap%4])
	if ambience != null:
		ambience.smoke(root,Vector3(0,2.1,0),"9a978d",4,0.2)

## 佛像 with its 夜明珠 (cavehall.c: 佛像顶部有一颗夜明珠发出莹莹的光芒): a seated figure on a
## lotus base, hands in its lap, the pearl on its crown glowing pale blue-white and lighting the
## hall day and night (`stone`: the figure's colours).
func _buddha(w: float, d: float) -> void:
	if data.get("gilt",false):
		_gilt_buddha(w,d)
		return
	var stone: Array = data.get("stone",["8d8a7c","9a9789","807d70"])
	var k: float = minf(w,d)*0.55
	for petal: int in 10:
		var a: float = petal*TAU/10.0
		s.tilted_box(root,Vector3(cos(a)*k*0.72,0.32,sin(a)*k*0.62),Vector3(k*0.42,0.2,k*0.3),String(stone[petal%2]),Vector3(0,-a,0.25))
	s.box(root,Vector3(0,0.2,0),Vector3(k*1.5,0.4,k*1.3),String(stone[2]))
	s.box(root,Vector3(0,0.62,0),Vector3(k*1.25,0.38,k*1.0),String(stone[0]))
	s.box(root,Vector3(0,1.22,-k*0.05),Vector3(k*0.8,0.9,k*0.6),String(stone[1]))
	s.box(root,Vector3(0,0.9,k*0.22),Vector3(k*0.5,0.12,k*0.3),String(stone[0]))
	for side: float in [-1.0,1.0]:
		s.box(root,Vector3(side*k*0.44,1.25,0),Vector3(k*0.18,0.7,k*0.3),String(stone[1]))
	s.box(root,Vector3(0,1.86,-k*0.02),Vector3(k*0.46,0.46,k*0.42),String(stone[0]))
	s.box(root,Vector3(0,2.16,-k*0.02),Vector3(k*0.36,0.18,k*0.34),String(stone[2]))
	s.box(root,Vector3(0,2.38,0),Vector3(0.22,0.22,0.22),"e6f2ff:glow")
	var light := OmniLight3D.new()
	light.position = Vector3(0,2.5,0.6)
	light.light_color = Color("cfe4ff")
	light.omni_range = float(data.get("range",7.0))
	light.set_meta("day_energy",1.2)
	light.set_meta("night_energy",1.8)
	root.add_child(light)

## 金身 (temple.c: 一丈八尺的如来佛祖金身, 坐在一座三尺高的莲台上): a gilt Buddha seated cross-legged
## on a lotus throne of two rings of petals over a stepped base, his robe (`robe`) falling over
## one shoulder, blue curls and the knot on his crown, long ears; behind him a flame-edged
## mandorla and a round halo (`halo`). `height` units from the floor to the mandorla's tip; his
## hands (`mudra`): "earth" the right hand down over the knee, "bowl" both in his lap holding
## the medicine bowl (药师如来), else folded in meditation. `gold` his gilt.
func _gilt_buddha(w: float, d: float) -> void:
	var gold: Array = data.get("gold",["c9a24a","dab45a","b08a3a"])
	var robe: String = String(data.get("robe","b8862e"))
	var height: float = float(data.get("height",4.0))
	# The mandorla's flame tip stands 0.62+5k over the floor.
	var k: float = maxf(0.2,(height-0.62)/5.0)
	var deep: float = minf(d*0.8,w*0.62)
	# The base and the throne: three stepped plinths, two rings of upturned petals.
	s.box(root,Vector3(0,0.15,0),Vector3(w*0.92,0.3,deep),String(data.get("base","8a6a4a")))
	s.box(root,Vector3(0,0.36,0),Vector3(w*0.8,0.12,deep*0.88),String(gold[2]))
	s.box(root,Vector3(0,0.52,0),Vector3(w*0.7,0.2,deep*0.78),String(data.get("base","8a6a4a")))
	var throne: float = 0.62+0.2*k
	for ring: int in 2:
		var radius: float = w*(0.34-ring*0.07)
		for petal: int in 14-ring*3:
			var a: float = petal*TAU/(14-ring*3)+ring*0.2
			var tip := Vector3(cos(a)*radius,throne+ring*0.22*k,sin(a)*radius*deep/w)
			s.tilted_box(root,tip,Vector3(0.36*k,0.28*k,0.16*k),String(["d8b078","c89a5a"][petal%2]) if ring==0 else String(gold[petal%2]),Vector3(0,-a,0.35))
	s.box(root,Vector3(0,throne+0.2*k,0),Vector3(w*0.5,0.26*k,deep*0.56),String(gold[0]))
	var seat: float = throne+0.33*k
	# Crossed legs, the robe over them, the body, one shoulder bare.
	s.box(root,Vector3(0,seat+0.22*k,0.05*k),Vector3(1.9*k,0.44*k,1.1*k),String(gold[1]))
	s.box(root,Vector3(0,seat+0.3*k,0.48*k),Vector3(1.7*k,0.3*k,0.18*k),robe)
	s.box(root,Vector3(0,seat+1.05*k,-0.05*k),Vector3(1.1*k,1.25*k,0.72*k),String(gold[0]))
	s.tilted_box(root,Vector3(-0.18*k,seat+1.1*k,0.08*k),Vector3(0.4*k,1.28*k,0.62*k),robe,Vector3(0,0,0.3))
	for side: float in [-1.0,1.0]:
		s.box(root,Vector3(side*0.66*k,seat+1.2*k,-0.04*k),Vector3(0.3*k,0.9*k,0.42*k),String(gold[1]) if side>0 else robe)
	match String(data.get("mudra","")):
		"earth":
			s.box(root,Vector3(0.62*k,seat+0.56*k,0.36*k),Vector3(0.22*k,0.48*k,0.24*k),String(gold[1]))
			s.box(root,Vector3(-0.16*k,seat+0.5*k,0.42*k),Vector3(0.42*k,0.14*k,0.3*k),String(gold[1]))
		"bowl":
			s.box(root,Vector3(0,seat+0.52*k,0.4*k),Vector3(0.58*k,0.14*k,0.34*k),String(gold[1]))
			s.box(root,Vector3(0,seat+0.68*k,0.42*k),Vector3(0.34*k,0.2*k,0.3*k),String(data.get("bowl","2f5a8a")))
			s.box(root,Vector3(0,seat+0.8*k,0.42*k),Vector3(0.26*k,0.05*k,0.22*k),"3a6a9a")
		_:
			s.box(root,Vector3(0,seat+0.5*k,0.4*k),Vector3(0.62*k,0.14*k,0.34*k),String(gold[1]))
	# The head: face, long ears, the blue curls and the knot on the crown.
	var head: float = seat+2.0*k
	s.box(root,Vector3(0,head-0.25*k,0),Vector3(0.36*k,0.2*k,0.36*k),String(gold[0]))
	s.box(root,Vector3(0,head+0.08*k,0),Vector3(0.62*k,0.68*k,0.6*k),String(gold[1]))
	for side: float in [-1.0,1.0]:
		s.box(root,Vector3(side*0.34*k,head,0),Vector3(0.08*k,0.5*k,0.16*k),String(gold[0]))
	s.box(root,Vector3(0,head+0.44*k,-0.02*k),Vector3(0.64*k,0.14*k,0.62*k),String(data.get("curls","2a3a5a")))
	s.box(root,Vector3(0,head+0.6*k,-0.02*k),Vector3(0.34*k,0.22*k,0.34*k),String(data.get("curls","2a3a5a")))
	s.box(root,Vector3(0,head+0.06*k,0.31*k),Vector3(0.06*k,0.06*k,0.02*k),"d84a3a")
	for side: float in [-1.0,1.0]:
		s.box(root,Vector3(side*0.13*k,head+0.12*k,0.31*k),Vector3(0.12*k,0.03*k,0.02*k),"6a4a22")
	if data.get("halo",true):
		var back: float = -deep*0.42
		# The round halo behind his head: a disc of bars, a paler ring inside.
		for bar: int in 7:
			var t: float = (float(bar)-3.0)/3.5
			var half: float = sqrt(maxf(0.0,1.0-t*t))
			s.box(root,Vector3(0,head+0.1*k+t*0.68*k,back+0.12),Vector3(1.36*k*half,0.2*k,0.06),String(gold[2]))
			s.box(root,Vector3(0,head+0.1*k+t*0.5*k,back+0.15),Vector3(1.0*k*half,0.15*k,0.04),"e8c86a")
		# The mandorla: a tall flame-edged back, its rim in red flames.
		for tier: int in 7:
			var t: float = float(tier)/6.0
			var span: float = 2.6*k*sin(lerpf(0.45,PI-0.15,t))
			s.box(root,Vector3(0,seat+0.4*k+tier*0.5*k,back),Vector3(span,0.52*k,0.08),String(gold[tier%2]))
			for side: float in [-1.0,1.0]:
				s.tilted_box(root,Vector3(side*span/2,seat+0.55*k+tier*0.5*k,back+0.02),Vector3(0.22*k,0.4*k,0.06),"c8442a",Vector3(0,0,-side*0.5))
		s.tilted_box(root,Vector3(0,seat+3.85*k,back),Vector3(0.36*k,0.6*k,0.08),"c8442a",Vector3(0,0,PI/4))
	var light := OmniLight3D.new()
	light.position = Vector3(0,head,deep*0.8)
	light.light_color = Color("ffd9a0")
	light.omni_range = float(data.get("range",7.0))
	light.set_meta("day_energy",0.6)
	light.set_meta("night_energy",1.0)
	root.add_child(light)

## 塔 (tower.c: 明心塔、见性塔, the ashes of the temple's great monks kept in them): a brick
## pagoda of `tiers` storeys on a stone plinth, each storey a little smaller than the one
## below, a tiled eave round each with a bell at its corners, a small arched door and its name
## (`text`) on a stone over the door, a gilt spire of rings on top. `colors`: wall, eave,
## spire; `height` units.
func _pagoda(w: float, d: float) -> void:
	var tones: Array = data.get("colors",["c8bca4","5e5a52","c9a24a"])
	var tiers: int = int(data.get("tiers",7))
	var height: float = float(data.get("height",8.0))
	var span: float = minf(w,d)
	var wall := Color(String(tones[0]).get_slice(":",0))
	var variant: int = int(data.get("variant",0))
	s.box(root,Vector3(0,0.2,0),Vector3(span,0.4,span),"9a978a")
	s.box(root,Vector3(0,0.46,0),Vector3(span*0.9,0.12,span*0.9),"8a877c")
	var story: float = (height-1.6)/(tiers+0.5)
	var y: float = 0.52
	for tier: int in tiers:
		var t: float = float(tier)/maxf(1,tiers)
		var side: float = span*lerpf(0.7,0.38,t)
		var tall: float = story*(1.5 if tier==0 else lerpf(1.0,0.82,t))
		var at := Vector3(0,y+tall/2,0)
		s.box(root,at,Vector3(side,tall,side),wall.darkened(0.05*float((tier*7+variant)%3)).to_html(false))
		# Bare brick where the plaster has fallen.
		if (tier+variant)%3==1:
			s.box(root,at+Vector3(side*0.2,-tall*0.15,side/2+0.005),Vector3(side*0.3,tall*0.3,0.02),"9a6a52")
		# A blind arch on each face; the real door below, on the south.
		for face: int in 4:
			var a: float = face*PI/2
			var door := Node3D.new()
			door.position = at+Vector3(sin(a),0,cos(a))*(side/2+0.01)-Vector3(0,tall*(0.18 if tier==0 else 0.12),0)
			door.rotation.y = a
			root.add_child(door)
			s.box(door,Vector3.ZERO,Vector3(side*0.26,tall*(0.58 if tier==0 else 0.5),0.03),"2e2a26" if tier==0 and face==0 else wall.darkened(0.3).to_html(false))
		# The eave: a corbelled band, tiles stepping in, a bell under each corner.
		var eave_y: float = y+tall
		s.box(root,Vector3(0,eave_y+0.04,0),Vector3(side+0.24,0.08,side+0.24),wall.darkened(0.15).to_html(false))
		var reach: float = side+0.7-t*0.2
		for ring: int in 3:
			s.box(root,Vector3(0,eave_y+0.14+ring*0.08,0),Vector3(reach-ring*0.22,0.08,reach-ring*0.22),String(tones[1]))
		for cx: float in [-1.0,1.0]:
			for cz: float in [-1.0,1.0]:
				var corner := Vector3(cx*reach/2,eave_y+0.2,cz*reach/2)
				s.box(root,corner,Vector3(0.14,0.12,0.14),String(tones[1]))
				s.box(root,corner+Vector3(0,-0.16,0),Vector3(0.08,0.14,0.08),"8a6a32")
		y = eave_y+0.36
	if data.has("text"):
		var plate := Label3D.new()
		plate.text = TranslationServer.translate(String(data["text"]))
		plate.position = Vector3(0,0.52+story*1.5*0.86,span*0.35+0.05)
		plate.pixel_size = 0.006
		plate.font_size = 40
		plate.outline_size = 0
		plate.modulate = Color("3a2a1e")
		s.box(root,plate.position-Vector3(0,0,0.03),Vector3(span*0.32,0.3,0.03),"d8d2c0")
		root.add_child(plate)
	# The spire: a lotus, a stack of gilt rings, a pearl.
	s.box(root,Vector3(0,y+0.1,0),Vector3(0.5,0.2,0.5),String(tones[1]))
	for ring: int in 6:
		s.box(root,Vector3(0,y+0.3+ring*0.16,0),Vector3(0.32-ring*0.03,0.1,0.32-ring*0.03),String(tones[2]))
	s.box(root,Vector3(0,y+1.3,0),Vector3(0.16,0.2,0.16),String(tones[2])+":glow")

## 铜钟: a great bronze bell hung from a beam on a red frame, the striking log on its ropes.
func _temple_bell(w: float, d: float) -> void:
	var frame: String = String(data.get("frame","8a3226"))
	var bronze: Array = data.get("colors",["5a5a3a","6a6844","4a4a32"])
	var bell: float = minf(w,1.4)
	for x: float in [-w/2+0.12,w/2-0.12]:
		s.box(root,Vector3(x,1.35,0),Vector3(0.18,2.7,0.18),frame)
		s.box(root,Vector3(x,0.08,0),Vector3(0.34,0.16,minf(d,0.6)),"6a5a48")
	s.box(root,Vector3(0,2.66,0),Vector3(w,0.18,0.24),frame)
	s.box(root,Vector3(0,2.45,0),Vector3(0.12,0.3,0.12),"3a3530")
	for band: int in 6:
		var r: float = lerpf(0.34,0.52,float(band)/5.0)*bell
		s.box(root,Vector3(0,2.24-band*0.24,0),Vector3(r,0.24,r),String(bronze[band%bronze.size()]))
	s.box(root,Vector3(0,0.94,0),Vector3(bell*0.56,0.06,bell*0.56),String(bronze[2]))
	for knob: int in 6:
		s.box(root,Vector3(-0.15+(knob%3)*0.15,2.0-floorf(knob/3.0)*0.18,bell*0.21),Vector3(0.05,0.05,0.04),"7a7650")
	s.tilted_box(root,Vector3(-w*0.05,1.6,bell*0.45),Vector3(0.9,0.14,0.14),"8a6a45",Vector3(0,0.1,0))
	for x: float in [-0.3,0.2]:
		s.box(root,Vector3(x,2.12,bell*0.45),Vector3(0.02,1.0,0.02),"b8a374")

## 鲜花素果 (temple1.c: 朱红色的大供桌, 上面排满了鲜花素果): a red cloth runner down the front,
## vases of fresh flowers at both ends, plates of fruit along it, red candles burning in pewter
## sticks, and a bronze censer in the middle with incense smoking.
func _offerings(w: float, d: float) -> void:
	var cloth: String = String(data.get("cloth","b23a2a"))
	s.box(root,Vector3(0,0.885,0),Vector3(w*0.4,0.01,d+0.02),cloth)
	s.box(root,Vector3(0,0.62,d/2+0.02),Vector3(w*0.4,0.5,0.015),cloth)
	s.box(root,Vector3(0,0.42,d/2+0.03),Vector3(w*0.34,0.06,0.015),"d8b04a")
	var flowers: Array = data.get("flowers",["e04a5a","f2d24a","f4f0e6","d86ab0"])
	for end: float in [-1.0,1.0]:
		var at := Vector3(end*(w/2-0.25),0.88,-d*0.15)
		s.box(root,at+Vector3(0,0.14,0),Vector3(0.18,0.28,0.18),"3f6f8a")
		s.box(root,at+Vector3(0,0.3,0),Vector3(0.12,0.06,0.12),"4f86a2")
		for stem: int in 7:
			var a: float = stem*TAU/7.0
			var tip := at+Vector3(cos(a)*0.14,0.5+fposmod(stem*0.37,0.2),sin(a)*0.1)
			s.box(root,tip-Vector3(0,0.12,0),Vector3(0.025,0.2,0.025),"4f7a3a")
			s.box(root,tip,Vector3(0.11,0.09,0.11),String(flowers[(stem+int(end+1.0))%flowers.size()]))
	var fruit: Array = data.get("fruit",["e8823a","f0a43a","d8503a","e8d06a"])
	for plate: int in 4:
		var x: float = -w*0.33+plate*w*0.22
		var at := Vector3(x,0.89,d*0.18)
		s.box(root,at,Vector3(0.36,0.03,0.36),"e8e2d2")
		for i: int in 5:
			var layer: int = 0 if i<4 else 1
			s.box(root,at+Vector3(((i%2)-0.5)*0.12*(1-layer),0.07+layer*0.1,((i/2)%2-0.5)*0.12*(1-layer)),Vector3(0.12,0.11,0.12),String(fruit[(plate+i)%fruit.size()]))
	for side: float in [-1.0,1.0]:
		var at := Vector3(side*w*0.16,0.88,-d*0.25)
		s.box(root,at+Vector3(0,0.04,0),Vector3(0.16,0.08,0.16),"9a968a")
		s.box(root,at+Vector3(0,0.18,0),Vector3(0.05,0.22,0.05),"9a968a")
		s.box(root,at+Vector3(0,0.38,0),Vector3(0.08,0.2,0.08),"c8382a")
		var flame := Node3D.new()
		flame.position = at+Vector3(0,0.5,0)
		flame.set_meta("light_fixture",true)
		root.add_child(flame)
		s.box(flame,Vector3(0,0.05,0),Vector3(0.045,0.1,0.045),"ffd88a:glow")
		if ambience != null:
			ambience.flame(flame)
	s.box(root,Vector3(0,1.0,-d*0.1),Vector3(0.42,0.24,0.36),String(data.get("bronze","8a6a3a")))
	s.box(root,Vector3(0,1.13,-d*0.1),Vector3(0.48,0.04,0.42),"a8884e")
	for stick: int in 5:
		s.box(root,Vector3((stick-2)*0.06,1.27,-d*0.1),Vector3(0.02,0.26,0.02),"8a3a2a")
		s.box(root,Vector3((stick-2)*0.06,1.41,-d*0.1),Vector3(0.03,0.03,0.03),"ff8a3a:glow")
	if ambience != null:
		ambience.smoke(root,Vector3(0,1.45,-d*0.1),String(data.get("smoke","dcd6c8")),6,0.12)
	var light := OmniLight3D.new()
	light.position = Vector3(0,1.5,d*0.4)
	light.light_color = Color("ffbe78")
	light.omni_range = float(data.get("range",4.5))
	light.set_meta("day_energy",0.5)
	light.set_meta("night_energy",1.4)
	light.set_meta("flicker",0.08)
	root.add_child(light)

## A god in his hall (temple1.c: 一尊真武大帝的金身): a gilt figure seated on a throne on a
## stepped altar, black hair loose on his shoulders, armour over his robe, a sword upright in his
## right hand, his bare feet on a tortoise wound about by a snake (`tortoise`); a flame-shaped
## nimbus behind his head and silk hangings either side (`hangings`). `height` of the figure
## seated, `base` of the altar; colours from the data (`gold`, `robe`, `hair`, `face`, `altar`).
func _deity(w: float, d: float) -> void:
	var gold: Array = data.get("gold",["d4a23c","c38f2e","e2b856"])
	var robe: String = String(data.get("robe","9a2a22"))
	var hair: String = String(data.get("hair","1c1a1a"))
	var face: String = String(data.get("face","e0b060"))
	var stone: Array = data.get("altar",["8a3428","9a3c2c","7a2e24"])
	var h: float = float(data.get("height",2.2))
	var base: float = float(data.get("base",0.7))
	# The stepped altar, vermilion lacquer edged in gold.
	s.box(root,Vector3(0,base*0.3,0),Vector3(w,base*0.6,d),String(stone[0]))
	s.box(root,Vector3(0,base*0.8,-d*0.08),Vector3(w*0.82,base*0.4,d*0.84),String(stone[1]))
	s.box(root,Vector3(0,base*0.6,d/2),Vector3(w,0.05,0.04),String(gold[2]))
	s.box(root,Vector3(0,base,d*0.34),Vector3(w*0.82,0.05,0.04),String(gold[2]))
	var k: float = h/2.2
	var seat: float = base
	# The throne: a high back and arms in dark red and gold.
	s.box(root,Vector3(0,seat+0.35*k,-d*0.3),Vector3(w*0.62,0.7*k,d*0.3),String(stone[2]))
	s.box(root,Vector3(0,seat+1.3*k,-d*0.42),Vector3(w*0.56,1.9*k,0.12),String(stone[1]))
	s.box(root,Vector3(0,seat+2.28*k,-d*0.42),Vector3(w*0.64,0.12,0.16),String(gold[0]))
	# The nimbus: a ring of flame-tongues behind the head.
	var crown := Vector3(0,seat+1.95*k,-d*0.36)
	for tongue: int in 9:
		var a: float = PI*0.1+tongue*PI*0.8/8.0
		s.tilted_box(root,crown+Vector3(cos(a)*0.62*k,sin(a)*0.5*k,0),Vector3(0.12*k,0.34*k,0.04),"c8502a" if tongue%3==0 else String(gold[tongue%2]),Vector3(0,0,a-PI/2))
	s.box(root,crown+Vector3(0,0,0.01),Vector3(0.9*k,0.9*k,0.03),"e8c868")
	# The figure: lap and shins, armoured chest over the robe, broad shoulders, arms.
	var front: float = d*0.05
	s.box(root,Vector3(0,seat+0.42*k,front),Vector3(0.9*k,0.36*k,0.7*k),String(gold[1]))
	for leg: float in [-1.0,1.0]:
		s.box(root,Vector3(leg*0.22*k,seat+0.3*k,front+0.36*k),Vector3(0.28*k,0.42*k,0.24*k),String(gold[1]))
		s.box(root,Vector3(leg*0.22*k,seat+0.06*k,front+0.46*k),Vector3(0.22*k,0.1*k,0.3*k),face)
	s.box(root,Vector3(0,seat+0.5*k,front+0.36*k),Vector3(0.36*k,0.4*k,0.06),robe)
	s.box(root,Vector3(0,seat+1.0*k,-d*0.1),Vector3(0.82*k,0.72*k,0.5*k),String(gold[0]))
	s.box(root,Vector3(0,seat+1.0*k,-d*0.1+0.26*k),Vector3(0.5*k,0.5*k,0.02),String(gold[2]))
	s.box(root,Vector3(0,seat+0.7*k,-d*0.1+0.27*k),Vector3(0.84*k,0.1*k,0.03),robe)
	for shoulder: float in [-1.0,1.0]:
		s.box(root,Vector3(shoulder*0.5*k,seat+1.28*k,-d*0.1),Vector3(0.3*k,0.2*k,0.42*k),String(gold[2]))
		s.box(root,Vector3(shoulder*0.52*k,seat+0.96*k,-d*0.02),Vector3(0.2*k,0.5*k,0.24*k),String(gold[0]))
	# Left hand resting on the knee, the right raising the sword.
	s.box(root,Vector3(-0.36*k,seat+0.66*k,front+0.24*k),Vector3(0.16*k,0.14*k,0.18*k),face)
	s.box(root,Vector3(0.44*k,seat+0.8*k,front+0.16*k),Vector3(0.16*k,0.16*k,0.18*k),face)
	s.box(root,Vector3(0.44*k,seat+1.4*k,front+0.16*k),Vector3(0.06*k,1.1*k,0.03),"c8ccc8")
	s.box(root,Vector3(0.44*k,seat+0.9*k,front+0.16*k),Vector3(0.24*k,0.05*k,0.08*k),String(gold[2]))
	# Head, a full face, loose black hair falling to the shoulders, a small gold crown.
	var head := Vector3(0,seat+1.62*k,-d*0.08)
	s.box(root,head,Vector3(0.42*k,0.46*k,0.4*k),face)
	s.box(root,head+Vector3(0,0.2*k,-0.04*k),Vector3(0.48*k,0.16*k,0.44*k),hair)
	s.box(root,head+Vector3(0,-0.1*k,-0.12*k),Vector3(0.52*k,0.6*k,0.2*k),hair)
	for side: float in [-1.0,1.0]:
		s.box(root,head+Vector3(side*0.24*k,-0.28*k,-0.02*k),Vector3(0.08*k,0.5*k,0.2*k),hair)
	s.box(root,head+Vector3(0,0.32*k,0),Vector3(0.22*k,0.1*k,0.2*k),String(gold[2]))
	if data.get("armour",false):
		# altar.c: 火龙将军高大威武的神像 — a general: a helmet with a red plume over the crown,
		# plates of gilt scale over the chest and shoulders, a halberd in the raised hand.
		s.box(root,head+Vector3(0,0.3*k,-0.02*k),Vector3(0.5*k,0.2*k,0.46*k),String(gold[0]))
		s.box(root,head+Vector3(0,0.48*k,0),Vector3(0.12*k,0.3*k,0.12*k),String(gold[2]))
		s.box(root,head+Vector3(0,0.7*k,0),Vector3(0.1*k,0.3*k,0.1*k),"c8382a")
		for row: int in 4:
			s.box(root,Vector3(0,seat+0.78*k+row*0.14*k,-d*0.1+0.27*k),Vector3(0.76*k,0.06*k,0.03),String(gold[2]) if row%2 else String(gold[1]))
		for shoulder: float in [-1.0,1.0]:
			s.box(root,Vector3(shoulder*0.56*k,seat+1.36*k,-d*0.1),Vector3(0.24*k,0.12*k,0.46*k),String(gold[2]))
		s.box(root,Vector3(0.44*k,seat+1.9*k,front+0.16*k),Vector3(0.14*k,0.3*k,0.03),"c8ccc8")
	s.box(root,head+Vector3(0,-0.04*k,0.205*k),Vector3(0.22*k,0.03,0.01),"3a2a20")
	s.box(root,head+Vector3(0,-0.2*k,0.205*k),Vector3(0.14*k,0.03,0.01),"7a3a2a")
	if data.get("tortoise",true):
		# On the lower step, in front of the upper tier.
		var at := Vector3(0,base*0.6+0.08*k,d*0.42)
		s.box(root,at,Vector3(0.6*k,0.16*k,0.4*k),"4a5a3a")
		s.box(root,at+Vector3(0,0.1*k,0),Vector3(0.44*k,0.08*k,0.3*k),"5f6e48")
		s.box(root,at+Vector3(0.36*k,0.02,0.04*k),Vector3(0.14*k,0.1*k,0.12*k),"4a5a3a")
		for coil: int in 6:
			var a: float = coil*TAU/6.0
			s.box(root,at+Vector3(cos(a)*0.34*k,0.12*k+coil*0.012,sin(a)*0.24*k),Vector3(0.14*k,0.07*k,0.1*k),"2f3a2a")
		s.box(root,at+Vector3(-0.38*k,0.24*k,0.12*k),Vector3(0.08*k,0.08*k,0.1*k),"2f3a2a")
	if data.get("hangings",true):
		var silk: Array = data.get("silk",["d8a83a","c8902a","b8382a"])
		for side: float in [-1.0,1.0]:
			var hang := Node3D.new()
			hang.position = Vector3(side*w*0.46,seat+2.5*k,-d*0.2)
			root.add_child(hang)
			s.box(hang,Vector3(0,-0.9*k,0),Vector3(0.16,1.8*k,0.05),String(silk[0]))
			s.box(hang,Vector3(0,-1.82*k,0),Vector3(0.18,0.1,0.06),String(silk[2]))
			s.box(hang,Vector3(0,0.02,0),Vector3(0.24,0.08,0.08),String(silk[1]))
			if ambience != null:
				ambience.sway(hang,side*0.9,0.05)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0,seat+1.4*k,d*0.9)
	glow.light_color = Color("ffd290")
	glow.omni_range = float(data.get("range",5.0))
	glow.set_meta("day_energy",0.35)
	glow.set_meta("night_energy",0.9)
	root.add_child(glow)

## 牌位 (temple2.c: 剑的两旁陪祀著历代掌门人的牌位): a lacquered stand of three steps, on each a
## row of spirit tablets, red with gold edges and a gilt inscription, their heights uneven, a
## lamp of everlasting oil before them.
func _spirit_tablets(w: float, d: float) -> void:
	var lacquer: Array = data.get("stand",["3a2420","4a2c24","2e1e1a"])
	var tablet: Array = data.get("tablets",["8a2a22","9a3428","7a241e","5a2a22"])
	var count: int = int(data.get("count",4))
	for step: int in 3:
		var y: float = 0.3+step*0.32
		var z: float = d*0.3-step*d*0.28
		s.box(root,Vector3(0,y/2,z),Vector3(w,y,d*0.3),String(lacquer[step%lacquer.size()]))
		var row: int = count-step%2
		for i: int in row:
			var x: float = -w*0.4+(i+0.5)*w*0.8/row
			var th: float = 0.46+fposmod(i*0.29+step*0.41,0.2)
			s.box(root,Vector3(x,y+0.04,z),Vector3(0.18,0.08,0.12),"2a1c18")
			s.box(root,Vector3(x,y+0.08+th/2,z),Vector3(0.14,th,0.04),String(tablet[(i+step)%tablet.size()]))
			s.box(root,Vector3(x,y+0.1+th,z),Vector3(0.18,0.05,0.06),"c8a24a")
			s.box(root,Vector3(x,y+0.08+th*0.5,z+0.022),Vector3(0.03,th*0.7,0.005),"d8b45a")
	s.box(root,Vector3(0,0.34,d*0.4),Vector3(0.16,0.08,0.16),"8a7a5a")
	var flame := Node3D.new()
	flame.position = Vector3(0,0.42,d*0.4)
	flame.set_meta("light_fixture",true)
	root.add_child(flame)
	s.box(flame,Vector3(0,0.03,0),Vector3(0.035,0.06,0.035),"ffcf7a:glow")
	if ambience != null:
		ambience.flame(flame)

## 宝剑 (temple2.c: 当年张天师收妖伏魔时所用的宝剑): a narrow table under a yellow cloth, on
## it a carved stand holding the sheathed sword level on its two rests, a red tassel hanging
## from the hilt, the seven stars inlaid on the scabbard.
func _sword_stand(w: float, d: float) -> void:
	var wood: String = String(data.get("wood","3e2620"))
	var cloth: String = String(data.get("cloth","d8b03a"))
	s.box(root,Vector3(0,0.86,0),Vector3(w,0.1,d),wood)
	for x: float in [-w/2+0.08,w/2-0.08]:
		for z: float in [-d/2+0.08,d/2-0.08]:
			s.box(root,Vector3(x,0.42,z),Vector3(0.09,0.84,0.09),wood)
	s.box(root,Vector3(0,0.915,0),Vector3(w+0.02,0.01,d*0.8),cloth)
	s.box(root,Vector3(0,0.7,d/2+0.01),Vector3(w*0.8,0.42,0.012),cloth)
	s.box(root,Vector3(0,0.96,0),Vector3(w*0.7,0.08,0.3),"5a3428")
	for rest: float in [-1.0,1.0]:
		s.box(root,Vector3(rest*w*0.22,1.08,0),Vector3(0.08,0.2,0.16),"5a3428")
		s.box(root,Vector3(rest*w*0.22,1.2,0),Vector3(0.1,0.06,0.2),"c8a24a")
	var blade := Vector3(0,1.26,0)
	s.box(root,blade,Vector3(w*0.62,0.07,0.08),"2a2a30")
	s.box(root,blade+Vector3(w*0.33,0,0),Vector3(0.08,0.16,0.14),"c8a24a")
	s.box(root,blade+Vector3(w*0.41,0,0),Vector3(0.18,0.06,0.06),"5a2a22")
	s.box(root,blade-Vector3(w*0.31,0,0),Vector3(0.06,0.09,0.1),"c8a24a")
	for star: int in 7:
		s.box(root,blade+Vector3(-w*0.22+star*0.09,0.04,sin(star*1.9)*0.02),Vector3(0.025,0.01,0.025),"e8d07a")
	var tassel := Node3D.new()
	tassel.position = blade+Vector3(w*0.5,0,0)
	root.add_child(tassel)
	s.box(tassel,Vector3(0,-0.16,0),Vector3(0.05,0.3,0.05),"b8302a")
	if ambience != null:
		ambience.sway(tassel,0.7,0.06)

## 经案 (book_room2.c: 一张覆著红布的桌子, 桌上整齐地放著茅山的镇教秘籍): a long table under a red
## cloth hanging to the floor, the sacred books laid on it in neat stacks, bound in blue and
## yellow, a brass lamp and a little incense burner beside them.
func _scripture_table(w: float, d: float) -> void:
	var cloth: String = String(data.get("cloth","a8302a"))
	s.box(root,Vector3(0,0.42,0),Vector3(w,0.84,d),String(data.get("wood","4a2c22")))
	s.box(root,Vector3(0,0.86,0),Vector3(w+0.04,0.04,d+0.04),cloth)
	s.box(root,Vector3(0,0.44,d/2+0.03),Vector3(w+0.04,0.84,0.02),cloth)
	s.box(root,Vector3(0,0.1,d/2+0.04),Vector3(w+0.04,0.06,0.02),"d8b04a")
	var covers: Array = data.get("covers",["2f4a7a","c8a03a","3a5a8a","b89030"])
	var stacks: int = maxi(2,floori(w/0.5))
	for stack: int in stacks:
		var x: float = -w*0.38+stack*w*0.76/maxf(1,stacks-1)
		for book: int in 2+stack%3:
			s.box(root,Vector3(x,0.92+book*0.07,0),Vector3(0.34,0.06,0.46),String(covers[(stack+book)%covers.size()]))
			s.box(root,Vector3(x+0.172,0.92+book*0.07,0),Vector3(0.01,0.05,0.44),"e8e0c8")
	_candles(Vector3(-w/2+0.2,0.88,-d*0.25),1)
	# 木鱼 (`fish`): the wooden fish and its beater, for the chanting.
	if data.get("fish",false):
		s.box(root,Vector3(-w*0.18,0.98,d*0.22),Vector3(0.3,0.2,0.26),"a8442a")
		s.box(root,Vector3(-w*0.18,1.06,d*0.22),Vector3(0.18,0.06,0.2),"b8562e")
		s.tilted_box(root,Vector3(-w*0.05,0.92,d*0.3),Vector3(0.04,0.03,0.3),"7a5a3a",Vector3(0,0.6,0))
	s.box(root,Vector3(w/2-0.2,0.94,-d*0.2),Vector3(0.16,0.12,0.16),"7a6040")
	if ambience != null:
		ambience.smoke(root,Vector3(w/2-0.2,1.02,-d*0.2),"d8d2c4",3,0.08)
