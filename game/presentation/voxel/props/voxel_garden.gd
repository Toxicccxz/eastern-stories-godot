extends RefCounted

## Gardens, yards and temple grounds (美术规划 group D): a pavilion (whole, or leaning and
## falling in), a rockery of holed stones, lotus on a pond, a swing frame, thorny brambles, a
## stone table with drum stools and a round gateway in a garden wall; white stone balustrades
## (with a rail seat), stair flights, a pavilion's posts and its glazed roof held up over open
## ground, steles, a bronze censer, stone lanterns, camellia beds, single strange stones,
## columns and the carved gateways of a hall. Sizes and colours from the data.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var s: Shapes
var root: Node3D
var rng: RandomNumberGenerator
var ambience: VoxelAmbience
var data: Dictionary

func draw(shapes: Shapes, parent: Node3D, look: Dictionary, w: float, d: float) -> bool:
	s = shapes
	root = parent
	data = look
	match String(look["kind"]):
		"pavilion": _pavilion(w,d)
		"rockery": _rockery(w,d)
		"lotus": _lotus(w,d)
		"swing_frame": _swing_frame(w,d)
		"thorns": _thorns(w,d)
		"stone_table": _stone_table(w)
		"moon_gate": _moon_gate(w)
		"screen_wall": _screen_wall(w,d)
		"balustrade": _balustrade(w,d)
		"stair_flight": _stair_flight(w,d)
		"pavilion_post": _post(float(data.get("height",2.7)),String(data.get("column","9c3a2c")),true)
		"column": _post(float(data.get("height",3.1)),String(data.get("column","7a4a32")),false)
		"pavilion_roof": _pavilion_roof(w,d)
		"stele": _stele(w,d)
		"censer": _censer(w)
		"stone_lantern": _stone_lantern()
		"camellia_bed": _camellia_bed(w,d)
		"strange_stone": _strange_stone(w,d)
		"gate_frame": _gate_frame(w,d)
		_:
			return false
	return true

func _colors(key: String, fallback: Array) -> Array:
	return data.get(key,fallback)

func _pick(colors: Array) -> String:
	return String(colors[rng.randi_range(0,colors.size()-1)])

## 亭: posts on a stone plinth under a hipped roof with lifted corners, benches between the
## posts. `ruined`: the roof sags and has lost tiles, a post has gone, weeds on the plinth
## (场院's 亭子似乎也快要倒塌了).
func _pavilion(w: float, d: float) -> void:
	var ruined: bool = data.get("ruined",false)
	var posts: String = String(data.get("posts","9c3a2c"))
	var timber: String = String(data.get("timber","5f4331"))
	var height: float = float(data.get("height",2.6))
	s.box(root,Vector3(0,0.15,0),Vector3(w,0.3,d),String(data.get("plinth","9a998c")))
	s.box(root,Vector3(0,0.31,0),Vector3(w-0.2,0.03,d-0.2),"aaa99a")
	var corners: Array[Vector2] = [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]
	var frame := Node3D.new()
	root.add_child(frame)
	if ruined:
		frame.rotation = Vector3(0.07,0,-0.1)
	for i: int in corners.size():
		var c: Vector2 = corners[i]
		var at := Vector3(c.x*(w/2-0.3),0.3,c.y*(d/2-0.3))
		if ruined and i==1:
			# The fallen post lies across the plinth.
			s.tilted_box(root,at+Vector3(-0.6,0.1,0.2),Vector3(0.22,0.22,height),posts,Vector3(PI/2,0.5,0))
			continue
		s.box(frame,at+Vector3(0,height/2,0),Vector3(0.22,height,0.22),posts)
	for side: int in 4:
		if side==2:
			continue
		var c0: Vector2 = corners[side]
		var c1: Vector2 = corners[(side+1)%4]
		var mid := Vector3((c0.x+c1.x)*0.5*(w/2-0.3),0.75,(c0.y+c1.y)*0.5*(d/2-0.3))
		var along_x: bool = c0.y==c1.y
		s.box(frame,mid,Vector3(w-0.7,0.08,0.3) if along_x else Vector3(0.3,0.08,d-0.7),timber)
	var tint := Color(String(data.get("roof","3f4a52")))
	var top: float = 0.3+height
	s.box(frame,Vector3(0,top,0),Vector3(w-0.3,0.18,d-0.3),timber)
	var rows: int = ceili((d+0.8)/0.37)
	var cols: int = ceili((w+0.8)/0.37)
	for z: int in rows:
		for x: int in cols:
			var px: float = -(w+0.8)/2+0.185+x*0.37
			var pz: float = -(d+0.8)/2+0.185+z*0.37
			var inset: float = minf((w+0.8)/2-absf(px),(d+0.8)/2-absf(pz))
			if ruined and rng.randf()<0.22:
				continue
			var corner: float = pow(1.0-clampf(inset/0.9,0.0,1.0),3)*0.35
			var rise: float = minf(1.2,inset*0.75)
			s.box(frame,Vector3(px,top+0.15+rise+corner,pz),Vector3(0.38,0.12,0.38),tint.lightened(((x+z)%3)*0.03).to_html(false))
	s.box(frame,Vector3(0,top+1.45,0),Vector3(0.3,0.4,0.3),String(data.get("finial","b89548")))
	if ruined:
		for weed: int in 8:
			var at := Vector3(rng.randf_range(-0.45,0.45)*w,0.32,rng.randf_range(-0.45,0.45)*d)
			s.box(root,at+Vector3(0,0.12,0),Vector3(0.14,0.24,0.14),_pick(["6f7a40","7f8a4a","5d6a3a"]))
		for tile: int in 6:
			s.tilted_box(root,Vector3(rng.randf_range(-0.5,0.5)*w,0.34,rng.randf_range(-0.5,0.5)*d),Vector3(0.36,0.06,0.3),tint.darkened(0.1).to_html(false),Vector3(rng.randf()*0.4,rng.randf()*TAU,0))

