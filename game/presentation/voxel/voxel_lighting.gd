class_name VoxelLighting
extends RefCounted

## A presentation-only light of the day (DECISIONS「昼夜」). It never advances the authored
## game clock: the view gives it the DayClock's minute (set_time()) or holds a frame
## (set_frame(): the 昼夜 setting's 一直白天 / 一直夜晚, a test's night).
##
## Five keyframes, DayPhaseDefinition.FRAMES: dawn (微曦 + 日出), day (上午 / 正午 / 下午),
## dusk (傍晚), night (夜晚), midnight (午夜). Each phase's frame holds through its middle and
## blends into the next across the phase boundary, so no phase change jumps.
const FRAMES: Array[String] = DayPhaseDefinition.FRAMES
## Where on the 1440-minute day each frame is purely itself: a profile that leaves a frame
## out gets it interpolated between the written frames on either side by these.
const FRAME_MINUTES: Dictionary[String, float] = {"dawn": 180.0, "day": 630.0, "dusk": 990.0, "night": 1140.0, "midnight": 1320.0}
## How far into night each frame is: the lamps' energy, the windows' glow, the moonlight
## and fireflies (night_only, haze), the occlusion's night tint. The lamps come up from dusk.
const FRAME_NIGHT: Dictionary[String, float] = {"dawn": 0.5, "day": 0.0, "dusk": 0.45, "night": 1.0, "midnight": 1.0}
## The sun's (or moon's) [pitch, yaw] per frame: low in the east at dawn, high by day, low
## in the west at dusk, the moon up by night. A profile's `sun_angle` frames override.
const SUN_ANGLES: Dictionary[String, Array] = {"dawn": [-36.0, -74.0], "day": [-55.0, -32.0], "dusk": [-36.0, 24.0], "night": [-43.0, -55.0], "midnight": [-52.0, -62.0]}
## A frame's margin: how much of a phase group blends into its neighbours (a quarter of the
## group, at most this many minutes each side).
const BLEND_MINUTES: float = 60.0
## How long a held frame (a setting's switch) takes to blend in, in real seconds.
const FRAME_FADE_SECONDS: float = 0.9
const LAMP_FADE_BEGIN: float = 18.0
const LAMP_FADE_END: float = 26.0
## Keys that are not frame maps: merged whole (merge_profile()).
const WHOLE_KEYS: Array[String] = ["carried", "areas", "note"]

var environment: Environment
var sun: DirectionalLight3D
var occlusion: VoxelOcclusion
var lamps: Array[Light3D] = []
var windows: Array[StandardMaterial3D] = []
## Translucent light (a moonbeam through the pines): materials whose meta `haze` holds
## their [day, night] opacity.
var hazes: Array[StandardMaterial3D] = []
## How far into night the light is now (0 day .. 1 night): the frames' FRAME_NIGHT by weight.
var amount: float = 0.0
var indoor: bool = false
## The light profile (the region's light.json merged with the layout's `light`): each of
## "sky", "ambient", "ambient_energy", "sun", "sun_energy", "sun_angle" either a frame map
## {"dawn": .., "day": .., ..} (a frame left out is interpolated) or the older [day, night]
## pair (read as day and night, midnight as night); "carried": a soft light that goes with
## the player (a dark cave); "fog": {"color", "density" (frame maps or pairs), "height",
## "height_density", "depth"}: haze that thickens below `height` (the depths of a gorge, the
## ground far under a tree); "areas": [{"rect": px, any of the keys above}]: parts of the map
## under skies of their own (迷阵's illusions, each its own weather), the first holding the
## player winning over the map's.
var profile: Dictionary = {}
## The frames' weights now and where they go (set_time(), set_frame()).
var weights: Dictionary[String, float] = {"dawn": 0.0, "day": 1.0, "dusk": 0.0, "night": 0.0, "midnight": 0.0}
var _target: Dictionary[String, float] = weights.duplicate()
var _area: int = -1
var carried: OmniLight3D
var _player: Vector3 = Vector3.ZERO
## Fire and candle lights (meta `flicker`: how much their energy wavers).
var flickering: Array[Light3D] = []
var _clock: float = 0.0
## The phases set_time() reads (the catalog's; a test may give its own).
var phases: Array[DayPhaseDefinition] = []
## Resolved frame maps by area and key (cleared with the profile).
var _resolved: Dictionary[String, Dictionary] = {}

