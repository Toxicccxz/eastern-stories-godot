class_name VoxelWater
extends RefCounted

## Water cells (`water`, `deep_water`, `shallow_water`, and the stream at a gorge's
## bottom) as a rippling surface set into the ground, with earth or stone banks, foam
## where it meets rock, and seen through it a bed that steps down from the bank, with what
## lives and lies there (VoxelWaterLife). Layout `water`: per kind {"level", "colors" (edge to
## deep), "depth" (px to the deepest colour), "flow" [x, z], "speed", "clear" (true a spring,
## false a dark pool), "murk", "tint", "caustics", "bed" (colours), "bed_depth", "bed_slope",
## "life" (VoxelWaterLife), "foam", "swell" (wave height, units) and "swell_speed", "sunset":
## {"color", "amount"}: how far it goes to that colour at dusk}, then `areas` overriding by rect.
## Presentation only: the TileMap's water still decides what can be walked.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
const SHADER = preload("res://presentation/voxel/shaders/water.gdshader")
const WaterLife = preload("res://presentation/voxel/terrain/voxel_water_life.gd")
const KINDS: Array[String] = ["water","deep_water","shallow_water"]
const CHUNK: int = 256
const NEIGHBOURS: Array[Vector2i] = [Vector2i(16,0),Vector2i(-16,0),Vector2i(0,16),Vector2i(0,-16)]
const DEFAULTS: Dictionary = {
	"water": {"level": -0.16, "colors": ["5d8a86", "3f6f70", "2c5559"]},
	"deep_water": {"level": -0.22, "colors": ["3c6a68", "264c4f", "15302f"], "depth": 80},
	"shallow_water": {"level": 0.06, "colors": ["8fb3ab", "6d9a96", "557f7f"], "clear": true},
}
## How deep the bed goes at most (units under the surface), by kind: a ford can be waded.
const BED_DEPTH: Dictionary = {"water": 1.1, "deep_water": 1.8, "shallow_water": 0.3}
## How much of the water's colour is in a unit of it, by kind (the shader's `murk`).
const MURK: Dictionary = {"water": 0.85, "deep_water": 0.75, "shallow_water": 0.9}
const DEFAULT_BED: Array = ["7a7058","6b6450","857a60","6e6a52"]
var config: Dictionary = {}
var root: Node3D
## Cell -> the height of the bed under it.
var beds: Dictionary[Vector2i, float] = {}
## How deep the landmass's slab goes (VoxelLandmass.depth): no bed lies under its foot.
var base_depth: float = 2.2
## Cell -> its surface height and settings, for every water cell drawn.
var levels: Dictionary[Vector2i, float] = {}
var looks: Dictionary[Vector2i, Dictionary] = {}
var materials: Dictionary[String, ShaderMaterial] = {}
## Material key -> how far its water goes to its `sunset` colour at full dusk (those that do).
var sunsets: Dictionary[String, float] = {}
var _dusk: float = -1.0
## The merged look per kind and the areas that cover a cell (look_at): shared, never changed.
var _look_cache: Dictionary[String, Dictionary] = {}
## Water cells that got an earth or stone bank on some side.
var banked: Dictionary[Vector2i, bool] = {}

func _init(settings: Dictionary = {}) -> void:
	config = settings

## Every water kind cell, plus `extra` cells (cell -> {"kind", "level"}) such as a pit's bed.
func collect(cells: Dictionary[Vector2i, String], extra: Dictionary = {}) -> void:
	for cell: Vector2i in cells:
		if cells[cell] in KINDS:
			var look: Dictionary = look_at(cell,cells[cell])
			looks[cell] = look
			levels[cell] = float(look.get("level",-0.16))
	for cell: Vector2i in extra:
		var look: Dictionary = look_at(cell,String(extra[cell]["kind"]))
		looks[cell] = look
		levels[cell] = float(extra[cell]["level"])

