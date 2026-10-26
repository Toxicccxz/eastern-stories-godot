class_name VoxelArchitecture
extends RefCounted

## Data-authored massing and construction, independent of the real portal/collision map.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var shapes: Shapes
var parent: Node3D
var rng: RandomNumberGenerator
var noise: FastNoiseLite
var occluders: Array[Dictionary] = []
## Chimney smoke and flags stirring on a facade (null where nothing moves).
var ambience: VoxelAmbience

var _body: Node3D

## A part of the building; unless it moves (a flag in the wind), its forms batch with the
## building's body (Shapes.merge: its pose is read when something is drawn into it).
func _node(at: Vector3, into: Node3D, moves: bool = false) -> Node3D:
	var node := Node3D.new()
	node.position = at
	into.add_child(node)
	if _body != null and not moves:
		shapes.merge(node,_body)
	return node

## `arches`: those of the entrances that are round openings in the wall (a hall's 圆形拱门), no
## porch or door.
func build(center: Vector3, w: float, d: float, data: Dictionary, entrances: Array[Vector3], arches: Array[Vector3] = []) -> void:
	_body = null
	var body: Node3D = _node(center,parent)
	_body = body
	occluders.append({"node":body})
	var height: float = data.get("height",3.4)
	var masses: Array = data.get("masses",[])
	var enclosure: float = data.get("enclosure_height",height)
	# `ruined` (spath.c: 路旁隐约可见房舍, 皆已破败): walls fallen to uneven heights, no roof.
	var ruined: bool = data.get("ruined",false)
	_walls(body,w,d,enclosure,data,entrances)
	if ruined:
		pass
	elif masses.is_empty():
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
		var spot: Array = data.get("chimney_at",[-0.24,0.17])
		var chimney_at := Vector3(w*float(spot[0]),height+0.65,d*float(spot[1]))
		for course: int in 10:
			shapes.box(body,chimney_at+Vector3(0,course*0.19,0),Vector3(0.77,0.175,0.79),["625e51","77705d","686659"][course%3])
		shapes.box(body,chimney_at+Vector3(0,1.95,0),Vector3(0.94,0.2,0.95),"525649")
		shapes.box(body,chimney_at+Vector3(0,2.06,0),Vector3(0.55,0.02,0.56),"303c36")
		# 炊烟: smoke curling up from the kitchen fire.
		if data.get("smoke",false) and ambience != null:
			# On a node of its own beside the body: the body is an occluder, whose reveal
			# material would turn the see-through puffs solid.
			var smoke := Node3D.new()
			smoke.position = center+chimney_at+Vector3(0,2.2,0)
			parent.add_child(smoke)
			ambience.smoke(smoke,Vector3.ZERO,String(data.get("smoke_color","9a978d")),5,0.26)
	# 腰檐: a pent eave round a two-storey house between its floors (a tea house, a 春楼).
	if data.has("skirt"):
		_skirt(body,w,d,float(data["skirt"]),data)
	# `skirts`: one pent eave per floor of a taller house (n_street2.c: 一家三层楼的酒馆).
	for at: Variant in data.get("skirts",[]):
		_skirt(body,w,d,float(at),data)
	if ruined:
		# The roof gone, rubble and weeds inside the walls.
		for i: int in 9:
			shapes.shard(body,Vector3(rng.randf_range(-0.35,0.35)*w,0.1,rng.randf_range(-0.35,0.35)*d),Vector3(0.5,0.2,0.4),["8a8276","7a7268","948c80"][i%3],i)
			shapes.box(body,Vector3(rng.randf_range(-0.4,0.4)*w,0.14,rng.randf_range(-0.4,0.4)*d),Vector3(0.12,0.28,0.12),"5f7a3a")
		shapes.tilted_box(body,Vector3(0,0.5,0),Vector3(0.2,0.2,d*0.8),"5a4a3a",Vector3(0,0.3,0.2))
	for door: Vector3 in entrances:
		if door in arches:
			_arch(body,door,w,d,data)
		else:
			_entrance(body,door,w,d,data)

