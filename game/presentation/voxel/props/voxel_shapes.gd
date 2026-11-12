extends RefCounted

## Small authored voxel forms, batched by material; only large footprints get collisions.
var batches: Dictionary = {}
var materials: Dictionary = {}
## One small number per parent, colour and mesh: the parts of a batch's key.
var _slots: Dictionary = {}
var cube := BoxMesh.new()
var stones: Dictionary[int, ArrayMesh] = {}
var _pooled: StandardMaterial3D
const LIGHT_SPLIT_DEPTH: int = 12
var spatial_batching: bool = false
var spatial_cell_size: float = 12.0
## Placed in front of every form drawn while set: many trees share one grove parent (and so
## one batch per colour) yet each keeps its own position, turn and size.
var frame := Transform3D.IDENTITY
## Nodes whose forms go into another node's batches (`merge`): a prop that never moves into
## its neighbourhood's shared node, a facade's parts into the building's body. The same
## picture with one batch per colour there instead of one per part; both nodes must be in
## the tree, posed, before anything is drawn into the first.
var merged: Dictionary[Node3D, Node3D] = {}
## Nodes already as small as a batch cell (a building's body, a neighbourhood of props): their
## batches are not cut again by position.
var compact: Dictionary[Node3D, bool] = {}
## A merged node's place in the node it merges into, read when the first form is drawn into it.
var _merged_pose: Dictionary[Node3D, Transform3D] = {}
## How far a box's face steps back behind a later box's face of another colour in its plane
## (settle_coplanar): about a hundred times the depth buffer's grain at the map's camera, far
## below a pixel.
const COPLANAR_STEP: float = 0.001
## A face narrower than this (units) is a sliver at the map's camera: under two pixels.
const SLIVER: float = 0.03
## A face smaller than this every way is a speck there (two or three pixels): its fight is lost
## in the picture.
const SPECK: float = 0.08
## A box of a map's ground (a place with meta `flat`) this wide both ways is one of its cells
## (VoxelMapGeometry's tiles and beds, 16 px), side by side with its neighbours, and whatever is
## laid on it lies above it: left as it is (voxel_coplanar_test checks that nothing lies flush).
const GROUND_CELL: float = 0.5
## Layers a face may step back to stay under every later face it overlaps; past them it takes
## any layer those faces leave free.
const COPLANAR_LAYERS: int = 4
## The boxes drawn since the last settle_coplanar(), in the order drawn: [batch entry, index].
var _unsettled: Array = []
## Drawn for the map's camera (VoxelMapGeometry): faces it never sees, and slivers, are left as
## they are. Off for a thing that turns (the 背包's item, VoxelItemLook): every face shows.
var settle_for_map: bool = false
## The faces of a box square to the world that are settled, as axis*2 (+1 the face toward
## the axis's negative end): the map's camera never sees an underside or a north face.
const _MAP_FACES: Array[int] = [0,1,2,4]
const _ALL_FACES: Array[int] = [0,1,2,4,5]
const _AXIS_NORMALS: Array[Vector3] = [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
## _normal_code() of each of those normals.
const _AXIS_CODES: Array[int] = [192*65536+128*256+128,64*65536+128*256+128,128*65536+192*256+128,128*65536+64*256+128,128*65536+128*256+192,128*65536+128*256+64]
## Faces are looked up by their plane in steps of 1/_PLANE_CELLS of a unit.
const _PLANE_CELLS: float = 100.0
## ... and by the cells of their plane they cover, 1/_AREA_CELLS of a unit across.
const _AREA_CELLS: float = 0.5
## Two faces must share more than this along each side to overlap (half on each).
const _EDGE: float = 0.00025
## Places being settled: {"items", "stepped" (once done)}.
var _settling: Array[Dictionary] = []
## The WorkerThreadPool group task settling them, or -1.
var _task: int = -1
## Threads a background settle uses.
const SETTLE_THREADS: int = 4
## Faces stepped back so far (settle_coplanar).
var stepped_faces: int = 0
## Suites only (off in the game): while set, every batch flushed by any Shapes is kept in
## `flushed` as it went out ({"by" (the Shapes' instance id), "parent", "color", "mesh", "transforms", "colors"}), so a suite can
## look at what a figure, an item or a map drew after the batches are gone.
static var keep_flushed: bool = false
static var flushed: Array[Dictionary] = []

## A colour key; "<hex>:gloss" is the same colour, wet and shiny (its own material);
## "<hex>:glow" gives off its own light (a red paper lantern, gilt letters catching the sun);
## "<hex>:haze" is seen through, flat, as far hills in the mist (fainter by night); "<hex>:mist"
## is seen through but lit like the land (a cloud sea: white by day, dark blue by night).
func color(hex: String) -> Color:
	return Color.html(hex.get_slice(":",0))

## A seed from a place on the map, the same every build: what varies about a prop (a lantern
## taller than its neighbour, a vat with a crack) follows where it stands, not what was drawn
## before it, so one change elsewhere never reshuffles the whole map.
static func place_seed(x: int, y: int, z: int = 0, salt: int = 0) -> int:
	var h: int = (x*73856093) ^ (y*19349663) ^ (z*83492791) ^ (salt*2654435761)
	h = (h ^ (h >> 13))*1274126177
	return (h ^ (h >> 16)) & 0x7fffffff

## A random source seeded by a spot (units) and a salt.
static func spot_rng(at: Vector3, salt: int = 0) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = place_seed(roundi(at.x*8.0),roundi(at.y*8.0),roundi(at.z*8.0),salt)
	return random

## `hex` shifted a little in brightness and hue (within `amount`), its ":gloss"/":glow" kept:
## paper lanterns of one string that are not quite one colour. The shifts are in coarse steps,
## so a map's many lanterns fall into a few colours (each colour is a batch), not one each.
static func tinted(hex: String, random: RandomNumberGenerator, amount: float = 0.05) -> String:
	var tint: Color = Color.html(hex.get_slice(":",0))
	tint.v = clampf(tint.v+snappedf(random.randf_range(-amount,amount),0.03),0.0,1.0)
	tint.h = fposmod(tint.h+snappedf(random.randf_range(-amount*0.3,amount*0.3),0.01),1.0)
	var suffix: String = hex.substr(hex.find(":")) if hex.contains(":") else ""
	return tint.to_html(false)+suffix

func box(parent: Node3D, at: Vector3, size: Vector3, hex: String) -> void:
	_instance(parent, Transform3D(Basis.from_scale(size), at), hex, cube)

func tilted_box(parent: Node3D, at: Vector3, size: Vector3, hex: String, angles: Vector3) -> void:
	_instance(parent, Transform3D(Basis.from_euler(angles).scaled_local(size), at), hex, cube)

func shard(parent: Node3D, at: Vector3, size: Vector3, hex: String, variant: int, yaw: float = 0.0) -> void:
	# Reusable chipped, bevelled stones. Variants change silhouette, not just colour.
	variant = posmod(variant, 8)
	if not stones.has(variant):
		stones[variant] = _stone_mesh(variant)
	_instance(parent, Transform3D(Basis(Vector3.UP, yaw).scaled_local(size), at), hex, stones[variant])

func merge(node: Node3D, into: Node3D) -> void:
	merged[node] = into
	compact[into] = true

func _instance(parent: Node3D, transform: Transform3D, hex: String, mesh: Mesh) -> void:
	# Worker threads may be settling the batches: nothing is drawn into them meanwhile.
	if _task >= 0:
		finish_settling()
	transform = frame*transform
	if merged.has(parent):
		var into: Node3D = merged[parent]
		if not _merged_pose.has(parent):
			_merged_pose[parent] = into.global_transform.affine_inverse()*parent.global_transform
		transform = _merged_pose[parent]*transform
		parent = into
	var cell: int = -1
	if spatial_batching and not compact.has(parent):
		# Mobile lighting chooses lights per instance. A map-wide ground instance
		# otherwise exceeds that budget and changes lights abruptly while walking.
		cell = (floori(transform.origin.x/spatial_cell_size)+16384 << 16) | (floori(transform.origin.z/spatial_cell_size) & 0xffff)
	var key := Vector4i(_slot(parent),_slot(hex),_slot(mesh),cell)
	var entry: Variant = batches.get(key)
	if entry == null:
		entry = {"parent":parent,"color":hex,"mesh":mesh,"transforms":[]}
		batches[key] = entry
	var transforms: Array = entry["transforms"]
	if mesh == cube:
		_unsettled.append([entry,transforms.size()])
	transforms.append(transform)

## Two boxes of one place in different colours whose faces lie in one plane and overlap fight
## over every pixel there (z-fighting): which one wins flips as the camera moves by a hair, so
## the face flickers while the camera eases after the player and is still only once it stops
## (owner, 2026-11-11: a shelf's boards, a belt, a drumstick's crust). The later box is the
## detail drawn over the earlier one (the board over its post, the crust over the meat), so the
## earlier box's face steps back by COPLANAR_STEP, one behind both by twice that, and so on:
## the same picture, without the fight. Boxes of different places (parents) never meet here;
## same-coloured faces are left as they are (their fight shows nothing). pool_plain_colours()
## and flush() settle what is left first.
func settle_coplanar() -> void:
	if _task >= 0:
		finish_settling()
		return
	_queue_unsettled()
	for group: Dictionary in _settling:
		stepped_faces += _settle_group(group)
	_settling.clear()

## settle_coplanar() on the WorkerThreadPool, a place to a thread (a big map's build: a map has
## a hundred places, sharing nothing), while the loading screen goes on; true when there is
## something to wait for (settling_done(), then finish_settling()). Drawing anything more first
## waits for it.
func settle_coplanar_in_background() -> bool:
	if _task >= 0:
		finish_settling()
	_queue_unsettled()
	if _settling.is_empty():
		return false
	# The biggest places first, so that no thread is left with one at the end. A few threads: more
	# only wait on each other (measured: GDScript's shared values, its allocator).
	_settling.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["items"] as Array).size() > (b["items"] as Array).size())
	_task = WorkerThreadPool.add_group_task(_settle_group_at,_settling.size(),SETTLE_THREADS,true,"voxel coplanar faces")
	return true

