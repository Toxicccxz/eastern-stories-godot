class_name VoxelArchitecture
extends RefCounted

## Data-authored massing and construction, independent of the real portal/collision map.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var shapes: Shapes
var parent: Node3D
var rng: RandomNumberGenerator
var noise: FastNoiseLite
var occluders: Array[Dictionary] = []

func _node(at: Vector3, into: Node3D) -> Node3D:
	var node := Node3D.new()
	node.position = at
	into.add_child(node)
	return node

func build(center: Vector3, w: float, d: float, data: Dictionary, entrances: Array[Vector3]) -> void:
	var body: Node3D = _node(center,parent)
	occluders.append({"node":body})
	var height: float = data.get("height",3.4)
	var masses: Array = data.get("masses",[])
	var enclosure: float = data.get("enclosure_height",height)
	_walls(body,w,d,enclosure,data,entrances)
	if masses.is_empty():
		_roof(body,Vector3.ZERO,w,d,height,data)
	else:
		for mass: Dictionary in masses:
			var bounds: Array = mass["bounds"]
			var mw: float = (bounds[2]-bounds[0])*w
			var md: float = (bounds[3]-bounds[1])*d
			var offset := Vector3(((bounds[0]+bounds[2])*0.5-0.5)*w,0,((bounds[1]+bounds[3])*0.5-0.5)*d)
			var section: Node3D = _node(offset,body)
			var config: Dictionary = data.duplicate()
			config.merge(mass,true)
			var mh: float = config.get("height",height)
			var local_entries: Array[Vector3] = []
			for entrance: Vector3 in entrances:
				local_entries.append(entrance-offset)
			_walls(section,mw,md,mh,config,local_entries)
			_roof(section,Vector3.ZERO,mw,md,mh,config)
	if data.get("chimney",false):
		var chimney_at := Vector3(-w*0.24,height+0.65,d*0.17)
		for course: int in 10:
			shapes.box(body,chimney_at+Vector3(0,course*0.19,0),Vector3(0.77,0.175,0.79),["625e51","77705d","686659"][course%3])
		shapes.box(body,chimney_at+Vector3(0,1.95,0),Vector3(0.94,0.2,0.95),"525649")
		shapes.box(body,chimney_at+Vector3(0,2.06,0),Vector3(0.55,0.02,0.56),"303c36")
	for door: Vector3 in entrances:
		_entrance(body,door,w,d,data)