func look_at(cell: Vector2i, kind: String) -> Dictionary:
	var key: String = kind
	var at: int = 0
	for area: Dictionary in config.get("areas",[]):
		var box: Array = area["rect"]
		if Rect2(box[0],box[1],box[2]-box[0],box[3]-box[1]).has_point(Vector2(cell)) and (not area.has("kinds") or kind in area["kinds"]):
			key += ":%d" % at
		at += 1
	if _look_cache.has(key):
		return _look_cache[key]
	var merged: Dictionary = (DEFAULTS.get(kind,DEFAULTS["water"]) as Dictionary).duplicate()
	merged.merge(config.get("kinds",{}).get(kind,{}),true)
	merged["kind"] = kind
	var index: int = 0
	for area: Dictionary in config.get("areas",[]):
		var r: Array = area["rect"]
		if Rect2(r[0],r[1],r[2]-r[0],r[3]-r[1]).has_point(Vector2(cell)) and (not area.has("kinds") or kind in area["kinds"]):
			merged.merge(area,true)
			merged["area"] = index
		index += 1
	_look_cache[key] = merged
	return merged

## `breathe` (the geometry's frame slicer) is awaited every few hundred cells: a sea that runs on
## past the map (番坊) is tens of thousands of them. `ambience` sets the fish and weed stirring.
func build(parent: Node3D, cells: Dictionary[Vector2i, String], cliffs: VoxelCliffs, shapes: Shapes, rng: RandomNumberGenerator, breathe: Callable = Callable(), ambience: VoxelAmbience = null) -> void:
	root = Node3D.new()
	root.name = "Water"
	parent.add_child(root)
	if levels.is_empty():
		return
	var depth: Dictionary[Vector2i, float] = _distances()
	_shape_beds(depth,cliffs)
	var surfaces: Dictionary[String, SurfaceTool] = {}
	var keys: Dictionary[String, String] = {}
	# The bed, its steps and the banks down to it, cut in chunks like the surface.
	var grounds: Dictionary[Vector2i, SurfaceTool] = {}
	var done: int = 0
	for cell: Vector2i in levels:
		done += 1
		if breathe.is_valid() and done % 512 == 0:
			await breathe.call()
		var look: Dictionary = looks[cell]
		var level: float = levels[cell]
		var key: String = "%s:%s" % [look["kind"],look.get("area",-1)]
		var chunk := Vector2i(floori(float(cell.x)/CHUNK),floori(float(cell.y)/CHUNK))
		var surface_key: String = key+"@%d,%d" % [chunk.x,chunk.y]
		if not surfaces.has(surface_key):
			surfaces[surface_key] = SurfaceTool.new()
			surfaces[surface_key].begin(Mesh.PRIMITIVE_TRIANGLES)
			keys[surface_key] = key
			if not materials.has(key):
				materials[key] = _material(look)
				var sunset: Dictionary = look.get("sunset",{})
				if not sunset.is_empty():
					materials[key].set_shader_parameter("sunset",Color(String(sunset.get("color","e8904a"))))
					sunsets[key] = float(sunset.get("amount",0.4))
		if not grounds.has(chunk):
			grounds[chunk] = SurfaceTool.new()
			grounds[chunk].begin(Mesh.PRIMITIVE_TRIANGLES)
		var ground: SurfaceTool = grounds[chunk]
		var surface: SurfaceTool = surfaces[surface_key]
		var colors: Array = look.get("colors",["5d8a86","3f6f70","2c5559"])
		var t: float = clampf(depth.get(cell,0.0)/float(look.get("depth",48)),0.0,1.0)*(colors.size()-1)
		var base: Color = Color(String(colors[floori(t)])).lerp(Color(String(colors[mini(ceili(t),colors.size()-1)])),t-floori(t))
		var foam: float = float(look.get("foam",0.0))
		for shift: Vector2i in [Vector2i(16,0),Vector2i(-16,0),Vector2i(0,16),Vector2i(0,-16),Vector2i(16,16),Vector2i(-16,16),Vector2i(16,-16),Vector2i(-16,-16)]:
			var next: Vector2i = cell+shift
			if levels.has(next):
				continue
			var rocky: bool = cliffs != null and cliffs.heights.get(next,0.0)>0.0 or cells.get(next,"") in ["rock","cliff"]
			foam = maxf(foam,float(look.get("rock_foam",0.75)) if rocky else float(look.get("bank_foam",0.18)))
		var x0: float = (cell.x-8)/32.0
		var z0: float = (cell.y-8)/32.0
		var x1: float = x0+0.5
		var z1: float = z0+0.5
		var tint := Color(base.srgb_to_linear(),foam)
		_quad(surface,Vector3(x0,level,z0),Vector3(x1,level,z0),Vector3(x1,level,z1),Vector3(x0,level,z1),Vector3.UP,tint)
		var bed: float = beds[cell]
		var bed_color: Color = _bed_color(cell,look)
		if not _in_pit(cliffs,cell):
			_quad(ground,Vector3(x0,bed,z0),Vector3(x1,bed,z0),Vector3(x1,bed,z1),Vector3(x0,bed,z1),Vector3.UP,bed_color.srgb_to_linear())
		for shift: Vector2i in NEIGHBOURS:
			var next: Vector2i = cell+shift
			var a: Vector3
			var b: Vector3
			if shift.x > 0:
				a = Vector3(x1,0,z1)
				b = Vector3(x1,0,z0)
			elif shift.x < 0:
				a = Vector3(x0,0,z0)
				b = Vector3(x0,0,z1)
			elif shift.y > 0:
				a = Vector3(x0,0,z1)
				b = Vector3(x1,0,z1)
			else:
				a = Vector3(x1,0,z0)
				b = Vector3(x0,0,z0)
			var normal := Vector3(-shift.x,0,-shift.y)/16.0
			if levels.has(next):
				# A step between two water levels: a little spill of foaming water.
				var other: float = levels[next]
				if other < level-0.06:
					_quad(surface,a+Vector3.UP*level,b+Vector3.UP*level,b+Vector3.UP*other,a+Vector3.UP*other,Vector3(shift.x,0,shift.y)/16.0,Color(base.lightened(0.2).srgb_to_linear(),1.0))
				# A step down in the bed toward the deep: its face, a shade darker than the bed.
				if beds[next] < bed-0.01 and not _in_pit(cliffs,next):
					_quad(ground,a+Vector3.UP*bed,b+Vector3.UP*bed,b+Vector3.UP*beds[next],a+Vector3.UP*beds[next],-normal,bed_color.darkened(0.18).srgb_to_linear())
				continue
			if not cells.has(next) and not (cliffs != null and cliffs.heights.has(next)):
				continue
			# The bank: from the ground (or the rock's foot) down to the bed, wet and darker under
			# the water. A stream at a pit's bottom, or beside a pit, has the pit's own wall there.
			if cliffs != null and (cliffs.heights.get(next,0.0)<0.0 or cliffs.heights.get(cell,0.0)<0.0):
				continue
			var bank: Array = look.get("bank",config.get("bank",["5a5142","4c4539","665c4a"]))
			var bank_color := Color(String(bank[absi(cell.x+cell.y)/16%bank.size()]))
			var top: float = 0.0
			var wet: float = minf(level-0.06,top)
			banked[cell] = true
			if wet < top-0.01:
				_quad(ground,a+Vector3.UP*top,b+Vector3.UP*top,b+Vector3.UP*wet,a+Vector3.UP*wet,normal,bank_color.srgb_to_linear())
			_quad(ground,a+Vector3.UP*wet,b+Vector3.UP*wet,b+Vector3.UP*bed,a+Vector3.UP*bed,normal,bank_color.lerp(bed_color,0.35).darkened(0.25).srgb_to_linear())
	for surface_key: String in surfaces:
		var instance := MeshInstance3D.new()
		instance.mesh = surfaces[surface_key].commit()
		instance.material_override = materials[keys[surface_key]]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)
	var bed_material := StandardMaterial3D.new()
	bed_material.vertex_color_use_as_albedo = true
	bed_material.roughness = 0.85
	for chunk: Vector2i in grounds:
		var instance := MeshInstance3D.new()
		instance.name = "Bed"
		instance.mesh = grounds[chunk].commit()
		instance.material_override = bed_material
		root.add_child(instance)
	await WaterLife.new(self,shapes,ambience,depth,cliffs).build(rng.seed,breathe)