func build(world: Node3D, reveal: VoxelOcclusion, interior: bool, settings: Dictionary = {}) -> void:
	indoor = interior
	profile = settings
	_resolved.clear()
	occlusion = reveal
	if phases.is_empty():
		phases = GameContent.catalog().day_phases()
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
	# A flash of lightning keeps its own energy (VoxelAmbience).
	for light: Light3D in lamps.duplicate():
		if light.has_meta("own_energy"):
			light.shadow_enabled = false
			lamps.erase(light)
			flickering.erase(light)
	var seen: Dictionary[int,bool] = {}
	for node: Node in world.find_children("*","GeometryInstance3D",true,false):
		var mat := (node as GeometryInstance3D).material_override as StandardMaterial3D
		if mat != null and mat.get_meta("night_only",false) and not seen.has(mat.get_instance_id()):
			seen[mat.get_instance_id()] = true
			windows.append(mat)
		if mat != null and mat.has_meta("haze") and not seen.has(mat.get_instance_id()):
			seen[mat.get_instance_id()] = true
			hazes.append(mat)
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

## Lets go of a freed world's nodes and materials (WorldVoxelView.release_world()); the
## phases and the frame weights stay, so the next build() lights the same hour the same way.
func release() -> void:
	environment = null
	sun = null
	occlusion = null
	carried = null
	lamps.clear()
	windows.clear()
	hazes.clear()
	flickering.clear()
	profile = {}
	_resolved.clear()
	_area = -1

## Holds one frame: 一直白天 / 一直夜晚, or a test's night. Blends over FRAME_FADE_SECONDS
## unless `immediate`.
func set_frame(frame: String, immediate: bool = false) -> void:
	for name: String in FRAMES:
		_target[name] = 1.0 if name == frame else 0.0
	if immediate:
		weights = _target.duplicate()
		_apply()

## Day or night at once (the older two-frame call, kept for the suites and kits).
func set_night(enabled: bool, immediate: bool = false) -> void:
	set_frame("night" if enabled else "day", immediate)

## Follows the day: the light `minutes` into it (DayClock.day_minutes()). The first call
## after a build snaps; later ones move with the clock.
func set_time(minutes: float, immediate: bool = false) -> void:
	_target = frame_weights_at(minutes, phases)
	if immediate:
		weights = _target.duplicate()
		_apply()

## The frames' weights `minutes` into a day of `day_phases`: the phase's frame, pure through
## the middle of its run of phases, blending linearly into the next frame's over the margins
## either side of the boundary (BLEND_MINUTES at most). Without phases: day.
static func frame_weights_at(minutes: float, day_phases: Array[DayPhaseDefinition]) -> Dictionary[String, float]:
	var result: Dictionary[String, float] = {"dawn": 0.0, "day": 0.0, "dusk": 0.0, "night": 0.0, "midnight": 0.0}
	if day_phases.is_empty():
		result["day"] = 1.0
		return result
	# Runs of phases of one frame: [frame, start, end] in minutes.
	var groups: Array[Array] = []
	var at: float = 0.0
	for phase: DayPhaseDefinition in day_phases:
		if not groups.is_empty() and groups[-1][0] == phase.frame:
			groups[-1][2] += float(phase.minutes)
		else:
			groups.append([phase.frame, at, at + float(phase.minutes)])
		at += float(phase.minutes)
	var day: float = at
	if groups.size() > 1 and groups[0][0] == groups[-1][0]:
		groups[0][1] = groups[-1][1] - day
		groups.remove_at(groups.size() - 1)
	var m: float = fposmod(minutes, day)
	if m < groups[0][1]:
		m += day
	var count: int = groups.size()
	for index: int in count:
		var group: Array = groups[index]
		if m < group[1] or m >= group[2]:
			continue
		var margin: float = minf((group[2] - group[1]) / 4.0, BLEND_MINUTES)
		var previous: Array = groups[(index - 1 + count) % count]
		var next: Array = groups[(index + 1) % count]
		var previous_margin: float = minf((previous[2] - previous[1]) / 4.0, BLEND_MINUTES)
		var next_margin: float = minf((next[2] - next[1]) / 4.0, BLEND_MINUTES)
		if count > 1 and m < group[1] + margin:
			var t: float = (m - (group[1] - previous_margin)) / (previous_margin + margin)
			result[previous[0]] += 1.0 - t
			result[group[0]] += t
		elif count > 1 and m >= group[2] - margin:
			var t: float = (m - (group[2] - margin)) / (margin + next_margin)
			result[group[0]] += 1.0 - t
			result[next[0]] += t
		else:
			result[group[0]] = 1.0
		return result
	result["day"] = 1.0
	return result

