extends RefCounted

## 立面细节 (雪亭镇立面细化): what age and daily use leave on the outside of a building, each from a
## key of its `buildings` entry; where a key is absent nothing is drawn, so a building written
## without them draws as it did. Everything varies by where it stands (Shapes.place_seed), never
## by the build's random source, so adding one key never reshuffles the rest of the map.
##
## On the walls, panel by panel (the share of panels each touches, 0..1):
## `damp` (返潮: {"height", "color", "share"}; a dark band at the wall's foot, its top ragged — in a
## pale colour, the chaff and flour on a mill's wall), `stains` (雨水渍 down from the eaves and from
## the window sills), `patches` (补丁: fresh lime on plaster, a new board in a timber wall, other
## bricks in a brick one; `patch_colors`), `cracks`, `foot_weeds` (grass at the plinth, moss on
## it; `weed_colors`), `notices` (old papers pasted up, some half torn away), `soot` ({"eaves":
## share, "door": true, "color"}: smoke-blackened under the eaves and over the door).
## Windows: `windows` ({"style": "propped" (支摘窗, the upper sash propped open on a stick) |
## "shutters" (board shutters, open against the wall or shut), "share", "sill": "pots" | "herbs" |
## "orchids", "sill_share"}).
## Roofs: `eave_tiles` (瓦当滴水 along the eaves), `ridge_tips` (the ridge's ends curled up),
## `roof_weeds` (瓦松 and grass, the share of tiles).
## At the door: `couplets` ({"paper", "letters", "faded", "lintel"}), `door_paper` (on a shut
## door: {"kind": "gods" | "fu", "faded"}), `steps` ({"count", "color"}), `door_stones` ({"kind":
## "drum" | "block", "color"}), `blade_sign` (竖招: {"text", "board", "letters", "frame", "side",
## "length"}, hung square off the wall so both views read it), `door_glow` (the light of a fire
## within: {"color", "day", "night", "embers"}).
## On the walls' faces: `wall_hangings` ([{"kind", "wall": "north" | "south" | "east" | "west",
## "at": 0..1 along it (west to east, north to south), "y"}]): the household's wall kinds
## (string_hang, straw_cape, tool_hooks, notices, new_year_print, double_happiness ...) and
## "broom", "kindling", "winnow", "hat" here.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
const Household = preload("res://presentation/voxel/props/voxel_household.gd")
var shapes: Shapes
var noise: FastNoiseLite
var ambience: VoxelAmbience
## The masses' footprints (body coordinates: x, z): the enclosure's own walls under them carry no
## wear (the mass's walls there carry it, at their own height).
var covered: Array[Rect2] = []
## Wall hangings of a kind nobody draws, or with no room on their wall (the map's unknown kinds
## take them, so a test sees them).
var unknown: Array[String] = []
## Where the wall hangings went: wall and panel, one entry each.
var placed: Array[String] = []

const PANEL_KEYS: Array[String] = ["damp","stains","patches","cracks","foot_weeds","notices","soot"]
const GREENS: Array = ["5f7a3a","6f8a44","4f6a34","7d8f4a"]

## Whether any panel key is written (else the walls are left as they were).
static func wears(data: Dictionary) -> bool:
	for key: String in PANEL_KEYS:
		if data.has(key):
			return true
	return false

## How far a wall's outer face stands from the middle of its panels, by how it is built (boards,
## bricks and stones lie proud of a plaster panel; a dado stands proud of the plaster).
static func skin(data: Dictionary) -> float:
	var face: float = {"timber":0.165,"brick":0.185,"earth":0.155,"rubble":0.215}.get(String(data.get("construction","plaster")),0.145)
	return maxf(face,0.17) if data.has("wall_bands") else face

## Whether a face of `node` turned `out` looks north: both views look from the south (DECISIONS
## 「固定俯视体素地图」), so nothing on it is ever seen and nothing is drawn there.
static func facing_away(node: Node3D, out: Vector3) -> bool:
	return (node.global_transform.basis*out).normalized().z < -0.5

## A number in [0, 1) from a place's seed and a salt: the same every build.
static func roll(seed: int, salt: int) -> float:
	return float(Shapes.place_seed(seed,salt,7,salt*3+1)%1000)/1000.0

