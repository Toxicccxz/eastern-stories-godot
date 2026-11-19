extends Node3D

## 状态挂在身上 (DECISIONS「战斗运功」): what a figure's conditions look like, worn by the figure
## for as long as they last — in a fight and out of it (person_states.json `marks`: each
## condition of daemon/condition/ its kind and colour; `wound`: an open wound's). The view reads
## the conditions off the character's state a few times a second and hands them here; this node
## only draws them. KINDS:
## - bubbles: bubbles welling up off the body and bursting over the head (poison);
## - flush: two warm motes circling the head (drunk);
## - drowse: three pale blocks wheeling slowly over the head (蒙汗药);
## - frost: pale chips clinging to head, shoulders and arms, glinting (意寒掌's cold);
## - band: a strip of cloth bound round the head, its knot's end hanging behind (bandaged);
## - drip: dark drops falling from the side to the ground (an open wound, not bound up).
## Every block's place is the clock's alone (no draw, nothing kept): a few blocks a figure.
## Presentation only: no body, no rule, nothing saved.

const KINDS: Array[String] = ["bubbles", "flush", "drowse", "frost", "band", "drip"]
const DATA_PATH: String = "res://data/common/person_states.json"
## Where frost clings (the figure's own space, a person's height 1).
const FROST_SPOTS: Array[Vector3] = [Vector3(0.0, 1.72, 0.0), Vector3(-0.36, 1.2, 0.05), Vector3(0.36, 1.22, -0.05), Vector3(0.0, 1.05, 0.25), Vector3(0.0, 1.1, -0.25), Vector3(-0.32, 0.75, 0.1), Vector3(0.32, 0.8, -0.1)]

static var _data: Dictionary = {}

## How tall the figure is beside a person (a dog's marks sit lower and closer).
var height: float = 1.0
## What is bound on the body hangs from this (a person's torso: it leans and lies with it);
## unset: from this node. `head_lift` and `head_scale`: how much higher than the plain figure's
## this body's neck is, and its head's size beside the plain one's (what is bound round the head
## goes by them, not by `height`); `headless`: it has no head to bind.
var body: Node3D
var head_lift: float = 0.0
var head_scale: float = 1.0
var headless: bool = false
## What is drawn now: [kind, colour hex] each, in the order given.
var shown: Array = []
var clock: float = 0.0
## Each drawn mark's blocks, by its place in `shown`.
var _blocks: Array[Array] = []
var _signature: String = ""


## person_states.json, read once.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


## The marks of `condition_ids` as they stand in the data ([kind, colour hex] each; two
## conditions with one look show once), and an open wound's when `wounded`.
static func marks_for(condition_ids: Array[StringName], wounded: bool) -> Array:
	var marks: Array = []
	var looks: Dictionary = data().get("marks", {})
	for id: StringName in condition_ids:
		var look: Variant = looks.get(String(id))
		if look is Dictionary and KINDS.has(String(look.get("kind", ""))):
			var mark: Array = [String(look["kind"]), String(look.get("colour", "ffffff"))]
			if not marks.has(mark):
				marks.append(mark)
	var wound: Dictionary = data().get("wound", {})
	if wounded and not condition_ids.has(StringName(String(wound.get("stopped_by", "")))):
		marks.append([String(wound.get("kind", "drip")), String(wound.get("colour", "b3261e"))])
	return marks


## Whether a wound is open: 气's ceiling (`effective`) under the data's share of its `maximum`.
static func wounded(effective: int, maximum: int) -> bool:
	return maximum > 0 and float(effective) / float(maximum) < float(data().get("wound", {}).get("below", 0.0))


## How worn a figure is (0 fresh .. 1 spent) with 气 at `current` of `maximum`: from the data's
## `from` share down to its `full`.
static func weariness(current: int, maximum: int) -> float:
	var weary: Dictionary = data().get("weary", {})
	var from: float = float(weary.get("from", 0.0))
	var full: float = float(weary.get("full", 0.0))
	if maximum <= 0 or from <= full:
		return 0.0
	return clampf((from - float(current) / float(maximum)) / (from - full), 0.0, 1.0)


## What the body does under `condition_ids` ([sway, shiver, nod]: the most of each).
static func bearing(condition_ids: Array[StringName]) -> Array[float]:
	var looks: Dictionary = data().get("marks", {})
	var most: Array[float] = [0.0, 0.0, 0.0]
	for id: StringName in condition_ids:
		var look: Variant = looks.get(String(id))
		if look is Dictionary:
			most[0] = maxf(most[0], float(look.get("sway", 0.0)))
			most[1] = maxf(most[1], float(look.get("shiver", 0.0)))
			most[2] = maxf(most[2], float(look.get("nod", 0.0)))
	return most


