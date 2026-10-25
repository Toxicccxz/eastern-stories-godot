extends RefCounted

## Gardens and yards (美术规划 group D): a pavilion (whole, or leaning and falling in), a
## rockery of holed stones, lotus on a pond, a swing frame, thorny brambles, a stone table
## with drum stools and a round gateway in a garden wall. Sizes and colours from the data.
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
	s.box(swing,Vector3(-0.35,-drop/2,0),Vector3(0.03,drop,0.03),"b09a6c")
	if broken:
		swing.rotation = Vector3(0.3,0,0.35)
		s.box(swing,Vector3(0.05,-drop*0.45,0.1),Vector3(0.03,drop*0.6,0.03),"b09a6c")
	else:
		s.box(swing,Vector3(0.35,-drop/2,0),Vector3(0.03,drop,0.03),"b09a6c")
	s.box(swing,Vector3(0,-drop,0),Vector3(0.85,0.06,0.3),"8a6a45")
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