func settling_done() -> bool:
	return _task < 0 or WorkerThreadPool.is_group_task_completed(_task)

func finish_settling() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_task)
		_task = -1
		for group: Dictionary in _settling:
			stepped_faces += int(group["stepped"])
		_settling.clear()
	settle_coplanar()

## Waits for any worker thread and drops what was to be settled (a build given up half way).
func abandon_settling() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_task)
		_task = -1
	_settling.clear()
	_unsettled.clear()

func _queue_unsettled() -> void:
	if _unsettled.is_empty():
		return
	var groups: Dictionary = {}
	for item: Array in _unsettled:
		var parent: Variant = (item[0] as Dictionary)["parent"]
		if not groups.has(parent):
			groups[parent] = []
		(groups[parent] as Array).append(item)
	_unsettled.clear()
	for parent: Variant in groups:
		_settling.append({"items":groups[parent],"stepped":0,"ground":settle_for_map and (parent as Node).get_meta("flat",false)})

## On a worker thread: touches only its own place's boxes.
func _settle_group_at(index: int) -> void:
	var group: Dictionary = _settling[index]
	group["stepped"] = _settle_group(group)

## A place's boxes, latest first; the count of faces stepped back.
func _settle_group(group: Dictionary) -> int:
	var items: Array = group["items"]
	var cells: Dictionary = {}
	var ground: bool = group.get("ground",false)
	var stepped: int = 0
	for next: int in range(items.size()-1,-1,-1):
		stepped += _settle_box(items[next],cells,ground)
	return stepped

