class_name GrowthFx
extends RefCounted

## 练功演出 (DECISIONS「练功演出」): growth.json, and an art of glowing blocks (BattleArts) with a
## light on a figure of the map, outside a fight — the 气 about one seated, the mark of a gain.
## Presentation only.

const DATA_PATH: String = "res://data/common/growth.json"

static var _data: Dictionary = {}


## growth.json, read once.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func training() -> Dictionary:
	var part: Variant = data().get("training", {})
	return part if part is Dictionary else {}


static func moments() -> Dictionary:
	var part: Variant = data().get("moments", {})
	return part if part is Dictionary else {}


## The art `kind` in `colour` about `model` (a figure of the view: its parent is its place on the
## map) for `seconds`, with a light (`light`: energy, range; none without energy), moved by
## tweens of `host` and gone when over. What was made (the art, the light), for the host to clear
## should it go first; nothing for a figure that is not there, no time or an art unknown.
static func play(host: Node, model: Node3D, kind: String, colour: Color, seconds: float, light: Dictionary, rng: RandomNumberGenerator) -> Array[Node]:
	var made: Array[Node] = []
	if host == null or not host.is_inside_tree() or model == null or model.get_parent() == null or seconds <= 0.0 or not BattleArts.KINDS.has(kind):
		return made
	var parent: Node3D = model.get_parent()
	var tween: Tween = host.create_tween().set_parallel(true)
	var art: Node3D = BattleArts.play(parent, tween, kind, colour, model.position, model.position, seconds, rng)
	art.set_meta(&"growth", kind)
	tween.chain().tween_callback(GrowthFx.drop.bind(art))
	made.append(art)
	# 画质 低 on a phone goes without the fight's lights (GraphicsQuality.stage_lights()): so here.
	if float(light.get("energy", 0.0)) > 0.0 and GraphicsQuality.stage_lights():
		var lamp := OmniLight3D.new()
		lamp.name = "GrowthLight"
		lamp.light_color = colour
		lamp.omni_range = float(light.get("range", 3.4))
		lamp.light_energy = 0.0
		lamp.shadow_enabled = false
		lamp.position = model.position + Vector3.UP * 1.3
		parent.add_child(lamp)
		var glow: Tween = host.create_tween()
		glow.tween_method(GrowthFx.light_step.bind(lamp, float(light["energy"])), 0.0, 1.0, seconds)
		glow.tween_callback(GrowthFx.drop.bind(lamp))
		made.append(lamp)
	return made


## One moment `t` (0..1) of the light (it may be gone with its figure): up in the first fifth,
## held, down over the last quarter.
static func light_step(t: float, light: Variant, energy: float) -> void:
	if is_instance_valid(light):
		(light as OmniLight3D).light_energy = energy * minf(clampf(t / 0.2, 0.0, 1.0), clampf((1.0 - t) / 0.25, 0.0, 1.0))


## `node` gone, if it is still there (its figure may have left the map with it).
static func drop(node: Variant) -> void:
	if is_instance_valid(node):
		(node as Node).queue_free()


## Each of `nodes` still there, gone.
static func clear(nodes: Array[Node]) -> void:
	for index: int in nodes.size():
		drop(nodes[index])
	nodes.clear()


## `nodes` without the ones gone already (one freed cannot be handed to a typed lambda: by index).
static func live(nodes: Array[Node]) -> Array[Node]:
	var kept: Array[Node] = []
	for index: int in nodes.size():
		var node: Variant = nodes[index]
		if is_instance_valid(node):
			kept.append(node)
	return kept