## Wear on one panel of a wall: `at` its middle (y half its height), `out` the wall's outward
## normal, `window_y` the middle of its window (or -1 where it has none).
func panel(body: Node3D, at: Vector3, out: Vector3, along_x: bool, height: float, foundation: float, window_y: float, data: Dictionary, on_body: bool) -> void:
	if on_body:
		for rect: Rect2 in covered:
			if rect.grow(0.3).has_point(Vector2(at.x,at.z)):
				return
	if facing_away(body,out):
		return
	var spot: Vector3 = body.global_transform*at
	var seed: int = Shapes.place_seed(roundi(spot.x*4),0,roundi(spot.z*4),23)
	var face: float = skin(data)+0.01
	var wall := Color(String(data.get("wall","c8b999")))
	var window: bool = window_y >= 0.0
	var window_top: float = window_y+0.5
	var sill: float = window_y-0.5
	var plinth_top: float = 0.205+(maxi(1,ceili(foundation/0.22))-1)*0.21
	if data.has("damp"):
		var damp: Dictionary = data["damp"] if data["damp"] is Dictionary else {}
		if roll(seed,1) < float(damp.get("share",1.0)):
			var n: float = clampf(noise.get_noise_2d(spot.x*3.1+70.0,spot.z*3.1)+0.5,0.0,1.0)
			var tall: float = float(damp.get("height",0.7))*(0.5+0.9*n)
			var tone: Color = Color(String(damp["color"])) if damp.has("color") else wall.darkened(0.24).lerp(Color("4a5240"),0.12)
			_flat(body,at,out,along_x,face,0.0,plinth_top+tall/2,0.5,tall,tone)
			var lip: float = roll(seed,2)
			if lip < 0.5:
				_flat(body,at,out,along_x,face,(lip-0.25)*0.5,plinth_top+tall+0.05,0.16+0.2*lip,0.1,tone.lerp(wall,0.4))
	var stains: float = float(data.get("stains",0.0))
	if stains > 0.0 and roll(seed,3) < stains:
		var r: float = roll(seed,4)
		var top: float = height-0.24
		var bottom: float = top-(0.5+1.2*r)
		if window:
			bottom = maxf(bottom,window_top)
		if top-bottom > 0.15:
			var wide: float = 0.1+0.12*roll(seed,5)
			var dx: float = (roll(seed,6)-0.5)*0.24
			_flat(body,at,out,along_x,face,dx,(top+bottom)/2,wide,top-bottom,wall.darkened(0.17 if r < 0.5 else 0.24))
			_flat(body,at,out,along_x,face+0.004,dx,top-(top-bottom)*0.25,wide*0.5,(top-bottom)*0.5,wall.darkened(0.32))
	if window and stains > 0.0 and roll(seed,7) < stains*1.6:
		var drip: float = 0.35+0.4*roll(seed,8)
		_flat(body,at,out,along_x,face,(roll(seed,9)-0.5)*0.3,sill-drip/2,0.09,drip,wall.darkened(0.22))
	var patches: float = float(data.get("patches",0.0))
	if patches > 0.0 and roll(seed,10) < patches:
		var pw: float = 0.24+0.2*roll(seed,11)
		var ph: float = 0.2+0.3*roll(seed,12)
		var y: float = plinth_top+0.3+ph/2+roll(seed,13)*maxf(0.0,height-plinth_top-1.2-ph)
		if window and y+ph/2 > sill-0.05:
			y = plinth_top+0.25+ph/2
		var dx: float = (roll(seed,14)-0.5)*(0.46-pw)
		var colors: Array = data.get("patch_colors",_patch_colors(data,wall))
		var tone: String = String(colors[Shapes.place_seed(seed,15)%colors.size()])
		_flat(body,at,out,along_x,face-0.003,dx,y,pw+0.05,ph+0.05,wall.darkened(0.22))
		_flat(body,at,out,along_x,face+0.004,dx,y,pw,ph,Color(tone))
		if String(data.get("construction","plaster")) == "brick":
			for row: int in 2:
				_flat(body,at,out,along_x,face+0.008,dx,y-ph/4+row*ph/2,pw,0.025,wall.darkened(0.3))
	var cracks: float = float(data.get("cracks",0.0))
	if cracks > 0.0 and roll(seed,16) < cracks:
		var from := Vector2((roll(seed,17)-0.5)*0.3,plinth_top+0.6+roll(seed,18)*maxf(0.2,height-plinth_top-1.6))
		if window and from.y > sill-0.1:
			from.y = window_top+0.1 if window_top+0.6 < height else sill-0.1
		var lean: float = 1.0 if roll(seed,19) < 0.5 else -1.0
		for step: int in 3:
			var length: float = 0.18+0.14*roll(seed,20+step)
			var angle: float = lean*(0.5 if step%2 == 0 else -0.35)
			var to: Vector2 = from+Vector2(sin(angle),-cos(angle))*length
			_line(body,at,out,along_x,face+0.006,from,to,0.035,wall.darkened(0.42))
			from = to
	var weeds: float = float(data.get("foot_weeds",0.0))
	if weeds > 0.0 and roll(seed,24) < weeds:
		var greens: Array = data.get("weed_colors",GREENS)
		for tuft: int in 2+int(roll(seed,25)*2.0):
			var tall: float = 0.08+0.24*roll(seed,26+tuft)
			var dx: float = (roll(seed,31+tuft)-0.5)*0.46
			var reach: float = 0.27+0.14*roll(seed,36+tuft)
			var wide: float = 0.06+0.07*roll(seed,41+tuft)
			var tone := Color(String(greens[Shapes.place_seed(seed,46+tuft)%greens.size()]))
			shapes.box(body,_on(at,out,along_x,reach,dx,tall/2),Vector3(wide,tall,wide),tone.to_html(false))
		shapes.box(body,_on(at,out,along_x,0.2,(roll(seed,51)-0.5)*0.2,plinth_top+0.01),Vector3(0.32,0.04,0.14) if along_x else Vector3(0.14,0.04,0.32),String(data.get("moss","5d7044")))
	var notices: float = float(data.get("notices",0.0))
	if notices > 0.0 and not window and roll(seed,52) < notices:
		var papers: Array = ["e6dcc0","d8c8a0","c8b88a","ddd0b0"]
		var pw: float = 0.28+0.08*roll(seed,53)
		var ph: float = 0.36+0.1*roll(seed,54)
		var y: float = 1.25+0.4*roll(seed,55)
		var dx: float = (roll(seed,56)-0.5)*0.16
		var paper := Color(String(papers[Shapes.place_seed(seed,57)%papers.size()]))
		var torn: bool = roll(seed,58) < 0.45
		var shown: float = ph*0.55 if torn else ph
		_flat(body,at,out,along_x,face,dx,y+(ph-shown)/2,pw,shown,paper)
		for column: int in 3:
			_flat(body,at,out,along_x,face+0.004,dx-pw*0.28+column*pw*0.28,y+(ph-shown)/2+shown*0.06,0.03,shown*0.6,Color("4a4440"))
		if torn:
			_line(body,at,out,along_x,face+0.002,Vector2(dx+pw*0.3,y),Vector2(dx+pw*0.38,y-0.16),0.08,paper.darkened(0.08))
	if data.has("soot") and data["soot"] is Dictionary and float(data["soot"].get("eaves",0.0)) > 0.0:
		var soot: Dictionary = data["soot"]
		if roll(seed,59) < float(soot["eaves"]):
			var n: float = clampf(noise.get_noise_2d(spot.x*2.3,spot.z*2.3+40.0)+0.5,0.0,1.0)
			var tall: float = 0.25+0.35*n
			var tone: Color = Color(String(soot.get("color","3a3632"))).lerp(wall,0.35+0.3*(1.0-n))
			_flat(body,at,out,along_x,face+0.006,0.0,height-0.22-tall/2,0.5,tall,tone)

