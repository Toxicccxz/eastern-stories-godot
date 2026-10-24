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
	_check_profiles(tree)
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

## Desktop keeps the full look; the phone profile thins shadows and grass, never lights.
func _check_profiles(tree: SceneTree) -> void:
	var desktop := VoxelRenderQuality.named("desktop")
	_check(desktop.msaa==Viewport.MSAA_4X and is_equal_approx(desktop.scale_3d,1.0) and desktop.sun_shadow_mode()==DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		and is_equal_approx(desktop.sun_shadow_distance,80.0) and desktop.lamp_shadow_limit<0 and is_equal_approx(desktop.foliage_density,1.0),"the desktop profile is the full look")
	_check(VoxelRenderQuality.current().name=="desktop","a desktop build picks the desktop profile")
	var mobile := VoxelRenderQuality.named("mobile")
	_check(mobile.msaa==Viewport.MSAA_DISABLED and mobile.scale_3d<1.0 and mobile.sun_shadow_splits<4 and mobile.lamp_shadow_limit>0 and mobile.foliage_density<1.0,"the phone profile draws less")
	var world := Node3D.new()
	tree.root.add_child(world)
	for i: int in 12:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3((i%4)*2.0,2.0,(i/4)*2.0)
		lamp.light_energy = 0.5
		lamp.set_meta("night_energy",2.0)
		world.add_child(lamp)
	var lighting := VoxelLighting.new()
	lighting.quality = mobile
	lighting.build(world,VoxelOcclusion.new(),false)
	lighting.set_night(true,true)
	_check(lighting.sun.directional_shadow_mode==mobile.sun_shadow_mode() and is_equal_approx(lighting.sun.directional_shadow_max_distance,mobile.sun_shadow_distance),"the phone sun uses the profile's cascades")
	var capped: bool = true
	var lit: bool = true
	var smooth: bool = true
	var previous: Dictionary[Light3D, float] = {}
	for step: int in 120:
		lighting.advance(1.0/30.0,Vector3(-4.0+step*0.1,0,2))
		var shadowed: int = 0
		for lamp: Light3D in lighting.lamps:
			shadowed += int(lamp.shadow_enabled)
			lit = lit and lamp.visible and is_equal_approx(lamp.light_energy,2.0)
			var opacity: float = lamp.shadow_opacity if lamp.shadow_enabled else 0.0
			smooth = smooth and absf(opacity-previous.get(lamp,opacity))<0.1
			previous[lamp] = opacity
		capped = capped and shadowed<=mobile.lamp_shadow_limit
	_check(capped,"on a phone only the profile's nearest lamps cast shadows")
	_check(lit,"every lamp still lights at its authored brightness on a phone")
	_check(smooth,"a phone lamp's shadow fades in and out instead of popping")
	for i: int in 30:
		lighting.advance(0.05,Vector3(2,0,2))
	var settled: int = 0
	for lamp: Light3D in lighting.lamps:
		settled += int(lamp.shadow_enabled)
	_check(settled<=mobile.lamp_shadow_limit,"standing still, no more than the limit cast shadows")
	var near: Light3D = null
	for lamp: Light3D in lighting.lamps:
		if near==null or lamp.position.distance_to(Vector3(2,2,2))<near.position.distance_to(Vector3(2,2,2)):
			near = lamp
	_check(near.shadow_enabled and is_equal_approx(near.shadow_opacity,1.0),"the lamp beside the player casts its full shadow on a phone")
	world.free()
	var foliage := VoxelFoliage.new()
	foliage.density = 0.5
	tree.root.add_child(foliage)
	for i: int in 10:
		foliage.plant(Vector3(i*0.3,0,0),0,1.0,0.0)
	foliage.butterfly_count = 0
	foliage.finish()
	var drawn: int = 0
	for child: Node in foliage.get_children():
		if child is MultiMeshInstance3D:
			drawn += (child as MultiMeshInstance3D).multimesh.instance_count
	_check(drawn==5 and foliage.roots.size()==10,"a half-density meadow draws every other tuft and keeps every root")
	foliage.free()

func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
