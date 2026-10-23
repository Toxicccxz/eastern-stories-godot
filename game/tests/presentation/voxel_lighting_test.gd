extends RefCounted

const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var assertions: int = 0
var failures: Array[String] = []

func run_all(tree: SceneTree) -> Dictionary:
	var world := Node3D.new()
	tree.root.add_child(world)
	# More than eight nearby lamps reproduced the old rank-based shadow swaps.
	for i: int in 12:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3((i%4)*2.0,2.0,(i/4)*2.0)
		lamp.light_energy = 0.5
		lamp.set_meta("night_energy",2.0)
		world.add_child(lamp)
	var lighting := VoxelLighting.new()
	lighting.build(world,VoxelOcclusion.new(),false)
	lighting.set_night(true,true)
	var steady: bool = true
	for step: int in 80:
		lighting.advance(0.05,Vector3(-4.0+step*0.15,0,2))
		for lamp: Light3D in lighting.lamps:
			steady = steady and lamp.shadow_enabled and lamp.visible and is_equal_approx(lamp.light_energy,2.0)
	_check(steady,"approaching and passing twelve door lamps never swaps shadows or nearby brightness")
	var first: Light3D = lighting.lamps[0]
	var previous: float = first.light_energy
	var smooth: bool = true
	for step: int in 61:
		lighting.advance(1.0/30.0,Vector3(-16.0-step*0.2,0,0))
		smooth = smooth and first.light_energy<=previous+0.0001 and previous-first.light_energy<0.08 and first.shadow_enabled
		previous = first.light_energy
	_check(smooth,"a distant lamp fades its whole light smoothly without losing its shadow first")
	_check(not first.visible and is_zero_approx(first.light_energy),"a fully faded lamp is culled from the renderer")
	lighting.advance(0.1,Vector3(-25.8,0,0))
	_check(first.visible and first.light_energy<0.01 and first.shadow_enabled,"approaching a culled lamp restores it at near-zero brightness with its shadow already enabled")
	lighting.advance(0.1,Vector3.ZERO)
	_check(first.visible and is_equal_approx(first.light_energy,2.0),"returning restores the authored night brightness")
	lighting.set_night(false)
	lighting.advance(0.45,Vector3.ZERO)
	_check(first.light_energy>0.5 and first.light_energy<2.0 and first.shadow_enabled,"day/night blends brightness without switching doorway shadows")
	lighting.advance(0.45,Vector3.ZERO)
	_check(is_equal_approx(first.light_energy,0.5),"daylight restores the authored day brightness")
	# A cut-away parent remains hidden; light updates cannot resurrect its wall window.
	world.visible = false
	lighting.advance(0.1,Vector3.ZERO)
	_check(not first.is_visible_in_tree(),"cut-away or inactive parents still hide their lights")
	world.free()
	var interior := Node3D.new()
	tree.root.add_child(interior)
	var window := SpotLight3D.new()
	window.position = Vector3(40,2,0)
	window.light_energy = 1.2
	interior.add_child(window)
	var indoor := VoxelLighting.new()
	indoor.build(interior,VoxelOcclusion.new(),true)
	indoor.advance(1.0,Vector3.ZERO)
	_check(window.visible and window.shadow_enabled and is_equal_approx(window.light_energy,1.2),"interior windows retain stable authored lighting across a large compound")
	interior.free()
	# The headless dummy renderer returns identity for every MultiMesh transform.
	# Check generated mesh bounds/volume in the native windowed rendering pass.
	if DisplayServer.get_name()!="headless":
		await _check_light_batches(tree)
	return {"assertions":assertions,"failures":failures}

func _check_light_batches(tree: SceneTree) -> void:
	var holder := Node3D.new()
	tree.root.add_child(holder)
	holder.position = Vector3(10,0,-12)
	holder.rotation.y = 0.4
	var shapes := Shapes.new()
	shapes.box(holder,Vector3(0,1,0),Vector3(36,0.2,1),"91836a")
	var lights: Array[AABB] = []
	for i: int in 12:
		lights.append(holder.global_transform*AABB(Vector3(-18.5+i*3.0,-1,-2),Vector3(4,5,4)))
	shapes.flush(lights)
	await RenderingServer.frame_post_draw
	_check(holder.get_child_count()>1,"a long plinth is split when its original batch spans more than eight lights")
	var within_budget: bool = true
	var volume: float = 0.0
	var combined := AABB()
	var first: bool = true
	for child: Node in holder.get_children():
		var mesh := child as MultiMeshInstance3D
		var bounds: AABB = mesh.global_transform*mesh.get_aabb()
		var count: int = 0
		for light: AABB in lights:
			count += int(bounds.intersects(light))
		within_budget = within_budget and count<=8
		for i: int in mesh.multimesh.instance_count:
			var part: AABB = mesh.multimesh.get_instance_transform(i)*mesh.multimesh.mesh.get_aabb()
			volume += part.get_volume()
			combined = part if first else combined.merge(part)
			first = false
	_check(within_budget,"rotated building batches stay within Mobile's eight-light limit")
	_check(is_equal_approx(volume,7.2) and combined.is_equal_approx(AABB(Vector3(-18,0.9,-0.5),Vector3(36,0.2,1))),"light-aware splits preserve the original plinth's extent and volume: %s, %s" % [volume,combined])
	holder.free()
	var plain := Node3D.new()
	tree.root.add_child(plain)
	shapes.box(plain,Vector3.ZERO,Vector3(36,0.2,1),"91836a")
	shapes.flush()
	_check(plain.get_child_count()==1,"geometry without excess lights keeps its original batching")
	plain.free()

func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