func _walls(body: Node3D, w: float, d: float, height: float, data: Dictionary, entrances: Array[Vector3]) -> void:
	var plaster := Color(String(data.get("wall","c8b999")))
	var timber: String = data.get("timber","79533d")
	var construction: String = data.get("construction","plaster")
	var bay: int = int(data.get("bay",6))
	var foundation: float = data.get("foundation",0.48)
	var gap_half: float = float(data.get("doorway_width",2.3))/2.0
	var ruined: bool = data.get("ruined",false)
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
				if absf((door.z if along_x else door.x)-fixed)<1.6 and absf((door.x if along_x else door.z)-along)<gap_half:
					gap = true
			if gap:
				continue
			var weather: float = noise.get_noise_2d((body.position.x+at.x)*29,(body.position.z+at.z)*29)
			if ruined:
				# Walls fallen to uneven heights, a gap here and there.
				if weather > 0.32:
					continue
				var left: float = height*(0.35+0.45*(weather+0.5))
				at.y = left/2
				shapes.box(body,at,Vector3(0.50,left,0.24) if along_x else Vector3(0.24,left,0.50),plaster.darkened(0.1).to_html(false))
				continue
			var panel := Vector3(0.50,height,0.24) if along_x else Vector3(0.24,height,0.50)
			var tone: String = plaster.darkened(0.035*roundf((weather+0.5)*3)).to_html(false)
			shapes.box(body,at,panel,tone)
			# Stone plinth courses have their own lengths, joints and water staining.
			for course: int in maxi(1,ceili(foundation/0.22)):
				var base_at := Vector3(at.x,0.10+course*0.21,at.z)+out*0.06
				var plinth: Array = data.get("plinth",["848572","92907b","777d6c"])
				shapes.shard(body,base_at,Vector3(0.53,0.21,0.37) if along_x else Vector3(0.37,0.21,0.53),String(plinth[(i+course)%plinth.size()]),i+course,0.02*sin(i))
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
		if not ruined:
			shapes.box(body,Vector3(0,height-0.13,fixed) if along_x else Vector3(fixed,height-0.13,0),Vector3(w,0.18,0.33) if along_x else Vector3(0.33,0.18,d),timber)
		if data.get("gallery",false):
			var rail_at := Vector3(0,height-0.65,fixed) if along_x else Vector3(fixed,height-0.65,0)
			shapes.box(body,rail_at+out*0.32,Vector3(w,0.13,0.12) if along_x else Vector3(0.12,0.13,d),timber)
			shapes.box(body,rail_at+out*0.26-Vector3(0,0.55,0),Vector3(w,0.13,0.55) if along_x else Vector3(0.55,0.13,d),"8a6546")
			for post: int in ceili(length/0.55):
				var along: float = -length/2+post*0.55
				shapes.box(body,(Vector3(along,height-0.90,fixed) if along_x else Vector3(fixed,height-0.90,along))+out*0.32,Vector3(0.065,0.5,0.065),timber)

func _roof(into: Node3D, at: Vector3, w: float, d: float, height: float, data: Dictionary) -> void:
	var direction: String = data.get("ridge", "z" if d>w else "x")
	var root: Node3D = _node(at,into)
	if direction=="z":
		root.rotation.y = PI/2
	var wide: float = (d if direction=="z" else w)+float(data.get("overhang",0.7))
	var deep: float = (w if direction=="z" else d)+float(data.get("overhang",0.7))
	var rise: float = data.get("rise",1.5)
	var form: String = data.get("roof_form","gable")
	var curve: float = data.get("eave_lift",0.10)
	# A glazed roof ("<hex>:gloss", 琉璃瓦) keeps its shine on every tile.
	var roof_color: String = String(data.get("roof","50626a"))
	var tint := Color(roof_color.get_slice(":",0))
	var glaze: String = "" if not roof_color.contains(":") else ":"+roof_color.get_slice(":",1)
	var timber: String = data.get("timber","79533d")
	if form=="terrace":
		_terrace(root,wide,deep,height,data)
		return
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
	# `roof_tiles`: "slate" (石板: rough stone slabs, moss in their laps) or "thatch" (茅草).
	var cover: String = String(data.get("roof_tiles","tiles"))
	if cover in ["slate","thatch"]:
		_rough_roof(root,wide,deep,height,rise,form,curve,tint,data,cover=="thatch")
	else:
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
				var tile_color: String = tint.lightened(shade*0.025).to_html(false)+glaze
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
				shapes.box(root,Vector3(x,height+rise+0.24+up,0),Vector3(0.43,0.24,0.29),tint.darkened(0.10).to_html(false)+glaze)
			# 鸱吻: the curled beasts at the ridge's ends (`ridge_ends`: their colour).
			if data.has("ridge_ends"):
				for end: float in [-1.0,1.0]:
					var end_at := Vector3(end*ridge_length/2,height+rise+0.24+curve,0)
					shapes.box(root,end_at+Vector3(0,0.3,0),Vector3(0.3,0.6,0.32),String(data["ridge_ends"]))
					shapes.box(root,end_at+Vector3(-end*0.16,0.68,0),Vector3(0.24,0.26,0.26),String(data["ridge_ends"]))
					shapes.box(root,end_at+Vector3(-end*0.3,0.86,0),Vector3(0.12,0.2,0.14),String(data["ridge_ends"]))
	for side: float in [-1.0,1.0]:
		var eave_y: float = height+curve
		if form=="shed" and side>0:
			eave_y += rise
		shapes.box(root,Vector3(0,eave_y-0.10,side*deep/2),Vector3(wide,0.19,0.16),timber)
		for bracket: int in 0 if cover=="thatch" else ceili(wide/1.25):
			shapes.box(root,Vector3(-wide/2+0.45+bracket*1.25,eave_y-0.24,side*(deep/2-0.13)),Vector3(0.14,0.23,0.45),timber)
		# Gilt beasts on the corners (`corner_beasts`, road1.c: 屋檐的四个角落雕就著四只栩栩如的金龙):
		# a dragon riding up each swept corner, its head reared out over the eave.
		if data.has("corner_beasts") and form!="shed":
			var gilt: String = String(data["corner_beasts"])
			for end: float in [-1.0,1.0]:
				var corner := Vector3(end*(wide/2-0.1),height+curve+0.16,side*(deep/2-0.1))
				shapes.tilted_box(root,corner+Vector3(-end*0.22,0.06,-side*0.1),Vector3(0.5,0.14,0.16),gilt,Vector3(0,-end*side*0.6,end*0.35))
				shapes.box(root,corner+Vector3(end*0.08,0.26,side*0.06),Vector3(0.18,0.2,0.2),gilt)
				shapes.box(root,corner+Vector3(end*0.16,0.38,side*0.12),Vector3(0.08,0.14,0.06),gilt)
				shapes.tilted_box(root,corner+Vector3(-end*0.46,0.2,-side*0.2),Vector3(0.24,0.06,0.08),gilt,Vector3(0,0,-end*0.8))
		# 风铎: a bronze bell hung under each corner of the eaves, stirring in the wind.
		if data.get("bells",false) and form!="shed":
			for end: float in [-1.0,1.0]:
				var bell: Node3D = _node(Vector3(end*wide/2,height+curve-0.05,side*deep/2),root,true)
				shapes.box(bell,Vector3(0,-0.15,0),Vector3(0.03,0.26,0.03),"4a3a2a")
				shapes.box(bell,Vector3(0,-0.36,0),Vector3(0.16,0.2,0.16),String(data.get("bell","b88a3a")))
				if ambience != null:
					ambience.sway(bell,end*1.7+side*0.9+parent.position.x,0.16)