## A box (latest first) against the faces of the boxes of its place drawn after it, found by
## their plane and the cells of that plane they cover (_PLANE_CELLS, _AREA_CELLS). A box
## square to the world (most are, turned or not) is its own bounds: its faces are rectangles of
## the world's planes. One turned some other way takes the long way (_settle_turned).
func _settle_box(item: Array, cells: Dictionary, ground: bool = false) -> int:
	var entry: Dictionary = item[0]
	var index: int = item[1]
	var transforms: Array = entry["transforms"]
	var t: Transform3D = transforms[index]
	var x: Vector3 = t.basis.x
	var y: Vector3 = t.basis.y
	var z: Vector3 = t.basis.z
	if absf(x.x*x.y)+absf(x.y*x.z)+absf(x.z*x.x)+absf(y.x*y.y)+absf(y.y*y.z)+absf(y.z*y.x)+absf(z.x*z.y)+absf(z.y*z.z)+absf(z.z*z.x) > 0.0000000001:
		return _settle_turned(item,cells)
	var size := Vector3(absf(x.x)+absf(y.x)+absf(z.x),absf(x.y)+absf(y.y)+absf(z.y),absf(x.z)+absf(y.z)+absf(z.z))
	if ground and absf(size.x-GROUND_CELL) < 0.02 and absf(size.z-GROUND_CELL) < 0.02:
		return 0
	var low: Vector3 = t.origin-size*0.5
	var high: Vector3 = t.origin+size*0.5
	var colour: String = entry["color"]
	var stepped: int = 0
	for face: int in (_MAP_FACES if settle_for_map else _ALL_FACES):
		var axis: int = face >> 1
		var ahead: bool = face & 1 == 0
		var u: int = 1 if axis == 0 else 0
		var v: int = 1 if axis == 2 else 2
		if settle_for_map and (minf(size[u],size[v]) < SLIVER or maxf(size[u],size[v]) < SPECK):
			continue
		var area := Rect2(low[u]+_EDGE,low[v]+_EDGE,size[u]-_EDGE*2.0,size[v]-_EDGE*2.0)
		var d: float = high[axis] if ahead else -low[axis]
		var deepest: float = minf(COPLANAR_STEP*COPLANAR_LAYERS,(size[axis]-COPLANAR_STEP)*0.5)
		var record: Array = [_AXIS_NORMALS[face],d,null,null,null,colour,area,true,d]
		var later: PackedVector2Array = _later_planes(cells,_AXIS_CODES[face],record)
		var plane_at: float = d if later.is_empty() else _clear_of(d,later,deepest)
		record[1] = plane_at
		# A box's own faces never meet (one colour): filed at once.
		_file(cells,_AXIS_CODES[face],record)
		if plane_at != d:
			stepped += 1
			if ahead:
				high[axis] -= d-plane_at
			else:
				low[axis] += d-plane_at
	if stepped > 0:
		transforms[index] = Transform3D(Basis.from_scale(high-low),(high+low)*0.5)
	return stepped