## 假山: a pile of pale holed lake stones, tall and lean, moss in its hollows.
func _rockery(w: float, d: float) -> void:
	var stone: Array = _colors("colors",["a8a89c","b6b5a8","9a9a8e","c2c0b2"])
	var height: float = float(data.get("height",2.2))
	var count: int = int(data.get("count",7))
	for i: int in count:
		var t: float = float(i)/count
		var at := Vector3(rng.randf_range(-0.32,0.32)*w*(1.0-t*0.6),t*height*0.85,rng.randf_range(-0.32,0.32)*d*(1.0-t*0.6))
		var size: float = rng.randf_range(0.5,0.9)*(1.15-t*0.5)
		s.shard(root,at+Vector3(0,size*0.4,0),Vector3(size*rng.randf_range(0.7,1.1),size*rng.randf_range(0.9,1.5),size*rng.randf_range(0.6,1.0)),_pick(stone),i*3,rng.randf()*TAU)
		if i%2==0:
			# The holes that make a lake stone: dark pockets on its face.
			s.box(root,at+Vector3(size*0.3,size*0.5,size*0.25),Vector3(0.14,0.16,0.08),"5f5f58")
		if rng.randf()<0.5:
			s.box(root,at+Vector3(0,size*0.95,0),Vector3(size*0.4,0.05,size*0.35),_pick(["5d7a45","6c8a4c"]))
	if data.get("pine",false):
		var trunk := Vector3(w*0.2,height*0.7,0)
		s.tilted_box(root,trunk,Vector3(0.12,0.9,0.12),"5b4636",Vector3(0,0,0.5))
		s.box(root,trunk+Vector3(0.4,0.45,0),Vector3(0.9,0.22,0.6),"2f5233")

## Lotus pads on the water, a few flowers standing out of them (on water cells).
func _lotus(w: float, d: float) -> void:
	var pads: Array = _colors("colors",["4f7a3c","5f8a46","6e9a4f"])
	var count: int = int(data.get("count",10))
	var level: float = float(data.get("level",-0.14))
	for i: int in count:
		var at := Vector3(rng.randf_range(-0.45,0.45)*w,level+0.02,rng.randf_range(-0.45,0.45)*d)
		var r: float = rng.randf_range(0.18,0.32)
		s.box(root,at,Vector3(r*2,0.02,r*2),_pick(pads))
		s.box(root,at+Vector3(r*0.5,0.012,0),Vector3(r*0.9,0.01,0.03),"3f5f32")
		if i%3==0:
			s.box(root,at+Vector3(0,0.25,0),Vector3(0.03,0.5,0.03),"4f7a3c")
			s.box(root,at+Vector3(0,0.55,0),Vector3(0.18,0.14,0.18),String(data.get("flower","e8a4b4")))
			s.box(root,at+Vector3(0,0.63,0),Vector3(0.1,0.06,0.1),"f4d0d8")

## 秋千架: two posts and a beam, the seat hanging by its ropes, or by one (`broken`) with
## the other trailing, grass grown up round its feet.
func _swing_frame(w: float, d: float) -> void:
	var wood: String = String(data.get("wood","6a5038"))
	var height: float = float(data.get("height",2.6))
	var broken: bool = data.get("broken",false)
	for x: float in [-w/2+0.12,w/2-0.12]:
		for z: float in [-0.25,0.25]:
			s.tilted_box(root,Vector3(x,height/2,z*0.5),Vector3(0.14,height,0.14),wood,Vector3(z*0.4,0,0))
	var beam := Node3D.new()
	root.add_child(beam)
	if broken:
		beam.rotation.z = 0.06
	s.box(beam,Vector3(0,height,0),Vector3(w,0.14,0.16),wood)
	var swing := Node3D.new()
	swing.position = Vector3(0,height,0)
	root.add_child(swing)
	var drop: float = height-0.6
	# The seat hangs inside the swaying node, so a broken one keeps its twist as it swings.
	var seat := Node3D.new()
	swing.add_child(seat)
	s.box(seat,Vector3(-0.35,-drop/2,0),Vector3(0.03,drop,0.03),"b09a6c")
	if broken:
		seat.rotation = Vector3(0.3,0,0.35)
		s.box(seat,Vector3(0.05,-drop*0.45,0.1),Vector3(0.03,drop*0.6,0.03),"b09a6c")
	else:
		s.box(seat,Vector3(0.35,-drop/2,0),Vector3(0.03,drop,0.03),"b09a6c")
	s.box(seat,Vector3(0,-drop,0),Vector3(0.85,0.06,0.3),"8a6a45")
	if ambience != null:
		ambience.sway(swing,root.position.x,0.05 if broken else 0.08)