## The height of a roof's surface over a point (gable, hip or shed), as the tiles follow it.
func _roof_top(px: float, pz: float, wide: float, deep: float, rise: float, form: String) -> float:
	var t: float = clampf(absf(pz)/(deep/2),0,1)
	if form=="hip":
		return minf(rise,minf(deep/2-absf(pz),wide/2-absf(px))/(deep/2)*rise)
	if form=="shed":
		return (pz/deep+0.5)*rise
	return (1-t)*rise

## A roof of rough stuff instead of fired tiles. Slate: courses of split stone slabs, each its own
## width, shade and tilt, laps staggered, moss (`moss`: colour, `mossy`: share) in the shaded laps,
## a slab slipped here and there, a few stones laid on to hold the rest. Thatch: thick bundles of
## straw in ragged courses (`straw` colours), darker where it has rotted, grass in it, a roll
## along the ridge and poles tied over it. `holes`: the share of the roof fallen in (屋顶隐约还可以
## 看到一些破洞), the rafters showing through.
func _rough_roof(root: Node3D, wide: float, deep: float, height: float, rise: float, form: String, curve: float, tint: Color, data: Dictionary, thatch: bool) -> void:
	var colors: Array = data.get("straw" if thatch else "slates",[])
	var moss: String = String(data.get("moss","5f7444"))
	var mossy: float = float(data.get("mossy",0.18))
	var course: float = 0.34 if thatch else 0.42
	var rows: int = ceili(deep/course)
	var offset := Vector2(rng.randf()*400.0,rng.randf()*400.0)
	var holes: float = float(data.get("holes",0.0))
	var timber: String = String(data.get("timber","79533d"))
	for z: int in rows:
		var pz: float = -deep/2+(z+0.5)*deep/rows
		var x: float = -wide/2-rng.randf_range(0.0,0.3)
		while x < wide/2:
			var piece: float = rng.randf_range(0.3,0.5) if thatch else rng.randf_range(0.42,0.82)
			var px: float = clampf(x+piece/2,-wide/2+0.05,wide/2-0.05)
			var span: float = minf(piece,wide/2-x)
			x += piece
			if span < 0.12:
				continue
			var top: float = _roof_top(px,pz,wide,deep,rise,form)
			if top < 0.0:
				continue
			var t: float = clampf(absf(pz)/(deep/2),0,1)
			var at := Vector3(px,height+0.12+top+pow(t,5)*curve*0.4,pz)
			var shade: float = noise.get_noise_2d(px*21+offset.x,pz*21+offset.y)
			var hex: String = String(colors[posmod(roundi((shade+0.5)*colors.size()*1.7)+z,colors.size())]) if not colors.is_empty() else tint.lightened((shade+0.5)*0.12).to_html(false)
			var tilt := Vector3(rng.randf_range(-0.06,0.06),rng.randf_range(-0.05,0.05),rng.randf_range(-0.05,0.05))
			if holes > 0.0 and z > 0 and z < rows-1 and noise.get_noise_2d(px*9+offset.y,pz*9+offset.x) > 0.62-holes:
				# A hole: a rafter across it, the dark of the room below.
				shapes.box(root,at-Vector3(0,0.14,0),Vector3(span,0.04,course),"1c1916")
				shapes.box(root,at-Vector3(0,0.06,0),Vector3(0.08,0.08,course+0.1),timber)
				continue
			if thatch:
				shapes.tilted_box(root,at+Vector3(0,0.06,0),Vector3(span+0.04,0.24,course+0.12),Color(hex).darkened(0.25 if shade < -0.3 else 0.0).to_html(false),tilt)
				if rng.randf() < 0.12:
					shapes.box(root,at+Vector3(rng.randf_range(-0.1,0.1),0.22,0),Vector3(0.12,0.12,0.1),moss)
				# The eaves' straw hangs ragged.
				if z==0 or z==rows-1:
					shapes.box(root,at+Vector3(0,-0.08,signf(pz)*(course/2+0.06)),Vector3(span*rng.randf_range(0.6,1.0),0.16,0.1),hex)
				continue
			if rng.randf() < 0.025:
				# A slipped slab: the dark lap under it shows, the slab askew below.
				shapes.box(root,at-Vector3(0,0.03,0),Vector3(span,0.05,course),Color(hex).darkened(0.45).to_html(false))
				shapes.tilted_box(root,at+Vector3(0.08,0.02,signf(pz)*0.12),Vector3(span*0.8,0.08,course*0.8),hex,tilt*3.0)
				continue
			shapes.tilted_box(root,at,Vector3(span+0.03,0.1,course+0.1),hex,tilt)
			if shade > 0.42-mossy or rng.randf() < mossy*0.3:
				shapes.box(root,at+Vector3(rng.randf_range(-span/4,span/4),0.055,-signf(pz)*course*0.25),Vector3(span*rng.randf_range(0.35,0.7),0.03,course*0.45),moss)
			if rng.randf() < 0.012:
				shapes.shard(root,at+Vector3(0,0.15,0),Vector3(0.24,0.18,0.22),"77786c",z,px)
	if form=="shed":
		return
	var ridge_length: float = wide if form=="gable" else maxf(0.4,wide-deep+0.5)
	if thatch:
		shapes.box(root,Vector3(0,height+rise+0.28,0),Vector3(ridge_length+0.1,0.34,0.62),String(colors[0]) if not colors.is_empty() else "a88f5c")
		for pole: float in [-0.32,0.32]:
			shapes.box(root,Vector3(0,height+rise+0.18-absf(pole)*0.35,pole),Vector3(ridge_length+0.3,0.06,0.06),"6e5a3e")
		return
	# Saddle stones along the ridge, each laid over the one before.
	var stone: float = -ridge_length/2
	while stone < ridge_length/2:
		var long: float = rng.randf_range(0.38,0.6)
		shapes.tilted_box(root,Vector3(stone+long/2,height+rise+0.2,0),Vector3(long,0.14,0.46),tint.darkened(rng.randf_range(0.05,0.16)).to_html(false),Vector3(0,rng.randf_range(-0.08,0.08),rng.randf_range(-0.04,0.04)))
		stone += long

