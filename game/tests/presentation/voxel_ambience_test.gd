extends RefCounted

## DECISIONS「氛围动画」: what stirs on its own (hangings, flags, flames, smoke, swarms of dust)
## is moved only while the camera sees it, a slow sway only once it has turned a step, and each
## swarm keeps within its own fixed box. The picture is the same: whatever is on screen is posed
## as the clock has it, as it would be with nothing skipped.
var assertions: int = 0
var failures: Array[String] = []

const Ambience = preload("res://presentation/voxel/voxel_ambience.gd")
## Far enough that the camera's sight (an orthogonal view 24 units high) never reaches it.
const FAR := Vector3(300.0, 0.0, 0.0)


func run_all(tree: SceneTree) -> Dictionary:
	_test_only_what_is_seen_moves(tree)
	_test_slow_sway_written_by_steps(tree)
	_test_swarms_keep_in_their_box()
	_test_swarm_out_of_sight_is_left(tree)
	return {"assertions": assertions, "failures": failures}


## A view: a viewport with an ambience and an orthogonal camera looking down at `at` from the
## map's angle.
func _stage(tree: SceneTree) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	tree.root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var ambience: VoxelAmbience = Ambience.new()
	world.add_child(ambience)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24.0
	world.add_child(camera)
	_aim(camera, Vector3.ZERO)
	camera.current = true
	return {"viewport": viewport, "ambience": ambience, "camera": camera}


func _aim(camera: Camera3D, at: Vector3) -> void:
	camera.position = at + Vector3(0.0, 18.0, 20.0)
	camera.look_at(at, Vector3.UP)


## A hanging thing at `at`, swaying, under the ambience; the same in a second ambience that has no
## camera (all of it moves), to say where the first's should be.
func _hang(ambience: VoxelAmbience, at: Vector3, phase: float, amount: float = 0.12) -> Node3D:
	var node := Node3D.new()
	node.position = at
	ambience.add_child(node)
	ambience.sway(node, phase, amount)
	return node


func _test_only_what_is_seen_moves(tree: SceneTree) -> void:
	var stage: Dictionary = _stage(tree)
	var ambience: VoxelAmbience = stage["ambience"]
	var near: Node3D = _hang(ambience, Vector3(2.0, 3.0, 1.0), 0.3)
	var far: Node3D = _hang(ambience, FAR + Vector3(0.0, 3.0, 0.0), 0.3)
	var flame := Node3D.new()
	flame.position = FAR
	ambience.add_child(flame)
	ambience.flame(flame)
	var smoke_root := Node3D.new()
	smoke_root.position = FAR
	ambience.add_child(smoke_root)
	ambience.smoke(smoke_root, Vector3.ZERO, "8d877c", 3)
	var free := Node3D.new()
	var reference: VoxelAmbience = Ambience.new()
	free.add_child(reference)
	var near_twin: Node3D = _hang(reference, near.position, 0.3)
	var far_twin: Node3D = _hang(reference, far.position, 0.3)
	ambience.camera = stage["camera"]
	for step: int in 30:
		ambience.advance(1.0 / 30.0)
		reference.advance(1.0 / 30.0)
	_check(ambience._near["_swaying"].size() == 1 and ambience._near["_flame_entries"].is_empty() and ambience._near["_puffs"].is_empty(),
		"only the hanging thing on screen is near: %d hanging, %d flames, %d puffs" % [ambience._near["_swaying"].size(), ambience._near["_flame_entries"].size(), ambience._near["_puffs"].size()])
	_check(_close(near.rotation, near_twin.rotation, Ambience.SWAY_STEP), "on screen it sways as the clock has it: %s, %s" % [near.rotation, near_twin.rotation])
	_check(far.rotation == Vector3.ZERO and not far_twin.rotation.is_zero_approx(), "out of sight it is left as it was")
	_check(is_equal_approx(flame.scale.y, 1.0), "a flame out of sight is left")
	# The camera goes over to it: from the next frame it is where the clock has it.
	_aim(stage["camera"], FAR)
	ambience.advance(1.0 / 30.0)
	reference.advance(1.0 / 30.0)
	_check(_close(far.rotation, far_twin.rotation, 0.0001), "in sight again, it is where it would have been: %s, %s" % [far.rotation, far_twin.rotation])
	_check(not is_equal_approx(flame.scale.y, 1.0), "and the flame there flickers")
	# No camera: everything moves (a view that is not set up, or a test's ambience).
	ambience.camera = null
	var before: Vector3 = near.rotation
	for step: int in 20:
		ambience.advance(1.0 / 30.0)
	_check(near.rotation != before and ambience._near["_puffs"].size() == 3, "without a camera all of it moves")
	free.free()
	(stage["viewport"] as Node).free()