## A box turned other than square to the world (a crust a quarter turned on the meat, a worn
## patch askew on the floor): each face by its own normal.
func _settle_turned(item: Array, cells: Dictionary) -> int:
	var entry: Dictionary = item[0]
	var index: int = item[1]
	var transforms: Array = entry["transforms"]
	var t: Transform3D = transforms[index]
	var colour: String = entry["color"]
	var steps := PackedFloat32Array([0.0,0.0,0.0,0.0,0.0,0.0])
	for axis: int in 3:
		var column: Vector3 = t.basis[axis]
		var length: float = column.length()
		if length < 0.00001:
			continue
		var half_a: Vector3 = t.basis[(axis+1)%3]*0.5
		var half_b: Vector3 = t.basis[(axis+2)%3]*0.5
		for side: int in 2:
			var normal: Vector3 = column/length if side == 0 else -column/length
			# No camera of the game looks up at an underside; the map's never sees a north face,
			# nor a sliver too thin to show a fight.
			if normal.y < -0.99 or (settle_for_map and (_unseen_on_map(normal) or minf(half_a.length(),half_b.length()) < SLIVER*0.5 or maxf(half_a.length(),half_b.length()) < SPECK*0.5)):
				continue
			var centre: Vector3 = t.origin+normal*length*0.5
			# The plane's two coordinates: the world axes the normal lies least along.
			var u: int = 0 if absf(normal.x) < 0.7 else 1
			var v: int = 2 if absf(normal.z) < 0.7 else 1
			if u == v:
				v = 2
			var reach := Vector2(absf(half_a[u])+absf(half_b[u]),absf(half_a[v])+absf(half_b[v]))
			var area := Rect2(centre[u]-reach.x,centre[v]-reach.y,reach.x*2.0,reach.y*2.0)
			var d: float = normal.dot(centre)
			# Never through the box (its other face may step back as far).
			var deepest: float = minf(COPLANAR_STEP*COPLANAR_LAYERS,(length-COPLANAR_STEP)*0.5)
			var record: Array = [normal,d,centre,half_a,half_b,colour,area,false,d]
			var later: PackedVector2Array = _later_planes(cells,_normal_code(Vector3i((normal*64.0).round())),record)
			var plane_at: float = d if later.is_empty() else _clear_of(d,later,deepest)
			record[1] = plane_at
			steps[axis*2+side] = d-plane_at
			# A turned normal may round either way: the face is filed under each way it may.
			var floor_n := Vector3i((normal*64.0).floor())
			var ceil_n := Vector3i((normal*64.0).ceil())
			for cx: int in range(floor_n.x,ceil_n.x+1):
				for cy: int in range(floor_n.y,ceil_n.y+1):
					for cz: int in range(floor_n.z,ceil_n.z+1):
						_file(cells,_normal_code(Vector3i(cx,cy,cz)),record)
	var stepped: int = 0
	for axis: int in 3:
		var ahead: float = steps[axis*2]
		var behind: float = steps[axis*2+1]
		if ahead == 0.0 and behind == 0.0:
			continue
		stepped += int(ahead > 0.0)+int(behind > 0.0)
		var column: Vector3 = t.basis[axis]
		var length: float = column.length()
		var direction: Vector3 = column/length
		t.origin += direction*(behind-ahead)*0.5
		t.basis[axis] = direction*(length-ahead-behind)
	if stepped > 0:
		transforms[index] = t
	return stepped

## The later faces of other colours that `record` (a face: [normal, plane, centre, half edges,
## colour, area, square to the world, plane as drawn]) overlaps, from just before it to as deep
## as any face steps: each (where it lies now, where it was drawn).
func _later_planes(cells: Dictionary, code: int, record: Array) -> PackedVector2Array:
	var found := PackedVector2Array()
	var d: float = record[1]
	var area: Rect2 = record[6]
	var colour: String = record[5]
	var square: bool = record[7]
	var reach: float = COPLANAR_STEP*(COPLANAR_LAYERS+2)
	# On the map, faces that share only a strip under a pixel wide (two floor tiles lapping by
	# a hair) show no fight there.
	var least: float = SLIVER if settle_for_map else 0.0005
	var cu_end: int = floori(area.end.x*_AREA_CELLS)
	var cv_start: int = floori(area.position.y*_AREA_CELLS)
	var cv_end: int = floori(area.end.y*_AREA_CELLS)
	for at_d: int in range(floori((d-reach)*_PLANE_CELLS),floori((d+COPLANAR_STEP)*_PLANE_CELLS)+1):
		for cu: int in range(floori(area.position.x*_AREA_CELLS),cu_end+1):
			for cv: int in range(cv_start,cv_end+1):
				var near: Variant = cells.get(Vector4i(code,at_d,cu,cv))
				if near == null:
					continue
				for other: Array in near:
					var at: float = other[1]
					if absf(at-d) >= reach or other[5] == colour or not area.intersects(other[6]):
						continue
					# Two faces square to the world under one code overlap where their areas do.
					if square and other[7]:
						var shared: Rect2 = area.intersection(other[6])
						if minf(shared.size.x,shared.size.y) < least-_EDGE*2.0:
							continue
					elif not _same_way(other[0],record[0]) or not _faces_overlap(_centre(record),_half(record,0),_half(record,1),_centre(other),_half(other,0),_half(other,1),least):
						continue
					found.append(Vector2(at,float(other[8])))
	return found