func _walls(body: Node3D, w: float, d: float, height: float, data: Dictionary, entrances: Array[Vector3]) -> void:
	var plaster := Color(String(data.get("wall","c8b999")))
	var timber: String = data.get("timber","79533d")
	var construction: String = data.get("construction","plaster")
	var bay: int = int(data.get("bay",6))
	var foundation: float = data.get("foundation",0.48)
	for side: int in 4:
		var along_x: bool = side<2
		var length: float = w if along_x else d
		var fixed: float = (d if along_x else w)/2*(1 if side%2 else -1)
		var out := Vector3(0,0,signf(fixed)) if along_x else Vector3(signf(fixed),0,0)
		for i: int in ceili(length/0.5):
			var along: float = -length/2+0.25+i*0.5
			var at := Vector3(along,height/2,fixed) if along_x else Vector3(fixed,height/2,along)
			var gap: bool = false
			for door: Vector3 in entrances:
				if absf((door.z if along_x else door.x)-fixed)<1.6 and absf((door.x if along_x else door.z)-along)<1.15:
					gap = true
			if gap:
				continue
			var panel := Vector3(0.50,height,0.24) if along_x else Vector3(0.24,height,0.50)
			var weather: float = noise.get_noise_2d((body.position.x+at.x)*29,(body.position.z+at.z)*29)
			var tone: String = plaster.darkened(0.035*roundf((weather+0.5)*3)).to_html(false)
			shapes.box(body,at,panel,tone)
			# Stone plinth courses have their own lengths, joints and water staining.
			for course: int in maxi(1,ceili(foundation/0.22)):
				var base_at := Vector3(at.x,0.10+course*0.21,at.z)+out*0.06
				shapes.shard(body,base_at,Vector3(0.53,0.21,0.37) if along_x else Vector3(0.37,0.21,0.53),["848572","92907b","777d6c"][(i+course)%3],i+course,0.02*sin(i))
			if construction=="timber":
				for board: int in ceili(height/0.21):
					shapes.box(body,Vector3(at.x,board*0.21+0.1,at.z)+out*0.14,Vector3(0.495,0.19,0.035) if along_x else Vector3(0.035,0.19,0.495),["96744e","896747","a17c53"][(board+i/3)%3])
			elif construction=="rubble":
				# Dry-laid field stone: courses of irregular blocks proud of the face.
				for course: int in ceili(height/0.3):
					var stone_at := Vector3(at.x+sin(i*2.7+course)*0.06,course*0.3+0.15,at.z)+out*0.14
					var stones: Array = data.get("stones",["8a7c64","978a70","7a6e5a","a39577"])
					shapes.shard(body,stone_at,Vector3(0.52,0.28,0.12) if along_x else Vector3(0.12,0.28,0.52),String(stones[(i*3+course)%stones.size()]),i+course,0.0)
			elif construction=="earth":
				# 土墙: rammed earth in bands, rain-scored, a crack here and there.
				var bands: Array = data.get("bands",["a68a5f","9a7f57","b0946a"])
				for band: int in ceili(height/0.35):
					shapes.box(body,Vector3(at.x,band*0.35+0.17,at.z)+out*0.13,Vector3(0.5,0.33,0.03) if along_x else Vector3(0.03,0.33,0.5),String(bands[(band+floori(i/4.0))%bands.size()]))
				if i%5==2:
					shapes.box(body,Vector3(at.x,height*0.55,at.z)+out*0.15,Vector3(0.04,height*0.4,0.02) if along_x else Vector3(0.02,height*0.4,0.04),"5e4a35")
			elif construction=="brick":
				for course: int in ceili(height/0.28):
					var brick_at := Vector3(at.x,course*0.28+0.13,at.z)+out*0.15
					shapes.box(body,brick_at,Vector3(0.465,0.25,0.05) if along_x else Vector3(0.05,0.25,0.465),["737c73","858b7a","69766e"][(i+course*2)%3])
			elif weather>0.05 and i%3==1:
				# Small patches of lost plaster expose the underlying masonry near the base.
				for chip: int in 3:
					shapes.box(body,Vector3(at.x,foundation+0.13+chip*0.17,at.z)+out*0.135,Vector3(0.40-chip*0.09,0.15,0.025) if along_x else Vector3(0.025,0.15,0.40-chip*0.09),"a29171")
			if i%bay==0:
				shapes.box(body,at+out*0.08,Vector3(0.18,height+0.08,0.31) if along_x else Vector3(0.31,height+0.08,0.18),timber)
			elif i%bay in [2,3] and height>2.4:
				var window_y: float = minf(2.05,height-0.9)
				var window_at := Vector3(at.x,window_y,at.z)+out*0.18
				shapes.box(body,window_at,Vector3(0.47,0.94,0.10) if along_x else Vector3(0.10,0.94,0.47),timber)
				shapes.window(body,window_at+out*0.06,Vector3(0.35,0.73,0.03) if along_x else Vector3(0.03,0.73,0.35))
				if i==3:
					var light := OmniLight3D.new()
					light.position = window_at+out*0.6
					light.light_color = Color("ffc27a")
					light.omni_range = 3.0
					light.omni_attenuation = 1.6
					light.set_meta("day_energy",0.0)
					light.set_meta("night_energy",1.2)
					body.add_child(light)
				shapes.box(body,window_at+out*0.09,Vector3(0.045,0.76,0.03) if along_x else Vector3(0.03,0.76,0.045),timber)
				if data.get("lattice",false):
					for bar: float in [-0.20,0.04,0.26]:
						shapes.box(body,window_at+out*0.1+Vector3(0,bar,0),Vector3(0.40,0.035,0.03) if along_x else Vector3(0.03,0.035,0.40),timber)
				if construction=="timber" and i%bay==2:
					shapes.box(body,window_at+out*0.13,Vector3(0.38,0.78,0.06) if along_x else Vector3(0.06,0.78,0.38),"796348")
		shapes.box(body,Vector3(0,height-0.13,fixed) if along_x else Vector3(fixed,height-0.13,0),Vector3(w,0.18,0.33) if along_x else Vector3(0.33,0.18,d),timber)
		if data.get("gallery",false):
			var rail_at := Vector3(0,height-0.65,fixed) if along_x else Vector3(fixed,height-0.65,0)
			shapes.box(body,rail_at+out*0.32,Vector3(w,0.13,0.12) if along_x else Vector3(0.12,0.13,d),timber)
			shapes.box(body,rail_at+out*0.26-Vector3(0,0.55,0),Vector3(w,0.13,0.55) if along_x else Vector3(0.55,0.13,d),"8a6546")
			for post: int in ceili(length/0.55):
				var along: float = -length/2+post*0.55
				shapes.box(body,(Vector3(along,height-0.90,fixed) if along_x else Vector3(fixed,height-0.90,along))+out*0.32,Vector3(0.065,0.5,0.065),timber)

