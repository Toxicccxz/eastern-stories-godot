class_name VoxelLighting
extends RefCounted

## A presentation-only day/night blend. It never advances the authored game clock.
const LAMP_FADE_BEGIN: float = 18.0
const LAMP_FADE_END: float = 26.0
var environment: Environment
var sun: DirectionalLight3D
var occlusion: VoxelOcclusion
var lamps: Array[Light3D] = []
var windows: Array[StandardMaterial3D] = []
var amount: float = 0.0
var target: float = 0.0
var indoor: bool = false
## Layout `light`: [day, night] pairs for "sky", "ambient", "ambient_energy", "sun",
## "sun_energy"; "carried": a soft light that goes with the player (a dark cave).
var profile: Dictionary = {}
var carried: OmniLight3D
var _player: Vector3 = Vector3.ZERO
## Fire and candle lights (meta `flicker`: how much their energy wavers).
var flickering: Array[Light3D] = []
var _clock: float = 0.0

func build(world: Node3D, reveal: VoxelOcclusion, interior: bool, settings: Dictionary = {}) -> void:
	indoor = interior
	profile = settings
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
		# Never alternate a lit doorway between shadowed and unshadowed as nearby
		# lamps exchange distance ranks. Cull the entire distant light after it fades.
		light.shadow_enabled = true
		lamps.append(light)
		if light.has_meta("flicker"):
			flickering.append(light)
	var seen: Dictionary[int,bool] = {}
	for node: Node in world.find_children("*","GeometryInstance3D",true,false):
		var mat := (node as GeometryInstance3D).material_override as StandardMaterial3D
		if mat != null and mat.get_meta("night_only",false) and not seen.has(mat.get_instance_id()):
			seen[mat.get_instance_id()] = true
			windows.append(mat)
	if profile.has("carried"):
		# Moves every frame: no shadow (its cube map would re-render the whole map each frame).
		var lamp: Dictionary = profile["carried"]
		carried = OmniLight3D.new()
		carried.light_color = Color(String(lamp.get("color","ffc78a")))
		carried.omni_range = float(lamp.get("range",5.0))
		carried.omni_attenuation = float(lamp.get("attenuation",1.4))
		carried.shadow_enabled = false
		carried.set_meta("day_energy",float(lamp.get("day",0.8)))
		carried.set_meta("night_energy",float(lamp.get("night",1.2)))
		world.add_child(carried)
		lamps.append(carried)
	_apply()

func set_night(enabled: bool, immediate: bool = false) -> void:
	target = 1.0 if enabled else 0.0
	if immediate:
		amount = target
		_apply()

func advance(delta: float, player: Vector3) -> void:
	_player = player
	if carried != null:
		carried.position = player+Vector3(0.3,1.9,0.3)
	if not is_equal_approx(amount,target):
		amount = move_toward(amount,target,delta/0.9)
		_apply()
	elif not indoor or not flickering.is_empty():
		_apply_lamps(smoothstep(0.0,1.0,amount))
	_clock += delta

func _apply_lamps(blend: float) -> void:
	for lamp: Light3D in lamps:
		var fade: float = 1.0
		if not indoor:
			var offset: Vector3 = lamp.global_position-_player
			fade = 1.0-smoothstep(LAMP_FADE_BEGIN,LAMP_FADE_END,Vector2(offset.x,offset.z).length())
		var energy: float = lerpf(float(lamp.get_meta("day_energy")),float(lamp.get_meta("night_energy")),blend)*fade
		if lamp.has_meta("flicker"):
			var phase: float = lamp.global_position.x*3.1+lamp.global_position.z*1.7
			energy *= 1.0+float(lamp.get_meta("flicker"))*(sin(_clock*13.0+phase)*0.5+sin(_clock*7.3+phase*2.0)*0.35+sin(_clock*29.0)*0.15)
		if not is_equal_approx(lamp.light_energy,energy):
			lamp.light_energy = energy
		var emitting: bool = energy>0.0
		if lamp.visible!=emitting:
			lamp.visible = emitting

func _apply() -> void:
	if environment==null:
		return
	var blend: float = smoothstep(0.0,1.0,amount)
	environment.background_color = _color("sky",["9cb5ac","111e35"],blend)
	environment.ambient_light_color = _color("ambient",["c7bdac","929bac"] if indoor else ["b4c4c9","738db8"],blend)
	environment.ambient_light_energy = _amount("ambient_energy",[0.55,0.43] if indoor else [0.38,0.30],blend)
	sun.light_color = _color("sun",["fff0d6","91b3ee"],blend)
	sun.light_energy = _amount("sun_energy",[0.40,0.10] if indoor else [0.85,0.32],blend)
	sun.rotation_degrees = Vector3(-55,-32,0).lerp(Vector3(-43,-55,0),blend)
	_apply_lamps(blend)
	for mat: StandardMaterial3D in windows:
		mat.emission_energy_multiplier = blend*0.9
	occlusion.set_night(blend)

func _color(key: String, fallback: Array, blend: float) -> Color:
	var pair: Array = profile.get(key,fallback)
	return Color(String(pair[0])).lerp(Color(String(pair[1])),blend)

func _amount(key: String, fallback: Array, blend: float) -> float:
	var pair: Array = profile.get(key,fallback)
	return lerpf(float(pair[0]),float(pair[1]),blend)