## Files a face's record under `code`, its plane and its cells, for the earlier boxes.
static func _file(cells: Dictionary, code: int, record: Array) -> void:
	var area: Rect2 = record[6]
	var at_d: int = floori(float(record[1])*_PLANE_CELLS)
	var cv_start: int = floori(area.position.y*_AREA_CELLS)
	var cv_end: int = floori(area.end.y*_AREA_CELLS)
	for cu: int in range(floori(area.position.x*_AREA_CELLS),floori(area.end.x*_AREA_CELLS)+1):
		for cv: int in range(cv_start,cv_end+1):
			var key := Vector4i(code,at_d,cu,cv)
			var list: Variant = cells.get(key)
			if list == null:
				cells[key] = [record]
			else:
				(list as Array).append(record)

## A face record's centre and half edges; a square face's from its area and plane.
static func _centre(record: Array) -> Vector3:
	if not record[7]:
		return record[2]
	var normal: Vector3 = record[0]
	var area: Rect2 = record[6]
	var axis: int = normal.abs().max_axis_index()
	var centre := Vector3.ZERO
	centre[axis] = float(record[1])*normal[axis]
	centre[1 if axis == 0 else 0] = area.get_center().x
	centre[1 if axis == 2 else 2] = area.get_center().y
	return centre

static func _half(record: Array, which: int) -> Vector3:
	if not record[7]:
		return record[3+which]
	var normal: Vector3 = record[0]
	var area: Rect2 = record[6]
	var axis: int = normal.abs().max_axis_index()
	var half := Vector3.ZERO
	if which == 0:
		half[1 if axis == 0 else 0] = area.size.x*0.5+_EDGE
	else:
		half[1 if axis == 2 else 2] = area.size.y*0.5+_EDGE
	return half

## Whether the map's camera, from either side or turning between them (WorldVoxelView: always
## south of what it looks at, 45 degrees east or west), never sees a face turned this way.
static func _unseen_on_map(normal: Vector3) -> bool:
	for yaw: float in [-PI/4.0,0.0,PI/4.0]:
		if normal.dot(Vector3(sin(yaw)*30.0,26.0,cos(yaw)*30.0)) > -0.5:
			return false
	return true

## Two faces look the same way when their normals differ by less than half a code's step in each
## part (some half a degree): more than that, they cross along a line, not lie in one plane.
static func _same_way(a: Vector3, b: Vector3) -> bool:
	var apart: Vector3 = (a-b).abs()
	return apart.x < 0.5/64.0 and apart.y < 0.5/64.0 and apart.z < 0.5/64.0

static func _normal_code(n: Vector3i) -> int:
	return (n.x+128)*65536+(n.y+128)*256+n.z+128

## Where a face drawn at `d` goes among the later faces it overlaps (`others`: each where it
## lies now and where it was drawn): behind every one drawn in its plane, however far that one
## stepped back itself (the later face wins, as drawn over it), and clear of any other it would
## now meet; no deeper than `deepest`. Many tiles each overlapping the next (worn patches,
## paving) would push the first ever deeper: then the free place nearest where it was drawn,
## before or behind its neighbours as it falls.
static func _clear_of(d: float, others: PackedVector2Array, deepest: float) -> float:
	var at: float = d
	for other: Vector2 in others:
		if absf(other.y-d) < COPLANAR_STEP*0.5:
			at = minf(at,other.x-COPLANAR_STEP)
	var moved: bool = true
	while moved:
		moved = false
		for other: Vector2 in others:
			if absf(at-other.x) < COPLANAR_STEP-0.00001:
				at = other.x-COPLANAR_STEP
				moved = true
	if d-at <= deepest+0.00001:
		return at
	var places: Array[float] = [d]
	for other: Vector2 in others:
		places.append(other.x-COPLANAR_STEP)
		places.append(other.x+COPLANAR_STEP)
	places.sort()
	places.reverse()
	for place: float in places:
		if place > d+0.00001 or d-place > deepest+0.00001:
			continue
		var clear: bool = true
		for other: Vector2 in others:
			if absf(place-other.x) < COPLANAR_STEP-0.00001:
				clear = false
				break
		if clear:
			return place
	return d

