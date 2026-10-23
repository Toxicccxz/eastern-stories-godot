class_name VoxelMapGeometry
extends Node3D

## Visual geometry only. The authored TileMapLayer remains the collision authority.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
const Furniture = preload("res://presentation/voxel/props/voxel_furniture.gd")
const Fixtures = preload("res://presentation/voxel/props/voxel_fixtures.gd")
const TradeProps = preload("res://presentation/voxel/props/voxel_trade_props.gd")
const UNIT: float = 32.0
var shapes := Shapes.new()
var rng := RandomNumberGenerator.new()
var occluders: Array[Dictionary] = []
var footprints: Array[Rect2] = []
var indoor: bool = false
var foliage: VoxelFoliage
var meadow := FastNoiseLite.new()
var flora: Dictionary = {}
var _walls: Node3D
## Cut-away walls are knee height and hide nothing, so they are not occluders.
var _low_walls: Node3D
var ground: VoxelGround
var tree_shapes := VoxelTree.new()
var landmass: VoxelLandmass
var edge_config: Dictionary = {}
## Indoor walls on the camera's near side, cut low (layout `low_walls`: pixel rects).
var low_walls: Array[Rect2] = []
var left_low_walls: Array[Rect2] = []
var side_walls: Array[Node3D] = []
var _side_high_walls: Array[Node3D] = []
var mounted_props: Array[Dictionary] = []
var passage_props: Array[Dictionary] = []
var palette: Dictionary = {}
var surfaces: Dictionary = {}
var floor_openings: Array[Rect2] = []
## Prop kinds no props file draws (layout looks and voxel configs); tests require none.
var unknown_kinds: Array[String] = []
var furniture := Furniture.new()
var fixtures := Fixtures.new()
var trade_props := TradeProps.new()

