class_name VoxelLife
extends RefCounted

## How lived in each room looks (the scene's RoomLife node, presets in
## game/data/common/room_life.json): floors worn along the ways people walk and dirty at the
## door, walls yellowed, stained, patched and smoked above fires and lamps, the room's things
## hung on its walls, what is left on its tables, chairs pushed back, litter and cobwebs in its
## corners. Presentation only: it reads the map, never changes it, and draws nothing that blocks.
const PRESETS: String = "res://data/common/room_life.json"
const HEAT: Array[String] = ["forge","tea_stove","altar","cauldron","censer","incense_burner","candles","brazier","wall_lamp","hearth"]
const TABLES: Array[String] = ["table","square_table"]
const WALKABLE_NOT: Array[String] = ["cliff","chasm","forest","boundary","wall","wall_wood","shutter","shop_front","blocked","water","deep_water"]
## Preset hanging names that are drawn by a kind of another name.
const HANGING_KINDS: Dictionary = {"talismans":{"kind":"paper_charms","size":[40,16],"count":3,"height":1.9},
	"wall_scroll":{"kind":"wall_scroll","size":[40,16]},
	"cobweb":{"kind":"cobweb","size":[40,40],"height":2.55}}
## The small movements a room's use calls for (preset `ambience`: [{"kind", "anchor", "count",
## "color", "max"}]), each hung on the room's own things where it has them: moths at its lamps,
## smoke or steam at a stove, incense at a censer, sparks at a forge, a sunbeam of dust from a
## window by day, flies over a butcher's block; dust in the middle of a room that has none.
const AMBIENCE_KINDS: Array[String] = ["moths","smoke","steam","incense","sparks","sunbeam","dust","flies"]
## What each ambience kind hangs on, by prop kind.
const ANCHORS: Dictionary = {
	"lamp": ["hanging_lantern","wall_lamp","lamp_stand","candles","lantern","lantern_post","oil_lamp"],
	"stove": ["hearth","tea_stove","cauldron","brazier","campfire","pill_furnace","forge"],
	"censer": ["censer","incense_burner","altar","altar_table"],
	"forge": ["forge"],
	"window": ["window"],
	"block": ["chopping_block","meat_rack","meat_hooks"]}
const ANCHOR_OF: Dictionary = {"moths":"lamp","smoke":"stove","steam":"stove","incense":"censer","sparks":"forge","sunbeam":"window","flies":"block"}
## How high each lamp kind holds its flame (units): its moths keep just under it.
const LAMP_HEIGHT: Dictionary = {"hanging_lantern":3.0,"wall_lamp":2.1,"lamp_stand":1.7,"candles":1.1,"lantern":1.6,"lantern_post":2.6,"oil_lamp":1.1}
## Props that smoke of themselves (their own `ambience.smoke`): no second plume over them.
const SELF_SMOKING: Array[String] = ["hearth","tea_stove","cauldron","brazier","campfire","censer","incense_burner","pill_furnace"]
## A plume's colour, puff count, puff size and height off the floor, by kind.
const PLUMES: Dictionary = {"smoke":["8d877c",5,0.26,1.2],"steam":["eeece6",4,0.18,1.1],"incense":["d8d2c4",4,0.1,1.0]}
## A loose haze's colour where a plume has nothing to rise from.
const HAZE: Dictionary = {"smoke":"9a958c","steam":"e8e6e0","incense":"d8d2c4","sparks":"b8b0a0"}

var geometry: VoxelMapGeometry
## The household goods drawer (the geometry's, so pieces and hangings batch alike).
var household
var presets: Dictionary = {}
## Zone id -> {"rect", "life" (the room's spec merged with its use and wealth), "rng"}.
var rooms: Dictionary = {}
var _tables: Array[Dictionary] = []
## What each room got, for the tests: zone id -> floor cells worn by feet, things hung on its walls.
var worn_cells: Dictionary[StringName,int] = {}
var hung: Dictionary[StringName,int] = {}
var _heat: Array[Vector2] = []
var _blocked_props: Array[Dictionary] = []
## Wall things the voxel config already hangs (windows, signs, scrolls): kept clear of.
var _mounted: Array[Vector2] = []
var _outer_looks: Array[Dictionary] = []
## The room things an ambience can hang on: {"kind", "at" (px), "into" (a wall thing's way into
## the room, else ZERO), "elevation"}.
var _anchors: Array[Dictionary] = []
## What each room's use set moving, for the tests: zone id -> how many (its own things that
## smoke count, a preset adds nothing over them).
var ambience_made: Dictionary[StringName,int] = {}

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
			var r: Rect2 = area.global_rect()
			look["rect"] = [r.position.x,r.position.y,r.end.x,r.end.y]
			geometry.wall_looks.append(look)
			# A fills map's zone is its floor only: its walls just outside, after every room's own
			# (the first look that holds a wall wins, so no room paints its neighbour's walls).
			var outer: Dictionary = look.duplicate()
			r = r.grow(32)
			outer["rect"] = [r.position.x,r.position.y,r.end.x,r.end.y]
			_outer_looks.append(outer)
	geometry.wall_looks.append_array(_outer_looks)
	for prop: Dictionary in layout.get("props",[]):
		if prop.get("wall_mounted",false) or prop.get("kind","") in ["window","wall_scroll","sign","curtain","closed_door","red_door","silk_curtain"]:
			_mounted.append(Vector2(prop["at"][0],prop["at"][1]))
		if prop.get("kind","") in HEAT or prop.get("kind","")=="hanging_lantern":
			_heat.append(Vector2(prop["at"][0],prop["at"][1]))
		_anchor(prop)