## The usual mend for a wall of its make.
func _patch_colors(data: Dictionary, wall: Color) -> Array:
	match String(data.get("construction","plaster")):
		"timber": return ["a8865a","b8956a","9a7a50"]
		"brick": return ["8a8070","7e7466","958a78"]
	return [wall.lightened(0.08).to_html(false),wall.lightened(0.05).lerp(Color("d8c8a8"),0.25).to_html(false)]

## A point `reach` out from a panel's middle line, `dx` along the wall, at height `y`.
static func _on(at: Vector3, out: Vector3, along_x: bool, reach: float, dx: float, y: float) -> Vector3:
	return Vector3(at.x+(dx if along_x else 0.0),y,at.z+(0.0 if along_x else dx))+out*reach

## A thin flat piece laid on the wall's face.
func _flat(body: Node3D, at: Vector3, out: Vector3, along_x: bool, face: float, dx: float, y: float, across: float, tall: float, tone: Color) -> void:
	shapes.box(body,_on(at,out,along_x,face,dx,y),Vector3(across,tall,0.02) if along_x else Vector3(0.02,tall,across),tone.to_html(false))

## A thin straight mark on the wall's face from `from` to `to` (along the wall, up it).
func _line(body: Node3D, at: Vector3, out: Vector3, along_x: bool, face: float, from: Vector2, to: Vector2, width: float, tone: Color) -> void:
	var mid: Vector2 = (from+to)/2
	var span: Vector2 = to-from
	var angles := Vector3(0,0,atan2(-span.x,span.y)) if along_x else Vector3(atan2(span.x,span.y),0,0)
	shapes.tilted_box(body,_on(at,out,along_x,face,mid.x,mid.y),Vector3(width,span.length(),0.02) if along_x else Vector3(0.02,span.length(),width),tone.to_html(false),angles)

