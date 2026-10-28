extends RefCounted

func run_all(_tree: SceneTree) -> Dictionary:
	var failures: Array[String] = []
	var union := VoxelCellSurface.new()
	union.cells[Vector3i.ZERO] = Color.RED
	union.cells[Vector3i.RIGHT] = Color.GREEN
	var mesh: ArrayMesh = union.mesh()
	if union.face_count!=10:
		failures.append("adjacent differently coloured leaves must not retain their shared faces")
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var correct_winding: bool = true
	for i: int in range(0,vertices.size(),3):
		correct_winding = correct_winding and (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).dot(normals[i])>0
	if not correct_winding:
		failures.append("union faces must face outward for opaque and shadow rendering")
	var canopy := VoxelCellSurface.new()
	canopy.ellipsoid(Vector3(0,2,0),Vector3.ONE,["54885a","8aaa68"],71)
	canopy.mesh()
	var original_faces: int = canopy.face_count
	canopy.ellipsoid(Vector3(0,2,0),Vector3.ONE,["cf8bab","eeb3c7"],71)
	canopy.mesh()
	if canopy.face_count!=original_faces:
		failures.append("overlapping crowns must overwrite occupancy instead of duplicating coplanar surfaces")
	var land := VoxelLandmass.new()
	var source: Dictionary[Vector2i,String] = {
		Vector2i(-24,-24):"grass",Vector2i(8,8):"street",
		Vector2i(800,800):"boundary",Vector2i(8,984):"path"}
	var required: Array[Rect2] = [Rect2(-128,-64,96,64)]
	land.build(source,required,{})
	var terrain: Dictionary[Vector2i,String] = land.terrain(source)
	if terrain.get(Vector2i(-24,-24))!="grass" or terrain.get(Vector2i(8,984))!="path" or not land.supports(Vector2(-80,-32),20):
		failures.append("authored terrain and building footprints stay supported, including negative coordinates")
	if land.contains(Vector2(8,480)) or land.contains(Vector2(800,800)) or terrain.has(Vector2i(800,800)):
		failures.append("unrelated scenery cannot fill the entire bounds between distant map sections")
	var finite: bool = true
	for cell: Vector2i in land.patches:
		var center: Vector2 = (Vector2(cell)+Vector2.ONE*0.5)*32
		finite = finite and (Rect2(-272,-208,448,384).has_point(center) or Rect2(-128,832,288,288).has_point(center))
	if not finite:
		failures.append("the scenery extension must stay within its bounded shoulder")
	var holder := Node3D.new()
	land.make_base(holder)
	var base := holder.get_child(0) as MeshInstance3D
	var base_arrays: Array = base.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = base_arrays[Mesh.ARRAY_VERTEX]
	var base_normals: PackedVector3Array = base_arrays[Mesh.ARRAY_NORMAL]
	var edges: Dictionary[String,int] = {}
	var base_winding: bool = true
	for i: int in range(0,positions.size(),3):
		base_winding = base_winding and (positions[i+2]-positions[i]).cross(positions[i+1]-positions[i]).dot(base_normals[i])>0
		for j: int in 3:
			var a: String = str(positions[i+j])
			var b: String = str(positions[i+(j+1)%3])
			var key: String = a+"/"+b if a<b else b+"/"+a
			edges[key] = edges.get(key,0)+1
	var closed: bool = true
	for count: int in edges.values():
		closed = closed and count==2
	if not closed or not base_winding:
		failures.append("the irregular soil base must be closed and face outward, including its stepped corners")
	holder.free()
	# 大石板: a whole 6×4-cell square is laid at once from any of its cells, every cell once,
	# round a doorway's footprint; the stones are long (several cells), not cobbles.
	var ground := VoxelGround.new()
	ground.shapes = preload("res://presentation/voxel/props/voxel_shapes.gd").new()
	ground.parent = Node3D.new()
	ground.rng = RandomNumberGenerator.new()
	ground.rng.seed = 3
	ground.noise = FastNoiseLite.new()
	ground.footprints = [Rect2(64,48,16,16)]
	var square: Dictionary[Vector2i,String] = {}
	for y: int in 4:
		for x: int in 6:
			square[Vector2i(8+x*16,8+y*16)] = "town_ground"
	var painted: Dictionary[Vector2i,bool] = {}
	ground.slabs(Vector2i(40,40),square,painted,{"lengths":[2,3],"depths":[1,2],"sunk":0.0,"broken":0.0})
	var beds: int = 0
	for entry: Dictionary in ground.shapes.batches.values():
		beds += (entry.get("transforms",[]) as Array).size() if String(entry.get("color","")) == "6f6c5e" else 0
	if painted.size()!=23 or painted.has(Vector2i(72,56)) or beds<6 or beds>14:
		failures.append("old slabs cover the stretch once, round the doorway, in long stones: %d cells, %d stones" % [painted.size(),beds])
	# Where the slabs meet another style (the 官道's 青石板), neither runs its stones into the other.
	var slab_style: Dictionary = {"style":"slabs","size":[3,2]}
	var road_style: Dictionary = {"style":"paving"}
	ground.style_at = func(cell: Vector2i, _kind: String) -> Dictionary: return slab_style if cell.x>=56 else road_style
	ground.rng.seed = 7
	var seam_ok: bool = true
	for road_first: bool in [true,false]:
		var laid: Dictionary[Vector2i,bool] = {}
		for pass_road: bool in [road_first,not road_first]:
			for cell: Vector2i in square.keys():
				if laid.has(cell) or (cell.x<56)!=pass_road:
					continue
				var before: Array = laid.keys()
				if pass_road:
					ground.paving(cell,square,laid,road_style)
				else:
					ground.slabs(cell,square,laid,slab_style)
				for done: Vector2i in laid:
					if not done in before:
						seam_ok = seam_ok and (done.x<56)==pass_road
	if not seam_ok:
		failures.append("slabs and other paving stop at the line between their styles")
	ground.parent.free()
	# Seams between road surfaces wander within two cells either side; a one-cell rut keeps its line.
	var geometry := VoxelMapGeometry.new()
	geometry.seam_noise.seed = 3511
	geometry.seam_noise.frequency = 0.03
	var road: Dictionary[Vector2i,String] = {}
	for y: int in 24:
		for x: int in 24:
			road[Vector2i(8+x*16,8+y*16)] = "street" if x < 12 else "path"
	for y: int in 24:
		road[Vector2i(8+4*16,8+y*16)] = "riverbank"
	var original: Dictionary[Vector2i,String] = road.duplicate()
	geometry._fray_seams(road)
	var into_path: int = 0
	var into_street: int = 0
	var far: int = 0
	var rut: int = 0
	for cell: Vector2i in road:
		var column: int = (cell.x-8)/16
		if road[cell] != original[cell]:
			into_path += 1 if original[cell] == "street" and column != 4 else 0
			into_street += 1 if original[cell] == "path" else 0
			far += 1 if column < 9 or column > 14 else 0
			rut += 1 if column in [3,4,5] else 0
	if into_path < 4 or into_street < 4 or far > 0 or rut > 0:
		failures.append("the street/path seam interlocks within two cells (%d into the path, %d into the street, %d too far) and the rut stays (%d)" % [into_path,into_street,far,rut])
	geometry.free()
	# Trees in clumps: of each spacing cluster's cells one is chosen by the cluster's place, the
	# same every time and not always in its first row; the roll is shaded by a slow noise, so a
	# wood of chance 1 still has clearings, and none once the shading is off.
	var planter := VoxelMapGeometry.new()
	planter.flora = {"tree_chance":1.0}
	var sites: Dictionary = {}
	for cy: int in 30:
		for cx: int in 30:
			var cluster := Vector3i(cx,cy,64)
			sites[cluster] = []
			for y: int in 4:
				for x: int in 4:
					(sites[cluster] as Array).append(Vector2i(cx*64+8+x*16,cy*64+8+y*16))
	var first: Dictionary = planter._tree_sites(sites)
	var again: Dictionary = planter._tree_sites(sites)
	var top_row: int = 0
	var same: bool = first.size()==again.size()
	for cluster: Vector3i in first:
		top_row += 1 if (first[cluster] as Vector2i).y == cluster.y*64+8 else 0
		same = same and again.get(cluster)==first[cluster]
	if not same or first.size() < 360 or first.size() > 870 or top_row == 0 or top_row*2 > first.size():
		failures.append("tree sites repeat exactly, leave clearings (%d of 900 planted) and spread over the cluster's rows (%d in the first)" % [first.size(),top_row])
	planter.flora = {"tree_chance":1.0,"grove_contrast":0.0}
	if planter._tree_sites(sites).size() != 900:
		failures.append("without grove contrast every cluster of a chance-1 wood gets its tree")
	planter.free()
	# Every region's outdoor maps have, under their region's flora.json, four or more grass and
	# flower colours (the foliage indexes them) and crown colours for every species their tree
	# lists name, so the code's own greens are only a fallback.
	var thin: Array[String] = []
	for region: String in DirAccess.get_directories_at("res://data"):
		var dir: String = "res://data/%s/voxel" % region
		if not DirAccess.dir_exists_absolute(dir):
			continue
		if not FileAccess.file_exists(dir+"/flora.json"):
			thin.append(region+": no flora.json")
			continue
		var defaults: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir+"/flora.json"))
		for file: String in DirAccess.get_files_at(dir):
			if file in ["flora.json","light.json"]:
				continue
			var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir+"/"+file))
			if layout.get("indoor",false) and not layout.get("courtyard",false):
				continue
			var merged: Dictionary = VoxelMapGeometry.merge_flora(defaults,layout.get("flora",{}))
			if merged.get("grass_colors",[]).size() < 4 or merged.get("flower_colors",[]).size() < 4:
				thin.append("%s/%s: grass or flower colours" % [region,file])
			var parts: Array = [merged]+merged.get("areas",[])+(merged.get("zones",{}) as Dictionary).values()
			for part: Dictionary in parts:
				var local: Dictionary = VoxelMapGeometry.merge_flora(merged,part)
				var named: Array = part.get("tree_types",[])+part.get("cliff_tree_types",[])
				for band: Dictionary in part.get("bands",[]):
					named.append_array(band.get("types",[]))
				for species: String in named:
					if species != "dead" and not local.get("crown_colors",{}).has(species):
						thin.append("%s/%s: no crown colours for %s" % [region,file,species])
	if not thin.is_empty():
		failures.append("every outdoor map has its region's full flora: %s" % [thin])
	# A prop varies by where it stands, the same every build: two stone lanterns at one spot
	# draw alike, at another spot not.
	var garden: RefCounted = preload("res://presentation/voxel/props/voxel_garden.gd").new()
	var forms: Array[String] = []
	for spot: Vector3 in [Vector3(4,0,6),Vector3(4,0,6),Vector3(9,0,2)]:
		var into: RefCounted = preload("res://presentation/voxel/props/voxel_shapes.gd").new()
		garden.rng = RandomNumberGenerator.new()
		garden.rng.seed = 5
		var stand := Node3D.new()
		stand.position = spot
		garden.draw(into,stand,{"kind":"stone_lantern"},0.5,0.5)
		var form: Array[String] = []
		for entry: Dictionary in into.batches.values():
			for transform: Transform3D in entry["transforms"]:
				form.append(String(entry["color"])+str(transform))
		form.sort()
		forms.append(",".join(form)+str(stand.rotation))
		stand.free()
	if forms[0] != forms[1] or forms[1] == forms[2]:
		failures.append("a stone lantern's variations follow its place: alike at one spot, unlike at another")
	# A building's facade keys (三镇立面分化): a house written without them draws as it did before
	# they existed (its forms pinned); each of them adds or recolours forms, the same every build.
	var house: Dictionary = {"wall":"c8c4b8","roof":"5c6468","timber":"6a4a38","construction":"plaster","height":3.2,"roof_form":"gable","rise":1.2,"porch":"tiled","goods":"none","lanterns":false,"bay":5}
	var stage := Node3D.new()
	_tree.root.add_child(stage)
	var built: Callable = func(data: Dictionary) -> Array:
		var into: RefCounted = preload("res://presentation/voxel/props/voxel_shapes.gd").new()
		var architecture: RefCounted = preload("res://presentation/voxel/props/voxel_architecture.gd").new()
		var site := Node3D.new()
		stage.add_child(site)
		architecture.shapes = into
		architecture.parent = site
		architecture.rng = RandomNumberGenerator.new()
		architecture.rng.seed = 11
		architecture.noise = FastNoiseLite.new()
		architecture.build(Vector3(20,0,12),6.0,5.0,data,[Vector3(0,0,2.5)] as Array[Vector3])
		var colours: Dictionary = {}
		var count: int = 0
		for entry: Dictionary in into.batches.values():
			count += entry["transforms"].size()
			colours[entry["color"]] = true
		site.queue_free()
		return [count,colours]
	var plain: Array = built.call(house)
	var twice: Array = built.call(house)
	if plain[0] != 697 or twice[0] != plain[0]:
		failures.append("a house written without the facade keys draws its %d forms as before" % plain[0])
	var worn: Array = built.call(house.merged({"worn":0.3,"worn_colors":["8e9088","7a8a6a"]}))
	if worn[0] != plain[0] or not worn[1].has("8e9088") or not worn[1].has("7a8a6a"):
		failures.append("`worn` recolours a share of the tiles pale and mossy without adding forms")
	var beasts: Array = built.call(house.merged({"ridge_beasts":{"count":3,"color":"3e3f3a"}}))
	var xieshan: Array = built.call(house.merged({"roof_form":"xieshan"},true))
	var peeled: Array = built.call(house.merged({"whitewash":0.5,"peel":["9a8a78"]}))
	var dado: Array = built.call(house.merged({"wall_bands":{"color":"6b6e66","height":1.0}}))
	if beasts[0] != plain[0]+12 or not beasts[1].has("3e3f3a"):
		failures.append("`ridge_beasts` sits a file of three beasts at each end of the ridge (%d forms over %d)" % [beasts[0],plain[0]])
	if xieshan[0] == plain[0] or not xieshan[1].has("6a4a38"):
		failures.append("歇山: a gable over a hip, its 山花 walls set in from the ends (%d forms over %d)" % [xieshan[0],plain[0]])
	if peeled[0] <= plain[0] or not peeled[1].has("9a8a78") or dado[0] <= plain[0] or not dado[1].has("6b6e66"):
		failures.append("`whitewash` peels to the brick under it and `wall_bands` paints a dado along the foot of the wall")
	stage.queue_free()
	return {"assertions":18,"failures":failures}