## Remembers a prop an ambience can hang on (a lamp, a stove, a window).
func _anchor(data: Dictionary) -> void:
	var kind: String = String(data.get("kind",""))
	if not data.has("at"):
		return
	for group: String in ANCHORS:
		if kind in ANCHORS[group]:
			var into := Vector2.ZERO
			if data.get("wall_mounted",false) or kind=="window":
				into = Vector2(0,1).rotated(-deg_to_rad(float(data.get("rotation",0))))
			_anchors.append({"kind":kind,"at":Vector2(data["at"][0],data["at"][1]),"into":into,"elevation":float(data.get("elevation",0.0))})
			return

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
		"cloth":
			# A tent (camp3.c: 粗略的布料; camp5.c: 布料倒是比小兵营帐好多了): coarse cloth, a shade
			# of its own per tent, darker the dirtier.
			var tones: Array = []
			for hex: String in life.get("cloth_colors",["8a7a5c","948466","7e6e52","a09070"]):
				tones.append(Color(hex).darkened(float(life["grime"])*0.2+random.randf()*0.06).to_html(false))
			return {"style":"cloth","colors":tones,"grime":life["grime"]}
		"iron_bars":
			return {"style":"iron_bars","colors":["3a3835","46423e","2e2c2a"]}
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
	_anchor(data)
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
		var worn: Dictionary[Vector2i,float] = _wear(room,floor,cells,doors,markers)
		worn_cells[zone_id] = worn.size()
		_floor(room,floor,cells,worn,doors)
		# Hung lamps smoke the wall above them too: hang first.
		hung[zone_id] = _hangings(room,floor,cells,doors)
		_walls(room,floor,cells)
		_ambience(zone_id,room)

## The room's small movements, from its use's `ambience` (overridable per room: `"ambience": []`
## stills it), hung on its own anchors; the same every build (seeded by the room).
func _ambience(zone_id: StringName, room: Dictionary) -> void:
	var rect: Rect2 = room["rect"]
	var within: Array[Dictionary] = []
	for anchor: Dictionary in _anchors:
		if rect.grow(16).has_point(anchor["at"]):
			within.append(anchor)
	var planned: Dictionary = plan_ambience(room["life"].get("ambience",[]),rect,within,hash(String(zone_id)+":ambience"))
	ambience_made[zone_id] = int(planned["made"])
	planned.erase("made")
	geometry.ambience.add(planned)