## A window's dressing (`windows`): `window_at` its middle on the frame, `pair` +1 for the left
## panel of a window pair, -1 for the right (the pair's middle is half a panel that way).
func window(body: Node3D, at: Vector3, window_y: float, out: Vector3, along_x: bool, pair: float, data: Dictionary, timber: String) -> void:
	var spec: Dictionary = data["windows"]
	if facing_away(body,out):
		return
	var along := Vector3(1,0,0) if along_x else Vector3(0,0,1)
	var middle: Vector3 = at+along*0.25*pair
	var spot: Vector3 = body.global_transform*middle
	var seed: int = Shapes.place_seed(roundi(spot.x*4),0,roundi(spot.z*4),31)
	var face: float = skin(data)
	var style: String = String(spec.get("style","propped"))
	if roll(seed,1) < float(spec.get("share",0.5)):
		var pane := Vector3(at.x,window_y,at.z)
		if style == "propped":
			# 支摘窗: the upper sash swung out on its top rail and propped on a stick.
			var swing: float = 0.65
			var hinge: Vector3 = pane+Vector3(0,0.36,0)+out*0.3
			var sash: Vector3 = hinge+Vector3(0,-0.19*cos(swing),0)+out*0.19*sin(swing)
			var angles := Vector3(-swing*out.z,0,0) if along_x else Vector3(0,0,swing*out.x)
			shapes.tilted_box(body,sash,Vector3(0.44,0.38,0.05) if along_x else Vector3(0.05,0.38,0.44),timber,angles)
			shapes.tilted_box(body,sash+out*0.03,Vector3(0.34,0.28,0.02) if along_x else Vector3(0.02,0.28,0.34),"cdb88c",angles)
			shapes.box(body,pane+Vector3(0,0.18,0)+out*0.24,Vector3(0.36,0.34,0.02) if along_x else Vector3(0.02,0.34,0.36),"2a241e")
			if pair > 0.0:
				shapes.tilted_box(body,pane+Vector3(0,0.05,0)+out*0.4,Vector3(0.03,0.44,0.03),"5a4632",Vector3(0.6*out.z,0,0) if along_x else Vector3(0,0,-0.6*out.x))
		elif style == "shutters":
			if roll(seed,2) < 0.4:
				# Shut: boards over the window, a crack of light between them at night.
				for half: float in [-0.11,0.11]:
					shapes.box(body,pane+along*half+out*0.31,Vector3(0.2,0.8,0.04) if along_x else Vector3(0.04,0.8,0.2),Color(timber).lightened(0.12).to_html(false))
				shapes.box(body,pane+out*0.335,Vector3(0.44,0.06,0.03) if along_x else Vector3(0.03,0.06,0.44),timber)
			else:
				# Open, folded back flat against the wall beside the window.
				var leaf: Vector3 = Vector3(at.x,window_y,at.z)-along*0.47*pair+out*(face+0.03)
				shapes.box(body,leaf,Vector3(0.4,0.8,0.04) if along_x else Vector3(0.04,0.8,0.4),Color(timber).lightened(0.12).to_html(false))
				for board: float in [-0.1,0.1]:
					shapes.box(body,leaf+along*board+out*0.025,Vector3(0.02,0.76,0.01) if along_x else Vector3(0.01,0.76,0.02),timber)
	if pair > 0.0 and spec.has("sill") and roll(seed,3) < float(spec.get("sill_share",0.5)):
		var ledge: Vector3 = Vector3(middle.x,window_y-0.52,middle.z)+out*0.33
		shapes.box(body,ledge,Vector3(1.0,0.06,0.22) if along_x else Vector3(0.22,0.06,1.0),timber)
		for i: int in 2:
			var item: Vector3 = ledge+along*(-0.24+i*0.48)+Vector3(0,0.03,0)
			match String(spec["sill"]):
				"herbs":
					shapes.box(body,item+Vector3(0,0.02,0),Vector3(0.36,0.04,0.18) if along_x else Vector3(0.18,0.04,0.36),"b39a5c")
					shapes.box(body,item+Vector3(0,0.05,0),Vector3(0.28,0.03,0.12) if along_x else Vector3(0.12,0.03,0.28),["7d8a52","8a5a3a"][i])
				"orchids":
					shapes.box(body,item+Vector3(0,0.08,0),Vector3(0.14,0.16,0.14),"5d7f78")
					for blade: int in 3:
						shapes.tilted_box(body,item+Vector3(0,0.28,0),Vector3(0.025,0.32,0.025),"4a7a3a",Vector3((blade-1)*0.5,0,(blade-1)*0.35))
				_:
					shapes.box(body,item+Vector3(0,0.08,0),Vector3(0.16,0.16,0.16),["8b5440","6b4a35"][i])
					shapes.box(body,item+Vector3(0,0.22,0),Vector3(0.22,0.14,0.22),["5f8a3c","74a04a"][i])
					if roll(seed,4+i) < 0.5:
						shapes.box(body,item+Vector3(0.04,0.3,0.02),Vector3(0.07,0.06,0.07),["e2c25c","d65a4a"][i])