func _roof(into: Node3D, at: Vector3, w: float, d: float, height: float, data: Dictionary) -> void:
	var root: Node3D = _node(at,into)
	var direction: String = data.get("ridge", "z" if d>w else "x")
	if direction=="z":
		root.rotation.y = PI/2
	var wide: float = (d if direction=="z" else w)+float(data.get("overhang",0.7))
	var deep: float = (w if direction=="z" else d)+float(data.get("overhang",0.7))
	var rise: float = data.get("rise",1.5)
	var form: String = data.get("roof_form","gable")
	var curve: float = data.get("eave_lift",0.10)
	var tint := Color(String(data.get("roof","50626a")))
	var timber: String = data.get("timber","79533d")
	var cols: int = ceili(wide/0.37)
	var rows: int = ceili(deep/0.37)
	var spacing_x: float = wide/cols
	var spacing_z: float = deep/rows
	# Solid stepped gable ends under the roof, instead of floating open triangular gaps.
	if form=="gable":
		for end: float in [-1.0,1.0]:
			for tier: int in ceili(rise/0.18):
				var t: float = tier*0.18/rise
				shapes.box(root,Vector3(end*(wide/2-0.35),height+tier*0.18,0),Vector3(0.18,0.18,maxf(0.2,(deep-0.65)*(1-t))),data.get("wall","c8b999"))
	for z: int in rows:
		var pz: float = -deep/2+(z+0.5)*spacing_z
		for x: int in cols:
			var px: float = -wide/2+(x+0.5)*spacing_x
			var inset: float = minf(deep/2-absf(pz),wide/2-absf(px))
			var t: float = clampf(absf(pz)/(deep/2),0,1)
			var top: float = (1-t)*rise
			if form=="hip":
				top = minf(rise,inset/(deep/2)*rise)
			elif form=="shed":
				top = (pz/deep+0.5)*rise
			var lift: float = pow(t,5)*curve
			var sag: float = -0.10*sin((px/wide+0.5)*PI)*sin(t*PI)
			var tile_at := Vector3(px+rng.randf_range(-0.018,0.018),height+0.10+top+lift+sag+rng.randf_range(-0.018,0.018),pz+rng.randf_range(-0.018,0.018))
			var shade: int = clampi(roundi(noise.get_noise_2d((px+into.position.x)*27,(pz+into.position.z)*27)*3)+2,0,4)
			var tile_color: String = tint.lightened(shade*0.025).to_html(false)
			shapes.box(root,tile_at,Vector3(spacing_x+0.018,0.14,spacing_z+0.035),tile_color)
			# A few displaced/repaired tiles, and weathering concentrated on shaded eaves.
			if (z<2 or z>rows-3) and rng.randf()<0.13:
				shapes.box(root,tile_at+Vector3(0,0.077,0),Vector3(0.21,0.015,0.17),["748363","7e8d69","8c9775"][x%3])
			elif rng.randf()<0.012:
				shapes.tilted_box(root,tile_at+Vector3(0.04,0.09,0.04),Vector3(0.22,0.07,0.3),tint.darkened(0.13).to_html(false),Vector3(0,0.15,0))
	# Segmented ridge with raised ends, not one ruler-straight bar.
	if form!="shed":
		var ridge_length: float = wide if form=="gable" else maxf(0.4,wide-deep+0.5)
		for cap: int in ceili(ridge_length/0.42):
			var x: float = -ridge_length/2+(cap+0.5)*0.42
			var up: float = pow(absf(x)/maxf(0.2,ridge_length/2),6)*curve
			shapes.box(root,Vector3(x,height+rise+0.24+up,0),Vector3(0.43,0.24,0.29),tint.darkened(0.10).to_html(false))
	for side: float in [-1.0,1.0]:
		var eave_y: float = height+curve
		if form=="shed" and side>0:
			eave_y += rise
		shapes.box(root,Vector3(0,eave_y-0.10,side*deep/2),Vector3(wide,0.19,0.16),timber)
		for bracket: int in ceili(wide/1.25):
			shapes.box(root,Vector3(-wide/2+0.45+bracket*1.25,eave_y-0.24,side*(deep/2-0.13)),Vector3(0.14,0.23,0.45),timber)