## Whether two rectangles of one plane (centres, half edges) share more than a strip `least`
## wide (by default, more than an edge).
static func _faces_overlap(c1: Vector3, a1: Vector3, b1: Vector3, c2: Vector3, a2: Vector3, b2: Vector3, least: float = 0.0005) -> bool:
	var apart: Vector3 = c2-c1
	for axis: Vector3 in [a1,b1,a2,b2]:
		var length: float = axis.length()
		if length < 0.00001:
			continue
		var unit: Vector3 = axis/length
		var reach: float = absf(a1.dot(unit))+absf(b1.dot(unit))+absf(a2.dot(unit))+absf(b2.dot(unit))
		if reach-absf(apart.dot(unit)) <= least:
			return false
	return true

func _slot(thing: Variant) -> int:
	var slot: Variant = _slots.get(thing)
	if slot == null:
		slot = _slots.size()
		_slots[thing] = slot
	return slot

func _stone_mesh(variant: int) -> ArrayMesh:
	var random := RandomNumberGenerator.new()
	random.seed = 193 + variant * 97
	var corners := PackedVector2Array([
		Vector2(-0.5,-0.32), Vector2(-0.30,-0.5), Vector2(0.30,-0.5), Vector2(0.5,-0.31),
		Vector2(0.5,0.30), Vector2(0.31,0.5), Vector2(-0.33,0.5), Vector2(-0.5,0.32)])
	for i: int in corners.size():
		corners[i] += Vector2(random.randf_range(-0.065,0.065), random.randf_range(-0.065,0.065))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i+1)%corners.size()]
		var top_a := Vector3(a.x*0.91,0.5,a.y*0.91)
		var top_b := Vector3(b.x*0.91,0.5,b.y*0.91)
		var rim_a := Vector3(a.x,0.12,a.y)
		var rim_b := Vector3(b.x,0.12,b.y)
		var low_a := Vector3(a.x,-0.5,a.y)
		var low_b := Vector3(b.x,-0.5,b.y)
		for triangle: Array in [[Vector3(0,0.5,0),top_a,top_b], [top_a,rim_a,rim_b], [top_a,rim_b,top_b], [rim_a,low_a,low_b], [rim_a,low_b,rim_b]]:
			var normal: Vector3 = ((triangle[2] as Vector3)-(triangle[0] as Vector3)).cross((triangle[1] as Vector3)-(triangle[0] as Vector3)).normalized()
			surface.set_normal(normal)
			for vertex: Vector3 in triangle:
				surface.add_vertex(vertex)
	return surface.commit()

## A colour that is only a colour: no glow, no gloss, nothing seen through, and no material
## of its own asked for (`window` and the like make theirs glow by the colour's name).
func _plain(hex: String) -> bool:
	return not hex.contains(":") and hex != "ffd88a" and hex != "ffb858" and not materials.has(hex)

## The batches of one place that differ only in a plain colour become one, its colours per
## instance: a town's hundreds of colours are hundreds of nodes and buffers per street block
## otherwise, most of them a stone or two (DECISIONS「搭建开销」). The same picture: colours,
## place and shape are the same, and the light-aware split still applies. Once everything is
## drawn, so that any colour made to glow on the way stays out.
func pool_plain_colours() -> void:
	settle_coplanar()
	var pooled: Dictionary = {}
	for key: Vector4i in batches:
		var entry: Dictionary = batches[key]
		var hex: String = entry["color"]
		if not _plain(hex):
			pooled[key] = entry
			continue
		var place := Vector4i(key.x,-1,key.z,key.w)
		if not pooled.has(place):
			pooled[place] = {"parent":entry["parent"],"color":"","mesh":entry["mesh"],"transforms":[],"colors":PackedColorArray()}
		var into: Dictionary = pooled[place]
		var transforms: Array = entry["transforms"]
		(into["transforms"] as Array).append_array(transforms)
		# Instance colours are multiplied in as they are; a material's albedo is taken as sRGB.
		var run := PackedColorArray()
		run.resize(transforms.size())
		run.fill(color(hex).srgb_to_linear())
		var colors: PackedColorArray = into["colors"]
		colors.append_array(run)
		into["colors"] = colors
	batches = pooled

func flush(light_bounds: Array[AABB] = []) -> void:
	settle_coplanar()
	for key: Variant in batches:
		flush_one(key,light_bounds)
	batches.clear()

## One batch of flush(), for a build that goes over several frames; batches.clear() is the caller's.
func flush_one(key: Variant, light_bounds: Array[AABB] = []) -> void:
	var entry: Dictionary = batches[key]
	if keep_flushed:
		flushed.append({"by":get_instance_id(),"parent":entry["parent"],"color":entry["color"],"mesh":entry["mesh"],"transforms":(entry["transforms"] as Array).duplicate(),"colors":entry.get("colors",PackedColorArray())})
	_flush_batch(entry,entry["transforms"],entry.get("colors",PackedColorArray()),light_bounds)