## A roof tile's weeds (`roof_weeds`): a tuft of grass or a 瓦松 rosette on the shady old tiles.
func roof_tile(root: Node3D, tile_at: Vector3, data: Dictionary) -> void:
	var spot: Vector3 = root.global_transform*tile_at
	var seed: int = Shapes.place_seed(roundi(spot.x*8),roundi(spot.y*8),roundi(spot.z*8),37)
	var patch: float = noise.get_noise_2d(spot.x*5+200.0,spot.z*5)
	if roll(seed,1) >= float(data["roof_weeds"])*clampf(1.0+patch*2.0,0.0,2.5):
		return
	if roll(seed,2) < 0.4:
		shapes.box(root,tile_at+Vector3(0,0.12,0),Vector3(0.2,0.07,0.2),"7a9a86")
		shapes.box(root,tile_at+Vector3(0,0.18,0),Vector3(0.1,0.08,0.1),"8aaa94")
	else:
		var greens: Array = data.get("weed_colors",GREENS)
		for blade: int in 3:
			var tall: float = 0.12+0.2*roll(seed,3+blade)
			shapes.box(root,tile_at+Vector3(-0.08+blade*0.08,0.08+tall/2,(roll(seed,6+blade)-0.5)*0.12),Vector3(0.05,tall,0.05),String(greens[(seed+blade)%greens.size()]))

## The ridge's ends curled up (`ridge_tips`), over a roof `ridge_length` long.
func ridge_tips(root: Node3D, ridge_length: float, top: float, tint: Color, glaze: String) -> void:
	var tone: String = tint.darkened(0.14).to_html(false)+glaze
	for end: float in [-1.0,1.0]:
		var tip := Vector3(end*ridge_length/2,top,0)
		shapes.box(root,tip+Vector3(end*0.08,0.12,0),Vector3(0.34,0.26,0.3),tone)
		shapes.tilted_box(root,tip+Vector3(end*0.3,0.3,0),Vector3(0.3,0.16,0.24),tone,Vector3(0,0,end*0.55))
		shapes.box(root,tip+Vector3(end*0.42,0.48,0),Vector3(0.14,0.18,0.18),tone)

## 瓦当滴水 along a roof's eaves: the round caps of the cover tiles and the pointed drips of the
## pan tiles between them, a dark beaded edge. `top` gives the roof's height over a point.
func eave_tiles(root: Node3D, wide: float, deep: float, height: float, curve: float, form: String, tint: Color, glaze: String, spacing: Vector2, top: Callable) -> void:
	var cap: String = tint.darkened(0.26).to_html(false)+glaze
	var drip: String = tint.darkened(0.16).to_html(false)+glaze
	var cols: int = roundi(wide/spacing.x)
	for side: float in [-1.0,1.0]:
		# A shed roof's high side has no eave; a north eave is behind its roof from both views.
		if form == "shed" and side > 0.0 or facing_away(root,Vector3(0,0,side)):
			continue
		var pz: float = side*(deep/2-spacing.y/2)
		var t: float = clampf(absf(pz)/(deep/2),0.0,1.0)
		for col: int in cols:
			var px: float = -wide/2+(col+0.5)*spacing.x
			var y: float = height+0.02+float(top.call(px,pz))+pow(t,5)*curve
			if col%2 == 0:
				shapes.box(root,Vector3(px,y,side*(deep/2+0.03)),Vector3(0.15,0.15,0.07),cap)
			else:
				shapes.box(root,Vector3(px,y-0.05,side*(deep/2+0.02)),Vector3(0.18,0.14,0.06),drip)
	if form in ["hip","xieshan"]:
		var rows: int = roundi(deep/spacing.y)
		for end: float in [-1.0,1.0]:
			if facing_away(root,Vector3(end,0,0)):
				continue
			var px: float = end*(wide/2-spacing.x/2)
			for row: int in rows:
				var pz: float = -deep/2+(row+0.5)*spacing.y
				var t: float = clampf(absf(pz)/(deep/2),0.0,1.0)
				var y: float = height+0.02+float(top.call(px,pz))+pow(t,5)*curve
				shapes.box(root,Vector3(end*(wide/2+0.03),y,pz),Vector3(0.07,0.15,0.15),cap if row%2 == 0 else drip)