static func point(at: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(at.x / UNIT, height, at.y / UNIT)

func make(map: WorldMapController, layout: Dictionary) -> void:
	rng.seed = 7819
	furniture.rng = rng
	shapes.spatial_batching = true
	indoor = layout.get("indoor", false)
	shapes.spatial_cell_size = 6.0 if indoor else 12.0
	flora = layout.get("flora", {})
	palette = layout.get("palette", {})
	surfaces = layout.get("surfaces", {})
	edge_config = layout.get("edge", {})
	for a: Array in layout.get("low_walls", []):
		low_walls.append(Rect2(Vector2(a[0],a[1]), Vector2(a[2]-a[0],a[3]-a[1])))
	for a: Array in layout.get("low_walls_left", layout.get("low_walls", [])):
		left_low_walls.append(Rect2(Vector2(a[0],a[1]), Vector2(a[2]-a[0],a[3]-a[1])))
	if layout.get("cutaway_rooms",false):
		for node: Node in map.find_children("*","Area2D",true,false):
			if node is WorldPhysicalZoneArea2D:
				var room: Rect2 = (node as WorldPhysicalZoneArea2D).global_rect()
				var south := Rect2(Vector2(room.position.x,room.end.y-32),Vector2(room.size.x,32))
				low_walls.append(south)
				left_low_walls.append(south)
				low_walls.append(Rect2(Vector2(room.end.x-32,room.position.y),Vector2(32,room.size.y)))
				left_low_walls.append(Rect2(room.position,Vector2(32,room.size.y)))
	for prop: Dictionary in layout.get("props", []):
		if prop.get("kind","")=="stairwell":
			var at: Array = prop["at"]
			var size: Array = prop["size"]
			var extent := Vector2(size[0],size[1])
			floor_openings.append(Rect2(Vector2(at[0],at[1])-extent/2,extent))
	meadow.seed = 8147
	meadow.frequency = 0.009
	meadow.fractal_octaves = 2
	_walls = _node()
	occluders.append({"node": _walls})
	_low_walls = _node()
	for side: int in 2 if indoor else 0:
		var group: Node3D = _node()
		side_walls.append(group)
		var high: Node3D = _node(Vector3.ZERO,group)
		_side_high_walls.append(high)
		occluders.append({"node":high})
	if not indoor or layout.get("courtyard",false):
		foliage = VoxelFoliage.new()
		add_child(foliage)
	for building: Dictionary in layout.get("buildings", []):
		var a: Array = building["rect"]
		footprints.append(Rect2(Vector2(a[0],a[1]), Vector2(a[2]-a[0],a[3]-a[1])))
	ground = VoxelGround.new()
	ground.parent = self
	ground.shapes = shapes
	ground.rng = rng
	ground.noise = meadow
	ground.foliage = foliage
	ground.footprints = footprints
	ground.weather = layout.get("weather",[])
	_terrain(map)
	for building: Dictionary in layout.get("buildings", []):
		_building(map, building)
	for prop: Dictionary in layout.get("props", []):
		_prop(prop)
	var furnishings: Node = map.get_node_or_null("Furnishings")
	if furnishings != null:
		for node: Node in furnishings.get_children():
			_prop(furnishing(node as Node2D))
	# Split only batches exceeding Mobile's eight local omni lights. Making every
	# street tile batch smaller needlessly multiplies draw calls away from doorways.
	var light_bounds: Array[AABB] = []
	for lamp: Node in find_children("*","OmniLight3D",true,false):
		var light := lamp as OmniLight3D
		light_bounds.append(light.global_transform*light.get_aabb())
	shapes.flush(light_bounds)
	if foliage != null:
		foliage.finish()
	set_view_side(false)
	sync_passages(map)

func set_view_side(left: bool) -> void:
	if side_walls.size()==2:
		side_walls[0].visible = not left
		side_walls[1].visible = left
	for entry: Dictionary in mounted_props:
		(entry["node"] as Node3D).visible = not _mounted_cut(entry["at"],left)

func _mounted_cut(at: Vector2, left: bool) -> bool:
	for rect: Rect2 in left_low_walls if left else low_walls:
		if rect.grow(12).has_point(at):
			return true
	return false

## The hidden passage's original state decides whether its floor is closed.
func sync_passages(map: WorldMapController) -> void:
	for entry: Dictionary in passage_props:
		var open: bool = map.is_portal_open(entry["portal"])
		(entry["node"] as Node3D).visible = open
		(entry["cover"] as Node3D).visible = not open

## A layout furnishing as prop data: its look, standing on its blocked box. The visual size
## defaults to the box (in the prop's own axes, so turned a quarter it swaps).
static func furnishing(node: Node2D) -> Dictionary:
	var data: Dictionary = (node.get_meta("look") as Dictionary).duplicate()
	data["at"] = [node.global_position.x,node.global_position.y]
	if not data.has("size"):
		var box: Vector2 = node.get_meta("footprint")
		var turned: bool = posmod(roundi(float(data.get("rotation",0))),180)==90
		data["size"] = [box.y,box.x] if turned else [box.x,box.y]
	return data

func _node(at: Vector3 = Vector3.ZERO, parent: Node3D = null) -> Node3D:
	if parent == null:
		parent = self
	var node := Node3D.new()
	node.position = at
	parent.add_child(node)
	return node

func _pick(colors: Array) -> String:
	return String(colors[rng.randi_range(0,colors.size()-1)])

func _terrain(map: WorldMapController) -> void:
	var cells: Dictionary[Vector2i, String] = {}
	for node: Node in map.find_children("*", "TileMapLayer", true, false):
		var layer := node as TileMapLayer
		for cell: Vector2i in layer.get_used_cells():
			var tile: TileData = layer.get_cell_tile_data(cell)
			if tile != null:
				var at: Vector2 = layer.to_global(layer.map_to_local(cell))
				cells[Vector2i(at)] = String(tile.get_custom_data("terrain"))
	for node: Node in map.find_children("*","Area2D",true,false):
		if node is WorldPhysicalZoneArea2D and surfaces.has(String((node as WorldPhysicalZoneArea2D).zone_id)):
			var zone := node as WorldPhysicalZoneArea2D
			for cell: Vector2i in cells:
				if zone.global_rect().has_point(Vector2(cell)) and cells[cell] in ["floor_wood","floor_shop","floor_yard","blocked","rock"]:
					cells[cell] = String(surfaces[String(zone.zone_id)])
	if not indoor:
		var required: Array[Rect2] = footprints.duplicate()
		for node: Node in map.find_children("*","Area2D",true,false):
			if node is WorldPhysicalZoneArea2D:
				required.append((node as WorldPhysicalZoneArea2D).global_rect())
		landmass = VoxelLandmass.new()
		landmass.build(cells,required,edge_config)
		cells = landmass.terrain(cells)
		landmass.make_base(self)
		_ground_under_blocks(cells)
	var trees: Dictionary[Vector2i, bool] = {}
	var painted: Dictionary[Vector2i, bool] = {}
	# Merged paving and boards must also see the hole, not bridge over a skipped cell.
	for cell: Vector2i in cells.keys():
		if _floor_opening(Vector2(cell)):
			cells.erase(cell)
	for cell: Vector2i in cells:
		if painted.has(cell):
			continue
		var pos: Vector2 = Vector2(cell)
		if _floor_opening(pos):
			continue
		var p: Vector3 = point(pos)
		var kind: String = cells[cell]
		var covered: bool = false
		for rect: Rect2 in footprints:
			if rect.has_point(pos):
				covered = true
				break
		if covered:
			continue
		var wood: bool = kind in ["floor_wood", "floor_shop", "blocked"] and indoor
		var road: bool = kind in ["town_ground", "street", "floor_yard", "rock"]
		var wall: bool = kind in ["wall", "wall_wood", "shutter", "shop_front"]
		var growth: float = meadow.get_noise_2d(pos.x, pos.y)
		var palette: Array = ["68814e", "718a50", "799456"] if growth>0 else ["56754b", "60804b", "688550"]
		if wood:
			palette = self.palette.get("wood",["9f7953", "a37e57", "a7815b", "99754f"])
		elif road:
			palette = ["acac98", "a0a695", "9ba492", "b6b49b"]
		elif kind in ["path", "riverbank"]:
			palette = ["b4a077", "beab7e", "b6a37b"]
		elif wall:
			palette = ["7b806d", "848773"]
		var size := Vector3(0.5,0.12,0.5)
		if wood:
			var boards: int = 1
			for next: int in range(1,rng.randi_range(2,5)):
				var neighbor := cell+Vector2i(16*next,0)
				if painted.has(neighbor) or _floor_opening(Vector2(neighbor)) or not cells.get(neighbor,"") in ["floor_wood","floor_shop","blocked"]:
					break
				painted[neighbor] = true
				boards += 1
			size.x = boards*0.5-0.015
			p.x += (boards-1)*0.25
			size.z = 0.47
		if road:
			ground.paving(cell,cells,painted)
		else:
			# Ground colour changes in broad patches, not independently on every tile.
			var tint: String = _pick(palette) if indoor or wall else String(palette[clampi(roundi((growth+0.5)*2),0,palette.size()-1)])
			shapes.box(self,p-Vector3(0,0.06,0),size,tint)
		if wall:
			var right_low: bool = indoor and low_wall(pos)
			var left_low: bool = indoor and low_wall(pos,true)
			var horizontal: bool = cells.get(cell+Vector2i(16,0),"") in ["wall","wall_wood"] or cells.get(cell-Vector2i(16,0),"") in ["wall","wall_wood"]
			if right_low==left_low:
				_wall_cell(_low_walls if right_low else _walls,p,0.36 if right_low else 3.2,horizontal)
			else:
				_wall_cell(side_walls[0] if right_low else _side_high_walls[0],p,0.36 if right_low else 3.2,horizontal)
				_wall_cell(side_walls[1] if left_low else _side_high_walls[1],p,0.36 if left_low else 3.2,horizontal)
		elif kind in ["forest", "boundary"] and not indoor:
			var cluster := Vector2i(floori(pos.x/120),floori(pos.y/120))
			if not trees.has(cluster) and rng.randf()<0.15 and landmass.supports(pos,64):
				trees[cluster] = true
				_tree(p, rng.randf()<float(flora.get("blossom_trees",0.35)))
		if foliage != null and not wall and (not indoor or kind in ["grass","forest","forest_floor"]):
			_dress_ground(cell, p, kind, growth, cells)
	# Indoor floors keep their cutaway plinth. Outdoors has only the finite,
	# contoured landmass above, with no rectangle spanning its gaps or surroundings.
	if indoor:
		_plinth(cells)
	if foliage != null:
		for edge_cell: Vector2i in cells:
			var hidden: bool = false
			for footprint: Rect2 in footprints:
				hidden = hidden or footprint.has_point(Vector2(edge_cell))
			if not hidden:
				ground.edge(edge_cell,cells)
				if cells[edge_cell] in ["path","riverbank"]:
					ground.dirt(edge_cell)
		ground.puddles()

## Outdoors a blocked box (a board, a stone lion) stands on the ground beside it, not on
## grass: each blocked cell takes the nearest open ground kind along the four axes.
func _ground_under_blocks(cells: Dictionary[Vector2i, String]) -> void:
	var under: Dictionary[Vector2i, String] = {}
	for cell: Vector2i in cells:
		if cells[cell] != "blocked":
			continue
		under[cell] = "town_ground"
		for reach: int in range(1,8):
			var found: String = ""
			for shift: Vector2i in [Vector2i(-16,0),Vector2i(16,0),Vector2i(0,-16),Vector2i(0,16)]:
				var kind: String = cells.get(cell+shift*reach,"")
				if found.is_empty() and not kind.is_empty() and not kind in ["blocked","wall","wall_wood","shutter","shop_front"]:
					found = kind
			if not found.is_empty():
				under[cell] = found
				break
	for cell: Vector2i in under:
		cells[cell] = under[cell]

func _floor_opening(at: Vector2) -> bool:
	for rect: Rect2 in floor_openings:
		if rect.has_point(at):
			return true
	return false

func low_wall(at: Vector2, left: bool = false) -> bool:
	for rect: Rect2 in left_low_walls if left else low_walls:
		if rect.has_point(at):
			return true
	return false

func _wall_cell(into: Node3D, p: Vector3, height: float, horizontal: bool) -> void:
	shapes.box(into,p+Vector3(0,height/2,0),Vector3(0.5,height,0.5),String(palette.get("wall","c9b997" if indoor else "83917b")))
	shapes.box(into,p+Vector3(0,height+0.05,0),Vector3(0.53,0.12,0.53),"78513b" if indoor else "607a60")
	if indoor:
		_interior_wall(into,p,height,horizontal)

## The plinth under an interior follows its drawn cells, so an L- or T-shaped floor
## leaves its empty corners open. Rows with the same runs merge into one slab.
func _plinth(cells: Dictionary[Vector2i, String]) -> void:
	var rows: Dictionary[int, Array] = {}
	for cell: Vector2i in cells:
		if _floor_opening(Vector2(cell)):
			continue
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell.x)
	var slabs: Array[Rect2] = []
	var open: Dictionary[Vector2i, int] = {}
	var ys: Array = rows.keys()
	ys.sort()
	for y: int in ys:
		var xs: Array = rows[y]
		xs.sort()
		var runs: Array[Vector2i] = []
		for x: int in xs:
			if not runs.is_empty() and x-runs[-1].y==16:
				runs[-1].y = x
			else:
				runs.append(Vector2i(x,x))
		var still: Dictionary[Vector2i, int] = {}
		for run: Vector2i in runs:
			var index: int = open.get(run,-1)
			if index>=0 and is_equal_approx(slabs[index].end.y,float(y-8)):
				slabs[index].size.y += 16
			else:
				index = slabs.size()
				slabs.append(Rect2(Vector2(run.x-8,y-8),Vector2(run.y-run.x+16,16)))
			still[run] = index
		open = still
	for slab: Rect2 in slabs:
		shapes.box(self,point(slab.get_center())-Vector3(0,0.18,0),Vector3(slab.size.x/UNIT,0.14,slab.size.y/UNIT),"776b51")