func _test_slow_sway_written_by_steps(tree: SceneTree) -> void:
	var stage: Dictionary = _stage(tree)
	var ambience: VoxelAmbience = stage["ambience"]
	ambience.camera = stage["camera"]
	var slow: Node3D = _hang(ambience, Vector3(0.0, 3.0, 0.0), 0.0, 0.04)
	ambience.advance(0.0)
	var first: Vector3 = slow.rotation
	# A sixtieth of a second at the swing's fastest turns it far less than a step: not written.
	ambience.advance(1.0 / 60.0)
	_check(slow.rotation == first, "a turn under a step is not written")
	var writes: int = 0
	var last: Vector3 = slow.rotation
	for step: int in 600:
		ambience.advance(1.0 / 60.0)
		if slow.rotation != last:
			writes += 1
			last = slow.rotation
		var t: float = ambience.clock * 1.1
		var due := Vector3(sin(t) * 0.04, 0.0, sin(t * 0.73 + 1.3) * 0.04 * 0.7)
		if not _close(slow.rotation, due, Ambience.SWAY_STEP):
			_check(false, "never more than a step behind the clock: %s, %s" % [slow.rotation, due])
			break
	_check(writes > 10 and writes < 300, "a slow sway is written now and then, not every frame: %d of 600" % writes)
	(stage["viewport"] as Node).free()


## However long they drift, a swarm's things stay inside its MultiMesh's own box, which is set.
func _test_swarms_keep_in_their_box() -> void:
	var ambience: VoxelAmbience = Ambience.new()
	ambience.configure({
		"dust": [{"rect": [0, 0, 320, 160], "count": 20, "wind": [1.0, -0.4], "height": [0.2, 1.8]},
			{"rect": [100, 100, 200, 200], "count": 8, "flit": 1.0, "height": [2.0, 2.5]}],
		"fall": [{"rect": [0, 0, 256, 256], "count": 20, "height": 5.0}, {"rect": [0, 0, 64, 64], "count": 6, "height": 3.0, "up": true, "glow": true}],
		"fireflies": [{"rect": [0, 0, 320, 320], "count": 12, "height": 1.0}],
	})
	ambience.night = 1.0
	var swarms: Array[MultiMesh] = []
	for holder: Node in ambience.get_children():
		if holder is MultiMeshInstance3D:
			swarms.append((holder as MultiMeshInstance3D).multimesh)
	_check(swarms.size() == 5, "five swarms: %d" % swarms.size())
	var unbounded: Array[MultiMesh] = swarms.filter(func(multi: MultiMesh) -> bool: return not multi.custom_aabb.has_volume())
	_check(unbounded.is_empty(), "every swarm has its own box")
	# The headless renderer keeps no instance transforms: the places are asked for as advance() sets them.
	var strays: Array[String] = []
	for step: int in 400:
		ambience.advance(0.137)
		var places: Array[Array] = []
		for mote: Dictionary in ambience._motes:
			places.append([mote["multi"], ambience._mote_place(mote)])
		for needle: Dictionary in ambience._falling:
			places.append([needle["multi"], ambience._needle_pose(needle).origin])
		for fly: Dictionary in ambience._fireflies:
			places.append([fly["multi"], ambience._fly_pose(fly).origin])
		for place: Array in places:
			var box: AABB = (place[0] as MultiMesh).custom_aabb
			if not box.grow(0.001).has_point(place[1]):
				strays.append("%s at %s" % [box, place[1]])
		if not strays.is_empty():
			break
	_check(strays.is_empty(), "every thing stays in its swarm's box: %s" % [strays.slice(0, 3)])
	ambience.free()


func _test_swarm_out_of_sight_is_left(tree: SceneTree) -> void:
	var stage: Dictionary = _stage(tree)
	var ambience: VoxelAmbience = stage["ambience"]
	ambience.configure({"fall": [{"rect": [9600, 0, 9700, 100], "count": 4, "height": 5.0}, {"rect": [-64, -64, 64, 64], "count": 4, "height": 5.0}]})
	ambience.camera = stage["camera"]
	ambience.advance(0.1)
	_check(not ambience._rect_in_sight(ambience._falling[0]), "a swarm out of sight is left")
	_check(ambience._rect_in_sight(ambience._falling[4]), "a swarm in sight is moved")
	(stage["viewport"] as Node).free()


func _close(a: Vector3, b: Vector3, within: float) -> bool:
	return absf(a.x - b.x) <= within + 0.00001 and absf(a.y - b.y) <= within + 0.00001 and absf(a.z - b.z) <= within + 0.00001


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