## A flat roof walked on (a hall's 露台 over the floor below): stone slabs, a balustrade round
## its edge (`rail` colours: post, rail), stones set out on it (`rocks`: a count).
func _terrace(root: Node3D, wide: float, deep: float, height: float, data: Dictionary) -> void:
	var slab: String = String(data.get("terrace","d9d6cc"))
	var rail: Array = data.get("rail",["d9d6cc","e8e5dc"])
	shapes.box(root,Vector3(0,height+0.1,0),Vector3(wide,0.2,deep),slab)
	shapes.box(root,Vector3(0,height+0.21,0),Vector3(wide-0.3,0.02,deep-0.3),Color(slab).darkened(0.06).to_html(false))
	for side: int in 4:
		var along_x: bool = side<2
		var length: float = wide if along_x else deep
		var fixed: float = (deep if along_x else wide)/2*(1 if side%2 else -1)
		var posts: int = ceili(length/0.5)
		for post: int in posts+1:
			var along: float = -length/2+post*length/posts
			var at := Vector3(along,height+0.6,fixed) if along_x else Vector3(fixed,height+0.6,along)
			shapes.box(root,at,Vector3(0.12,0.8,0.12),String(rail[0]))
		shapes.box(root,(Vector3(0,height+1.0,fixed) if along_x else Vector3(fixed,height+1.0,0)),Vector3(length,0.08,0.12) if along_x else Vector3(0.12,0.08,length),String(rail[1]))
		shapes.box(root,(Vector3(0,height+0.5,fixed) if along_x else Vector3(fixed,height+0.5,0)),Vector3(length,0.3,0.05) if along_x else Vector3(0.05,0.3,length),String(rail[0]))
	var stones: Array = data.get("rock_colors",["7a877d","8b978c","6a766d"])
	var rocks: int = int(data.get("rocks",0))
	for i: int in rocks:
		var a: float = PI*(0.1+0.8*float(i)/maxf(1,rocks-1))
		var at := Vector3(cos(a)*wide*0.36,height+0.2,sin(a)*deep*0.32)
		for course: int in 3:
			shapes.shard(root,at+Vector3(sin(i+course)*0.08,0.3+course*0.4,0),Vector3(0.5-course*0.08,0.5,0.4),String(stones[(i+course)%stones.size()]),i*3+course)