## What a room's ambience spec becomes, as VoxelAmbience data (`dust`, `fall`, `smoke`) plus
## `made`, how many movements the room has (its self-smoking props counted). Pure: the same
## spec, rect, anchors and seed give the same plan.
static func plan_ambience(spec: Array, rect: Rect2, anchors: Array[Dictionary], seed: int) -> Dictionary:
	var out: Dictionary = {"dust":[],"fall":[],"smoke":[],"made":0}
	var random := RandomNumberGenerator.new()
	random.seed = seed
	var centre: Vector2 = rect.get_center()
	var middle: Rect2 = rect.grow(-minf(24.0,rect.size.x*0.25))
	var band: Array = [middle.position.x,middle.position.y,middle.end.x,middle.end.y]
	for entry: Dictionary in spec:
		var kind: String = String(entry.get("kind","dust"))
		var count: int = int(entry.get("count",0))
		var limit: int = int(entry.get("max",3))
		var found: Array[Dictionary] = []
		var group: String = String(entry.get("anchor",ANCHOR_OF.get(kind,"")))
		if not group.is_empty():
			for anchor: Dictionary in anchors:
				if String(anchor["kind"]) in ANCHORS.get(group,[]):
					found.append(anchor)
		# The nearest to the room's middle first, so a long room's far lamps are the ones left out.
		found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["at"] as Vector2).distance_squared_to(centre)<(b["at"] as Vector2).distance_squared_to(centre))
		var used: int = 0
		for anchor: Dictionary in found:
			if used>=limit:
				break
			var at: Vector2 = anchor["at"]+(anchor["into"] as Vector2)*18.0
			var head: String = String(anchor["kind"])
			match kind:
				"moths":
					var top: float = float(LAMP_HEIGHT.get(head,2.0))+float(anchor["elevation"])
					out["dust"].append({"rect":[at.x-26,at.y-26,at.x+26,at.y+26],"count":count if count>0 else 2+random.randi_range(0,1),"color":String(entry.get("color","e8dcc0")),
						"size":[0.05,0.03,0.05],"height":[top-0.55,top+0.05],"wind":[0.6,0.5],"flit":1.0})
				"smoke","steam","incense":
					if head in SELF_SMOKING:
						# Its own plume already rises; the room is not still.
						out["made"] += 1
						used += 1
						continue
					var look: Array = PLUMES[kind]
					if LAMP_HEIGHT.has(head):
						# An oil lamp's thread of soot from just over its flame.
						look = ["6a665e",3,0.08,float(LAMP_HEIGHT[head])+0.1]
					out["smoke"].append({"at":[at.x,at.y],"height":float(look[3])+float(anchor["elevation"]),"color":String(entry.get("color",look[0])),"count":count if count>0 else int(look[1]),"size":float(look[2])})
				"sparks":
					out["fall"].append({"rect":[at.x-22,at.y-22,at.x+22,at.y+22],"count":count if count>0 else 10,"up":true,"glow":true,"colors":["ffd890","ff9a40","ff6a2a"],"height":1.9,"wind":[0.2,0.1]})
				"sunbeam":
					# From the window into the room, the way its sill faces; the beam's far end a
					# few steps in.
					var into: Vector2 = anchor["into"]
					if into == Vector2.ZERO:
						into = (centre-anchor["at"]).normalized()
					var inner: Vector2 = anchor["at"]+into*12.0
					var far: Vector2 = anchor["at"]+into*88.0
					var across: Vector2 = (into.orthogonal()*28.0).abs()
					var lo: Vector2 = Vector2(minf(inner.x,far.x),minf(inner.y,far.y))-across
					var hi: Vector2 = Vector2(maxf(inner.x,far.x),maxf(inner.y,far.y))+across
					out["dust"].append({"rect":[lo.x,lo.y,hi.x,hi.y],"count":count if count>0 else 9,"color":String(entry.get("color","f0e6c8")),"size":[0.05,0.04,0.05],"height":[0.4,2.2],
						"wind":[0.12,0.08],"day":true,"beam":true,"beam_from":[anchor["at"].x,anchor["at"].y]})
				"flies":
					out["dust"].append({"rect":[at.x-30,at.y-30,at.x+30,at.y+30],"count":count if count>0 else 5,"color":"3a342c","size":[0.04,0.03,0.04],"height":[0.9,1.6],"wind":[0.8,0.7],"flit":1.4})
				_:
					break
			out["made"] += 1
			used += 1
		if used>0:
			continue
		# Nothing of that kind to hang on: the same movement, loose in the room's middle band.
		match kind:
			"moths":
				out["dust"].append({"rect":band,"count":count if count>0 else 6,"color":String(entry.get("color","d8ccb0")),"size":[0.05,0.04,0.05],"height":[0.9,2.1],"wind":[0.5,0.4],"flit":0.6})
			"smoke","steam","incense","sparks":
				out["dust"].append({"rect":band,"count":count if count>0 else 6,"color":String(entry.get("color",HAZE[kind])),"size":[0.09,0.06,0.09],"height":[1.1,2.5],"wind":[0.3,0.2]})
			"sunbeam":
				out["dust"].append({"rect":band,"count":count if count>0 else 8,"color":String(entry.get("color","f0e6c8")),"size":[0.05,0.04,0.05],"height":[0.5,2.2],"wind":[0.12,0.08],"day":true})
			"flies":
				out["dust"].append({"rect":band,"count":count if count>0 else 5,"color":"3a342c","size":[0.04,0.03,0.04],"height":[0.9,1.6],"wind":[0.8,0.7],"flit":1.4})
			_:
				out["dust"].append({"rect":band,"count":count if count>0 else 10,"color":String(entry.get("color","c8bc9c")),"size":entry.get("size",[0.06,0.05,0.06]),"height":entry.get("height",[0.3,1.8]),"wind":entry.get("wind",[0.3,0.2])})
		out["made"] += 1
	return out

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
	# A square table draws its own tea, wine or incense (VoxelMapGeometry's furniture).
	if data["kind"]=="square_table" and data["set"] in ["tea","wine","incense"]:
		return
	var top: float = 1.0 if data["kind"]=="table" else 0.945
	household.table_set(geometry.shapes,node,top,float(size[0])/32.0*0.8,float(size[1])/32.0*0.7,String(data["set"]),hash(a))

