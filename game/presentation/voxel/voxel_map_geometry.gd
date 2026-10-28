class_name VoxelMapGeometry
extends Node3D

## Visual geometry only. The authored TileMapLayer remains the collision authority.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
const Furniture = preload("res://presentation/voxel/props/voxel_furniture.gd")
const Fixtures = preload("res://presentation/voxel/props/voxel_fixtures.gd")
const TradeProps = preload("res://presentation/voxel/props/voxel_trade_props.gd")
const Wilds = preload("res://presentation/voxel/props/voxel_wilds.gd")
const ShrineProps = preload("res://presentation/voxel/props/voxel_shrine_props.gd")
const Woods = preload("res://presentation/voxel/props/voxel_woods.gd")
const Town = preload("res://presentation/voxel/props/voxel_town.gd")
const Waterside = preload("res://presentation/voxel/props/voxel_waterside.gd")
const Garden = preload("res://presentation/voxel/props/voxel_garden.gd")
const Household = preload("res://presentation/voxel/props/voxel_household.gd")
const Critter = preload("res://presentation/voxel/actors/voxel_critter.gd")
const UNIT: float = 32.0
var shapes := Shapes.new()
var rng := RandomNumberGenerator.new()
var occluders: Array[Dictionary] = []
var footprints: Array[Rect2] = []
var indoor: bool = false
var foliage: VoxelFoliage
var meadow := FastNoiseLite.new()
var flora: Dictionary = {}
## flora `zones`: zone id -> overrides (grown by `margin` px) where a place shades into the
## next region (雪亭镇's north end thinning toward the bare mountain).
var flora_regions: Array[Dictionary] = []
## flora `areas` that lay their own ground (`ground_styles`: kind -> style, over the layout's
## `ground` for that stretch only, whatever else covers it): 水烟阁's maple litter along the
## 官道, 雪亭镇's 青石板 on the highway beyond the town's big slabs.
var ground_areas: Array[Dictionary] = []
## Shapes the wandering seams between road surfaces (`_fray_seams`).
var seam_noise := FastNoiseLite.new()
## Shades a wood's `tree_chance` slowly across the map (`_tree_sites`): thickets, thin
## places and clearings instead of one even scatter.
var grove_noise := FastNoiseLite.new()
var _walls: Node3D
## Cut-away walls are knee height and hide nothing, so they are not occluders.
var _low_walls: Node3D
var ground: VoxelGround
var tree_shapes := VoxelTree.new()
## Trees by 16-unit chunk: {"node": the grove, "crowns": crown mesh -> transforms}. A big
## forest is a few hundred draws this way, not thousands.
const GROVE: float = 16.0
var _groves: Dictionary[Vector2i, Dictionary] = {}
var landmass: VoxelLandmass
## Raised rock for `cliff`/`chasm` cells (layout `cliffs`); null where a map has none.
var cliffs: VoxelCliffs
## Water surfaces (layout `water`); a map without water cells draws none.
var water: VoxelWater
var water_config: Dictionary = {}
## Ground kind -> {"style": "scree", "colors": [...]} (layout `ground`); a town keeps its paving.
var ground_styles: Dictionary = {}
var edge_config: Dictionary = {}
## Indoor walls on the camera's near side, cut low (layout `low_walls`: pixel rects).
var low_walls: Array[Rect2] = []
var left_low_walls: Array[Rect2] = []
## Near walls are cut low (indoors, or an outdoor map with low walls of its own).
var cuts: bool = false
var side_walls: Array[Node3D] = []
var _side_high_walls: Array[Node3D] = []
var mounted_props: Array[Dictionary] = []
var passage_props: Array[Dictionary] = []
var palette: Dictionary = {}
## Walls of another stuff inside rects (layout `wall_looks`): "rock" (a room built against
## the mountain) or "earth" (土墙), with their colours.
var wall_looks: Array = []
## How high the walls stand (`wall_height`, units): a great hall's taller than a room's 3.2.
var wall_height: float = 3.2
var surfaces: Dictionary = {}
var floor_openings: Array[Rect2] = []
## Prop kinds no props file draws (layout looks and voxel configs); tests require none.
var unknown_kinds: Array[String] = []
var furniture := Furniture.new()
var fixtures := Fixtures.new()
var trade_props := TradeProps.new()
var wilds := Wilds.new()
var shrine_props := ShrineProps.new()
var woods := Woods.new()
var town := Town.new()
var waterside := Waterside.new()
var garden := Garden.new()
var household := Household.new()
## How lived in the rooms look (the scene's RoomLife): worn floors, old walls, things on walls.
var life := VoxelLife.new()
## The ground as drawn: cell -> kind, a zone's `surfaces` applied.
var terrain_cells: Dictionary[Vector2i, String] = {}
## Birds, dust, smoke and drips (layout `ambience`, and the props that make them).
var ambience: VoxelAmbience
## Small animals loose on the map (layout `critters`), for the tests.
var critters: Array[Node3D] = []

## An exit command's compass direction on the map (north is up); zero for any other verb.
static func compass(command: String) -> Vector2:
	var base: String = command.trim_suffix("up").trim_suffix("down") if command not in ["up","down"] else ""
	var directions: Dictionary = {"north":Vector2.UP,"south":Vector2.DOWN,"east":Vector2.RIGHT,"west":Vector2.LEFT,
		"northeast":Vector2(1,-1),"northwest":Vector2(-1,-1),"southeast":Vector2(1,1),"southwest":Vector2(-1,1)}
	return (directions.get(base,Vector2.ZERO) as Vector2).normalized()

