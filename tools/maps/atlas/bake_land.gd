extends SceneTree
## The 沙盘's land (DECISIONS「总图」): a voxel world in 青绿山水 colours, towns in the valleys,
## ranges rising between them, a river, a sea and a sea of cloud round the rim, under the
## miniatures' own sun, and the roads: found over the land from each ordinary way's real doors,
## cut into it, each its own layer so a road can show once it has been walked. Run by bake.py
## after the miniatures: `-- <out dir>`.
const BLOCK: float = 1.5
## Half the land's columns on a side.
const SPAN: int = 694
## How far a road's cut reaches into the land beside it.
const CUT: float = 20.0
## How much the view's ray climbs per unit it runs on the ground.
const VIEW_RISE: float = 0.8667
const PITCH: float = 112.0
const PX: float = 4.0
const COS_X: float = 0.7071
const COS_Y: float = 0.4631
const STEP_UP: float = 0.7557
const REGION: Dictionary = {
	"snow": "green", "cloud": "green", "green": "green", "sanyen": "green", "choyin": "green", "sunhill": "forest", "latemoon": "forest",
	"oldpine": "forest", "chuenyu": "forest", "goathill": "brown", "temple": "teal", "waterfog": "teal", "canyon": "yellow", "guanbei": "steppe",
	"niling": "black", "village": "green", "city": "ochre", "death": "black",
}
const TONES: Dictionary = {
	"green": ["7a9a48", "3f8048", "1f6a64", "1f5a84"], "forest": ["527f40", "2a6a44", "1a5c5a", "1c507c"],
	"teal": ["6a9a58", "348068", "1f6c78", "20588c"], "brown": ["988a48", "7a6a40", "4f6658", "2c5874"],
	"yellow": ["d4a044", "bc7a30", "9a5028", "6a3626"], "steppe": ["c8b050", "a89c44", "708844", "447454"],
	"ochre": ["bc9c4c", "988844", "5e7a48", "386a68"], "black": ["4a443e", "38343c", "2c2c42", "22223e"],
}
const RIVER: Array[Vector2] = [Vector2(9.4, 3.4), Vector2(8.3, 4.2), Vector2(7.4, 4.9), Vector2(6.4, 5.3), Vector2(5.6, 5.55), Vector2(4.7, 5.5), Vector2(3.7, 5.55), Vector2(2.6, 5.75), Vector2(2.2, 6.6), Vector2(2.7, 7.6), Vector2(2.6, 9.2)]
const TRIBUTARY: Array[Vector2] = [Vector2(0.6, 1.5), Vector2(0.9, 2.9), Vector2(0.2, 4.9), Vector2(0.5, 5.8), Vector2(1.9, 6.4)]
## Road earth per tone: rut, packed earth, worn stone.
const ROAD: Dictionary = {
	"green": ["a88a50", "e2c282", "f4e0a8"], "forest": ["a08648", "d8ba7c", "ecd8a0"], "teal": ["a08c60", "dcc48c", "f0e0b0"],
	"brown": ["a08048", "dcb878", "f0d8a0"], "yellow": ["b47c40", "ecc07c", "f8dca0"], "steppe": ["a89a58", "dcc880", "ecdca0"],
	"ochre": ["a88a50", "e0c484", "f4e0a8"], "black": ["5a5660", "8a8490", "aca6b0"],
}
var terrain := FastNoiseLite.new()
var ridges := FastNoiseLite.new()
var warp := FastNoiseLite.new()
var grain := FastNoiseLite.new()
var cloud := FastNoiseLite.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var catalog: ContentCatalog = GameContent.catalog()
	var bake: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AtlasPictures.BAKE))
	var frame: Array = bake["frame"]
	var low := Vector2(frame[0], frame[1])
	var high := Vector2(frame[2], frame[3])
	var cells: Dictionary = {}
	var nodes: Array = []
	for cell: AtlasCell in catalog.atlas().cells():
		cells[String(cell.map_id)] = [cell.at.x / PITCH, cell.at.y / PITCH]
		nodes.append([cell.at, String(cell.map_id).get_slice(".", 0)])
	var trims: Dictionary = {}
	var doors: Dictionary = {}
	for map_id: String in bake["cells"]:
		var baked: Dictionary = bake["cells"][map_id]
		trims[map_id] = [float(baked["size"][0]), float(baked["size"][1]), float(baked["anchor"][0]), float(baked["anchor"][1])]
		doors[map_id] = {}
		for key: String in baked["pins"]:
			if key.begins_with("door:"):
				doors[map_id][key.trim_prefix("door:")] = Vector2(baked["pins"][key][0], baked["pins"][key][1])
	terrain.seed = 31
	terrain.frequency = 0.007
	terrain.fractal_octaves = 5
	ridges.seed = 7
	ridges.frequency = 0.0052
	ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridges.fractal_octaves = 5
	warp.seed = 11
	warp.frequency = 0.012
	grain.seed = 3
	grain.frequency = 0.09
	cloud.seed = 21
	cloud.frequency = 0.0075
	cloud.fractal_octaves = 4
	var began: int = Time.get_ticks_msec()
	var middle: Vector2 = (low + high) / 2.0
	var half: Vector2 = (high - low) / 2.0
	var span: int = SPAN
	var count: int = span * 2 + 1
	var flat := PackedByteArray()
	flat.resize(count * count)
	var centre := Vector2(3.5, 3.5) * PITCH
	var minis: String = ProjectSettings.globalize_path(AtlasPictures.DIRECTORY)
	# Under each miniature the land lies flat.
	for map_id: String in trims:
		var trim: Array = trims[map_id]
		var cell: Array = cells[map_id]
		var plane := Vector2(float(cell[0]), float(cell[1])) * PITCH
		var image: Image = Image.load_from_file(minis.path_join(map_id + ".png"))
		var reach: int = ceili((trim[0] + trim[1]) / 8.0 / BLOCK / 1.2)
		var at: Vector2i = Vector2i(((plane - centre) / BLOCK).round()) + Vector2i(span, span)
		for j: int in range(maxi(0, at.y - reach), mini(count, at.y + reach)):
			for i: int in range(maxi(0, at.x - reach), mini(count, at.x + reach)):
				var delta: Vector2 = Vector2(i - at.x, j - at.y) * BLOCK
				var px := Vector2((delta.x - delta.y) * COS_X, (delta.x + delta.y) * COS_Y) * 4.0 + Vector2(trim[2], trim[3])
				if px.x >= 0 and px.y >= 0 and px.x < trim[0] and px.y < trim[1] and image.get_pixel(int(px.x), int(px.y)).a > 0.4:
					flat[j * count + i] = 1
	var distance := PackedFloat32Array()
	distance.resize(count * count)
	for index: int in distance.size():
		distance[index] = 0.0 if flat[index] == 1 else 1e6
	for j: int in range(1, count):
		for i: int in range(1, count - 1):
			var index: int = j * count + i
			distance[index] = minf(distance[index], minf(minf(distance[index - 1] + 1.0, distance[index - count] + 1.0), minf(distance[index - count - 1], distance[index - count + 1]) + 1.41))
	for j: int in range(count - 2, -1, -1):
		for i: int in range(count - 2, 0, -1):
			var index: int = j * count + i
			distance[index] = minf(distance[index], minf(minf(distance[index + 1] + 1.0, distance[index + count] + 1.0), minf(distance[index + count + 1], distance[index + count - 1]) + 1.41))
	print("MASK ", Time.get_ticks_msec() - began, " ms")
	# The land before any road, then the roads across it.
	var raw := PackedFloat32Array()
	raw.resize(count * count)
	raw.fill(1e6)
	for j: int in count:
		for i: int in count:
			var plane: Vector2 = centre + Vector2(i - span, j - span) * BLOCK
			var seen: Vector2 = _screen(plane)
			if absf(seen.x - middle.x) <= half.x + 30 and absf(seen.y - middle.y) <= half.y + 90:
				raw[j * count + i] = _rough(plane, seen, distance[j * count + i] * BLOCK, _region(plane, nodes), middle, half)
	var cut_gap := PackedFloat32Array()
	cut_gap.resize(count * count)
	cut_gap.fill(1e6)
	var cut_height := PackedFloat32Array()
	cut_height.resize(count * count)
	var roads: Array = _lay_roads(_links(catalog), cells, trims, doors, raw, flat, distance, count, span, centre, nodes, cut_gap, cut_height)
	print("ROADS ", roads.size(), " ", Time.get_ticks_msec() - began, " ms")
	# Columns.
	var boxes: Array = []
	var trees: Array = []
	var colours := PackedColorArray()
	var ground := PackedFloat32Array()
	ground.resize(count * count)
	ground.fill(-3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var mist_size := Vector2i(ceili((high.x - low.x) * PX / 8.0), ceili((high.y - low.y) * PX / 8.0))
	var mist := PackedFloat32Array()
	mist.resize(mist_size.x * mist_size.y)
	for j: int in count:
		for i: int in count:
			var plane: Vector2 = centre + Vector2(i - span, j - span) * BLOCK
			var seen: Vector2 = _screen(plane)
			if absf(seen.x - middle.x) > half.x + 30 or absf(seen.y - middle.y) > half.y + 90:
				continue
			var near: float = distance[j * count + i] * BLOCK
			var region: String = _region(plane, nodes)
			var tone: String = REGION.get(region, "green")
			var rise: float = smoothstep(7.0, 62.0, near)
			var height: float = raw[j * count + i]
			var gap: float = cut_gap[j * count + i]
			if gap < CUT and height >= -2.0:
				height = lerpf(cut_height[j * count + i], height, smoothstep(4.5, CUT, gap))
			height = -0.0 if near <= 0.0 else round(height / 2.0) * 2.0
			var colour: Color
			var water: bool = height < -2.0
			if water:
				var depth: float = clampf(-height / 40.0, 0.0, 1.0)
				colour = Color("68d8c0").lerp(Color("1f78a4"), depth)
				colour = colour.lerp(Color("f0c090"), clampf(grain.get_noise_2d(plane.x * 0.4, plane.y * 2.2) * 0.5, 0.0, 0.22))
				height = -3.0
			else:
				var band: Array = TONES[tone]
				var heat: float = clampf(height / 92.0, 0.0, 1.0) * 3.0
				var from: int = mini(int(heat), 2)
				colour = Color(band[from]).lerp(Color(band[from + 1]), heat - from)
				var fleck: float = grain.get_noise_2d(plane.x, plane.y) * 0.1 + rng.randf_range(-0.03, 0.03)
				colour = colour.lightened(fleck) if fleck > 0.0 else colour.darkened(-fleck)
				if near > 0.0 and near < 8.0:
					colour = colour.darkened(0.14 * (1.0 - near / 8.0))
			ground[j * count + i] = height
			boxes.append(Vector3(plane.x, height, plane.y))
			colours.append(colour)
			var wisp: float = smoothstep(5.0, 34.0, gap) * rise * (1.0 - smoothstep(4.0, 46.0, height)) * clampf(0.5 + cloud.get_noise_2d(plane.x * 0.6, plane.y * 0.6) * 1.6, 0.0, 1.0)
			var spot: Vector2i = Vector2i((seen - low) * PX / 8.0)
			if wisp > 0.0 and spot.x >= 0 and spot.y >= 0 and spot.x < mist_size.x and spot.y < mist_size.y:
				mist[spot.y * mist_size.x + spot.x] = maxf(mist[spot.y * mist_size.x + spot.x], wisp)
			if not water and near > 8.0 and gap > 6.0 and height < 66.0 and tone not in ["steppe", "black", "yellow", "ochre"]:
				var stand: float = terrain.get_noise_2d(plane.y * 2.3, plane.x * 2.3)
				if stand > 0.14 and rng.randf() < 0.42 * pow(BLOCK / 2.0, 2.0):
					trees.append([plane, height, region, rng.randf(), rng.randf()])
	var veil: Image = Image.create_empty(mist_size.x, mist_size.y, false, Image.FORMAT_RGBA8)
	for y: int in mist_size.y:
		for x: int in mist_size.x:
			veil.set_pixel(x, y, Color(1.0, 0.93, 0.84, mist[y * mist_size.x + x]))
	veil.resize(mist_size.x / 5, mist_size.y / 5, Image.INTERPOLATE_BILINEAR)
	veil.resize(mist_size.x / 3, mist_size.y / 3, Image.INTERPOLATE_CUBIC)
	veil.save_png(out.path_join("mist.png"))
	print("LAND ", boxes.size(), " columns, ", trees.size(), " trees, ", Time.get_ticks_msec() - began, " ms")
	# Scene.
	var size := Vector2i(int((high.x - low.x) * PX), int((high.y - low.y) * PX))
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = size
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.positional_shadow_atlas_size = 0
	root.add_child(viewport)
	RenderingServer.directional_shadow_atlas_set_size(16384, true)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("8fa4c8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8fa4c8")
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var holder := WorldEnvironment.new()
	holder.environment = environment
	world.add_child(holder)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffba80")
	sun.light_energy = 1.4
	sun.rotation_degrees = Vector3(-26, -50, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 3200
	world.add_child(sun)
	var basis := Basis.looking_at(Vector3(-21.213203, -26, -21.213203), Vector3.UP)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = high.y - low.y
	camera.near = 1.0
	camera.far = 4000.0
	viewport.add_child(camera)
	var mid_plane: Vector3 = _ground(middle)
	camera.global_transform = Transform3D(basis, mid_plane + Vector3(21.213203, 26, 21.213203).normalized() * 1800.0)
	camera.current = true
	var land: MultiMeshInstance3D = _columns(boxes, colours)
	world.add_child(land)
	var forest: MultiMeshInstance3D = _trees(trees)
	world.add_child(forest)
	await _shoot(viewport, 8)
	viewport.get_texture().get_image().save_png(out.path_join("land.png"))
	print("LAND PNG ", size, " ", Time.get_ticks_msec() - began, " ms")
	# Each road alone: the land only throws its shadows on it, what the land hides is left out.
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	forest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var routes: Array = []
	for index: int in roads.size():
		var road: Dictionary = roads[index]
		var seen_parts: Array = _in_sight(road["parts"], ground, count, span, centre)
		var entry: Dictionary = {"a": road["a"], "b": road["b"], "file": "road_%02d" % index}
		entry["at"] = await _layer(viewport, world, seen_parts, out.path_join("road_%02d.png" % index))
		entry["stub_a"] = await _layer(viewport, world, _stub(seen_parts, false), out.path_join("road_%02d_a.png" % index))
		entry["stub_b"] = await _layer(viewport, world, _stub(seen_parts, true), out.path_join("road_%02d_b.png" % index))
		var line: Array = []
		for point: Array in road["line"]:
			var at: Vector2 = (_screen(point[0]) - low) * PX - Vector2(0, point[1] * STEP_UP * PX)
			line.append([round(at.x), round(at.y)])
		entry["line"] = line
		routes.append(entry)
	var written := FileAccess.open(out.path_join("roads.json"), FileAccess.WRITE)
	written.store_string(JSON.stringify(routes))
	written.close()
	print("ROAD PNG ", Time.get_ticks_msec() - began, " ms")
	land.visible = false
	forest.visible = false
	var anchors: Array[Vector2] = []
	for node: Array in nodes:
		anchors.append(_screen(node[0]))
	world.add_child(_clouds(middle, half, anchors))
	await _shoot(viewport, 8)
	var sky: Image = viewport.get_texture().get_image()
	sky.save_png(out.path_join("clouds.png"))
	# Their soft shadow on the land.
	var whole: Vector2i = sky.get_size()
	sky.resize(whole.x / 24, whole.y / 24, Image.INTERPOLATE_BILINEAR)
	sky.resize(whole.x / 12, whole.y / 12, Image.INTERPOLATE_CUBIC)
	sky.save_png(out.path_join("shade.png"))
	print("DONE ", Time.get_ticks_msec() - began, " ms")
	quit()


func _shoot(viewport: SubViewport, frames: int) -> void:
	for _frame: int in frames:
		await process_frame
	await RenderingServer.frame_post_draw


## One layer of road, cut to what it covers; [x, y] of its corner, or [] with nothing to show.
func _layer(viewport: SubViewport, world: Node3D, parts: Array, path: String) -> Array:
	if parts.is_empty():
		return []
	var pieces: MultiMeshInstance3D = _parts(parts)
	world.add_child(pieces)
	await _shoot(viewport, 3)
	var image: Image = viewport.get_texture().get_image()
	pieces.queue_free()
	await process_frame
	var used: Rect2i = image.get_used_rect()
	if used.size == Vector2i.ZERO:
		return []
	image.get_region(used).save_png(path)
	return [used.position.x, used.position.y]


## The parts the land does not hide from the fixed view.
func _in_sight(parts: Array, ground: PackedFloat32Array, count: int, span: int, centre: Vector2) -> Array:
	var kept: Array = []
	for part: Array in parts:
		var at: Vector3 = part[0]
		var top: float = at.y + part[1].y / 2.0
		if not _hidden(Vector2(at.x, at.z), top, ground, count, span, centre):
			kept.append(part)
	return kept


## Whether the land rises between the point and the camera, which looks along (21, 26, 21).
func _hidden(plane: Vector2, top: float, ground: PackedFloat32Array, count: int, span: int, centre: Vector2) -> bool:
	var along: float = 0.7071
	for step: int in range(2, 80):
		var far: float = step * BLOCK
		var spot: Vector2i = Vector2i(((plane + Vector2(far, far) * along - centre) / BLOCK).round()) + Vector2i(span, span)
		if spot.x < 0 or spot.y < 0 or spot.x >= count or spot.y >= count:
			return false
		if ground[spot.y * count + spot.x] > top + far * VIEW_RISE:
			return true
	return false


## The first third of a road from one end, thinning out into the grass.
func _stub(parts: Array, from_b: bool) -> Array:
	var kept: Array = []
	for part: Array in parts:
		var out: float = 1.0 - part[3] if from_b else part[3]
		if part[4] and out < 0.36 and _speck(Vector2(part[0].x, part[0].z) * 0.73) > smoothstep(0.16, 0.36, out):
			kept.append(part)
	return kept


## Pairs of places an ordinary way joins, with the doors it leaves by.
func _links(catalog: ContentCatalog) -> Array:
	var table: AtlasTable = catalog.atlas()
	var found: Dictionary = {}
	for portal: PortalDefinition in catalog.portals():
		var x: String = table.home_of(catalog, portal.source_map_id)
		var y: String = table.home_of(catalog, portal.destination_map_id)
		if x.is_empty() or y.is_empty() or x == y or not MapAtlas.plain(catalog, portal):
			continue
		var first: String = x if x < y else y
		var second: String = y if x < y else x
		var key: String = first + "|" + second
		if not found.has(key):
			found[key] = {"a": first, "b": second, "door_a": null, "door_b": null, "hidden": false}
		var link: Dictionary = found[key]
		if String(portal.source_map_id) == first and link["door_a"] == null:
			link["door_a"] = String(portal.destination_map_id)
		if String(portal.source_map_id) == second and link["door_b"] == null:
			link["door_b"] = String(portal.destination_map_id)
	var keys: Array = found.keys()
	keys.sort()
	var result: Array = []
	for key: String in keys:
		result.append(found[key])
	return result


func _screen(plane: Vector2) -> Vector2:
	return Vector2((plane.x - plane.y) * COS_X, (plane.x + plane.y) * COS_Y)


## The ground point (y 0) a screen position shows.
func _ground(seen: Vector2) -> Vector3:
	var diff: float = seen.x / COS_X
	var total: float = seen.y / COS_Y
	return Vector3((total + diff) / 2.0, 0.0, (total - diff) / 2.0)


func _region(plane: Vector2, nodes: Array) -> String:
	var bent: Vector2 = plane + Vector2(warp.get_noise_2d(plane.x, plane.y), warp.get_noise_2d(plane.y, plane.x)) * 90.0
	var best: String = "green"
	var closest: float = INF
	for node: Array in nodes:
		var gap: float = bent.distance_squared_to(node[0])
		if gap < closest:
			closest = gap
			best = node[1]
	return "forest" if best == "death" and closest > 7000.0 else best


## The land's height before roads: ranges, the sea at the rim, rivers.
func _rough(plane: Vector2, seen: Vector2, near: float, region: String, middle: Vector2, half: Vector2) -> float:
	var tone: String = REGION.get(region, "green")
	var relief: float = {"steppe": 0.32, "ochre": 0.45, "green": 0.9, "yellow": 0.95}.get(tone, 1.0)
	var rise: float = smoothstep(7.0, 62.0, near)
	var ridge: float = pow(ridges.get_noise_2d(plane.x, plane.y) * 0.5 + 0.5, 1.7)
	var height: float = rise * (3.0 + relief * ridge * 118.0) + terrain.get_noise_2d(plane.x, plane.y) * 5.0 * smoothstep(3.0, 24.0, near)
	# The rim falls to the sea on the south and the east, to cloud on the rest.
	var edge: float = maxf(absf(seen.x - middle.x) / half.x, absf(seen.y - middle.y) / half.y) + warp.get_noise_2d(plane.x, plane.y) * 0.1
	height -= smoothstep(0.80, 0.98, edge) * 90.0
	var river: float = minf(_to_line(plane / PITCH, RIVER, 0.13 + warp.get_noise_2d(plane.y, plane.x) * 0.05), _to_line(plane / PITCH, TRIBUTARY, 0.07))
	if near > 0.0 and river < 0.42:
		height = lerpf(minf(height, -4.0), height, smoothstep(0.0, 0.42, river))
	return height


## Roads find their own way: along valleys, over the lowest passes, joining a road already there.
func _lay_roads(links: Array, cells: Dictionary, trims: Dictionary, doors: Dictionary, raw: PackedFloat32Array, flat: PackedByteArray, distance: PackedFloat32Array, count: int, span: int, centre: Vector2, nodes: Array, cut_gap: PackedFloat32Array, cut_height: PackedFloat32Array) -> Array:
	var size: int = count / 2
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, size, size)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.update()
	for y: int in size:
		for x: int in size:
			var index: int = y * 2 * count + x * 2
			var here: float = raw[index]
			if here > 1e5 or here < -14.0:
				grid.set_point_solid(Vector2i(x, y))
				continue
			var slope: float = 0.0
			if x + 1 < size and y + 1 < size and raw[index + 2] < 1e5 and raw[index + 2 * count] < 1e5:
				slope = absf(raw[index + 2] - here) + absf(raw[index + 2 * count] - here)
			var weight: float = 1.0 + maxf(here, 0.0) * 0.16 + slope * 0.4 + (warp.get_noise_2d(x * 3.0, y * 3.0) + 1.0) * 0.9
			if here < -2.0:
				weight += 16.0
			if flat[index] == 1:
				weight += 8.0
			if here >= 0.0 and _hidden(centre + Vector2(x * 2 - span, y * 2 - span) * BLOCK, here + 1.0, raw, count, span, centre):
				weight += 9.0
			grid.set_point_weight_scale(Vector2i(x, y), weight)
	var todo: Array = links.filter(func(link: Dictionary) -> bool: return not link["hidden"] and cells.has(link["a"]) and cells.has(link["b"]))
	todo.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _reach(a, cells) < _reach(b, cells))
	var laid: Array = []
	for link: Dictionary in todo:
		var from: Vector2 = _door(link["a"], link["door_a"], cells, trims, doors)
		var to: Vector2 = _door(link["b"], link["door_b"], cells, trims, doors)
		var a := Vector2i(((from - centre) / BLOCK / 2.0).round()) + Vector2i(span, span) / 2
		var b := Vector2i(((to - centre) / BLOCK / 2.0).round()) + Vector2i(span, span) / 2
		var steps: Array[Vector2i] = grid.get_id_path(a, b, true)
		if steps.size() < 2:
			print("NO ROAD ", link["a"], " ", link["b"])
			continue
		var rough: Array[Vector2] = [from]
		for step: Vector2i in steps:
			rough.append(centre + Vector2(step - Vector2i(span, span) / 2) * BLOCK * 2.0)
			grid.set_point_weight_scale(step, 0.55)
		rough.append(to)
		var path: Array[Vector2] = _resampled(_smoothed(rough))
		laid.append(_road(link, path, raw, distance, count, span, centre, nodes, cut_gap, cut_height))
	return laid