## A pent roof of tiles all round the walls at `at` units up, a short wall-hung eave.
func _skirt(body: Node3D, w: float, d: float, at: float, data: Dictionary) -> void:
	var roof_color: String = String(data.get("roof","50626a"))
	var tint := Color(roof_color.get_slice(":",0))
	var glaze: String = "" if not roof_color.contains(":") else ":"+roof_color.get_slice(":",1)
	var timber: String = data.get("timber","79533d")
	var depth: float = float(data.get("skirt_depth",0.85))
	for side: int in 4:
		var along_x: bool = side<2
		var length: float = (w if along_x else d)+depth*2.0
		var fixed: float = (d if along_x else w)/2*(1 if side%2 else -1)
		var out := Vector3(0,0,signf(fixed)) if along_x else Vector3(signf(fixed),0,0)
		var face: Node3D = _node(out*absf(fixed),body)
		face.rotation.y = atan2(out.x,out.z)
		shapes.box(face,Vector3(0,at-0.08,0.06),Vector3(length,0.16,0.14),timber)
		for row: int in 3:
			var z: float = 0.15+row*depth/3.0
			var y: float = at+0.32-row*0.16
			for col: int in ceili(length/0.37):
				var x: float = -length/2+0.185+col*0.37
				# A corner's tiles stop at the neighbouring face: no overlap at the hips.
				if absf(x) > length/2-depth+z-0.2:
					continue
				var shade: int = clampi(roundi(noise.get_noise_2d((x+body.position.x+out.x*9)*27,(z+body.position.z)*27)*3)+2,0,4)
				shapes.box(face,Vector3(x,y,z),Vector3(0.38,0.12,depth/3.0+0.04),tint.lightened(shade*0.025).to_html(false)+glaze)
		shapes.box(face,Vector3(0,at-0.06,depth+0.04),Vector3(length,0.1,0.1),timber)

## 圆形拱门: the wall's gap closed again above and round a circle (`arch_rim` its stone ring),
## the circle's lower part open to walk through.
func _arch(body: Node3D, door: Vector3, w: float, d: float, data: Dictionary) -> void:
	var x_face: bool = absf(door.x)>w/2-1.7
	# In the wall's own plane (the passage stands just outside it).
	var front: Node3D = _node(Vector3(signf(door.x)*w/2,0,door.z) if x_face else Vector3(door.x,0,signf(door.z)*d/2),body)
	front.rotation.y = signf(door.x)*PI/2 if x_face else (0.0 if door.z>0 else PI)
	var plaster := Color(String(data.get("wall","c8b999")))
	var height: float = data.get("enclosure_height",data.get("height",3.4))
	var rim: String = String(data.get("arch_rim","cfcabd"))
	var r: float = 1.05
	var centre := Vector2(0,1.25)
	for y: int in ceili(height/0.25):
		for x: int in 9:
			var at := Vector2(-1.0+x*0.25,0.125+y*0.25)
			var gap: float = at.distance_to(centre)
			if gap < r+0.12 or absf(at.x) < 0.8 and at.y < centre.y:
				continue
			shapes.box(front,Vector3(at.x,at.y,0),Vector3(0.26,0.26,0.24),plaster.darkened(0.02*((x+y)%3)).to_html(false))
	for i: int in 26:
		var a: float = i*TAU/26.0
		var at: Vector2 = centre+Vector2(cos(a),sin(a))*(r+0.02)
		if at.y < centre.y and absf(at.x) < 0.95:
			continue
		shapes.box(front,Vector3(at.x,at.y,0),Vector3(0.24,0.24,0.32),rim)
	shapes.box(front,Vector3(0,0.03,0),Vector3(1.8,0.06,0.5),String(data.get("step","b7b091")))

