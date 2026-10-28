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
	_check_frames(tree)
	_check_cloud(tree)
	# The headless dummy renderer returns identity for every MultiMesh transform.
	# Check generated mesh bounds/volume in the native windowed rendering pass.
	if DisplayServer.get_name()!="headless":
		await _check_light_batches(tree)
	return {"assertions":assertions,"failures":failures}

## Five frames (DECISIONS「昼夜」): a frame map, the older [day, night] pair reading as before,
## a missing frame interpolated, the time of day blending frames, the lamps up from dusk.
func _check_frames(tree: SceneTree) -> void:
	var world := Node3D.new()
	tree.root.add_child(world)
	var lamp := OmniLight3D.new()
	lamp.light_energy = 0.5
	lamp.set_meta("night_energy",2.0)
	world.add_child(lamp)
	var legacy := VoxelLighting.new()
	legacy.build(world,VoxelOcclusion.new(),false,{"sky":["9cb5ac","111e35"],"ambient_energy":[0.38,0.30]})
	legacy.set_night(true,true)
	_check(legacy.environment.background_color.is_equal_approx(Color("111e35")) and is_equal_approx(legacy.environment.ambient_light_energy,0.30) and is_equal_approx(legacy.amount,1.0) and is_equal_approx(lamp.light_energy,2.0),"a [day, night] pair by night: as before")
	legacy.set_night(false,true)
	_check(legacy.environment.background_color.is_equal_approx(Color("9cb5ac")) and is_equal_approx(legacy.environment.ambient_light_energy,0.38) and is_zero_approx(legacy.amount) and is_equal_approx(lamp.light_energy,0.5),"by day: as before")
	legacy.set_frame("midnight",true)
	_check(legacy.environment.background_color.is_equal_approx(Color("111e35")) and is_equal_approx(lamp.light_energy,2.0),"a pair's midnight is its night")
	legacy.set_frame("dusk",true)
	_check(is_equal_approx(legacy.amount,0.45) and is_equal_approx(lamp.light_energy,lerpf(0.5,2.0,0.45)) and is_equal_approx(legacy.sun.rotation_degrees.y,24.0),"at dusk the lamps are coming up and the sun is low in the west")
	legacy.set_frame("dawn",true)
	_check(is_equal_approx(legacy.sun.rotation_degrees.y,-74.0) and is_equal_approx(legacy.sun.rotation_degrees.x,-36.0),"at dawn the sun is low in the east")
	world.free()
	var framed := Node3D.new()
	tree.root.add_child(framed)
	var five := VoxelLighting.new()
	five.phases = GameContent.catalog().day_phases()
	five.build(framed,VoxelOcclusion.new(),false,{"sky":{"dawn":"ff0000","day":"00ff00","dusk":"0000ff","night":"000000","midnight":"ffffff"},"sun_energy":{"day":1.0,"night":0.0}})
	var colors: Dictionary = {"dawn":Color.RED,"day":Color.GREEN,"dusk":Color.BLUE,"night":Color.BLACK,"midnight":Color.WHITE}
	var each: bool = true
	for frame: String in VoxelLighting.FRAMES:
		five.set_frame(frame,true)
		each = each and five.environment.background_color.is_equal_approx(colors[frame])
	_check(each,"each frame's own sky")
	five.set_frame("dusk",true)
	_check(is_equal_approx(five.sun.light_energy,1.0-360.0/510.0),"a missing frame is interpolated between its neighbours")
	five.set_time(360.0,true)
	_check(five.environment.background_color.is_equal_approx(Color(0.5,0.5,0.0)) and is_equal_approx(five.amount,0.25),"6:00 is half dawn, half day")
	five.set_time(630.0,true)
	five.set_time(990.0)
	five.advance(0.3,Vector3.ZERO)
	_check(five.environment.background_color.g>0.6 and five.environment.background_color.b>0.3 and five.environment.background_color.b<0.4,"a held frame blends over 0.9 s, not at once")
	five.advance(1.0,Vector3.ZERO)
	_check(five.environment.background_color.is_equal_approx(Color.BLUE),"and arrives")
	framed.free()