func _reach(link: Dictionary, cells: Dictionary) -> float:
	var a: Array = cells[link["a"]]
	var b: Array = cells[link["b"]]
	return Vector2(float(a[0]), float(a[1])).distance_to(Vector2(float(b[0]), float(b[1])))


## Where a door stands on the land; a place without a picture or the door answers its centre.
func _door(map_id: String, target: Variant, cells: Dictionary, trims: Dictionary, doors: Dictionary) -> Vector2:
	var cell: Array = cells[map_id]
	var plane := Vector2(float(cell[0]), float(cell[1])) * PITCH
	if target == null or not trims.has(map_id) or not doors.get(map_id, {}).has(target):
		return plane
	var trim: Array = trims[map_id]
	var seen: Vector2 = (doors[map_id][target] - Vector2(trim[2], trim[3])) / 4.0
	var across: float = seen.x / COS_X
	var along: float = seen.y / COS_Y
	return plane + Vector2((along + across) / 2.0, (along - across) / 2.0)


func _smoothed(points: Array[Vector2]) -> Array[Vector2]:
	var line: Array[Vector2] = points
	for _pass: int in 3:
		var next: Array[Vector2] = [line[0]]
		for index: int in range(1, line.size() - 1):
			var total := Vector2.ZERO
			var taken: int = 0
			for other: int in range(maxi(index - 3, 0), mini(index + 4, line.size())):
				total += line[other]
				taken += 1
			next.append(total / taken)
		next.append(line[-1])
		line = next
	return line