func _entrance(body: Node3D, door: Vector3, w: float, d: float, data: Dictionary) -> void:
	var front: Node3D = _node(door,body)
	var x_face: bool = absf(door.x)>w/2-1.7
	front.rotation.y = signf(door.x)*PI/2 if x_face else (0.0 if door.z>0 else PI)
	var timber: String = data.get("timber","79533d")
	var posts: String = data.get("posts",timber)
	# `doorway_width` (units): the opening as wide as the 2D gate's (a 山门's 128 px).
	var half: float = float(data.get("doorway_width",2.3))/2.0
	for x: float in [-half+0.02,half-0.02]:
		shapes.box(front,Vector3(x,1.3,0),Vector3(0.2,2.6,0.27),posts)
		if data.get("lanterns",true):
			shapes.lantern(front,Vector3(x*1.23,2.15,0.25),false,String(data.get("lantern","ffb858")))
	shapes.box(front,Vector3(0,2.68,0),Vector3(half*2.0+0.25,0.25,0.38),timber)
	shapes.box(front,Vector3(0,0.025,0),Vector3(half*2.0-0.1,0.07,1.0),String(data.get("step","b7b091")))
	if data.has("gate"):
		_gate_leaves(front,data)
	if data.has("signboard"):
		_signboard(front,data["signboard"])
	if data.has("hanging_flag"):
		_hanging_flag(front,data["hanging_flag"])
	if data.get("doorway","")=="shut":
		# A door nobody goes through stays shut: planks, a bar across.
		shapes.box(front,Vector3(0,1.15,-0.05),Vector3(1.9,2.3,0.14),String(data.get("leaf","6b5038")))
		for plank: int in 5:
			shapes.box(front,Vector3(-0.76+plank*0.38,1.15,0.03),Vector3(0.05,2.2,0.04),"4f3c2c")
		shapes.box(front,Vector3(0,1.2,0.07),Vector3(2.1,0.14,0.08),"3f3226")
	elif data.get("doorway","")=="dark":
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
		if _trade_goods(front,pos,side,goods):
			continue
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

## The open leaves of a gateway, folded back against its posts: vermilion with rows of
## gilt studs (`gate`: "red"), black lacquer ("black"), or a colour of its own.
func _gate_leaves(front: Node3D, data: Dictionary) -> void:
	var leaf: String = {"red":"9c3a2c","black":"2d2a28"}.get(String(data["gate"]),String(data["gate"]))
	var half: float = float(data.get("doorway_width",2.3))/2.0
	var span: float = half-0.19
	for side: float in [-1.0,1.0]:
		var hinge: Node3D = _node(Vector3(side*(half-0.2),0,-0.1),front)
		hinge.rotation.y = side*1.25
		shapes.box(hinge,Vector3(-side*span/2,1.2,0),Vector3(span,2.36,0.1),leaf)
		for row: int in 5:
			for col: int in maxi(3,roundi(span/0.32)):
				shapes.box(hinge,Vector3(-side*(0.2+col*0.28),0.45+row*0.42,0.06),Vector3(0.07,0.07,0.04),"d6b25a")
		shapes.box(hinge,Vector3(-side*(span-0.16),1.2,0.07),Vector3(0.14,0.14,0.05),"b89548")
	shapes.box(front,Vector3(0,0.09,-0.05),Vector3(half*2.0-0.4,0.18,0.16),String(data.get("sill","5c4433")))

## 招牌/匾: a lacquered board over the doorway with the shop's name (`signboard`: {"text",
## "board", "letters" (a ":glow" colour reads as gilt), "frame", "width", "height", "y"}).
## `tilt` (degrees): it hangs askew from one cord; `worn`: weathered grey, split along the
## grain, a corner gone, the words half rubbed away (一片快要散掉似的木牌).
func _signboard(front: Node3D, sign_data: Variant) -> void:
	var info: Dictionary = sign_data if sign_data is Dictionary else {"text":String(sign_data)}
	var width: float = float(info.get("width",1.9))
	var y: float = float(info.get("y",3.12))
	var tall: float = float(info.get("height",0.62))
	var letters: String = String(info.get("letters","e6c66e"))
	var hung := Node3D.new()
	hung.position = Vector3(0,y,0)
	hung.rotation.z = deg_to_rad(float(info.get("tilt",0.0)))
	front.add_child(hung)
	if _body != null:
		shapes.merge(hung,_body)
	var worn: bool = info.get("worn",false)
	if not worn:
		shapes.box(hung,Vector3(0,0,0.24),Vector3(width+0.16,tall+0.14,0.08),String(info.get("frame","8a6a3e")))
		shapes.box(hung,Vector3(0,0,0.29),Vector3(width,tall,0.06),String(info.get("board","2b2520")))
	else:
		# Two boards with a gap between them, the lower one shorter: its end has broken off.
		var board: String = String(info.get("board","8a8170"))
		shapes.box(hung,Vector3(0,tall*0.26,0.28),Vector3(width,tall*0.46,0.06),board)
		shapes.box(hung,Vector3(-width*0.1,-tall*0.26,0.28),Vector3(width*0.8,tall*0.44,0.06),Color(board).darkened(0.12).to_html(false))
		shapes.box(hung,Vector3(width*0.18,tall*0.25,0.315),Vector3(width*0.34,0.03,0.02),Color(board).darkened(0.3).to_html(false))
		for cord: float in [-1.0,1.0]:
			if cord > 0.0 and absf(float(info.get("tilt",0.0))) > 0.0:
				continue
			shapes.box(hung,Vector3(cord*width*0.42,tall*0.5+0.18,0.27),Vector3(0.03,0.36,0.03),"5a4a36")
	var title := Label3D.new()
	title.text = TranslationServer.translate(String(info.get("text","")))
	title.position = Vector3(0,0,0.33)
	title.pixel_size = float(info.get("pixel_size",0.0075))
	title.font_size = 56
	title.outline_size = 0
	title.modulate = Color(letters.get_slice(":",0))
	if worn:
		title.modulate.a = 0.45
	hung.add_child(title)
	if letters.ends_with(":glow"):
		# Gilt that flashes in the light (金字招牌十分晃眼): a glowing rim round the words.
		for edge: float in [-1.0,1.0]:
			shapes.box(front,Vector3(0,y+edge*(tall/2-0.04),0.33),Vector3(width-0.1,0.035,0.02),letters)
		var shine := OmniLight3D.new()
		shine.position = Vector3(0,y,0.9)
		shine.light_color = Color(letters.get_slice(":",0))
		shine.omni_range = 2.2
		shine.set_meta("day_energy",0.35)
		shine.set_meta("night_energy",0.6)
		front.add_child(shine)

