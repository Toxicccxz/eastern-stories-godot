class_name VoxelLife
extends RefCounted

## How lived in each room looks (the scene's RoomLife node, presets in
## game/data/common/room_life.json): floors worn along the ways people walk and dirty at the
## door, walls yellowed, stained, patched and smoked above fires and lamps, the room's things
## hung on its walls, what is left on its tables, chairs pushed back, litter and cobwebs in its
## corners. Presentation only: it reads the map, never changes it, and draws nothing that blocks.
const PRESETS: String = "res://data/common/room_life.json"
const HEAT: Array[String] = ["forge","tea_stove","altar","cauldron","censer","incense_burner","candles","brazier","wall_lamp"]
const TABLES: Array[String] = ["table","square_table"]
const WALKABLE_NOT: Array[String] = ["cliff","chasm","forest","boundary","wall","wall_wood","shutter","shop_front","blocked","water","deep_water"]
## Preset hanging names that are drawn by a kind of another name.
const HANGING_KINDS: Dictionary = {"talismans":{"kind":"paper_charms","size":[40,16],"count":3,"height":1.9},
	"wall_scroll":{"kind":"wall_scroll","size":[40,16]}}

var geometry: VoxelMapGeometry
## The household goods drawer (the geometry's, so pieces and hangings batch alike).
var household
var presets: Dictionary = {}
## Zone id -> {"rect", "life" (the room's spec merged with its use and wealth), "rng"}.
var rooms: Dictionary = {}
var _tables: Array[Dictionary] = []
var _heat: Array[Vector2] = []
var _blocked_props: Array[Dictionary] = []
## Wall things the voxel config already hangs (windows, signs, scrolls): kept clear of.
var _mounted: Array[Vector2] = []

## Reads the rooms' lives before the terrain is drawn: their walls' looks are added to the
## layout's own (`wall_looks`), which come first and so win where a map sets them itself.
func prepare(owner: VoxelMapGeometry, map: WorldMapController, layout: Dictionary) -> void:
	geometry = owner
	household = owner.household
	var node: Node = map.get_node_or_null("RoomLife")
	if node == null or not node.has_meta("rooms"):
		return
	presets = JSON.parse_string(FileAccess.get_file_as_string(PRESETS))
	var specs: Dictionary = node.get_meta("rooms")
	var overrides: Dictionary = layout.get("life",{})
	for zone: Node in map.find_children("*","Area2D",true,false):
		var area := zone as WorldPhysicalZoneArea2D
		if area == null or not specs.has(String(area.zone_id)):
			continue
		var spec: Dictionary = specs[String(area.zone_id)]
		var life: Dictionary = (presets["uses"][spec["use"]] as Dictionary).duplicate(true)
		life.merge(spec,true)
		life.merge(overrides.get(String(area.zone_id),{}),true)
		var wealth: Dictionary = presets["wealth"][String(life.get("wealth","plain"))]
		var tidy: Dictionary = presets["tidy"] if life.get("tidy",false) else {}
		life["grime"] = clampf((float(life.get("grime",0.4))+float(wealth["grime"]))*float(tidy.get("grime",1.0)),0.0,1.0)
		life["cobwebs"] = float(wealth["cobwebs"])*float(tidy.get("cobwebs",1.0))
		life["patches"] = float(wealth["patches"])*float(tidy.get("patches",1.0))
		life["spread"] = float(life.get("spread",0.0))*float(wealth["scatter"])*float(tidy.get("scatter",1.0))
		var random := RandomNumberGenerator.new()
		random.seed = hash(String(area.zone_id)+":"+str(life.get("seed",0)))
		rooms[area.zone_id] = {"rect":area.global_rect(),"life":life,"rng":random}
		var look: Dictionary = _wall_look(life,random)
		if not look.is_empty():
			# The room's own walls, from its outer edge (a fills map's zone is its floor only).
			var r: Rect2 = area.global_rect().grow(32)
			look["rect"] = [r.position.x,r.position.y,r.end.x,r.end.y]
			geometry.wall_looks.append(look)
	for prop: Dictionary in layout.get("props",[]):
		if prop.get("wall_mounted",false) or prop.get("kind","") in ["window","wall_scroll","sign","curtain","closed_door","red_door","silk_curtain"]:
			_mounted.append(Vector2(prop["at"][0],prop["at"][1]))
		if prop.get("kind","") in HEAT or prop.get("kind","")=="hanging_lantern":
			_heat.append(Vector2(prop["at"][0],prop["at"][1]))