## One point per unit along the line.
func _resampled(points: Array[Vector2]) -> Array[Vector2]:
	var even: Array[Vector2] = [points[0]]
	var left: float = 1.0
	for index: int in points.size() - 1:
		var from: Vector2 = points[index]
		var to: Vector2 = points[index + 1]
		var length: float = from.distance_to(to)
		var walked: float = left
		while walked <= length and length > 0.0:
			even.append(from.lerp(to, walked / length))
			walked += 1.0
		left = walked - length
	return even


func _road(link: Dictionary, path: Array[Vector2], raw: PackedFloat32Array, distance: PackedFloat32Array, count: int, span: int, centre: Vector2, nodes: Array, cut_gap: PackedFloat32Array, cut_height: PackedFloat32Array) -> Dictionary:
	var heights := PackedFloat32Array()
	heights.resize(path.size())
	var wet := PackedByteArray()
	wet.resize(path.size())
	var free := PackedFloat32Array()
	free.resize(path.size())
	for index: int in path.size():
		var spot: Vector2i = Vector2i(((path[index] - centre) / BLOCK).round()) + Vector2i(span, span)
		var value: float = raw[spot.y * count + spot.x]
		wet[index] = 1 if value < -2.0 else 0
		heights[index] = maxf(value, 0.0)
		free[index] = distance[spot.y * count + spot.x] * BLOCK
	for _pass: int in 2:
		var eased := PackedFloat32Array()
		eased.resize(path.size())
		for index: int in path.size():
			var total: float = 0.0
			var taken: int = 0
			for other: int in range(maxi(index - 12, 0), mini(index + 13, path.size())):
				total += heights[other]
				taken += 1
			eased[index] = total / taken
		heights = eased
	# Over water the road is a bridge: its deck arches between the banks.
	var index: int = 0
	var spans: Array = []
	while index < path.size():
		if wet[index] == 0:
			index += 1
			continue
		var start: int = index
		while index < path.size() and wet[index] == 1:
			index += 1
		spans.append([start, index])
	for run: Array in spans:
		var length: int = run[1] - run[0]
		var bank: float = heights[maxi(run[0] - 1, 0)]
		for at: int in range(run[0], run[1]):
			heights[at] = bank + 2.0 + sin(PI * (at - run[0] + 0.5) / length) * clampf(length * 0.14, 1.0, 4.0)
	var seen: Dictionary = {}
	var parts: Array = []
	# A stub counts from where the road leaves its miniature.
	var first_out: int = 0
	var last_out: int = path.size() - 1
	while first_out < last_out and free[first_out] <= 1.0:
		first_out += 1
	while last_out > first_out and free[last_out] <= 1.0:
		last_out -= 1
	var total_length: float = maxf(last_out - first_out, 1.0)
	var line: Array = []
	for at: int in path.size():
		var plane: Vector2 = path[at]
		var height: float = heights[at]
		var side: Vector2 = (path[mini(at + 2, path.size() - 1)] - path[maxi(at - 2, 0)]).normalized().orthogonal()
		var region: String = _region(plane, nodes)
		var tone: String = REGION.get(region, "green")
		var colours: Array = ROAD[tone]
		var bridge: bool = wet[at] == 1
		var wide: float = lerpf(3.4, 1.9, smoothstep(8.0, 40.0, height))
		if bridge:
			wide = 2.4
		var top: float = height if bridge else round(height / 2.0) * 2.0 + 0.5
		if (free[at] > 5.0 and at % 5 == 0) or at == 0 or at == path.size() - 1:
			line.append([plane, top + 0.6])
		var t: float = clampf((at - first_out) / total_length, 0.0, 1.0)
		# Under a miniature the street it joins takes over.
		var across: float = -wide if free[at] > 1.0 else wide + 1.0
		while across <= wide:
			var cell := Vector2(plane + side * across).round()
			across += 0.6
			if seen.has(cell):
				continue
			seen[cell] = true
			var speck: float = _speck(cell)
			var off: float = absf(across - 0.6) / wide
			if not bridge and off > 0.72 and speck < (off - 0.72) * 2.6:
				continue
			var colour: Color
			if bridge:
				colour = Color("9a6a3a").lerp(Color("6e4628"), _speck(cell * 1.7))
			else:
				colour = Color(colours[1])
				if absf(off - 0.45) < 0.18 and wide > 2.2:
					colour = Color(colours[0]).lerp(colour, 0.35)
				if speck > 0.72:
					colour = Color(colours[2])
				colour = colour.darkened(_speck(cell * 0.3) * 0.12)
			var tall: float = 1.0 if bridge else 3.0
			parts.append([Vector3(cell.x, top - tall / 2.0, cell.y), Vector3(1.0, tall, 1.0), colour, t, true])
		# Trodden verges: the road wears into the land, no ruled edge. They come with the road.
		if not bridge and free[at] > 1.0:
			for way: float in [-1.0, 1.0]:
				for out: float in [wide + 0.6, wide + 1.3, wide + 2.1]:
					var cell := Vector2(plane + side * way * out).round()
					if seen.has(cell) or _speck(cell * 1.3) > 0.62 - (out - wide) * 0.16:
						continue
					seen[cell] = true
					parts.append([Vector3(cell.x, top - 1.8, cell.y), Vector3(1.0, 3.0, 1.0), Color(colours[0]).lerp(Color("6a7a48"), _speck(cell * 0.7) * 0.5), t, true])
		if bridge and at % 3 == 0:
			for way: float in [-1.0, 1.0]:
				var post: Vector2 = plane + side * way * 3.1
				parts.append([Vector3(post.x, top + 0.5, post.y), Vector3(0.6, 1.6, 0.6), Color("5a3820"), t, true])
		if bridge and at % 6 == 0:
			parts.append([Vector3(plane.x, -1.0, plane.y), Vector3(1.6, maxf(top + 1.0, 1.0) * 2.0, 3.0), Color("5e4a38"), t, true])
		if not bridge and at > 30 and at < path.size() - 30 and free[at] > 12.0 and height < 26.0 and at % 62 == 0:
			_wayside(parts, plane + side * (8.0 if at % 2 == 0 else -8.0), top, at / 62, t)
		# The road cuts its way through what it crosses.
		if at % 3 == 0 and not bridge:
			var spot: Vector2i = Vector2i(((plane - centre) / BLOCK).round()) + Vector2i(span, span)
			var cut: int = ceili(CUT / BLOCK)
			for j: int in range(maxi(spot.y - cut, 0), mini(spot.y + cut + 1, count)):
				for i: int in range(maxi(spot.x - cut, 0), mini(spot.x + cut + 1, count)):
					var cell_at: int = j * count + i
					var gap: float = (centre + Vector2(i - span, j - span) * BLOCK).distance_to(plane)
					if gap < cut_gap[cell_at]:
						cut_gap[cell_at] = gap
						cut_height[cell_at] = height
	return {"a": link["a"], "b": link["b"], "parts": parts, "line": line}