## 荆棘: low tangled brambles, thorns and a few red hips (the ground they hold is blocked).
func _thorns(w: float, d: float) -> void:
	var stems: Array = _colors("colors",["4f4a2f","5d5636","6b6239","3f4a2c"])
	var count: int = maxi(4,floori(w*d*3.0))
	for i: int in count:
		var at := Vector3(rng.randf_range(-0.46,0.46)*w,0,rng.randf_range(-0.46,0.46)*d)
		var h: float = rng.randf_range(0.4,float(data.get("height",1.0)))
		s.tilted_box(root,at+Vector3(0,h/2,0),Vector3(0.05,h,0.05),_pick(stems),Vector3(rng.randf_range(-0.6,0.6),rng.randf()*TAU,rng.randf_range(-0.6,0.6)))
		s.shard(root,at+Vector3(0,h*0.4,0),Vector3(0.3,h*0.5,0.3),_pick(["4c5a33","5a6a3a","66733f"]),i)
		if i%4==0:
			s.box(root,at+Vector3(0.1,h*0.7,0.05),Vector3(0.06,0.06,0.06),"b8432f")

## 石桌石凳: a round stone table on a drum, four drum stools round it.
func _stone_table(w: float) -> void:
	var stone: Array = _colors("colors",["9a998c","a8a79a","8a8a7e"])
	s.box(root,Vector3(0,0.35,0),Vector3(0.4,0.7,0.4),String(stone[2]))
	for i: int in 6:
		var a: float = i*PI/6.0
		s.box(root,Vector3(0,0.74,0),Vector3(w*0.5*absf(cos(a))+w*0.18,0.1,w*0.5*absf(sin(a))+w*0.18),String(stone[0]))
	for i: int in 4:
		var a: float = i*TAU/4.0+PI/4
		s.box(root,Vector3(cos(a)*w*0.42,0.22,sin(a)*w*0.42),Vector3(0.32,0.44,0.32),String(stone[1]))
	if data.get("chess",false):
		s.box(root,Vector3(0,0.8,0),Vector3(0.5,0.015,0.5),"c9b98e")
		for i: int in 5:
			s.box(root,Vector3(rng.randf_range(-0.2,0.2),0.82,rng.randf_range(-0.2,0.2)),Vector3(0.05,0.03,0.05),["2a2622","efe8d6"][i%2])

## 月洞门: a round gateway set in a garden wall, its rim of grey brick; the opening itself is
## the 2D doorway (`w` its width), so this stands on the wall's line either side and above.
func _moon_gate(w: float) -> void:
	var rim: Array = _colors("colors",["8a8d82","969888","7c7f76"])
	var r: float = w*0.5+0.35
	var centre := Vector3(0,r*0.95,0)
	for i: int in 24:
		var a: float = i*TAU/24.0
		var at: Vector3 = centre+Vector3(cos(a)*r,sin(a)*r,0)
		# The lower rim stays out of the opening the 2D doorway leaves.
		if at.y < 0.1 or absf(at.x) < w*0.5+0.12 and at.y < centre.y:
			continue
		s.box(root,at,Vector3(0.32,0.32,0.4),String(rim[i%rim.size()]))
	s.box(root,Vector3(0,centre.y+r+0.3,0),Vector3(w+1.6,0.2,0.5),String(data.get("cap","4a5560")))

## 影壁: a free-standing screen wall just inside a gate, tiled on top, a carved panel (`text`)
## in its middle, so no one sees straight in from the street.
func _screen_wall(w: float, d: float) -> void:
	var plaster: String = String(data.get("wall","d8d4c6"))
	var height: float = float(data.get("height",2.4))
	var along_x: bool = w>=d
	var length: float = maxf(w,d)
	s.box(root,Vector3(0,0.2,0),Vector3(length+0.1,0.4,0.6) if along_x else Vector3(0.6,0.4,length+0.1),"8a8a7e")
	s.box(root,Vector3(0,height/2,0),Vector3(length,height,0.4) if along_x else Vector3(0.4,height,length),plaster)
	var tint := Color(String(data.get("roof","343e46")))
	for i: int in ceili((length+0.4)/0.37):
		var t: float = -(length+0.4)/2+0.185+i*0.37
		for side: float in [-1.0,1.0]:
			s.box(root,Vector3(t,height+0.1,side*0.18) if along_x else Vector3(side*0.18,height+0.1,t),Vector3(0.38,0.12,0.4) if along_x else Vector3(0.4,0.12,0.38),tint.lightened((i%3)*0.03).to_html(false))
	s.box(root,Vector3(0,height+0.26,0),Vector3(length+0.5,0.16,0.2) if along_x else Vector3(0.2,0.16,length+0.5),tint.darkened(0.1).to_html(false))
	var panel := Vector3(0,height*0.55,0.21) if along_x else Vector3(0.21,height*0.55,0)
	s.box(root,panel,Vector3(minf(length*0.45,1.4),minf(height*0.5,1.2),0.04) if along_x else Vector3(0.04,minf(height*0.5,1.2),minf(length*0.45,1.4)),String(data.get("panel","8a8d82")))
	if data.has("text"):
		var title := Label3D.new()
		title.text = TranslationServer.translate(String(data["text"]))
		title.position = panel+(Vector3(0,0,0.03) if along_x else Vector3(0.03,0,0))
		if not along_x:
			title.rotation.y = PI/2
		title.pixel_size = 0.012
		title.font_size = 64
		title.outline_size = 0
		title.modulate = Color(String(data.get("letters","9b2f25")))
		root.add_child(title)