## The figure wears `marks` now ([kind, colour hex] each); built again only when they change.
func wear(marks: Array) -> void:
	var signature: String = str(marks)
	if signature == _signature:
		return
	_signature = signature
	shown = marks.duplicate(true)
	for blocks: Array in _blocks:
		for block: MeshInstance3D in blocks:
			if is_instance_valid(block):
				block.get_parent().remove_child(block)
				block.queue_free()
	_blocks.clear()
	for mark: Array in shown:
		_blocks.append(_build(String(mark[0]), Color(String(mark[1]))))
	set_process(not shown.is_empty())
	_pose()


func _ready() -> void:
	set_process(not shown.is_empty())


func _process(delta: float) -> void:
	clock += delta
	_pose()


func _build(kind: String, colour: Color) -> Array:
	var blocks: Array = []
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(colour, 0.85)
	glow.render_priority = VoxelBackdrop.OVER_BACKDROP
	match kind:
		"bubbles":
			for index: int in 5:
				blocks.append(_block(glow, Vector3.ONE * 0.11))
		"flush":
			for index: int in 2:
				blocks.append(_block(glow, Vector3.ONE * 0.07))
		"drowse":
			for index: int in 3:
				blocks.append(_block(glow, Vector3.ONE * 0.09))
		"frost":
			for index: int in FROST_SPOTS.size():
				blocks.append(_block(glow, Vector3.ONE * 0.08))
		"band":
			if headless:
				return blocks
			# Cloth is no light: it is lit as the figure is.
			var cloth := StandardMaterial3D.new()
			cloth.albedo_color = colour
			blocks.append(_block(cloth, Vector3(0.53, 0.09, 0.48), true))
			blocks.append(_block(cloth, Vector3(0.08, 0.2, 0.04), true))
		"drip":
			for index: int in 2:
				blocks.append(_block(glow, Vector3(0.06, 0.1, 0.06)))
	return blocks


## A block of `size` (a person's measure); `bound`: on the body, not about it.
func _block(material: Material, size: Vector3, bound: bool = false) -> MeshInstance3D:
	var on_body: bool = bound and body != null and is_instance_valid(body)
	var block := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size * (head_scale if on_body else height)
	block.mesh = mesh
	block.material_override = material
	block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	block.set_meta(&"bound", on_body)
	(body if on_body else self).add_child(block)
	return block


## Every block where the clock has it now.
func _pose() -> void:
	for at: int in shown.size():
		var blocks: Array = _blocks[at]
		match String(shown[at][0]):
			"bubbles":
				for index: int in blocks.size():
					# One after another, each from its own side of the body.
					var t: float = fposmod(clock / 2.2 + float(index) / float(blocks.size()), 1.0)
					var angle: float = 2.4 * index + 0.7
					var wobble: float = sin(t * TAU * 2.0 + index) * 0.05
					_put(blocks[index], Vector3(cos(angle) * 0.38 + wobble, 0.7 + t * 1.4, sin(angle) * 0.38), 0.0 if t > 0.92 else 0.35 + t * 0.9)
			"flush":
				for index: int in blocks.size():
					var angle: float = clock * 2.6 + PI * index
					_put(blocks[index], Vector3(cos(angle) * 0.34, 1.45 + sin(clock * 3.1 + index) * 0.04, sin(angle) * 0.34), 1.0)
			"drowse":
				for index: int in blocks.size():
					var angle: float = clock * 1.3 + TAU * float(index) / float(blocks.size())
					_put(blocks[index], Vector3(cos(angle) * 0.27, 1.92 + sin(clock * 1.7 + index * 2.0) * 0.03, sin(angle) * 0.27), 1.0)
			"frost":
				for index: int in blocks.size():
					_put(blocks[index], FROST_SPOTS[index], 0.7 + 0.5 * absf(sin(clock * 1.9 + index * 1.3)))
			"band":
				if blocks.size() == 2:
					_put(blocks[0], Vector3(0.0, 1.53, 0.0), 1.0)
					_put(blocks[1], Vector3(0.1, 1.34, -0.27), 1.0)
			"drip":
				for index: int in blocks.size():
					var t: float = fposmod(clock / 1.5 + 0.5 * index, 1.0)
					# It gathers at the side, then falls faster and faster to the ground.
					var fall: float = clampf((t - 0.25) / 0.6, 0.0, 1.0)
					_put(blocks[index], Vector3(0.32 - 0.64 * index, 0.95 - 0.92 * fall * fall, 0.1), 0.0 if t > 0.9 else minf(1.0, t * 4.0))


## `block` at `at` (a person's measure, scaled to the figure) and `size` of itself, written only
## when it is not there already.
func _put(block: MeshInstance3D, at: Vector3, size: float) -> void:
	var place: Vector3 = at * height
	if bool(block.get_meta(&"bound", false)):
		# On the body: the head's own place and size (VoxelPerson.head_point()).
		place = Vector3(at.x * head_scale, 1.2 + head_lift + (at.y - 1.2) * head_scale, at.z * head_scale)
	if not block.position.is_equal_approx(place):
		block.position = place
	var scaled: Vector3 = Vector3.ONE * maxf(size, 0.001)
	if not block.scale.is_equal_approx(scaled):
		block.scale = scaled
	if block.visible != (size > 0.0):
		block.visible = size > 0.0