func _entrance(body: Node3D, door: Vector3, w: float, d: float, data: Dictionary) -> void:
	var front: Node3D = _node(door,body)
	var x_face: bool = absf(door.x)>w/2-1.7
	front.rotation.y = signf(door.x)*PI/2 if x_face else (0.0 if door.z>0 else PI)
	var timber: String = data.get("timber","79533d")
	for x: float in [-1.13,1.13]:
		shapes.box(front,Vector3(x,1.3,0),Vector3(0.2,2.6,0.27),timber)
		if data.get("lanterns",true):
			shapes.lantern(front,Vector3(x*1.23,2.15,0.25))
	shapes.box(front,Vector3(0,2.68,0),Vector3(2.55,0.25,0.38),timber)
	shapes.box(front,Vector3(0,0.025,0),Vector3(2.2,0.07,1.0),String(data.get("step","b7b091")))
	if data.get("doorway","")=="dark":
		# An unlit doorway (黑漆漆): black within, one leaf hanging open on a hinge.
		shapes.box(front,Vector3(0,1.2,-0.3),Vector3(2.0,2.4,0.5),"14110f")
		shapes.tilted_box(front,Vector3(-0.75,1.1,0.25),Vector3(0.75,2.1,0.08),String(data.get("leaf","6b5038")),Vector3(0,-0.9,0))
	var porch: String = data.get("porch","tiled")
	if porch=="cloth":
		for stripe: int in 10:
			shapes.tilted_box(front,Vector3(-1.65+stripe*0.37,2.90,0.68),Vector3(0.375,0.07,1.65),"7c8c64" if stripe%2 else "c8bc94",Vector3(0.13,0,0))
			shapes.box(front,Vector3(-1.65+stripe*0.37,2.67,1.49),Vector3(0.37,0.22,0.05),"7c8c64" if stripe%2 else "c8bc94")
	elif porch=="tiled":
		_roof(front,Vector3(0,0,0.50),3.1,1.6,2.8,{"roof":data.get("roof","50626a"),"roof_form":"hip","ridge":"x","rise":0.55,"eave_lift":0.18,"timber":timber})
	elif porch=="wood":
		for plank: int in 10:
			shapes.tilted_box(front,Vector3(-1.6+plank*0.35,2.85,0.65),Vector3(0.34,0.10,1.65),["8e7451","9b7c53","806746"][plank%3],Vector3(0.12,0,0))
	var goods: String = data.get("goods","pots")
	for side: float in [] if goods=="none" else [-1.0,1.0]:
		var pos := Vector3(side*1.85,0,0.35)
		if goods=="sacks":
			for sack: int in 3:
				shapes.shard(front,pos+Vector3(sack*0.22,0.28+sack%2*0.3,0),Vector3(0.65,0.55,0.55),["b09a69","bdaa7b","a78f5d"][sack],sack)
		elif goods=="tools":
			shapes.box(front,pos+Vector3(0,0.3,0),Vector3(0.70,0.58,0.65),"72664b")
			for tool: int in 3:
				shapes.tilted_box(front,pos+Vector3((tool-1)*0.16,0.9,0),Vector3(0.05,0.95,0.06),"5d4d3b",Vector3(0.09,0,0.10*(tool-1)))
				shapes.box(front,pos+Vector3((tool-1)*0.16,1.26,0),Vector3(0.22,0.19,0.12),"6b7d7b")
		else:
			shapes.pot(front,pos)
			for stem: int in 3:
				shapes.box(front,pos+Vector3((stem-1)*0.12,0.9+stem*0.08,0.04),Vector3(0.14,0.07,0.13),["ead7a1","d799af","f1e5c2"][stem])
	# Rain stains and climbing leaves stay on the facade and use its local reveal mask.
	for leaf: int in 10 if goods=="pots" else (0 if goods=="none" else 3):
		shapes.box(front,Vector3(-2.3+sin(leaf*1.6)*0.15,0.35+leaf*0.20,-0.12),Vector3(0.27,0.15,0.18),["507855","739351","91a962"][leaf%3])