## `cuts`: how many times a box has been cut in two on the way here. Halving a batch ends by
## itself; the cuts need their limit whatever the batch's size.
func _flush_batch(entry: Dictionary, transforms: Array, colors: PackedColorArray, light_bounds: Array[AABB], cuts: int = 0) -> void:
	var mesh: Mesh = entry["mesh"]
	var parent: Node3D = entry["parent"]
	if not light_bounds.is_empty() and cuts<LIGHT_SPLIT_DEPTH:
		var shape: AABB = mesh.get_aabb()
		var bounds: AABB = (transforms[0] as Transform3D)*shape
		for transform: Transform3D in transforms:
			bounds = bounds.merge(transform*shape)
		var world_bounds: AABB = parent.global_transform*bounds
		var overlaps: int = 0
		for light: AABB in light_bounds:
			if world_bounds.intersects(light):
				overlaps += 1
			if overlaps>8:
				break
		if overlaps>8:
			if transforms.size()>1:
				_split_batch(entry,transforms,colors,light_bounds,cuts,bounds.size.max_axis_index())
				return
			# Long plinths and beams are one box, but must not collect the lights of
			# an entire building. Subdivide without moving or overlapping their faces.
			var transform: Transform3D = transforms[0]
			var size: Vector3 = transform.basis.get_scale().abs()
			var axis: int = size.max_axis_index()
			if mesh==cube and size[axis]>1.0:
				var offset: Vector3 = transform.basis[axis]*0.25
				transform.basis[axis] *= 0.5
				transform.origin -= offset
				_flush_batch(entry,[transform],colors,light_bounds,cuts+1)
				transform.origin += offset*2.0
				_flush_batch(entry,[transform],colors,light_bounds,cuts+1)
				return
	_add_batch(entry,transforms,colors)