func _interior_wall(walls: Node3D, p: Vector3, height: float, horizontal: bool) -> void:
	# These reliefs stay within the existing wall thickness and add no obstacle.
	shapes.box(walls,p+Vector3(0,0.16,0),Vector3(0.54,0.30,0.54),"654b38")
	if height<1.0:
		return
	shapes.box(walls,p+Vector3(0,0.67,0),Vector3(0.52,0.69,0.52),"93704e")
	for level: float in [1.02,2.9]:
		shapes.box(walls,p+Vector3(0,level,0),Vector3(0.55,0.09,0.55),"72503a")
	var along: float = p.x if horizontal else p.z
	if posmod(roundi((along-0.25)*32),128)==0:
		shapes.box(walls,p+Vector3(0,1.60,0),Vector3(0.58,3.20,0.58),"6e4d37")

func _dress_ground(cell: Vector2i, p: Vector3, kind: String, growth: float, cells: Dictionary[Vector2i,String]) -> void:
	var grassy: bool = kind in ["grass", "forest_floor", "forest", "boundary"]
	var roadside: bool = false
	for shift: Vector2i in [Vector2i(-16,0),Vector2i(16,0),Vector2i(0,-16),Vector2i(0,16)]:
		if (cells.get(cell+shift, "") in ["grass", "forest_floor", "forest", "boundary"]) != grassy:
			roadside = true
	var density: float = float(flora.get("grass_density",0.72)) if grassy else (0.38 if roadside else 0.025)
	if rng.randf() < density:
		var at: Vector3 = p+Vector3(rng.randf_range(-0.19,0.19),0.025,rng.randf_range(-0.19,0.19))
		var flower: bool = growth>float(flora.get("flower_threshold",0.08)) and rng.randf()<0.28
		var kind_index: int = 1+rng.randi_range(0,3) if flower and grassy else 0
		if grassy and growth< -0.15 and rng.randf()<0.2:
			kind_index = 5
		foliage.plant(at, kind_index, rng.randf_range(0.65,1.25) if grassy else rng.randf_range(0.23,0.48),rng.randf()*TAU)
	if roadside and rng.randf()<0.42:
		var at: Vector3 = p+Vector3(rng.randf_range(-0.24,0.24),0.015,rng.randf_range(-0.24,0.24))
		shapes.box(self,at,Vector3(rng.randf_range(0.08,0.25),0.04,rng.randf_range(0.07,0.18)),_pick(["8b9672","7d8961","aaae8e"]))
	if not grassy and growth>0.18 and rng.randf()<0.10:
		# Small petals and moss in irregular clusters, leaving the main walking line clear.
		shapes.box(self,p+Vector3(rng.randf_range(-0.2,0.2),0.025,rng.randf_range(-0.2,0.2)),Vector3(0.09,0.025,0.07),_pick(["d3a6ad","c98c9f","9d9f69"]))