## Something beside the road, so a road reads as used: a mile post, a stone lantern, a little pavilion.
func _wayside(parts: Array, at: Vector2, top: float, turn: int, t: float) -> void:
	var base: float = top - 0.5
	match turn % 3:
		0:
			for corner: Vector2 in [Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(-1.5, 1.5), Vector2(1.5, 1.5)]:
				parts.append([Vector3(at.x + corner.x, base + 2.0, at.y + corner.y), Vector3(0.5, 4.0, 0.5), Color("8a3a28"), t, false])
			parts.append([Vector3(at.x, base + 4.3, at.y), Vector3(5.4, 0.7, 5.4), Color("2f5a54"), t, false])
			parts.append([Vector3(at.x, base + 5.0, at.y), Vector3(3.4, 0.8, 3.4), Color("2a4e4a"), t, false])
			parts.append([Vector3(at.x, base + 5.6, at.y), Vector3(1.4, 0.6, 1.4), Color("c8a048"), t, false])
		1:
			parts.append([Vector3(at.x, base + 1.2, at.y), Vector3(1.0, 2.4, 0.6), Color("a89c8a"), t, false])
			parts.append([Vector3(at.x, base + 2.7, at.y), Vector3(1.5, 0.6, 1.1), Color("6e665a"), t, false])
		2:
			parts.append([Vector3(at.x, base + 1.0, at.y), Vector3(0.7, 2.0, 0.7), Color("9c9484"), t, false])
			parts.append([Vector3(at.x, base + 2.3, at.y), Vector3(1.3, 1.0, 1.3), Color("e8a860"), t, false])
			parts.append([Vector3(at.x, base + 3.0, at.y), Vector3(1.7, 0.4, 1.7), Color("6e665a"), t, false])