## A size laid along the box's long axis (x when `along_x`), else turned onto z.
func _along(along_x: bool, length: float, height: float, depth: float) -> Vector3:
	return Vector3(length,height,depth) if along_x else Vector3(depth,height,length)

## A child of the prop's root turned by `turn`, batched with it when the root is.
func _frame(turn: float) -> Node3D:
	var frame := Node3D.new()
	frame.rotation.y = turn
	root.add_child(frame)
	if s.merged.has(root):
		s.merge(frame,s.merged[root])
	return frame

## 白石栏杆: a stone kerb, posts with bud caps every half unit, a top rail and carved panels
## between, along the box's long side (a 16 px box at a way's edge). `jade`: the purest white
## (白玉); `wooden`: red lacquered wood; `seat`: a plank along it at sitting height (美人靠).
func _balustrade(w: float, d: float) -> void:
	var along_x: bool = w>=d
	var length: float = maxf(w,d)
	var depth: float = minf(w,d)
	var wooden: bool = data.get("wooden",false)
	var fallback: Array = ["d9d6cc","e8e5dc","c4c0b4"]
	if data.get("jade",false):
		fallback = ["e8ebe6","f5f6f1","d2d8d2"]
	elif wooden:
		fallback = ["8e3a2c","a8483a","6b2e24"]
	var colors: Array = _colors("colors",fallback)
	var height: float = float(data.get("height",0.85))
	s.box(root,Vector3(0,0.06,0),_along(along_x,length,0.12,depth*0.9),String(data.get("kerb","5c3f2b" if wooden else "b4b0a3")))
	var count: int = maxi(1,roundi(length/0.5))
	for i: int in count+1:
		var t: float = -length/2+i*length/count
		var at: Vector3 = Vector3(t,0,0) if along_x else Vector3(0,0,t)
		s.box(root,at+Vector3(0,height/2+0.06,0),Vector3(0.13,height,0.13),String(colors[0]))
		s.box(root,at+Vector3(0,height+0.14,0),Vector3(0.1,0.11,0.1),String(colors[1]))
		if i<count:
			var mid: Vector3 = at+(Vector3(length/count/2,0,0) if along_x else Vector3(0,0,length/count/2))
			s.box(root,mid+Vector3(0,height*0.45+0.06,0),_along(along_x,length/count-0.17,height*0.5,0.06),String(colors[2]))
			s.box(root,mid+Vector3(0,height*0.45+0.06,0),_along(along_x,0.1,0.1,0.08),String(colors[1]))
	s.box(root,Vector3(0,height+0.05,0),_along(along_x,length,0.08,0.12),String(colors[1]))
	s.box(root,Vector3(0,0.18,0),_along(along_x,length,0.06,0.09),String(colors[1]))
	if data.get("seat",false):
		s.box(root,Vector3(0,0.44,0),_along(along_x,length,0.07,depth*0.95),String(data.get("seat_color",colors[1])))

## 白石阶: the treads of a stone stair drawn flat over the way (a stair is a 2D path; its rise is
## not shown): a nosing every `step` units across the climb (up is local -z), the riser's shade
## behind it, the middle worn paler where feet go.
func _stair_flight(w: float, d: float) -> void:
	var colors: Array = _colors("colors",["e2ded3","c9c4b6","f2efe8"])
	var count: int = maxi(1,floori(d/float(data.get("step",0.5))))
	for i: int in count:
		var z: float = d/2-(i+0.5)*d/count
		s.box(root,Vector3(0,0.055,z+d/count*0.3),Vector3(w,0.02,d/count*0.32),String(colors[1]))
		s.box(root,Vector3(0,0.07,z+d/count*0.46),Vector3(w,0.03,0.05),String(colors[2]))
	s.box(root,Vector3(0,0.05,0),Vector3(w*0.36,0.012,d),String(data.get("worn",colors[0])))

## A column on its stone drum: a pavilion's (`outdoor`: a white drum, a bracket on top) or a
## hall's (`column` its lacquer, `band` the gilt ring near its head).
func _post(height: float, column: String, outdoor: bool) -> void:
	var stone: String = String(data.get("base","d6d2c6" if outdoor else "a8a497"))
	s.box(root,Vector3(0,0.12,0),Vector3(0.56,0.24,0.56),stone)
	s.box(root,Vector3(0,0.3,0),Vector3(0.44,0.14,0.44),stone)
	s.box(root,Vector3(0,0.37+height/2,0),Vector3(0.3,height,0.3),column)
	s.box(root,Vector3(0,0.37+height*0.84,0),Vector3(0.33,0.06,0.33),String(data.get("band","c9a24a")))
	if outdoor:
		s.box(root,Vector3(0,0.37+height+0.08,0),Vector3(0.5,0.16,0.5),String(data.get("bracket","6e2a20")))

