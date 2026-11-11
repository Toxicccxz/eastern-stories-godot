class_name VoxelGlints
extends Node3D

## 交互闪光点 (owner, 2026-11-11; DECISIONS「交互闪光点」): a small twinkling point, always shown, over
## each thing on the map that does something but may not look like it — a vine or a rope to climb,
## a tree, a stone to push, grass to part, a picture that teaches a dance (a landmark with an action,
## or one whose look teaches), and a room's own command the player has a branch for (ActService:
## 泡澡, 静修, 摘瓜). A landmark that is only looked at and teaches nothing has none. So the player
## knows "there is something here" before walking up to it. Presentation only: it reads the 2D map's
## landmark areas and services and changes nothing; it stands beside the world (a child of the view,
## in the world's coordinates) like the quest marker.

## Over the floor (voxel units): about a hand's height over a waist.
const HEIGHT: float = 1.1
## The point's size at rest and at the top of its twinkle (voxel units across).
const SIZE: float = 0.95
const SIZE_FLASH: float = 1.5
## One twinkle every this many seconds; each point starts at its own place in it.
const PERIOD: float = 2.2
## Warm white at the heart, gold at the arms (the house's lantern colours, not the exits' amber),
## and a faint dark warm shadow round them so they read on pale sand and snow.
const CORE: Color = Color("fffdf2")
const ARMS: Color = Color("ffc93c")
const SHADOW: Color = Color(0.23, 0.12, 0.04, 0.45)
## How often the room commands' branches are asked again (a mark taken, a class joined).
const REFRESH_SECONDS: float = 0.5

## landmark id or service id -> the point (a billboarded quad).
var points: Dictionary[StringName, MeshInstance3D] = {}
var _phases: Dictionary[StringName, float] = {}
var _acts: Dictionary[StringName, ActService] = {}
var _clock: float = 0.0
var _since_refresh: float = INF
static var _texture: ImageTexture


## A point over each landmark and room command of `map` worth one (see above).
func build(map: WorldMapController) -> void:
	name = "Glints"
	# Out of doors over whatever stands there (the tree a vine hangs from, the rock), so never
	# hidden by it; indoors behind the walls and the roof like the room itself.
	var materials: Array[StandardMaterial3D] = [_material(false), _material(true)]
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * SIZE
	for landmark_id: StringName in map.landmark_areas:
		var landmark: WorldLandmarkDefinition = GameContent.catalog().landmark(landmark_id)
		if landmark == null or not worth_a_glint(landmark):
			continue
		_add(landmark_id, _middle(map.landmark_areas[landmark_id]), materials[int(_outdoors(landmark.zone_id))], quad)
	for service: WorldService in map.service_nodes:
		if service is ActService:
			_add(service.service_id(), service.anchor(), materials[int(_outdoors(service.definition.zone_id))], quad)
			_acts[service.service_id()] = service as ActService


## A landmark that does something when used (any policy with an action), or whose look teaches.
static func worth_a_glint(landmark: WorldLandmarkDefinition) -> bool:
	var policy: Dictionary = WorldLandmarkDefinition.POLICIES.get(landmark.policy, {})
	return not bool(policy.get("no_action", false)) or not landmark.teaches.is_empty()


## Twinkles each point; all away while `hidden` (a show on a stage), a room command's while the
## player has no branch of it.
func advance(delta: float, hidden: bool) -> void:
	_clock += delta
	visible = not hidden
	if hidden:
		return
	_since_refresh += delta
	if _since_refresh >= REFRESH_SECONDS:
		_since_refresh = 0.0
		for id: StringName in _acts:
			points[id].visible = _acts[id].offers_player()
	for id: StringName in points:
		var point: MeshInstance3D = points[id]
		if not point.visible:
			continue
		# A quick swell and fade once a period, a faint breath between.
		var t: float = fposmod(_clock / PERIOD + _phases[id], 1.0)
		var flash: float = maxf(0.0, sin(t * TAU * 3.0)) if t < 1.0 / 6.0 else 0.0
		var breath: float = 0.5 + 0.5 * sin(_clock * 2.0 + _phases[id] * TAU)
		point.scale = Vector3.ONE * lerpf(SIZE, SIZE_FLASH, flash) / SIZE
		point.transparency = lerpf(0.25 - 0.2 * breath, 0.0, flash)


func _add(id: StringName, at: Vector2, material: Material, quad: QuadMesh) -> void:
	var point := MeshInstance3D.new()
	point.name = String(id).replace(".", "_")
	point.mesh = quad
	point.material_override = material
	point.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	point.position = VoxelMapGeometry.point(at, HEIGHT)
	add_child(point)
	points[id] = point
	# Each its own moment: points side by side do not twinkle together.
	_phases[id] = float(hash(id) % 1000) / 1000.0


static func _outdoors(zone_id: StringName) -> bool:
	var zone: ZoneDefinition = GameContent.catalog().zone(zone_id)
	return zone == null or not zone.indoors


## The middle of a landmark's area (its shape, else the area itself).
static func _middle(area: Area2D) -> Vector2:
	var shape: CollisionShape2D = area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return area.global_position if shape == null else shape.global_position


static func _material(over_all: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.no_depth_test = over_all
	material.albedo_texture = _star()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# The twinkle swells the point (its scale), which a billboard drops unless told to keep it.
	material.billboard_keep_scale = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return material


## A four-armed star: a warm white heart, gold arms thinning to their tips, a soft halo.
static func _star() -> ImageTexture:
	if _texture != null:
		return _texture
	var size: int = 48
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var middle: float = (size - 1) / 2.0
	for y: int in size:
		for x: int in size:
			var dx: float = absf(x - middle) / middle
			var dy: float = absf(y - middle) / middle
			var arm: float = maxf(clampf(1.0 - dx - 5.0 * dy, 0.0, 1.0), clampf(1.0 - dy - 5.0 * dx, 0.0, 1.0))
			var halo: float = clampf(1.0 - Vector2(dx, dy).length() * 2.0, 0.0, 1.0)
			var core: float = clampf(1.0 - Vector2(dx, dy).length() * 3.2, 0.0, 1.0)
			# The arms a little wider in shadow, under the light.
			var shade: float = maxf(clampf(1.0 - dx - 2.5 * dy, 0.0, 1.0), clampf(1.0 - dy - 2.5 * dx, 0.0, 1.0)) * 0.8
			var light: float = clampf(maxf(arm * 1.6, halo * 0.7) + core, 0.0, 1.0)
			var colour: Color = ARMS.lerp(CORE, clampf(core * 2.0 + halo * 0.5, 0.0, 1.0))
			colour.a = light
			var under: Color = SHADOW
			under.a *= minf(1.0, shade * 2.0)
			image.set_pixel(x, y, under.blend(colour))
	_texture = ImageTexture.create_from_image(image)
	return _texture
