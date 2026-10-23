class_name VoxelLighting
extends RefCounted

## A presentation-only day/night blend. It never advances the authored game clock.
var environment: Environment
var sun: DirectionalLight3D
var occlusion: VoxelOcclusion
var lamps: Array[Light3D] = []
var windows: Array[StandardMaterial3D] = []
var amount: float = 0.0
var target: float = 0.0
var indoor: bool = false
var _shadow_elapsed: float = 1.0

func build(world: Node3D, reveal: VoxelOcclusion, interior: bool) -> void:
	indoor = interior
	occlusion = reveal
	var sky := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	sky.environment = environment
	world.add_child(sky)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.15
	sun.shadow_normal_bias = 0.65
	world.add_child(sun)
	for node: Node in world.find_children("*","Light3D",true,false):
		if not (node is OmniLight3D or node is SpotLight3D):
			continue
		var light := node as Light3D
		light.set_meta("day_energy",light.get_meta("day_energy",light.light_energy))
		light.set_meta("night_energy",light.get_meta("night_energy",light.light_energy*1.7))
		light.shadow_bias = 0.06
		light.shadow_normal_bias = 0.45
		light.shadow_blur = 1.5
		lamps.append(light)
	var seen: Dictionary[int,bool] = {}
	for node: Node in world.find_children("*","GeometryInstance3D",true,false):
		var mat := (node as GeometryInstance3D).material_override as StandardMaterial3D
		if mat != null and mat.get_meta("night_only",false) and not seen.has(mat.get_instance_id()):
			seen[mat.get_instance_id()] = true
			windows.append(mat)
	_apply()

func set_night(enabled: bool, immediate: bool = false) -> void:
	target = 1.0 if enabled else 0.0
	if immediate:
		amount = target
		_apply()
	_shadow_elapsed = 1.0

func advance(delta: float, player: Vector3) -> void:
	if not is_equal_approx(amount,target):
		amount = move_toward(amount,target,delta/0.9)
		_apply()
	_shadow_elapsed += delta
	if _shadow_elapsed<0.2:
		return
	_shadow_elapsed = 0.0
	# Only nearby lights need shadow maps; light colour/energy stays continuous.
	var sorted: Array[Light3D] = lamps.duplicate()
	sorted.sort_custom(func(a: Light3D,b: Light3D) -> bool: return a.global_position.distance_squared_to(player)<b.global_position.distance_squared_to(player))
	for i: int in sorted.size():
		# All indoor lamps are stable and shadowed in both modes. Their housings
		# no longer block their own source; walls and furnishings still cast shadows.
		sorted[i].shadow_enabled = indoor or (amount>0.1 and i<8 and sorted[i].global_position.distance_squared_to(player)<225)

func _apply() -> void:
	if environment==null:
		return
	var blend: float = smoothstep(0.0,1.0,amount)
	environment.background_color = Color("9cb5ac").lerp(Color("111e35"),blend)
	environment.ambient_light_color = Color("c7bdac" if indoor else "b4c4c9").lerp(Color("929bac" if indoor else "738db8"),blend)
	environment.ambient_light_energy = lerpf(0.55,0.43,blend) if indoor else lerpf(0.38,0.30,blend)
	sun.light_color = Color("fff0d6").lerp(Color("91b3ee"),blend)
	sun.light_energy = lerpf(0.40,0.10,blend) if indoor else lerpf(0.85,0.32,blend)
	sun.rotation_degrees = Vector3(-55,-32,0).lerp(Vector3(-43,-55,0),blend)
	for lamp: Light3D in lamps:
		lamp.light_energy = lerpf(float(lamp.get_meta("day_energy")),float(lamp.get_meta("night_energy")),blend)
	for mat: StandardMaterial3D in windows:
		mat.emission_energy_multiplier = blend*0.9
	occlusion.set_night(blend)
