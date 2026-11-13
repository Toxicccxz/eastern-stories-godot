class_name BattleSwingTrail
extends MeshInstance3D

## 战斗特效 (DECISIONS「战斗特效」): the light a weapon leaves as it swings — the stretch of its
## edge (`from`..`to`, in `source`'s own space: VoxelPerson.strike_edge()) swept through the air,
## as flat facets between where the edge was one frame and the next, the newest brightest, each
## fading over `fade` seconds. The edge is followed for `sampling` seconds (the blow's travel);
## the facets left then fade out and the trail reports `finished`.
## Presentation only. Drawn in the world's own space (top_level), so the figure moving on does
## not drag what it left behind.

signal finished

## A facet is not laid for a move shorter than this (an edge held still leaves no light).
const MIN_STEP: float = 0.01
## The most facets kept (a long fade at a high frame rate).
const MAX_FACETS: int = 48

var source: Node3D
var from: Vector3
var to: Vector3
var colour: Color = Color.WHITE
var sampling: float = 0.1
var fade: float = 0.18
## Each sample: [the edge's near end, its far end (world), its age in seconds].
var _samples: Array[Array] = []
var _age: float = 0.0
var _done: bool = false
var _shape := ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _shape
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = VoxelBackdrop.OVER_BACKDROP
	material_override = material
	# No sample yet: the figure takes the blow's first pose in its own frame, and the edge it
	# held on guard is no part of the sweep.


func _process(delta: float) -> void:
	advance(delta)


## `delta` seconds on (the suites call it themselves): the edge sampled while the blow travels,
## every facet older, the mesh drawn again.
func advance(delta: float) -> void:
	if _done:
		return
	_age += delta
	for sample: Array in _samples:
		sample[2] = float(sample[2]) + delta
	while not _samples.is_empty() and float(_samples[0][2]) >= fade:
		_samples.pop_front()
	if _age <= sampling:
		_sample()
	_draw()
	if _age > sampling and _samples.size() < 2:
		_done = true
		_shape.clear_surfaces()
		finished.emit()


## How many facets are drawn now (tests).
func facet_count() -> int:
	return maxi(0, _samples.size() - 1)


func _sample() -> void:
	if source == null or not is_instance_valid(source) or not source.is_inside_tree():
		return
	var near: Vector3 = source.global_transform * from
	var far: Vector3 = source.global_transform * to
	if not _samples.is_empty() and (_samples.back()[1] as Vector3).distance_to(far) < MIN_STEP:
		return
	_samples.append([near, far, 0.0])
	if _samples.size() > MAX_FACETS + 1:
		_samples.pop_front()


func _draw() -> void:
	_shape.clear_surfaces()
	if _samples.size() < 2 or fade <= 0.0:
		return
	_shape.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(1, _samples.size()):
		var old: Array = _samples[index - 1]
		var new: Array = _samples[index]
		# One flat shade to a facet (its newer edge's): the steps of the sweep show.
		var shade := Color(colour, colour.a * clampf(1.0 - float(new[2]) / fade, 0.0, 1.0))
		for corner: Vector3 in [old[0], old[1], new[1], old[0], new[1], new[0]]:
			_shape.surface_set_color(shade)
			_shape.surface_add_vertex(corner)
	_shape.surface_end()