## A pavilion's roof held up over open ground (its posts are blocked boxes of the layout, the
## roof raised by `elevation` onto them): beams and a painted frieze round the eaves, glazed
## tiles rising to a gilt finial (a point over a square plan, a ridge over a long one), the
## corners swept up, a second eave below (`double`, 重檐), wind bells at the corners that stir.
func _pavilion_roof(w: float, d: float) -> void:
	var tint: String = String(data.get("roof","3c8a8a:gloss"))
	var timber: String = String(data.get("timber","8e3a2c"))
	var frieze: String = String(data.get("frieze","2f6a70"))
	for side: float in [-1.0,1.0]:
		s.box(root,Vector3(0,-0.04,side*d/2),Vector3(w+0.2,0.22,0.16),timber)
		s.box(root,Vector3(side*w/2,-0.04,0),Vector3(0.16,0.22,d+0.2),timber)
		s.box(root,Vector3(0,-0.24,side*d/2),Vector3(w,0.16,0.12),frieze)
		s.box(root,Vector3(side*w/2,-0.24,0),Vector3(0.12,0.16,d),frieze)
		for dot: int in maxi(1,floori(w/0.6)):
			s.box(root,Vector3(-w/2+0.3+dot*0.6,-0.24,side*(d/2+0.065)),Vector3(0.1,0.06,0.02),"c9a24a")
	var rise: float = float(data.get("rise",1.7))
	var span := Vector2(w+float(data.get("overhang",0.9)),d+float(data.get("overhang",0.9)))
	if data.get("double",false):
		_tiles(Vector3(0,-0.7,0),span+Vector2(0.9,0.9),0.3,tint,0.75)
	_tiles(Vector3.ZERO,span,rise,tint)
	var finial: String = String(data.get("finial","c9a24a"))
	var apex: float = 0.2+rise
	if absf(span.x-span.y) > 0.3:
		# A ridge along the longer side, its ends raised.
		var length: float = absf(span.x-span.y)+0.4
		var along_x: bool = span.x>span.y
		s.box(root,Vector3(0,apex+0.12,0),_along(along_x,length,0.22,0.26),Color(tint.get_slice(":",0)).darkened(0.15).to_html(false))
		for end: float in [-1.0,1.0]:
			s.box(root,(Vector3(end*length/2,apex+0.3,0) if along_x else Vector3(0,apex+0.3,end*length/2)),Vector3(0.24,0.36,0.24),finial)
	else:
		for tier: int in 3:
			s.box(root,Vector3(0,apex+0.12+tier*0.2,0),Vector3(0.34-tier*0.08,0.2,0.34-tier*0.08),finial)
	if data.get("bells",true):
		for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			var bell := Node3D.new()
			# Hung from the swept-up corner itself.
			bell.position = Vector3(corner.x*span.x/2,0.82,corner.y*span.y/2)
			root.add_child(bell)
			s.box(bell,Vector3(0,-0.18,0),Vector3(0.03,0.3,0.03),"4a3a2a")
			s.box(bell,Vector3(0,-0.4,0),Vector3(0.14,0.18,0.14),String(data.get("bell","b88a3a")))
			if ambience != null:
				ambience.sway(bell,corner.x*1.3+corner.y*0.7,0.14)

## Glazed tiles over a plan (`span`, units) rising `rise` to its middle, the eaves' corners swept
## up; with `ring`, only the outer band that wide (a lower eave). The colour's ":gloss" stays.
func _tiles(at: Vector3, span: Vector2, rise: float, tint: String, ring: float = 0.0) -> void:
	var base := Color(tint.get_slice(":",0))
	var suffix: String = "" if not tint.contains(":") else ":"+tint.get_slice(":",1)
	var cols: int = ceili(span.x/0.37)
	var rows: int = ceili(span.y/0.37)
	var half: float = minf(span.x,span.y)/2
	for z: int in rows:
		for x: int in cols:
			var px: float = -span.x/2+(x+0.5)*span.x/cols
			var pz: float = -span.y/2+(z+0.5)*span.y/rows
			var edge_x: float = span.x/2-absf(px)
			var edge_z: float = span.y/2-absf(pz)
			var inset: float = minf(edge_x,edge_z)
			if ring > 0.0 and inset > ring:
				continue
			var top: float = minf(1.0,inset/half)*rise
			var corner: float = pow(1.0-clampf(maxf(edge_x,edge_z)/1.3,0.0,1.0),2)*0.55
			var lift: float = pow(1.0-clampf(inset/0.6,0.0,1.0),3)*0.12
			var shade: String = base.lightened(((x+z)%3)*0.035).to_html(false)+suffix
			s.box(root,at+Vector3(px,0.15+top+corner+lift,pz),Vector3(span.x/cols+0.02,0.12,span.y/rows+0.02),shade)
	# The hips: darker ridges from each corner up toward the middle.
	if ring == 0.0:
		for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			for step: int in ceili(half/0.3):
				var t: float = step*0.3/half
				var px: float = corner.x*(span.x/2-t*half)
				var pz: float = corner.y*(span.y/2-t*half)
				var swept: float = pow(1.0-clampf(t*half/1.3,0.0,1.0),2)*0.55
				s.box(root,at+Vector3(px,0.25+t*rise+swept,pz),Vector3(0.18,0.12,0.18),base.darkened(0.18).to_html(false)+suffix)

