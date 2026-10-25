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
	_check(mobile.msaa==Viewport.MSAA_DISABLED and mobile.scale_3d<1.0 and mobile.sun_shadow_splits<4 and mobile.lamp_shadow_limit>=0 and mobile.lamp_light_limit>=0
		and mobile.merged_batches and mobile.foliage_density<1.0,"the phone profile draws less")
	# The limits' mechanics, whatever numbers the profile ships with.
	mobile.lamp_shadow_limit = 2
	mobile.lamp_light_limit = 4
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
	var lit_capped: bool = true
	var smooth: bool = true
	var steady_light: bool = true
	var previous: Dictionary[Light3D, float] = {}
	var previous_energy: Dictionary[Light3D, float] = {}
	# Arriving picks the lit lamps at once (the view builds and advances in one frame).
	lighting.advance(1.0/30.0,Vector3(-4.0,0,2))
	for lamp: Light3D in lighting.lamps:
		previous_energy[lamp] = lamp.light_energy
	for step: int in 120:
		lighting.advance(1.0/30.0,Vector3(-4.0+step*0.1,0,2))
		var shadowed: int = 0
		var lit: int = 0
		for lamp: Light3D in lighting.lamps:
			shadowed += int(lamp.shadow_enabled)
			lit += int(lamp.visible)
			var opacity: float = lamp.shadow_opacity if lamp.shadow_enabled else 0.0
			smooth = smooth and absf(opacity-previous.get(lamp,opacity))<0.1
			previous[lamp] = opacity
			steady_light = steady_light and absf(lamp.light_energy-previous_energy.get(lamp,lamp.light_energy))<0.2
			previous_energy[lamp] = lamp.light_energy
		capped = capped and shadowed<=mobile.lamp_shadow_limit
		lit_capped = lit_capped and lit<=mobile.lamp_light_limit
	_check(capped,"on a phone only the profile's nearest lamps cast shadows")
	_check(lit_capped,"outdoors on a phone only the profile's nearest lamps light")
	_check(smooth,"a phone lamp's shadow fades in and out instead of popping")
	_check(steady_light,"a phone lamp's light fades in and out instead of popping")
	for i: int in 30:
		lighting.advance(0.05,Vector3(2,0,2))
	var settled: int = 0
	for lamp: Light3D in lighting.lamps:
		settled += int(lamp.shadow_enabled)
	_check(settled<=mobile.lamp_shadow_limit,"standing still, no more than the limit cast shadows")
	var nearest: Array[Light3D] = lighting.lamps.duplicate()
	nearest.sort_custom(func(a: Light3D,b: Light3D) -> bool: return a.position.distance_to(Vector3(2,2,2))<b.position.distance_to(Vector3(2,2,2)))
	var chosen: bool = true
	for lamp: Light3D in lighting.lamps:
		chosen = chosen and (not lamp.shadow_enabled or nearest.find(lamp)<mobile.lamp_shadow_limit+1)
	_check(chosen,"the shadows standing still are the nearest lamps'")
	var near: Light3D = null
	for lamp: Light3D in lighting.lamps:
		if near==null or lamp.position.distance_to(Vector3(2,2,2))<near.position.distance_to(Vector3(2,2,2)):
			near = lamp
	_check(near.shadow_enabled and is_equal_approx(near.shadow_opacity,1.0),"the lamp beside the player casts its full shadow on a phone")
	_check(near.visible and is_equal_approx(near.light_energy,2.0),"the lamp beside the player lights at its authored brightness on a phone")
	world.free()
	# By day a window lamp is dark: it must not take a slot from a lantern that lights.
	var street := Node3D.new()
	tree.root.add_child(street)
	var lanterns: Array[OmniLight3D] = []
	for i: int in 4:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(i*1.0,2.0,0)
		if i<2:
			lamp.set_meta("day_energy",0.0)
			lamp.set_meta("night_energy",1.2)
		else:
			lamp.set_meta("day_energy",1.1)
			lamp.set_meta("night_energy",2.8)
			lanterns.append(lamp)
		street.add_child(lamp)
	var day := VoxelLighting.new()
	day.quality = VoxelRenderQuality.named("mobile")
	day.quality.lamp_light_limit = 2
	day.build(street,VoxelOcclusion.new(),false)
	day.set_night(false,true)
	day.advance(1.0/30.0,Vector3.ZERO)
	_check(lanterns.all(func(l: OmniLight3D) -> bool: return l.visible and is_equal_approx(l.light_energy,1.1)),
		"by day the phone's lit lamps are the nearest that give light, lit at once on arrival")
	street.free()
	var room := Node3D.new()
	tree.root.add_child(room)
	for i: int in 6:
		var candle := OmniLight3D.new()
		candle.position = Vector3(i*2.0,2.0,0)
		candle.light_energy = 0.5
		candle.set_meta("night_energy",2.0)
		room.add_child(candle)
	var inside := VoxelLighting.new()
	inside.quality = mobile
	inside.build(room,VoxelOcclusion.new(),true)
	inside.set_night(true,true)
	for i: int in 20:
		inside.advance(0.05,Vector3.ZERO)
	var every: bool = true
	for lamp: Light3D in inside.lamps:
		every = every and lamp.visible and is_equal_approx(lamp.light_energy,2.0)
	_check(every,"indoors on a phone every lamp still lights")
	room.free()
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
	_check_merged_batches(tree)