## How deep the bed lies under each cell: a step down from the bank toward the middle (`bed_depth`
## units at most, `bed_slope` units a cell), in steps a voxel high, never under the landmass's
## foot nor a pit's floor.
func _shape_beds(depth: Dictionary[Vector2i, float], cliffs: VoxelCliffs) -> void:
	for cell: Vector2i in levels:
		var look: Dictionary = looks[cell]
		var kind: String = String(look["kind"])
		var deepest: float = float(look.get("bed_depth",BED_DEPTH.get(kind,1.1)))
		var slope: float = float(look.get("bed_slope",0.14))
		var wobble: float = float(absi(cell.x*7+cell.y*13)/16%3-1)*0.06
		var down: float = snappedf(clampf(0.22+depth.get(cell,0.0)/16.0*slope+wobble,0.18,maxf(deepest,0.18)),0.08)
		var bed: float = maxf(levels[cell]-down,-(base_depth-0.15))
		if _in_pit(cliffs,cell):
			bed = cliffs.heights[cell]
		beds[cell] = bed

## A cell's bed colour: its look's `bed` colours, in patches of paler sand and darker silt.
func _bed_color(cell: Vector2i, look: Dictionary) -> Color:
	var bed_colors: Array = look.get("bed",DEFAULT_BED)
	var color := Color(String(bed_colors[absi(cell.x*3+cell.y*7)/16%bed_colors.size()]))
	var patch: float = sin(cell.x*0.021+cell.y*0.013)*sin(cell.y*0.027-cell.x*0.009)
	return color.lightened(0.12) if patch > 0.35 else color.darkened(0.14) if patch < -0.4 else color