## The look of a room's walls by its use (`walls`): plaster in the map's own wall colour, shaded a
## little per room so repeated rooms differ; boards, 青砖 or rammed earth.
func _wall_look(life: Dictionary, random: RandomNumberGenerator) -> Dictionary:
	var base := Color(String(geometry.palette.get("wall","c9b997")))
	match String(life.get("walls","plaster")):
		"boards":
			var wood: Array = geometry.palette.get("wood",["9f7953","a37e57","a7815b"])
			var tones: Array = []
			for hex: String in wood:
				tones.append(Color(hex).darkened(0.18+random.randf()*0.08).to_html(false))
			return {"style":"boards","colors":tones,"grime":life["grime"]}
		"brick":
			return {"style":"brick","colors":["6f716a","7b7c73","646660","85857a"],"mortar":"9a9888","grime":life["grime"]}
		"earth":
			return {"style":"earth","colors":["8d7a5c","98856a","806e53","a08c6c"]}
		_:
			var shade: float = random.randf_range(-0.06,0.06)
			var wall: Color = base.darkened(shade) if shade>0 else base.lightened(-shade)
			# Old plaster yellows (grime) toward a warm grey.
			wall = wall.lerp(Color("a89a7c"),float(life["grime"])*0.25)
			return {"style":"plaster","wall":wall.to_html(false),"grime":life["grime"]}

## A furnishing about to be drawn: a table gets what is left on it, a chair is pushed a little
## out of line (not in a room its text keeps neat).
func dress(data: Dictionary) -> void:
	var at := Vector2(data["at"][0],data["at"][1])
	var room: Dictionary = _room_at(at)
	if data.get("kind","") in HEAT:
		_heat.append(at)
	_blocked_props.append(data)
	if room.is_empty():
		return
	var life: Dictionary = room["life"]
	var random: RandomNumberGenerator = room["rng"]
	var messy: bool = not life.get("tidy",false) and life.get("wealth","plain")!="rich"
	if data["kind"] in TABLES and not data.has("set") and not (life.get("tables",[]) as Array).is_empty():
		var sets: Array = life["tables"]
		data["set"] = String(sets[random.randi_range(0,sets.size()-1)])
		_tables.append(data)
		if messy and data["kind"]=="table":
			data["askew"] = random.randi_range(1,999)
	elif data["kind"]=="chair" and messy:
		data["rotation"] = float(data.get("rotation",0))+random.randf_range(-9.0,9.0)

## Everything else, once the terrain and furnishings are drawn: `cells` is the map's ground.
func finish(map: WorldMapController, cells: Dictionary[Vector2i,String]) -> void:
	if rooms.is_empty():
		return
	for table: Dictionary in _tables:
		_table_items(table)
	var markers: Array[Vector2] = []
	for node: Node in map.find_children("*","Marker2D",true,false):
		if node is WorldSpawnMarker2D:
			markers.append((node as Node2D).global_position)
	var doors: Array[Vector2] = []
	for node: Node in map.find_children("*","Area2D",true,false):
		if node is WorldPassageArea2D:
			doors.append((node as Node2D).global_position)
	for zone_id: StringName in rooms:
		var room: Dictionary = rooms[zone_id]
		var floor: Dictionary[Vector2i,bool] = {}
		for cell: Vector2i in cells:
			if (room["rect"] as Rect2).has_point(Vector2(cell)) and not cells[cell] in WALKABLE_NOT:
				floor[cell] = true
		if floor.is_empty():
			continue
		var worn: Dictionary[Vector2i,float] = _wear(room,floor,doors,markers)
		_floor(room,floor,cells,worn,doors)
		# Hung lamps smoke the wall above them too: hang first.
		_hangings(room,floor,cells,doors)
		_walls(room,floor,cells)

func _room_at(at: Vector2) -> Dictionary:
	for zone_id: StringName in rooms:
		if (rooms[zone_id]["rect"] as Rect2).grow(16).has_point(at):
			return rooms[zone_id]
	return {}