## 挑幌: a pennant hung from a pole out over the street beside the door (`hanging_flag`:
## {"text", "cloth", "trim", "letters", "side"}), stirring in the wind.
func _hanging_flag(front: Node3D, flag_data: Dictionary) -> void:
	var side: float = float(flag_data.get("side",1.0))
	var pole: Node3D = _node(Vector3(side*1.45,3.35,0.1),front)
	shapes.tilted_box(pole,Vector3(side*0.55,0.18,0.35),Vector3(0.08,0.08,1.6),"5b4433",Vector3(0.22,side*0.6,0))
	var cloth: Node3D = _node(Vector3(side*0.95,0.1,0.75),pole,true)
	shapes.box(cloth,Vector3(0,-0.75,0),Vector3(0.62,1.5,0.04),String(flag_data.get("cloth","b8412f")))
	shapes.box(cloth,Vector3(0,-0.02,0),Vector3(0.7,0.1,0.06),String(flag_data.get("trim","2f2a24")))
	for tail: int in 3:
		shapes.box(cloth,Vector3(-0.2+tail*0.2,-1.58,0),Vector3(0.12,0.2,0.04),String(flag_data.get("trim","2f2a24")))
	if flag_data.has("text"):
		var title := Label3D.new()
		title.text = TranslationServer.translate(String(flag_data["text"]))
		title.position = Vector3(0,-0.72,0.03)
		title.pixel_size = 0.009
		title.font_size = 60
		title.width = 60.0
		title.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		title.outline_size = 0
		title.modulate = Color(String(flag_data.get("letters","f1e3bd")))
		cloth.add_child(title)
	if ambience != null:
		ambience.flutter(cloth,side*1.7+front.position.x)