static func point(at: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(at.x / UNIT, height, at.y / UNIT)

func _init() -> void:
	grove_noise.seed = 2741
	grove_noise.frequency = 0.0035

## A region's default flora (data/<region>/voxel/flora.json: its tree, bark, grass and flower
## colours) under a map's own `flora`: the map's keys win, except `crown_colors` and
## `bark_colors`, where the map overrides species one by one.
static func merge_flora(region: Dictionary, own: Dictionary) -> Dictionary:
	var result: Dictionary = region.duplicate(true)
	for key: String in own:
		var value: Variant = own[key]
		if key in ["crown_colors","bark_colors"] and value is Dictionary and result.get(key) is Dictionary:
			var species: Dictionary = (result[key] as Dictionary).duplicate()
			species.merge(value,true)
			result[key] = species
		else:
			result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result

func make(map: WorldMapController, layout: Dictionary) -> void:
	rng.seed = 7819
	furniture.rng = rng
	shapes.spatial_batching = true
	indoor = layout.get("indoor", false)
	shapes.spatial_cell_size = 6.0 if indoor else 12.0
	flora = layout.get("flora", {})
	tree_shapes.palettes = flora.get("crown_colors",{})
	tree_shapes.barks = flora.get("bark_colors",{})
	# flora `areas`: [{"rect": px, overrides}] for a stretch inside a zone (npath3's starved
	# pines); they come before the zones, so the smaller patch wins. An area's or zone's
	# `crown_colors` override the map's species by species (`merge_flora`).
	# An area may cover several stretches (`rects` instead of `rect`).
	for area: Dictionary in flora.get("areas",[]):
		var merged: Dictionary = merge_flora(flora,area)
		for r: Array in area.get("rects",[area.get("rect")]):
			flora_regions.append({"rect":Rect2(r[0],r[1],r[2]-r[0],r[3]-r[1]),"style":merged})
			if area.has("ground_styles"):
				ground_areas.append({"rect":Rect2(r[0],r[1],r[2]-r[0],r[3]-r[1]),"styles":area["ground_styles"]})
	for node: Node in map.find_children("*","Area2D",true,false):
		var zone := node as WorldPhysicalZoneArea2D
		if zone != null and flora.get("zones",{}).has(String(zone.zone_id)):
			var settings: Dictionary = flora["zones"][String(zone.zone_id)]
			var merged: Dictionary = merge_flora(flora,settings)
			flora_regions.append({"rect":zone.global_rect().grow(float(settings.get("margin",0))),"style":merged})
	palette = layout.get("palette", {})
	surfaces = layout.get("surfaces", {})
	wall_looks = layout.get("wall_looks", [])
	wall_height = float(layout.get("wall_height", 3.2))
	edge_config = layout.get("edge", {})
	ground_styles = layout.get("ground", {})
	water_config = layout.get("water", {})
	if layout.has("cliffs"):
		cliffs = VoxelCliffs.new(layout["cliffs"])
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
		if prop.get("kind","") in ["stairwell","drop"]:
			var at: Array = prop["at"]
			var size: Array = prop["size"]
			var extent := Vector2(size[0],size[1])
			floor_openings.append(Rect2(Vector2(at[0],at[1])-extent/2,extent))
	meadow.seed = 8147
	seam_noise.seed = 3511
	seam_noise.frequency = 0.03
	meadow.frequency = 0.009
	meadow.fractal_octaves = 2
	_walls = _node()
	occluders.append({"node": _walls})
	_low_walls = _node()
	# Outdoors too a room's near walls are cut low when the layout asks (湘园's little rooms
	# among the trees: `cutaway_rooms` on an outdoor map).
	cuts = indoor or not low_walls.is_empty()
	for side: int in 2 if cuts else 0:
		var group: Node3D = _node()
		side_walls.append(group)
		var high: Node3D = _node(Vector3.ZERO,group)
		_side_high_walls.append(high)
		occluders.append({"node":high})
	if not indoor or layout.get("courtyard",false):
		foliage = VoxelFoliage.new()
		foliage.greens = flora.get("grass_colors",foliage.greens)
		foliage.petals = flora.get("flower_colors",foliage.petals)
		foliage.gust = float(flora.get("wind",0.0))
		foliage.butterfly_count = int(flora.get("butterflies",8))
		add_child(foliage)
	for building: Dictionary in layout.get("buildings", []):
		var a: Array = building["rect"]
		footprints.append(Rect2(Vector2(a[0],a[1]), Vector2(a[2]-a[0],a[3]-a[1])))
	ground = VoxelGround.new()
	ground.parent = self
	set_meta("flat",true)
	ground.root_ferns = flora.get("root_ferns",true)
	ground.shapes = shapes
	ground.rng = rng
	ground.noise = meadow
	ground.foliage = foliage
	ground.footprints = footprints
	ground.weather = layout.get("weather",[])
	ground.tints = layout.get("ground_tints",{})
	ground.style_at = func(cell: Vector2i, kind: String) -> Dictionary: return _ground_style(Vector2(cell),kind)
	for kind: String in ground_styles:
		if ground_styles[kind].get("style","")=="scree":
			ground.loose.append(kind)
	ambience = VoxelAmbience.new()
	ambience.name = "Ambience"
	add_child(ambience)
	ambience.configure(layout.get("ambience",{}))
	wilds.ambience = ambience
	wilds.rng = rng
	shrine_props.ambience = ambience
	woods.ambience = ambience
	fixtures.ambience = ambience
	woods.rng = rng
	woods.tree_shapes = tree_shapes
	furniture.ambience = ambience
	trade_props.rng = rng
	trade_props.ambience = ambience
	town.rng = rng
	town.ambience = ambience
	waterside.rng = rng
	waterside.ambience = ambience
	garden.rng = rng
	garden.ambience = ambience
	household.ambience = ambience
	life.prepare(self,map,layout)
	_terrain(map, layout.get("reshape",[]), layout.get("exit_trails",{}))
	for building: Dictionary in layout.get("buildings", []):
		_building(map, building)
	for prop: Dictionary in layout.get("props", []):
		_prop(prop)
	var furnishings: Node = map.get_node_or_null("Furnishings")
	if furnishings != null:
		for node: Node in furnishings.get_children():
			var data: Dictionary = furnishing(node as Node2D)
			life.dress(data)
			_prop(data)
	life.finish(map,terrain_cells)
	_critters(layout)
	_plant_groves()
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

const BLOCKING: Array[String] = ["cliff","chasm","forest","boundary","wall","wall_wood","shutter","shop_front","blocked","water","deep_water"]

func _terrain(map: WorldMapController, reshape: Array = [], exit_trails: Dictionary = {}) -> void:
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
	# Visual only: what a stretch of ground shows (the road running on past an exit).
	for entry: Dictionary in reshape:
		var r: Array = entry["rect"]
		var area := Rect2(r[0],r[1],r[2]-r[0],r[3]-r[1])
		for cell: Vector2i in cells:
			if area.has_point(Vector2(cell)) and (not entry.has("from") or cells[cell] in entry["from"]):
				cells[cell] = String(entry["to"])
	# Visual only: a road runs on past an exit to another map (layout `exit_trails`: portal id
	# -> length in cells, four cells of "path" wide; or {"cells", "kind", "width"}: a paved
	# road its own width), the way its command points.
	for node: Node in map.find_children("*","Area2D",true,false):
		var passage := node as WorldPassageArea2D
		if passage == null or not exit_trails.has(String(passage.portal_id)):
			continue
		var portal: PortalDefinition = GameContent.catalog().portal(passage.portal_id)
		var toward: Vector2 = compass(portal.legacy_command) if portal != null else Vector2.ZERO
		if toward == Vector2.ZERO:
			continue
		var across := Vector2(-toward.y,toward.x)
		var trail: Variant = exit_trails[String(passage.portal_id)]
		var length: int = int(trail.get("cells",8)) if trail is Dictionary else int(trail)
		var road: String = String(trail.get("kind","path")) if trail is Dictionary else "path"
		var wide: int = int(trail.get("width",4)) if trail is Dictionary else 4
		# One cell further each step on the long axis (a diagonal steps without gaps), `wide`
		# cells about the passage's middle, starting past its mouth.
		var stride: float = 16.0/maxf(absf(toward.x),absf(toward.y))
		for step: int in range(1,length+1):
			for lane: int in wide:
				var at: Vector2 = passage.global_position+toward*step*stride+across*(lane-(wide-1)/2.0)*16
				cells[Vector2i(floori(at.x/16)*16+8,floori(at.y/16)*16+8)] = road
	if cliffs != null:
		cliffs.prepare(cells,BLOCKING)
	if not indoor:
		var required: Array[Rect2] = footprints.duplicate()
		for node: Node in map.find_children("*","Area2D",true,false):
			if node is WorldPhysicalZoneArea2D:
				required.append((node as WorldPhysicalZoneArea2D).global_rect())
		landmass = VoxelLandmass.new()
		landmass.build(cells,required,edge_config)
		cells = landmass.terrain(cells)
		_ground_under_blocks(cells)
		_fray_seams(cells)
	if cliffs != null:
		cliffs.shape(cells)
		cliffs.remember(cells)
	water = VoxelWater.new(water_config)
	var beds: Dictionary = {}
	if cliffs != null and cliffs.sink.has("bed"):
		# A stream along the bottom of a gorge, a little above its floor.
		for cell: Vector2i in cliffs.holes():
			beds[cell] = {"kind":String(cliffs.sink["bed"]),"level":cliffs.heights[cell]+float(cliffs.sink.get("bed_level",0.25))}
	water.collect(cells,beds)
	# A map in the air (the great pine's boughs) has no ground slab under it.
	if landmass != null and not edge_config.get("none",false):
		var holes: Dictionary[Vector2i, bool] = {}
		if cliffs != null:
			holes = cliffs.holes()
			cliffs.base_depth = landmass.depth
		# Water set below the slab's top (a stream, a deep pool) is not covered by it, nor is
		# clear water, whose stony bed lies below the slab.
		for cell: Vector2i in water.levels:
			if water.levels[cell] < -0.1 or water.looks[cell].get("clear",false):
				holes[cell] = true
		landmass.make_base(self,holes)
	var sites: Dictionary = {}
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
		if covered or cliffs != null and cliffs.heights.has(cell) or water.levels.has(cell):
			continue
		var style: Dictionary = _ground_style(pos,kind)
		if style.get("style","")=="void":
			continue
		var wood: bool = kind in ["floor_wood", "floor_shop", "blocked"] and indoor
		var road: bool = kind in ["town_ground", "street", "floor_yard", "rock"]
		var wall: bool = kind in ["wall", "wall_wood", "shutter", "shop_front"]
		var growth: float = meadow.get_noise_2d(pos.x, pos.y)
		var palette: Array = ["68814e", "718a50", "799456"] if growth>0 else ["56754b", "60804b", "688550"]
		if not flora_regions.is_empty() and kind in ["grass","forest_floor","forest","boundary"]:
			# A flora zone's own ground (`ground`: dark to light), as a town gives way to bare hills.
			palette = _flora_at(pos).get("ground",palette)
		if wood:
			palette = self.palette.get("wood",["9f7953", "a37e57", "a7815b", "99754f"])
		elif road:
			palette = ["acac98", "a0a695", "9ba492", "b6b49b"]
		elif kind in ["path", "riverbank"]:
			palette = ["b4a077", "beab7e", "b6a37b"]
		elif wall:
			palette = ["7b806d", "848773"]
		if style.has("colors"):
			palette = style["colors"]
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
		if style.get("style","")=="scree":
			ground.scree(cell,p,palette,growth,style)
		elif style.get("style","")=="litter":
			ground.litter(cell,p,palette,growth,style)
		elif style.get("style","")=="bark":
			ground.bark(cell,p,palette,cells,style)
		elif style.get("style","")=="slabs":
			ground.slabs(cell,cells,painted,style)
		elif style.get("style","")=="mosaic":
			ground.mosaic(cell,style)
		elif style.get("style","")=="paving" or road and not style.has("colors"):
			ground.paving(cell,cells,painted,style)
		else:
			# Ground colour changes in broad patches, not independently on every tile.
			var tint: String = _pick(palette) if indoor or wall else String(palette[clampi(roundi((growth+0.5)*2),0,palette.size()-1)])
			shapes.box(self,p-Vector3(0,0.06,0),size,tint)
		if wall:
			var right_low: bool = cuts and low_wall(pos)
			var left_low: bool = cuts and low_wall(pos,true)
			var horizontal: bool = cells.get(cell+Vector2i(16,0),"") in ["wall","wall_wood"] or cells.get(cell-Vector2i(16,0),"") in ["wall","wall_wood"]
			if right_low==left_low:
				_wall_cell(_low_walls if right_low else _walls,p,0.36 if right_low else wall_height,horizontal)
			else:
				_wall_cell(side_walls[0] if right_low else _side_high_walls[0],p,0.36 if right_low else wall_height,horizontal)
				_wall_cell(side_walls[1] if left_low else _side_high_walls[1],p,0.36 if left_low else wall_height,horizontal)
		elif kind in flora.get("tree_kinds",["forest", "boundary"]) and not indoor and not _treeless(pos) and landmass.supports(pos,64):
			# A cell a tree may stand on, grouped with its neighbours by `tree_spacing` (the
			# area's or zone's own, else the map's); `_plant_trees` picks one per group.
			var spacing: float = float(_flora_at(pos).get("tree_spacing",120))
			var cluster := Vector3i(floori(pos.x/spacing),floori(pos.y/spacing),roundi(spacing))
			if not sites.has(cluster):
				sites[cluster] = []
			(sites[cluster] as Array).append(cell)
		if foliage != null and not wall and (not indoor or kind in ["grass","forest","forest_floor"]):
			_dress_ground(cell, p, kind, growth, cells)
	_plant_trees(sites)
	# Indoor floors keep their cutaway plinth. Outdoors has only the finite,
	# contoured landmass above, with no rectangle spanning its gaps or surroundings.
	if indoor:
		_plinth(cells)
	if cliffs != null:
		cliffs.build(self)
		occluders.append({"node":cliffs.root})
		_dress_cliffs()
	water.build(self,cells,cliffs,shapes,rng)
	if foliage != null:
		for edge_cell: Vector2i in cells:
			var hidden: bool = false
			for footprint: Rect2 in footprints:
				hidden = hidden or footprint.has_point(Vector2(edge_cell))
			if not hidden:
				ground.edge(edge_cell,cells)
				# Trodden dirt on paths and banks, unless the ground is kept clean (`clean`: a floor).
				if cells[edge_cell] in ["path","riverbank"] and not ground_styles.get(cells[edge_cell],{}).get("clean",false):
					ground.dirt(edge_cell)
		ground.puddles()
	terrain_cells = cells

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

## Ground kinds a way is surfaced with: where two meet, their seam wanders (`_fray_seams`).
const SURFACES: Array[String] = ["town_ground","street","floor_yard","rock","path","riverbank","gravel"]

## Two road surfaces (青石 and 黄土, flags and scree) never meet along a ruled line: within two
## cells of the seam a cell takes the other side's surface in clumps along a noise field, the
## seam pushed into one side where the field is high and into the other where it is low, so the
## two interlock. A strip one cell wide (a rut) keeps its line. The picture only: the 2D map
## keeps its tiles and collision.
func _fray_seams(cells: Dictionary[Vector2i, String]) -> void:
	var near: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells:
		if cells[cell] in SURFACES:
			for shift: Vector2i in [Vector2i(16,0),Vector2i(0,16)]:
				var other: String = cells.get(cell+shift,"")
				if other != cells[cell] and other in SURFACES and VoxelGround.broad(cells,cell) and VoxelGround.broad(cells,cell+shift):
					for y: int in range(-2,3):
						for x: int in range(-2,3):
							near[cell+Vector2i(x,y)*16] = true
							near[cell+shift+Vector2i(x,y)*16] = true
	var frayed: Dictionary[Vector2i, String] = {}
	for cell: Vector2i in near:
		var kind: String = cells.get(cell,"")
		if not kind in SURFACES or not VoxelGround.broad(cells,cell):
			continue
		var best: String = ""
		var reach: int = 3
		for y: int in range(-2,3):
			for x: int in range(-2,3):
				var other: String = cells.get(cell+Vector2i(x,y)*16,"")
				var d: int = maxi(absi(x),absi(y))
				if other != kind and other in SURFACES and d < reach and VoxelGround.broad(cells,cell+Vector2i(x,y)*16):
					best = other
					reach = d
		if best.is_empty():
			continue
		var field: float = seam_noise.get_noise_2d(cell.x,cell.y)*(1.0 if kind < best else -1.0)
		if field > (0.0 if reach == 1 else 0.32):
			frayed[cell] = best
	for cell: Vector2i in frayed:
		cells[cell] = frayed[cell]

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
	for look: Dictionary in wall_looks:
		var r: Array = look["rect"]
		if Rect2(r[0],r[1],r[2]-r[0],r[3]-r[1]).has_point(Vector2(p.x,p.z)*UNIT):
			_styled_wall_cell(into,p,height,look,horizontal)
			return
	shapes.box(into,p+Vector3(0,height/2,0),Vector3(0.5,height,0.5),String(palette.get("wall","c9b997" if indoor else "83917b")))
	shapes.box(into,p+Vector3(0,height+0.05,0),Vector3(0.53,0.12,0.53),"78513b" if indoor else "607a60")
	if indoor:
		_interior_wall(into,p,height,horizontal)

## A wall cell of rock (rough courses proud of each other) or rammed earth (bands); indoors also
## plaster of a room's own colour, upright boards or 青砖 courses (a room's life, VoxelLife).
func _styled_wall_cell(into: Node3D, p: Vector3, height: float, look: Dictionary, horizontal: bool = true) -> void:
	var colors: Array = look.get("colors",["7c6e58","8b7c63","6e6250","978869"])
	match String(look.get("style","rock")):
		"plaster":
			shapes.box(into,p+Vector3(0,height/2,0),Vector3(0.5,height,0.5),String(look["wall"]))
			shapes.box(into,p+Vector3(0,height+0.05,0),Vector3(0.53,0.12,0.53),"78513b")
			_interior_wall(into,p,height,horizontal)
			return
		"boards":
			# Upright planks, two to a cell, of slightly different lengths and shades, a dark seam
			# between; the skirting and top rail as on plaster.
			shapes.box(into,p+Vector3(0,height/2,0),Vector3(0.48,height,0.48),"4a3a2c")
			for plank: int in 2:
				var offset: float = -0.125+plank*0.25
				var at := p+(Vector3(offset,0,0) if horizontal else Vector3(0,0,offset))
				shapes.box(into,at+Vector3(0,height/2,0),Vector3(0.235 if horizontal else 0.5,height,0.5 if horizontal else 0.235),_pick(colors))
			shapes.box(into,p+Vector3(0,0.16,0),Vector3(0.54,0.30,0.54),"654b38")
			shapes.box(into,p+Vector3(0,height+0.05,0),Vector3(0.53,0.12,0.53),"78513b")
			if height>1.0:
				shapes.box(into,p+Vector3(0,2.9,0),Vector3(0.55,0.09,0.55),"72503a")
			return
		"brick":
			# 青砖 in running bond, the courses offset by half a brick, mortar showing between.
			shapes.box(into,p+Vector3(0,height/2,0),Vector3(0.48,height,0.48),String(look.get("mortar","9a9888")))
			var course: int = 0
			var y: float = 0.0
			while y < height-0.01:
				var h: float = minf(0.17,height-y)
				var shift: float = 0.125 if course%2 else 0.0
				for brick: int in 2:
					var offset: float = -0.125+brick*0.25+shift
					if offset>0.25:
						offset -= 0.5
					var at := p+(Vector3(offset,0,0) if horizontal else Vector3(0,0,offset))
					shapes.box(into,at+Vector3(0,y+h/2,0),Vector3(0.235 if horizontal else 0.5,h-0.02,0.5 if horizontal else 0.235),_pick(colors))
				y += 0.17
				course += 1
			shapes.box(into,p+Vector3(0,height+0.05,0),Vector3(0.53,0.12,0.53),"5c5a52")
			return
	if look.get("style","rock")=="cloth":
		# 粗略的布料所搭成的营帐 (camp3.c): a tent's wall — coarse cloth between poles, sagging a
		# little, a seam across it, a patch here and there, a rope along the top.
		var cloth: String = String(colors[absi(int(p.x*2+p.z*2))%colors.size()])
		var sag: float = 0.1*absf(sin(p.x*3.1+p.z*2.3))
		shapes.box(into,p+Vector3(0,height/2-sag/2,0),Vector3(0.5,height-sag,0.3) if horizontal else Vector3(0.3,height-sag,0.5),cloth)
		shapes.box(into,p+Vector3(0,height*0.55,0),Vector3(0.52,0.025,0.32) if horizontal else Vector3(0.32,0.025,0.52),String(look.get("seam","5a4a3a")))
		var tag: int = absi(int(p.x*7+p.z*13))
		if tag%4==1:
			shapes.box(into,p+Vector3(0,0.5+float(tag%5)*0.3,0),Vector3(0.3,0.26,0.33) if horizontal else Vector3(0.33,0.26,0.3),String(look.get("patch","7a6a4e")))
		if tag%3==0:
			shapes.box(into,p+(Vector3(0.22,height/2,0) if horizontal else Vector3(0,height/2,0.22)),Vector3(0.1,height+0.1,0.1),String(look.get("poles","6a5038")))
		shapes.box(into,p+Vector3(0,height+0.02,0),Vector3(0.54,0.06,0.34) if horizontal else Vector3(0.34,0.06,0.54),String(look.get("rope","a08e62")))
		return
	if look.get("style","rock")=="iron_bars":
		# 铁栅 (canyon3.c): iron bars close set, spiked, rusting, on a stone sill, two rails through them.
		shapes.box(into,p+Vector3(0,0.1,0),Vector3(0.5,0.2,0.5),String(look.get("sill","7d7262")))
		for bar: int in 2:
			var offset: float = -0.125+bar*0.25
			var at := p+(Vector3(offset,0,0) if horizontal else Vector3(0,0,offset))
			var tall: float = height*(0.94+0.05*float(absi(int(p.x*5+p.z*3+bar))%3))
			var tone: String = String(colors[absi(int(p.x*3+p.z*7+bar))%colors.size()])
			shapes.box(into,at+Vector3(0,0.2+tall/2,0),Vector3(0.1,tall,0.1),tone)
			shapes.box(into,at+Vector3(0,0.3+tall,0),Vector3(0.06,0.2,0.06),String(look.get("tips","2e2c2a")))
		for rail: float in [0.9,height-0.5]:
			shapes.box(into,p+Vector3(0,rail,0),Vector3(0.52,0.08,0.14) if horizontal else Vector3(0.14,0.08,0.52),String(look.get("rail","46423e")))
		return
	if look.get("smooth",false):
		# 光滑的山壁 (canyon4.c: 在西边的山壁似乎过于平滑, 不太自然): rock dressed flat, its courses true.
		var level: float = 0.0
		var row: int = 0
		while level < height-0.01:
			var h: float = minf(0.6,height-level)
			shapes.box(into,p+Vector3(0,level+h/2,0),Vector3(0.5,h-0.01,0.5),String(colors[(row+absi(int(p.x*2)))%colors.size()]))
			level += h
			row += 1
		return
	if look.get("style","rock")=="palisade":
		# 老松寨's wall: logs stood side by side, sharpened, lashed at two heights.
		for log_index: int in 2:
			var offset := Vector3(-0.125+log_index*0.25,0,0) if horizontal else Vector3(0,0,-0.125+log_index*0.25)
			var tall: float = height*rng.randf_range(0.85,1.05)
			shapes.box(into,p+offset+Vector3(0,tall/2,0),Vector3(0.24,tall,0.24),_pick(colors))
			shapes.box(into,p+offset+Vector3(0,tall+0.09,0),Vector3(0.14,0.18,0.14),String(look.get("tips","8a7254")))
		for band: float in [0.9,height-0.7]:
			shapes.box(into,p+Vector3(0,band,0),Vector3(0.52 if horizontal else 0.27,0.07,0.27 if horizontal else 0.52),String(look.get("rope","8e7c55")))
		return
	if look.get("style","rock")=="earth":
		for band: int in ceili(height/0.35):
			var h: float = minf(0.35,height-band*0.35)
			shapes.box(into,p+Vector3(0,band*0.35+h/2,0),Vector3(0.5,h,0.5),String(colors[(band+absi(int(p.x*2+p.z*2)))%colors.size()]))
		return
	var y: float = 0.0
	var course: int = 0
	while y < height-0.01:
		var h: float = minf(rng.randf_range(0.3,0.55),height-y)
		var wobble := Vector3(rng.randf_range(-0.05,0.05),0,rng.randf_range(-0.05,0.05))
		shapes.shard(into,p+wobble+Vector3(0,y+h/2,0),Vector3(rng.randf_range(0.5,0.62),h,rng.randf_range(0.5,0.62)),_pick(colors),rng.randi(),rng.randf_range(-0.2,0.2))
		y += h
		course += 1
	if height>1.0 and rng.randf()<0.25:
		shapes.box(into,p+Vector3(0,rng.randf_range(0.8,height-0.4),0),Vector3(0.56,0.06,0.56),String(look.get("seam","5c5144")))

## The plinth under an interior follows its drawn cells, so an L- or T-shaped floor
## leaves its empty corners open. Rows with the same runs merge into one slab.
func _plinth(cells: Dictionary[Vector2i, String]) -> void:
	var rows: Dictionary[int, Array] = {}
	for cell: Vector2i in cells:
		# A pool indoors (晚月庄's 小花池) sinks below the floor: no plinth over it.
		if _floor_opening(Vector2(cell)) or water.levels.has(cell):
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
	var local: Dictionary = _flora_at(Vector2(cell))
	var density: float = float(local.get("grass_density",0.72)) if grassy else (0.38 if roadside else 0.025)
	density = float(local.get("density",{}).get(kind,density))
	var tall: Dictionary = _meadow(Vector2(cell),kind)
	if not tall.is_empty():
		# Long grass (layout flora `meadows`): taller tufts, thick enough to read as a sward.
		var sizes: Array = tall.get("scale",[1.6,2.4])
		for i: int in int(tall.get("tufts",2)):
			if rng.randf() < float(tall.get("density",0.9)):
				foliage.plant(p+Vector3(rng.randf_range(-0.22,0.22),0.025,rng.randf_range(-0.22,0.22)),0,rng.randf_range(float(sizes[0]),float(sizes[1])),rng.randf()*TAU)
		return
	if rng.randf() < density:
		var at: Vector3 = p+Vector3(rng.randf_range(-0.19,0.19),0.025,rng.randf_range(-0.19,0.19))
		var flower: bool = growth>float(local.get("flower_threshold",0.08)) and rng.randf()<0.28
		var kind_index: int = 1+rng.randi_range(0,3) if flower and grassy else 0
		if grassy and growth< -0.15 and rng.randf()<0.2:
			kind_index = 5
		foliage.plant(at, kind_index, rng.randf_range(0.65,1.25) if grassy else rng.randf_range(0.23,0.48),rng.randf()*TAU)
	if roadside and rng.randf()<0.42:
		var at: Vector3 = p+Vector3(rng.randf_range(-0.24,0.24),0.015,rng.randf_range(-0.24,0.24))
		shapes.box(self,at,Vector3(rng.randf_range(0.08,0.25),0.04,rng.randf_range(0.07,0.18)),_pick(["8b9672","7d8961","aaae8e"]))
	if not grassy and growth>0.18 and rng.randf()<0.10:
		# Small petals and moss in irregular clusters, leaving the main walking line clear
		# (flora `petals`: the region's own, 雪亭镇's blossom by default).
		shapes.box(self,p+Vector3(rng.randf_range(-0.2,0.2),0.025,rng.randf_range(-0.2,0.2)),Vector3(0.09,0.025,0.07),_pick(local.get("petals",["d3a6ad","c98c9f","9d9f69"])))

func _meadow(at: Vector2, kind: String) -> Dictionary:
	for entry: Dictionary in flora.get("meadows",[]):
		var r: Array = entry["rect"]
		if Rect2(r[0],r[1],r[2]-r[0],r[3]-r[1]).has_point(at) and kind in entry.get("on",["grass","boundary"]):
			return entry
	return {}

## Rock the cliffs raise: outcrops and tufts on the faces beside the road, dry growth,
## boulders and the odd stunted tree on the tops. The stones and trees are parented to the
## rock so they fade with it; grass tufts stay in the shared foliage (small, they hide nobody).
func _dress_cliffs() -> void:
	var rock: Array = flora.get("outcrop_colors",["8a7b62","9b8a6d","7a6c57"])
	var on_top: float = float(flora.get("cliff_tufts",0.18))
	var tree_chance: float = float(flora.get("cliff_trees",0.0))
	for cell: Vector2i in cliffs.heights:
		var h: float = cliffs.heights[cell]
		if h <= 0.0:
			continue
		var p: Vector3 = point(Vector2(cell))
		for shift: Vector2i in cliffs.faces_open(cell):
			var out := Vector3(shift.x,0,shift.y)/16.0
			if rng.randf()<0.35:
				var size: float = rng.randf_range(0.16,0.34)
				shapes.shard(cliffs.root,p+out*0.25+Vector3(0,rng.randf_range(0.1,maxf(0.2,h-0.3)),0),Vector3(size,size*0.8,size*1.2),_pick(rock),rng.randi(),rng.randf()*TAU)
			if foliage != null and rng.randf()<0.5:
				foliage.plant(p+out*rng.randf_range(0.28,0.42)+Vector3(rng.randf_range(-0.2,0.2),0.02,rng.randf_range(-0.2,0.2)),0,rng.randf_range(0.5,1.0),rng.randf()*TAU)
		var tall: Dictionary = _meadow(Vector2(cell),"cliff") if foliage != null else {}
		if not tall.is_empty() and h<=float(tall.get("below",1.6)):
			# Long grass over the low banks beside a road, as on the road's own verges.
			var sizes: Array = tall.get("scale",[1.6,2.4])
			for i: int in int(tall.get("tufts",2)):
				if rng.randf() < float(tall.get("density",0.9)):
					foliage.plant(p+Vector3(rng.randf_range(-0.22,0.22),h+0.01,rng.randf_range(-0.22,0.22)),0,rng.randf_range(float(sizes[0]),float(sizes[1])),rng.randf()*TAU)
		elif foliage != null and rng.randf()<on_top:
			var kind_index: int = 1+rng.randi_range(0,3) if rng.randf()<float(flora.get("cliff_flowers",0.0)) else 0
			foliage.plant(p+Vector3(rng.randf_range(-0.2,0.2),h,rng.randf_range(-0.2,0.2)),kind_index,rng.randf_range(0.6,1.3),rng.randf()*TAU)
		if rng.randf()<0.025:
			var size: float = rng.randf_range(0.3,0.6)
			shapes.shard(cliffs.root,p+Vector3(rng.randf_range(-0.1,0.1),h+size*0.3,rng.randf_range(-0.1,0.1)),Vector3(size*1.3,size*0.8,size),_pick(rock),rng.randi(),rng.randf()*TAU)
		if tree_chance>0.0 and rng.randf()<tree_chance:
			var choices: Array = flora.get("cliff_tree_types",["shrub"])
			var tree: Node3D = _node(p+Vector3(0,h,0),cliffs.root)
			var size: float = rng.randf_range(0.6,1.0)
			tree.scale = Vector3.ONE*size
			tree.rotation.y = rng.randf()*TAU
			tree_shapes.build(tree,shapes,String(choices[rng.randi_range(0,choices.size()-1)]),rng.randi_range(0,5))

## Round arches drawn in buildings' walls (`arches`: those portal ids found on the map).
var arches_built: int = 0

func _building(map: WorldMapController, data: Dictionary) -> void:
	var a: Array = data["rect"]
	var rect := Rect2(Vector2(a[0],a[1]),Vector2(a[2]-a[0],a[3]-a[1]))
	var center: Vector3 = point(rect.get_center())
	var w: float = rect.size.x/UNIT
	var d: float = rect.size.y/UNIT
	var entrances: Array[Vector3] = []
	var arches: Array[Vector3] = []
	for portal_id: String in data.get("portals",[])+data.get("arches",[]):
		for passage: Node in map.find_children("*","Area2D",true,false):
			if passage is WorldPassageArea2D and String((passage as WorldPassageArea2D).portal_id) == portal_id:
				entrances.append(point((passage as Node2D).global_position)-center)
				if portal_id in data.get("arches",[]):
					arches.append(entrances[-1])
	arches_built += arches.size()
	# A door nobody goes through (no room behind it in the source): drawn, not entered.
	for at: Array in data.get("doors",[]):
		entrances.append(point(Vector2(at[0],at[1]))-center)
	shapes.box(self,center-Vector3(0,0.025,0),Vector3(w,0.10,d),"91836a")
	var architecture := VoxelArchitecture.new()
	architecture.parent = self
	architecture.shapes = shapes
	architecture.rng = rng
	architecture.noise = meadow
	architecture.ambience = ambience
	architecture.build(center,w,d,data,entrances,arches)
	occluders.append_array(architecture.occluders)

var _band_hit: bool = false

## The tree kinds of the first flora band the cell lies within (see _terrain); `_band_hit`
## says whether any band applied (an empty list then means: no tree here).
func _band(local: Dictionary, cell: Vector2i) -> Array:
	_band_hit = false
	if cliffs == null:
		return []
	var near: float = cliffs.distances.get(cell,INF)
	# Both views look from the south: a tree south of the open ground stands between it and the
	# camera, so there the bands reach further (flora `south_reach`, a factor).
	if cliffs.distances.get(cell-Vector2i(0,16),INF) < cliffs.distances.get(cell+Vector2i(0,16),INF):
		near /= float(local.get("south_reach",1.0))
	for band: Dictionary in local.get("bands",[]):
		if near < float(band["within"]):
			_band_hit = true
			return band.get("types",[])
	return []

## Trees stand in clumps with grass between them (owner: 树成丛、丛间留草地). The cells a
## tree may stand on come grouped by `tree_spacing` (`sites`: cluster -> cells) and each
## group gets at most one tree: a roll seeded by the group's place picks the cell, so a tree
## is not always in the group's first row and the same map plants the same trees every time.
## `tree_chance` is each cell's chance, so a group's is that of any of its cells passing (a
## group cut by a path, with fewer cells, is emptier, as it always was); it is then shaded by a
## slow noise (flora `grove_contrast`, 0 an even scatter .. 1 thickets and clearings) so a
## wood has thick places, thin places and open ground. Returns cluster -> the tree's cell.
func _tree_sites(sites: Dictionary) -> Dictionary:
	var chosen: Dictionary = {}
	for cluster: Vector3i in sites:
		var random := RandomNumberGenerator.new()
		random.seed = Shapes.place_seed(cluster.x,cluster.y,cluster.z)
		var cells: Array = sites[cluster]
		var cell: Vector2i = cells[random.randi_range(0,cells.size()-1)]
		var local: Dictionary = _flora_at(Vector2(cell))
		var any: float = 1.0-pow(1.0-float(local.get("tree_chance",0.15)),cells.size())
		var middle := Vector2(cluster.x+0.5,cluster.y+0.5)*float(cluster.z)
		var shade: float = clampf(1.0+grove_noise.get_noise_2d(middle.x,middle.y)*float(local.get("grove_contrast",0.8))*1.6,0.0,2.0)
		if random.randf() < any*shade:
			chosen[cluster] = cell
	return chosen

func _plant_trees(sites: Dictionary) -> void:
	var chosen: Dictionary = _tree_sites(sites)
	for cluster: Vector3i in chosen:
		var cell: Vector2i = chosen[cluster]
		var local: Dictionary = _flora_at(Vector2(cell))
		# Close to a path only low growth (flora `bands`: [{"within": px of open ground,
		# "types": [...]}], nearest first): a tall pine there would wall the way off
		# from the camera. An empty band plants nothing.
		var band: Array = _band(local,cell)
		if _band_hit:
			local = local.duplicate()
			local["tree_types"] = band
		if local.get("tree_types",[0]).is_empty():
			continue
		var random := RandomNumberGenerator.new()
		random.seed = Shapes.place_seed(cluster.x,cluster.y,cluster.z,1)
		_tree(point(Vector2(cell)), random.randf()<float(local.get("blossom_trees",0.35)), local, random)

## flora `no_trees`: rects (px) where no tree is planted (a landmark's own ground).
func _treeless(at: Vector2) -> bool:
	for r: Array in flora.get("no_trees",[]):
		if Rect2(r[0],r[1],r[2]-r[0],r[3]-r[1]).has_point(at):
			return true
	return false

func _plant_groves() -> void:
	for chunk: Vector2i in _groves:
		var grove: Node3D = _groves[chunk]["node"]
		var crowns: Dictionary = _groves[chunk]["crowns"]
		for crown: ArrayMesh in crowns:
			var placed: Array = crowns[crown]
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = crown
			multi.instance_count = placed.size()
			for i: int in placed.size():
				multi.set_instance_transform(i,placed[i])
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multi
			instance.material_override = tree_shapes.material()
			grove.add_child(instance)

## `critters`: [{"kind": "chicken"|"dog", "rect": [x0, y0, x1, y1] px, "count", "colors", "speed",
## "scale"}]: they wander the open ground within their rect (walkable cells no building or
## furnishing stands on), presentation only (VoxelCritter).
func _critters(layout: Dictionary) -> void:
	var index: int = 0
	# The terrain relabels a blocked box's cells as the ground around it (`_terrain`), so the
	# furnishings' own boxes (every authored blocked prop) are kept out here.
	var taken: Array[Rect2] = footprints.duplicate()
	for data: Dictionary in life._blocked_props:
		var size: Array = data.get("size",[32,32])
		var box := Vector2(float(size[0]),float(size[1]))
		taken.append(Rect2(Vector2(data["at"][0],data["at"][1])-box/2.0,box))
	for spec: Dictionary in layout.get("critters",[]):
		var a: Array = spec["rect"]
		var rect := Rect2(a[0],a[1],a[2]-a[0],a[3]-a[1])
		var open: Array[Vector2] = []
		for cell: Vector2i in terrain_cells:
			if not rect.has_point(Vector2(cell)) or terrain_cells[cell] in VoxelLife.WALKABLE_NOT:
				continue
			var under: bool = false
			for footprint: Rect2 in taken:
				if footprint.grow(8).has_point(Vector2(cell)):
					under = true
					break
			if not under:
				open.append(Vector2(cell))
		if open.is_empty():
			continue
		var kind: String = String(spec.get("kind","chicken"))
		for i: int in int(spec.get("count",1)):
			var critter := Critter.new()
			critter.kind = kind
			critter.colors = spec.get("colors",[])
			critter.cells = open
			critter.seed = Shapes.place_seed(int(a[0]),int(a[1]),index*31+i,9)
			critter.speed = float(spec.get("speed",1.4 if kind=="dog" else 0.9))
			critter.scale = Vector3.ONE*float(spec.get("scale",1.0))
			add_child(critter)
			critters.append(critter)
		index += 1

var _static_chunks: Dictionary[Vector2i, Node3D] = {}

## The shared node the still props of a neighbourhood (a GROVE square) batch in.
func _static_chunk(at: Vector3) -> Node3D:
	var chunk := Vector2i(floori(at.x/GROVE),floori(at.z/GROVE))
	if not _static_chunks.has(chunk):
		_static_chunks[chunk] = _node()
	return _static_chunks[chunk]

## The ground style at a spot; an area's edge wanders like a seam between kinds.
func _ground_style(at: Vector2, kind: String) -> Dictionary:
	if not ground_areas.is_empty():
		at += Vector2(seam_noise.get_noise_2d(at.x,at.y),seam_noise.get_noise_2d(at.y+977.0,at.x))*40.0
	for entry: Dictionary in ground_areas:
		if (entry["rect"] as Rect2).has_point(at) and (entry["styles"] as Dictionary).has(kind):
			return entry["styles"][kind]
	return ground_styles.get(kind,{})

func _flora_at(at: Vector2) -> Dictionary:
	for entry: Dictionary in flora_regions:
		if (entry["rect"] as Rect2).has_point(at):
			return entry["style"]
	return flora

## One tree at `at`, its species, size and turn drawn from `random` (the planting's own,
## seeded by its place; the map's shared `rng` when none), its crown in the colours of the
## flora it stands in (`crown_colors`: an area's own, else the map's).
func _tree(at: Vector3, pink: bool, local: Dictionary = {}, random: RandomNumberGenerator = null) -> void:
	if local.is_empty():
		local = flora
	if random == null:
		random = rng
	var choices: Array = local.get("tree_types",["pine","broadleaf","broadleaf","slender","shrub"])
	var species: String = "blossom" if pink else String(choices[random.randi_range(0,choices.size()-1)])
	var size: float = random.randf_range(0.82,1.32)
	var scale := Vector3(size*random.randf_range(0.86,1.18),size*random.randf_range(0.90,1.23),size)
	var frame := Transform3D(Basis(Vector3.UP,random.randf()*TAU)*Basis.from_scale(scale),at)
	# Trees near each other share one grove node: one batch per colour and one crown
	# MultiMesh per silhouette instead of a handful of draws for every tree.
	var chunk := Vector2i(floori(at.x/GROVE),floori(at.z/GROVE))
	if not _groves.has(chunk):
		var grove: Node3D = _node()
		_groves[chunk] = {"node":grove,"crowns":{}}
		occluders.append({"node":grove})
	var colors: Array = (local.get("crown_colors",{}) as Dictionary).get(species,[])
	tree_shapes.build(_groves[chunk]["node"],shapes,species,random.randi_range(0,5),frame,_groves[chunk]["crowns"],colors)
	if ground != null and species!="shrub":
		ground.roots(at,size)
	for petal: int in 10 if pink else 3:
		var drop := Vector3(random.randf_range(-1.8,1.8),0.032+petal*0.001,random.randf_range(-1.8,1.8))
		if landmass == null or landmass.contains(Vector2(at.x+drop.x,at.z+drop.z)*UNIT):
			shapes.box(self,at+drop,Vector3(0.1,0.025,0.08),"d095ae" if pink else "9c995e")

## Draws a look (a door's closed state, a floor item) into a node of the view's own; false
## if no props file knows its kind.
func draw_look(into: Shapes, parent: Node3D, data: Dictionary) -> bool:
	var size: Array = data.get("size",[32,32])
	parent.rotation.y = deg_to_rad(float(data.get("rotation",0)))
	return _draw_kind(into,parent,data,float(size[0])/UNIT,float(size[1])/UNIT)

func _draw_kind(into: Shapes, root: Node3D, data: Dictionary, w: float, d: float) -> bool:
	return furniture.draw(into,root,data,w,d) or fixtures.draw(into,root,data,w,d) or trade_props.draw(into,root,data,w,d) or wilds.draw(into,root,data,w,d) \
		or shrine_props.draw(into,root,data,w,d) or woods.draw(into,root,data,w,d) or town.draw(into,root,data,w,d) \
		or waterside.draw(into,root,data,w,d) or garden.draw(into,root,data,w,d) or household.draw(into,root,data,w,d)

func _prop(data: Dictionary) -> void:
	var a: Array = data.get("at",[0,0])
	var at: Vector3 = point(Vector2(a[0],a[1]))
	if data.get("on_cliff",false) and cliffs != null:
		# Stands on the rock's top where the cliffs raised it (a boulder, a flag on a shelf):
		# the lowest rock under its footprint, so no part of it hangs over open ground.
		var extent: Array = data.get("size",[16,16])
		var box := Vector2(float(extent[0]),float(extent[1]))
		at.y = cliffs.footing(Rect2(Vector2(a[0],a[1])-box/2.0,box),data.get("perch","")=="highest")
	# `elevation`: up or down from there (what is seen far below a ledge, a pad in the air).
	at.y += float(data.get("elevation",0.0))
	var root: Node3D = _node(at)
	root.rotation.y = deg_to_rad(float(data.get("rotation",0)))
	var size: Array = data.get("size",[64,32])
	var w: float = float(size[0])/UNIT
	var d: float = float(size[1])/UNIT
	# A prop that never fades, hides or moves as a whole batches with its neighbours (its
	# swaying, glowing and smoking parts are nodes of their own and stay so).
	var shown_alone: bool = data.get("occludes",false) or data.get("wall_mounted",false) or data.has("portal") 		or data["kind"] in ["window","wall_scroll","closed_door"]
	if not shown_alone:
		shapes.merge(root,_static_chunk(at))
	if _draw_kind(shapes,root,data,w,d):
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