func _speck(cell: Vector2) -> float:
	return fposmod(sin(cell.x * 12.9898 + cell.y * 78.233) * 43758.5453, 1.0)


func _parts(parts: Array) -> MultiMeshInstance3D:
	var instance: MultiMeshInstance3D = _batch(parts.size())
	for index: int in parts.size():
		var part: Array = parts[index]
		instance.multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(part[1]), part[0]))
		instance.multimesh.set_instance_color(index, part[2])
	return instance


## How far past the banks of `width` a cell point is from the line (0 on the water).
func _to_line(point: Vector2, line: Array[Vector2], width: float) -> float:
	var nearest: float = INF
	for index: int in line.size() - 1:
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, line[index], line[index + 1])
		nearest = minf(nearest, point.distance_to(closest))
	return maxf(nearest - width, 0.0)


func _voxel() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.92
	return material


func _batch(count: int) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.material = _voxel()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	batch.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.custom_aabb = AABB(Vector3(-4000, -400, -4000), Vector3(8000, 900, 8000))
	return instance


func _columns(boxes: Array, colours: PackedColorArray) -> MultiMeshInstance3D:
	var instance: MultiMeshInstance3D = _batch(boxes.size())
	var base: float = -24.0
	for index: int in boxes.size():
		var box: Vector3 = boxes[index]
		var tall: float = box.y - base
		instance.multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3(BLOCK, tall, BLOCK)), Vector3(box.x, base + tall / 2.0, box.z)))
		instance.multimesh.set_instance_color(index, colours[index])
	return instance