## 石碑: an inscribed slab on its plinth, or borne on a stone tortoise (`turtle`, 赑屃), its top
## carved round (螭首), the incised columns of its text on both faces; `height` units tall.
func _stele(w: float, d: float) -> void:
	var colors: Array = _colors("colors",["8a8c84","9a9c93","74766f"])
	var height: float = float(data.get("height",2.4))
	var along_x: bool = w>=d
	var frame: Node3D = _frame(0.0 if along_x else PI/2)
	var width: float = maxf(w,d)*0.82
	var deep: float = minf(w,d)
	var thick: float = clampf(deep*0.45,0.22,0.5)
	var base: float = 0.35
	if data.get("turtle",false):
		# A long-necked tortoise, its shell in plates, four stubby feet, the slab on its back.
		base = 0.62
		s.box(frame,Vector3(0,0.26,0),Vector3(width*0.95,0.46,deep*0.95),String(colors[2]))
		s.box(frame,Vector3(0,0.52,0),Vector3(width*0.78,0.14,deep*0.78),String(colors[0]))
		for plate: int in 6:
			s.box(frame,Vector3(-width*0.3+(plate%3)*width*0.3,0.6,(plate/3-0.5)*deep*0.4),Vector3(width*0.2,0.03,deep*0.3),String(colors[1]))
		s.box(frame,Vector3(0,0.32,deep/2+0.12),Vector3(0.34,0.3,0.4),String(colors[2]))
		s.box(frame,Vector3(0,0.4,deep/2+0.32),Vector3(0.26,0.22,0.16),String(colors[0]))
		for foot: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			s.box(frame,Vector3(foot.x*width*0.42,0.09,foot.y*deep*0.4),Vector3(0.3,0.18,0.28),String(colors[2]))
	else:
		s.box(frame,Vector3(0,base/2,0),Vector3(width*1.15,base,deep*0.9),String(colors[2]))
	s.box(frame,Vector3(0,base+height/2,0),Vector3(width,height,thick),String(colors[0]))
	for tier: int in 3:
		s.box(frame,Vector3(0,base+height+0.1+tier*0.18,0),Vector3(width*(0.92-tier*0.22),0.2,thick*1.05),String(colors[1] if tier%2==0 else colors[2]))
	var cols: int = maxi(2,floori(width/0.2))
	var lines: String = Color(String(colors[2])).darkened(0.3).to_html(false)
	for face: float in [-1.0,1.0]:
		s.box(frame,Vector3(0,base+height*0.5,face*(thick/2+0.005)),Vector3(width*0.86,height*0.86,0.012),String(colors[1]))
		for col: int in cols:
			var x: float = -width*0.38+col*width*0.76/maxf(1,cols-1)
			for row: int in maxi(2,floori(height*0.75/0.17)):
				if (col*7+row*3)%9==0:
					continue
				s.box(frame,Vector3(x,base+height*0.86-row*0.17,face*(thick/2+0.012)),Vector3(0.08,0.1,0.012),lines)

## 大香炉: a great bronze censer on a stone base: a round belly on three legs, two ears, a lid
## stepped up to a knob and pierced for the smoke, the embers glowing inside, incense smoke
## curling up from it.
func _censer(w: float) -> void:
	var bronze: Array = _colors("colors",["5d5440","706549","4a4434"])
	s.box(root,Vector3(0,0.12,0),Vector3(w*0.98,0.24,w*0.98),String(data.get("base","a8a598")))
	for leg: int in 3:
		var a: float = leg*TAU/3.0+PI/2
		s.box(root,Vector3(cos(a)*w*0.28,0.46,sin(a)*w*0.28),Vector3(0.16,0.46,0.16),String(bronze[2]))
	s.box(root,Vector3(0,0.98,0),Vector3(w*0.74,0.62,w*0.74),String(bronze[0]))
	s.box(root,Vector3(0,0.92,0),Vector3(w*0.84,0.34,w*0.84),String(bronze[1]))
	s.box(root,Vector3(0,1.3,0),Vector3(w*0.8,0.08,w*0.8),String(bronze[2]))
	for side: float in [-1.0,1.0]:
		s.box(root,Vector3(side*w*0.43,1.47,0),Vector3(0.08,0.34,0.24),String(bronze[1]))
	for tier: int in 3:
		s.box(root,Vector3(0,1.42+tier*0.13,0),Vector3(w*(0.62-tier*0.17),0.13,w*(0.62-tier*0.17)),String(bronze[tier%2]))
	s.box(root,Vector3(0,1.85,0),Vector3(0.14,0.14,0.14),String(data.get("knob","c9a24a")))
	for hole: int in 4:
		var a: float = hole*TAU/4.0
		s.box(root,Vector3(cos(a)*w*0.31,1.42,sin(a)*w*0.31),Vector3(0.1,0.07,0.1),"e8803a:glow")
	if ambience != null:
		ambience.smoke(root,Vector3(0,1.95,0),String(data.get("smoke","cfcac0")),6,0.16)