func _table_items(data: Dictionary) -> void:
	var a: Array = data["at"]
	var at: Vector3 = VoxelMapGeometry.point(Vector2(a[0],a[1]))
	var node: Node3D = geometry._node(at)
	node.rotation.y = deg_to_rad(float(data.get("rotation",0)))
	geometry.shapes.merge(node,geometry._static_chunk(at))
	var size: Array = data.get("size",[64,32])
	var top: float = 1.0 if data["kind"]=="table" else 0.945
	household.table_set(geometry.shapes,node,top,float(size[0])/32.0*0.8,float(size[1])/32.0*0.7,String(data["set"]),hash(a))

## How worn each floor cell is, 0..1: the shortest walks from each way in to each place people
## stand (markers, counters' fronts, tables), spread a little either side.
func _wear(room: Dictionary, floor: Dictionary[Vector2i,bool], doors: Array[Vector2], markers: Array[Vector2]) -> Dictionary[Vector2i,float]:
	var rect: Rect2 = (room["rect"] as Rect2).grow(16)
	var starts: Array[Vector2i] = []
	for door: Vector2 in doors:
		if rect.has_point(door):
			starts.append(_nearest(floor,door))
	var goals: Array[Vector2i] = []
	for marker: Vector2 in markers:
		if rect.has_point(marker):
			goals.append(_nearest(floor,marker))
	for data: Dictionary in _blocked_props:
		var at := Vector2(data["at"][0],data["at"][1])
		if rect.has_point(at) and data["kind"] in ["counter","shop_counter","table","square_table","altar","forge","anvil"]:
			var front := Vector2(0,float(data["size"][1])/2.0+24).rotated(-deg_to_rad(float(data.get("rotation",0))))
			goals.append(_nearest(floor,at+front))
	var visits: Dictionary[Vector2i,float] = {}
	for start: Vector2i in starts:
		var from: Dictionary[Vector2i,Vector2i] = _paths(floor,start)
		for goal: Vector2i in goals:
			var cell: Vector2i = goal
			var guard: int = 0
			while from.has(cell) and cell!=start and guard<400:
				visits[cell] = visits.get(cell,0.0)+1.0
				cell = from[cell]
				guard += 1
	var worn: Dictionary[Vector2i,float] = {}
	var peak: float = 0.0
	for cell: Vector2i in visits:
		peak = maxf(peak,visits[cell])
	if peak<=0.0:
		return worn
	for cell: Vector2i in visits:
		var strength: float = 0.55+0.45*visits[cell]/peak
		for dy: int in range(-2,3):
			for dx: int in range(-2,3):
				var near := cell+Vector2i(dx,dy)*16
				if floor.has(near):
					var fall: float = strength*maxf(0.0,1.0-Vector2(dx,dy).length()/2.6)
					worn[near] = maxf(worn.get(near,0.0),fall)
	return worn

func _nearest(floor: Dictionary[Vector2i,bool], at: Vector2) -> Vector2i:
	var best: Vector2i = floor.keys()[0]
	var best_d: float = INF
	for cell: Vector2i in floor:
		var d: float = Vector2(cell).distance_squared_to(at)
		if d<best_d:
			best_d = d
			best = cell
	return best

## Breadth-first over the open floor: each cell's step back toward `start`.
func _paths(floor: Dictionary[Vector2i,bool], start: Vector2i) -> Dictionary[Vector2i,Vector2i]:
	var from: Dictionary[Vector2i,Vector2i] = {start:start}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head<queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for step: Vector2i in [Vector2i(16,0),Vector2i(-16,0),Vector2i(0,16),Vector2i(0,-16)]:
			var next: Vector2i = cell+step
			if floor.has(next) and not from.has(next):
				from[next] = cell
				queue.append(next)
	return from