func _trees(trees: Array) -> MultiMeshInstance3D:
	var instance: MultiMeshInstance3D = _batch(trees.size() * 2)
	var index: int = 0
	for tree: Array in trees:
		var plane: Vector2 = tree[0]
		var height: float = tree[1]
		var kind: float = tree[3]
		var tall: float = lerpf(3.0, 6.0, tree[4])
		var crown: Color
		var region: String = tree[2]
		if region in ["snow", "cloud", "choyin"] and kind < 0.16:
			crown = Color("e39cb3").lerp(Color("c67a98"), tree[4])
		elif region in ["temple", "waterfog", "sunhill"] and kind < 0.09:
			crown = Color("c4462c").lerp(Color("e27a3a"), tree[4])
		else:
			crown = Color("1f5f48").lerp(Color("4f9a48"), tree[4])
		instance.multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3(2.6, tall, 2.6)), Vector3(plane.x, height + tall / 2.0, plane.y)))
		instance.multimesh.set_instance_color(index, crown)
		instance.multimesh.set_instance_transform(index + 1, Transform3D(Basis.from_scale(Vector3(1.5, 1.8, 1.5)), Vector3(plane.x, height + tall + 0.8, plane.y)))
		instance.multimesh.set_instance_color(index + 1, crown.lightened(0.12))
		index += 2
	return instance