## 石灯: a stone lantern: a square foot and shaft, the fire box with its windows lit at night, a
## cap curling up at its corners, a jewel on top.
func _stone_lantern() -> void:
	var stone: Array = _colors("colors",["bdb9ad","aaa79a","cbc8bc"])
	var height: float = float(data.get("height",1.6))
	s.box(root,Vector3(0,0.09,0),Vector3(0.62,0.18,0.62),String(stone[1]))
	s.box(root,Vector3(0,0.24,0),Vector3(0.44,0.12,0.44),String(stone[0]))
	s.box(root,Vector3(0,0.3+height*0.2,0),Vector3(0.22,height*0.4,0.22),String(stone[0]))
	s.box(root,Vector3(0,0.3+height*0.42,0),Vector3(0.5,0.08,0.5),String(stone[2]))
	var box_y: float = 0.3+height*0.58
	s.box(root,Vector3(0,box_y,0),Vector3(0.4,height*0.24,0.4),String(stone[0]))
	for out: Vector3 in [Vector3(0,0,1),Vector3(0,0,-1),Vector3(1,0,0),Vector3(-1,0,0)]:
		s.window(root,Vector3(0,box_y,0)+out*0.205,Vector3(0.2,height*0.15,0.02) if out.z != 0.0 else Vector3(0.02,height*0.15,0.2))
	s.box(root,Vector3(0,box_y+height*0.16,0),Vector3(0.66,0.1,0.66),String(stone[2]))
	s.box(root,Vector3(0,box_y+height*0.22,0),Vector3(0.44,0.1,0.44),String(stone[1]))
	for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		s.box(root,Vector3(corner.x*0.3,box_y+height*0.19,corner.y*0.3),Vector3(0.08,0.08,0.08),String(stone[2]))
	s.box(root,Vector3(0,box_y+height*0.3,0),Vector3(0.12,0.14,0.12),String(stone[1]))
	if data.get("lit",true):
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0,box_y,0)
		lamp.light_color = Color("ffc884")
		lamp.omni_range = float(data.get("range",4.5))
		lamp.omni_attenuation = 1.3
		lamp.set_meta("day_energy",0.0)
		lamp.set_meta("night_energy",1.5)
		lamp.set_meta("flicker",0.08)
		root.add_child(lamp)

## 茶花: a bed of camellia bushes along the box, dark glossy leaves, flowers (`flower`) with pale
## hearts, a few petals fallen on the earth under them.
func _camellia_bed(w: float, d: float) -> void:
	var along_x: bool = w>=d
	var length: float = maxf(w,d)
	var depth: float = minf(w,d)
	var bloom: String = String(data.get("flower","c8342c"))
	s.box(root,Vector3(0,0.05,0),_along(along_x,length,0.1,depth),String(data.get("earth","4f3b2c")))
	var count: int = maxi(1,floori(length/0.55))
	for i: int in count:
		var t: float = -length/2+(i+0.5)*length/count
		var at: Vector3 = Vector3(t,0,0) if along_x else Vector3(0,0,t)
		var h: float = rng.randf_range(0.55,0.95)
		s.shard(root,at+Vector3(0,h*0.5,0),Vector3(0.6,h,0.55),_pick(["2c4a33","355a3b","3f6a42"]),i)
		s.shard(root,at+Vector3(rng.randf_range(-0.1,0.1),h*0.95,0),Vector3(0.42,h*0.3,0.4),_pick(["3a5f3f","467048"]),i+3)
		for flower: int in 3:
			var spot := Vector3(rng.randf_range(-0.26,0.26),h*rng.randf_range(0.5,1.05),rng.randf_range(-0.24,0.24))
			s.box(root,at+spot,Vector3(0.13,0.1,0.13),bloom)
			s.box(root,at+spot+Vector3(0,0.05,0),Vector3(0.05,0.03,0.05),"f2dc8e")
		s.box(root,at+Vector3(rng.randf_range(-0.3,0.3),0.11,rng.randf_range(-0.2,0.2)),Vector3(0.1,0.015,0.08),bloom)