## What stands at a doorway beyond the old porch and goods: `front` the doorway's node (+z out
## to the street, x along the wall), `half` the opening's half width, `wall_z` the wall's face.
func entrance(front: Node3D, merge_into: Node3D, data: Dictionary, half: float, wall_z: float, wall_top: float) -> void:
	# A doorway turned north is never seen (both views look from the south).
	if facing_away(front,Vector3(0,0,1)):
		return
	# A shop's posts stand a body out in the street before its wall (a porch): what stands at
	# its door stands at the posts.
	var porched: bool = wall_z < -0.3
	var base: float = 0.14 if porched else wall_z
	if data.has("steps"):
		var steps: Dictionary = data["steps"] if data["steps"] is Dictionary else {"count":int(data["steps"])}
		var count: int = int(steps.get("count",2))
		var stone := Color(String(steps.get("color","9a9a90")))
		for k: int in count:
			var deep: float = (count-k)*0.32
			var tall: float = (k+1)*0.075
			shapes.box(front,Vector3(0,tall/2,base-0.3+(deep+0.3)/2),Vector3(half*2.0+0.6-k*0.1,tall,deep+0.3),stone.darkened(0.05*(k%2)).to_html(false))
	if data.has("door_stones"):
		var stones: Dictionary = data["door_stones"] if data["door_stones"] is Dictionary else {"kind":String(data["door_stones"])}
		var grey := Color(String(stones.get("color","8e8e84")))
		for side: float in [-1.0,1.0]:
			var foot := Vector3(side*(half+0.3),0,base+0.3)
			shapes.box(front,foot+Vector3(0,0.18,0),Vector3(0.34,0.36,0.6),grey.to_html(false))
			if String(stones.get("kind","drum")) == "drum":
				# 抱鼓石: a drum stood on its edge on the block, its face to the street's way.
				shapes.box(front,foot+Vector3(0,0.66,0),Vector3(0.2,0.56,0.44),grey.lightened(0.06).to_html(false))
				shapes.box(front,foot+Vector3(0,0.66,0),Vector3(0.2,0.44,0.56),grey.lightened(0.06).to_html(false))
				shapes.box(front,foot+Vector3(0,0.66,0),Vector3(0.24,0.2,0.2),grey.darkened(0.12).to_html(false))
			else:
				shapes.box(front,foot+Vector3(0,0.4,0),Vector3(0.3,0.1,0.52),grey.lightened(0.08).to_html(false))
	if data.has("couplets"):
		_couplets(front,data["couplets"] if data["couplets"] is Dictionary else {},half,wall_z,porched)
	if data.has("door_paper") and String(data.get("doorway","")) == "shut":
		var paper: Dictionary = data["door_paper"] if data["door_paper"] is Dictionary else {"kind":String(data["door_paper"])}
		var red := Color(String(paper.get("paper","c0392b"))).lerp(Color("d8c0b0"),float(paper.get("faded",0.3)))
		if String(paper.get("kind","fu")) == "gods":
			# 门神: a warrior painted on each leaf, his coat and face, the paper's edge gone pale.
			for side: float in [-1.0,1.0]:
				var at := Vector3(side*0.45,1.62,0.075)
				shapes.box(front,at,Vector3(0.56,0.74,0.012),red.to_html(false))
				shapes.box(front,at+Vector3(0,-0.08,0.008),Vector3(0.34,0.44,0.01),["3f5f7a","6a4a2a"][int(side > 0.0)])
				shapes.box(front,at+Vector3(0,0.22,0.008),Vector3(0.16,0.16,0.01),"d8b088")
				shapes.box(front,at+Vector3(0,0.32,0.01),Vector3(0.2,0.06,0.01),"2a2622")
		else:
			var fu := Node3D.new()
			fu.position = Vector3(0,1.62,0.075)
			fu.rotation.z = PI/4
			front.add_child(fu)
			shapes.merge(fu,merge_into)
			shapes.box(fu,Vector3.ZERO,Vector3(0.46,0.46,0.012),red.to_html(false))
			for bar: int in 3:
				shapes.box(fu,Vector3(-0.08+bar*0.08,0,0.008),Vector3(0.04,0.26,0.01),"2a2622")
	if data.has("soot") and data["soot"] is Dictionary and data["soot"].get("door",false):
		# Smoke from within has blackened the lintel and the posts' heads, and the wall over the
		# opening as far as it goes before the eaves (`top`: the wall's height there, else the
		# height of what stands over the doorway).
		var soot: Dictionary = data["soot"]
		var black := Color(String(soot.get("color","3a3632")))
		var wall := Color(String(data.get("wall","c8b999")))
		var top: float = float(soot.get("top",wall_top))-0.2
		shapes.box(front,Vector3(0,2.68,0.2),Vector3(half*2.0+0.27,0.27,0.02),black.to_html(false))
		for side: float in [-1.0,1.0]:
			shapes.box(front,Vector3(side*(half-0.02),2.2,0.145),Vector3(0.22,0.7,0.02),black.lerp(Color(String(data.get("posts",data.get("timber","79533d")))),0.35).to_html(false))
		for layer: int in 4:
			var y: float = 2.95+layer*0.3
			if y+0.17 > top:
				break
			var across: float = half*2.0+0.8-layer*0.4
			shapes.box(front,Vector3(0,y,wall_z+0.012+layer*0.002),Vector3(across,0.34,0.02),black.lerp(wall,0.15+layer*0.18).to_html(false))
	if data.has("blade_sign"):
		_blade_sign(front,data["blade_sign"],half,wall_z)
	if data.has("door_glow"):
		var glow: Dictionary = data["door_glow"] if data["door_glow"] is Dictionary else {}
		var fire := Color(String(glow.get("color","ff7a3a")))
		var light := OmniLight3D.new()
		light.position = Vector3(0,1.1,wall_z-0.8)
		light.light_color = fire
		light.omni_range = float(glow.get("range",4.5))
		light.omni_attenuation = 1.4
		light.set_meta("day_energy",float(glow.get("day",0.8)))
		light.set_meta("night_energy",float(glow.get("night",2.6)))
		light.light_energy = float(glow.get("day",0.8))
		front.add_child(light)
		if glow.get("embers",true):
			shapes.box(front,Vector3(0.3,0.06,wall_z-1.0),Vector3(0.7,0.12,0.5),fire.to_html(false)+":glow")