func _building(map: WorldMapController, data: Dictionary) -> void:
	var a: Array = data["rect"]
	var rect := Rect2(Vector2(a[0],a[1]),Vector2(a[2]-a[0],a[3]-a[1]))
	var center: Vector3 = point(rect.get_center())
	var w: float = rect.size.x/UNIT
	var d: float = rect.size.y/UNIT
	var entrances: Array[Vector3] = []
	for portal_id: String in data.get("portals",[]):
		for passage: Node in map.find_children("*","Area2D",true,false):
			if passage is WorldPassageArea2D and String((passage as WorldPassageArea2D).portal_id) == portal_id:
				entrances.append(point((passage as Node2D).global_position)-center)
	shapes.box(self,center-Vector3(0,0.025,0),Vector3(w,0.10,d),"91836a")
	var architecture := VoxelArchitecture.new()
	architecture.parent = self
	architecture.shapes = shapes
	architecture.rng = rng
	architecture.noise = meadow
	architecture.build(center,w,d,data,entrances)
	occluders.append_array(architecture.occluders)

func _tree(at: Vector3, pink: bool) -> void:
	var choices: Array = flora.get("tree_types",["pine","broadleaf","broadleaf","slender","shrub"])
	var species: String = "blossom" if pink else String(choices[rng.randi_range(0,choices.size()-1)])
	var tree: Node3D = _node(at)
	var size: float = rng.randf_range(0.82,1.32)
	tree.scale = Vector3(size*rng.randf_range(0.86,1.18),size*rng.randf_range(0.90,1.23),size)
	tree.rotation.y = rng.randf()*TAU
	tree_shapes.build(tree,shapes,species,rng.randi_range(0,5))
	if ground != null and species!="shrub":
		ground.roots(at,size)
	occluders.append({"node":tree})
	for petal: int in 10 if pink else 3:
		var drop := Vector3(rng.randf_range(-1.8,1.8),0.032+petal*0.001,rng.randf_range(-1.8,1.8))
		if landmass == null or landmass.contains(Vector2(at.x+drop.x,at.z+drop.z)*UNIT):
			shapes.box(self,at+drop,Vector3(0.1,0.025,0.08),"d095ae" if pink else "9c995e")