## How worn each floor cell is, 0..1: the shortest walks from each way in (a passage, a door,
## an open doorway to the next room) to each place people stand (markers, counters' fronts,
## tables), spread a little either side.
func _wear(room: Dictionary, floor: Dictionary[Vector2i,bool], cells: Dictionary[Vector2i,String], doors: Array[Vector2], markers: Array[Vector2]) -> Dictionary[Vector2i,float]:
	var rect: Rect2 = (room["rect"] as Rect2).grow(16)
	var starts: Array[Vector2i] = []
	for door: Vector2 in doors:
		if rect.has_point(door):
			starts.append(_nearest(floor,door))
	starts.append_array(_openings(room,floor,cells))
	var goals: Array[Vector2i] = []
	for marker: Vector2 in markers:
		if rect.has_point(marker):
			goals.append(_nearest(floor,marker))
	for data: Dictionary in _blocked_props:
		var at := Vector2(data["at"][0],data["at"][1])
		if rect.has_point(at) and data["kind"] in ["counter","shop_counter","table","square_table","altar","forge","anvil"]:
			var front := Vector2(0,float(data["size"][1])/2.0+24).rotated(-deg_to_rad(float(data.get("rotation",0))))
			goals.append(_nearest(floor,at+front))
	# A room where nobody stands and nothing is served (a bare 石室): people walk in to its middle.
	if goals.is_empty() and not starts.is_empty():
		goals.append(_nearest(floor,(room["rect"] as Rect2).get_center()))
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

## The room's open doorways: floor at its edge that goes on as floor beyond the room (the gap
## in the wall to the next room, a hall's way into its side rooms), one cell per gap.
func _openings(room: Dictionary, floor: Dictionary[Vector2i,bool], cells: Dictionary[Vector2i,String]) -> Array[Vector2i]:
	var rect: Rect2 = room["rect"]
	var gaps: Array[Vector2i] = []
	for cell: Vector2i in floor:
		for step: Vector2i in [Vector2i(16,0),Vector2i(-16,0),Vector2i(0,16),Vector2i(0,-16)]:
			var beyond: Vector2i = cell+step*2
			if not rect.has_point(Vector2(beyond)) and cells.has(beyond) and not cells[beyond] in WALKABLE_NOT and not floor.has(beyond):
				gaps.append(cell)
				break
	# One way in per gap: cells of the same gap lie within a doorway's width of each other.
	var groups: Array[Array] = []
	for cell: Vector2i in gaps:
		var joined: bool = false
		for group: Array in groups:
			if group.any(func(g: Vector2i) -> bool: return Vector2(g).distance_to(Vector2(cell))<=48):
				group.append(cell)
				joined = true
				break
		if not joined:
			groups.append([cell])
	var out: Array[Vector2i] = []
	for group: Array in groups:
		var centre := Vector2.ZERO
		for cell: Vector2i in group:
			centre += Vector2(cell)
		centre /= group.size()
		var best: Vector2i = group[0]
		for cell: Vector2i in group:
			if Vector2(cell).distance_squared_to(centre)<Vector2(best).distance_squared_to(centre):
				best = cell
		out.append(best)
	return out

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
## scroll, no door, nothing tall in front. How many were hung.
func _hangings(room: Dictionary, floor: Dictionary[Vector2i,bool], cells: Dictionary[Vector2i,String], doors: Array[Vector2]) -> int:
	var life: Dictionary = room["life"]
	var kinds: Array = life.get("hangings",[])
	if kinds.is_empty() or float(life.get("hang",0.0))<=0.0:
		return 0
	var count: int = 0
	var random: RandomNumberGenerator = room["rng"]
	var faces: Array[Dictionary] = _faces(floor,cells).filter(func(f: Dictionary) -> bool: return (f["into"] as Vector2).y>=0.0)
	# Shuffled by the room's own seed (Array.shuffle would use the global RNG: another look each load).
	for i: int in range(faces.size()-1,0,-1):
		var j: int = random.randi_range(0,i)
		var swap: Dictionary = faces[i]
		faces[i] = faces[j]
		faces[j] = swap
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
			"banner_cloth":
				# `banner_cloth:<hex>`: the cloth's colour (a 镖局's red, a 棺材铺's white).
				if not variant.is_empty():
					prop["cloth"] = variant
			"wall_scroll":
				if variant=="calligraphy":
					prop["calligraphy"] = true
		var into: Vector2 = face["into"]
		prop["at"] = [at.x,at.y]
		prop["rotation"] = rad_to_deg(atan2(into.x,into.y))
		geometry._prop(prop)
		if prop["kind"]=="wall_lamp":
			_heat.append(at)
			_anchors.append({"kind":"wall_lamp","at":at,"into":into,"elevation":0.0})
		placed.append(at)
		wanted -= 1
		count += 1
	return count