## 对联 down the door's posts (on the wall either side where the door is in the wall), a 横批 on
## the lintel (`lintel`), the red gone pale and torn away below on old ones (`faded`).
func _couplets(front: Node3D, spec: Dictionary, half: float, wall_z: float, porched: bool) -> void:
	var faded: float = float(spec.get("faded",0.2))
	var red := Color(String(spec.get("paper","b8342a"))).lerp(Color("d8c0b0"),faded)
	var ink := Color(String(spec.get("letters","2a2018")))
	var z: float = 0.15 if porched else wall_z+0.012
	var wide: float = 0.18 if porched else 0.28
	for side: float in [-1.0,1.0]:
		var torn: float = 0.35 if faded > 0.45 and side > 0.0 else 0.0
		var tall: float = 1.6*(1.0-torn)
		var x: float = side*(half-0.02 if porched else half+0.32)
		shapes.box(front,Vector3(x,2.25-tall/2,z),Vector3(wide,tall,0.02),red.to_html(false))
		for c: int in 6:
			if 2.1-c*0.25 < 2.25-tall:
				break
			shapes.box(front,Vector3(x,2.1-c*0.25,z+0.012),Vector3(wide*0.5,0.13,0.008),ink.to_html(false))
		if torn > 0.0:
			shapes.tilted_box(front,Vector3(x+0.05,2.25-tall-0.1,z+0.008),Vector3(wide*0.45,0.2,0.012),red.lightened(0.1).to_html(false),Vector3(0,0,0.5))
	if spec.get("lintel",false):
		var lintel_z: float = 0.215 if porched else wall_z+0.012
		shapes.box(front,Vector3(0,2.68 if porched else 2.98,lintel_z),Vector3(half*2.0-0.3,0.2,0.02),red.to_html(false))
		for c: int in 4:
			shapes.box(front,Vector3(-0.45+c*0.3,2.68 if porched else 2.98,lintel_z+0.012),Vector3(0.12,0.12,0.008),ink.to_html(false))

## 竖招: a narrow board hung on an iron arm square off the wall beside the doorway, its words in a
## column on both faces (the street's two ways), stirring a little on its hooks.
func _blade_sign(front: Node3D, spec: Dictionary, half: float, wall_z: float) -> void:
	# By default on the doorway's south side: both views look from the south, so a sign on the
	# north side stands behind the porch.
	var side: float = float(spec.get("side",1.0 if (front.global_transform.basis*Vector3(1,0,0)).z > 0.0 else -1.0))
	var length: float = float(spec.get("length",1.3))
	var top: float = float(spec.get("y",2.75))
	var x: float = side*float(spec.get("x",half+1.1))
	var reach: float = float(spec.get("reach",0.95))
	shapes.box(front,Vector3(x,top+0.08,wall_z+reach/2),Vector3(0.05,0.05,reach+0.1),"3a3530")
	shapes.tilted_box(front,Vector3(x,top-0.2,wall_z+0.2),Vector3(0.04,0.5,0.04),"3a3530",Vector3(0.75,0,0))
	var hung := Node3D.new()
	hung.position = Vector3(x,top,wall_z+reach*0.6)
	front.add_child(hung)
	shapes.box(hung,Vector3(0,-0.06,0),Vector3(0.03,0.12,0.03),"3a3530")
	var board: String = String(spec.get("board","2b2520"))
	var frame: String = String(spec.get("frame","8a6a3e"))
	shapes.box(hung,Vector3(0,-0.12-length/2,0),Vector3(0.08,length+0.1,0.56),frame)
	shapes.box(hung,Vector3(0,-0.12-length/2,0),Vector3(0.1,length-0.04,0.46),board)
	for face: float in [-1.0,1.0]:
		var title := Label3D.new()
		title.text = TranslationServer.translate(String(spec.get("text","")))
		title.position = Vector3(face*0.056,-0.12-length/2,0)
		title.rotation.y = face*PI/2
		title.pixel_size = float(spec.get("pixel_size",0.0072))
		title.font_size = 56
		title.width = 60.0
		title.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		title.outline_size = 0
		title.modulate = Color(String(spec.get("letters","e6c66e")))
		hung.add_child(title)
	if ambience != null:
		ambience.sway(hung,x+wall_z,0.04)

