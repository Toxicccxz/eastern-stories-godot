class_name VoxelWater
extends RefCounted

## Water cells (`water`, `deep_water`, `shallow_water`, and the stream at a gorge's
## bottom) as a rippling surface set into the ground, with earth or stone banks, foam
## where it meets rock and, for clear shallows, a stony bed seen through it. Layout
## `water`: per kind {"level", "colors" (edge to deep), "depth" (px to the deepest
## colour), "flow" [x, z], "speed", "clear", "foam", "swell" (wave height, units) and
## "swell_speed"}, then `areas` overriding by rect.
## Presentation only: the TileMap's water still decides what can be walked.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
const SHADER = preload("res://presentation/voxel/shaders/water.gdshader")
const CLEAR = preload("res://presentation/voxel/shaders/water_clear.gdshader")
const KINDS: Array[String] = ["water","deep_water","shallow_water"]
const CHUNK: int = 256
const NEIGHBOURS: Array[Vector2i] = [Vector2i(16,0),Vector2i(-16,0),Vector2i(0,16),Vector2i(0,-16)]
const DEFAULTS: Dictionary = {
	"water": {"level": -0.16, "colors": ["5d8a86", "3f6f70", "2c5559"]},
	"deep_water": {"level": -0.22, "colors": ["3c6a68", "264c4f", "15302f"], "depth": 80},
	"shallow_water": {"level": 0.06, "colors": ["8fb3ab", "6d9a96", "557f7f"], "clear": true},
}
var config: Dictionary = {}
var root: Node3D
## Cell -> its surface height and settings, for every water cell drawn.
var levels: Dictionary[Vector2i, float] = {}
var looks: Dictionary[Vector2i, Dictionary] = {}
var materials: Dictionary[String, ShaderMaterial] = {}
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
	return merged

func build(parent: Node3D, cells: Dictionary[Vector2i, String], cliffs: VoxelCliffs, shapes: Shapes, rng: RandomNumberGenerator) -> void:
	root = Node3D.new()
	root.name = "Water"
	parent.add_child(root)
	if levels.is_empty():
		return
	var depth: Dictionary[Vector2i, float] = _distances()
	var surfaces: Dictionary[String, SurfaceTool] = {}
	var keys: Dictionary[String, String] = {}
	var banks := SurfaceTool.new()
	banks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bank_count: int = 0
	for cell: Vector2i in levels:
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
			if levels.has(next):
				# A step between two water levels: a little spill of foaming water.
				var other: float = levels[next]
				if other < level-0.01:
					_quad(surface,a+Vector3.UP*level,b+Vector3.UP*level,b+Vector3.UP*other,a+Vector3.UP*other,Vector3(shift.x,0,shift.y)/16.0,Color(base.lightened(0.2).srgb_to_linear(),1.0))
				continue
			if not cells.has(next) and not (cliffs != null and cliffs.heights.has(next)):
				continue
			# The bank: from below the surface up to the ground (or the rock's foot). A stream
			# at a pit's bottom, or beside a pit, has the pit's own wall there instead.
			var top: float = 0.0
			if cliffs != null and (cliffs.heights.get(next,0.0)<0.0 or cliffs.heights.get(cell,0.0)<0.0) or top <= level:
				continue
			var normal := Vector3(-shift.x,0,-shift.y)/16.0
			var bank: Array = look.get("bank",config.get("bank",["5a5142","4c4539","665c4a"]))
			var low: float = level-0.35
			banked[cell] = true
			_quad(banks,a+Vector3.UP*top,b+Vector3.UP*top,b+Vector3.UP*low,a+Vector3.UP*low,normal,Color(String(bank[absi(cell.x+cell.y)/16%bank.size()])).srgb_to_linear())
			bank_count += 1
		if look.get("clear",false):
			# The bed under clear water: dark grit and stones, seen through the surface.
			var bed: Array = look.get("bed",["5d5a4c","6b6756","4f4c41"])
			shapes.box(root,Vector3(cell.x/32.0,level-0.3,cell.y/32.0),Vector3(0.5,0.06,0.5),String(bed[absi(cell.x*3+cell.y)/16%bed.size()]))
			if rng.randf()<float(look.get("stones",0.35)):
				var size: float = rng.randf_range(0.1,0.24)
				shapes.shard(root,Vector3(cell.x/32.0+rng.randf_range(-0.18,0.18),level-0.24,cell.y/32.0+rng.randf_range(-0.18,0.18)),Vector3(size*1.3,size*0.6,size),String(bed[rng.randi_range(0,bed.size()-1)]),rng.randi(),rng.randf()*TAU)
	for surface_key: String in surfaces:
		var instance := MeshInstance3D.new()
		instance.mesh = surfaces[surface_key].commit()
		instance.material_override = materials[keys[surface_key]]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)
	if bank_count>0:
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.6
		var instance := MeshInstance3D.new()
		instance.mesh = banks.commit()
		instance.material_override = material
		root.add_child(instance)

func _material(look: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CLEAR if look.get("clear",false) else SHADER
	var flow: Array = look.get("flow",[0,0])
	material.set_shader_parameter("flow",Vector2(float(flow[0]),float(flow[1])))
	material.set_shader_parameter("speed",float(look.get("speed",0.35)))
	material.set_shader_parameter("glint",Color(String(look.get("glint","cfe3e0"))))
	material.set_shader_parameter("foam",Color(String(look.get("foam_color","dcebe6"))))
	material.set_shader_parameter("clarity",float(look.get("clarity",1.0)))
	material.set_shader_parameter("sky",float(look.get("sky",0.22)))
	material.set_shader_parameter("swell",float(look.get("swell",0.0)))
	material.set_shader_parameter("swell_speed",float(look.get("swell_speed",1.6)))
	return material

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