## The phone profile's batching: plain colours share one batch with a colour per instance,
## every caster's shadow is one shadow-only batch, special materials keep their own.
func _check_merged_batches(tree: SceneTree) -> void:
	var holder := Node3D.new()
	tree.root.add_child(holder)
	var shapes := Shapes.new()
	shapes.merged_batches = true
	for i: int in 3:
		shapes.box(holder,Vector3(i,0,0),Vector3.ONE,["91836a","4f6b47","c9a37a"][i])
	shapes.box(holder,Vector3(0,1,0),Vector3.ONE,"527581:gloss")
	shapes.window(holder,Vector3(1,1,0),Vector3(0.5,0.5,0.1))
	var fixture := Node3D.new()
	fixture.set_meta("light_fixture",true)
	holder.add_child(fixture)
	shapes.box(fixture,Vector3(2,1,0),Vector3.ONE,"993f35")
	shapes.flush()
	var tinted: Array[MultiMeshInstance3D] = []
	var shadows: Array[MultiMeshInstance3D] = []
	var own: Array[MultiMeshInstance3D] = []
	for child: Node in holder.get_children():
		var batch := child as MultiMeshInstance3D
		if batch==null:
			continue
		if batch.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			shadows.append(batch)
		elif batch.multimesh.use_colors:
			tinted.append(batch)
		else:
			own.append(batch)
	var colours: Array[Color] = []
	if tinted.size()==1:
		for i: int in tinted[0].multimesh.instance_count:
			colours.append(tinted[0].multimesh.get_instance_color(i))
	# The headless dummy renderer does not keep instance colours.
	var coloured: bool = DisplayServer.get_name()=="headless" or colours.has(Color("4f6b47").srgb_to_linear())
	_check(tinted.size()==1 and colours.size()==3 and coloured and (tinted[0].material_override as StandardMaterial3D).vertex_color_use_as_albedo
		and tinted[0].cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"three plain colours draw as one batch, each box in its own colour")
	_check(own.size()==2 and own.all(func(b: MultiMeshInstance3D) -> bool: return b.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),
		"the glossy colour and the night window keep their own materials, their shadows drawn elsewhere")
	_check(shadows.size()==1 and shadows[0].multimesh.instance_count==5,"every caster's shadow is one shadow-only batch, whatever its colour")
	var lamp_batch := fixture.get_child(0) as MultiMeshInstance3D
	_check(fixture.get_child_count()==1 and not lamp_batch.multimesh.use_colors and lamp_batch.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"a lantern housing keeps its own unshadowed batch")
	# An occluder drawn in merged batches: its colours reach the reveal shaders through the
	# instance colours, and its shadow-only caster keeps casting.
	var occlusion := VoxelOcclusion.new()
	occlusion.register(holder)
	var reveal := tinted[0].material_override as ShaderMaterial
	_check(reveal!=null and reveal.get_shader_parameter("vertex_tint") and shadows[0].material_override is StandardMaterial3D
		and shadows[0].cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"a merged occluder reveals in its instance colours and keeps its shadow")
	holder.free()
	# Splitting a merged batch to stay within Mobile's eight lights keeps each box's colour.
	var row := Node3D.new()
	tree.root.add_child(row)
	var split := Shapes.new()
	split.merged_batches = true
	var hexes: Array[String] = []
	for i: int in 24:
		hexes.append(["91836a","4f6b47","c9a37a"][i%3])
		split.box(row,Vector3(i*1.5,0,0),Vector3.ONE,hexes[i])
	var lights: Array[AABB] = []
	for i: int in 12:
		lights.append(AABB(Vector3(i*3.0-1.0,-1,-1),Vector3(2,3,2)))
	split.flush(lights)
	var pieces: int = 0
	var boxes: int = 0
	var kept: bool = true
	for child: Node in row.get_children():
		var batch := child as MultiMeshInstance3D
		if batch==null or not batch.multimesh.use_colors:
			continue
		pieces += 1
		boxes += batch.multimesh.instance_count
		if DisplayServer.get_name()!="headless":
			for i: int in batch.multimesh.instance_count:
				var at: Vector3 = batch.multimesh.get_instance_transform(i).origin
				kept = kept and batch.multimesh.get_instance_color(i).is_equal_approx(Color(hexes[roundi(at.x/1.5)]).srgb_to_linear())
	_check(pieces>1 and boxes==24 and kept,"a merged batch split for the light budget keeps every box in its own colour")
	row.free()

func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