## The batch's instance under its parent.
func _add_batch(entry: Dictionary, transforms: Array, colors: PackedColorArray) -> void:
	var parent: Node3D = entry["parent"]
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not colors.is_empty()
	multi.mesh = entry["mesh"]
	multi.instance_count = transforms.size()
	for i: int in transforms.size():
		multi.set_instance_transform(i,transforms[i])
	for i: int in colors.size():
		multi.set_instance_color(i,colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = _plain_material() if colors.size()>0 else material(entry["color"])
	# The ground's own boxes and stones lie flat: their shadows would fall on nothing, yet they
	# would fill every shadow map pass (meta `flat` on the parent they are drawn into).
	if entry["color"] in ["ffd88a","ffb858"] or String(entry["color"]).ends_with(":glow") or String(entry["color"]).ends_with(":haze") or String(entry["color"]).ends_with(":mist") or parent.get_meta("light_fixture",false) or parent.get_meta("flat",false):
		# Tiny opaque lantern caps otherwise project enormous square shadows from
		# the point source inside them. The housing represents a diffuse emitter.
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

## Half the batch by place along `axis`, each half again if it needs it.
func _split_batch(entry: Dictionary, transforms: Array, colors: PackedColorArray, light_bounds: Array[AABB], cuts: int, axis: int) -> void:
	var order: Array[Vector2] = []
	for i: int in transforms.size():
		order.append(Vector2((transforms[i] as Transform3D).origin[axis],i))
	order.sort()
	var middle: int = transforms.size()/2
	for half: Array[Vector2] in [order.slice(0,middle),order.slice(middle)]:
		var part: Array = []
		var tints := PackedColorArray()
		for item: Vector2 in half:
			part.append(transforms[int(item.y)])
			if not colors.is_empty():
				tints.append(colors[int(item.y)])
		_flush_batch(entry,part,tints,light_bounds,cuts)

func _plain_material() -> StandardMaterial3D:
	if _pooled == null:
		_pooled = StandardMaterial3D.new()
		_pooled.vertex_color_use_as_albedo = true
		_pooled.roughness = 0.93
	return _pooled

func material(hex: String) -> StandardMaterial3D:
	if not materials.has(hex):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color(hex)
		mat.roughness = 0.93
		if hex.ends_with(":gloss"):
			mat.roughness = 0.08
			mat.metallic = 0.3
		if hex.ends_with(":haze"):
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.5
			mat.set_meta("haze",[0.5,0.22])
		if hex.ends_with(":mist"):
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 1.0
			mat.albedo_color.a = 0.55
			mat.set_meta("haze",[0.55,0.4])
		if hex.ends_with(":glow"):
			mat.emission_enabled = true
			mat.emission = color(hex)
			mat.emission_energy_multiplier = 0.9
		if hex == "ffd88a" or hex == "ffb858":
			mat.emission_enabled = true
			mat.emission = color(hex)
			mat.emission_energy_multiplier = 1.5
		materials[hex] = mat
	return materials[hex]

func solid(parent: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body

## A paper lantern with its light; `paper` another glowing colour ("d8452f:glow", a red one).
## A paper lantern at `at`: on its own post from the ground when `standing`, else hung;
## `size` scales the lantern (not the post), a little bigger or smaller than its neighbours.
func lantern(parent: Node3D, at: Vector3, standing: bool = false, paper: String = "ffb858", size: float = 1.0) -> void:
	var housing := Node3D.new()
	housing.set_meta("light_fixture",true)
	parent.add_child(housing)
	if standing:
		box(housing,Vector3(at.x,at.y/2,at.z),Vector3(0.12,at.y,0.12),"483b32")
	box(housing,at,Vector3(0.34,0.45,0.34)*size,paper)
	for y: float in [-0.25,0.25]:
		box(housing,at+Vector3(0,y*size,0),Vector3(0.44,0.07,0.44)*size,"993f35")
	for x: float in [-0.17,0.17]:
		box(housing,at+Vector3(x,0,0.175)*size,Vector3(0.045,0.44,0.04)*size,"ba613c")
	box(housing,at+Vector3(0,-0.36*size,0),Vector3(0.06,0.16,0.06)*size,"b54135")
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color("ffbd72") if paper == "ffb858" else color(paper).lerp(color("ffbd72"),0.55)
	lamp.light_energy = 1.1
	lamp.omni_range = 3.2
	lamp.set_meta("night_energy",2.8)
	lamp.set_meta("day_energy",1.1)
	parent.add_child(lamp)

func window(parent: Node3D, at: Vector3, size: Vector3) -> void:
	box(parent,at,size,"d7bb88")
	var mat: StandardMaterial3D = material("d7bb88")
	mat.emission_enabled = true
	mat.emission = Color("ffbb6e")
	mat.emission_energy_multiplier = 0.9
	mat.set_meta("night_only",true)

## A flower pot: by its place a little bigger or smaller, the glaze a shade off, and what
## grows in it (when `green`) leafy, or in flower of one colour or another.
func pot(parent: Node3D, at: Vector3, green: bool = true) -> void:
	var vary: RandomNumberGenerator = spot_rng(parent.position+at,3)
	var size: float = vary.randf_range(0.88,1.1)
	var clay: String = tinted("8b5440",vary,0.06)
	box(parent,at+Vector3(0,0.22*size,0),Vector3(0.44,0.42,0.44)*size,clay)
	box(parent,at+Vector3(0,0.43*size,0),Vector3(0.5,0.08,0.5)*size,tinted("be8660",vary,0.05))
	box(parent,at+Vector3(0,0.48*size,0),Vector3(0.37,0.04,0.37)*size,"473b2c")
	if green:
		var turn: float = vary.randf()*TAU
		for i: int in 7:
			var a: float = i*TAU/7+turn
			box(parent,at+Vector3(cos(a)*0.19,0.65+float(i%3)*0.09,sin(a)*0.19)*size,Vector3(0.18,0.4,0.16)*size,["417653","689951","8eaa58"][i%3])
		if vary.randf()<0.4:
			var bloom: String = ["d84a5a","e8a0b4","f2dc8e","b890d0","f0f0e8"][vary.randi_range(0,4)]
			for i: int in 3:
				var a: float = i*2.1+turn
				box(parent,at+Vector3(cos(a)*0.12,0.84+(i%2)*0.06,sin(a)*0.12)*size,Vector3(0.1,0.07,0.1)*size,bloom)

func table(parent: Node3D, at: Vector3) -> void:
	box(parent,at+Vector3(0,0.72,0),Vector3(1.65,0.14,0.95),"ae7049")
	for x: float in [-0.64,0.64]:
		for z: float in [-0.33,0.33]:
			box(parent,at+Vector3(x,0.35,z),Vector3(0.13,0.7,0.13),"654536")
	for z: float in [-0.82,0.82]:
		box(parent,at+Vector3(0,0.38,z),Vector3(1.4,0.1,0.32),"855737")
		for x: float in [-0.5,0.5]:
			box(parent,at+Vector3(x,0.17,z),Vector3(0.12,0.34,0.24),"573c30")
	box(parent,at+Vector3(-0.3,0.83,0),Vector3(0.32,0.06,0.29),"d5d8ba")
	box(parent,at+Vector3(-0.3,0.89,0),Vector3(0.2,0.08,0.17),"b6773f")
	box(parent,at+Vector3(0.32,0.91,0.08),Vector3(0.19,0.25,0.19),"648b83")
	box(parent,at+Vector3(0.44,0.9,0.08),Vector3(0.1,0.08,0.08),"7aaba2")
	box(parent,at+Vector3(0.2,0.84,-0.26),Vector3(0.13,0.1,0.13),"e0dbbd")
	solid(parent,at+Vector3(0,0.4,0),Vector3(1.65,0.8,0.95))