## The cloud (DECISIONS「天气」): each level greys and dims the day toward the region's
## overcast (or the default), softens the shadow, blends over twenty seconds, passes over as
## a drifting shadow at the 白云 levels, changes nothing indoors; a depth fog's density by frame.
func _check_cloud(tree: SceneTree) -> void:
	var world := Node3D.new()
	tree.root.add_child(world)
	var lighting := VoxelLighting.new()
	lighting.phases = GameContent.catalog().day_phases()
	lighting.build(world,VoxelOcclusion.new(),false,{"sky":{"day":"80c0a0","night":"102030"},"ambient_energy":{"day":0.4,"night":0.3},"sun_energy":{"day":1.0,"night":0.3},"overcast":{"sky":"8090a0","ambient":"90a0a8","sun":"e0e0e0"}})
	lighting.set_frame("day",true)
	var clear_sky: Color = lighting.environment.background_color
	var clear_sun: float = lighting.sun.light_energy
	var clear_ambient: float = lighting.environment.ambient_light_energy
	_check(is_zero_approx(lighting.cloud) and is_equal_approx(clear_sun,1.0) and clear_sky.is_equal_approx(Color("80c0a0")),"clear by day: the day's own light")
	lighting.set_cloud_level(4,true)
	_check(is_equal_approx(lighting.cloud,1.0) and is_equal_approx(lighting.sun.light_energy,0.4) and lighting.environment.background_color.is_equal_approx(Color("80c0a0").lerp(Color("8090a0"),0.85)) and lighting.sun.light_color.is_equal_approx(Color("fff0d6").lerp(Color("e0e0e0"),0.6)),"乌云密布 by day: the sun at two fifths, the sky toward the region's overcast, the sun whitened: %s %s" % [lighting.sun.light_energy,lighting.environment.background_color])
	_check(is_equal_approx(lighting.environment.ambient_light_energy,clear_ambient*1.12) and is_equal_approx(lighting.sun.shadow_blur,3.5),"the ambient up a little, the shadow soft")
	lighting.set_cloud_level(2,true)
	_check(is_equal_approx(lighting.cloud,0.42) and lighting.sun.light_energy<clear_sun*(1.0-0.6*0.42)+0.001 and lighting.sun.light_energy>clear_sun*(1.0-0.6*0.42)*(1.0-0.16)-0.001,"白云飘来飘去: the sun under its cloud and a passing shadow: %s" % lighting.sun.light_energy)
	var here: float = lighting.cloud_shadow_at(Vector3.ZERO,0.0)
	var there: float = lighting.cloud_shadow_at(Vector3(40,0,40),0.0)
	var later: float = lighting.cloud_shadow_at(Vector3.ZERO,120.0)
	_check(here>=0.0 and here<=1.0 and there>=0.0 and there<=1.0 and not is_equal_approx(here,there) and not is_equal_approx(here,later),"the shadow differs across the map and drifts with time: %s %s %s" % [here,there,later])
	lighting.set_cloud_level(0,true)
	_check(is_zero_approx(lighting.cloud) and is_equal_approx(lighting.sun.light_energy,clear_sun) and lighting.environment.background_color.is_equal_approx(clear_sky) and is_equal_approx(lighting.sun.shadow_blur,1.0),"clear again: as before")
	lighting.set_cloud_level(4)
	lighting.advance(1.0,Vector3.ZERO)
	_check(is_equal_approx(lighting.cloud,0.05) and lighting.sun.light_energy<clear_sun and lighting.sun.light_energy>clear_sun*0.9,"a change blends over twenty seconds: %s" % lighting.cloud)
	lighting.advance(30.0,Vector3.ZERO)
	_check(is_equal_approx(lighting.cloud,1.0),"and arrives")
	lighting.set_frame("night",true)
	var night_sky: Color = lighting.environment.background_color
	_check(night_sky.r<0.2 and night_sky.g<0.2 and night_sky.b<0.25 and is_equal_approx(lighting.sun.light_energy,0.12),"by night the cloud darkens the sky further and takes most of the moon: %s" % night_sky)
	world.free()
	var plain := Node3D.new()
	tree.root.add_child(plain)
	var bare := VoxelLighting.new()
	bare.build(plain,VoxelOcclusion.new(),false,{"sky":["80c0a0","102030"]})
	bare.set_frame("day",true)
	bare.set_cloud_level(4,true)
	_check(bare.environment.background_color.is_equal_approx(Color("80c0a0").lerp(Color(VoxelLighting.OVERCAST_DEFAULT["sky"]),0.85)),"without an overcast of its own a map greys to the default")
	plain.free()
	var interior := Node3D.new()
	tree.root.add_child(interior)
	var indoor := VoxelLighting.new()
	indoor.build(interior,VoxelOcclusion.new(),true,{"sky":["c0b0a0","202030"]})
	indoor.set_frame("day",true)
	var inside_sun: float = indoor.sun.light_energy
	indoor.set_cloud_level(4,true)
	indoor.advance(30.0,Vector3.ZERO)
	_check(is_zero_approx(indoor.cloud) and is_equal_approx(indoor.sun.light_energy,inside_sun) and indoor.environment.background_color.is_equal_approx(Color("c0b0a0")) and is_equal_approx(indoor.sun.shadow_blur,1.0),"indoors the cloud changes nothing")
	interior.free()
	var misty := Node3D.new()
	tree.root.add_child(misty)
	var fogged := VoxelLighting.new()
	fogged.phases = GameContent.catalog().day_phases()
	fogged.build(misty,VoxelOcclusion.new(),false,{"fog":{"color":{"dawn":"e6eef0","day":"d6e0e4","dusk":"d6dce0","night":"141c2a","midnight":"101828"},"depth":[44,84],"depth_density":{"dawn":0.6,"day":0.0,"dusk":0.0,"night":0.0,"midnight":0.0}}})
	fogged.set_frame("dawn",true)
	_check(fogged.environment.fog_enabled and fogged.environment.fog_mode==Environment.FOG_MODE_DEPTH and is_equal_approx(fogged.environment.fog_density,0.6) and is_equal_approx(fogged.environment.fog_depth_begin,44.0) and fogged.environment.fog_light_color.is_equal_approx(Color("e6eef0")),"the morning mist at dawn, past the player, cold white: %s" % fogged.environment.fog_density)
	fogged.set_frame("day",true)
	_check(is_zero_approx(fogged.environment.fog_density),"gone by day")
	fogged.set_time(330.0,true)
	_check(fogged.environment.fog_density>0.0 and fogged.environment.fog_density<0.6,"thinning as 日出 ends: %s" % fogged.environment.fog_density)
	fogged.set_frame("night",true)
	_check(is_zero_approx(fogged.environment.fog_density) and fogged.environment.fog_height<0.0,"none by night, and no height fog unless written")
	misty.free()

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