## 怪石: one tall stone stood alone (forehall.c's 灰绿色的怪石), leaning and pinched in the
## middle, pocked with dark holes, moss in its hollows; `height` units.
func _strange_stone(w: float, d: float) -> void:
	var stone: Array = _colors("colors",["7a877d","8b978c","6a766d","9aa597"])
	var height: float = float(data.get("height",2.0))
	var size: float = minf(w,d)
	var lean: float = rng.randf_range(-0.18,0.18)
	s.shard(root,Vector3(0,0.08,0),Vector3(w*1.05,0.16,d*1.05),String(stone[2]),5)
	var courses: int = 6
	for i: int in courses:
		var t: float = float(i)/courses
		var girth: float = size*(0.72+0.32*sin(t*PI*1.4+0.4))
		var at := Vector3(sin(lean)*t*height+rng.randf_range(-0.06,0.06),0.16+(t+0.5/courses)*height,rng.randf_range(-0.05,0.05))
		s.shard(root,at,Vector3(girth*rng.randf_range(0.85,1.1),height/courses*1.25,girth*rng.randf_range(0.7,0.95)),_pick(stone),i*3+1,rng.randf()*TAU)
		if i%2==1:
			s.box(root,at+Vector3(girth*0.38,0,girth*0.25),Vector3(0.13,0.15,0.09),"3a423d")
		if rng.randf()<0.4:
			s.box(root,at+Vector3(-girth*0.3,height/courses*0.4,0),Vector3(0.16,0.04,0.14),_pick(["5d7a45","6c8a4c"]))

## 檀木门: one side of a carved sandalwood gateway across a hall (entrance.c's 正门共分三进): its
## post at the opening's edge (local +x), the panelled leaf folded back along the box, the lintel
## reaching over half the opening (`opening` px), and over the middle a board (`plaque`:
## {"text"}, or {"scrawl": true}: 龙飞凤舞, too wild to read) on the side that carries it.
func _gate_frame(w: float, d: float) -> void:
	var wood: Array = _colors("colors",["7a4a32","8e5a3a","5e3826"])
	var height: float = float(data.get("height",3.0))
	var half: float = float(data.get("opening",160))/32.0/2.0
	var post_x: float = w/2-0.16
	s.box(root,Vector3(post_x,0.1,0),Vector3(0.46,0.2,0.46),"a8a497")
	s.box(root,Vector3(post_x,height/2,0),Vector3(0.32,height,0.32),String(wood[0]))
	s.box(root,Vector3(-w/2+0.1,height/2,0),Vector3(0.2,height,0.24),String(wood[0]))
	var leaf: float = w-0.5
	var leaf_x: float = -0.05
	s.box(root,Vector3(leaf_x,0.55,0),Vector3(leaf,0.9,d*0.4),String(wood[1]))
	s.box(root,Vector3(leaf_x,0.55,d*0.21),Vector3(leaf-0.2,0.66,0.02),String(wood[2]))
	s.box(root,Vector3(leaf_x,1.7,0),Vector3(leaf,1.3,d*0.25),String(wood[2]))
	for bar: int in 5:
		s.box(root,Vector3(leaf_x,1.15+bar*0.27,d*0.14),Vector3(leaf-0.1,0.05,0.04),String(wood[1]))
	for bar: int in maxi(2,floori(leaf/0.3)):
		s.box(root,Vector3(-leaf/2+leaf_x+0.15+bar*0.3,1.7,d*0.14),Vector3(0.05,1.25,0.04),String(wood[1]))
	s.box(root,Vector3(leaf_x,2.45,0),Vector3(leaf,0.2,d*0.4),String(wood[1]))
	# The lintel over its half of the opening, cloud brackets under it at the post.
	var reach: float = w+half
	s.box(root,Vector3(-w/2+reach/2,height+0.12,0),Vector3(reach,0.26,0.34),String(wood[0]))
	s.box(root,Vector3(-w/2+reach/2,height-0.12,0),Vector3(reach,0.14,0.26),String(data.get("frieze","2f6a70")))
	for side: float in [-1.0,1.0]:
		s.tilted_box(root,Vector3(post_x+side*0.3,height-0.35,0),Vector3(0.12,0.5,0.2),String(wood[1]),Vector3(0,0,side*0.6))
	if data.has("plaque"):
		var plaque: Dictionary = data["plaque"]
		var at := Vector3(w/2+half,height+0.72,0.1)
		var width: float = minf(half*1.5,2.6)
		s.box(root,at,Vector3(width+0.16,0.86,0.08),String(plaque.get("frame","c9a24a")))
		s.box(root,at+Vector3(0,0,0.05),Vector3(width,0.7,0.04),String(plaque.get("board","2b2520")))
		if plaque.get("scrawl",false):
			# Brush strokes flung across the board, joined and looping: no character to be read.
			for stroke: int in 9:
				var x: float = -width*0.42+stroke*width*0.105
				s.tilted_box(root,at+Vector3(x,sin(stroke*2.1)*0.12,0.08),Vector3(0.06,0.42+0.12*sin(stroke*1.3),0.02),"e6c66e",Vector3(0,0,0.9*sin(stroke*1.7)))
				s.tilted_box(root,at+Vector3(x+0.05,0.16*cos(stroke*1.9),0.085),Vector3(0.2,0.05,0.02),"e6c66e",Vector3(0,0,0.6*cos(stroke*2.3)))
		else:
			var title := Label3D.new()
			title.text = TranslationServer.translate(String(plaque.get("text","")))
			title.position = at+Vector3(0,0,0.08)
			title.pixel_size = 0.008
			title.font_size = 56
			title.outline_size = 0
			title.modulate = Color("e6c66e")
			root.add_child(title)
	if data.get("lantern",false):
		s.lantern(root,Vector3(post_x+0.55,height-0.75,0.0),false,"d8452f:glow")