## Polished where feet go, dark with dust along the walls and in corners, mud and footprints at
## the doors, litter where nobody sweeps.
func _floor(room: Dictionary, floor: Dictionary[Vector2i,bool], cells: Dictionary[Vector2i,String], worn: Dictionary[Vector2i,float], doors: Array[Vector2]) -> void:
	var life: Dictionary = room["life"]
	var random: RandomNumberGenerator = room["rng"]
	var grime: float = float(life["grime"])
	var shapes = geometry.shapes
	for cell: Vector2i in floor:
		var p: Vector3 = VoxelMapGeometry.point(Vector2(cell))
		var wood: bool = cells[cell] in ["floor_wood","floor_shop"]
		var base := Color(_floor_tone(cells[cell]))
		var wear: float = worn.get(cell,0.0)
		if wear>0.2:
			# Feet polish a path paler and smoother; greasy in its middle where the traffic is.
			var tone: Color = base.lightened(0.10*wear) if wood else base.lightened(0.07*wear)
			if wear>0.8 and grime>0.4:
				tone = base.darkened(0.05)
			shapes.tilted_box(geometry,p+Vector3(random.randf_range(-0.04,0.04),0.003,random.randf_range(-0.04,0.04)),Vector3(0.5,0.008,0.46*random.randf_range(0.7,1.0)),tone.to_html(false),Vector3(0,random.randf_range(-0.08,0.08),0))
		var edge: int = _wall_side_count(floor,cell)
		if edge>0 and random.randf()<grime*0.75:
			# Dust gathers against walls and furniture, thickest in corners.
			var dust: Color = base.darkened(0.05+0.05*edge*grime)
			shapes.tilted_box(geometry,p+Vector3(random.randf_range(-0.08,0.08),0.004,random.randf_range(-0.08,0.08)),Vector3(random.randf_range(0.3,0.52),0.008,random.randf_range(0.25,0.5)),dust.to_html(false),Vector3(0,random.randf()*TAU,0))
		if wear<0.3 and random.randf()<float(life["spread"]) and not (life.get("scatter",[]) as Array).is_empty():
			var kinds: Array = life["scatter"]
			var kind: String = String(kinds[random.randi_range(0,kinds.size()-1)])
			if kind=="dust":
				# Grey fluff in the floor's own colour, a shade darker.
				shapes.tilted_box(geometry,p+Vector3(0,0.005,0),Vector3(random.randf_range(0.18,0.32),0.008,random.randf_range(0.14,0.26)),base.darkened(0.12).lerp(Color("8a8478"),0.25).to_html(false),Vector3(0,random.randf()*TAU,0))
			else:
				household.scatter(shapes,geometry,p,kind,random.randi())
		elif wear<0.3 and random.randf()<grime*0.04:
			# A stain where something was spilt.
			shapes.tilted_box(geometry,p+Vector3(0,0.005,0),Vector3(random.randf_range(0.2,0.45),0.008,random.randf_range(0.15,0.35)),base.darkened(0.2).to_html(false),Vector3(0,random.randf()*TAU,0))
	# At each way in: trodden earth and footprints a few steps into the room.
	for door: Vector2 in doors:
		if not (room["rect"] as Rect2).grow(16).has_point(door):
			continue
		var inward: Vector2 = ((room["rect"] as Rect2).get_center()-door).normalized()
		var mud := Color(_floor_tone("floor_wood")).darkened(0.35).lerp(Color("6e5a40"),0.5)
		for i: int in int(4+grime*8):
			var at: Vector2 = door+inward*random.randf_range(8,64)+inward.orthogonal()*random.randf_range(-24,24)
			var cell := Vector2i(floori(at.x/16)*16+8,floori(at.y/16)*16+8)
			if not floor.has(cell):
				continue
			shapes.tilted_box(geometry,VoxelMapGeometry.point(at,0.006),Vector3(random.randf_range(0.12,0.3),0.008,random.randf_range(0.1,0.22)),mud.to_html(false),Vector3(0,random.randf()*TAU,0))
		for step: int in 3+int(grime*3):
			var at: Vector2 = door+inward*(20+step*14)+inward.orthogonal()*(5 if step%2 else -5)
			if floor.has(Vector2i(floori(at.x/16)*16+8,floori(at.y/16)*16+8)):
				shapes.tilted_box(geometry,VoxelMapGeometry.point(at,0.008),Vector3(0.09,0.006,0.17),mud.darkened(0.1).to_html(false),Vector3(0,atan2(inward.x,inward.y),0))
	# Cobwebs high in the back corners (against the north wall, which every view shows whole) of
	# a poor or forgotten room.
	for corner: Vector2i in floor:
		var walled := func(step: Vector2i) -> bool: return cells.get(corner+step,"") in ["wall","wall_wood"]
		if walled.call(Vector2i(0,-16)) and (walled.call(Vector2i(-16,0)) or walled.call(Vector2i(16,0))) and random.randf()<float(life["cobwebs"])*2.0:
			var into := Vector2(0,0)
			for step: Vector2i in [Vector2i(16,0),Vector2i(-16,0),Vector2i(0,16),Vector2i(0,-16)]:
				if floor.has(corner+step):
					into += Vector2(step)
			var yaw: float = rad_to_deg(atan2(into.x,into.y))+90
			geometry._prop({"kind":"cobweb","at":[corner.x,corner.y],"size":[44,44],"rotation":yaw,"height":random.randf_range(2.5,2.95)})