func _prop(data: Dictionary) -> void:
	var a: Array = data.get("at",[0,0])
	var at: Vector3 = point(Vector2(a[0],a[1]))
	var root: Node3D = _node(at)
	root.rotation.y = deg_to_rad(float(data.get("rotation",0)))
	var size: Array = data.get("size",[64,32])
	var w: float = float(size[0])/UNIT
	var d: float = float(size[1])/UNIT
	if furniture.draw(shapes,root,data,w,d) or fixtures.draw(shapes,root,data,w,d) or trade_props.draw(shapes,root,data,w,d):
		if data.get("wall_mounted",false) or data["kind"] in ["window","wall_scroll","closed_door"]:
			mounted_props.append({"node":root,"at":Vector2(a[0],a[1])})
		if data.has("portal"):
			var cover := _node(at)
			for i: int in 3:
				shapes.box(cover,Vector3(0,-0.045,(i-1)*d/3),Vector3(w,0.09,d/3-0.015),"9f7953")
			passage_props.append({"node":root,"cover":cover,"portal":StringName(data["portal"])})
		if data.get("occludes",false):
			occluders.append({"node":root})
	else:
		# A misspelt kind would otherwise leave a silent gap on the map.
		unknown_kinds.append(String(data.get("kind","")))
		push_error("Voxel map: unknown prop kind \"%s\" at %s" % [data.get("kind",""),a])