## A sea of cloud round the rim and a few banks over the land, high enough never to read as snow.
func _clouds(middle: Vector2, half: Vector2, anchors: Array[Vector2]) -> MultiMeshInstance3D:
	var puffs: Array = []
	var size: float = 5.0
	var reach: int = 300
	var centre: Vector3 = _ground(middle)
	for j: int in range(-reach, reach):
		for i: int in range(-reach, reach):
			var plane := Vector2(centre.x, centre.z) + Vector2(i, j) * size
			var seen: Vector2 = _screen(plane)
			var edge: float = maxf(absf(seen.x - middle.x) / half.x, absf(seen.y - middle.y) / half.y)
			if edge > 1.25:
				continue
			var value: float = cloud.get_noise_2d((plane.x - plane.y) * 0.3, (plane.x + plane.y) * 1.25)
			var limit: float = lerpf(0.38, -0.1, smoothstep(0.86, 1.06, edge))
			# Never over a town: where the cloud falls on the sheet is 59 units up.
			var over: Vector2 = seen - Vector2(0, 59)
			var clear: bool = true
			for anchor: Vector2 in anchors:
				var gap: Vector2 = (over - anchor) * Vector2(1.0, 1.5)
				if gap.length() < 118.0:
					clear = false
					break
			if clear and value > limit:
				var thick: float = round(((value - limit) * 15.0 + 1.6) / 1.6) * 1.6
				puffs.append(Vector3(plane.x, 78.0 + cloud.get_noise_2d(plane.y, plane.x) * 10.0, plane.y) + Vector3(0, thick, 0))
	var instance: MultiMeshInstance3D = _batch(puffs.size())
	for index: int in puffs.size():
		var puff: Vector3 = puffs[index]
		var tall: float = maxf((puff.y - 70.0) * 0.5, 1.6)
		instance.multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3(size, tall, size)), puff))
		instance.multimesh.set_instance_color(index, Color("fffaf2"))
	var material: StandardMaterial3D = _voxel()
	material.emission_enabled = true
	material.emission = Color("ffe4cc")
	material.emission_energy_multiplier = 0.3
	(instance.multimesh.mesh as BoxMesh).material = material
	return instance