func _in_pit(cliffs: VoxelCliffs, cell: Vector2i) -> bool:
	return cliffs != null and cliffs.heights.get(cell,0.0) < 0.0

func _material(look: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var flow: Array = look.get("flow",[0,0])
	material.set_shader_parameter("flow",Vector2(float(flow[0]),float(flow[1])))
	material.set_shader_parameter("speed",float(look.get("speed",0.35)))
	material.set_shader_parameter("glint",Color(String(look.get("glint","cfe3e0"))))
	material.set_shader_parameter("foam",Color(String(look.get("foam_color","dcebe6"))))
	# `murk`: how much of its colour is in a unit of the water; a water whose text calls it dark
	# (`clear`: false) keeps its bed faint, a spring (`clear`: true) shows it plainly.
	var murk: float = float(MURK.get(String(look["kind"]),0.9))
	if look.has("clear"):
		murk = 0.6 if look["clear"] else 2.2
	material.set_shader_parameter("murk",float(look.get("murk",murk)))
	var colors: Array = look.get("colors",["5d8a86"])
	material.set_shader_parameter("tint",Color(String(look["tint"])) if look.has("tint") else Color.WHITE.lerp(Color(String(colors[0])),0.3))
	material.set_shader_parameter("caustics",float(look.get("caustics",0.55)))
	material.set_shader_parameter("sky",float(look.get("sky",0.22)))
	material.set_shader_parameter("swell",float(look.get("swell",0.0)))
	material.set_shader_parameter("swell_speed",float(look.get("swell_speed",1.6)))
	return material

## The hour's light on the water: `weight`, how much of the frame now is dusk.
func set_dusk(weight: float) -> void:
	if is_equal_approx(weight,_dusk):
		return
	_dusk = weight
	for key: String in sunsets:
		materials[key].set_shader_parameter("sunset_amount",sunsets[key]*weight)

## Pixels from each water cell to the nearest cell that is not water (its bank).
func _distances() -> Dictionary[Vector2i, float]:
	var result: Dictionary[Vector2i, float] = {}
	var frontier: Array[Vector2i] = []
	for cell: Vector2i in levels:
		for shift: Vector2i in NEIGHBOURS:
			if not levels.has(cell+shift):
				result[cell] = 0.0
				frontier.append(cell)
				break
	var head: int = 0
	while head < frontier.size():
		var at: Vector2i = frontier[head]
		head += 1
		for shift: Vector2i in NEIGHBOURS:
			var next: Vector2i = at+shift
			if levels.has(next) and result.get(next,INF) > result[at]+16.0:
				result[next] = result[at]+16.0
				frontier.append(next)
	return result

func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	surface.set_normal(normal)
	surface.set_color(color)
	var points: Array[Vector3] = [a,b,c,d]
	var outward: bool = (c-a).cross(b-a).dot(normal) > 0
	for index: int in [0,1,2,0,2,3] if outward else [0,2,1,0,3,2]:
		surface.add_vertex(points[index])
