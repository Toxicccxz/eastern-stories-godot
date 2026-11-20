class_name VoxelWeather
extends Node3D

## 世界演出 (DECISIONS「世界演出」): rain over an outdoor map while the sky is at its darkest
## (SkyState's last level, 天空中乌云密布; DECISIONS「天气」) — thin pale streaks falling about what
## the camera looks at, slanted on the map's wind, and the rings they leave on the ground. It
## comes and goes slowly as the sky turns (world_fx.json `weather`). Two MultiMeshes, moved
## here each frame; each drop keeps its place in the world as the camera moves on (the box of
## rain follows, the drops do not slide with it).
## Presentation only: it reads the sky's level and wets nothing.

const DATA_PATH: String = "res://data/common/world_fx.json"
## The rings lie a little over the ground.
const RING_LIFT: float = 0.08

static var _data: Dictionary = {}

## What falls here ("" nothing) and how much of it is shown now (0 none .. 1 all of it).
var kind: String = ""
var amount: float = 0.0
var _look: Dictionary = {}
var _drops: MultiMesh
var _rings: MultiMesh
var _drop_count: int = 0
var _ring_count: int = 0
## Each drop's place in its box and its moment of the fall (0..1 each); each ring's phase.
var _seeds: PackedVector3Array = []
var _ring_seeds: PackedFloat32Array = []
var _clock: float = 0.0
var _ring_tone := Color.WHITE


## world_fx.json, read once.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func part(key: String) -> Dictionary:
	var section: Variant = data().get(key, {})
	return section if section is Dictionary else {}


## What falls on the map `map_id` of `region_id` ("" nothing): the map's own (a cave drawn as an
## outdoor map has no sky over it), else the region's, else the default; a kind the data does
## not describe is nothing.
static func kind_for(region_id: StringName, map_id: StringName = &"") -> String:
	var weather: Dictionary = part("weather")
	var named: String = String(weather.get("regions", {}).get(String(region_id), weather.get("default", "")))
	named = String(weather.get("maps", {}).get(String(map_id), named))
	return named if weather.get("kinds", {}).has(named) else ""


## How much falls (0 or 1) on a map with the sky at `level`: only outdoors, only where the map
## takes weather, only from the data's level on.
static func falls(level: int, indoor: bool, takes_weather: bool) -> float:
	return 1.0 if not indoor and takes_weather and level >= int(part("weather").get("from_level", 4)) else 0.0


## Builds the drops and rings of `p_kind` (kind_for()); nothing for "".
func configure(p_kind: String, low_quality: bool) -> void:
	kind = p_kind
	_look = part("weather").get("kinds", {}).get(kind, {})
	if _look.is_empty():
		kind = ""
		return
	var share: float = float(part("weather").get("low_quality", 0.5)) if low_quality else 1.0
	_drop_count = maxi(1, int(float(_look.get("count", 160)) * share))
	var size: Array = _look.get("size", [0.025, 0.55, 0.025])
	var height: float = float(_look.get("height", 9.0))
	_drops = _swarm(Vector3(float(size[0]), float(size[1]), float(size[2])), _drop_count, Color(String(_look.get("colour", "c4d2e0")), float(_look.get("alpha", 0.55))), height)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5eed
	_seeds.resize(_drop_count)
	for index: int in _drop_count:
		_seeds[index] = Vector3(rng.randf(), rng.randf(), rng.randf())
	var rings: Dictionary = _look.get("rings", {})
	_ring_count = maxi(0, int(float(rings.get("count", 0)) * share))
	if _ring_count > 0:
		var wide: float = float(rings.get("size", 0.34))
		_ring_tone = Color(String(rings.get("colour", "dfe9f2")), float(rings.get("alpha", 0.5)))
		_rings = _swarm(Vector3(wide, 0.02, wide), _ring_count, _ring_tone, 1.0)
		_ring_seeds.resize(_ring_count)
		for index: int in _ring_count:
			_ring_seeds[index] = rng.randf()
	_show(0)


