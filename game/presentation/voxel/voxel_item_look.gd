class_name VoxelItemLook
extends RefCounted
## What a carried thing looks like (owner, 2026-11-04: every item a voxel picture, a small one
## on its 背包 row and a large one turning beside the list). game/data/common/item_looks.json
## gives each item a `kind` and its colours and sizes; the props files voxel_item_arms,
## voxel_item_wear and voxel_item_goods draw the kinds. Presentation only: no rule reads it.
##
## Also the little studio both pictures are taken in: an own world with a warm key light, a
## cool fill and a soft ambient, an orthographic camera looking down at the game's angle, the
## background clear so the panel shows through.

const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
const Arms = preload("res://presentation/voxel/props/voxel_item_arms.gd")
const Wear = preload("res://presentation/voxel/props/voxel_item_wear.gd")
const Goods = preload("res://presentation/voxel/props/voxel_item_goods.gd")
const LOOKS_PATH: String = "res://data/common/item_looks.json"
## The camera's look down, as the map's (a little flatter, so a thing reads face on).
const PITCH: float = -0.42
## The camera's turn round the item in a still picture (an icon).
const ICON_YAW: float = 0.55
## Room left round a framed thing.
const MARGIN: float = 1.12

static var _looks: Dictionary = {}
static var _loaded: bool = false


## The look of an item definition, or {} when it has none. A form the catalog makes of
## another item (a 断掉的 blade, food half eaten, a letter with a name: `<id>#...`) looks like
## that item; a broken one with its blade snapped (`broken`).
static func look(item_definition_id: StringName) -> Dictionary:
	_load()
	var id: String = String(item_definition_id)
	if _looks.has(id):
		return _looks[id]
	var found: Dictionary = _looks.get(id.get_slice("#", 0), {})
	if found.is_empty() or not id.contains(ItemContentDefinition.BROKEN_SUFFIX):
		return found
	var broken: Dictionary = found.duplicate()
	broken["broken"] = true
	return broken


static func all_looks() -> Dictionary:
	_load()
	return _looks


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOOKS_PATH))
	if parsed is Dictionary and (parsed as Dictionary).get("looks") is Dictionary:
		_looks = (parsed as Dictionary)["looks"]
	else:
		push_error("item looks: %s is missing or not {\"looks\": {...}}" % LOOKS_PATH)


## Draws `look` into `parent` about the origin. False when its kind is not drawn by any of
## the item props files: a wrapped parcel stands in.
static func build(parent: Node3D, data: Dictionary) -> bool:
	var shapes := Shapes.new()
	var drawn: bool = false
	if data.has("kind"):
		drawn = Arms.new().draw(shapes, parent, data) or Wear.new().draw(shapes, parent, data) or Goods.new().draw(shapes, parent, data)
	if not drawn:
		Goods.new().draw(shapes, parent, {"kind": "parcel"})
	# The box round what was drawn, from the boxes themselves: a renderer that draws nothing
	# (headless) knows no mesh's extent.
	var box := AABB()
	var first: bool = true
	for key: Variant in shapes.batches:
		var entry: Dictionary = shapes.batches[key]
		var shape: AABB = (entry["mesh"] as Mesh).get_aabb()
		for placed: Transform3D in entry["transforms"]:
			box = placed * shape if first else box.merge(placed * shape)
			first = false
	parent.set_meta(&"look_bounds", box)
	shapes.flush()
	return drawn


## Whether a thing this shape is shown leaning, so a long blade fills a square picture.
static func leans(bounds: AABB) -> bool:
	return bounds.size.y > 2.2 * maxf(bounds.size.x, bounds.size.z)


## The box round what build() drew into `model`, in its own space.
static func bounds(model: Node3D) -> AABB:
	return model.get_meta(&"look_bounds", AABB())


## Lights, environment and camera in `viewport` (an own world, its background clear); the
## returned pivot holds the thing shown.
static func furnish(viewport: SubViewport) -> Node3D:
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	var stage := Node3D.new()
	stage.name = "Stage"
	viewport.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a39280")
	environment.ambient_light_energy = 0.95
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.name = "Key"
	key.light_color = Color("fff0d6")
	key.light_energy = 1.4
	key.rotation = Vector3(-0.9, -0.6, 0.0)
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_color = Color("b9cbe8")
	fill.light_energy = 0.5
	fill.rotation = Vector3(-0.3, 2.4, 0.0)
	stage.add_child(fill)
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.05
	camera.far = 20.0
	camera.rotation = Vector3(PITCH, 0.0, 0.0)
	camera.position = Vector3(0.0, 0.0, 0.0) + camera.basis.z * 6.0
	camera.current = true
	stage.add_child(camera)
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	stage.add_child(pivot)
	return pivot


## Puts a freshly drawn `model` (a child of `pivot`) in the middle of the picture and sizes the
## camera to it: turning about `pivot` (`turning`), or still at ICON_YAW, a long thing leaning.
static func frame(pivot: Node3D, model: Node3D, camera: Camera3D, turning: bool) -> void:
	var box: AABB = bounds(model)
	if box.size == Vector3.ZERO:
		return
	model.rotation = Vector3(0.0, 0.0, -PI / 4 if not turning and leans(box) else 0.0)
	var tilt: Basis = model.basis
	model.position = -(tilt * box.get_center())
	var corners: Array[Vector3] = []
	for i: int in 8:
		corners.append(tilt * (box.get_endpoint(i) - box.get_center()))
	var yaws: Array[float] = []
	if turning:
		for i: int in 16:
			yaws.append(i * TAU / 16)
	else:
		yaws.append(ICON_YAW)
		pivot.rotation.y = ICON_YAW
	var view: Basis = camera.basis.inverse()
	var reach := Vector2.ZERO
	for yaw: float in yaws:
		var turn := Basis(Vector3.UP, yaw)
		for corner: Vector3 in corners:
			var seen: Vector3 = view * (turn * corner)
			reach.x = maxf(reach.x, absf(seen.x))
			reach.y = maxf(reach.y, absf(seen.y))
	camera.size = maxf(reach.x, reach.y) * 2.0 * MARGIN