## Things on a building's walls (`wall_hangings`), each on its wall's face at `at` along it,
## moved to the nearest stretch of wall with no window and no doorway.
func hangings(body: Node3D, w: float, d: float, data: Dictionary, entrances: Array[Vector3], merge: Callable) -> void:
	var bay: int = int(data.get("bay",6))
	var face: float = skin(data)
	var household := Household.new()
	household.ambience = ambience
	# One thing to a panel: two strings asked for near each other go to neighbouring panels.
	var taken: Dictionary = {}
	for item: Dictionary in data["wall_hangings"]:
		var wall: String = String(item.get("wall","south"))
		var along_x: bool = wall in ["north","south"]
		var length: float = w if along_x else d
		var sign: float = 1.0 if wall in ["south","east"] else -1.0
		var fixed: float = (d if along_x else w)/2*sign
		var out := Vector3(0,0,sign) if along_x else Vector3(sign,0,0)
		if facing_away(body,out):
			continue
		var panels: int = ceili(length/0.5)
		var want: int = clampi(roundi((float(item.get("at",0.5))*length-0.25)/0.5),0,panels-1)
		var leaning: bool = String(item["kind"]) in ["broom","kindling"]
		var chosen: int = -1
		# First well clear of the windows; on a wall with no such room, beside them.
		for roomy: bool in [true,false]:
			for offset: int in panels:
				for i: int in [want+offset,want-offset]:
					if chosen < 0 and i >= 0 and i < panels and not taken.has("%s%d" % [wall,i]) and _clear(i,bay,leaning,roomy,along_x,fixed,-length/2+0.25+i*0.5,entrances):
						chosen = i
		if chosen < 0:
			unknown.append("%s (no room on the %s wall)" % [item["kind"],wall])
			continue
		taken["%s%d" % [wall,chosen]] = true
		placed.append("%s%d" % [wall,chosen])
		var along: float = -length/2+0.25+chosen*0.5
		var node := Node3D.new()
		node.position = (Vector3(along,0,fixed) if along_x else Vector3(fixed,0,along))+out*face+Vector3(0,float(item.get("y",0.0)),0)
		node.rotation.y = atan2(out.x,out.z)
		body.add_child(node)
		merge.call(node)
		if not _own(node,item) and not household.draw(shapes,node,item,float(item.get("width",1.0)),0.3):
			unknown.append(String(item["kind"]))

## Whether panel `i` of a wall is free for a hanging: no post, not in a doorway, and for a hung
## thing no window (`roomy`: nor a window's neighbour; a leaning thing stands below them).
func _clear(i: int, bay: int, leaning: bool, roomy: bool, along_x: bool, fixed: float, along: float, entrances: Array[Vector3]) -> bool:
	if i%bay == 0 or (not leaning and i%bay in ([1,2,3,4] if roomy else [2,3])):
		return false
	for door: Vector3 in entrances:
		if absf((door.z if along_x else door.x)-fixed) < 1.6 and absf((door.x if along_x else door.z)-along) < 2.2:
			return false
	return true

## The facade's own wall things; false for the household's kinds.
func _own(node: Node3D, item: Dictionary) -> bool:
	match String(item["kind"]):
		"broom":
			shapes.tilted_box(node,Vector3(0,0.75,0.2),Vector3(0.04,1.45,0.04),"8a6a45",Vector3(-0.14,0,0.1))
			shapes.tilted_box(node,Vector3(0.05,0.16,0.3),Vector3(0.3,0.36,0.1),"b8a468",Vector3(-0.14,0,0.1))
		"kindling":
			for stick: int in 7:
				shapes.tilted_box(node,Vector3(-0.2+stick*0.07,0.45,0.2),Vector3(0.06,0.9,0.06),["8a6a45","7a5a3e","9a7a52"][stick%3],Vector3(-0.2,0,(stick-3)*0.03))
			shapes.box(node,Vector3(0,0.5,0.24),Vector3(0.52,0.05,0.12),"b8a46c")
		"winnow":
			# 簸箕 and 筛子 hung on a nail: a round tray, its rim, the weave across it.
			shapes.box(node,Vector3(0,2.3,0.04),Vector3(0.05,0.05,0.08),"3a3530")
			shapes.box(node,Vector3(0,1.95,0.05),Vector3(0.62,0.62,0.04),"b8a068")
			shapes.box(node,Vector3(0,1.95,0.06),Vector3(0.5,0.5,0.03),"a08850")
			for line: int in 3:
				shapes.box(node,Vector3(-0.15+line*0.15,1.95,0.08),Vector3(0.02,0.5,0.01),"8a7244")
			if item.get("sieve",true):
				shapes.box(node,Vector3(0.48,1.7,0.06),Vector3(0.44,0.44,0.05),"c4ac70")
				shapes.box(node,Vector3(0.48,1.7,0.08),Vector3(0.34,0.34,0.02),"6a5a3a")
		"hat":
			for tier: int in 3:
				shapes.box(node,Vector3(0,2.0+tier*0.08,0.04),Vector3(0.62-tier*0.2,0.09,0.06),["c4ad72","b39a62","a88f5a"][tier])
		_:
			return false
	return true