func _floor_tone(kind: String) -> String:
	if geometry.surfaces.values().has(kind) or kind in ["rock","floor_yard","town_ground"]:
		return "a39f8c"
	var wood: Array = geometry.palette.get("wood",["9f7953"])
	return String(wood[0])

func _wall_side_count(floor: Dictionary[Vector2i,bool], cell: Vector2i) -> int:
	var count: int = 0
	for step: Vector2i in [Vector2i(16,0),Vector2i(-16,0),Vector2i(0,16),Vector2i(0,-16)]:
		if not floor.has(cell+step):
			count += 1
	return count

## A wall cell's face toward the room: its node (by which views show it high) and outward normal.
func _faces(floor: Dictionary[Vector2i,bool], cells: Dictionary[Vector2i,String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cell: Vector2i in floor:
		for step: Vector2i in [Vector2i(0,-16),Vector2i(-16,0),Vector2i(16,0),Vector2i(0,16)]:
			var wall: Vector2i = cell+step
			if not cells.get(wall,"") in ["wall","wall_wood"]:
				continue
			var pos := Vector2(wall)
			var right_low: bool = geometry.low_wall(pos)
			var left_low: bool = geometry.low_wall(pos,true)
			if right_low and left_low:
				continue
			var parent: Node3D = geometry._walls
			if right_low:
				parent = geometry._side_high_walls[1]
			elif left_low:
				parent = geometry._side_high_walls[0]
			out.append({"wall":wall,"into":-Vector2(step)/16.0,"parent":parent,"face":Vector2(wall)+Vector2(-step)/2.0})
	return out

## Yellowing and scuffs low down, water stains from the eaves, patched and cracked plaster, and
## soot above every fire and lamp.
func _walls(room: Dictionary, floor: Dictionary[Vector2i,bool], cells: Dictionary[Vector2i,String]) -> void:
	var life: Dictionary = room["life"]
	var random: RandomNumberGenerator = room["rng"]
	var grime: float = float(life["grime"])
	var shapes = geometry.shapes
	var wall_color := Color(_room_wall(room))
	for face: Dictionary in _faces(floor,cells):
		var into: Vector2 = face["into"]
		var parent: Node3D = face["parent"]
		var at: Vector3 = VoxelMapGeometry.point(face["face"])+Vector3(into.x,0,into.y)*0.012
		var flat := Vector3(0.5,0,0.012) if absf(into.y)>0.5 else Vector3(0.012,0,0.5)
		var along: Vector3 = Vector3(1,0,0) if absf(into.y)>0.5 else Vector3(0,0,1)
		# Scuffed and darkened at the foot, where brooms and boots reach.
		if random.randf()<0.5+grime*0.5:
			var h: float = random.randf_range(0.15,0.35+grime*0.35)
			shapes.box(parent,at+Vector3(0,0.3+h/2,0),flat+Vector3(0,h,0),wall_color.darkened(0.12+grime*0.12).to_html(false))
		if random.randf()<grime*0.22:
			# A water stain down from the top.
			var long: float = random.randf_range(0.4,1.4)
			var width: float = random.randf_range(0.12,0.4)
			shapes.box(parent,at+along*random.randf_range(-0.1,0.1)+Vector3(0,2.88-long/2,0),Vector3(width if along.x>0 else 0.014,long,width if along.z>0 else 0.014),wall_color.darkened(0.16).lerp(Color("8a7a58"),0.3).to_html(false))
		if random.randf()<float(life["patches"])*0.12:
			# A patch of newer plaster, paler than the old.
			var size := Vector2(random.randf_range(0.2,0.45),random.randf_range(0.2,0.4))
			shapes.box(parent,at+Vector3(0,random.randf_range(1.3,2.4),0)+Vector3(into.x,0,into.y)*0.004,Vector3(size.x if along.x>0 else 0.016,size.y,size.x if along.z>0 else 0.016),wall_color.lightened(0.1).to_html(false))
		if random.randf()<grime*0.08:
			shapes.tilted_box(parent,at+Vector3(0,random.randf_range(1.4,2.6),0),Vector3(0.02 if along.x==0 else random.randf_range(0.3,0.6),0.02,0.02 if along.z==0 else random.randf_range(0.3,0.6)),wall_color.darkened(0.35).to_html(false),Vector3(random.randf_range(-0.6,0.6) if along.z>0 else 0.0,0,random.randf_range(-0.6,0.6) if along.x>0 else 0.0))
		# Soot: darker the nearer a fire or lamp below, rising up the wall.
		for heat: Vector2 in _heat:
			var gap: float = (face["face"] as Vector2).distance_to(heat)
			if gap<56:
				var strength: float = 1.0-gap/56.0
				for band: int in 4:
					var y: float = 1.4+band*0.4
					shapes.box(parent,at+Vector3(into.x,0,into.y)*(0.003*band)+Vector3(0,y+0.2,0),flat+Vector3(0,0.4,0),wall_color.darkened(0.25+0.45*strength*(0.5+band*0.15)).to_html(false))

func _room_wall(room: Dictionary) -> String:
	var r: Rect2 = (room["rect"] as Rect2)
	for look: Dictionary in geometry.wall_looks:
		var a: Array = look["rect"]
		if Rect2(a[0],a[1],a[2]-a[0],a[3]-a[1]).encloses(r):
			if look.has("wall"):
				return String(look["wall"])
			return String(look.get("colors",["8a7a5c"])[0])
	return String(geometry.palette.get("wall","c9b997"))

## The room's things hung along its walls where nothing stands before them: no window, sign or
## scroll, no door, nothing tall in front.
func _hangings(room: Dictionary, floor: Dictionary[Vector2i,bool], cells: Dictionary[Vector2i,String], doors: Array[Vector2]) -> void:
	var life: Dictionary = room["life"]
	var kinds: Array = life.get("hangings",[])
	if kinds.is_empty() or float(life.get("hang",0.0))<=0.0:
		return
	var random: RandomNumberGenerator = room["rng"]
	var faces: Array[Dictionary] = _faces(floor,cells).filter(func(f: Dictionary) -> bool: return (f["into"] as Vector2).y>=0.0)
	faces.shuffle()
	var placed: Array[Vector2] = _mounted.duplicate()
	var wanted: int = maxi(1,roundi(faces.size()*0.5*float(life["hang"])))
	var index: int = random.randi_range(0,kinds.size()-1)
	for face: Dictionary in faces:
		if wanted<=0:
			break
		var at: Vector2 = face["face"]
		if placed.any(func(p: Vector2) -> bool: return p.distance_to(at)<44):
			continue
		if doors.any(func(p: Vector2) -> bool: return p.distance_to(at)<56):
			continue
		var blocked: bool = false
		for data: Dictionary in _blocked_props:
			var centre := Vector2(data["at"][0],data["at"][1])
			var size: Array = data.get("size",[32,32])
			var reach: float = maxf(float(size[0]),float(size[1]))/2.0+20
			if centre.distance_to(at)<reach and (data.get("occludes",false) or data["kind"] in ["shelf","bookcase","herb_cabinet","wardrobe","clothes_rack","weapon_rack","forge","altar"]):
				blocked = true
		if blocked:
			continue
		var name: String = String(kinds[index%kinds.size()])
		index += 1
		var prop: Dictionary = {"kind":name.get_slice(":",0),"size":[48,16],"wall_mounted":true,"seed":random.randi_range(1,999)}
		if HANGING_KINDS.has(prop["kind"]):
			prop.merge(HANGING_KINDS[prop["kind"]],true)
		var variant: String = name.get_slice(":",1) if name.contains(":") else ""
		match prop["kind"]:
			"string_hang": prop["goods"] = variant
			"tool_hooks": prop["tools"] = variant
			"wall_scroll":
				if variant=="calligraphy":
					prop["calligraphy"] = true
		var into: Vector2 = face["into"]
		prop["at"] = [at.x,at.y]
		prop["rotation"] = rad_to_deg(atan2(into.x,into.y))
		geometry._prop(prop)
		if prop["kind"]=="wall_lamp":
			_heat.append(at)
		placed.append(at)
		wanted -= 1