## What a shop sets out either side of its door, by trade (`goods`); false for the older kinds.
func _trade_goods(front: Node3D, pos: Vector3, side: float, goods: String) -> bool:
	match goods:
		"cloth":
			# Bolts of cloth stood in a rack, the bright ones outermost.
			shapes.box(front,pos+Vector3(0,0.06,0),Vector3(0.8,0.12,0.55),"6a5039")
			for bolt: int in 5:
				shapes.tilted_box(front,pos+Vector3(-0.3+bolt*0.15,0.5,0),Vector3(0.13,0.8,0.13),["4a6f8f","b4473a","d6b862","5d8160","a77ba0"][(bolt+int(side>0)*2)%5],Vector3(0,0,0.18))
		"herbs":
			# Flat trays of drying roots and leaves on a low trestle.
			shapes.box(front,pos+Vector3(0,0.35,0),Vector3(0.85,0.06,0.6),"8f7650")
			for leg: float in [-0.35,0.35]:
				shapes.box(front,pos+Vector3(leg,0.17,0),Vector3(0.06,0.34,0.5),"6c5439")
			for tray: int in 2:
				shapes.box(front,pos+Vector3(-0.2+tray*0.4,0.41,0),Vector3(0.36,0.05,0.5),["a3955c","7d8a52"][tray])
				shapes.box(front,pos+Vector3(-0.2+tray*0.4,0.45,0.06),Vector3(0.2,0.03,0.22),["8a5a3a","b4a26a"][tray])
		"coffins":
			# Coffin boards leaning against the wall, and a finished lid on trestles.
			for board: int in 3:
				shapes.tilted_box(front,pos+Vector3(-0.25+board*0.22,0.75,-0.25),Vector3(0.2,1.5,0.08),["5a3b2c","4a3226","6b4a34"][board],Vector3(-0.22,0,0))
			shapes.box(front,pos+Vector3(0,0.12,0.15),Vector3(0.7,0.24,0.4),"2f2621")
		"weapons":
			shapes.box(front,pos+Vector3(0,0.05,0),Vector3(0.75,0.1,0.4),"5b4433")
			for i: int in 4:
				shapes.box(front,pos+Vector3(-0.27+i*0.18,0.75,0),Vector3(0.05,1.4,0.05),"7a5a3e")
				shapes.box(front,pos+Vector3(-0.27+i*0.18,1.48,0),Vector3(0.09,0.2,0.04),"b9c2bf")
			shapes.box(front,pos+Vector3(0,0.9,-0.08),Vector3(0.8,0.06,0.06),"5b4433")
		"books":
			shapes.box(front,pos+Vector3(0,0.3,0),Vector3(0.8,0.6,0.45),"6a4f37")
			for stack: int in 3:
				for book: int in 2+stack%2:
					shapes.box(front,pos+Vector3(-0.25+stack*0.25,0.65+book*0.07,0),Vector3(0.2,0.06,0.28),["c9b98e","4e6967","ad8055"][(stack+book)%3])
		"baskets":
			for basket: int in 3:
				var at: Vector3 = pos+Vector3(-0.25+basket*0.25,0,(basket%2)*0.2)
				shapes.box(front,at+Vector3(0,0.2,0),Vector3(0.3,0.36,0.3),["a68a55","b89a5e","947a4a"][basket])
				shapes.box(front,at+Vector3(0,0.4,0),Vector3(0.24,0.06,0.24),["c94b37","e2c25c","6f9a4e"][basket])
		"jars":
			for jar: int in 3:
				var at: Vector3 = pos+Vector3(-0.25+jar*0.26,0,(jar%2)*0.12)
				shapes.box(front,at+Vector3(0,0.25,0),Vector3(0.32,0.46,0.32),["6b4a35","7b5a3e","5b3f2f"][jar])
				shapes.box(front,at+Vector3(0,0.52,0),Vector3(0.2,0.08,0.2),"b23a2b")
		"tea":
			# Tea in deep baskets and a sealed jar by a tea house door.
			for basket: int in 2:
				shapes.box(front,pos+Vector3(-0.2+basket*0.4,0.3,0),Vector3(0.36,0.6,0.36),"a98d58")
				shapes.box(front,pos+Vector3(-0.2+basket*0.4,0.62,0),Vector3(0.3,0.06,0.3),"55703c")
			shapes.box(front,pos+Vector3(0,0.2,0.32),Vector3(0.26,0.36,0.26),"5d7f78")
		"wedding":
			# 红娘庄: red silk knotted on the posts over potted flowers.
			shapes.box(front,pos+Vector3(-side*0.7,2.3,0.0),Vector3(0.3,0.5,0.16),"c0392b")
			shapes.box(front,pos+Vector3(-side*0.7,2.0,0.05),Vector3(0.08,0.4,0.04),"c0392b")
			shapes.pot(front,pos)
		"dice":
			# Gamblers' stools left outside, a bowl of dice on one.
			shapes.box(front,pos+Vector3(0,0.25,0),Vector3(0.5,0.08,0.5),"6b4e36")
			for leg: Vector2 in [Vector2(-0.18,-0.18),Vector2(0.18,-0.18),Vector2(-0.18,0.18),Vector2(0.18,0.18)]:
				shapes.box(front,pos+Vector3(leg.x,0.11,leg.y),Vector3(0.06,0.22,0.06),"4f3a29")
			shapes.box(front,pos+Vector3(0,0.35,0),Vector3(0.24,0.12,0.24),"2a2622")
			shapes.box(front,pos+Vector3(0.06,0.43,0.02),Vector3(0.05,0.05,0.05),"efe8d6")
		"escort":
			# A 镖局's ironbound chest and a spear stood by the door.
			shapes.box(front,pos+Vector3(0,0.28,0.1),Vector3(0.7,0.5,0.45),"5d4632")
			for band: float in [-0.22,0.22]:
				shapes.box(front,pos+Vector3(band,0.28,0.1),Vector3(0.05,0.52,0.47),"3d3d3a")
			shapes.tilted_box(front,pos+Vector3(side*0.3,1.1,-0.2),Vector3(0.05,2.2,0.05),"6a4c33",Vector3(0,0,side*0.08))
			shapes.box(front,pos+Vector3(side*0.38,2.2,-0.2),Vector3(0.08,0.24,0.04),"bfc6c2")
			shapes.box(front,pos+Vector3(side*0.38,2.05,-0.2),Vector3(0.12,0.12,0.04),"b8412f")
		"alms":
			# 斋院: a great pot of gruel on its stand, bowls stacked by it.
			shapes.box(front,pos+Vector3(0,0.2,0),Vector3(0.6,0.4,0.6),"5e5a52")
			shapes.box(front,pos+Vector3(0,0.5,0),Vector3(0.72,0.24,0.72),"3a3632")
			shapes.box(front,pos+Vector3(0,0.63,0),Vector3(0.6,0.02,0.6),"d9cfb4")
			for bowl: int in 3:
				shapes.box(front,pos+Vector3(-side*0.5,0.06+bowl*0.07,0.2),Vector3(0.2,0.06,0.2),"d8d2c2")
		_:
			return false
	return true