## Moves the rain on by `delta`: `falling` how much should fall now (falls()), `centre` what the
## camera looks at, `wind` the map's guiding wind (units a second; zero: the kind's own drift).
func advance(delta: float, falling: float, centre: Vector3, wind: Vector2) -> void:
	if kind.is_empty():
		return
	var fade: float = float(part("weather").get("fade_seconds", 6.0))
	amount = move_toward(amount, clampf(falling, 0.0, 1.0), delta / fade if fade > 0.0 and is_finite(delta) else 1.0)
	if not is_finite(delta):
		delta = 0.0
	var shown: int = int(round(float(_drop_count) * amount))
	_show(shown)
	if shown <= 0:
		return
	_clock += delta
	var radius: float = float(_look.get("radius", 13.0))
	var height: float = float(_look.get("height", 9.0))
	var fall: float = maxf(0.1, float(_look.get("fall", 15.0)))
	var drift: Array = _look.get("drift", [0.9, 0.3])
	var blown: Vector2 = wind * float(_look.get("wind", 2.0)) if wind.length_squared() > 0.0001 else Vector2(float(drift[0]), float(drift[1]))
	# A drop lies along its own fall.
	var way: Vector3 = Vector3(blown.x, -fall, blown.y).normalized()
	var side: Vector3 = way.cross(Vector3.FORWARD).normalized()
	var basis := Basis(side, -way, side.cross(-way))
	var span: float = radius * 2.0
	var turn: float = _clock * fall / height
	for index: int in shown:
		var seed: Vector3 = _seeds[index]
		var t: float = fposmod(seed.y + turn, 1.0)
		# Where it began, carried on the wind as it falls; kept in the world as the box moves.
		var x: float = seed.x * span + blown.x * t * height / fall
		var z: float = seed.z * span + blown.y * t * height / fall
		var at := Vector3(centre.x - radius + fposmod(x - centre.x, span), height * (1.0 - t), centre.z - radius + fposmod(z - centre.z, span))
		_drops.set_instance_transform(index, Transform3D(basis, at))
	if _rings == null:
		return
	var lasts: float = maxf(0.05, float(_look.get("rings", {}).get("seconds", 0.45)))
	var rings_shown: int = int(round(float(_ring_count) * amount))
	_rings.visible_instance_count = rings_shown
	for index: int in rings_shown:
		var life: float = _clock / lasts + _ring_seeds[index]
		var t: float = fposmod(life, 1.0)
		# A new place each time round, the same for the same round (no draw of anyone's).
		var round_index: float = floorf(life) + float(index) * 17.0
		var u: float = fposmod(sin(round_index * 12.9898) * 43758.5453, 1.0)
		var v: float = fposmod(sin(round_index * 78.233) * 24634.6345, 1.0)
		var at := Vector3(centre.x - radius + fposmod(u * span - centre.x, span), RING_LIFT, centre.z - radius + fposmod(v * span - centre.z, span))
		_rings.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3(0.25 + 0.75 * t, 1.0, 0.25 + 0.75 * t)), at))
		_rings.set_instance_color(index, Color(_ring_tone, _ring_tone.a * (1.0 - t)))


## How many drops are drawn now (tests, kits).
func shown_drops() -> int:
	return _drops.visible_instance_count if _drops != null else 0


func _show(count: int) -> void:
	if _drops != null and _drops.visible_instance_count != count:
		_drops.visible_instance_count = count
	visible = count > 0


## One MultiMesh of `count` boxes in `tone`, never culled by where its first frame put it.
func _swarm(size: Vector3, count: int, tone: Color, height: float) -> MultiMesh:
	var cube := BoxMesh.new()
	cube.size = size
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = cube
	multi.instance_count = count
	multi.custom_aabb = AABB(Vector3(-4096.0, -1.0, -4096.0), Vector3(8192.0, height + 2.0, 8192.0))
	for index: int in count:
		multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(0.0, -50.0, 0.0)))
		multi.set_instance_color(index, tone)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	instance.material_override = material
	add_child(instance)
	return multi