## The layout's `light` over the region's default: a frame map over a frame map merges
## frame by frame (a map writing only "dusk" keeps the region's other frames); a [day, night]
## pair, a number, "carried", "areas" or "fog"'s plain keys replace the region's whole key.
static func merge_profile(base: Dictionary, over: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key: String in over:
		var value: Variant = over[key]
		if key == "fog" and value is Dictionary and result.get("fog") is Dictionary:
			result["fog"] = merge_profile(result["fog"], value)
		elif value is Dictionary and result.get(key) is Dictionary and not WHOLE_KEYS.has(key):
			var frames: Dictionary = (result[key] as Dictionary).duplicate()
			frames.merge(value, true)
			result[key] = frames
		else:
			result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result

func advance(delta: float, player: Vector3) -> void:
	_player = player
	var area: int = _area_at(player)
	var changed: bool = false
	if area != _area:
		_area = area
		changed = true
	if carried != null:
		carried.position = player+Vector3(0.3,1.9,0.3)
	var step: float = delta/FRAME_FADE_SECONDS
	for name: String in FRAMES:
		var goal: float = _target[name]
		if not is_equal_approx(weights[name],goal):
			weights[name] = move_toward(weights[name],goal,step)
			changed = true
	if changed:
		_apply()
	elif not indoor or not flickering.is_empty():
		_apply_lamps(amount)
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

## The weights as a share each (they drift off one while blending).
func _shares() -> Dictionary[String, float]:
	var total: float = 0.0
	for name: String in FRAMES:
		total += weights[name]
	var shares: Dictionary[String, float] = {}
	for name: String in FRAMES:
		shares[name] = weights[name]/total if total > 0.0 else (1.0 if name == "day" else 0.0)
	return shares

func _apply() -> void:
	if environment==null:
		return
	var shares: Dictionary[String, float] = _shares()
	amount = 0.0
	for name: String in FRAMES:
		amount += shares[name]*FRAME_NIGHT[name]
	environment.background_color = _color("sky",["9cb5ac","111e35"],shares)
	environment.ambient_light_color = _color("ambient",["c7bdac","929bac"] if indoor else ["b4c4c9","738db8"],shares)
	environment.ambient_light_energy = _amount("ambient_energy",[0.55,0.43] if indoor else [0.38,0.30],shares)
	sun.light_color = _color("sun",["fff0d6","91b3ee"],shares)
	sun.light_energy = _amount("sun_energy",[0.40,0.10] if indoor else [0.85,0.32],shares)
	var angle := Vector3.ZERO
	var angles: Dictionary = _frames("sun_angle",SUN_ANGLES)
	for name: String in FRAMES:
		var pair: Array = angles[name]
		angle += Vector3(float(pair[0]),float(pair[1]),0.0)*shares[name]
	sun.rotation_degrees = angle
	_apply_lamps(amount)
	for mat: StandardMaterial3D in windows:
		mat.emission_energy_multiplier = amount*0.9
	for mat: StandardMaterial3D in hazes:
		var opacity: Array = mat.get_meta("haze")
		mat.albedo_color.a = lerpf(float(opacity[0]),float(opacity[1]),amount)
	var fog_source: Dictionary = _source("fog")
	if fog_source.has("fog"):
		var fog: Dictionary = fog_source["fog"]
		environment.fog_enabled = true
		# `depth`: [begin, end] units from the camera — what lies far behind the place (another of
		# the 迷阵's illusions on the same line of sight) fades out into the fog by `depth_density`.
		# The mode goes first, and only when it changes: assigning `fog_mode` in Godot 4.7.2 resets
		# `fog_density` to 1.0, which set after the density here fogged every outdoor map solid.
		var depth_fog: bool = fog.has("depth")
		var mode: Environment.FogMode = Environment.FOG_MODE_DEPTH if depth_fog else Environment.FOG_MODE_EXPONENTIAL
		if environment.fog_mode != mode:
			environment.fog_mode = mode
		environment.fog_light_color = _blend_color(_resolve("fog.color.%d" % _area,fog.get("color",["9fb0a8","1c2433"])),shares)
		if depth_fog:
			var depth: Array = fog["depth"]
			environment.fog_depth_begin = float(depth[0])
			environment.fog_depth_end = float(depth[1])
			environment.fog_density = float(fog.get("depth_density",1.0))
		else:
			environment.fog_density = _blend_amount(_resolve("fog.density.%d" % _area,fog.get("density",[0.0,0.0])),shares)
		environment.fog_height = float(fog.get("height",-1.0))
		environment.fog_height_density = float(fog.get("height_density",0.4))
		environment.fog_sky_affect = 0.0
	elif environment.fog_enabled:
		environment.fog_enabled = false
	occlusion.set_night(amount)

func _color(key: String, fallback: Array, shares: Dictionary[String, float]) -> Color:
	return _blend_color(_frames(key,fallback),shares)

func _amount(key: String, fallback: Array, shares: Dictionary[String, float]) -> float:
	return _blend_amount(_frames(key,fallback),shares)

static func _blend_color(frames: Dictionary, shares: Dictionary[String, float]) -> Color:
	var result := Color(0,0,0,0)
	for name: String in FRAMES:
		result += Color(String(frames[name]))*shares[name]
	return result

static func _blend_amount(frames: Dictionary, shares: Dictionary[String, float]) -> float:
	var result: float = 0.0
	for name: String in FRAMES:
		result += float(frames[name])*shares[name]
	return result

## `key`'s five frames from where the player is (the area's or the map's; `fallback` when
## neither writes it), resolved and cached.
func _frames(key: String, fallback: Variant) -> Dictionary:
	var source: Dictionary = _source(key)
	return _resolve("%s.%d" % [key,_area],source.get(key,fallback))

## A written value as five frames: a frame map (missing frames interpolated by FRAME_MINUTES
## between the written ones), or a [day, night] pair (midnight as night).
func _resolve(cache_key: String, value: Variant) -> Dictionary:
	if _resolved.has(cache_key):
		return _resolved[cache_key]
	var frames: Dictionary = resolve_frames(value)
	_resolved[cache_key] = frames
	return frames

static func resolve_frames(value: Variant) -> Dictionary:
	var known: Dictionary = {}
	if value is Dictionary:
		for name: String in FRAMES:
			if (value as Dictionary).has(name):
				known[name] = value[name]
	elif value is Array and (value as Array).size() >= 2:
		known = {"day": value[0], "night": value[1], "midnight": value[1]}
	if known.is_empty():
		return {}
	var result: Dictionary = {}
	for name: String in FRAMES:
		if known.has(name):
			result[name] = known[name]
			continue
		# The nearest written frames before and after on the day's circle.
		var at: float = FRAME_MINUTES[name]
		var before: String = ""
		var before_gap: float = INF
		var after: String = ""
		var after_gap: float = INF
		for other: String in known:
			var gap_before: float = fposmod(at-FRAME_MINUTES[other],1440.0)
			var gap_after: float = fposmod(FRAME_MINUTES[other]-at,1440.0)
			if gap_before < before_gap:
				before_gap = gap_before
				before = other
			if gap_after < after_gap:
				after_gap = gap_after
				after = other
		var t: float = before_gap/(before_gap+after_gap) if before != after else 0.0
		var a: Variant = known[before]
		var b: Variant = known[after]
		if a is String:
			result[name] = Color(String(a)).lerp(Color(String(b)),t).to_html(false)
		elif a is Array:
			var mixed: Array = []
			for index: int in (a as Array).size():
				mixed.append(lerpf(float(a[index]),float(b[index]),t))
			result[name] = mixed
		else:
			result[name] = lerpf(float(a),float(b),t)
	return result

## Where a key's values come from: the player's area if it sets the key, else the map.
func _source(key: String) -> Dictionary:
	if _area >= 0:
		var area: Dictionary = profile["areas"][_area]
		if area.has(key):
			return area
	return profile

func _area_at(at: Vector3) -> int:
	var areas: Array = profile.get("areas",[])
	for i: int in areas.size():
		var r: Array = areas[i]["rect"]
		if Rect2(r[0],r[1],r[2]-r[0],r[3]-r[1]).has_point(Vector2(at.x,at.z)*32.0):
			return i
	return -1
